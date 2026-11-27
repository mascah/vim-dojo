package main

import (
	"image/color"
	"strings"

	"charm.land/bubbles/v2/help"
	"charm.land/bubbles/v2/progress"
	"charm.land/lipgloss/v2"
	xansi "github.com/charmbracelet/x/ansi"
)

// theme is every colour the shell uses, chosen for the terminal's background.
type theme struct {
	dark                                      bool
	text, muted, faint, line, surface         color.Color
	accent, key, solid, shaky, fail, onAccent color.Color
	levels                                    [3]color.Color // new, shaky, solid
	heat                                      []color.Color  // activity, none to most
	hex                                       map[string]string
}

func newTheme(dark bool) theme {
	pick := func(light, dark_ string) string {
		if dark {
			return dark_
		}
		return light
	}
	hex := map[string]string{
		"text":    pick("#24292F", "#D5D9E3"),
		"muted":   pick("#57606A", "#8E97AD"),
		"faint":   pick("#A7AFBA", "#565F7A"),
		"line":    pick("#D0D7DE", "#343A52"),
		"surface": pick("#E9ECF2", "#262B40"),
		"accent":  pick("#7C3AED", "#B794F6"),
		"key":     pick("#0B6FBF", "#7DCFFF"),
		"solid":   pick("#1A7F37", "#9ECE6A"),
		"shaky":   pick("#9A6700", "#E0AF68"),
		"fail":    pick("#CF222E", "#F7768E"),
		"on":      pick("#FFFFFF", "#16161E"),
	}
	c := func(name string) color.Color { return lipgloss.Color(hex[name]) }
	t := theme{dark: dark, hex: hex, text: c("text"), muted: c("muted"), faint: c("faint"), line: c("line"),
		surface: c("surface"), accent: c("accent"), key: c("key"), solid: c("solid"), shaky: c("shaky"),
		fail: c("fail"), onAccent: c("on")}
	t.levels = [3]color.Color{t.faint, t.shaky, t.solid}
	t.heat = lipgloss.Blend1D(5, t.line, t.solid)
	return t
}

func (t theme) fg(c color.Color) lipgloss.Style { return lipgloss.NewStyle().Foreground(c) }

// gradient colours each rune of the text along a blend.
func gradient(text string, stops ...color.Color) string {
	runes := []rune(text)
	blend := lipgloss.Blend1D(len(runes), stops...)
	var b strings.Builder
	for i, r := range runes {
		b.WriteString(lipgloss.NewStyle().Bold(true).Foreground(blend[i]).Render(string(r)))
	}
	return b.String()
}

// card is a rounded box with its title set into the top border, and a note
// at the right of it. Width and height are the outer size.
func (t theme) card(title, note, body string, width, height int, focused bool) string {
	edge := t.line
	head := t.fg(t.muted)
	if focused {
		edge, head = t.accent, t.fg(t.accent).Bold(true)
	}
	lines := strings.Split(body, "\n")
	for i, l := range lines {
		lines[i] = xansi.Truncate(l, width-4, "…") // a line too long is cut, never wrapped
	}
	body = strings.Join(lines, "\n")
	box := lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderTop(false).BorderForeground(edge).
		Padding(0, 1).Width(width).Height(height - 1).MaxHeight(height - 1).Render(body)
	line := t.fg(edge)
	if note != "" {
		note = " " + note + " "
	}
	title = truncate(title, max(1, width-6))
	if lipgloss.Width(title)+lipgloss.Width(note) > width-6 {
		note = ""
	}
	fill := max(0, width-5-lipgloss.Width(title)-lipgloss.Width(note)-1)
	top := line.Render("╭─ ") + head.Render(title) + line.Render(" "+strings.Repeat("─", fill)) +
		t.fg(t.muted).Render(note) + line.Render("─╮")
	return top + "\n" + box
}

// cell is one column of a row: text, its style, and the width it is padded to.
type cell struct {
	text  string
	style lipgloss.Style
	width int
}

// row joins cells. A selected row in the focused pane takes the surface
// colour across its whole width, which each cell has to carry itself: an
// outer background stops at the first inner reset.
func (t theme) row(width int, selected, focused bool, cells ...cell) string {
	mark := "  "
	if selected {
		mark = "› "
	}
	cells = append([]cell{{mark, t.fg(t.accent).Bold(true), 2}}, cells...)
	var b strings.Builder
	used := 0
	for _, c := range cells {
		style := c.style
		if selected && focused {
			style = style.Background(t.surface)
		}
		text := c.text
		if c.width > 0 {
			text = pad(truncate(text, c.width), c.width)
		}
		used += lipgloss.Width(text)
		b.WriteString(style.Render(text))
	}
	if rest := width - used; rest > 0 {
		fill := lipgloss.NewStyle()
		if selected && focused {
			fill = fill.Background(t.surface)
		}
		b.WriteString(fill.Render(strings.Repeat(" ", rest)))
	}
	return b.String()
}

func pad(text string, width int) string {
	return text + strings.Repeat(" ", max(0, width-lipgloss.Width(text)))
}

func truncate(text string, width int) string {
	if runes := []rune(text); len(runes) > width && width > 0 {
		return string(runes[:width-1]) + "…"
	}
	return text
}

var (
	symbols = []string{"○", "◐", "●"}
	words   = []string{"new", "shaky", "solid"}
	blocks  = []rune("▁▂▃▄▅▆▇█")
)

// spark draws values from 0 to 1 as a row of bars, each in its own colour.
func spark(values []float64, colours []color.Color) string {
	var b strings.Builder
	for i, v := range values {
		at := int(v*float64(len(blocks)-1) + 0.5)
		b.WriteString(lipgloss.NewStyle().Foreground(colours[i]).Render(string(blocks[max(0, min(at, len(blocks)-1))])))
	}
	return b.String()
}

// pips shows a lesson's box out of five.
func (t theme) pips(box int) string {
	if box == 0 {
		return t.fg(t.faint).Render("▱▱▱▱▱")
	}
	level := t.shaky
	if box >= 3 {
		level = t.solid
	}
	return t.fg(level).Render(strings.Repeat("▰", box)) + t.fg(t.faint).Render(strings.Repeat("▱", 5-box))
}

// bar is a progress bar of the given width, filled to a fraction, in a blend.
func (t theme) bar(width int, fraction float64, stops ...color.Color) string {
	p := progress.New(progress.WithWidth(width), progress.WithoutPercentage(), progress.WithColors(stops...),
		progress.WithFillCharacters('━', '━'), progress.WithScaled(true))
	p.EmptyColor = t.line
	return p.ViewAs(max(0, min(fraction, 1)))
}

func (t theme) help() help.Styles {
	key, desc, sep := t.fg(t.key), t.fg(t.muted), t.fg(t.faint)
	return help.Styles{ShortKey: key, ShortDesc: desc, ShortSeparator: sep, Ellipsis: sep,
		FullKey: key, FullDesc: desc, FullSeparator: sep}
}
