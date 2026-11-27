package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
	"time"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/x/ansi"
)

func catalog(t *testing.T) *Catalog {
	t.Helper()
	c, err := Load(".", filepath.Join(t.TempDir(), "drills"))
	if err != nil {
		t.Fatal(err)
	}
	return c
}

// write puts records in a state directory under names that sort in order.
func write(t *testing.T, dir string, records ...map[string]any) {
	t.Helper()
	os.MkdirAll(dir, 0o700)
	existing, _ := os.ReadDir(dir)
	for i, r := range records {
		data, _ := json.Marshal(r)
		name := fmt.Sprintf("%012d-0000000001-%06d.json", r["time"], len(existing)+i+1)
		if err := os.WriteFile(filepath.Join(dir, name), data, 0o600); err != nil {
			t.Fatal(err)
		}
	}
}

func round(id, kind string, clean int, passed any, at int64) map[string]any {
	return map[string]any{"id": id, "technique": id, "result": "round", "kind": kind,
		"clean": clean, "goals": 10, "passed": passed, "seconds": 60, "time": at}
}

// press is the message for a key by its name.
func press(name string) tea.KeyPressMsg {
	switch name {
	case "enter":
		return tea.KeyPressMsg{Code: tea.KeyEnter}
	case "esc":
		return tea.KeyPressMsg{Code: tea.KeyEscape}
	case "space":
		return tea.KeyPressMsg{Code: tea.KeySpace, Text: " "}
	}
	return tea.KeyPressMsg{Code: []rune(name)[0], Text: name}
}

// shown is what the shell shows, without colour.
func shown(m *model) string { return ansi.Strip(m.View().Content) }

// outline and shell-map: the eleven sections in order, each listing its
// lessons and ending in a review, every lesson new on a fresh state, and the
// cursor on today's session.
func TestMap(t *testing.T) {
	c := catalog(t)
	var names []string
	for _, s := range c.Sections {
		names = append(names, s.Name)
	}
	want := "Foundations,Entering Insert,Along the line,Operators,Through the file,Search and jumps," +
		"Text objects,Repeat,Visual,Registers and macros,Ex"
	if strings.Join(names, ",") != want {
		t.Fatalf("sections %v", names)
	}
	m := newModel(c, t.TempDir())
	view := shown(m)
	lines := strings.Split(view, "\n")
	if len(lines) != 24 {
		t.Errorf("%d lines at the default size", len(lines))
	}
	for _, line := range lines {
		if ansi.StringWidth(line) > 80 {
			t.Errorf("wider than 80: %q", line)
		}
	}
	if strings.ContainsAny(view, "◐●") {
		t.Errorf("not new on a fresh state:\n%s", view)
	}
	for _, text := range []string{"Due today", "› ▶ Start today's session", "▶ learn  modes and Esc", "New here?",
		"j/k move", "l lessons", "enter open", "q quit"} {
		if !strings.Contains(view, text) {
			t.Errorf("dashboard lacks %q:\n%s", text, view)
		}
	}
	m.Update(press("j"))
	for _, s := range c.Sections {
		m.Update(press("j"))
		// The detail pane is right of the practice pane, which is 33 wide at 80.
		var detail strings.Builder
		for _, line := range strings.Split(shown(m), "\n") {
			if runes := []rune(line); len(runes) > 33 {
				detail.WriteString(string(runes[33:]) + "\n")
			}
		}
		pane, at := detail.String(), 0
		for _, id := range s.Lessons {
			row := "○ " + truncate(c.ByID[id].Title, 19)
			i := strings.Index(pane[at:], row)
			if i < 0 {
				t.Fatalf("%s: no %q in order:\n%s", s.Name, row, pane)
			}
			at += i + len(row)
		}
		if !strings.Contains(pane[at:], "▷ Review "+s.Name) {
			t.Fatalf("%s: no review after its lessons:\n%s", s.Name, pane)
		}
	}
}

