# d

`d` deletes over any motion, so how much it takes depends only on the motion
you give it. With the finds from the last section it becomes precise: `dt)`
deletes up to a closing paren and keeps it, `df.` deletes through a dot.
What `d` removes is kept in a register, so you can put it back elsewhere.

| Key | What it does |
| --- | --- |
| `dW` | Delete to the start of the next WORD |
| `dt{c}` | Delete up to, not including, the next `{c}` |
| `df{c}` | Delete up to and including the next `{c}` |
| `d$` | Delete to the end of the line |

## Example

The cursor, shown as `[ ]`, is on the start of a qualifier:

```text
total = [s]elf.compute(items)
```

Type `df.`:

```text
total = [c]ompute(items)
```

## When to use it

Choose the motion by what ends the text you want gone. A word ends at a
space, so `dw`. An argument list ends at `)`, so `dt)`. A dotted prefix ends
at its dot, so `df.`. A trailing comment runs to the end of the line, so
`d$`.

## The trap

Mixing up `t` and `f`. `dt,` leaves the comma; `df,` takes it. Before you
type, decide whether the character you are aiming at should survive. If you
get it wrong, `u` puts the text back, and the other key is the fix.

```json
{
  "id": "delete",
  "title": "d",
  "keys": [["dW", "delete to the next WORD"], ["dt{c}", "delete up to {c}"],
           ["df{c}", "delete through {c}"], ["d$", "delete to the end of the line"]],
  "snippets": ["go", "python", "typescript"],
  "generators": [
    {
      "at": "(\\zs\\w\\{4,}, ",
      "cursor": "first",
      "keys": "dW",
      "goal": "Delete the highlighted argument with the comma and space after it."
    },
    {
      "at": "(\\zs[^(),]\\{6,}\\ze,",
      "cursor": "first",
      "keys": "dt,",
      "goal": "Delete the highlighted first argument, keeping the comma."
    },
    {
      "at": "(\\zs[^()]\\{6,}\\ze)",
      "cursor": "first",
      "keys": "dt)",
      "goal": "Delete the highlighted text, keeping the closing parenthesis."
    },
    {
      "at": "\\<\\a\\w\\{5,}\\.\\ze\\a",
      "cursor": "first",
      "keys": "df.",
      "goal": "Delete the highlighted name and its dot."
    },
    {
      "at": "\\S\\s\\+\\zs\\%(#\\|//\\).*",
      "cursor": "first",
      "keys": "d$",
      "goal": "Delete the highlighted comment."
    }
  ]
}
```
