# s

`s` deletes the character under the cursor and goes into Insert mode in its
place, so you can type as much as you like where it was. Think of it as `r`
for when the replacement is longer than one character, or as `x` and `i` in a
single key.

| Key | What it does |
| --- | --- |
| `s` | Delete the character under the cursor and insert in its place |
| `Esc` | Back to Normal mode |

## Example

The cursor, shown as `[ ]`, is on the `5`:

```text
backoff = [5]  # seconds
```

Type `s`, then `30`, then `Esc`:

```text
backoff = 3[0]  # seconds
```

## When to use it

When one character has to become several: a digit that becomes a two-digit
number, a one-letter name that gets a real one, a `=` that should be `:=`.
Like the other ways into Insert mode, the whole change is one step for `u`
and `.`.

## The trap

Using `s` where `r` would do. `r` replaces with one character and stays in
Normal mode; `s` needs an `Esc` after it, which is a key more. The other trap
runs the other way: `s` only takes one character, so for a whole word you want
the change operator, which comes a few lessons later.

```json
{
  "id": "s",
  "title": "s",
  "keys": [["s", "replace the character under the cursor with what you type"]],
  "snippets": ["go", "python", "typescript"],
  "generators": [
    {
      "at": "\\<\\d\\>",
      "keys": "s{n}<Esc>",
      "vars": {"n": ["10", "15", "30", "60", "100", "250"]},
      "goal": "Replace the highlighted digit with {n}."
    },
    {
      "at": "\\<\\a\\>",
      "keys": "s{name}<Esc>",
      "vars": {"name": ["item", "index", "entry", "value", "row"]},
      "goal": "Replace the highlighted one-letter word with {name}."
    }
  ]
}
```