// The dashboard's counts: a streak runs back from today, or from yesterday
// while today is empty, and stops at a gap; an overdue lesson falls due
// today; every lesson sits in one box.
func TestMetrics(t *testing.T) {
	c := catalog(t)
	dir := t.TempDir()
	now := time.Now().Unix()
	write(t, dir, round("modes", "learn", 9, true, now-40*86400), round("hjkl", "learn", 9, true, now),
		map[string]any{"id": "a", "technique": "hjkl", "result": "clean", "time": now},
		map[string]any{"id": "b", "technique": "hjkl", "result": "unclean", "time": now - 86400},
		map[string]any{"id": "c", "technique": "hjkl", "result": "skipped", "time": now - 3*86400})
	records, today := Records(dir), Day(now)
	days := Active(records)
	if days[today] != 1 || Streak(days, today) != 2 || Streak(days, today+1) != 2 || Streak(days, today+2) != 0 {
		t.Fatalf("days %v: streaks %d %d %d", days, Streak(days, today), Streak(days, today+1), Streak(days, today+2))
	}
	if s := Since(records, today); s != (Totals{Rounds: 1, Clean: 9, Goals: 10, Seconds: 60}) {
		t.Fatalf("today's totals %+v", s)
	}
	items := State(c, records)
	if f := Forecast(items, today, 7); f[0] != 1 || f[1] != 1 || len(f) != 7 {
		t.Fatalf("forecast %v", f)
	}
	boxes, sum := Boxes(items), 0
	for _, n := range boxes {
		sum += n
	}
	if sum != len(c.Lessons) || boxes[1] != 2 {
		t.Fatalf("boxes %v", boxes)
	}
}

// box-by-round and learn-pass: a passed learn round makes a lesson shaky,
// due tomorrow; seven clean leaves it new; a passed review moves it up; one
// not passed sends it back to the first box. v2 records move nothing.
func TestState(t *testing.T) {
	c := catalog(t)
	dir := t.TempDir()
	now := time.Now().Unix()
	day := Day(now)
	write(t, dir, map[string]any{"id": "quoted-item", "technique": "quote", "result": "recalled", "time": now - 9})
	write(t, dir, round("dot", "learn", 7, 0, now-8))
	if s := State(c, Records(dir)); s["dot"].Box != 0 || s["quote"].Box != 0 {
		t.Fatalf("seven clean or a v2 record moved a box: %+v %+v", s["dot"], s["quote"])
	}
	write(t, dir, round("dot", "learn", 8, 1, now-7))
	if s := State(c, Records(dir))["dot"]; s.Box != 1 || s.Due != day+1 || s.Level() != 1 {
		t.Fatalf("learn pass: %+v", s)
	}
	write(t, dir, round("dot", "review", 8, true, now-6))
	if s := State(c, Records(dir))["dot"]; s.Box != 2 || s.Due != day+3 {
		t.Fatalf("review pass: %+v", s)
	}
	write(t, dir, round("dot", "review", 7, false, now-5))
	if s := State(c, Records(dir))["dot"]; s.Box != 1 || s.Due != day+1 || s.Rounds != 4 {
		t.Fatalf("review fail: %+v", s)
	}
	os.WriteFile(filepath.Join(dir, "000000000001-0000000001-999999.json"), []byte("not json"), 0o600)
	if len(Records(dir)) != 5 {
		t.Fatal("a malformed record was read")
	}
}

// Today's session reviews up to three due lessons, oldest first, then
// teaches the next new one.
func TestPlan(t *testing.T) {
	c := catalog(t)
	dir := t.TempDir()
	now := time.Now().Unix()
	for _, r := range []struct {
		id   string
		days int64
	}{{"global", 5}, {"dot", 4}, {"jumplist", 3}, {"substitute", 2}} {
		write(t, dir, round(r.id, "learn", 9, true, now-r.days*86400))
	}
	write(t, dir, round("substitute", "review", 9, true, now-86400))
	state := State(c, Records(dir))
	if state["substitute"].Box != 2 || state["substitute"].Due-Day(now) != 2 {
		t.Fatalf("substitute %+v", state["substitute"])
	}
	var got []string
	for _, p := range Plan(c, state, Day(now)) {
		got = append(got, p.Kind+" "+p.Lesson.ID)
	}
	if strings.Join(got, ",") != "review global,review dot,review jumplist,learn modes" {
		t.Fatalf("plan %v", got)
	}
	view := shown(newModel(c, dir))
	for _, text := range []string{"3 lessons", "▶ review :g", "· review .", "· review Ctrl-O Ctrl-I", "· learn  modes and Esc"} {
		if !strings.Contains(view, text) {
			t.Errorf("session pane lacks %q:\n%s", text, view)
		}
	}
}

