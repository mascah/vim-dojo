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

	tea "github.com/charmbracelet/bubbletea"
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

func key(k string) tea.KeyMsg {
	switch k {
	case "enter":
		return tea.KeyMsg{Type: tea.KeyEnter}
	case "esc":
		return tea.KeyMsg{Type: tea.KeyEsc}
	}
	return tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune(k)}
}

func plain(s string) string { return regexp.MustCompile(`\x1b\[[0-9;]*m`).ReplaceAllString(s, "") }

// outline and shell-map: the eleven sections and their lessons in order,
// each ending in a review, every lesson new on a fresh state, and the cursor
// on today's session.
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
	m := &model{catalog: c, state: t.TempDir()}
	m.refresh()
	var got, expected []string
	for _, r := range m.rows {
		if r.kind == "lesson" || r.kind == "review" {
			got = append(got, r.kind+" "+r.id)
		}
		if strings.Contains(r.text, "◐") || strings.Contains(r.text, "●") {
			t.Errorf("not new on a fresh state: %q", r.text)
		}
		if len([]rune(r.text)) > 80 {
			t.Errorf("wider than 80: %q", r.text)
		}
	}
	for _, s := range c.Sections {
		for _, id := range s.Lessons {
			expected = append(expected, "lesson "+id)
		}
		expected = append(expected, "review "+s.ID)
	}
	if strings.Join(got, "\n") != strings.Join(expected, "\n") {
		t.Fatalf("rows\n%v\nwant\n%v", got, expected)
	}
	view := plain(m.View())
	for _, text := range []string{"0 due today · 0 in inbox", "New here?", "› ▶ Start today's session",
		"learn modes and Esc", "○ modes and Esc       new", "▷ Review Foundations", "Enter open · s stats · q quit"} {
		if !strings.Contains(view, text) {
			t.Errorf("map lacks %q:\n%s", text, view)
		}
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
	m := &model{catalog: c, state: dir}
	m.refresh()
	if view := plain(m.View()); !strings.Contains(view, "3 due today") ||
		!strings.Contains(view, "review :g / . / Ctrl-O Ctrl-I  ·  learn modes") {
		t.Fatalf("session row:\n%s", view)
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
	m := &model{catalog: c, state: t.TempDir()}
	m.refresh()
	if view := plain(m.View()); !strings.Contains(view, "Custom") || !strings.Contains(view, "○ old-gone") {
		t.Fatalf("no Custom section:\n%s", view)
	}
}

// shell-page and page-first: Enter on a lesson shows its page, which
// scrolls; Enter there writes the round's request and starts Vim.
func TestPage(t *testing.T) {
	c := catalog(t)
	m := &model{catalog: c, state: t.TempDir()}
	m.refresh()
	m.Update(tea.WindowSizeMsg{Width: 80, Height: 10})
	m.Update(key("j"))
	m.Update(key("j"))
	m.Update(key("enter"))
	if m.view != pageView || m.pending.Lesson.ID != "modes" || m.pending.Kind != "learn" {
		t.Fatalf("Enter on the first lesson: view %d %+v", m.view, m.pending)
	}
	top := plain(m.View())
	if !strings.Contains(top, "Modes and Esc") || strings.Contains(top, "```") {
		t.Fatalf("page:\n%s", top)
	}
	m.Update(key("j"))
	if m.scroll != 1 || plain(m.View()) == top {
		t.Fatal("the page does not scroll")
	}
	m.Update(key("G"))
	if lines := m.pageLines(); !strings.Contains(m.View(), lines[len(lines)-1]) || m.scroll == 0 {
		t.Fatal("the end of the page is out of reach")
	}
	_, cmd := m.Update(key("enter"))
	if cmd == nil || m.view != mapView {
		t.Fatal("Enter on the page did not start the round")
	}
	var r Request
	data, err := os.ReadFile(filepath.Join(m.state, "round.json"))
	if err != nil || json.Unmarshal(data, &r) != nil || r.Kind != "learn" || r.Lesson != "modes" || len(r.Goals) != 10 {
		t.Fatalf("request %s %v", data, err)
	}
	// A session's learn round on a new lesson opens on its page too.
	m.Update(key("g"))
	m.Update(key("enter"))
	if m.view != pageView || !m.fromSession {
		t.Fatal("the session's new lesson skipped its page")
	}
}

// shell-round: after Vim exits, the shell says how the round went from the
// records it left, and the map shows the lesson's new state. A round left
// early says so and drops the rest of the session.
func TestFinish(t *testing.T) {
	c := catalog(t)
	dir := t.TempDir()
	m := &model{catalog: c, state: dir}
	m.refresh()
	m.session = Plan(c, m.items, m.today())
	m.sessionSize = 2
	m.session = append(m.session, m.session[0])
	p := m.session[0]
	m.session = m.session[1:]
	now := time.Now().Unix()
	write(t, dir, map[string]any{"id": "a", "technique": "modes", "result": "clean", "time": now},
		round("modes", "learn", 8, 1, now))
	m.Update(roundDone{planned: p, request: Request{Goals: make([]Goal, 10)}, before: map[string]bool{}})
	view := plain(m.View())
	for _, text := range []string{"Learn  modes and Esc  ·  8 of 10 clean  ·  1:00  ·  passed",
		"› ▶ Next round, 2 of 2", "◐ modes and Esc       shaky     due tomorrow"} {
		if !strings.Contains(view, text) {
			t.Errorf("lacks %q:\n%s", text, view)
		}
	}
	before := map[string]bool{}
	for _, r := range Records(dir) {
		before[r.Name] = true
	}
	write(t, dir, map[string]any{"id": "b", "technique": "modes", "result": "clean", "time": now + 1},
		map[string]any{"id": "c", "technique": "modes", "result": "started", "time": now + 1})
	m.Update(roundDone{planned: m.session[0], request: Request{Goals: make([]Goal, 10)}, before: before})
	if view := plain(m.View()); !strings.Contains(view, "Left Learn  modes and Esc after 1 of 10 goals, 1 clean") ||
		!strings.Contains(view, "Start today's session") || len(m.session) != 0 {
		t.Fatalf("left early:\n%s", view)
	}
	// shell-stats: the lesson's recent round, clean of goals and seconds per goal.
	m.Update(key("s"))
	if view := plain(m.View()); !strings.Contains(view, "modes and Esc       8/10  6.0s") {
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
	m := &model{catalog: c, state: dir}
	m.refresh()
	m.Update(key("j"))
	if m.rows[m.cursor].kind != "mixed" {
		t.Fatalf("no mixed row after the session: %+v", m.rows[m.cursor])
	}
	m.Update(key("enter"))
	if view := plain(m.View()); m.view != mixedView || !strings.Contains(view, "every learned lesson (2)") ||
		!strings.Contains(view, "‹ 20 goals ›") {
		t.Fatalf("mixed view:\n%s", view)
	}
	m.Update(key("l"))
	m.Update(key("l"))
	m.Update(key("l"))
	m.Update(key("j"))
	m.Update(key(" "))
	if view := plain(m.View()); !strings.Contains(view, "‹ 5 minutes ›") || !strings.Contains(view, "[x] Entering Insert") ||
		!strings.Contains(view, "Entering Insert (4 lessons)") {
		t.Fatalf("after choosing:\n%s", view)
	}
	_, cmd := m.Update(key("enter"))
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
	view := plain(m.View())
	if !strings.Contains(view, "Mixed practice  ·  11 of 14 clean  ·  5:00") || strings.Contains(view, "passed") {
		t.Fatalf("mixed summary:\n%s", view)
	}
	m.Update(key("s"))
	if view := plain(m.View()); !strings.Contains(view, "Mixed practice      11/14 21.4s") {
		t.Fatalf("stats:\n%s", view)
	}
}
