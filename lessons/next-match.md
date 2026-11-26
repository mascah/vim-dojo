# n N

After a search, `n` jumps to the next match, and `N` to the previous one.
They follow the direction of the search, so after a `?` search `n` goes
backward. You type the search once and step through its matches as often as
you like.

| Key | What it does |
| --- | --- |
| `n` | Next match, in the search's direction |
| `N` | Previous match, against it |

## Example

The cursor, shown as `[ ]`, is at the start of a function, and you want the
second call to `score`:

```text
[d]ef report(rows):
    total = score(rows[0])
    for row in rows[1:]:
        total += score(row)
```

Type `/score`, Enter, then `n`:

```text
def report(rows):
    total = score(rows[0])
    for row in rows[1:]:
        total += [s]core(row)
```

## When to use it

When the word you can search for appears more than once before the target.
Search for it, then press `n` until you arrive. With `hlsearch` on, every
match is highlighted, so you can count how many presses you need.

## The trap

Retyping the search to get to the next match. `n` does it in one key, and so
does `N` when you have gone one too far. Also watch the direction: `n` after
`?` searches backward, which surprises everyone once.

```json
{
  "id": "next-match",
  "title": "n N",
  "keys": [["n", "next match"], ["N", "previous match"]],
  "moves": true,
  "generators": [
    {"at": "\\<\\a\\w\\{3,}\\>", "keys": "/{0}<CR>n", "goal": "Move onto the second \"{0}\" after the cursor."},
    {"at": "\\<\\a\\w\\{3,}\\>", "keys": "/{0}<CR>nn", "goal": "Move onto the third \"{0}\" after the cursor."},
    {"at": "\\<\\a\\w\\{3,}\\>", "keys": "?{0}<CR>n", "goal": "Move onto the second \"{0}\" before the cursor."}
  ],
  "scenarios": [
    {"id": "third-call", "ft": "python", "start": "def report", "locate": 1,
     "vars": {"fn": ["score", "weight", "clamp"], "name": ["rows", "items"]},
     "goal": "Put the cursor on the third call to {fn}.",
     "lines": ["def report({name}):", "    total = {fn}({name}[0])", "    for row in {name}[1:]:",
               "        total += {fn}(row)", "    print(\"sum\", {fn}({name}))", "    return {fn}(total)"],
     "solution": "/{fn}<CR>nn"}
  ]
}
```