// round-length and the section review: ten goals on a lesson, generated
// first; twenty in a section review, five from each Foundations lesson, with
// its new lessons to place; each scenario once before any twice.
func TestDraw(t *testing.T) {
	c := catalog(t)
	dir := t.TempDir()
	write(t, dir, round("hjkl", "learn", 9, true, time.Now().Unix()))
	records := Records(dir)
	r := Draw(c, Planned{Kind: "learn", Lesson: c.ByID["quote"]}, records)
	if len(r.Goals) != 10 || !r.Demo || r.Lesson != "quote" {
		t.Fatalf("quote round %+v", r)
	}
	for i, g := range r.Goals {
		if g.Generated != (i < 7) {
			t.Fatalf("goal %d %+v", i, g)
		}
	}
	if Draw(c, Planned{Kind: "learn", Lesson: c.ByID["hjkl"]}, records).Demo {
		t.Fatal("a lesson already practised is demonstrated again")
	}
	r = Draw(c, Planned{Kind: "section", Section: "foundations"}, records)
	count := map[string]int{}
	for _, g := range r.Goals {
		count[g.Lesson]++
	}
	if len(r.Goals) != 20 || fmt.Sprint(count) != "map[hjkl:5 insert:5 modes:5 word:5]" ||
		strings.Join(r.Place, ",") != "modes,word,insert" || r.Name != "Foundations" {
		t.Fatalf("section %v %+v", count, r)
	}
	ids := map[string]map[string]bool{}
	for _, g := range Draw(c, Planned{Kind: "section", Section: "repeat"}, nil).Goals {
		if ids[g.Lesson] == nil {
			ids[g.Lesson] = map[string]bool{}
		}
		ids[g.Lesson][g.Drill] = true
	}
	for lesson, drills := range ids {
		if len(drills) < 4 {
			t.Errorf("%s repeats a scenario before using four: %v", lesson, drills)
		}
	}
}

// section-skip: placements put a section's lessons in the third box, solid,
// and a lesson already learned keeps its box.
func TestPlaced(t *testing.T) {
	c := catalog(t)
	dir := t.TempDir()
	now := time.Now().Unix()
	write(t, dir, round("hjkl", "learn", 9, true, now-2))
	for _, id := range []string{"modes", "word", "insert"} {
		write(t, dir, map[string]any{"id": id, "technique": id, "result": "placed", "time": now})
	}
	s := State(c, Records(dir))
	if s["modes"].Box != 3 || s["modes"].Level() != 2 || s["hjkl"].Box != 1 || s["insert-line"].Box != 0 {
		t.Fatalf("%+v %+v", s["modes"], s["hjkl"])
	}
}

// custom-still-loads: a custom drill joins its lesson, under a renamed v2 id
// too, takes a custom- prefix when a built-in has its id, and stands in
// Custom when its lesson is gone. Untried custom drills come first.
func TestCustom(t *testing.T) {
	drills := t.TempDir()
	for name, body := range map[string]string{
		"paren.json": `{"id": "old-paren", "goal": "Empty it", "technique": "paren", "lines": ["f(x)"]}`,
		"clash.json": `{"id": "quoted-item", "goal": "Quote it", "technique": "quote", "lines": ["x"]}`,
		"gone.json":  `{"id": "old-gone", "goal": "Empty it", "technique": "no-such", "lines": ["f(x)"]}`,
		"bad.json":   `{}`,
	} {
		os.WriteFile(filepath.Join(drills, name), []byte(body), 0o600)
	}
	c, err := Load(".", drills)
	if err != nil {
		t.Fatal(err)
	}
	last := func(l *Lesson) Drill { return l.Drills[len(l.Drills)-1] }
	if last(c.ByID["bracket"]).ID != "old-paren" || last(c.ByID["quote"]).ID != "custom-quoted-item" {
		t.Fatalf("custom drills did not join their lessons")
	}
	if l := c.ByID["old-gone"]; l == nil || l.Section != "custom" || len(c.Lessons) != 54 {
		t.Fatalf("old-gone %+v, %d lessons", l, len(c.Lessons))
	}
	goals := Goals(c.ByID["quote"], nil)
	if goals[7].Drill != "custom-quoted-item" {
		t.Fatalf("an untried custom drill does not come first: %+v", goals[7:])
	}
	m := newModel(c, t.TempDir())
	if view := shown(m); !strings.Contains(view, "Custom") {
		t.Fatalf("no Custom section:\n%s", view)
	}
	m.Update(press("G"))
	m.Update(press("l"))
	if view := shown(m); !strings.Contains(view, "○ old-gone") {
		t.Fatalf("Custom does not list old-gone:\n%s", view)
	}
}

