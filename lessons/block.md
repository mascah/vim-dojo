# Ctrl-V

`Ctrl-V` selects a rectangle: the same columns on several lines. With a
block selected, `I` inserts text before it on every line and `A` appends
after it, `d` deletes the block, and `r` replaces each character in it.

| Key | What it does |
| --- | --- |
| `Ctrl-V` | Select a rectangle |
| `I` | Insert before the block on every line |
| `A` | Append after the block on every line |
| `d` | Delete the block |

## Example

The cursor, shown as `[ ]`, is at the start of the first of three settings:

```text
import os
[h]ost = os.environ["APP_host"]
port = os.environ["APP_port"]
user = os.environ["APP_user"]
```

Type `Ctrl-V`, `jj`, `I`, `# `, then `Esc`:

```text
import os
[#] host = os.environ["APP_host"]
# port = os.environ["APP_port"]
# user = os.environ["APP_user"]
```

## When to use it

To comment or uncomment a run of lines, to add the same text at the same
column, or to edit a column of aligned values. With `$` before `A`, the
block reaches the end of every line, however long, so `Ctrl-V jj$A,`
appends a comma to three lines of different length.

## The trap

Watching only the first line while typing and thinking it failed. The
other lines change when you press `Esc`, not before. Lines too short to
reach the block are skipped by `I`, so keep blocks within text that
exists.

```json
{
  "id": "block",
  "title": "Ctrl-V",
  "keys": [["Ctrl-V", "select a rectangle"], ["I", "insert before it on each line"], ["A", "append after it"],
           ["d", "delete the block"]],
  "scenarios": [
    {"id": "comment-block", "ft": "python", "start": "{a} =",
     "vars": {"names": [{"a": "host", "b": "port", "c": "user"}, {"a": "region", "b": "bucket", "c": "key"},
                        {"a": "token", "b": "org", "c": "repo"}], "prefix": ["APP", "SVC"]},
     "goal": "Comment out the three environment lines by putting \"# \" in front of each.",
     "lines": ["import os", "{a} = os.environ[\"{prefix}_{a}\"]", "{b} = os.environ[\"{prefix}_{b}\"]",
               "{c} = os.environ[\"{prefix}_{c}\"]", "connect()"],
     "solution": "<C-V>jjI# <Esc>"},
    {"id": "append-commas", "ft": "python", "start": "\"{c1}\"",
     "vars": {"colors": [{"c1": "red", "c2": "green", "c3": "blue"}, {"c1": "teal", "c2": "amber", "c3": "violet"},
                         {"c1": "black", "c2": "white", "c3": "grey"}], "name": ["colors", "palette"]},
     "goal": "Add a comma to the end of each of the three strings.",
     "lines": ["{name} = [", "    \"{c1}\"", "    \"{c2}\"", "    \"{c3}\"", "]"],
     "solution": "<C-V>jj$A,<Esc>"},
    {"id": "uncomment", "ft": "python", "start": "# {a}",
     "vars": {"a": ["workers", "threads"], "b": ["batch", "chunk"], "c": ["timeout", "deadline"]},
     "goal": "Uncomment the three settings by removing \"# \" from each.",
     "lines": ["import os", "# {a} = 4", "# {b} = 100", "# {c} = 30", "run()"],
     "solution": "<C-V>jjld"},
    {"id": "bump-version", "ft": "text", "start": "1/orders",
     "vars": {"n": ["2", "3"], "c": ["users", "accounts"], "d": ["items", "carts"]},
     "goal": "Change v1 to v{n} on all three routes.",
     "lines": ["GET  /v1/orders", "GET  /v1/{c}", "POST /v1/{d}"],
     "solution": "<C-V>jjr{n}"}
  ]
}
```
