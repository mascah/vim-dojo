# 0 ^ _ $

Four keys for the two edges of a line. `0` goes to the very first column,
before any indent. `^` goes to the first character that is not a space, which
is usually where the code starts. `_` does the same as `^` and is easier to
reach on many keyboards. `$` goes to the last character.

| Key | What it does |
| --- | --- |
| `0` | First column of the line |
| `^` | First non-blank character |
| `_` | First non-blank character, like `^` |
| `$` | Last character of the line |

## Example

The cursor, shown as `[ ]`, is in the middle of an indented line:

```text
        if retries > [l]imit:
```

Type `^`:

```text
        [i]f retries > limit:
```

From the same start, `$` would land on the `:`, and `0` on the first space of
the indent.

## When to use it

Whenever the target is at either end of the line, however far away it is. On
indented code you nearly always want `^` or `_` rather than `0`, because the
indent is not where the text is.

## The trap

Holding `h` or `b` to get back to the start of a line. Both cost more the
longer the line is, while `^` is always one key. The other slip is pressing
`0` on indented code and landing in the indent, then walking right to the
first letter.

```json
{
  "id": "line-ends",
  "title": "0 ^ _ $",
  "keys": [["0", "first column"], ["^", "first non-blank character"], ["_", "first non-blank, like ^"],
           ["$", "last character"]],
  "moves": true,
  "generators": [
    {"keys": "$"},
    {"keys": "^"},
    {"keys": "_"},
    {"keys": "0"},
    {"keys": "j$"},
    {"keys": "k_"}
  ]
}
```