// shell-page and page-first: Enter on a section, then on a lesson, shows its
// page, which scrolls; Enter there writes the round's request and starts Vim.
func TestPage(t *testing.T) {
	c := catalog(t)
	m := newModel(c, t.TempDir())
	m.Update(tea.WindowSizeMsg{Width: 80, Height: 10})
	for _, k := range []string{"j", "j", "enter", "enter"} {
		m.Update(press(k))
	}
	if m.screen != pageScreen || m.pending.Lesson.ID != "modes" || m.pending.Kind != "learn" {
		t.Fatalf("Enter on the first lesson: screen %d %+v", m.screen, m.pending)
	}
	top := shown(m)
	if !strings.Contains(top, "Modes and Esc") || strings.Contains(ansi.Strip(m.page.GetContent()), "`") {
		t.Fatalf("page:\n%s", top)
	}
	m.Update(press("j"))
	if m.page.YOffset() != 1 || shown(m) == top {
		t.Fatal("the page does not scroll")
	}
	m.Update(press("G"))
	if !m.page.AtBottom() {
		t.Fatal("the end of the page is out of reach")
	}
	_, cmd := m.Update(press("enter"))
	if cmd == nil || m.screen != homeScreen {
		t.Fatal("Enter on the page did not start the round")
	}
	var r Request
	data, err := os.ReadFile(filepath.Join(m.state, "round.json"))
	if err != nil || json.Unmarshal(data, &r) != nil || r.Kind != "learn" || r.Lesson != "modes" || len(r.Goals) != 10 {
		t.Fatalf("request %s %v", data, err)
	}
	// A session's learn round on a new lesson opens on its page too.
	m.Update(press("esc"))
	m.Update(press("g"))
	m.Update(press("enter"))
	if m.screen != pageScreen || !m.fromSession {
		t.Fatal("the session's new lesson skipped its page")
	}
}

// shell-round: after Vim exits, the shell says how the round went from the
// records it left, and the dashboard shows the lesson's new state. A round left
// early says so and drops the rest of the session.
func TestFinish(t *testing.T) {
	c := catalog(t)
	dir := t.TempDir()
	m := newModel(c, dir)
	m.session = Plan(c, m.items, m.today())
	m.sessionSize = 2
	m.session = append(m.session, m.session[0])
	p := m.session[0]
	m.session = m.session[1:]
	now := time.Now().Unix()
	write(t, dir, map[string]any{"id": "a", "technique": "modes", "result": "clean", "time": now},
		round("modes", "learn", 8, 1, now))
	m.Update(roundDone{planned: p, request: Request{Goals: make([]Goal, 10)}, before: map[string]bool{}})
	view := shown(m)
	for _, text := range []string{"Learn  modes and Esc  ·  8 of 10 clean  ·  1:00  ·  passed",
		"› ▶ Next round, 2 of 2"} {
		if !strings.Contains(view, text) {
			t.Errorf("lacks %q:\n%s", text, view)
		}
	}
	m.Update(press("j"))
	m.Update(press("j"))
	if view := shown(m); !regexp.MustCompile(`◐ modes and Esc +shaky.*due tomorrow`).MatchString(view) {
		t.Errorf("Foundations does not show modes shaky:\n%s", view)
	}
	before := map[string]bool{}
	for _, r := range Records(dir) {
		before[r.Name] = true
	}
	write(t, dir, map[string]any{"id": "b", "technique": "modes", "result": "clean", "time": now + 1},
		map[string]any{"id": "c", "technique": "modes", "result": "started", "time": now + 1})
	m.Update(roundDone{planned: m.session[0], request: Request{Goals: make([]Goal, 10)}, before: before})
	if view := shown(m); !strings.Contains(view, "Left Learn  modes and Esc after 1 of 10 goals, 1 clean") ||
		!strings.Contains(view, "Start today's session") || len(m.session) != 0 {
		t.Fatalf("left early:\n%s", view)
	}
	// shell-stats: the lesson's recent round, clean of goals and seconds per goal.
	m.Update(press("s"))
	if view := shown(m); !strings.Contains(view, "modes and Esc       8/10  6.0s") {
		t.Fatalf("stats:\n%s", view)
	}
}

