# Vim Dojo

Five minutes of editing practice in your own Vim. The dojo teaches one technique
at a time, watches how you solve each drill, and brings techniques back for
review when they are due. Practice happens in scratch buffers with your own
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

A session reviews what is due, then practises the next new technique in the
curriculum. The first time you meet a technique, the dojo shows a short card
and plays the solution in the buffer, then hands you the same drill.

The diagnostic is about ten drills across the skills, with no cards and no
hints. A technique you solve with it, within two keys of par, is placed as
already known. Everything else stays new. Leave it whenever you like.

## Practising

| Key | Command | Action |
| --- | --- | --- |
| `<LocalLeader>h` | `:DojoHint` | A clue, then the keys, then a demo. Any hint marks the drill assisted. |
| `<LocalLeader>r` | `:DojoReset` | Restore the drill and starting cursor. |
| `<LocalLeader>s` | `:DojoSkip` | Move to the next drill. |
| `Enter` | `:DojoNext` | Continue once the drill is solved. Until then Enter is not mapped. |
| | `:DojoCheck` | Show where the attempt stands. |
| | `:DojoClose` | Close the practice tab. |

`<LocalLeader>` is `\` unless you have set `maplocalleader`.

There is no check key. The dojo checks after every Normal-mode change, when you
leave Insert mode, and when the cursor moves. Text that has to change is
highlighted, and so is the target of a drill that only moves the cursor, except
where finding it is the exercise. Put `let g:vim_dojo_highlight = 0` in your
vimrc to turn the highlight off.

Any technique that gives the requested result solves the drill. When you solve
it, the panel shows your keys against par, the length of the dojo’s solution:

```
Solved in 15 keys · par 11
You: x x x x x x i r a t c h e t <Esc>
Try: c i " r a t c h e t <Esc>
```

Using the drill’s technique without a hint counts as **recalled** and moves it
up a review box. Solving another way counts as **solved**, and a hint makes it
**assisted**; both leave it where it is. A skip sends it back to the first box.
Review intervals are 1, 3, 7, 14, and 30 days.

The demo plays one key every 400 milliseconds. Set `g:vim_dojo_demo_delay` to
another number of milliseconds to change that.

## Your data

Everything stays on this machine. The dojo records drill IDs, times, outcomes,
key counts, and seconds in `${XDG_STATE_HOME:-$HOME/.local/state}/vim-dojo`,
never the keys you typed. Key capture covers only the practice buffer. Set
`g:vim_dojo_state_dir` before starting to choose another location. Progress
from earlier versions of the dojo still counts.

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
  "hint": "Vim can increment the next number on the line.",
  "keys": "Ctrl-A",
  "why": "Ctrl-A finds and increments the number without entering Insert mode."
}
```

`id`, `lines`, `goal`, `hint`, and `why` are required, with `expected` (the
buffer when solved), or `target` (text the cursor must reach, for a drill that
only moves). The rest are optional. `ft` sets the filetype; `start` is text the
cursor starts on; `skill` and `technique` place the drill on the map;
`solution` is the keys in Vim notation, which gives the drill a par and, with
a `technique`, detection of whether you used it. The dojo shows and counts a
custom solution but never runs it, so custom drills have no demo. A file whose
`id` a built-in drill has since taken loads as `custom-` plus that id. `keys` is display text for the hint, and is
required when there is no `solution`.

To generate one, ask your model for “one Vim editing drill as JSON following
the example below. Pick a technique from this list: (paste the technique names
from `:DojoFocus <Tab>`). Give the starting lines, an exact expected buffer,
the text the cursor starts on, the shortest solution in Vim key notation, a
clue that does not give the keys away, and a one-line explanation. Use a unique
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
the drill solutions of one skill only.
