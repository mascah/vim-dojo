package main

import (
	"fmt"
	"image/color"
	"os"
	"strings"

	"charm.land/lipgloss/v2"
)

const (
	maxWidth = 128 // wider terminals get the shell centred
	twoPanes = 80  // narrower ones show one pane at a time
)

// fill puts the footer on the last line and centres the shell in a wide terminal.
func (m *model) fill(body, footer string) string {
	gap := max(0, m.height-lipgloss.Height(body)-lipgloss.Height(footer))
	out := body + strings.Repeat("\n", gap+1) + footer
	if m.width > maxWidth {
		out = lipgloss.PlaceHorizontal(m.width, lipgloss.Center, lipgloss.NewStyle().Width(maxWidth).Render(out))
	}
	return out
}

// between sets one text at the left of a line and another at its right.
func between(width int, left, right string) string {
	gap := width - lipgloss.Width(left) - lipgloss.Width(right)
	if gap < 1 {
		return lipgloss.NewStyle().MaxWidth(width).Render(left)
	}
	return left + strings.Repeat(" ", gap) + right
}

func (m *model) header(w int, right string, crumbs ...string) string {
	t := m.th
	left := " " + gradient("VIM DOJO", t.accent, t.key)
	for i, c := range crumbs {
		style := t.fg(t.muted)
		if i == len(crumbs)-1 {
			style = lipgloss.NewStyle().Bold(true).Foreground(t.text)
		}
		left += t.fg(t.faint).Render(" › ") + style.Render(c)
	}
	if len(crumbs) == 0 {
		if m.inbox > 0 {
			right = t.fg(t.text).Render(fmt.Sprintf("%d in inbox", m.inbox)) +
				t.fg(t.muted).Render(" · "+tilde(m.inboxDir)+" ")
		}
		// The inbox has to show; the tagline gives way to it.
		if tagline := "  practice in your own Vim"; lipgloss.Width(left+tagline+right) < w {
			left += t.fg(t.muted).Render(tagline)
		}
	}
	return between(w, left, right)
}

func tilde(path string) string {
	if home := os.Getenv("HOME"); home != "" && strings.HasPrefix(path, home+"/") {
		return "~" + path[len(home):]
	}
	return path
}

func (m *model) footer(w int, b bindings, right string) string {
	if m.help.ShowAll {
		m.help.SetWidth(w - 2)
		return lipgloss.NewStyle().PaddingLeft(1).Render(m.help.View(b))
	}
	m.help.SetWidth(w - lipgloss.Width(right) - 3)
	return between(w, " "+m.help.View(b), right+" ")
}

func (m *model) legend() string {
	t := m.th
	var parts []string
	for i, s := range symbols {
		parts = append(parts, t.fg(t.levels[i]).Render(s)+" "+t.fg(t.muted).Render(words[i]))
	}
	return strings.Join(parts, "  ")
}

func plural(n int, one string) string {
	if n == 1 {
		return fmt.Sprintf("%d %s", n, one)
	}
	return fmt.Sprintf("%d %ss", n, one)
}

// homeView is the dashboard: the practice pane and its detail.
func (m *model) homeView() string {
	w := min(m.width, maxWidth)
	b := bindings{named(keys.Down, "j/k", "move"), keys.Right, keys.Open, keys.Mixed, keys.Stats, keys.Help, keys.Quit}
	if m.inDetail {
		b = bindings{named(keys.Down, "j/k", "move"), keys.Left, named(keys.Open, "enter", "start"), keys.Mixed, keys.Stats, keys.Help, keys.Quit}
	}
	if m.help.ShowAll {
		b = bindings{keys.Down, keys.Up, keys.Top, keys.Bottom, keys.Right, keys.Left, keys.Open, keys.Back,
			keys.Mixed, keys.Stats, keys.Help, keys.Quit}
	}
	legend := m.legend()
	if w < 100 {
		legend = ""
	}
	footer := m.footer(w, b, legend)
	parts := []string{m.header(w, "")}
	toast := m.toast(w)
	rest := m.height - 1 - lipgloss.Height(footer)
	if toast != "" {
		rest -= lipgloss.Height(toast)
	}
	rest = max(rest, 4)
	switch {
	case w < twoPanes && m.inDetail:
		parts = append(parts, m.detail(w, rest))
	case w < twoPanes:
		parts = append(parts, m.practice(w, rest))
	default:
		left := 33
		if w >= 96 {
			left = 40
		}
		parts = append(parts, lipgloss.JoinHorizontal(lipgloss.Top, m.practice(left, rest), m.detail(w-left, rest)))
	}
	if toast != "" {
		parts = append(parts, toast)
	}
	return m.fill(strings.Join(parts, "\n"), footer)
}

