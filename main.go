// Command dojo is Vim Dojo's shell: the map, lesson pages, and stats. A
// round runs in the learner's own Vim, which the shell starts on a request
// file in the state directory and reads the records of when Vim exits.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

var (
	symbols = []string{"○", "◐", "●"}
	words   = []string{"new", "shaky", "solid"}

	bold     = lipgloss.NewStyle().Bold(true)
	faint    = lipgloss.NewStyle().Faint(true)
	selected = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("5"))
	levels   = []lipgloss.Style{faint, lipgloss.NewStyle().Foreground(lipgloss.Color("3")),
		lipgloss.NewStyle().Foreground(lipgloss.Color("2"))}
	code = lipgloss.NewStyle().Foreground(lipgloss.Color("6"))
)

func main() {
	root, err := pluginRoot()
	if err == nil {
		var c *Catalog
		if c, err = Load(root, drillDir()); err == nil {
			m := &model{catalog: c, state: stateDir()}
			m.refresh()
			_, err = tea.NewProgram(m, tea.WithAltScreen()).Run()
		}
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "dojo:", err)
		os.Exit(1)
	}
}

// pluginRoot is VIM_DOJO_ROOT, or the directory the dojo binary sits in,
// following a symlink to it.
func pluginRoot() (string, error) {
	if root := os.Getenv("VIM_DOJO_ROOT"); root != "" {
		return root, nil
	}
	exe, err := os.Executable()
	if err == nil {
		exe, err = filepath.EvalSymlinks(exe)
	}
	if err != nil {
		return "", err
	}
	root := filepath.Dir(exe)
	if _, err := os.Stat(filepath.Join(root, "lessons", "outline.json")); err != nil {
		return "", fmt.Errorf("no lessons next to %s; set VIM_DOJO_ROOT to the vim-dojo checkout", exe)
	}
	return root, nil
}

func stateDir() string {
	if dir := os.Getenv("VIM_DOJO_STATE_DIR"); dir != "" {
		return dir
	}
	home := os.Getenv("XDG_STATE_HOME")
	if home == "" {
		home = filepath.Join(os.Getenv("HOME"), ".local", "state")
	}
	return filepath.Join(home, "vim-dojo")
}

func drillDir() string {
	if dir := os.Getenv("VIM_DOJO_DRILL_DIR"); dir != "" {
		return dir
	}
	return filepath.Join(os.Getenv("HOME"), ".vim", "vim-dojo", "drills")
}

type view int

const (
	mapView view = iota
	pageView
	statsView
	mixedView
)

// The lengths a mixed round can have: a number of goals, or minutes.
var lengths = []struct {
	label        string
	count, limit int
}{{"10 goals", 10, 0}, {"20 goals", 20, 0}, {"40 goals", 40, 0},
	{"2 minutes", 0, 120}, {"5 minutes", 0, 300}, {"10 minutes", 0, 600}}

const defaultLength = 1

// row is one line of the map. Rows with a kind can be selected.
type row struct {
	text, kind, id string
}

type model struct {
	catalog       *Catalog
	state         string
	records       []Record
	items         map[string]*Item
	rows          []row
	cursor        int
	offset        int
	width, height int
	view          view
	scroll        int // the page's or stats' first line
	page          []string
	pending       Planned // the round a page starts
	fromSession   bool
	session       []Planned // the rest of today's session once it has started
	sessionSize   int
	banner        []string
	length        int             // the mixed round's, in lengths
	chosen        map[string]bool // the sections a mixed round is over
	mixCursor     int
}

func (m *model) Init() tea.Cmd { return nil }

// refresh rereads the records and redraws the map, keeping the cursor on
// the row it was on, or on today's session to begin with.
func (m *model) refresh() {
	var at row
	if m.cursor < len(m.rows) {
		at = m.rows[m.cursor]
	}
	m.records = Records(m.state)
	m.items = State(m.catalog, m.records)
	m.rows = m.mapRows()
	m.cursor = m.first("session")
	for i, r := range m.rows {
		if at.kind != "" && at.kind != "session" && r.kind == at.kind && r.id == at.id {
			m.cursor = i
		}
	}
}

func (m *model) first(kind string) int {
	for i, r := range m.rows {
		if r.kind == kind {
			return i
		}
	}
	return 0
}

func pad(text string, width int) string {
	return text + strings.Repeat(" ", max(0, width-lipgloss.Width(text)))
}

