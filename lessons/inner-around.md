# Inner vs around

A text object names a piece of text by what it is rather than where it
ends: a word, a string, the inside of a bracket. It follows an operator, as a
motion does, but the cursor can be anywhere inside it. Every text object
comes in two sizes: `i` for inner, just the contents, and `a` for around,
the contents with what surrounds them.

| Key | What it does |
| --- | --- |
| `i{object}` | The inside only: the word, or the text between the quotes |
| `a{object}` | The same with its surroundings: a space, the quotes, the brackets |

## Example

The cursor, shown as `[ ]`, is in the middle of a string:

```text
headers = {"Accept": "appl[i]cation/json"}
```

Type `da"` to remove it with its quotes:

```text
headers = {"Accept":[}]
```

`da"` took the space before the string too, since there was none after it.
`di"` would have left an empty `""` in its place.

## When to use it

Choose by what should be left. To replace a value but keep its quotes or
brackets, use `i` with `c`. To remove something whole, use `a` with `d`.
`ciw` and `daw` are the commonest pair.

## The trap

Using `i` with `d` when the thing should go entirely, then tidying up the
empty quotes or the double space by hand. `daw` takes a word and one space,
leaving the sentence well spaced. `da"` takes the quotes and a space beside
them.

```json
{
  "id": "inner-around",
  "title": "inner vs around",
  "keys": [["i{object}", "inner: just the contents"], ["a{object}", "around: with the surroundings"]],
  "generators": [
    {
      "at": "\\v\"[^\"]{3,}\"\\ze[,)\\]:;}]",
      "keys": "di\"",
      "goal": "Empty the highlighted string, keeping its quotes."
    },
    {
      "at": "\\v[(\\[]\\zs\"[^\"]{3,}\"\\ze[,)\\]]",
      "keys": "da\"",
      "goal": "Delete the highlighted string, quotes and all."
    },
    {
      "at": "\\<\\a\\{4,} \\ze\\a",
      "keys": "daw",
      "goal": "Delete the highlighted word and its space."
    },
    {
      "at": "\\<\\a\\{4,}\\>",
      "keys": "diw",
      "goal": "Delete the highlighted word, leaving the spaces around it."
    }
  ]
}
```
