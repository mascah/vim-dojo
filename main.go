// Command dojo is Vim Dojo's shell: the dashboard, lesson pages, and stats.
// A round runs in the learner's own Vim, which the shell starts on a request
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

	"charm.land/bubbles/v2/help"
	"charm.land/bubbles/v2/key"
	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

var (
	bold     = lipgloss.NewStyle().Bold(true)
	faint    = lipgloss.NewStyle().Faint(true)
	selected = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("5"))
)

func main() {
	root, err := pluginRoot()
	if err == nil {
		var c *Catalog
		if c, err = Load(root, drillDir()); err == nil {
			_, err = tea.NewProgram(newModel(c, stateDir())).Run()
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

type screen int

const (
	homeScreen screen = iota
	pageScreen
	statsScreen
)

// The lengths a mixed round can have: a number of goals, or minutes.
var lengths = []struct {
	label        string
	count, limit int
}{{"10 goals", 10, 0}, {"20 goals", 20, 0}, {"40 goals", 40, 0},
	{"2 minutes", 0, 120}, {"5 minutes", 0, 300}, {"10 minutes", 0, 600}}

const defaultLength = 1

type model struct {
	catalog       *Catalog
	state         string
	records       []Record
	items         map[string]*Item
	inboxDir      string
	inbox         int
	th            theme
	help          help.Model
	width, height int
	screen        screen
	left, right   int  // the row in the practice pane and in the detail pane
	inDetail      bool // the detail pane has the focus
	dialog        bool // mixed practice's setup is open
	page, stats   viewport.Model
	pending       Planned // the round a page starts
	fromSession   bool
	session       []Planned // the rest of today's session once it has started
	sessionSize   int
	banner        []string
	length        int             // the mixed round's, in lengths
	chosen        map[string]bool // the sections a mixed round is over
	mixCursor     int
}

func newModel(c *Catalog, state string) *model {
	m := &model{catalog: c, state: state, th: newTheme(true), help: help.New(),
		chosen: map[string]bool{}, length: defaultLength}
	m.help.Styles = m.th.help()
	m.refresh()
	return m
}

func (m *model) Init() tea.Cmd { return tea.RequestBackgroundColor }

// refresh rereads the records and the inbox.
func (m *model) refresh() {
	m.records = Records(m.state)
	m.items = State(m.catalog, m.records)
	m.inboxDir, m.inbox = Inbox(m.state)
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

// sections lists the sections of the path, Custom too when it has lessons.
func (m *model) sections() []Section {
	sections := m.catalog.Sections
	if len(m.catalog.InSection("custom")) > 0 {
		sections = append(sections[:len(sections):len(sections)], Section{ID: "custom", Name: "Custom"})
	}
	return sections
}

// detailRows is how many rows of the detail pane can be selected.
func (m *model) detailRows() int {
	if m.left < 2 {
		return 0
	}
	s := m.sections()[m.left-2]
	n := len(m.catalog.InSection(s.ID))
	if s.ID != "custom" {
		n++ // the section review
	}
	return n
}

func (m *model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.layout()
	case tea.BackgroundColorMsg:
		m.th = newTheme(msg.IsDark())
		m.help.Styles = m.th.help()
		m.layout()
	case roundDone:
		m.finish(msg)
	case tea.KeyPressMsg:
		if msg.String() == "ctrl+c" {
			return m, tea.Quit
		}
		switch {
		case m.dialog:
			return m, m.dialogKey(msg)
		case m.screen == pageScreen:
			return m, m.pageKey(msg)
		case m.screen == statsScreen:
			return m, m.statsKey(msg)
		default:
			return m, m.homeKey(msg)
		}
	}
	return m, nil
}

func (m *model) homeKey(msg tea.KeyPressMsg) tea.Cmd {
	rows := 2 + len(m.sections())
	switch {
	case key.Matches(msg, keys.Quit):
		return tea.Quit
	case key.Matches(msg, keys.Help):
		m.help.ShowAll = !m.help.ShowAll
	case key.Matches(msg, keys.Stats):
		m.screen = statsScreen
		m.layout()
		m.stats.GotoTop()
	case key.Matches(msg, keys.Mixed):
		m.dialog = true
	case key.Matches(msg, keys.Back), key.Matches(msg, keys.Left):
		m.inDetail = false
	case key.Matches(msg, keys.Down) && m.inDetail:
		m.right = min(m.right+1, m.detailRows()-1)
	case key.Matches(msg, keys.Up) && m.inDetail:
		m.right = max(m.right-1, 0)
	case key.Matches(msg, keys.Top) && m.inDetail:
		m.right = 0
	case key.Matches(msg, keys.Bottom) && m.inDetail:
		m.right = m.detailRows() - 1
	case key.Matches(msg, keys.Down):
		m.left, m.right = min(m.left+1, rows-1), 0
	case key.Matches(msg, keys.Up):
		m.left, m.right = max(m.left-1, 0), 0
	case key.Matches(msg, keys.Top):
		m.left, m.right = 0, 0
	case key.Matches(msg, keys.Bottom):
		m.left, m.right = rows-1, 0
	case key.Matches(msg, keys.Right), key.Matches(msg, keys.Open):
		return m.open(key.Matches(msg, keys.Open))
	}
	return nil
}

// open acts on the selected row: into a section's lessons, or with Enter, on
// with the round the row stands for.
func (m *model) open(enter bool) tea.Cmd {
	switch {
	case m.left >= 2 && !m.inDetail:
		m.inDetail = true
	case !enter:
	case m.left == 0:
		if len(m.session) == 0 {
			m.session = m.plan()
			m.sessionSize = len(m.session)
		}
		if len(m.session) > 0 {
			return m.before(m.session[0], true)
		}
	case m.left == 1:
		m.dialog = true
	default:
		s := m.sections()[m.left-2]
		lessons := m.catalog.InSection(s.ID)
		if m.right == len(lessons) {
			return m.start(Planned{Kind: "section", Section: s.ID}, false)
		}
		l, kind := lessons[m.right], "review"
		if m.items[l.ID].Box == 0 {
			kind = "learn"
		}
		return m.before(Planned{Kind: kind, Lesson: l}, false)
	}
	return nil
}

func (m *model) pageKey(msg tea.KeyPressMsg) tea.Cmd {
	switch {
	case key.Matches(msg, keys.Open):
		m.screen = homeScreen
		return m.start(m.pending, m.fromSession)
	case key.Matches(msg, keys.Quit), key.Matches(msg, keys.Back):
		m.screen = homeScreen
	case key.Matches(msg, keys.Top):
		m.page.GotoTop()
	case key.Matches(msg, keys.Bottom):
		m.page.GotoBottom()
	default:
		m.page, _ = m.page.Update(msg)
	}
	return nil
}

func (m *model) statsKey(msg tea.KeyPressMsg) tea.Cmd {
	switch {
	case key.Matches(msg, keys.Quit), key.Matches(msg, keys.Back), key.Matches(msg, keys.Stats):
		m.screen = homeScreen
	case key.Matches(msg, keys.Top):
		m.stats.GotoTop()
	case key.Matches(msg, keys.Bottom):
		m.stats.GotoBottom()
	default:
		m.stats, _ = m.stats.Update(msg)
	}
	return nil
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

func (m *model) dialogKey(msg tea.KeyPressMsg) tea.Cmd {
	sections := m.sections()
	switch {
	case key.Matches(msg, keys.Quit), key.Matches(msg, keys.Back), key.Matches(msg, keys.Mixed):
		m.dialog = false
	case key.Matches(msg, keys.Down):
		m.mixCursor = min(m.mixCursor+1, len(sections)-1)
	case key.Matches(msg, keys.Up):
		m.mixCursor = max(m.mixCursor-1, 0)
	case key.Matches(msg, keys.Left):
		m.length = max(m.length-1, 0)
	case key.Matches(msg, keys.Right):
		m.length = min(m.length+1, len(lengths)-1)
	case key.Matches(msg, keys.Toggle):
		if id := sections[m.mixCursor].ID; m.chosen[id] {
			delete(m.chosen, id)
		} else {
			m.chosen[id] = true
		}
	case key.Matches(msg, keys.Open):
		if lessons := m.mixedLessons(); len(lessons) > 0 {
			m.dialog = false
			length := lengths[m.length]
			return m.start(Planned{Kind: "mixed", Lessons: lessons, Count: length.count, Limit: length.limit}, false)
		}
	}
	return nil
}

func (m *model) mixedLines() []string {
	lines := []string{bold.Render("Mixed practice") + "   goals across lessons, keys hidden, no box moves", "",
		"  Length   ‹ " + lengths[m.length].label + " ›", "  Over     " + truncate(m.over(), 68), ""}
	for i, s := range m.sections() {
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

// before shows a lesson's page ahead of its round, or starts a lesson without
// one. In a session only a new lesson opens on its page.
func (m *model) before(p Planned, fromSession bool) tea.Cmd {
	if len(p.Lesson.Page) == 0 || fromSession && m.items[p.Lesson.ID].Box > 0 {
		return m.start(p, fromSession)
	}
	m.screen, m.pending, m.fromSession = pageScreen, p, fromSession
	m.layout()
	m.page.GotoTop()
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
	} else {
		// A round outside the session can change what the session should be.
		m.session = nil
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
		"-c", "runtime plugin/vim_dojo.vim", // :DojoNote, if not installed as a package
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
		of := fmt.Sprintf(" of %d", max(done.request.Count, len(done.request.Goals)))
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

func (m *model) View() tea.View {
	// Bubble Tea draws once before it knows the window's size, and tests
	// draw without ever sending one.
	if m.width == 0 {
		m.width, m.height = 80, 24
		m.layout()
	}
	var content string
	switch {
	case m.screen == pageScreen:
		content = m.pageView()
	case m.screen == statsScreen:
		content = m.statsView()
	case m.dialog:
		content = m.window(m.mixedLines(), faint.Render("Enter start · Space choose a section · h l length · q back"))
	default:
		content = m.homeView()
	}
	// Whatever a screen drew, nothing reaches past the window.
	v := tea.NewView(lipgloss.NewStyle().MaxWidth(m.width).MaxHeight(m.height).Render(content))
	v.AltScreen = true
	v.WindowTitle = "Vim Dojo"
	return v
}

// window shows the first lines that fit, with a footer, which may take
// several lines.
func (m *model) window(lines []string, footer string) string {
	height := m.bodyHeight(len(lines), footer)
	shown := lines[:min(len(lines), height)]
	return strings.Join(shown, "\n") + strings.Repeat("\n", height-len(shown)+1) + footer
}

func (m *model) bodyHeight(lines int, footer string) int {
	if m.height > 1 {
		return max(1, m.height-strings.Count(footer, "\n")-1)
	}
	return lines
}

// keys are the shell's bindings, which the help line reads its text from.
var keys = struct {
	Up, Down, Left, Right, Top, Bottom, Open, Toggle, Mixed, Stats, Help, Back, Quit key.Binding
}{
	Up:     key.NewBinding(key.WithKeys("k", "up"), key.WithHelp("k", "up")),
	Down:   key.NewBinding(key.WithKeys("j", "down"), key.WithHelp("j", "down")),
	Left:   key.NewBinding(key.WithKeys("h", "left"), key.WithHelp("h", "back")),
	Right:  key.NewBinding(key.WithKeys("l", "right"), key.WithHelp("l", "lessons")),
	Top:    key.NewBinding(key.WithKeys("g", "home"), key.WithHelp("g", "top")),
	Bottom: key.NewBinding(key.WithKeys("G", "end"), key.WithHelp("G", "bottom")),
	Open:   key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "open")),
	Toggle: key.NewBinding(key.WithKeys("space", "x"), key.WithHelp("space", "choose")),
	Mixed:  key.NewBinding(key.WithKeys("m"), key.WithHelp("m", "mixed")),
	Stats:  key.NewBinding(key.WithKeys("s"), key.WithHelp("s", "stats")),
	Help:   key.NewBinding(key.WithKeys("?"), key.WithHelp("?", "help")),
	Back:   key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "back")),
	Quit:   key.NewBinding(key.WithKeys("q"), key.WithHelp("q", "quit")),
}

// bindings is a help.KeyMap: one line of keys, or with ? columns of four.
type bindings []key.Binding

func (b bindings) ShortHelp() []key.Binding { return b }

func (b bindings) FullHelp() [][]key.Binding {
	var columns [][]key.Binding
	for i := 0; i < len(b); i += 4 {
		columns = append(columns, b[i:min(i+4, len(b))])
	}
	return columns
}

// named is a binding under other help text.
func named(b key.Binding, keys, text string) key.Binding {
	b.SetHelp(keys, text)
	return b
}
