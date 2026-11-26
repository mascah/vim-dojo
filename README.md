# Vim Dojo

Editing practice in your own Vim. The dojo teaches one lesson at a time in
rounds of ten goals, counts the keys you use against par, and brings lessons
back for review when they are due. Practice happens in scratch buffers with your own
mappings.

Vim Dojo needs Vim 9.1.0597 or later. From this directory:

```sh
vim -S dojo.vim
```

For automatic command registration, install this repository as a Vim package under
`~/.vim/pack/dojo/start/vim-dojo` and restart Vim. From a Vim session you
already have open, `:source` this repo’s `dojo.vim`.

| Command | What it does |
| --- | --- |
| `:Dojo` | Resume the session in progress, or open the map. |
| `:DojoFocus {lesson}` | Practise one lesson, with completion. |
| `:DojoFree` | Practise one random drill. |
| `:[range]DojoNote [text]` | Save lines you found awkward to edit to the inbox. |

## The map

```
Vim Dojo                                    2 due today · 1 in inbox

  ▶ Start today's session        review w b e  ·  learn I A

Foundations           ●●◐◐       2 of 4 solid
  ● modes and Esc     solid     due in 6 days
  ● h j k l           solid     due in 9 days
  ◐ w b e             shaky     due today
  ◐ i a               shaky     due tomorrow
  ▷ Review Foundations
Entering Insert       ○○○○       0 of 4 solid

  ○ new  ◐ shaky  ● solid   Enter practise · p page · q close
```

The curriculum is eleven sections of small lessons, listed in teaching order
in `lessons/outline.json`. Each lesson is **new** until you pass a learn round
on it, **shaky** while you are still learning it, and **solid** once you recall
it reliably, with when it is next due. Press Enter on the session row to start
today's session, on a section to open or close it, or on a lesson to practise
just that one. `p` opens a lesson's page, `q` closes the map.

Today's session is a review round for each of up to three due lessons, oldest
first, then a learn round on the next new lesson. A lesson you open from the
map gets a learn round while it is new, which starts on its page, and a review
round after that.

Every section ends in a review: twenty goals drawn evenly from its lessons,
with the keys hidden. Take it whenever you like. Passing it places the
section's new lessons as already known, so you can skip what you know.
Not passing changes nothing.

## Practising

| Key | Command | Action |
| --- | --- | --- |
| `<LocalLeader>h` | `:DojoHint` | The solution keys, then a demo. Any hint makes the goal not clean. |
| `<LocalLeader>r` | `:DojoReset` | Restore the goal and starting cursor. |
| `<LocalLeader>s` | `:DojoSkip` | Move to the next goal, which is not clean. |
| `Enter` | `:DojoNext` | Leave a lesson's page or a round's summary. During a round Enter is not mapped. |
| | `:DojoCheck` | Show where the attempt stands. |
| | `:DojoClose` | Close the practice tab. |

`<LocalLeader>` is `\` unless you have set `maplocalleader`.

There is no check key. The dojo checks after every Normal-mode change, when you
leave Insert mode, and when the cursor moves, and opens the next goal as soon as
one is solved. Text that has to change is highlighted, and so is the target of a
goal that only moves the cursor, except where finding it is the exercise. Put
`let g:vim_dojo_highlight = 0` in your vimrc to turn the highlight off.

A goal is **clean** when you solve it without a hint in at most two keys more
than par, the length of the dojo’s solution. Which keys you use does not
matter. While the next goal is up, the panel shows how the last one went, with
the par solution if it was not clean:

```
Last: 15 keys · par 11 · try c i " r a t c h e t <Esc>
```

A learn round keeps the lesson’s keys in the panel; a review round does not.
The first goal of a lesson’s first learn round is played for you before it
is handed over. After the tenth goal, the summary shows how many were clean,
the time taken, and each goal that was not clean, and points out an obvious
long way round, such as arrow keys or repeated `x`.

A round with eight clean goals passes. A passed learn round puts the lesson
in the first review box; one that does not pass leaves it new. A passed review
round moves it up a box, and one that does not pass sends it back to the first.
Review intervals are 1, 3, 7, 14, and 30 days. Leaving a round early keeps the
goals you did in the record and moves nothing.

The demo plays one key every 400 milliseconds. Set `g:vim_dojo_demo_delay` to
another number of milliseconds to change that.

## Your data

Everything stays on this machine. The dojo records drill IDs, times, outcomes,
key counts, seconds, and each round's clean count in `${XDG_STATE_HOME:-$HOME/.local/state}/vim-dojo`,
never the keys you typed. Key capture covers only the practice buffer. Set
`g:vim_dojo_state_dir` before starting to choose another location. Progress
from v2 of the dojo, graded by a key count that dropped keys, does not carry
over; its files are left in place.

## Custom drills

Save one JSON object per `.json` file in `~/.vim/vim-dojo/drills/`, or set
`g:vim_dojo_drill_dir` to your own directory. A custom drill joins the rounds
of the lesson its `technique` names, after the generated goals, or stands as a
lesson of its own under Custom. See `:messages` for skipped files.

```json
{
  "id": "raise-timeout",
  "ft": "python",
  "lines": ["TIMEOUT = 29", "RETRIES = 3"],
  "start": "TIMEOUT",
  "expected": ["TIMEOUT = 30", "RETRIES = 3"],
  "technique": "increment",
  "solution": "<C-A>",
  "goal": "Increase the timeout by one.",
  "keys": "Ctrl-A"
}
```

`id`, `lines`, and `goal` are required, with `expected` (the
buffer when solved), or `target` (text the cursor must reach, for a drill that
only moves). The rest are optional. `ft` sets the filetype; `start` is text the
cursor starts on; `technique` is the id of the lesson the drill joins;
`solution` is the keys in Vim notation, which gives the drill a par. A drill
without one is clean when solved without a hint. The dojo shows and counts a
custom solution but never runs it, so custom drills have no demo. A file whose
`id` a built-in drill has since taken loads as `custom-` plus that id. `keys` is display text for the hint, and is
required when there is no `solution`. A `hint` or `why` from an older file is
ignored, and so is a `skill`.

To generate one, ask your model for “one Vim editing drill as JSON following
the example below. Pick a lesson from this list: (paste the lesson ids
from `:DojoFocus <Tab>`). Give the starting lines, an exact expected buffer,
the text the cursor starts on, and the shortest solution in Vim key notation. Use a unique
lowercase slug as the ID. Return only JSON.” You can paste a sample of the kind
of text you edit.

## Friction inbox

When an edit in your real work feels clumsy, select the lines or put the cursor
on one and run `:DojoNote` with an optional note, such as
`:'<,'>DojoNote took me ages to swap these`. The dojo saves just those lines,
the filetype, and the note to `inbox/` in the state directory. It reads
nothing else from your buffers, and only when you run the command. The map
shows how many notes are waiting and where.

To turn a note into a drill, give your model the note file with: “Here is some
text I found awkward to edit in Vim, with my note. Write one Vim editing drill
as JSON, in the format below, that practises the lesson that would have
made this edit easy. Keep the text close to mine.” followed by the example
from Custom drills above.

## Development

Run the checks from this directory with
`vim -Nu NONE -i NONE -n -es -S test/dojo.vim`. Set `DOJO_SKILL=foundations` to check
the drill solutions of one section only. `sh test/typing.sh` types real keys
into Vim through tmux, with pauses, and is skipped where tmux is missing.
