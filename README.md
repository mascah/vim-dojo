# Vim Dojo

Editing practice in your own Vim. The dojo teaches one lesson at a time in
rounds of ten goals, counts the keys you use against par, and brings lessons
back for review when they are due. Practice happens in scratch buffers with your own
mappings.

Vim Dojo needs Vim 9.1.0597 or later and Go to build its shell. From this
directory:

```sh
go build -o dojo .
ln -s "$PWD/dojo" ~/.local/bin/dojo
dojo
```

`dojo` opens the map in your terminal. Each round runs in your own `vim`, with
your config, and you are back at the map when it ends. The shell finds the
lessons next to the binary, following the link; set `VIM_DOJO_ROOT` to this
directory if you move the binary instead.

For `:DojoNote` in your everyday Vim, install this repository as a Vim package
under `~/.vim/pack/dojo/start/vim-dojo`. It is the dojo's only Vim command.

## The map

```
Vim Dojo                                    2 due today · 1 in inbox

  ▶ Start today's session        review w b e  ·  learn I A
  ▶ Mixed practice

Foundations           ●●◐◐       2 of 4 solid
  ● modes and Esc     solid     due in 6 days
  ● h j k l           solid     due in 9 days
  ◐ w b e             shaky     due today
  ◐ i a               shaky     due tomorrow
  ▷ Review Foundations
Entering Insert       ○○○○       0 of 4 solid

○ new  ◐ shaky  ● solid   Enter open · s stats · q quit
```

The curriculum is eleven sections of small lessons, listed in teaching order
in `lessons/outline.json`. Each lesson is **new** until you pass a learn round
on it, **shaky** while you are still learning it, and **solid** once you recall
it reliably, with when it is next due. Move with `j` and `k`. Enter on the
session row starts today's session. Enter on a lesson opens its page, which
scrolls with `j`, `k`, and Space; Enter there starts a learn round while the
lesson is new and a review round after that. `s` shows stats: the clean count
and seconds per goal of each lesson's recent rounds. `q` quits.

Today's session is a review round for each of up to three due lessons, oldest
first, then a learn round on the next new lesson, which opens on its page.
After each round the map shows how it went, and Enter on the session row
starts the next. Leaving a round early, by quitting Vim, ends the session.

Every section ends in a review: twenty goals drawn evenly from its lessons,
with the keys hidden. Take it whenever you like. Passing it places the
section's new lessons as already known, so you can skip what you know.
Not passing changes nothing.

Mixed practice draws goals across every lesson you have learned, leaning
toward due and shaky ones, with the keys hidden. In its view, Space on a
section limits the round to the sections you choose, and `h` and `l` set its
length: 10, 20, or 40 goals, or 2, 5, or 10 minutes. A timed round ends at
the limit, and goes round its goals again if you get through them first.
Mixed rounds move no lesson's box; stats show them on a line of their own.

## Practising

| Key | Command | Action |
| --- | --- | --- |
| `<LocalLeader>h` | `:DojoHint` | The solution keys, then a demo. Any hint makes the goal not clean. |
| `<LocalLeader>r` | `:DojoReset` | Restore the goal and starting cursor. |
| `<LocalLeader>s` | `:DojoSkip` | Move to the next goal, which is not clean. |
| `Enter` | `:DojoNext` | Leave a round's summary, back to the map. During a round Enter is not mapped. |
| | `:DojoCheck` | Show where the attempt stands. |
| | `:DojoClose` | Leave the round, back to the map. |

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
`VIM_DOJO_STATE_DIR` in your environment to choose another location; the
shell, its rounds, and `:DojoNote` all read it. The shell hands Vim each round
in `round.json` there. Progress
from v2 of the dojo, graded by a key count that dropped keys, does not carry
over; its files are left in place.

## Custom drills

Save one JSON object per `.json` file in `~/.vim/vim-dojo/drills/`, or set
`VIM_DOJO_DRILL_DIR` to your own directory. A custom drill joins the rounds
of the lesson its `technique` names, after the generated goals, or stands as a
lesson of its own under Custom. A file Vim cannot load is left out of its
round; see `:messages` there.

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
from `lessons/outline.json`). Give the starting lines, an exact expected buffer,
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
`vim -Nu NONE -i NONE -n -es -S test/dojo.vim` for the runner and `go test .`
for the shell. Set `DOJO_SECTION=foundations` to check the drill solutions of one
section only. `sh test/typing.sh` types real keys into Vim through tmux, with
pauses, and plays a round from the shell end to end; it is skipped where tmux
is missing.