// passColour is green for a passed round, amber for one not passed, and the
// key colour for a mixed round, which has no pass.
func (m *model) passColour(r Record) color.Color {
	switch {
	case r.Kind == "mixed":
		return m.th.key
	case r.Pass():
		return m.th.solid
	}
	return m.th.shaky
}

// window keeps the cursor's line in view when a pane is shorter than its list.
func window(lines []string, cursor, height int) []string {
	if len(lines) <= height {
		return lines
	}
	from := max(0, min(cursor-height/2, len(lines)-height))
	return lines[from : from+height]
}

// practice is the left pane: the two rounds to start, then the path's sections.
func (m *model) practice(w, h int) string {
	t := m.th
	inner, focused := max(1, w-4), !m.inDetail
	label := "Start today's session"
	if len(m.session) > 0 {
		label = fmt.Sprintf("Next round, %d of %d", m.sessionSize-len(m.session)+1, m.sessionSize)
	}
	action := func(i int, text string) string {
		style := lipgloss.NewStyle().Bold(true).Foreground(t.text)
		if m.left == i {
			style = style.Foreground(t.accent)
		}
		return t.row(inner, m.left == i, focused, cell{"▶ " + text, style, 0})
	}
	lines := []string{action(0, label), action(1, "Mixed practice"), t.fg(t.line).Render(strings.Repeat("─", inner))}
	for i, s := range m.sections() {
		lessons := m.catalog.InSection(s.ID)
		name := t.fg(t.text)
		if m.left == i+2 {
			name = name.Bold(true)
		}
		cells := []cell{{s.Name, name, 21}}
		solid := 0
		for j, l := range lessons {
			level := m.items[l.ID].Level()
			if level == 2 {
				solid++
			}
			if j < 6 {
				cells = append(cells, cell{symbols[level], t.fg(t.levels[level]), 1})
			}
		}
		if inner >= 35 {
			cells = append(cells, cell{"", lipgloss.NewStyle(), max(0, 6-len(lessons))},
				cell{fmt.Sprintf("%3d/%d", solid, len(lessons)), t.fg(t.muted), 6})
		}
		lines = append(lines, t.row(inner, m.left == i+2, focused, cells...))
	}
	cursor := m.left
	if cursor >= 2 {
		cursor++
	}
	return t.card("Practice", "", strings.Join(window(lines, cursor, h-2), "\n"), w, h, focused)
}

func (m *model) detail(w, h int) string {
	switch m.left {
	case 0:
		return m.sessionPane(w, h)
	case 1:
		return m.mixedPane(w, h)
	}
	return m.sectionPane(m.sections()[m.left-2], w, h)
}

// recentCells is a lesson's last rounds as bars, green where the round passed.
func (m *model) recentCells(recent []Record, width int) []cell {
	var cells []cell
	for _, r := range recent[max(0, len(recent)-width):] {
		at := int(float64(r.Clean)/float64(max(1, r.Goals))*float64(len(blocks)-1) + 0.5)
		cells = append(cells, cell{string(blocks[at]), m.th.fg(m.passColour(r)), 1})
	}
	return cells
}

func (t theme) pipCells(box int) []cell {
	level := t.shaky
	if box >= 3 {
		level = t.solid
	}
	return []cell{{strings.Repeat("▰", box), t.fg(level), box}, {strings.Repeat("▱", 5-box), t.fg(t.faint), 7 - box}}
}

// sectionPane lists a section's lessons and its review, each lesson with its
// state and when it is due. Columns join as the pane widens: the state's
// word, the box, the recent rounds. Under the list are the selected lesson's keys.
func (m *model) sectionPane(s Section, w, h int) string {
	t := m.th
	inner, today := max(1, w-4), m.today()
	lessons := m.catalog.InSection(s.ID)
	rule := t.fg(t.line).Render(strings.Repeat("─", inner))
	var lines []string
	solid := 0
	for i, l := range lessons {
		item := m.items[l.ID]
		level := item.Level()
		if level == 2 {
			solid++
		}
		selected := m.inDetail && m.right == i
		title := t.fg(t.text)
		if selected {
			title = title.Bold(true)
		}
		cells := []cell{{symbols[level], t.fg(t.levels[level]), 2}, {l.Title, title, 19}}
		if inner >= 43 {
			cells = append(cells, cell{words[level], t.fg(t.levels[level]), 6})
		}
		if inner >= 52 {
			cells = append(cells, t.pipCells(item.Box)...)
		}
		when := t.fg(t.muted)
		if item.Box > 0 && item.Due <= today {
			when = t.fg(t.shaky)
		}
		cells = append(cells, cell{due(item, today), when, 15})
		if inner >= 62 {
			cells = append(cells, m.recentCells(item.Recent, 8)...)
		}
		lines = append(lines, t.row(inner, selected, m.inDetail, cells...))
	}
	review := m.inDetail && m.right == len(lessons)
	if s.ID != "custom" {
		style := t.fg(t.text)
		if review {
			style = style.Bold(true).Foreground(t.accent)
		}
		lines = append(lines, t.row(inner, review, m.inDetail, cell{"▷ Review " + s.Name, style, 0},
			cell{"   20 goals, keys hidden", t.fg(t.muted), 0}))
	}
	lines = window(lines, m.right, h-2)
	if rest := h - 2 - len(lines); rest >= 3 {
		lines = append(lines, rule)
		note := t.fg(t.muted).Width(inner)
		switch {
		case !m.inDetail:
			lines = append(lines, t.fg(t.faint).Render("  l or Enter for these lessons"))
		case review:
			lines = append(lines, note.Render("Twenty goals drawn evenly from this section's lessons, with the keys "+
				"hidden. Passing it places the section's new lessons as known."))
		default:
			wide := 0
			for _, k := range lessons[m.right].Keys {
				wide = min(max(wide, lipgloss.Width(k[0])), 14)
			}
			for _, k := range lessons[m.right].Keys[:min(len(lessons[m.right].Keys), rest-1)] {
				lines = append(lines, "  "+t.fg(t.key).Render(pad(truncate(k[0], wide), wide))+"  "+
					t.fg(t.muted).Render(truncate(k[1], inner-wide-4)))
			}
		}
	}
	return t.card(s.Name, fmt.Sprintf("%d of %d solid", solid, len(lessons)), strings.Join(lines, "\n"), w, h, m.inDetail)
}

