# * #

`*` searches forward for the word under the cursor, as a whole word, and `#`
searches backward. There is nothing to type: the word is taken from where
the cursor sits. After either, `n` and `N` step through the other uses.

| Key | What it does |
| --- | --- |
| `*` | Next use of the word under the cursor |
| `#` | Previous use of the word under the cursor |

## Example

The cursor, shown as `[ ]`, is on the parameter `tax`:

```text
def apply(order, [t]ax):
    tax_rate = taxes[order.region]
    return order.total * (1 + tax)
```

Type `*`:

```text
def apply(order, tax):
    tax_rate = taxes[order.region]
    return order.total * (1 + [t]ax)
```

The whole-word match skips `tax_rate` and `taxes`, which a plain `/tax`
would have stopped on.

## When to use it

To follow a name through a file: where else a variable is used, where a
function is called. Put the cursor anywhere on the word and press `*`.

## The trap

Searching with `/` for a name that is already under the cursor, and then
landing inside longer names that contain it. `*` matches the whole word
only. If you do want the partial matches, `g*` is the version without the
word boundaries.

```json
{
  "id": "star",
  "title": "* #",
  "keys": [["*", "next use of this word"], ["#", "previous use of this word"]],
  "moves": true,
  "generators": [
    {"keys": "*"},
    {"keys": "#"},
    {"keys": "**"}
  ],
  "scenarios": [
    {"id": "next-use", "ft": "python", "start": "{var})",
     "vars": {"var": ["discount", "tax", "fee"], "table": ["table", "map"]},
     "goal": "Put the cursor on the next use of {var} as a whole word.",
     "lines": ["def apply(order, {var}):", "    {var}_rate = {var}s_{table}[order.region]", "    total = order.total",
               "    total -= {var}", "    return total * (1 + {var}_rate)"],
     "solution": "*"}
  ]
}
```
