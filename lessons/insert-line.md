# I A

`I` and `A` go into Insert mode at the edges of the line, wherever the cursor
is on it. `I` inserts before the first character that is not a space, so the
indent stays as it was. `A` appends after the last character. Each does a move
and an `i` or `a` in one key.

| Key | What it does |
| --- | --- |
| `I` | Insert before the first non-blank character of the line |
| `A` | Append after the end of the line |

## Example

The cursor, shown as `[ ]`, is in the middle of the line:

```text
    retries = fet[c]h_limit(config)
```

Type `A`, then `  # TODO`, then `Esc`:

```text
    retries = fetch_limit(config)  # TOD[O]
```

From the same start, `I`, `# `, and `Esc` would comment the line out instead,
with the `#` after the indent.

## When to use it

Whenever the text goes at the start or the end of a line: a comment, a
semicolon, a closing bracket. There is no need to move there first.

## The trap

Moving to the end with `$` and then pressing `a`, or to the start with `0` and
pressing `i`. It takes a key more, and `0` lands before the indent, so the
text goes in the wrong place on an indented line. `.` also repeats `A` as an
append at the end of whichever line you are on, which `$a` does not.

```json
{
  "id": "insert-line",
  "title": "I A",
  "keys": [["I", "insert at the start of the line, after the indent"], ["A", "append at the end of the line"]],
  "snippets": ["python", "yaml", "toml"],
  "generators": [
    {
      "at": "^\\s*\\zs[^# ].*",
      "keys": "I# <Esc>",
      "goal": "Comment out the highlighted line with \"# \"."
    },
    {
      "at": "^\\s*\\zs[^# ].*",
      "keys": "A  # {note}<Esc>",
      "vars": {"note": ["TODO", "see #142", "keep in sync", "temporary", "slow", "checked"]},
      "goal": "Add the comment \"# {note}\" at the end of the highlighted line, after two spaces."
    }
  ]
}
```