// sessionPane is today's session round by round: what is next and what is
// still to come.
func (m *model) sessionPane(w, h int) string {
	t := m.th
	inner, today := max(1, w-4), m.today()
	plan := m.plan()
	lines := []string{""}
	for i, p := range plan {
		item := m.items[p.Lesson.ID]
		mark, style := "·", t.fg(t.faint)
		state, more := t.fg(t.levels[item.Level()]).Render(symbols[item.Level()]+" "+words[item.Level()]), " · "+due(item, today)
		switch {
		case item.Box == 0 && len(p.Lesson.Page) > 0:
			more = " · opens on its page"
		case item.Box == 0:
			more = ""
		}
		if lipgloss.Width(state+more) <= inner-31 {
			state += t.fg(t.muted).Render(more)
		}
		if i == 0 {
			mark, style = "▶", t.fg(t.accent).Bold(true)
		}
		lines = append(lines, " "+style.Render(mark)+" "+t.fg(t.muted).Render(pad(p.Kind, 7))+
			lipgloss.NewStyle().Bold(i == 0).Foreground(t.text).Render(pad(truncate(p.Lesson.Title, 19), 20))+state)
	}
	hint := "A session reviews up to three due lessons, oldest first, then teaches the next new one. " +
		"Eight clean goals of ten pass a round."
	if len(m.records) == 0 {
		hint = "New here? Pass a section's review to skip it, or press Enter to begin."
	}
	lines = append(lines, "", t.fg(t.faint).Width(inner).PaddingLeft(1).Render(hint))
	note := plural(len(plan), "round")
	if len(m.session) > 0 {
		note = fmt.Sprintf("round %d of %d", m.sessionSize-len(m.session)+1, m.sessionSize)
	}
	return t.card("Today's session", note, strings.Join(lines, "\n"), w, h, false)
}

func (m *model) mixedPane(w, h int) string {
	t := m.th
	body := t.fg(t.muted).Width(w-4).PaddingLeft(1).Render("Goals drawn across the lessons you have learned, leaning toward "+
		"due and shaky ones, with the keys hidden. A mixed round moves no lesson's box.") + "\n\n" +
		" " + t.fg(t.muted).Render("Length  ") + t.fg(t.text).Render(lengths[m.length].label) + "\n" +
		" " + t.fg(t.muted).Render("Over    ") + t.fg(t.text).Render(m.over()) + "\n\n" +
		t.fg(t.faint).Render(" Enter to choose a length and sections")
	return t.card("Mixed practice", "", "\n"+body, w, h, false)
}

func (m *model) over() string {
	n := len(m.mixedLessons())
	if len(m.chosen) == 0 {
		if n == 0 {
			return "nothing learned yet; choose sections"
		}
		return fmt.Sprintf("every learned lesson (%d)", n)
	}
	var names []string
	for _, s := range m.sections() {
		if m.chosen[s.ID] {
			names = append(names, s.Name)
		}
	}
	return fmt.Sprintf("%s (%s)", strings.Join(names, ", "), plural(n, "lesson"))
}

// toast is the last round's summary above the footer.
func (m *model) toast(w int) string {
	if len(m.banner) == 0 {
		return ""
	}
	return lipgloss.NewStyle().Bold(true).Foreground(m.th.text).MaxWidth(w).Render("  " + strings.Join(m.banner, "\n  "))
}
