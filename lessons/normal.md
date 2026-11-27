# :normal

`:normal` runs Normal-mode keys from the command line, as if you typed them.
With a range, it runs them on each line in turn, starting from the start of
the line: `:%norm A;` appends a semicolon to every line in the file.
`:norm` is short for it, and after `:g` it acts on just the matching lines.

| Key | What it does |
| --- | --- |
| `:%norm {keys}` | Type `{keys}` on every line |
| `:2,4norm {keys}` | Type `{keys}` on lines 2 to 4 |
| `:g/{pattern}/norm {keys}` | Type `{keys}` on every matching line |

## Example

Five settings each need a semicolon at the end:

```text
const retries = 3
const timeout = 30
const verbose = false
const region = "eu"
const port = 8080
```

Type `:%norm A;` and Enter:

```text
const retries = 3;
const timeout = 30;
const verbose = false;
const region = "eu";
const port = 8080;
```

## When to use it

When one short edit is needed on many lines picked out by a range or by
`:g`. It is a one-line macro that needs no recording.

## The trap

Trying to end Insert mode inside the keys. Typing `Esc` on the command line
cancels the whole command, so `:norm` keys must end in Insert mode or not
use it at all. It finishes Insert mode by itself after each line, so `A;`
needs nothing after it.

```json
{
  "id": "normal",
  "title": ":normal",
  "keys": [[":%norm {keys}", "type the keys on every line"], [":2,4norm {keys}", "on lines 2 to 4"],
           [":g/{pattern}/norm {keys}", "on every matching line"]],
  "scenarios": [
    {"id": "end-lines", "ft": "{ft}",
     "vars": {"set": [
       {"ft": "javascript", "end": ";", "what": "a semicolon", "l1": "const retries = 3",
        "l2": "const timeout = 30", "l3": "const verbose = false", "l4": "const region = \"eu\"", "l5": "const port = 8080"},
       {"ft": "python", "end": ",", "what": "a comma", "l1": "    \"alpha\"", "l2": "    \"beta\"",
        "l3": "    \"gamma\"", "l4": "    \"delta\"", "l5": "    \"epsilon\""},
       {"ft": "css", "end": ";", "what": "a semicolon", "l1": "  color: red", "l2": "  margin: 0",
        "l3": "  padding: 4px", "l4": "  border: none", "l5": "  display: block"}]},
     "goal": "End every line with {what}.",
     "lines": ["{l1}", "{l2}", "{l3}", "{l4}", "{l5}"],
     "solution": ":%norm A{end}<CR>"},
    {"id": "comment-range", "ft": "python",
     "vars": {"a": ["DEBUG", "TRACE"], "b": ["CACHE", "MOCK_API"], "c": ["DRY_RUN", "VERBOSE"]},
     "goal": "Comment out lines 2 to 4 by putting \"# \" in front of each.",
     "lines": ["import os", "{a} = True", "{b} = True", "{c} = True", "", "run()"],
     "solution": ":2,4norm I# <CR>"},
    {"id": "noqa-imports", "ft": "python",
     "vars": {"mod": ["os", "sys", "json"]},
     "goal": "Add \"  # noqa\" to the end of every import line.",
     "lines": ["import {mod}", "import re", "", "LIMIT = 10", "import time", "", "def main():", "    pass"],
     "solution": ":g/^import/norm A  # noqa<CR>"},
    {"id": "drop-bullets", "ft": "markdown",
     "vars": {"a": ["Faster imports", "Smaller pages"], "b": ["Dark theme", "Bulk edit"], "c": ["New export", "Saved views"]},
     "goal": "Remove the \"- \" from the start of every line.",
     "lines": ["- {a}", "- {b}", "- {c}", "- Fixed the login loop"],
     "solution": ":%norm 2x<CR>"}
  ]
}
```