// mixed-round: goals from more than one learned lesson, leaning toward due
// and shaky ones, at most a round's worth from each, and no box moves after.
// timed: a time limit asks for as many goals as it might take.
func TestMixed(t *testing.T) {
	c := catalog(t)
	dir := t.TempDir()
	now := time.Now().Unix()
	write(t, dir, round("modes", "learn", 9, true, now-40*86400), round("hjkl", "learn", 9, true, now),
		round("word", "learn", 9, true, now-40*86400), round("word", "review", 9, true, now-30*86400),
		round("word", "review", 9, true, now-20*86400), round("word", "review", 9, true, now))
	records := Records(dir)
	learned := []*Lesson{c.ByID["modes"], c.ByID["hjkl"], c.ByID["word"]}
	count := map[string]int{}
	for range 50 {
		r := Draw(c, Planned{Kind: "mixed", Lessons: learned, Count: 20}, records)
		if len(r.Goals) != 20 || r.Kind != "mixed" || r.Demo || r.Lesson != "" || r.Limit != 0 {
			t.Fatalf("mixed round %+v", r)
		}
		lessons := map[string]int{}
		for _, g := range r.Goals {
			lessons[g.Lesson]++
			count[g.Lesson]++
		}
		if len(lessons) < 2 || lessons["modes"]+lessons["hjkl"]+lessons["word"] != 20 {
			t.Fatalf("goals from %v", lessons)
		}
	}
	// modes is due, hjkl shaky, word solid and not due.
	if !(count["modes"] > count["word"] && count["hjkl"] > count["word"]) {
		t.Fatalf("does not lean toward due and shaky: %v", count)
	}
	if r := Draw(c, Planned{Kind: "mixed", Lessons: learned[:1], Count: 20}, records); len(r.Goals) != 10 || r.Count != 20 {
		t.Fatalf("one lesson gave %d goals, count %d", len(r.Goals), r.Count)
	}
	if r := Draw(c, Planned{Kind: "mixed", Lessons: learned, Limit: 120}, records); r.Limit != 120 || len(r.Goals) != 30 || r.Count != 0 {
		t.Fatalf("timed round of %d goals, limit %d", len(r.Goals), r.Limit)
	}
	before := State(c, records)["modes"].Box
	write(t, dir, map[string]any{"id": "mixed", "result": "round", "kind": "mixed", "clean": 0, "goals": 20,
		"passed": 0, "seconds": 60, "time": now + 1})
	if State(c, Records(dir))["modes"].Box != before {
		t.Fatal("a mixed round moved a box")
	}
}

