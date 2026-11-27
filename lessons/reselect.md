# o gv

While selecting, `o` moves the cursor to the other end of the selection, so
you can grow or shrink the start as well as the end. After a selection has
ended, because a command used it, `gv` selects exactly the same text again
for a second command.

| Key | What it does |
| --- | --- |
| `o` | Jump to the other end of the selection |
| `gv` | Select the last selection again |

## Example

The cursor, shown as `[ ]`, is on the first of three unsorted imports:

```text
import (
["]strings"
"fmt"
"os"
)
```

Type `Vjj`, then `:sort` and Enter, then `gv>`:

```text
import (
        ["]fmt"
        "os"
        "strings"
)
```

The sort ended the selection, and `gv` brought it back for the indent.

## When to use it

`gv` when two commands should act on the same lines or text: sort then
indent, change case then shift. `o` when the selection started in the wrong
place, typically a word or line too late, to fix the start without
selecting again from scratch.

## The trap

Selecting the same lines again by hand, and getting them slightly wrong the
second time. `gv` cannot miscount. And when a selection grew too far the
wrong way, do not press `Esc` and start over; `o` turns round and lets you
adjust that end.

```json
{
  "id": "reselect",
  "title": "o gv",
  "keys": [["o", "other end of the selection"], ["gv", "select the last selection again"]],
  "scenarios": [
    {"id": "sort-imports", "ft": "go", "start": "\"{c}\"",
     "vars": {"pkgs": [{"a": "fmt", "b": "os", "c": "strings"}, {"a": "bufio", "b": "io", "c": "sort"},
                       {"a": "errors", "b": "net", "c": "time"}]},
     "goal": "Sort the three imports, then indent them one level.",
     "lines": ["import (", "\"{c}\"", "\"{a}\"", "\"{b}\"", ")"],
     "solution": "Vjj:sort<CR>gv>"},
    {"id": "grow-back", "ft": "text", "start": "import",
     "vars": {"adj": ["failed", "stuck", "partial"], "when": ["twice", "tonight", "at noon"]},
     "goal": "Change \"{adj} import job\" to \"export\".",
     "lines": ["Retry the {adj} import job {when}."],
     "solution": "veeobcexport<Esc>"},
    {"id": "indent-twice", "ft": "python", "start": "step_one",
     "vars": {"cond": ["ready", "cfg.enabled", "not dry_run"]},
     "goal": "Indent the last two lines two levels.",
     "lines": ["def run():", "    if {cond}:", "step_one()", "step_two()"],
     "solution": "Vj>gv>"},
    {"id": "sort-upper", "ft": "yaml", "start": "- {c}",
     "vars": {"codes": [{"a": "ams", "b": "lhr", "c": "sfo"}, {"a": "cdg", "b": "fra", "c": "nrt"},
                        {"a": "bos", "b": "dub", "c": "syd"}]},
     "goal": "Sort the three airport codes, then make them uppercase.",
     "lines": ["airports:", "- {c}", "- {a}", "- {b}"],
     "solution": "Vjj:sort<CR>gvU"}
  ]
}
```
