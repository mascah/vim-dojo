# Counts on changes

A count multiplies a change. Put it before the command, as in `3dd` for
three lines or `5x` for five characters, or before the motion, as in `d3w`
for three words or `c2w` to change two. Either way it is one change, so
`.` repeats all of it and `u` undoes all of it.

| Key | What it does |
| --- | --- |
| `{n}dd` | Delete `{n}` lines |
| `d{n}w` | Delete `{n}` words |
| `c{n}w` | Change `{n}` words |
| `{n}x` | Delete `{n}` characters |

## Example

The cursor, shown as `[ ]`, is on the first of three debugging prints:

```text
def checkout(order):
    [p]rint("DEBUG", order)
    print("DEBUG items", order.items)
    print("DEBUG total", order.total)
    return charge(order)
```

Type `3dd`:

```text
def checkout(order):
    [r]eturn charge(order)
```

## When to use it

When you can see how many: three lines, two words, a five-letter suffix.
Saying the number once is shorter than repeating the command, and it
leaves a single change behind for `.` and `u`.

## The trap

Counting wrong on long runs and having to fix it up. Counts pay off for
small numbers you can see at a glance; for more than about five, a search or
a text object is usually safer. And remember that `dw` stops at punctuation,
so `d3w` over `user.id = 1` deletes `user.id`, not three names.

```json
{
  "id": "count-change",
  "title": "counts on changes",
  "keys": [["{n}dd", "delete {n} lines"], ["d{n}w", "delete {n} words"], ["c{n}w", "change {n} words"],
           ["{n}x", "delete {n} characters"]],
  "scenarios": [
    {"id": "debug-prints", "ft": "python", "start": "    print(\"{tag}\", order)",
     "vars": {"fn": ["checkout", "refund", "ship"], "tag": ["DEBUG", "here", "XXX"]},
     "goal": "Delete the three print lines.",
     "lines": ["def {fn}(order):", "    print(\"{tag}\", order)", "    print(\"{tag} items\", order.items)",
               "    print(\"{tag} total\", order.total)", "    return charge(order)"],
     "solution": "3dd"},
    {"id": "comment-prefix", "ft": "go", "start": "{a}",
     "vars": {"words": [{"a": "TODO", "b": "clean", "c": "up"}, {"a": "XXX", "b": "very", "c": "hacky"},
                        {"a": "NOTE", "b": "please", "c": "review"}],
              "rest": ["retry the request when the token expires", "cache the parsed config"]},
     "goal": "Delete \"{a} {b} {c} \" so the comment starts with its fourth word.",
     "lines": ["func refresh() {", "    // {a} {b} {c} {rest}", "}"],
     "solution": "d3w"},
    {"id": "version-suffix", "ft": "python", "start": "{suffix}",
     "vars": {"v": [{"ver": "2.4.1", "suffix": "-beta"}, {"ver": "1.0.0", "suffix": "-rc.1"}, {"ver": "3.2.0", "suffix": "-dev1"}]},
     "goal": "Remove {suffix} from the version.",
     "lines": ["NAME = \"inventory\"", "VERSION = \"{ver}{suffix}\""],
     "solution": "5x"},
    {"id": "two-words", "ft": "markdown", "start": "{old}",
     "vars": {"pair": [{"old": "very slow", "new": "fast"}, {"old": "old manual", "new": "scripted"},
                       {"old": "nightly batch", "new": "hourly"}]},
     "goal": "Change \"{old}\" to \"{new}\".",
     "lines": ["# Imports", "", "The import uses the {old} path until the new queue ships."],
     "solution": "c2w{new}<Esc>"}
  ]
}
```