func due(item *Item, today int64) string {
	days := item.Due - today
	switch {
	case item.Box == 0:
		return ""
	case days <= 0:
		return "due today"
	case days == 1:
		return "due tomorrow"
	}
	return fmt.Sprintf("due in %d days", days)
}

func (m *model) today() int64 { return Day(time.Now().Unix()) }

func (m *model) plan() []Planned {
	if len(m.session) > 0 {
		return m.session
	}
	return Plan(m.catalog, m.items, m.today())
}

func (m *model) mapRows() []row {
	today := m.today()
	dueCount, fresh := 0, true
	for _, l := range m.catalog.Lessons {
		if item := m.items[l.ID]; item.Box > 0 {
			fresh = false
			if item.Due <= today {
				dueCount++
			}
		}
	}
	inboxDir, inbox := Inbox(m.state)
	right := fmt.Sprintf("%d due today · %d in inbox", dueCount, inbox)
	rows := []row{{text: pad("Vim Dojo", 78-lipgloss.Width(right)) + right}, {}}
	if inbox > 0 {
		rows = append(rows, row{text: "  Inbox notes are in " + tilde(inboxDir)})
	}
	if fresh {
		rows = append(rows, row{text: "  New here? Pass a section's review to skip it, or press Enter to begin."})
	}
	if inbox > 0 || fresh {
		rows = append(rows, row{})
	}
	label := "Start today's session"
	if len(m.session) > 0 {
		label = fmt.Sprintf("Next round, %d of %d", m.sessionSize-len(m.session)+1, m.sessionSize)
	}
	var parts []string
	for _, kind := range []string{"review", "learn"} {
		var titles []string
		for _, p := range m.plan() {
			if p.Kind == kind {
				titles = append(titles, p.Lesson.Title)
			}
		}
		if len(titles) > 0 {
			parts = append(parts, kind+" "+strings.Join(titles, " / "))
		}
	}
	rows = append(rows, row{text: truncate(fmt.Sprintf("  ▶ %-29s%s", label, strings.Join(parts, "  ·  ")), 80),
		kind: "session"}, row{text: "  ▶ Mixed practice", kind: "mixed"}, row{})

	for _, section := range append(m.catalog.Sections, Section{ID: "custom", Name: "Custom"}) {
		lessons := m.catalog.InSection(section.ID)
		if len(lessons) == 0 {
			continue
		}
		bar, solid := "", 0
		for _, l := range lessons {
			level := m.items[l.ID].Level()
			bar += symbols[level]
			if level == 2 {
				solid++
			}
		}
		rows = append(rows, row{text: pad(section.Name, 22) + pad(bar, 11) +
			fmt.Sprintf("%d of %d solid", solid, len(lessons))})
		for _, l := range lessons {
			item := m.items[l.ID]
			text := "  " + symbols[item.Level()] + " " + pad(truncate(l.Title, 19), 20) +
				pad(words[item.Level()], 10) + due(item, today)
			rows = append(rows, row{text: strings.TrimRight(text, " "), kind: "lesson", id: l.ID})
		}
		if section.ID != "custom" {
			rows = append(rows, row{text: "  ▷ Review " + section.Name, kind: "review", id: section.ID})
		}
	}
	return rows
}

func truncate(text string, width int) string {
	runes := []rune(text)
	if len(runes) > width {
		return string(runes[:width-1]) + "…"
	}
	return text
}

func tilde(path string) string {
	if home := os.Getenv("HOME"); home != "" && strings.HasPrefix(path, home+"/") {
		return "~" + path[len(home):]
	}
	return path
}

func (m *model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
	case roundDone:
		m.finish(msg)
	case tea.KeyMsg:
		key := msg.String()
		if key == "ctrl+c" {
			return m, tea.Quit
		}
		switch m.view {
		case mapView:
			return m, m.mapKey(key)
		case pageView:
			if key == "enter" {
				m.view = mapView
				return m, m.start(m.pending, m.fromSession)
			}
			m.scrollKey(key, len(m.pageLines()))
		case statsView:
			m.scrollKey(key, len(m.statsLines()))
		case mixedView:
			return m, m.mixedKey(key)
		}
	}
	return m, nil
}

