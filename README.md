# Vim Dojo

Five minutes of editing practice in your own Vim. Practice in scratch buffers with your own mappings. Choose a coached session,
a single drill, or a lesson path.

From this directory, start a session with Vim 9 or later.

```sh
vim -S dojo.vim
```

For automatic command registration, install this repository as a Vim package under
`~/.vim/pack/dojo/start/vim-dojo` and restart Vim.

| Command | What opens |
| --- | --- |
| `:Dojo` | Resume the active session, or start three history-based coached drills. |
| `:DojoFree` | Start one randomly selected drill from the full catalog. |
| `:DojoCatalog` | Browse goals with `j`/`k`, press Enter to practice, or `q` to leave. Each row shows completion, lifetime attempts, skill, and goal. |
| `:DojoLessons` | Practice unfinished lessons in order, from basic motions through text objects, repeated edits, and jumps. |

Starting a drill or lesson path replaces the current practice task. Opening a task
counts as one attempt. Resetting it keeps that attempt. Solving with or without
hints completes the lesson across all modes. A skipped or abandoned lesson will
appear again the next time you start the path.

From a Vim session you already have open, source this repo’s `dojo.vim`
with `:source`. Use `:Dojo` to resume or start your next session.

| Key | Command | Action |
| --- | --- | --- |
| `F5` | `:DojoCheck` | Check the result. Press again to continue after solving. |
| `F6` | `:DojoHint` | Get a clue. Press again for the keys. |
| `F7` | `:DojoReset` | Restore the task and starting cursor. |
| `F8` | `:DojoSkip` | Move to the next task. |
| `F9` | `:DojoUsed` | After solving without hints, confirm you used the suggested technique and continue. |
| | `:DojoClose` | Close the practice tab. |

Use any technique that gives the requested result. For a search and jump-back
task, check once at the definition and again when you return to the call site.
The drills use scratch buffers, so you can experiment and reset as often as you
like.

Progress stays on this machine. The dojo saves drill IDs, times, and outcomes in
`${XDG_STATE_HOME:-$HOME/.local/state}/vim-dojo`. Set `g:vim_dojo_state_dir`
before starting to choose another location. The next session uses your history
to vary the exercises and bring back skills due for review.

## Generate a drill with your LLM

Ask your model for “one Vim editing puzzle as JSON following the example below.
Start the cursor at the first character. Give an exact target buffer, a clue,
suggested Vim keys, and a short explanation. Use a unique lowercase slug as the
ID. Return only JSON.” You can specify a technique or paste a sample of the kind
of text you edit.

```json
{
  "id": "raise-timeout",
  "lines": ["timeout = 29"],
  "expected": ["timeout = 30"],
  "goal": "Increase the timeout by one.",
  "hint": "Vim can increment the next number on the line.",
  "keys": "Ctrl-A",
  "why": "Ctrl-A finds and increments the number without entering Insert mode."
}
```

Save one object per `.json` file in `~/.vim/vim-dojo/drills/` or set
`g:vim_dojo_drill_dir` to your own directory. Open the catalog to try it.
Custom drills join the random pool. Vim displays suggested keys as text and
checks your edited buffer against `expected`. See `:messages` for skipped files.

Run the checks from this directory with
`vim -Nu NONE -i NONE -n -es -S test/dojo.vim`.
