# Vim Dojo v2: teach, measure, and schedule by technique

Status: settled with the author on 2026-11-22. No open questions.

## Problem

The dojo today has 16 built-in drills (3 motions, 5 objects, 4 repeat, 4 jumps)
and grades only the resulting buffer.

- **It cannot see how you edited.** `xxxxxxx` and `ci"` both count as solved.
  The only signal that a technique was used is `:DojoUsed` (F9), a self-report.
- **It tests but never teaches.** A learner who has not met a technique gets a
  goal and, on request, a hint. Nothing introduces the technique first.
- **Fixed drills are memorised as answers.** After a few passes the learner
  recalls "this one is `ci"ratchet`", not the technique.
- **There is no picture of what you know.** A beginner cannot see which parts
  of Vim they have not met, so weak areas stay invisible.
- **The loop has friction.** Every check needs F5, and F5–F9 are media keys by
  default on a Mac keyboard.
- **Scheduling is coarse.** Review is per skill (three of them) at fixed one-
  and three-day intervals.

The primary learner is a beginner who knows basic motions and simple edits but
is not fluent and has large gaps. The tool should also carry that learner
through to fluency.

## Terms

- **Skill**: a group of related techniques (existing term: `objects`, `repeat`,
  `jumps`, `motions`, `custom`).
- **Technique**: one learnable command or pattern inside a skill, such as
  `ci"`, `.`, `f{char}`, or `Ctrl-O`. New in v2; the unit that is taught,
  detected, and scheduled.
- **Drill**: one exercise that practises a technique.
- **Template**: a drill whose text is filled from value lists each time it
  opens, so no two attempts look the same.
- **Solution**: an executable key sequence that solves a drill. Distinct from
  `keys`, which stays human-readable display text.
- **Par**: the key count of the solution.

## Intended behavior

### Practice loop

- The dojo checks the drill by itself after every change made in Normal mode,
  on leaving Insert mode, and on cursor movement. Reaching the target state
  solves the drill with no check key.
- While unsolved after an edit, the panel shows the remaining difference
  without a keypress (what F5 shows today on a failed check).
- F5–F9 mappings are removed. Hint, reset, and skip are buffer-local
  `<LocalLeader>` mappings (`h`, `r`, `s`); Enter continues once a drill is
  solved. The `:Dojo*` commands remain.
- A drill may be a **cursor-target drill**: the buffer is unchanged and the
  drill is solved when the cursor reaches a target position. The existing
  two-step jump drills (reach the definition, then return) advance each step
  automatically.
- Text that must change is highlighted in the buffer when a drill opens. A
  drill can declare that locating the text is part of the practice, as search
  and jump drills do, and then nothing is highlighted.
- `g:vim_dojo_highlight = 0` turns highlighting off for every drill. It is on
  by default.

### Measuring how the learner edited

- Keys pressed in the practice buffer are captured while a drill is open.
  Capture sees keys after the learner's own mappings are applied, so `jk`
  mapped to `<Esc>` is recorded as `<Esc>`.
- Capture covers only the dojo practice buffer. The raw key log lives in memory
  for the current drill only. Progress records store the key count and elapsed
  seconds, never the keys.
- A dot repeat counts as one key. Keys Vim replays internally for `.` are not
  counted.
- On solving, the panel reports keys against par and shows the learner's keys
  beside the solution.

  > Solved in 15 keys · par 11
  > You: `x x x x x x i r a t c h e t <Esc>`
  > Try: `c i " r a t c h e t <Esc>`

- Each technique has a key pattern. If the pattern appears in the learner's
  Normal-mode keys and no hint was used, the attempt is recorded as `recalled`.
  This replaces `:DojoUsed`; the command and its panel line are removed.
- A `.` typed as Insert-mode text (for example inside a URL) is not a dot
  repeat. Detection is mode-aware.
- Solving another way still solves the drill. It is recorded as `solved`, and
  the panel names the technique the drill is practising.
- Obvious anti-patterns are called out with the alternative: the same motion
  key repeated many times, arrow keys, repeated `x`.

### Teaching

- The first time a learner meets a technique, the dojo shows a short card: the
  technique's name, its keys, and one or two lines on what it does and when to
  reach for it.
- The dojo then plays the solution into the practice buffer key by key, slowly
  enough to follow, resets the buffer, and hands the same drill to the learner.
- Later drills for that technique open without the card or the demo.
- Hints become a three-step ladder: clue, then keys, then the demo. Any hint
  marks the attempt `assisted`, as today.