func (m *model) mapKey(key string) tea.Cmd {
	switch key {
	case "q", "esc":
		return tea.Quit
	case "j", "down":
		m.move(1)
	case "k", "up":
		m.move(-1)
	case "g", "home":
		m.cursor = m.first("session")
	case "G", "end":
		m.cursor = len(m.rows)
		m.move(-1)
	case "s":
		m.view, m.scroll = statsView, 0
	case "enter":
		r := m.rows[m.cursor]
		switch r.kind {
		case "session":
			if len(m.session) == 0 {
				m.session = m.plan()
				m.sessionSize = len(m.session)
			}
			if len(m.session) > 0 {
				return m.open(m.session[0], true)
			}
		case "lesson":
			l := m.catalog.ByID[r.id]
			kind := "review"
			if m.items[l.ID].Box == 0 {
				kind = "learn"
			}
			return m.open(Planned{Kind: kind, Lesson: l}, false)
		case "review":
			return m.start(Planned{Kind: "section", Section: r.id}, false)
		case "mixed":
			m.view = mixedView
			if m.chosen == nil {
				m.chosen, m.length = map[string]bool{}, defaultLength
			}
		}
	}
	return nil
}

func (m *model) move(step int) {
	for i := m.cursor + step; i >= 0 && i < len(m.rows); i += step {
		if m.rows[i].kind != "" {
			m.cursor = i
			return
		}
	}
}

func (m *model) scrollKey(key string, lines int) {
	page := m.bodyHeight(lines, "")
	switch key {
	case "q", "esc":
		m.view = mapView
	case "j", "down":
		m.scroll++
	case "k", "up":
		m.scroll--
	case " ", "f", "pgdown", "ctrl+d":
		m.scroll += page
	case "b", "pgup", "ctrl+u":
		m.scroll -= page
	case "g", "home":
		m.scroll = 0
	case "G", "end":
		m.scroll = lines
	}
	m.scroll = max(0, min(m.scroll, lines-page))
}

// mixedSections lists the sections a mixed round can be over, Custom too
// when it has lessons.
func (m *model) mixedSections() []Section {
	sections := m.catalog.Sections
	if len(m.catalog.InSection("custom")) > 0 {
		sections = append(sections[:len(sections):len(sections)], Section{ID: "custom", Name: "Custom"})
	}
	return sections
}

// mixedLessons is every lesson of the chosen sections, or with none chosen,
// every lesson learned.
func (m *model) mixedLessons() []*Lesson {
	var lessons []*Lesson
	for _, l := range m.catalog.Lessons {
		if len(m.chosen) == 0 && m.items[l.ID].Box > 0 || m.chosen[l.Section] {
			lessons = append(lessons, l)
		}
	}
	return lessons
}

func (m *model) mixedKey(key string) tea.Cmd {
	sections := m.mixedSections()
	switch key {
	case "q", "esc":
		m.view = mapView
	case "j", "down":
		m.mixCursor = min(m.mixCursor+1, len(sections)-1)
	case "k", "up":
		m.mixCursor = max(m.mixCursor-1, 0)
	case "h", "left":
		m.length = max(m.length-1, 0)
	case "l", "right":
		m.length = min(m.length+1, len(lengths)-1)
	case " ", "x":
		id := sections[m.mixCursor].ID
		if m.chosen[id] {
			delete(m.chosen, id)
		} else {
			m.chosen[id] = true
		}
	case "enter":
		if lessons := m.mixedLessons(); len(lessons) > 0 {
			m.view = mapView
			length := lengths[m.length]
			return m.start(Planned{Kind: "mixed", Lessons: lessons, Count: length.count, Limit: length.limit}, false)
		}
	}
	return nil
}

func (m *model) mixedLines() []string {
	lessons := len(m.mixedLessons())
	over := fmt.Sprintf("every learned lesson (%d)", lessons)
	if len(m.chosen) > 0 {
		var names []string
		for _, s := range m.mixedSections() {
			if m.chosen[s.ID] {
				names = append(names, s.Name)
			}
		}
		over = fmt.Sprintf("%s (%d lessons)", strings.Join(names, ", "), lessons)
	} else if lessons == 0 {
		over = "nothing learned yet; choose sections below"
	}
	lines := []string{bold.Render("Mixed practice") + "   goals across lessons, keys hidden, no box moves", "",
		"  Length   ‹ " + lengths[m.length].label + " ›", "  Over     " + truncate(over, 68), ""}
	for i, s := range m.mixedSections() {
		learned, all := 0, m.catalog.InSection(s.ID)
		for _, l := range all {
			if m.items[l.ID].Box > 0 {
				learned++
			}
		}
		mark := map[bool]string{true: "[x]", false: "[ ]"}[m.chosen[s.ID]]
		text := fmt.Sprintf("  %s %s%d of %d learned", mark, pad(s.Name, 22), learned, len(all))
		if i == m.mixCursor {
			text = selected.Render("›" + text[1:])
		}
		lines = append(lines, text)
	}
	return lines
}

