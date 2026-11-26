# t T

`t` followed by a character moves forward to just before the next copy of
it, and `T` moves backward to just after the previous one. They are `f` and
`F` that stop one short. `;` and `,` repeat them too.

| Key | What it does |
| --- | --- |
| `t{c}` | Forward to just before the next `{c}` |
| `T{c}` | Backward to just after the previous `{c}` |

## Example

The cursor, shown as `[ ]`, is on the `s` of `send`:

```text
[s]end(order_id)
```

Type `t)`:

```text
send(order_i[d])
```

The cursor stops on the last letter of the argument, not on the paren.

## When to use it

When the place you want is right next to a character you can see: the end of
an argument before its `)`, the last letter before a comma, the start of a
value after an `=` with `T=`. On their own, `t` and `T` save one key over
`f` and a nudge. With the operators in the next section, `dt)` deletes up to
the paren but keeps it, and that is where `t` earns its place.

## The trap

Pressing `;` after `t` and expecting it to move. In current Vim it skips the
character the cursor is already in front of and goes on to the next copy,
but some setups leave it stuck where it is. If `;` seems to do nothing after
`t`, that is why.

```json
{
  "id": "till",
  "title": "t T",
  "keys": [["t{c}", "forward to just before {c}"], ["T{c}", "backward to just after {c}"]],
  "moves": true,
  "generators": [
    {"at": "[[:punct:]]", "side": "after", "keys": "t{0}"},
    {"at": "[[:punct:]]", "side": "before", "keys": "T{0}"}
  ]
}
```
