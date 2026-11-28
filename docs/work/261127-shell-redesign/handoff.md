# Handoff: the shell on the Charm v2 stack, with a dashboard

Status: delivered. Designed and prototyped on 2026-11-27 and implemented the
same day, a commit a slice; the prototype and its screenshots were deleted in
the last slice, so the paths to them below no longer exist.

## The job

Rebuild the look of the Go shell (`main.go`) on Bubble Tea v2, Lip Gloss v2,
Bubbles v2, Glamour v2, and Harmonica. The map becomes a dashboard, lesson
pages are rendered by Glamour, mixed practice opens in a dialog over the
dashboard, and stats become a full screen of the same panels.

What the shell does is not changing: scheduling, the session plan, how a
round is drawn, the request file, how Vim is started, how records are read.
Only how it is shown and how the cursor moves around it.

A working prototype of every screen is in `prototype/`. It runs on the real
`Catalog`, `Item`, and `Record` types, so most of its drawing code moves into
the shell as it is. **Port the prototype; do not design again.** Where this
file and the prototype disagree, this file wins; where this file is silent,
the prototype is the answer.

## Read first, in this order

1. `main.go`, `dojo.go`, `dojo_test.go` at the repository root: the shell today.
2. `docs/work/261127-shell-redesign/prototype/`: `theme.go`, `views.go`,
   `main.go`, `metrics.go`, `proto_test.go`. `dojo.go` there is a link to the
   real one.
3. `docs/work/261127-shell-redesign/shots/*.png`: what each screen looks like
   in colour. `before-*.png` is the shell today.
4. The upgrade guides, which ship with the modules. They are the truth about
   the v2 APIs; prefer them and `go doc` to memory, since most of what you
   remember is v1:

   ```sh
   cd docs/work/261127-shell-redesign/prototype
   ls $(go env GOMODCACHE)/charm.land/{bubbletea,lipgloss,bubbles,glamour}/v2@*/UPGRADE_GUIDE_V2.md
   go doc charm.land/bubbles/v2/viewport
   ```

See it running:

```sh
cd docs/work/261127-shell-redesign/prototype
go run .                               # the dashboard on made-up records
go run . -fresh                        # as a new learner sees it
go run . -light                        # the light theme
go run . -snap 80x24                   # print one frame and exit
go run . -snap 100x30 -keys "j j j l"  # the same after some keys
go test .                              # every screen at every size
```

`-snap` prints a frame with its colours; pipe it through
`sed 's/\x1b\[[0-9;:]*m//g'` for plain text to compare your own output with.
Enter on a round in the prototype pretends the round was played; it starts
no Vim and writes nothing.

## Decided

- **The v2 line of all four libraries.** `charm.land/bubbletea/v2` v2.2.0,
  `charm.land/lipgloss/v2` v2.1.1, `charm.land/bubbles/v2` v2.2.2,
  `charm.land/glamour/v2` v2.0.1, with `github.com/charmbracelet/harmonica`
  v0.2.0 and `github.com/charmbracelet/x/ansi`. Lip Gloss v2 has what the
  design leans on: layers for the dialog, colour blends, blended borders. The
  prototype's `go.mod` has the exact set; the shell's direct dependencies
  become those six and no others.
- **This supersedes two lines of the v3 spec**: the constraint that the
  shell's only dependencies are Bubble Tea and Lip Gloss, and the decision
  that lesson pages are rendered without a Markdown library. Leave the v3
  spec as it is; this file records the change.
- **A dashboard over one long list.** Sections on the left, the selected
  section's lessons on the right. Eleven sections fit any window; the list of
  75 rows did not.
- **Colours are the shell's own**, in a dark and a light set picked from the
  terminal's background, not the terminal's 16. Bubble Tea downsamples them
  for terminals with fewer colours.
- **Motion is bars only.** One spring fills the bars when the dashboard
  appears and after each round. Text never animates and nothing waits on it.
- **The binary grows** from about 5 MB to about 15 MB, which is Glamour's
  syntax highlighter. Startup stays near 10 ms. Accepted.

## Not changing

- Everything in `dojo.go`, apart from the five small functions added from
  `prototype/metrics.go`.
- `start` and the Vim command line, `round.json`, the environment variables,
  `pluginRoot`, `stateDir`, `drillDir`.