// open shows a lesson's page before its round, or starts a lesson without one.
// In a session a page is shown only for a lesson that is still new.
func (m *model) open(p Planned, fromSession bool) tea.Cmd {
	if len(p.Lesson.Page) == 0 || fromSession && m.items[p.Lesson.ID].Box > 0 {
		return m.start(p, fromSession)
	}
	m.view, m.scroll, m.pending, m.fromSession = pageView, 0, p, fromSession
	m.page = p.Lesson.Page
	return nil
}

type roundDone struct {
	planned Planned
	request Request
	before  map[string]bool
	err     error
}

// start writes the round's request and hands the terminal to Vim.
func (m *model) start(p Planned, fromSession bool) tea.Cmd {
	if fromSession {
		m.session = m.session[1:]
	}
	request := Draw(m.catalog, p, m.records)
	before := map[string]bool{}
	for _, r := range Records(m.state) {
		before[r.Name] = true
	}
	path := filepath.Join(m.state, "round.json")
	data, _ := json.Marshal(request)
	err := os.MkdirAll(m.state, 0o700)
	if err == nil {
		err = os.WriteFile(path, data, 0o600)
	}
	if err != nil {
		return func() tea.Msg { return roundDone{p, request, before, err} }
	}
	cmd := exec.Command("vim",
		"-c", "set runtimepath^="+vimEscape(m.catalog.Root),
		"-c", "call vim_dojo#Run("+vimString(path)+")")
	return tea.ExecProcess(cmd, func(err error) tea.Msg { return roundDone{p, request, before, err} })
}

func vimString(s string) string { return "'" + strings.ReplaceAll(s, "'", "''") + "'" }

func vimEscape(s string) string {
	return regexp.MustCompile(`([\\, |"])`).ReplaceAllString(s, `\$1`)
}

// finish reads what the round left in the state directory and says how it
// went. A round left early drops the rest of the session.
func (m *model) finish(done roundDone) {
	os.Remove(filepath.Join(m.state, "round.json"))
	title := done.planned.Title(m.catalog)
	if done.err != nil {
		m.banner = []string{"Could not run Vim for " + title + ": " + done.err.Error()}
		m.session = nil
		m.refresh()
		return
	}
	var round *Record
	counts := map[string]int{}
	placed := 0
	for _, r := range Records(m.state) {
		if done.before[r.Name] {
			continue
		}
		counts[r.Result]++
		switch r.Result {
		case "round":
			round = &r
		case "placed":
			placed++
		}
	}
	finished := counts["clean"] + counts["unclean"] + counts["skipped"]
	if round == nil {
		of := fmt.Sprintf(" of %d", len(done.request.Goals))
		if done.request.Limit > 0 {
			of = ""
		}
		m.banner = []string{fmt.Sprintf("Left %s after %d%s goals, %d clean. Nothing was rescheduled.",
			title, finished, of, counts["clean"])}
		m.session = nil
	} else {
		m.banner = []string{fmt.Sprintf("%s  ·  %d of %d clean  ·  %d:%02d",
			title, round.Clean, round.Goals, round.Seconds/60, round.Seconds%60)}
		if round.Kind != "mixed" {
			m.banner[0] += map[bool]string{true: "  ·  passed", false: "  ·  not passed"}[round.Pass()]
		}
		if placed > 0 {
			m.banner = append(m.banner, fmt.Sprintf("%d %s placed as known.", placed,
				map[bool]string{true: "lesson", false: "lessons"}[placed == 1]))
		}
	}
	if len(m.session) == 0 {
		m.sessionSize = 0
	}
	m.refresh()
}

func (m *model) View() string {
	switch m.view {
	case pageView:
		return m.window(m.pageLines(), faint.Render("Enter start the round · j k scroll · q back"))
	case statsView:
		return m.window(m.statsLines(), faint.Render("j k scroll · q back"))
	case mixedView:
		return m.window(m.mixedLines(), faint.Render("Enter start · Space choose a section · h l length · q back"))
	}
	return m.mapView()
}

// window shows the lines from the scroll position, with a footer, which
// may take several lines.
func (m *model) window(lines []string, footer string) string {
	height := m.bodyHeight(len(lines), footer)
	end := min(len(lines), m.scroll+height)
	shown := lines[min(m.scroll, end):end]
	return strings.Join(shown, "\n") + strings.Repeat("\n", height-len(shown)+1) + footer
}

