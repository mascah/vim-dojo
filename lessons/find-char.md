# f F ; ,

`f` followed by a character jumps forward onto the next copy of that
character on the line. `F` does the same backward. `;` repeats the last find
in the same direction, and `,` repeats it the other way, so you can step from
one comma to the next without typing the comma again.

| Key | What it does |
| --- | --- |
| `f{c}` | Forward onto the next `{c}` on the line |
| `F{c}` | Backward onto the previous `{c}` |
| `;` | Repeat the last find |
| `,` | Repeat it in the other direction |

## Example

The cursor, shown as `[ ]`, is at the start of a call:

```text
[l]og.info("saved", user.id, order.total)
```

Type `f,` then `;` to land on the second comma:

```text
log.info("saved", user.id[,] order.total)
```

## When to use it

When you can see the character you want, especially punctuation: a comma, a
paren, a quote, an `=`. Pick a character that appears few times between the
cursor and the target, and press `;` for each extra copy you need to pass.

## The trap

Typing `f,` again instead of `;`. It works, but it is two keys where one
would do. And when `;` overshoots, `,` steps back one, so there is no need to
start over. The dojo cannot set up an overshoot for you, so `,` gets no goals
of its own here; remember it for real editing.

```json
{
  "id": "find-char",
  "title": "f F ; ,",
  "keys": [["f{c}", "forward onto {c}"], ["F{c}", "backward onto {c}"], [";", "repeat the find"],
           [",", "repeat it the other way"]],
  "moves": true,
  "generators": [
    {"at": "[[:punct:]]", "side": "after", "keys": "f{0}"},
    {"at": "[[:punct:]]", "side": "before", "keys": "F{0}"},
    {"at": "[[:punct:]]", "side": "after", "keys": "f{0};"},
    {"at": "[[:punct:]]", "side": "before", "keys": "F{0};"}
  ]
}
```
