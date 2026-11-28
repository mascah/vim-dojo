// Command dojo is Vim Dojo's shell: the dashboard, lesson pages, and stats.
// A round runs in the learner's own Vim, which the shell starts on a request
// file in the state directory and reads the records of when Vim exits.
package main

import (
	"encoding/json"
	"fmt"
	"math"
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
	"github.com/charmbracelet/harmonica"
)

// version is set by the release build with -ldflags -X.
var version = "dev"

func main() {
	if len(os.Args) == 2 && os.Args[1] == "version" {
		fmt.Println("dojo", version)
		return
	}
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
}{{"10", 10, 0}, {"20", 20, 0}, {"40", 40, 0}, {"2", 0, 120}, {"5", 0, 300}, {"10", 0, 600}}

const defaultLength = 1

// result is how a round went, for the line above the footer and the session
// pane. A round that did not end has its sentence in note.
type result struct {
	title, note          string
	kind                 string
	clean, goals         int
	seconds              int64
	passed, left, failed bool
}

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
	session       []Planned // today's session once started
	done          []result  // its finished rounds
	last          *result
	length        int             // the mixed round's, in lengths
	chosen        map[string]bool // the sections a mixed round is over
	mixCursor     int
	spring        harmonica.Spring
	pos, vel      float64 // bars grow from 0 to 1 when the dashboard appears
}

func newModel(c *Catalog, state string) *model {
	m := &model{catalog: c, state: state, th: newTheme(true), help: help.New(),
		chosen: map[string]bool{}, length: defaultLength, spring: harmonica.NewSpring(harmonica.FPS(60), 7, 0.8)}
	m.help.Styles = m.th.help()
	m.refresh()
	return m
}

type frameMsg struct{}

func frame() tea.Cmd {
	return tea.Tick(time.Second/60, func(time.Time) tea.Msg { return frameMsg{} })
}

func (m *model) Init() tea.Cmd { return tea.Batch(tea.RequestBackgroundColor, frame()) }

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
	case frameMsg:
		m.pos, m.vel = m.spring.Update(m.pos, m.vel, 1)
		if math.Abs(1-m.pos) > 0.002 || math.Abs(m.vel) > 0.002 {
			return m, frame()
		}
		m.pos, m.vel = 1, 0
	case roundDone:
		m.finish(msg)
		return m, frame()
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
		// Stats are drawn once, so their bars start full.
		m.screen, m.pos, m.vel = statsScreen, 1, 0
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
			m.session, m.done = m.plan(), nil
		}
		if len(m.session) > len(m.done) {
			return m.before(m.session[len(m.done)], true)
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
	planned     Planned
	request     Request
	before      map[string]bool
	fromSession bool
	err         error
}

// start writes the round's request and hands the terminal to Vim.
func (m *model) start(p Planned, fromSession bool) tea.Cmd {
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
		return func() tea.Msg { return roundDone{p, request, before, fromSession, err} }
	}
	cmd := exec.Command("vim",
		"-c", "set runtimepath^="+vimEscape(m.catalog.Root),
		"-c", "runtime plugin/vim_dojo.vim", // :DojoNote, if not installed as a package
		"-c", "call vim_dojo#Run("+vimString(path)+")")
	return tea.ExecProcess(cmd, func(err error) tea.Msg { return roundDone{p, request, before, fromSession, err} })
}

func vimString(s string) string { return "'" + strings.ReplaceAll(s, "'", "''") + "'" }

func vimEscape(s string) string {
	return regexp.MustCompile(`([\\, |"])`).ReplaceAllString(s, `\$1`)
}

// finish reads what the round left in the state directory and says how it
// went. The session goes on only after a round of its own that ended; one
// left early, one Vim could not run, or one outside it ends it, since a round
// outside it can change what it should be.
func (m *model) finish(done roundDone) {
	os.Remove(filepath.Join(m.state, "round.json"))
	p := done.planned
	title := p.Title(m.catalog)
	res := result{title: title, kind: p.Kind}
	// The lesson as it was, to say what the round did to it.
	var was Item
	if p.Lesson != nil {
		was = *m.items[p.Lesson.ID]
	}
	var round *Record
	counts := map[string]int{}
	placed := 0
	for _, r := range Records(m.state) {
		if done.err != nil || done.before[r.Name] {
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
	switch {
	case done.err != nil:
		res.failed, res.note = true, "Could not run Vim for "+title+": "+done.err.Error()
	case round == nil:
		finished := counts["clean"] + counts["unclean"] + counts["skipped"]
		of := fmt.Sprintf(" of %d", max(done.request.Count, len(done.request.Goals)))
		if done.request.Limit > 0 {
			of = ""
		}
		res.left, res.note = true, fmt.Sprintf("Left %s after %d%s goals, %d clean. Nothing was rescheduled.",
			title, finished, of, counts["clean"])
	default:
		res.clean, res.goals, res.seconds, res.passed = round.Clean, round.Goals, round.Seconds, round.Pass()
	}
	m.refresh()
	switch {
	case round != nil && placed > 0:
		res.note = plural(placed, "lesson") + " placed as known"
	case round != nil && p.Lesson != nil && p.Kind != "mixed":
		res.note = moved(was, *m.items[p.Lesson.ID], m.today())
	}
	m.last = &res
	if done.fromSession && round != nil {
		if m.done = append(m.done, res); len(m.done) == len(m.session) {
			m.session, m.done = nil, nil
		}
	} else {
		m.session, m.done = nil, nil
	}
	m.pos, m.vel = 0, 0
}

// moved says what a round did to its lesson's place in review.
func moved(was, now Item, today int64) string {
	when := due(&now, today)
	switch {
	case now.Box == 0:
		return "still new"
	case was.Box == 0:
		return "now shaky · " + when
	case now.Box > was.Box:
		return fmt.Sprintf("box %d → %d · %s", was.Box, now.Box, when)
	case now.Box < was.Box:
		return fmt.Sprintf("back to box 1 · %s", when)
	}
	return when
}

func (m *model) View() tea.View {
	// Bubble Tea draws once before it knows the window's size, and tests
	// draw without ever sending one.
	if m.width == 0 {
		m.width, m.height = 80, 24
		m.layout()
	}
	var content string
	switch m.screen {
	case pageScreen:
		content = m.pageView()
	case statsScreen:
		content = m.statsView()
	default:
		content = m.homeView()
		if m.dialog {
			content = m.overlay(content, m.dialogView())
		}
	}
	// Whatever a screen drew, nothing reaches past the window.
	v := tea.NewView(lipgloss.NewStyle().MaxWidth(m.width).MaxHeight(m.height).Render(content))
	v.AltScreen = true
	v.WindowTitle = "Vim Dojo"
	return v
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
