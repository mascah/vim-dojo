# i a

There are two ways into Insert mode from where the cursor sits. `i` inserts
before the character under the cursor, and `a`, for append, inserts after it.
Which one you want depends on which side of the cursor the new text goes.

| Key | What it does |
| --- | --- |
| `i` | Insert before the cursor |
| `a` | Insert after the cursor |
| `Esc` | Back to Normal mode |

## Example

The cursor, shown as `[ ]`, is on the last letter of `path`:

```text
data = load(pat[h])
```

Type `a`, then `, strict=True`, then `Esc`:

```text
data = load(path, strict=Tru[e])
```

With the cursor on the closing parenthesis, `i` and the same text would do
the same edit.

## When to use it

Look at where the cursor is and where the text should go. If the new text
goes after the character you are on, as it usually does at the end of a word,
press `a`. If it goes in front, press `i`. Either way, no extra move is
needed.

## The trap

Using `i` when you need `a`, then pressing `l` or an arrow key to get past the
character. The arrow keys also split the edit, so `.` can no longer repeat it
whole. Pick the key for the side you need before you start typing.

```json
{
  "id": "insert",
  "title": "i a",
  "keys": [["i", "insert before the cursor"], ["a", "insert after the cursor"]],
  "snippets": ["go", "python", "typescript"],
  "generators": [
    {
      "at": "\\w\\zs)",
      "keys": "i, {arg}<Esc>",
      "vars": {"arg": ["ctx", "opts", "retries", "limit", "cfg", "verbose"]},
      "goal": "Add {arg} as the last argument, just before the highlighted parenthesis."
    },
    {
      "at": "\\w\\ze)",
      "keys": "a, {arg}<Esc>",
      "vars": {"arg": ["ctx", "opts", "retries", "limit", "cfg", "verbose"]},
      "goal": "Add {arg} as the last argument, just after the highlighted character."
    },
    {
      "at": "(\\ze)",
      "keys": "a{arg}<Esc>",
      "vars": {"arg": ["ctx", "opts", "retries", "limit", "cfg", "verbose"]},
      "goal": "Pass {arg} inside the empty parentheses."
    }
  ]
}
```
