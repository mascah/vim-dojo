package main

import (
	"encoding/json"
	"fmt"
	"math/rand/v2"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

// Leitner boxes 1 to 5 and the days until each is due again.
var intervals = []int64{1, 3, 7, 14, 30}

const (
	placedBox     = 3
	roundLength   = 10
	sectionLength = 20
	scenarioTail  = 3
	// A timed mixed round asks for a goal per this many seconds of its limit.
	secondsPerGoal = 4
)

// v2 wrote solved, assisted, and recalled; they still mark a drill as tried.
var results = map[string]bool{"started": true, "clean": true, "unclean": true, "skipped": true,
	"round": true, "placed": true, "solved": true, "assisted": true, "recalled": true}

// v2 technique ids whose lesson took another id, as in drills.vim.
var renamed = map[string]string{"counts": "count-lines", "join": "line-ops", "paren": "bracket",
	"brace": "bracket", "insert-at": "insert-line", "put": "yank-put"}

type Section struct {
	ID      string   `json:"id"`
	Name    string   `json:"name"`
	Lessons []string `json:"lessons"`
}

type Drill struct {
	ID     string
	Custom bool
}

type Lesson struct {
	ID         string            `json:"id"`
	Title      string            `json:"title"`
	Keys       [][2]string       `json:"keys"`
	Generators []json.RawMessage `json:"generators"`
	Scenarios  []struct {
		ID string `json:"id"`
	} `json:"scenarios"`
	Section string   `json:"-"`
	Page    []string `json:"-"`
	Drills  []Drill  `json:"-"`
}

type Catalog struct {
	Root     string
	Drills   string // the custom drill directory
	Sections []Section
	Lessons  []*Lesson // in outline order, then Custom
	ByID     map[string]*Lesson
}

// Load reads lessons/outline.json, every lesson page, and the learner's
// custom drills. A custom drill joins the lesson its technique names, or
// stands as a lesson of its own in Custom.
func Load(root, drills string) (*Catalog, error) {
	c := &Catalog{Root: root, Drills: drills, ByID: map[string]*Lesson{}}
	data, err := os.ReadFile(filepath.Join(root, "lessons", "outline.json"))
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal(data, &c.Sections); err != nil {
		return nil, fmt.Errorf("outline.json: %w", err)
	}
	builtin := map[string]bool{}
	for _, section := range c.Sections {
		for _, id := range section.Lessons {
			lesson, err := ReadLesson(filepath.Join(root, "lessons", id+".md"))
			if err != nil {
				return nil, err
			}
			lesson.Section = section.ID
			for _, s := range lesson.Scenarios {
				lesson.Drills = append(lesson.Drills, Drill{ID: s.ID})
				builtin[s.ID] = true
			}
			c.Lessons = append(c.Lessons, lesson)
			c.ByID[lesson.ID] = lesson
		}
	}
	c.custom(builtin)
	return c, nil
}

var fence = regexp.MustCompile("^```json\\s*$")

// ReadLesson reads a page that ends with one ```json block holding the lesson.
func ReadLesson(path string) (*Lesson, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	lines := strings.Split(strings.TrimRight(string(data), "\n"), "\n")
	open := -1
	for i := len(lines) - 1; i >= 0; i-- {
		if fence.MatchString(lines[i]) {
			open = i
			break
		}
	}
	end := -1
	for i := open + 1; open >= 0 && i < len(lines); i++ {
		if strings.TrimSpace(lines[i]) == "```" {
			end = i
			break
		}
	}
	if open < 0 || end < 0 || strings.TrimSpace(strings.Join(lines[end+1:], "")) != "" {
		return nil, fmt.Errorf("%s does not end with one ```json block", path)
	}
	lesson := &Lesson{}
	if err := json.Unmarshal([]byte(strings.Join(lines[open+1:end], "\n")), lesson); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	page := lines[:open]
	for len(page) > 0 && strings.TrimSpace(page[len(page)-1]) == "" {
		page = page[:len(page)-1]
	}
	lesson.Page = page
	return lesson, nil
}

var customID = regexp.MustCompile(`^[a-z0-9-]+$`)

// ponytail: only id, goal, lines, and technique are checked here; drills.vim
// validates the rest and skips a bad file, which then drops out of its round.
func (c *Catalog) custom(builtin map[string]bool) {
	names, _ := filepath.Glob(filepath.Join(c.Drills, "*.json"))
	sort.Strings(names)
	seen := map[string]bool{}
	for _, name := range names {
		data, err := os.ReadFile(name)
		if err != nil {
			continue
		}
		var drill struct {
			ID     string   `json:"id"`
			Goal   string   `json:"goal"`
			Lesson string   `json:"technique"` // custom drill files keep the v2 name
			Lines  []string `json:"lines"`
		}
		if json.Unmarshal(data, &drill) != nil || drill.Goal == "" || len(drill.Lines) == 0 {
			continue
		}
		if builtin[drill.ID] || c.ByID[drill.ID] != nil {
			drill.ID = "custom-" + drill.ID
		}
		if !customID.MatchString(drill.ID) || seen[drill.ID] || c.ByID[drill.ID] != nil {
			continue
		}
		seen[drill.ID] = true
		id := drill.Lesson
		if to, ok := renamed[id]; ok {
			id = to
		}
		if lesson := c.ByID[id]; lesson != nil && lesson.Section != "custom" {
			lesson.Drills = append(lesson.Drills, Drill{ID: drill.ID, Custom: true})
			continue
		}
		lesson := &Lesson{ID: drill.ID, Title: drill.ID, Section: "custom",
			Drills: []Drill{{ID: drill.ID, Custom: true}}}
		c.Lessons = append(c.Lessons, lesson)
		c.ByID[lesson.ID] = lesson
	}
}

// SectionName is the section's name, Custom for the learner's own lessons.
func (c *Catalog) SectionName(id string) string {
	for _, s := range c.Sections {
		if s.ID == id {
			return s.Name
		}
	}
	return "Custom"
}

// InSection lists a section's lessons in order.
func (c *Catalog) InSection(id string) []*Lesson {
	var lessons []*Lesson
	for _, l := range c.Lessons {
		if l.Section == id {
			lessons = append(lessons, l)
		}
	}
	return lessons
}

// Record is one file in the state directory: a goal, a round, or a placement.
type Record struct {
	Name    string `json:"-"`
	ID      string `json:"id"`
	Time    int64  `json:"time"`
	Result  string `json:"result"`
	Lesson  string `json:"technique"` // records keep the v2 name
	Section string `json:"section"`
	Kind    string `json:"kind"`
	Clean   int    `json:"clean"`
	Goals   int    `json:"goals"`
	Passed  any    `json:"passed"` // Vim writes 1 and 0, tests write true
	Seconds int64  `json:"seconds"`
}

func (r Record) Pass() bool {
	switch v := r.Passed.(type) {
	case bool:
		return v
	case float64:
		return v != 0
	}
	return false
}

var recordName = regexp.MustCompile(`^\d+-\d+-\d+\.json$`)

// Records reads every record in the state directory, ordered by name, which
// orders records by time and, within one Vim, by attempt. A malformed file
// is skipped.
func Records(dir string) []Record {
	entries, _ := os.ReadDir(dir)
	var records []Record
	for _, entry := range entries {
		if !recordName.MatchString(entry.Name()) {
			continue
		}
		data, err := os.ReadFile(filepath.Join(dir, entry.Name()))
		var r Record
		if err != nil || json.Unmarshal(data, &r) != nil || r.ID == "" || r.Time == 0 || !results[r.Result] {
			continue
		}
		r.Name = entry.Name()
		records = append(records, r)
	}
	sort.SliceStable(records, func(i, j int) bool { return records[i].Time < records[j].Time })
	return records
}

// Day counts days since the epoch in local time, so "due tomorrow" follows
// the calendar.
func Day(t int64) int64 {
	_, offset := time.Unix(t, 0).Zone()
	return (t + int64(offset)) / 86400
}

// Item is a lesson's place in review. Box 0 is new.
type Item struct {
	Box, Rounds int
	Due, Last   int64
	Recent      []Record // learn and review rounds, oldest first
}

// Level is 0 for new, 1 for shaky (boxes 1 and 2), 2 for solid.
func (i *Item) Level() int {
	switch {
	case i.Box == 0:
		return 0
	case i.Box < 3:
		return 1
	}
	return 2
}

// State replays round records and placements. A passed round puts a new
// lesson in the first box and moves a known one up; one that is not passed
// leaves a new lesson new and sends a known one back to the first. v2's
// per-drill records move nothing.
func State(c *Catalog, records []Record) map[string]*Item {
	state := map[string]*Item{}
	for _, l := range c.Lessons {
		state[l.ID] = &Item{}
	}
	for _, r := range records {
		item := state[r.Lesson]
		if item == nil || r.Result != "round" && r.Result != "placed" {
			continue
		}
		if r.Result == "placed" {
			item.Box = max(item.Box, placedBox)
		} else {
			item.Rounds++
			item.Recent = append(item.Recent, r)
			switch {
			case r.Pass():
				item.Box = min(item.Box+1, len(intervals))
			case item.Box > 0:
				item.Box = 1
			}
		}
		if item.Box > 0 {
			item.Last = r.Time
			item.Due = Day(r.Time) + intervals[item.Box-1]
		}
	}
	return state
}

// Planned is a round still to be drawn: its kind and its lesson or section,
// or for a mixed round its lessons and how many goals or seconds it lasts.
type Planned struct {
	Kind         string
	Lesson       *Lesson
	Section      string
	Lessons      []*Lesson
	Count, Limit int
}

// Plan is today's session: a review round for each of up to three due
// lessons, oldest first, then a learn round on the next new one. With nothing
// due and nothing new, it reviews whatever is due soonest.
func Plan(c *Catalog, state map[string]*Item, today int64) []Planned {
	var known, review, learn []*Lesson
	for _, l := range c.Lessons {
		if state[l.ID].Box > 0 {
			known = append(known, l)
		} else if learn == nil {
			learn = []*Lesson{l}
		}
	}
	sort.SliceStable(known, func(i, j int) bool { return state[known[i].ID].Due < state[known[j].ID].Due })
	for _, l := range known {
		if state[l.ID].Due <= today && len(review) < 3 {
			review = append(review, l)
		}
	}
	if len(review) == 0 && len(learn) == 0 && len(known) > 0 {
		review = known[:1]
	}
	var plan []Planned
	for _, l := range review {
		plan = append(plan, Planned{Kind: "review", Lesson: l})
	}
	for _, l := range learn {
		plan = append(plan, Planned{Kind: "learn", Lesson: l})
	}
	return plan
}

// Goal names one goal for the runner: generated from a lesson, or a drill.
type Goal struct {
	Lesson    string `json:"lesson"`
	Generated bool   `json:"generated,omitempty"`
	Drill     string `json:"drill,omitempty"`
}

// Request is the round the shell hands the runner, written to round.json in
// the state directory.
type Request struct {
	Kind    string   `json:"kind"`
	Lesson  string   `json:"lesson"`
	Section string   `json:"section,omitempty"`
	Name    string   `json:"name,omitempty"`
	Goals   []Goal   `json:"goals"`
	Demo    bool     `json:"demo"`
	Place   []string `json:"place"`
	Drills  string   `json:"drills"`
	Limit   int      `json:"limit,omitempty"` // seconds, for a timed mixed round
	Count   int      `json:"count,omitempty"` // goals, for a mixed round by count
}

// Order lists a lesson's drills least recently tried first, and among those
// never tried, the learner's own first: a custom drill counts a second older.
func Order(l *Lesson, records []Record) []Drill {
	tried := map[string]int64{}
	for _, r := range records {
		tried[r.ID] = max(tried[r.ID], r.Time)
	}
	at := func(d Drill) int64 {
		if d.Custom {
			return tried[d.ID] - 1
		}
		return tried[d.ID]
	}
	order := append([]Drill(nil), l.Drills...)
	sort.SliceStable(order, func(i, j int) bool { return at(order[i]) < at(order[j]) })
	return order
}

// Goals is a round's ten goals on one lesson. With generators, the runner
// draws them as the round opens, and up to three of its scenarios and custom
// drills follow, after the generated run so a cursor lesson's hops are not
// broken. Otherwise it cycles through its drills.
func Goals(l *Lesson, records []Record) []Goal {
	order := Order(l, records)
	var goals []Goal
	if len(l.Generators) > 0 {
		tail := order[:min(scenarioTail, len(order))]
		for range roundLength - len(tail) {
			goals = append(goals, Goal{Lesson: l.ID, Generated: true})
		}
		for _, d := range tail {
			goals = append(goals, Goal{Lesson: l.ID, Drill: d.ID})
		}
		return goals
	}
	for i := range roundLength {
		goals = append(goals, Goal{Lesson: l.ID, Drill: order[i%len(order)].ID})
	}
	return goals
}

// Draw turns a planned round into a request. A learn round on a lesson never
// practised has its first goal demonstrated. A section review is twenty goals
// drawn evenly from the section's lessons, shuffled; each lesson's share is
// the start of its round, so its scenarios come least recently tried first and
// none twice before all have come. Passing it places the section's new lessons.
func Draw(c *Catalog, p Planned, records []Record) Request {
	state := State(c, records)
	if p.Kind == "mixed" {
		return Mixed(c, p, state, records, Day(time.Now().Unix()))
	}
	if p.Section == "" {
		return Request{Kind: p.Kind, Lesson: p.Lesson.ID, Goals: Goals(p.Lesson, records),
			Demo: p.Kind == "learn" && state[p.Lesson.ID].Rounds == 0, Place: []string{}, Drills: c.Drills}
	}
	lessons := c.InSection(p.Section)
	r := Request{Kind: "section", Section: p.Section, Name: c.SectionName(p.Section), Place: []string{},
		Drills: c.Drills}
	for i, l := range lessons {
		share := sectionLength / len(lessons)
		if i < sectionLength%len(lessons) {
			share++
		}
		r.Goals = append(r.Goals, Goals(l, records)[:share]...)
		if state[l.ID].Box == 0 {
			r.Place = append(r.Place, l.ID)
		}
	}
	rand.Shuffle(len(r.Goals), func(i, j int) { r.Goals[i], r.Goals[j] = r.Goals[j], r.Goals[i] })
	return r
}

// Mixed draws a mixed round over the planned lessons, each goal from a
// lesson picked at random, three times as often when it is due and twice
// when shaky. A lesson gives at most a round's worth, the start of its round.
// A timed round asks for as many goals as its limit might take; the runner
// ends it at the limit. It writes no lesson's record, so it moves no box.
func Mixed(c *Catalog, p Planned, state map[string]*Item, records []Record, today int64) Request {
	weight := func(l *Lesson) int {
		switch item := state[l.ID]; {
		case item.Box > 0 && item.Due <= today:
			return 3
		case item.Level() == 1:
			return 2
		}
		return 1
	}
	count := p.Count
	if p.Limit > 0 {
		count = p.Limit / secondsPerGoal
	}
	share := make([]int, len(p.Lessons))
	for range count {
		total := 0
		for i, l := range p.Lessons {
			if share[i] < roundLength {
				total += weight(l)
			}
		}
		if total == 0 {
			break
		}
		n := rand.IntN(total)
		for i, l := range p.Lessons {
			if share[i] < roundLength {
				if n -= weight(l); n < 0 {
					share[i]++
					break
				}
			}
		}
	}
	// Too few lessons to fill the count, the runner goes round their goals.
	r := Request{Kind: "mixed", Limit: p.Limit, Place: []string{}, Drills: c.Drills}
	if p.Limit == 0 {
		r.Count = count
	}
	for i, l := range p.Lessons {
		r.Goals = append(r.Goals, Goals(l, records)[:share[i]]...)
	}
	rand.Shuffle(len(r.Goals), func(i, j int) { r.Goals[i], r.Goals[j] = r.Goals[j], r.Goals[i] })
	return r
}

// Title is how a round is named in the shell and in Vim's panel.
func (p Planned) Title(c *Catalog) string {
	switch {
	case p.Kind == "mixed":
		return "Mixed practice"
	case p.Section != "":
		return "Section review  " + c.SectionName(p.Section)
	case p.Kind == "learn":
		return "Learn  " + p.Lesson.Title
	}
	return "Review  " + p.Lesson.Title
}

// Inbox counts the friction notes waiting in the state directory.
func Inbox(dir string) (string, int) {
	inbox := filepath.Join(dir, "inbox")
	names, _ := filepath.Glob(filepath.Join(inbox, "*.json"))
	return inbox, len(names)
}

// What the dashboard counts from the records.

// Active is the goals finished on each day.
func Active(records []Record) map[int64]int {
	days := map[int64]int{}
	for _, r := range records {
		switch r.Result {
		case "clean", "unclean", "skipped":
			days[Day(r.Time)]++
		}
	}
	return days
}

// Streak is the days in a row with practice, up to today, or up to yesterday
// while today has none yet.
func Streak(days map[int64]int, today int64) int {
	if days[today] == 0 {
		today--
	}
	n := 0
	for ; days[today] > 0; today-- {
		n++
	}
	return n
}

// Totals sums rounds.
type Totals struct {
	Rounds, Clean, Goals int
	Seconds              int64
}

// Since sums the rounds finished on or after a day.
func Since(records []Record, day int64) Totals {
	var t Totals
	for _, r := range records {
		if r.Result == "round" && Day(r.Time) >= day {
			t.Rounds++
			t.Clean += r.Clean
			t.Goals += r.Goals
			t.Seconds += r.Seconds
		}
	}
	return t
}

// Forecast is how many lessons fall due on each of the next n days, today
// first. An overdue lesson counts as today.
func Forecast(items map[string]*Item, today int64, n int) []int {
	days := make([]int, n)
	for _, item := range items {
		if at := max(item.Due-today, 0); item.Box > 0 && at < int64(n) {
			days[at]++
		}
	}
	return days
}

// Boxes counts the lessons in each box, new ones in box 0.
func Boxes(items map[string]*Item) [6]int {
	var boxes [6]int
	for _, item := range items {
		boxes[item.Box]++
	}
	return boxes
}