// The mixed row opens a view to pick the length and the sections; with none
// chosen it takes every learned lesson. Its summary has no pass, and stats
// show mixed rounds on a line of their own.
func TestMixedShell(t *testing.T) {
	c := catalog(t)
	dir := t.TempDir()
	now := time.Now().Unix()
	write(t, dir, round("modes", "learn", 9, true, now), round("hjkl", "learn", 9, true, now))
	m := newModel(c, dir)
	m.Update(press("j"))
	if m.left != 1 {
		t.Fatalf("no mixed row after the session: row %d", m.left)
	}
	m.Update(press("enter"))
	if view := shown(m); !m.dialog || !strings.Contains(view, "every learned lesson (2)") ||
		!strings.Contains(view, "‹ 20 goals ›") {
		t.Fatalf("mixed view:\n%s", view)
	}
	m.Update(press("l"))
	m.Update(press("l"))
	m.Update(press("l"))
	m.Update(press("j"))
	m.Update(press("space"))
	if view := shown(m); !strings.Contains(view, "‹ 5 minutes ›") || !strings.Contains(view, "[x] Entering Insert") ||
		!strings.Contains(view, "Entering Insert (4 lessons)") {
		t.Fatalf("after choosing:\n%s", view)
	}
	_, cmd := m.Update(press("enter"))
	var r Request
	data, err := os.ReadFile(filepath.Join(dir, "round.json"))
	if cmd == nil || err != nil || json.Unmarshal(data, &r) != nil || r.Kind != "mixed" || r.Limit != 300 {
		t.Fatalf("request %s %v", data, err)
	}
	for _, g := range r.Goals {
		if c.ByID[g.Lesson].Section != "entering-insert" {
			t.Fatalf("goal outside the chosen section: %+v", g)
		}
	}
	before := map[string]bool{}
	for _, rec := range Records(dir) {
		before[rec.Name] = true
	}
	write(t, dir, map[string]any{"id": "mixed", "result": "round", "kind": "mixed", "clean": 11, "goals": 14,
		"passed": 0, "seconds": 300, "time": now + 1})
	m.Update(roundDone{planned: Planned{Kind: "mixed", Limit: 300}, request: r, before: before})
	view := shown(m)
	if !strings.Contains(view, "Mixed practice  ·  11 of 14 clean  ·  5:00") || strings.Contains(view, "passed") {
		t.Fatalf("mixed summary:\n%s", view)
	}
	m.Update(press("s"))
	if view := shown(m); !strings.Contains(view, "Mixed practice      11/14 21.4s") {
		t.Fatalf("stats:\n%s", view)
	}
}

// Every screen, at every size from tiny to huge, fresh and practised, draws
// without a panic, no wider than the window and no taller.
func TestSizes(t *testing.T) {
	c := catalog(t)
	fresh, practised := t.TempDir(), t.TempDir()
	now := time.Now().Unix()
	for i, l := range c.Lessons[:12] {
		at := now - int64(i)*86400
		write(t, practised, map[string]any{"id": "g-" + l.ID, "technique": l.ID, "result": "clean", "time": at},
			round(l.ID, "learn", 8+i%3, i%4 != 3, at))
	}
	write(t, practised, map[string]any{"id": "mixed", "result": "round", "kind": "mixed", "clean": 15, "goals": 20,
		"passed": 0, "seconds": 200, "time": now})
	os.MkdirAll(filepath.Join(practised, "inbox"), 0o700)
	os.WriteFile(filepath.Join(practised, "inbox", "note.json"), []byte("{}"), 0o600)
	screens := map[string]string{"home": "", "detail": "j j j j j l j", "session": "enter", "page": "j j l enter",
		"stats": "s", "dialog": "m j space l l l", "help": "?"}
	for name, keys := range screens {
		for _, dir := range []string{fresh, practised} {
			for w := 20; w <= 150; w += 7 {
				for h := 5; h <= 50; h += 3 {
					m := newModel(c, dir)
					m.Update(tea.WindowSizeMsg{Width: w, Height: h})
					if dir == practised {
						// The line a round leaves above the footer.
						m.Update(roundDone{planned: Planned{Kind: "learn", Lesson: c.Lessons[0]},
							request: Request{Goals: make([]Goal, 10)}, before: map[string]bool{}})
					}
					for _, k := range strings.Fields(keys) {
						m.Update(press(k))
					}
					lines := strings.Split(m.View().Content, "\n")
					if len(lines) > h {
						t.Errorf("%s %s %dx%d: %d lines", name, dir, w, h, len(lines))
					}
					for _, line := range lines {
						if ansi.StringWidth(line) > w {
							t.Errorf("%s %s %dx%d: a line %d wide", name, dir, w, h, ansi.StringWidth(line))
							break
						}
					}
				}
			}
		}
	}
}