- Demo keys never count toward the learner's key count.

### Skill map

- `:Dojo` resumes a session in progress, as today. With no session in
  progress it opens the skill map.
- The map must be readable at a glance by someone who has never seen it, with
  no documentation. It looks like this:

  ```
  Vim Dojo                                    2 due today · 1 in inbox

    ▶ Start today's session        review f t ; ,  ·  learn i( a(

  Move               ●●◐◐○○○    2 of 7 solid
    ● w b e            solid     due in 6 days
    ● 0 ^ $            solid     due in 12 days
    ◐ f t ; ,          shaky     due today
    ◐ gg G {n}G        shaky     due tomorrow
    ○ { }              new
    ○ %                new
    ○ counts           new

  Objects            ◐○○○○○     0 of 6 solid
  Repeat             ○○○○       0 of 4 solid

  ○ new   ◐ shaky   ● solid       Enter practise · d diagnostic · q close
  ```

- Every technique is listed under its skill, marked **new**, **shaky**, or
  **solid**, with when it is next due. Techniques the learner has never met
  are visible, so the map doubles as a view of what exists.
- State is shown by symbol and by word, never by colour alone. Colour is added
  on top.
- Each skill has one summary line with a progress bar. Skills with something
  due or in progress start open; the rest start closed. Enter on a skill line
  opens or closes it.
- The last line is always a legend and the available keys. The map fits in 80
  columns.
- The cursor starts on the session row, so `:Dojo` then Enter starts
  practising. The row says what the session will review and teach.
- Enter on a technique starts focused practice on it. `:DojoFocus {technique}`
  does the same from the command line, with completion.
- Custom drills appear under their declared skill, or under `custom`.
- `:DojoCatalog` and `:DojoLessons` are removed; the map does both jobs.
  `:DojoFree` stays and opens one random drill.

### Diagnostic

- On first run, and on request from the map, the dojo offers a diagnostic:
  about ten drills spread across the skills, with no cards and no hints.
- A technique recalled within two keys of par in the diagnostic is placed as already
  known and scheduled for a later review. Everything else stays new.
- The diagnostic can be declined or abandoned at any point without penalty.

### Scheduling

- Review is scheduled per technique, not per skill, using Leitner boxes.
  Intervals: 1, 3, 7, 14, 30 days.
- `recalled` moves a technique up a box. `solved` by another route or
  `assisted` leaves it where it is. `skipped` returns it to the first box.
- Map states: **new** = never attempted; **shaky** = boxes 1–2;
  **solid** = box 3 and above.
- A coached session keeps today's shape (review or warm-up, practice, apply),
  choosing due techniques first, then the next new technique in curriculum
  order.

### Content

- Built-in drills become templates where the text can vary. Names, values,
  positions, and filetype are drawn from value lists each time.
- For every built-in drill and every template variant, the expected buffer and
  par come from running the solution. Neither is written by hand.
- The curriculum grows from three skills to roughly eight. Technique list,
  in teaching order:

  | Skill | Techniques |
  | --- | --- |
  | Move | `w` `b` `e`, `0` `^` `$`, `f` `t` `;` `,`, `gg` `G` `{n}G`, `{` `}`, `%`, counts |
  | Edit | operator + motion (`d` `c` `y`), `dd` `cc` `yy`, `x` `r`, `A` `I` `o` `O`, `J`, `p` `P`, `u` `Ctrl-R` |
  | Objects | `iw` `aw`, `i"` `a"`, `i(` `a(`, `i{` `a{`, `it` `at`, `ip` `ap` |
  | Repeat | `.`, `;` after `f`, `n` then `.`, counts on changes |
  | Search and jumps | `/` `?`, `n` `N`, `*` `#`, `Ctrl-O` `Ctrl-I`, marks |
  | Visual | `v`, `V`, `Ctrl-V` block insert and append, `gv` |
  | Registers and macros | named registers, `"0`, `Ctrl-R` in Insert mode, `q` and `@`, `@@` |
  | Ex | `:s` with ranges, `:g`, `:normal`, `Ctrl-A` `Ctrl-X`, `g Ctrl-A` |

- Each technique ships with a card and enough drills that it cannot be
  memorised: one template, or at least three fixed drills.

### Custom drills

- Custom drill JSON gains optional fields: `ft`, `start` (anchor text for the
  starting cursor, as built-ins use), `skill`, `technique`, `solution`, and
  `target` (anchor text for a cursor-target drill).
