# o O

`o` opens a new line below the cursor's line and puts you in Insert mode on
it. `O`, the capital, opens one above. Where the cursor is on the line does
not matter. If your Vim indents for the filetype, the new line starts at the
indent Vim would give it.

| Key | What it does |
| --- | --- |
| `o` | Open a line below and insert there |
| `O` | Open a line above and insert there |

## Example

The cursor, shown as `[ ]`, is on the `timeout` line:

```text
[t]imeout = 30
port = 8080
```

Type `o`, then `retries = 3`, then `Esc`:

```text
timeout = 30
retries = [3]
port = 8080
```

With `O` and the same text, the new line would go above `timeout`.

## When to use it

Every time you add a line. It is the one key for "a new line goes here",
whether that is a statement, a list item, or a comment above a block. Choose
`o` or `O` by which side of the current line the new one belongs, and skip
moving to the neighbour first.

## The trap

Going to the end of the line with `A` and pressing Enter. It works, but it is
a key longer for the same new line. Pressing `j` then `O` to add a line below
is the same waste the other way round, and on the last line there is no line
below to move to.

```json
{
  "id": "open-line",
  "title": "o O",
  "keys": [["o", "open a line below"], ["O", "open a line above"]],
  "snippets": ["python", "yaml", "toml"],
  "generators": [
    {
      "at": "^\\s*\\zs[^# ].*",
      "keys": "o# {note}<Esc>",
      "vars": {"note": ["TODO", "see #142", "keep in sync", "temporary", "slow", "checked"]},
      "goal": "Add the comment \"# {note}\" on a new line below the highlighted one."
    },
    {
      "at": "^\\s*\\zs[^# ].*",
      "keys": "O# {note}<Esc>",
      "vars": {"note": ["TODO", "see #142", "keep in sync", "temporary", "slow", "checked"]},
      "goal": "Add the comment \"# {note}\" on a new line above the highlighted one."
    }
  ]
}
```
