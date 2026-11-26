# Vim Dojo

Editing practice in your own Vim. The dojo teaches one technique at a time in
rounds of ten goals, counts the keys you use against par, and brings techniques
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
| `:Dojo` | Resume the session in progress, or open the skill map. |
| `:DojoFocus {technique}` | Practise one technique, with completion. |
| `:DojoFree` | Practise one random drill. |
| `:[range]DojoNote [text]` | Save lines you found awkward to edit to the inbox. |

## The skill map

```
Vim Dojo                                    2 due today · 1 in inbox

  ▶ Start today's session        review f t ; ,  ·  learn i( a(

Move               ●●◐◐○○○    2 of 7 solid
  ● w b e            solid     due in 6 days
  ◐ f t ; ,          shaky     due today
  ○ { }              new
Objects            ◐○○○○○     0 of 6 solid

  ○ new   ◐ shaky   ● solid       Enter practise · d diagnostic · q close
```

Every technique the dojo teaches is listed under its skill: **new** if you
have never tried it, **shaky** while you are still learning it, **solid** once
you recall it reliably, with when it is next due. Press Enter on the session
row to start today’s session, on a skill to open or close it, or on a technique
to practise just that one. `d` runs the diagnostic, `q` closes the map.

Today's session is a review round for each of up to three due techniques,
oldest first, then a learn round on the next new technique in the curriculum.
A technique you open from the map gets a learn round while it is new and a
review round after that.

The diagnostic is about ten goals across the skills, with no hints. A goal you
solve clean places its technique as already known. Everything else stays new.
Leave it whenever you like.

## Practising

| Key | Command | Action |
| --- | --- | --- |
| `<LocalLeader>h` | `:DojoHint` | The solution keys, then a demo. Any hint makes the goal not clean. |
| `<LocalLeader>r` | `:DojoReset` | Restore the goal and starting cursor. |
| `<LocalLeader>s` | `:DojoSkip` | Move to the next goal, which is not clean. |
| `Enter` | `:DojoNext` | Leave a round's summary. During a round Enter is not mapped. |
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

A learn round keeps the technique’s keys in the panel; a review round does not.
The first goal of a technique’s first learn round is played for you before it
is handed over. After the tenth goal, the summary shows how many were clean,
the time taken, and each goal that was not clean, and points out an obvious
long way round, such as arrow keys or repeated `x`.

A round with eight clean goals passes. A passed learn round puts the technique
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
`g:vim_dojo_drill_dir` to your own directory. Custom drills join the random
pool, and appear on the map under their technique, their skill, or Custom. See
`:messages` for skipped files.

```json
{
  "id": "raise-timeout",
  "ft": "python",
  "lines": ["TIMEOUT = 29", "RETRIES = 3"],
  "start": "TIMEOUT",
  "expected": ["TIMEOUT = 30", "RETRIES = 3"],
  "skill": "ex",
  "technique": "increment",
  "solution": "<C-A>",
  "goal": "Increase the timeout by one.",
  "keys": "Ctrl-A"
}
```

`id`, `lines`, and `goal` are required, with `expected` (the
buffer when solved), or `target` (text the cursor must reach, for a drill that
only moves). The rest are optional. `ft` sets the filetype; `start` is text the
cursor starts on; `skill` and `technique` place the drill on the map;
`solution` is the keys in Vim notation, which gives the drill a par. A drill
without one is clean when solved without a hint. The dojo shows and counts a
custom solution but never runs it, so custom drills have no demo. A file whose
`id` a built-in drill has since taken loads as `custom-` plus that id. `keys` is display text for the hint, and is
required when there is no `solution`. A `hint` or `why` from an older file is
ignored.

To generate one, ask your model for “one Vim editing drill as JSON following
the example below. Pick a technique from this list: (paste the technique names
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
as JSON, in the format below, that practises the technique that would have
made this edit easy. Keep the text close to mine.” followed by the example
from Custom drills above.

## Development

Run the checks from this directory with
`vim -Nu NONE -i NONE -n -es -S test/dojo.vim`. Set `DOJO_SKILL=move` to check
the drill solutions of one skill only. `sh test/typing.sh` types real keys
into Vim through tmux, with pauses, and is skipped where tmux is missing.
