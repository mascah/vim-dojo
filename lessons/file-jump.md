# gg G {n}G

Three jumps that cross a whole file in one move. `gg` goes to the first line
and `G` to the last. With a number in front, `G` goes to that line: `42G` is
line 42. Error messages and stack traces give you line numbers, and this is
the way to use them.

| Key | What it does |
| --- | --- |
| `gg` | First line of the file |
| `G` | Last line of the file |
| `{n}G` | Line `{n}` |

## Example

The cursor, shown as `[ ]`, is near the top, and a test failed on line 28:

```text
 1 [p]ackage store
   ...
28     return nil, fmt.Errorf("no order %d", id)
```

Type `28G`:

```text
 1 package store
   ...
28     [r]eturn nil, fmt.Errorf("no order %d", id)
```

Unlike `j` and `k`, `G` and `gg` land on the first non-blank character of
the line, unless you have turned off the `startofline` option.

## When to use it

Whenever you know the line: from a compiler, a linter, a test failure, or the
number in the margin with `:set number`. `gg` and `G` are the quickest way to
the imports at the top and the end of a file.

## The trap

Scrolling or holding `j` to a line you could name. Another is `:28` and
Enter, which also works but costs a key more than `28G`.

```json
{
  "id": "file-jump",
  "title": "gg G {n}G",
  "keys": [["gg", "first line"], ["G", "last line"], ["{n}G", "line {n}"]],
  "moves": true,
  "generators": [
    {"keys": "gg"},
    {"keys": "G"},
    {
      "keys": "{n}G",
      "vars": {"n": ["4", "7", "9", "12", "15", "18", "21", "24", "27", "30"]},
      "goal": "Jump to line {n}."
    }
  ]
}
```