- What `finish` works out from the records. Only what it stores for display
  changes.
- The session's rules: a round left early ends it, a round started outside it
  resets it, and only a new lesson opens on its page inside it.
- The symbols `○ ◐ ●` and the words new, shaky, solid.
- The Vim runner, the lessons, the snippets, `test/dojo.vim`.

## The screens

Reference frames are from the prototype. Yours should match them in
structure; counts and dates will differ.

### Dashboard, 80 by 24

```
 VIM DOJO  practice in your own Vim  1 in inbox · ~/.local/state/vim-dojo/inbox
╭─ Due today ──────╮╭─ Streak ─────────╮╭─ Solid ──────────╮╭─ This week ──────╮
│ 3 lessons        ││ 6 days           ││ 11 of 53         ││ 83% clean        │
│ █▁▆▃▃▃▃ 7 days   ││ ▁▁▅▅▅▅▁█▅▅▂▂▅▁   ││ ━━━━━━━━━━━  21% ││ ██▇██▅▆▇▇▇▆▇▅▇▇▆ │
╰──────────────────╯╰──────────────────╯╰──────────────────╯╰──────────────────╯
╭─ Practice ────────────────────╮╭─ Today's session ──────────────── 4 rounds ─╮
│ › ▶ Start today's session     ││                                             │
│   ▶ Mixed practice            ││  ▶ review verb + motion       ◐ shaky       │
│ ───────────────────────────── ││  · review t T                 ◐ shaky       │
│   Foundations          ●●●●   ││  · review c                   ◐ shaky       │
│   Entering Insert      ●●◐●   ││  · learn  dd cc D C           ○ new         │
│   Along the line       ●●●◐   ││                                             │
│   Operators            ◐●◐○○○ ││  A session reviews up to three due lessons, │
│   Through the file     ○○○○○  ││  oldest first, then teaches the next new    │
│   Search and jumps     ○○○○○○ ││  one. Eight clean goals of ten pass a       │
│   Text objects         ○○○○○○ ││  round.                                     │
│   Repeat               ○○○○   ││                                             │
│   Visual               ○○○○   ││                                             │
│   Registers and macros ○○○○○  ││                                             │
│   Ex                   ○○○○○  ││                                             │
│                               ││                                             │
│                               ││                                             │
╰───────────────────────────────╯╰─────────────────────────────────────────────╯
 j/k move • l lessons • enter open • m mixed • s stats • ? help • q quit
```

- **Header**, one line. The name in a blend from accent to key colour. The
  inbox count and its directory at the right when notes are waiting; the
  tagline gives way to it when both do not fit.
- **Tiles**, four cards of four lines. Due today, with the next seven days as
  bars. Streak, with the last fourteen days. Solid, with a bar that grows.
  This week, the clean rate of the last seven days with recent rounds as bars,
  green where the round passed, amber where it did not, blue for mixed.
- **Practice pane**, left. Two rounds to start, a rule, then the sections,
  each with its lessons' symbols and, from 96 columns, a count. The cursor
  starts on the session row, which reads `Next round, 2 of 4` once a session
  is under way.
- **Detail pane**, right. It shows whatever the practice pane's cursor is on:
  today's session, a note on mixed practice, or a section's lessons.
- **Footer**, one line of keys from the `help` bubble, with the legend at the
  right from 100 columns. `?` swaps it for the full help in columns.

### A section's lessons, 100 columns

```
╭─ Practice ───────────────────────────╮╭─ Operators ─────────────────────────────── 1 of 6 solid ─╮
│   ▶ Start today's session            ││   ◐ verb + motion      shaky ▰▰▱▱▱  due today            │
│   ▶ Mixed practice                   ││ › ● d                  solid ▰▰▰▱▱  due in 2 days        │
│ ──────────────────────────────────── ││   ◐ c                  shaky ▰▰▱▱▱  due today            │
│   Foundations          ●●●●    4/4   ││   ○ dd cc D C          new   ▱▱▱▱▱                       │
│   Entering Insert      ●●◐●    3/4   ││   ○ y p P              new   ▱▱▱▱▱                       │
│   Along the line       ●●●◐    3/4   ││   ○ u Ctrl-R           new   ▱▱▱▱▱                       │
│ › Operators            ◐●◐○○○  1/6   ││   ▷ Review Operators   20 goals, keys hidden             │
│   Through the file     ○○○○○   0/5   ││ ──────────────────────────────────────────────────────── │
│   Search and jumps     ○○○○○○  0/6   ││   dW     delete to the next WORD                         │
│   Text objects         ○○○○○○  0/6   ││   dt{c}  delete up to {c}                                │
```