- Without `solution`, a custom drill has no par, no demo, and no technique
  detection; it is checked on the buffer alone, as today.
- The README prompt for generating drills with an LLM is updated to produce
  the new fields.

### Friction inbox

- `:[range]DojoNote [text]` saves the given lines (default: the current line),
  the filetype, and an optional note to an `inbox/` directory under the state
  directory. It is the only v2 feature that reads a buffer outside the dojo,
  and it runs only when the learner invokes it.
- The skill map shows how many inbox entries are waiting and where they are.
- The README documents a prompt that turns an inbox entry into drill JSON.

## Constraints

- Vim only, pure Vimscript, no dependencies. Requires Vim 9.1.0597 or later:
  `KeyInputPre` arrived in 9.1.0563 and its `typedchar` field, which the dot
  filter relies on, in 9.1.0597. On an older Vim, `:Dojo` says so in one line
  and stops.
- Key capture sits behind one function so a later Neovim port replaces one
  function. No other Neovim work.
- Everything stays on the machine. The plugin sends nothing anywhere.
- Practice still happens in scratch buffers with the learner's own mappings.
  Opening and closing the dojo leaves the learner's other buffers untouched,
  including unsaved edits.
- Existing progress records and existing custom drill files stay valid. Old
  records have no key count or seconds; readers treat those as absent.
- Tests follow the existing convention: one headless run of `test/dojo.vim`
  with `assert_*`, driven through commands and `feedkeys`.

## Acceptance

- **auto-check**: `ci"ratchet<Esc>` on the `quoted-item` drill shows Solved
  with no further key. An edit that leaves a collateral change shows the
  remaining difference with no further key.
- **no-f-keys**: no F-key is mapped in the practice buffer; `<LocalLeader>h`,
  `r`, `s` and Enter do what F6, F7, F8 and F5-after-solve did.
- **cursor-target**: a cursor-target drill is solved when the cursor lands on
  the target with the buffer unchanged; a jump drill completes both steps with
  no check key.
- **key-count**: solving `pending-jobs` with `ciwqueued<Esc>j.j.` reports 14
  keys, with each `.` counted once.
- **mapping-aware**: with `inoremap jk <Esc>`, a solution typed with `jk` is
  detected as using the technique.
- **recalled-detected**: solving a `ci"` drill with `ci"` and no hint records
  `recalled`; solving it with `xxxxxxiratchet<Esc>` records `solved`; either with a
  hint records `assisted`.
- **insert-dot**: typing a `.` in Insert mode does not count as a dot repeat.
- **nothing-raw-persisted**: after a session, no file in the state directory
  contains the keys typed.
- **teach-first-meeting**: the first drill of an unmet technique shows the card
  and demo, and the buffer is back at its starting state when control returns.
  The second drill of that technique shows neither.
- **demo-not-counted**: after a demo, the learner's key count starts at zero.
- **solutions-valid**: for every built-in drill and several random variants of
  every template, running the solution from the starting cursor produces the
  expected state. The test suite checks this.
- **variants-differ**: opening the same template twice can produce different
  text, and each variant is solvable by its own solution.
- **highlight**: `quoted-item` opens with `"widget"` highlighted;
  `catalog-string`, where the item must be found by name, opens with nothing
  highlighted; with `g:vim_dojo_highlight = 0` neither is highlighted.
- **map-readable**: the map shows a symbol and a word for every technique, a
  bar per skill, and the legend with keys on its last line, within 80 columns.
  Enter on the session row starts a session; Enter on a skill line opens or
  closes it.
- **commands-removed**: `:DojoCatalog` and `:DojoLessons` no longer exist;
  `:DojoFree` opens one random drill.
- **map-states**: a fresh state directory shows every technique as new. After
  a `recalled` attempt, that technique shows as shaky with a due date.
- **focus**: `:DojoFocus` with a technique name starts drills for that
  technique only.
- **schedule-per-technique**: a technique recalled today is not due tomorrow
  if it sits in the three-day box; a skipped technique is due the next day.
- **diagnostic-places**: techniques recalled at par in the diagnostic do not
  get a card or demo afterwards; the rest do.
- **old-state-loads**: a state directory written by v1 loads, and its outcomes
  count toward the matching techniques.
- **custom-fields**: a custom drill with `ft`, `start`, and `solution` opens
  with that filetype and cursor and reports par. A v1 custom drill file still
  loads.
- **inbox**: `:3,5DojoNote too many keystrokes` writes one inbox entry holding
  those three lines, the filetype, and the note, and nothing else from the
  buffer.

