# Ctrl-A Ctrl-X

`Ctrl-A` adds one to the number under the cursor, and `Ctrl-X` takes one
away. If the cursor is not on a number, they use the next number on the
line, so there is no need to move onto it. A count changes it by that much:
`5 Ctrl-A` adds five.

| Key | What it does |
| --- | --- |
| `Ctrl-A` | Add one to the next number on the line |
| `Ctrl-X` | Subtract one from it |
| `{n} Ctrl-A` | Add `{n}` |

## Example

The cursor, shown as `[ ]`, is at the start of a setting:

```text
[m]ax_retries = 30
```

Type `5`, then `Ctrl-A`:

```text
max_retries = 3[5]
```

## When to use it

To change a number by a known amount: a port, a limit, a version, a size.
It is shorter than `cw` and typing the number, and you do not need to work
out the result yourself. It also works on negative numbers and goes through
zero without trouble.

## The trap

Landing on the wrong number because it is the first on the line, as in a
version like `2.4.1` where `Ctrl-A` from the start bumps the `2`. Move past
the numbers you want left alone first, with `f.` or `w`, and let `Ctrl-A`
find the next one. Leading zeros may be read as octal; `set nrformats-=octal`
turns that off.

```json
{
  "id": "increment",
  "title": "Ctrl-A Ctrl-X",
  "keys": [["Ctrl-A", "add one"], ["Ctrl-X", "subtract one"], ["{n} Ctrl-A", "add {n}"]],
  "scenarios": [
    {"id": "retry-limit", "ft": "python", "start": "max_retries",
     "vars": {"case": [{"old": "30", "new": "35", "step": "5", "op": "<C-A>", "verb": "Increase"},
                       {"old": "12", "new": "9", "step": "3", "op": "<C-X>", "verb": "Decrease"},
                       {"old": "8", "new": "15", "step": "7", "op": "<C-A>", "verb": "Increase"},
                       {"old": "40", "new": "36", "step": "4", "op": "<C-X>", "verb": "Decrease"}]},
     "goal": "{verb} max_retries to {new}.",
     "lines": ["timeout_s = 60", "max_retries = {old}", "backoff = 2"],
     "solution": "{step}{op}"},
    {"id": "minor-version", "ft": "python", "start": "VERSION",
     "vars": {"v": [{"major": "2", "minor": "4", "next": "5"}, {"major": "1", "minor": "7", "next": "8"},
                    {"major": "3", "minor": "0", "next": "1"}]},
     "goal": "Bump the minor version from {minor} to {next}.",
     "lines": ["NAME = \"inventory\"", "VERSION = \"{major}.{minor}.2\""],
     "solution": "f.<C-A>"},
    {"id": "port-step", "ft": "dosini", "start": "port",
     "vars": {"p": [{"old": "8080", "new": "8090", "step": "10"}, {"old": "3000", "new": "3005", "step": "5"},
                    {"old": "5432", "new": "5442", "step": "10"}]},
     "goal": "Change the port from {old} to {new}.",
     "lines": ["[server]", "host = 0.0.0.0", "port = {old}"],
     "solution": "{step}<C-A>"},
    {"id": "second-value", "ft": "css", "start": "{a}px",
     "vars": {"pad": [{"a": "4", "b": "8", "step": "4", "new": "12"}, {"a": "2", "b": "6", "step": "2", "new": "8"},
                      {"a": "8", "b": "16", "step": "8", "new": "24"}]},
     "goal": "Change the second padding value from {b}px to {new}px.",
     "lines": [".card {", "  padding: {a}px {b}px;", "}"],
     "solution": "w{step}<C-A>"}
  ]
}
```