The pane with the focus has an accent border and title, and its selected row
a background across the whole row. Columns join as the pane widens: the
state's word from 43 columns inside the pane, the box out of five from 52,
the recent rounds as bars from 62. Under the list are the selected lesson's
keys from its JSON, or for the review row a line on what the review is.

### After a round

```
  PASSED  Review  verb + motion  ·  10 of 10 clean  ·  1:52  ━━━━━━━━━━━━  box 2 → 3 · due in 7 days
 j/k move • l lessons • enter open • m mixed • s stats • ? help • q quit    ○ new  ◐ shaky  ● solid
```

One line above the footer, kept until the next round ends, as the banner is
today. A tag, the round's title, the count and time, a bar that grows, and
what the round did to the lesson. See `shots/after-round-100x30.png`: the
session pane also lists each finished round with a tick and its result.

| Tag | When | Text after it |
| --- | --- | --- |
| `PASSED`, on green | a learn, review, or section round that passed | title, count, time, bar, note |
| `NOT PASSED`, on red | one that did not | the same |
| `DONE`, on blue | a mixed round | title, count, time, bar |
| `LEFT EARLY`, on grey | Vim quit before the round ended | today's sentence, unchanged: `Left Review  zz-beta after 0 of 10 goals, 0 clean. Nothing was rescheduled.` |
| `ERROR`, on red | Vim could not be run | today's sentence, unchanged |

The note is `moved()` in the prototype: `now shaky · due tomorrow`,
`still new`, `box 2 → 3 · due in 7 days`, `back to box 1 · due tomorrow`.
A section review that placed lessons says `3 lessons placed as known`, or
`1 lesson placed as known`.

### Lesson page, 110 columns

```
 VIM DOJO › Text objects › inner vs around                                       LEARN  10 goals · keys shown
                                                                                                              
   Inner vs around                                                    ┃  ╭─ Keys ───────────────────────────╮
                                                                      ┃  │ i{object}  inner: just the       │
  A text object names a piece of text by what it is rather than where │  │            contents              │
  it ends: a word, a string, the inside of a bracket. It follows an   │  │ a{object}  around: with the      │
  operator, as a motion does, but the cursor can be anywhere inside   │  │            surroundings          │
  it. Every text object comes in two sizes:  i  for inner, just the   │  ╰──────────────────────────────────╯
  contents, and  a  for around, the contents with what surrounds      │  ╭─ Your record ────────────────────╮
  them.                                                               │  │ ○ new  ▱▱▱▱▱                     │
                                                                      │  ╰──────────────────────────────────╯
   Key         │ What it does                                         │
                                                                                                              
 enter start the round • j/k scroll • space/b page • g/G ends • q back                                     0%
```

Glamour renders the page into a `viewport` bubble. The style is
`theme.markdown()`: Glamour's own dark or light style with the shell's
colours over it, the title as a filled label, second-level headings with an
accent bar, inline code on the surface colour. The text column is at most 84
wide. A scroll bar runs beside it, and from 110 columns a side column holds
the lesson's keys and its record. `REVIEW` and `keys hidden` replace
`LEARN` and `keys shown` for a review round.

### Stats, mixed practice

See `shots/stats-120x40.png` and `shots/mixed-100x30.png`.

- **Stats** is a `viewport` over four tiles (rounds, goals, time, streak),
  the activity strip, and a `lipgloss/table` with a row a lesson: box, rounds,
  recent rounds as bars, the last result, seconds a goal over the last five
  rounds, when it is due. Mixed practice has the last row.
- **Mixed practice** is a dialog set over the dimmed dashboard with a
  `lipgloss.Compositor`. The chosen length is marked in the text as well as
  by colour, `‹20›`, so it reads without colour and a test can find it.

### The strip

On a window tall enough, under the panes: a calendar of the last weeks
shaded by goals finished each day, a bar for each of the next fourteen days'
reviews, and from 104 columns the count of lessons in each box. The stats
screen always shows it. See `shots/home-120x40.png`.