## Decisions

- **Beginner first.** Teaching, the map, and the diagnostic come before
  competitive modes, because the primary learner is still finding their gaps.
- **Grade by captured keys, not self-report.** `:DojoUsed` goes away.
- **One executable solution per drill** drives the demo, par, and validation of
  the expected buffer, so the three cannot drift apart.
- **Store counts, not keys.** Enough for scheduling and progress; nothing
  sensitive on disk.
- **Friction inbox in place of a watcher.** The learner was hesitant about
  observing real editing. The inbox gets real-work material with explicit
  consent each time.
- **Vim only for now.** The author does not use Neovim.
- **Enter to continue, no timed auto-advance.** A beginner needs time to read
  the explanation after solving.
- **Require `KeyInputPre`** instead of keeping a second, self-report path alive
  for older Vims.
- **The skill map replaces the catalog and lesson path**, on condition that it
  is visual and easy to understand. That condition is a requirement above, not
  a nicety.
- **Highlighting is a setting, not a key.** A toggle key would add one more
  dojo mapping to a buffer where the learner is practising Vim's own keys.
- **The curriculum table is accepted** as the technique list and order.
- **Review intervals and the diagnostic threshold are accepted** as written.
  They are single values in code and cheap to tune.
- **The inbox is plain files plus a README prompt.** No review screen in Vim.

## Out of scope

- A watcher that observes real editing and suggests drills.
- Neovim support.
- Golf, speed-round, and predict-the-result modes.
- Belts, streaks, and other gamification beyond the map states.
- Templates in custom drill JSON. Custom drills stay fixed text.
- An in-plugin LLM call. Drill generation stays a prompt the learner runs.

## Delivery

Slices in build order. Each leaves the dojo usable.

1. **Loop friction** (auto-check, no-f-keys, cursor-target, highlight). Touches
   `autoload/vim_dojo.vim` only. Includes target highlighting.
2. **Key capture and par** (key-count, mapping-aware, recalled-detected,
   insert-dot, nothing-raw-persisted, solutions-valid). Adds `technique` and
   `solution` to drills; rewrites the prose `keys` on `strip-debug-args` and
   the jump drills as executable solutions. Removes `:DojoUsed`.
3. **Teaching** (teach-first-meeting, demo-not-counted). Cards, demo playback,
   three-step hints.
4. **Technique scheduling and skill map** (map-readable, map-states,
   commands-removed, focus,
   schedule-per-technique, diagnostic-places, old-state-loads). Rewrites
   `progress#Plan`; replaces the catalog screen. The diagnostic is only as
   broad as the techniques authored so far and grows with slice 5.
5. **Content** (variants-differ, custom-fields). Template mechanism, then
   authoring cards and drills skill by skill. The bulk of the work by volume;
   each skill can land separately.
6. **Friction inbox** (inbox). Independent of the others.

### Delivery status

All six slices are implemented on `dojo-v2`, and `test/dojo.vim` covers every
acceptance item. Departures from the text above:

- **Custom solutions are never run.** Running keys from a JSON file in the
  learner's Vim can run shell commands, and `:sandbox` forbids any buffer edit,
  so it cannot contain them. A custom `solution` gives par and detection only;
  custom drills still need `expected` or `target`, and have no demo.
- **Capture counts only keys with a `typedchar`.** That drops keys replayed by
  `.` and `@`, and Vim's own expansions such as `x` into `dl`. A learner mapping
  that expands to several keys is seen as its first key.
- **Mode comes from autocommands, not `mode()`**, which reports Ex mode
  throughout a headless run.
- **Undo drills** use optional `history` and `redo` fields, built with
  `setline()` so the starting buffer has something to undo.

### Known risks, from a headless prototype on Vim 9.2

- **Dot replay leaks into capture, with a likely filter.** `KeyInputPre` fires
  for the keys Vim replays after `.`. `v:event.typed` does not distinguish
  them, but `v:event.typedchar` was empty for every replayed key in the
  prototype, so counting only keys with a non-empty `typedchar` gave the right
  total. Two details are unsettled: one key arrived as `<Ignore>c`, and it is
  untested how a learner mapping that expands to several keys is counted.
- **Real typing is unverified.** The prototype fed keys with `feedkeys`. Mode
  reporting in particular could not be checked headless (it reported Ex mode
  throughout). Check by hand in a terminal before building on it.
- **Demo playback uses timers**, which the headless suite cannot exercise
  faithfully. Expect a manual check for pacing; the suite can still assert the
  end state.
