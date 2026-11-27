# Vim Dojo v3: a lesson path with long rounds, and a Go shell

Status: direction settled with the author on 2026-11-26. The items under
"Chosen while writing" in Decisions have not been confirmed yet.

## Problem

The author used v2 for real and reported three things. The code and the
practice records bear each of them out.

- **Too few reps.** `:DojoFocus` gives exactly three drills and a session gives
  a new technique two. Eighteen of the 43 techniques have a single drill.
- **The text is trivial.** 46 of the 82 drills are three lines or fewer, 22 are
  one line, and the longest is 13 lines.
- **Teaching does not land.** A technique's card is two lines, shown once.
  After that the keys are hidden behind a clue ("One key goes straight to the
  end of the line"), and looking marks the attempt assisted. The learner ends
  up pressing hint.
- **The catalog has no path.** Coverage is wide, but techniques are grouped by
  Vim concept, the early ones are coarse, and nothing reviews a group. The
  author prefers the shape of vim-hero.com: sections of small lessons, each a
  few keys followed by many reps.
- **The map and panel are clumsy** as Vim buffers. Lesson pages and stats would
  be worse.

Looking into the records turned up a defect underneath all of this:

- **Key counting is wrong in real use.** The dojo counts only keys whose
  `KeyInputPre` event has a `typedchar`. With `set updatetime=100`, Vim reports
  an empty `typedchar` for real keystrokes and a non-empty one for the
  `<CursorHold>` pseudo-key. Real keys sent through tmux showed it: in bare Vim
  the dojo records `f=` as two keys and recalled; in bare Vim plus that one
  setting the same keys arrive with an empty `typedchar`, so no plugin is
  involved. With the author's config the panel reads "Solved in 0 keys" or
  `You: <CursorHold> t`. On 2026-11-26 the author solved nine
  drills without a hint and two were credited as recalled. v2 listed "real
  typing is unverified" as a known risk; the headless suite feeds keys with
  `feedkeys` and cannot see this.

v2 was built as a spaced-recall quiz. v3 turns it into a trainer: a lesson
path, real teaching, and enough reps on realistic text to build the habit.
Spaced review stays, on top of that.

## Terms

v2 terms keep their meaning unless replaced here.

- **Section**: a group of related lessons. Replaces *skill*.
- **Lesson**: a few keys taught together, such as `f F ; ,`. Replaces
  *technique* as the unit that is taught, practised, and scheduled.
- **Page**: a lesson's teaching text. Replaces the *card*.
- **Goal**: one thing to do in the practice buffer: reach a target or make an
  edit. Replaces *drill* as the unit of practice.
- **Round**: a run of goals done in one sitting in Vim, ten by default.
- **Generator**: a rule belonging to a lesson that makes goals on any suitable
  text: where a goal can sit, where the cursor starts, and the solution keys.
- **Scenario**: authored text with a fixed solution. This is what a v2 drill or
  template is. Used where a goal needs prepared text or state.
- **Snippet**: 20 to 40 lines of realistic code, prose, or config that
  generated goals are placed on.
- **Clean**: a goal solved without a hint in at most par plus two keys.
- **Runner**: the Vimscript that runs one round inside Vim.
- **Shell**: the Go program that shows everything outside a round.

## Intended behavior

### Counting keys

- Every key the learner types in the practice buffer is counted, however long
  they paused before it and whatever `updatetime` is.
- `<CursorHold>` and other keys Vim inserts by itself are never counted.
- A dot repeat still counts as one key, and keys replayed by `.` or `@` are
  still not counted, as in v2.

### Rounds

- Practising a lesson is a round of ten goals, not three drills.
- Solving a goal opens the next one with no key pressed. This replaces v2's
  Enter between drills.
- While the next goal is up, the panel shows how the last one went: keys
  against par, and the par solution if it was not clean.

  > Last: 7 keys · par 3 · try `c i " t i m e o u t <Esc>`

- After the last goal the panel shows a summary: how many goals were clean,
  the time taken, and each goal that was not clean with its par solution. If
  those goals show an obvious long way round (a motion key held, arrow keys,
  repeated `x`), the summary says so once. Enter leaves the round.
- A **learn round** keeps the lesson's keys in the panel for every goal, each
  with a few words on what it does. A **review round** does not show them.
- A hint shows the solution keys at once. A second hint plays the demo. Any
  hint makes that goal not clean. The clue step is gone.
- The first goal of a lesson's first learn round is demonstrated before it is
  handed over, as v2 does on first meeting a technique.
- Reset restores the current goal. Skip moves on and the goal is not clean.
- Leaving a round early keeps the goals already done in the record and changes
  no schedule.

### Grading

- A goal is clean when it is solved without a hint in at most par plus two
  keys. Which keys were used does not matter. Reaching the line's first
  character with `_` is as good as `^`.
- Technique detection patterns are removed, and with them the outcomes
  `recalled` and `solved`.
- A round is **passed** with at least eight clean goals in ten.

### Generated goals

- A lesson's generators make goals on a snippet. A generator picks a place
  where the lesson's keys apply, puts the cursor at a starting point, and
  names the solution keys, drawing any count, character, or replacement text
  it needs.
- The target is whatever playing the solution in Vim produces: a cursor
  position, or a changed buffer. Par is the solution's key count. Nothing
  about a target is worked out outside Vim. This is v2's rule for drills,
  applied to every goal.
- A generated goal is thrown away and drawn again when its solution raises an
  error, changes nothing, or could be matched within the clean threshold by
  single-step keys (`h j k l x`), except in lessons that teach those keys.
- The text to change, or the cell to reach, is highlighted, and the goal says
  what to do with it.

  > Change the highlighted string to "timeout".

- In a lesson that only moves the cursor, the text stays as it is and each new
  target is drawn from where the cursor now sits. In a lesson that edits, the
  snippet is restored before each goal.
- Two rounds on the same lesson do not give the same ten goals.
- Lessons whose goals need prepared text or state use scenarios instead: undo
  history, marks and jumps, dot repeats, registers, macros, and Ex commands.
  A lesson may use both. Each lesson that relies on scenarios has at least
  four, and a round rotates through them with fresh values.

### Snippets

- The dojo ships at least 24 snippets, each 20 to 40 lines, across Go, Python,
  TypeScript, HTML, Markdown prose, and config files.
- A lesson only uses snippets on which its generators find enough places for a
  round. The tag lesson, for example, uses HTML.

### Lessons and sections

- The curriculum is eleven sections, taught in this order:

  | Section | Lessons |
  | --- | --- |
  | Foundations | modes and Esc · `h j k l` · `w b e` · `i a` |
  | Entering Insert | `I A` · `o O` · `x r` · `s` |
  | Along the line | `W B E` · `0 ^ _ $` · `f F ; ,` · `t T` |
  | Operators | verb + motion · `d` · `c` · `dd cc D C` · `y p P` · `u Ctrl-R` |
  | Through the file | `{n}j {n}k` · `gg G {n}G` · `{ }` · `Ctrl-D Ctrl-U` · `%` |
  | Search and jumps | `/ ?` · `n N` · `* #` · search as a motion · `Ctrl-O Ctrl-I` · marks |
  | Text objects | inner vs around · words · quotes · brackets · tags · paragraphs |
  | Repeat | `.` · `;` after `f` · `n` then `.` · counts on changes |
  | Visual | `v` · `V` · `Ctrl-V` · `o` and `gv` |
  | Registers and macros | `"0` · named registers · `Ctrl-R` in Insert · `q @` · `@@` |
  | Ex | `:s` with ranges · `:g` · `:normal` · `Ctrl-A Ctrl-X` · `g Ctrl-A` |

- Two v2 techniques have no lesson of their own and are folded in when the
  lessons are written: `J` into `dd cc D C`, and counts on word motions into
  `{n}j {n}k`.
- Foundations through Text objects use generated goals, with scenarios where
  state is needed. Repeat through Ex use scenarios.
- Every lesson has a page of roughly 150 to 250 words: a table of its keys and
  what each does, one example showing the text before and after with the keys
  typed, when to reach for it, and one common trap.
- Opening a lesson that is still new shows its page, then a learn round.
  The page of any lesson can be reopened at any time.
- Every section ends with a **review**: one round of twenty goals drawn evenly
  from the section's lessons, with keys hidden. It can be taken at any time.
- Passing a section review while some of its lessons are still new places
  those lessons as already known, so a learner can skip Foundations by passing
  its review. Not passing changes nothing.
- No lesson is locked. The map shows the order; the learner can open anything.

### Scheduling

- Review is scheduled per lesson in the same Leitner boxes, with the same
  intervals: 1, 3, 7, 14, 30 days.
- A passed learn round puts a new lesson in the first box. A learn round that
  is not passed leaves it new.
- A passed review round moves the lesson up a box. One that is not passed
  returns it to the first box.
- A lesson placed by a section review starts in the third box, as v2's
  diagnostic placed techniques.
- Map states are unchanged: new, shaky (boxes 1 and 2), solid (box 3 and up).
- Today's session is review rounds for up to three due lessons, oldest first,
  then the next new lesson.

### The shell

- `dojo` in a terminal opens the map: the sections and lessons in order, each
  lesson's state and when it is due, the section reviews, and the inbox count.
  The cursor starts on today's session, which says what it will review and
  teach.
- Enter on a lesson opens its page in the shell. From the page, Enter starts
  the round: a learn round if the lesson is new, a review round otherwise.
- Starting a round opens the learner's own Vim, with their config, on that
  round. When the round ends, or the learner quits Vim, they are back in the
  shell, which shows the round's summary and the updated map.
- A stats view shows, for each lesson, the clean count and the time per goal
  of its recent rounds.
- The shell is the only front end. `:Dojo`, `:DojoFocus`, `:DojoFree`, and the
  in-Vim map are removed when it lands. `:DojoNote` stays a Vim command.

### Mixed practice

- From the shell, the learner can start a mixed round over every lesson they
  have learned, or over chosen sections. Goals are drawn across those lessons,
  leaning toward due and shaky ones, with keys hidden.
- A mixed round ends after a number of goals, twenty by default, or after a
  time limit the learner picks. The summary shows goals done and goals clean.

### Custom drills and the inbox

- A v2 custom drill file still loads. It is a scenario: it joins the lesson
  that covers its `technique`, or a Custom section. Its solution is shown and
  counted and never run, as in v2.
- The friction inbox is unchanged. The shell shows how many notes are waiting
  and where.

## Constraints

- The runner stays pure Vimscript with no plugin dependencies, and needs no
  newer Vim than v2 does.
- The shell is Go. Its only dependencies outside the standard library are
  Bubble Tea and Lip Gloss.
- Lesson pages, snippets, and scenarios are original. vim-hero.com is a
  reference for the shape of a curriculum only; none of its lesson or exercise
  text is used.
- Lessons are data files that both the runner and the shell read, in a format
  each can parse with what it already has.
- The shell and the runner talk through files in the state directory. No
  sockets and no long-running Vim.
- Everything stays on the machine. Records hold counts and seconds, never the
  keys typed.
- Practice happens in the learner's own Vim with their own mappings.
- For every generator on every suitable snippet, and for every scenario, the
  target comes from running the solution. The test suite checks this.
- The headless suite stays, in its existing form. A second check sends real
  keys to Vim through tmux, because the headless suite cannot see how typed
  keys arrive. It is skipped where tmux is missing.

## Acceptance

Counting keys:

- **real-typing-count**: with `updatetime=100` and a `CursorHold` autocommand
  defined, typing `f=` on a goal with a pause before each key reports two
  keys, and `<CursorHold>` is not among them.
- **dot-still-one**: typed for real, `ciwqueued<Esc>j.j.` reports 14 keys.
- **typing-check**: the tmux check exists and fails on the v2 code.

Rounds and grading:

- **round-length**: starting practice on a lesson gives ten goals.
- **auto-advance**: solving a goal opens the next with no key pressed, and the
  panel shows the last goal's keys against par.
- **not-clean-shown**: after a goal that was not clean, the panel shows its
  par solution; the summary lists it again.
- **summary**: after the tenth goal the panel shows the clean count and time,
  and Enter leaves the round.
- **keys-pinned**: in a learn round the lesson's keys are in the panel for
  every goal; in a review round they are not.
- **hint-direct**: the first hint shows the solution keys, and that goal is
  not clean however few keys follow.
- **par-grading**: a goal solved without a hint in par plus two keys is clean
  whatever keys were used; in par plus three it is not. No detection pattern
  remains in the code.
- **box-by-round**: a review round with eight clean goals moves the lesson up
  a box; one with seven returns it to the first box; one left early moves
  nothing.
- **learn-pass**: a learn round with eight clean goals makes a new lesson
  shaky with a due date; one with seven leaves it new.

Generated goals and snippets:

- **generated-goal**: in the quotes lesson, a goal highlights one string in a
  snippet of at least 20 lines and asks for a change; `ci"`, the new text, and
  `<Esc>` solves it clean.
- **targets-from-vim**: for every generator, many random goals on every
  suitable snippet each have a solution that runs without error, changes
  something, and produces the recorded target.
- **no-short-walk**: no generated goal outside the lessons that teach
  `h j k l` or `x` can be solved within the clean threshold by those keys.
- **hop**: in a cursor lesson the buffer is not reloaded between goals, and
  each target is drawn from the cursor's current position.
- **goals-differ**: two rounds on one lesson differ in their goals.
- **snippet-set**: at least 24 snippets of 20 to 40 lines across the six
  kinds, and no lesson is offered a snippet with too few places for a round.
- **scenario-width**: every lesson that relies on scenarios has at least four.

Lessons and sections:

- **outline**: the map lists the eleven sections and their lessons in the
  order above, each section ending in a review.
- **page-shape**: every lesson's page has a key table, a before-and-after
  example, when to use it, and a trap.
- **page-first**: opening a new lesson shows its page before its first goal.
- **section-skip**: passing the Foundations review on a fresh state marks its
  four lessons solid, and they open in review rounds. Not passing leaves them
  new.
- **diagnostic-gone**: the diagnostic and its key are removed.
- **lesson-files**: no lesson content remains in Vimscript.

The shell:

- **shell-map**: `dojo` opens the map with every lesson's state; Enter on
  today's session starts it.
- **shell-page**: Enter on a lesson shows its page, which scrolls.
- **shell-round**: starting a round opens Vim on it; finishing, or quitting
  Vim, returns to the shell with the summary and the map updated.
- **shell-stats**: the stats view shows recent rounds per lesson.
- **one-front-end**: `:Dojo`, `:DojoFocus`, `:DojoFree`, and `map.vim` are
  gone; `:DojoNote` still writes an inbox entry.
- **nothing-raw-persisted**: after a session, no file in the state directory
  contains the keys typed. Carried over from v2.

Mixed practice:

- **mixed-round**: a mixed round draws goals from more than one learned
  lesson and shows no keys.
- **timed**: with a time limit, the round ends at the limit and the summary
  shows goals done and clean.

Custom drills:

- **custom-still-loads**: a v2 custom drill file appears in rounds for its
  lesson, with its par shown and its solution never run.

## Decisions

Confirmed by the author on 2026-11-26:

- **A thin Go shell, after the practice loop is rebuilt.** The shell improves
  none of the reps, text, or teaching problems, and the round it launches has
  to exist first. Vim starts in 70 to 95 ms with the author's config, and the
  engine already takes a plan as a list and writes one JSON record per
  attempt, so the seam is there.
- **One front end.** The in-Vim map is retired when the shell lands. Starting
  practice from inside a running Vim goes away with it.
- **Grade on keys against par.** Detection patterns miss valid keys (`_` for
  `^`) and withhold credit for a shorter route (`W` reaches the `=` that the
  `f=` drill aims at, in one key).
- **The outline above**, including Foundations, with a review that can be
  passed to skip a section.
- **Built-in snippets first.** Reading the learner's own repositories is left
  out.

These reverse v2 decisions, on the evidence of use:

- **Enter to continue** gives way to rounds that advance by themselves. The
  reading time v2 wanted to protect now sits in the page before a round and
  the summary after it.
- **Technique detection** gives way to par, as above.
- **Vim only** gives way to Go for everything outside a round.

Chosen while writing, open to change:

- **Goal generation lives in the runner.** Only Vim knows where `3w` lands or
  what `di(` removes, so the shell never models Vim.
- **Clean allows two keys over par**, the margin v2 used for diagnostic
  placement. It absorbs a typo and the way a mapping is counted. A single
  value in code.
- **Pass is eight in ten.** A single value in code.
- **A review round that is not passed returns the lesson to the first box.**
  v2 left a technique in place on a weak attempt, which with long intervals
  would hide a lesson for weeks after a bad round.
- **Section reviews replace the diagnostic.** Ten drills could place ten
  techniques at most; a review places a whole section.
- **The clue step of the hint ladder is removed.** Generated goals have no
  authored clue, and the clue was what the author kept pressing through.
- **Mixed practice does not move review boxes.** A handful of goals per lesson
  is too few to judge it. Mixed rounds feed stats only.
- **v2 progress is not carried over.** It was graded by the broken key count,
  and there are 19 finished attempts. The files are left where they are.
- **A lesson file is a Markdown page with one fenced JSON block** holding its
  id, keys, generators, and scenarios. Vim has JSON built in and so does Go's
  standard library; neither needs a new parser.
- **Lesson pages are rendered by the shell itself**, without a Markdown
  library, since a page is headings, paragraphs, a table, and a code block.

## Open questions

None. Slice 1 settled the two it was given:

- **Whether dropped keys follow any pause longer than `updatetime`.** Yes,
  whatever the setting. After waiting `updatetime` for a key, Vim's
  `before_blocking()` calls `updatescript(0)`, which writes a NUL into the
  buffer `typedchar` is read from (`getchar.c`, 9.1.0597), so the next key's
  `typedchar` reads empty. `<CursorHold>` is returned without that call, so it
  keeps its `typedchar`.
- **How the replay filter is rebuilt.** It is kept, not replaced. A key still
  counts when it has a `typedchar`, and also when it arrives `updatetime` or
  more after the previous key event. Replays, `x`-style expansions, and
  mapping tails arrive with no wait, so they stay uncounted. Pseudo-keys
  (`<CursorHold>`, `<Ignore>`, focus and mouse-move events) are dropped by
  name. `v:event.typed` cannot replace `typedchar`: it is true for keys
  replayed by `.`, which inherit it from the key that started them. The
  `SafeState` candidate was not needed; it would fail on typeahead, where
  `SafeState` does not fire.

## Out of scope

- Snippets drawn from the learner's own repositories.
- Neovim support.
- A watcher that observes real editing.
- Belts, streaks, and leaderboards.
- Templates in custom drill JSON, and generators in custom drills.
- An in-plugin or in-shell LLM call.
- Locking lessons until earlier ones are passed.
- A web front end.

## Delivery

Slices in build order. Each leaves the dojo usable. Slices 1 to 4 are Vim
only; the v2 map keeps working until slice 5 replaces it.

1. **Key counting** (real-typing-count, dot-still-one, typing-check).
   `s:Capture` and `s:Key` in `autoload/vim_dojo.vim`. Write the tmux check
   first and watch it fail. Settles both open questions. Done 2026-11-26:
   `test/typing.sh` failed on v2 (`You: <CursorHold>`, 13 keys for the dot
   drill) and passes now.
2. **Rounds and par grading** (round-length, auto-advance, not-clean-shown,
   summary, keys-pinned, hint-direct, par-grading, box-by-round, learn-pass).
   Runs on the existing drills, so it can be tried with `:DojoFocus` before
   any new content exists. Removes `detect` from every technique and
   `vim_dojo#drills#Detect`; rewrites `progress#State`, `Plan`, and `Focus`
   around rounds. Done 2026-11-26. Until slice 4 gives each lesson a key
   table, a learn round pins the technique's keys, name, and two-line card.
   The clue and `why` text left the built-in drills, and custom files no
   longer need them. A custom drill with no solution has no par and is clean
   when solved without a hint. The diagnostic places on a clean goal. Old
   records stay readable but move no box.
3. **Generated goals and snippets** (generated-goal, targets-from-vim,
   no-short-walk, hop, goals-differ, snippet-set). Adds the generator
   interpreter beside `vim_dojo#drills#Instance`, and the snippet files.
   Start with one cursor lesson and one edit lesson end to end, then widen.
   Done 2026-11-26 for `word`, `find-char`, `quote`, and `paren`. Until
   slice 4, generators sit in `lessons/<id>.json`, one JSON object per
   lesson that slice 4 wraps in its Markdown page unchanged: `id`, `moves`
   for a cursor lesson, an optional `snippets` list of filetypes, and
   `generators`. A generator has `keys` in key notation, optional `vars` as
   in v2 templates, `at` (a Vim pattern for a place, found per line with
   `matchstrlist`), `cursor` (`inside`, `first`, `last`), `side` (`after` or
   `before` the cursor, for cursor lessons), and `goal`. `{0}` to `{9}` in
   `keys` and `goal` are the place's text and submatches. Patterns cannot
   refer to the cursor: `matchstrlist` and `matchbufline` ignore `\%.l`,
   hence `side`. Snippets are `snippets/*.{go,py,ts,html,md,yaml,toml,json}`,
   typed by extension, four per kind. A round is drawn on one snippet when
   it opens; a lesson that edits is offered a snippet only with ten places.
   Besides the spec's rules, a goal is also thrown away when it repeats one
   in the round, when an edit changes anything outside its highlighted
   place, and when a cursor goal's keys reach the target before their last
   key, as `f,;` with no second comma, which would overstate par. With that
   rule `;` gets goals; `,` does not, since from a fresh start it is never
   the shortest way. A cursor round starts a goal somewhere fresh after 40
   draws in a row find nothing from the last target, about one goal in 35
   for `find-char` and none seen for `word`. Rounds open in 20 to 130 ms.
   An edit that adds or removes lines is never kept yet; `dd` will need it.
   In a lesson with generators, rounds are generated only, so custom drills
   for those four lessons are not in their rounds until slice 4 mixes
   scenarios in. Fixed on the way: a lambda parameter named `count` reads
   `v:count` in legacy script, so every demo frame had shown the finished
   solution.
4. **Lessons and sections** (outline, page-shape, page-first, section-skip,
   diagnostic-gone, lesson-files, scenario-width, custom-still-loads). Moves
   content out of `autoload/vim_dojo/skills/*.vim` into lesson files, re-cut
   to the outline. The bulk of the work by volume; each section can land
   separately. Until slice 5, a page opens as a read-only buffer in the dojo
   tab. Settled with the author on 2026-11-26:
   - `lessons/outline.json` lists the sections in order, each with `id`,
     `name`, and its lesson ids in order. It is the only place order is set.
   - `lessons/<id>.md` is the page, ending with one fence opened by exactly
     ` ```json `; only blank lines may follow it. The page is everything
     above. The JSON holds `id`, `title` (what the map shows), `keys` as
     `[key, a few words]` pairs pinned in a learn round, optional `moves` and
     `snippets`, `generators`, and `scenarios`, which are v2 drill dicts
     unchanged. A page has a `| Key | What it does |` table naming every
     pinned key, `## Example` with a before and an after block, `## When to
     use it`, and `## The trap`.
   - In a lesson with generators, a round is its generated goals followed by
     up to three scenarios and custom drills, least recently tried first and
     untried custom drills before untried built-in ones, so a cursor
     lesson's hops are unbroken. A placeholder names its `lesson`.
   - v2 ids are kept where a lesson keeps its meaning. `counts`, `join`,
     `paren`, `brace`, `insert-at`, and `put` were renamed or folded; a
     custom drill naming one joins the new lesson, and one naming an unknown
     technique stands in Custom instead of being skipped. Round records under
     retired ids are ignored, not migrated.
   - Internal names stay `technique` and `skill` until slice 5, and records
     keep the `technique` field.
   - A learn round on a lesson still new opens on its page; Enter starts it.
     `p` on a map row opens a page below the map.
   - `,` has no goals: from a fresh start it is never the shortest key. Its
     page teaches it.
   - A scenario may name `marked`, marks set before it starts, as
     `{"a": "text the mark sits on"}`. Template values fill dict fields,
     keys included.
   - `para-object` uses scenarios only: a paragraph spans lines, which the
     edit check cannot place. `word-object` draws on code snippets only.
   - Done 2026-11-26: all 53 lessons are Markdown pages, one commit per
     section. `autoload/vim_dojo/skills` and the v2 bridge are gone, and v2
     drills the tests use live on as scenarios under their old ids. Page
     length is checked at 150 to 260 words.
5. **The shell** (shell-map, shell-page, shell-round, shell-stats,
   one-front-end, nothing-raw-persisted). Go module at the repository root.
   Ports `progress#State` and the session plan to Go, which then owns them;
   the runner takes a round request and writes goal records. Deletes
   `map.vim` and the planning half of `progress.vim`. Done 2026-11-26:
   - `dojo.go` holds the catalog, records, `State`, `Plan`, and `Draw`;
     `main.go` the Bubble Tea map, page, and stats views. Built with
     `go build -o dojo .`; the binary finds the lessons beside itself through
     a symlink, or at `VIM_DOJO_ROOT`. `snippets/go.mod` keeps the practice
     Go files out of the module.
   - The shell writes `round.json` in the state directory and runs
     `vim -c 'set rtp^=<root>' -c 'call vim_dojo#Run(<path>)'`. The request
     names goals by lesson, as `generated` or a `drill` id, with `demo`,
     `place` (the lessons a passed section review places), and `drills`,
     the custom drill directory, so both sides read the same one. The state
     directory is the request's directory. Enter at the summary, or
     `:DojoClose`, runs `confirm qall`.
   - When Vim exits, the shell reads the records that appeared since it
     started: a round record gives the summary line, otherwise it says the
     round was left after so many goals. The detailed not-clean list stays
     in Vim's panel, since records never hold solutions. The summary stays
     pinned above the map's legend; the cursor keeps its row.
   - Each round of a session is its own Vim. A round left early ends the
     session. A session's learn round on a new lesson opens on its page in
     the shell; the runner no longer shows pages, and takes one round.
   - `VIM_DOJO_STATE_DIR` and `VIM_DOJO_DRILL_DIR` replace the `g:` settings
     for learners; Vim still honours the `g:` ones, which the suite uses.
   - The shell checks a custom drill's id, goal, lines, and lesson only;
     a file Vim then rejects drops out of its round.
   - `dojo.vim` is gone with `:Dojo`. The suite builds rounds itself;
     scheduling, the plan, section draws, the map, pages, and stats are
     tested in `dojo_test.go`; `test/typing.sh` plays a round from the
     shell through tmux, finishing one and quitting another.
6. **Mixed practice** (mixed-round, timed).