## Sizes

All of this is in `homeView` and `layout` in the prototype. Keep the numbers.

| Rule | Value |
| --- | --- |
| Wider than 128 columns | the shell stays 128 wide, centred |
| Narrower than 80 | one pane at a time, the one with the focus |
| Practice pane | 33 wide, 40 from 96 columns |
| Tiles | shown when the panes still get their full list and the window is 56 wide |
| Strip | shown when tiles and list fit with 10 lines over, from 80 columns |
| Size not yet known | draw at 80 by 24 |
| Anything | never draw past the window: `View` clips to its width and height |

At 80 by 24 the dashboard fills the window exactly, with the Custom section
and the last round's line both showing.

## Keys

| Where | Key | Does |
| --- | --- | --- |
| anywhere | `ctrl+c` | quit |
| dashboard | `j` `k`, arrows | move in the pane with the focus |
| | `g` `G` | its first and last row |
| | `l`, right, Enter on a section | into the section's lessons |
| | `h`, left, `esc` | back to the practice pane |
| | Enter on the session | start it, or its next round |
| | Enter on mixed, or `m` | open the dialog |
| | Enter on a lesson | its page, or its round if it has no page |
| | Enter on a review | start the section review |
| | `s` | stats |
| | `?` | full help on and off |
| | `q` | quit |
| page | Enter | start the round |
| | `j` `k` `space` `b` `d` `u` `g` `G` | scroll |
| | `q`, `esc` | back |
| stats | the same scroll keys; `q`, `esc`, `s` | back |
| dialog | `j` `k`, `h` `l`, `space` or `x`, Enter | section, length, choose, start |
| | `esc`, `q`, `m` | close |

Two things differ from today and belong in the README: `esc` on the
dashboard steps back and no longer quits, and a lesson is reached through
its section.

## From prototype to shell

| Prototype | In the shell |
| --- | --- |
| `theme.go` | Move as it is. |
| `metrics.go` | Move its five functions into `dojo.go`, with a test. Delete the prototype's copy in the same commit, or the prototype stops building: it links the real `dojo.go`. |
| `views.go` | Move as it is, then make it read the real model. |
| `main.go`: `keys`, `bindings`, `named`, `homeKey`, `pageKey`, `statsKey`, `dialogKey`, `open`, `before`, `moved`, `due`, `View`, the spring | Move, joined to the real `start` and `finish`. |
| `main.go`: `demo`, `play`, the flags, `press` | Prototype only. `press` is how a test builds a key; put it in `dojo_test.go`. |
| `proto_test.go`: `TestSizes` | Move into `dojo_test.go`. It caught a panic and several lines drawn past the window in the prototype. |

What the real model needs that it lacks today:

- A constructor, `newModel(catalog, state)`, for `main` and the tests, which
  now build `&model{...}` by hand. It sets the theme, the help bubble, the
  spring, and the mixed dialog's defaults.
- `left`, `right`, `inDetail` in place of `rows`, `cursor`, `offset`. The
  cursor needs no restoring after a round: the catalog does not change while
  the shell runs, so the indexes stay good.
- `session` kept whole, with `done []result` beside it, in place of the
  shrinking `session` and `sessionSize`. The next round is
  `session[len(done)]`; the session is over when the two are the same length.
- `last *result` in place of `banner []string`. Build it in `finish` from
  the round's record, and take a copy of the lesson's `Item` before
  `refresh` so `moved` can compare.
- `roundDone` carries `fromSession`. `start` no longer shortens the session;
  `finish` appends to `done` when the round was the session's, and clears
  both when it was not, when it was left early, or when Vim failed. See
  `play` in the prototype for the order of things.
- `finish` restarts the spring: set `pos` and `vel` to 0, and have `Update`
  return `frame()` for `roundDone`.

## v2, where it is not what you remember

Each of these was hit or checked while building the prototype.

- Imports are `charm.land/bubbletea/v2`, `charm.land/lipgloss/v2`,
  `charm.land/bubbles/v2/...`, `charm.land/glamour/v2`. Not `github.com/charmbracelet/...`.
- `View()` returns `tea.View`. Build it with `tea.NewView(text)` and set
  `v.AltScreen = true` on it; `tea.WithAltScreen()` is gone. A test reads
  `m.View().Content`.
