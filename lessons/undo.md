# u Ctrl-R

`u` undoes the last change, and each further `u` steps one more change back.
`Ctrl-R` redoes, stepping forward again. A change is one whole command: a
`dd`, a `cw` and everything typed before `Esc`, a `p`. So undo takes back
whole edits, not single letters.

| Key | What it does |
| --- | --- |
| `u` | Undo the last change |
| `Ctrl-R` | Redo the change you last undid |

## Example

The last edit was a `dd` that took the wrong line. The cursor, shown as
`[ ]`, is where it left you:

```text
def total(items):
    [r]eturn sum(items)
```

Type `u`:

```text
def total(items):
    [i]f not items:
        return 0
    return sum(items)
```

## When to use it

The moment an edit goes wrong. Undo, then do it right, instead of repairing
the damage by hand. If you undid one step too many, `Ctrl-R` brings it back.

## The trap

Undoing a long insert and finding it all gone. Everything typed between
entering Insert mode and `Esc` is one change, so one `u` removes the lot. If
you want smaller steps to undo, leave Insert mode more often, which also
gives `.` smaller pieces to repeat.

```json
{
  "id": "undo",
  "title": "u Ctrl-R",
  "keys": [["u", "undo the last change"], ["Ctrl-R", "redo"]],
  "scenarios": [
    {"id": "undo-delete", "ft": "python", "start": "return",
     "vars": {"fn": ["total", "average", "score"], "check": ["if not items:", "if items is None:"]},
     "history": [["def {fn}(items):", "    {check}", "        return 0", "    return sum(items)"]],
     "lines": ["def {fn}(items):", "        return 0", "    return sum(items)"],
     "goal": "The line \"{check}\" was just deleted by mistake. Bring it back.",
     "solution": "u"},
    {"id": "undo-twice", "ft": "text",
     "vars": {"words": [{"a": "alpha", "b": "beta", "c": "gamma"}, {"a": "north", "b": "south", "c": "east"},
                        {"a": "red", "b": "green", "c": "blue"}]},
     "history": [["{a} {b} {c}"], ["{a} {c}"]],
     "lines": ["{c}"],
     "goal": "Undo the last two changes so the line reads \"{a} {b} {c}\" again.",
     "solution": "uu"},
    {"id": "redo-rename", "ft": "python",
     "vars": {"old": ["tmp", "val", "x"], "new": ["subtotal", "price", "count"]},
     "lines": ["{old} = load()"],
     "redo": [["{new} = load()"]],
     "goal": "The rename to {new} was undone by mistake. Bring it back.",
     "solution": "<C-R>"},
    {"id": "undo-insert", "ft": "markdown",
     "vars": {"extra": ["This step is optional and can be skipped on a laptop.",
                        "Ask before you run it on the shared database.",
                        "It used to take an hour, but now it is quick."]},
     "history": [["## Setup", "", "Run the seed script once.", "", "## Running"]],
     "lines": ["## Setup", "", "Run the seed script once. {extra}", "", "## Running"],
     "goal": "Take back the sentence that was just typed after \"once.\".",
     "solution": "u"},
    {"id": "redo-twice", "ft": "yaml",
     "vars": {"a": ["2", "3"], "b": ["4", "5"], "c": ["6", "8"]},
     "lines": ["replicas: 1", "strategy: rolling"],
     "redo": [["replicas: {a}", "strategy: rolling"], ["replicas: {b}", "strategy: rolling"],
              ["replicas: {c}", "strategy: rolling"]],
     "goal": "Three changes to replicas were undone. Redo the first two, so replicas is {b}.",
     "solution": "<C-R><C-R>"}
  ]
}
```
