# h j k l

The four keys under your right hand move the cursor one step at a time. They
sit on the home row, so your fingers stay where they type and never travel to
the arrow keys.

| Key | What it does |
| --- | --- |
| `h` | One character left |
| `j` | One line down |
| `k` | One line up |
| `l` | One character right |

## Example

The cursor, shown as `[ ]`, is at the start of the second line:

```text
host = "db.internal"
[p]ort = 5432
```

Type `k` then `l`:

```text
h[o]st = "db.internal"
port = 5432
```

`j` and `k` try to keep the column you were in, so moving down past a short
line and on to a long one puts you back where you started across.

## When to use it

For the short hops: the character beside the one you want, the line just
above or below. Anything further is faster with the motions in the next
lessons, which jump by words, to a character, or to a search match.

## The trap

Holding `j` or `l` to cross a long way. It feels quick, but you overshoot,
come back, and spend more keys than a single jump would. If you press the same
one of these four keys more than three times in a row, there is a better
motion for it, and the dojo will point that out.

```json
{
  "id": "hjkl",
  "title": "h j k l",
  "keys": [["h", "left"], ["j", "down"], ["k", "up"], ["l", "right"]],
  "moves": true,
  "generators": [
    {"keys": "{m}", "vars": {"m": ["h", "j", "k", "l", "hh", "jj", "kk", "ll", "jl", "jh", "kl", "kh"]}}
  ]
}
```