- **`View` is called before the first `tea.WindowSizeMsg`.** With a width of
  0 the prototype panicked on a negative `strings.Repeat`. Default the size.
- A key press is `tea.KeyPressMsg`. A test builds one as
  `tea.KeyPressMsg{Code: tea.KeyEnter}` or `tea.KeyPressMsg{Code: 'j', Text: "j"}`.
- **Space is `"space"`**, not `" "`, in `msg.String()` and in `key.WithKeys`.
- A colour is a `color.Color` from `image/color`. `lipgloss.Color("#B794F6")`
  is a function that returns one. `lipgloss.AdaptiveColor` is gone: ask for
  the background with `tea.RequestBackgroundColor` in `Init`, and on
  `tea.BackgroundColorMsg` rebuild the theme from `msg.IsDark()`.
- **`Style.Width` and `Style.Height` are the outer size**, border and padding
  included. In v1 the border was extra. `theme.card` relies on this.
- A background on an outer style stops at the first inner reset. A selected
  row gets its background cell by cell: see `theme.row`.
- Lip Gloss wraps a line that is too long for its `Width`. `theme.card`
  truncates each line first with `ansi.Truncate`, so a card never grows.
- Glamour has no `WithAutoStyle`. Pass the style with `glamour.WithStyles`.
  Rendering is not cheap: do it in `layout`, when the lesson or the width
  changes, never in `View`.
- Bubbles: `viewport.New(viewport.WithWidth(w), viewport.WithHeight(h))`, and
  `Width()`, `Height()`, `YOffset()` are methods with `Set...` partners.
  `help.New()` then `SetWidth`. `progress.New(...).ViewAs(fraction)` draws a
  bar at a fraction with no animation of its own, which is how the one
  spring drives every bar.
- The dialog: `lipgloss.NewCompositor(lipgloss.NewLayer(back), lipgloss.NewLayer(dialog).X(x).Y(y).Z(1)).Render()`.
  The back layer is the dashboard with `ansi.Strip` and one faint colour.
- The spring: `harmonica.NewSpring(harmonica.FPS(60), 7, 0.8)`, then
  `pos, vel = spring.Update(pos, vel, 1)` on each `tea.Tick` until it settles.
- `tea.ExecProcess` is unchanged.

## Slices

One commit each, in this order, `go test .` green at the end of every one.
Commit subjects in this repository are a plain sentence saying what changed,
such as "Bring the headless suite under a minute".

1. **Move to v2 with the screen as it is.** Imports, `View`, key messages,
   colours, the tests' key helper. Nothing looks different. This keeps the
   API move apart from the redesign.
2. **The dashboard's panes.** `theme.go`, the constructor, the new cursor,
   the practice and detail panes, header, footer with `help` and `key`, the
   clip in `View`. Rewrite `TestMap`, `TestPlan`'s view check, `TestCustom`'s
   view check. Add `TestSizes`.
3. **Tiles and strip.** The metrics into `dojo.go` with `TestMetrics`, then
   the tiles and the strip.
4. **Lesson pages.** Glamour, the viewport, the scroll bar, the side column.
   Rewrite `TestPage`.
5. **Stats.** Rewrite the stats checks in `TestFinish` and `TestMixedShell`.
6. **Mixed practice's dialog.** Rewrite the rest of `TestMixedShell`.
7. **The last round's line, the session pane's progress, the spring.**
   Rewrite the rest of `TestFinish`.
8. **Finish.** `test/typing.sh`, the README's map section and key list, this
   file's status line, and delete `prototype/` and `shots/`.

## Tests

`dojo_test.go` checks logic and screen text. The logic tests (`TestState`,
`TestDraw`, `TestPlaced`, `TestMixed`, the plan in `TestPlan`) need only the
v2 key helper. The screen checks change as below; keep each test's purpose.