func (m *model) bodyHeight(lines int, footer string) int {
	if m.height > 1 {
		return max(1, m.height-strings.Count(footer, "\n")-1)
	}
	return lines
}

// The last round's summary stays in view above the legend.
func (m *model) mapView() string {
	footer := faint.Render("○ new  ◐ shaky  ● solid   Enter open · s stats · q quit")
	if len(m.banner) > 0 {
		footer = bold.Render("  "+strings.Join(m.banner, "\n  ")) + "\n" + footer
	}
	height := m.bodyHeight(len(m.rows), footer)
	if m.cursor < m.offset {
		m.offset = m.cursor
	} else if m.cursor >= m.offset+height {
		m.offset = m.cursor - height + 1
	}
	if m.cursor == m.first("session") {
		m.offset = 0
	}
	colour := strings.NewReplacer(symbols[0], levels[0].Render(symbols[0]),
		symbols[1], levels[1].Render(symbols[1]), symbols[2], levels[2].Render(symbols[2]))
	var lines []string
	for i, r := range m.rows {
		switch {
		case i == m.cursor:
			lines = append(lines, selected.Render("›"+strings.TrimPrefix(r.text, " ")))
		case i == 0 || r.kind == "" && r.text != "" && !strings.HasPrefix(r.text, " "):
			lines = append(lines, bold.Render(colourless(r.text))+colourSymbols(r.text, colour))
		default:
			lines = append(lines, colour.Replace(r.text))
		}
	}
	m.scroll = m.offset
	return m.window(lines, footer)
}

// A section row's name is bold and its bar coloured.
func colourless(text string) string {
	if i := strings.IndexAny(text, "○◐●"); i >= 0 {
		return text[:i]
	}
	return text
}

func colourSymbols(text string, colour *strings.Replacer) string {
	if i := strings.IndexAny(text, "○◐●"); i >= 0 {
		return colour.Replace(text[i:])
	}
	return ""
}

var inline = regexp.MustCompile("`[^`]+`")

// pageLines renders a lesson page: headings bold, code blocks indented and
// coloured, inline code coloured, paragraphs wrapped to the window.
func (m *model) pageLines() []string {
	width := 80
	if m.width > 0 {
		width = min(width, m.width)
	}
	var lines []string
	inCode := false
	for _, line := range m.page {
		switch {
		case strings.HasPrefix(line, "```"):
			inCode = !inCode
		case inCode:
			lines = append(lines, code.Render("    "+line))
		case strings.HasPrefix(line, "#"):
			lines = append(lines, bold.Render(strings.TrimLeft(line, "# ")))
		default:
			wrapped := lipgloss.NewStyle().Width(width).Render(line)
			for part := range strings.SplitSeq(wrapped, "\n") {
				part = strings.TrimRight(part, " ")
				lines = append(lines, inline.ReplaceAllStringFunc(part, func(s string) string {
					return code.Render(strings.Trim(s, "`"))
				}))
			}
		}
	}
	return lines
}

// statsLines shows, for each lesson with rounds, the clean count and the
// seconds per goal of its last five learn and review rounds.
func (m *model) statsLines() []string {
	lines := []string{bold.Render("Stats") + "   recent rounds, oldest first: clean of goals, seconds per goal", ""}
	for _, l := range m.catalog.Lessons {
		item := m.items[l.ID]
		if len(item.Recent) == 0 {
			continue
		}
		lines = append(lines, "  "+levels[item.Level()].Render(symbols[item.Level()])+" "+
			pad(truncate(l.Title, 19), 20)+recent(item.Recent))
	}
	var mixed []Record
	for _, r := range m.records {
		if r.Result == "round" && r.Kind == "mixed" {
			mixed = append(mixed, r)
		}
	}
	if len(mixed) > 0 {
		lines = append(lines, "", "  "+pad("Mixed practice", 20)+recent(mixed))
	}
	if len(lines) == 2 {
		lines = append(lines, "  No rounds yet.")
	}
	return lines
}

// recent is the last five rounds: clean of goals, and seconds per goal.
func recent(records []Record) string {
	var rounds []string
	for _, r := range records[max(0, len(records)-5):] {
		rounds = append(rounds, fmt.Sprintf("%d/%d %4.1fs", r.Clean, r.Goals,
			float64(r.Seconds)/float64(max(1, r.Goals))))
	}
	return strings.Join(rounds, "   ")
}