| Test | Now checks |
| --- | --- |
| `TestMap` | The section names in order. On a fresh state at the default size: 24 lines, none wider than 80, no `◐` or `●`, `› ▶ Start today's session`, `▶ learn  modes and Esc`, `New here?`, the footer's keys. Then `j j` and one `j` a section: the detail pane lists that section's lesson titles in order and its `▷ Review` row. |
| `TestPlan` | `3 lessons` in the Due today tile; `▶ review :g`, `· review .`, `· review Ctrl-O Ctrl-I`, `· learn  modes and Esc` in the session pane. |
| `TestCustom` | `Custom` in the practice pane; after `G` and `l`, `○ old-gone`. |
| `TestPage` | `j j enter enter` opens the page on `modes`. It contains `Modes and Esc` and no backticks. `j` moves `YOffset` to 1. `G` reaches `AtBottom`. Enter starts the round and writes `round.json`. Then `esc`, `g`, Enter: the session's new lesson opens on its page with `fromSession` set. |
| `TestFinish` | Set `session` to two rounds and send `roundDone` with `fromSession`. `PASSED`, `Learn  modes and Esc  ·  8 of 10 clean  ·  1:00`, `now shaky · due tomorrow`, `› ▶ Next round, 2 of 2`. After `j j`, in the Foundations pane, `◐ modes and Esc` with `shaky` and `due tomorrow`. Left early: the old sentence, and `Start today's session` again. Stats: the lesson's row with `8 of 10` and `6.0s`. |
| `TestMixedShell` | The dialog opens with `every learned lesson (2)` and `‹20›`. After `l l l`, `‹5›`. After `j` and space, `[x] Entering Insert` and `Entering Insert (4 lessons)`. Enter writes a mixed request with limit 300. After the round: `DONE`, `Mixed practice  ·  11 of 14 clean  ·  5:00`, no `PASSED`. Stats: a Mixed practice row with `11 of 14` and `21.4s`. |
| `TestSizes`, new | From the prototype: every screen from 20 by 5 to 150 by 50, fresh and practised, draws without a panic and inside the window. |
| `TestMetrics`, new | `Streak` counts back from today, or from yesterday when today is empty, and stops at a gap. `Forecast` puts an overdue lesson on today. `Boxes` sums to the number of lessons. |

`test/typing.sh`, the shell part only:

- `G Enter` becomes `G Enter Enter`: the Custom section, into it, start. A
  custom lesson has no page.
- `'Learn  zz-beta  ·  10 of 10 clean  ·  .*passed'` becomes
  `'PASSED  *Learn  zz-beta  ·  10 of 10 clean'`.
- `'◐ zz-beta  *shaky  *due tomorrow'` becomes
  `'◐ zz-beta  *shaky.*due tomorrow'`: the box sits between the two.
- The Enter after it still starts the review, since the cursor keeps its
  row. `'Left Review  zz-beta after 0 of 10 goals'` stays as it is.

## Done when

- **deps**: `go.mod` requires the six modules above directly and no others.
- **logic-untouched**: `git diff` of `dojo.go` shows only the metrics added.
- **fits**: at 80 by 24 the dashboard is 24 lines, none wider than 80, with
  tiles and both panes.
- **any-size**: `TestSizes` passes.
- **narrow**: under 80 columns one pane shows, and `l` and `h` swap them.
- **page**: a lesson page is Glamour's rendering, scrolls, and shows no
  Markdown syntax.
- **last-round**: after a round the line shows the tag, count, time, and
  what moved, and the session pane ticks the round off.
- **dialog**: mixed practice opens over the dashboard and starts the same
  request as before.
- **light-and-dark**: both themes are legible. Check with `-light` in the
  prototype for the target, and by running the shell in a light terminal.
- **end-to-end**: `sh test/typing.sh` passes, and so does
  `vim -Nu NONE -i NONE -n -es -S test/dojo.vim`, which nothing here touches.
- **readme**: the map section shows the new dashboard, and the keys are right.

## Do not

- Change `dojo.go` beyond the metrics, the Vim runner, a lesson, or the
  request and record formats.
- Add a dependency outside the six. No `huh`, no chart library: the bars,
  calendar, and sparklines are a few lines each in `views.go`.
- Turn on the mouse, add settings or flags, add emoji, or animate text.
- Render Markdown in `View`.
- Keep the prototype's `demo`, `play`, or `-snap` in the shell.

## Style here

Comments say why, in a sentence, above the thing. British spelling: colour,
practised. Few files: `main.go` for the program, model, and keys, `view.go`
for drawing, `theme.go` for colours and the small widgets, `dojo.go` for
everything that is not the screen. No abstraction with one user.
