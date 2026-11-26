# {n}j {n}k

A number typed before a motion repeats it that many times. `5j` moves five
lines down, `8k` eight up. The same works for every motion: `3w` moves three
words, `2f,` to the second comma. Line numbers in the margin, from `:set
relativenumber`, show the count for each line at a glance.

| Key | What it does |
| --- | --- |
| `{n}j` | Move `{n}` lines down |
| `{n}k` | Move `{n}` lines up |
| `{n}w` | Move `{n}` words forward, and so on for any motion |

## Example

The cursor, shown as `[ ]`, is on the first setting, and the one you want is
five lines down:

```text
[h]ost = "0.0.0.0"
port = 8080
read_timeout = "15s"
write_timeout = "30s"

url = "postgres://orders@db.internal:5432/orders"
```

Type `5j`:

```text
host = "0.0.0.0"
port = 8080
read_timeout = "15s"
write_timeout = "30s"

[u]rl = "postgres://orders@db.internal:5432/orders"
```

## When to use it

When the target is more than a few lines or words away and you can see how
far. With relative numbers on, read the number beside the line and type it.

## The trap

Counting by eye on a long stretch and missing by one, then correcting with
`j`. Turn on `relativenumber` so the count is printed for you. And past ten
or so lines, the paragraph and search motions in this section and the next
are usually shorter.

```json
{
  "id": "count-lines",
  "title": "{n}j {n}k",
  "keys": [["{n}j", "down {n} lines"], ["{n}k", "up {n} lines"], ["{n}w", "forward {n} words, and so on"]],
  "moves": true,
  "generators": [
    {"keys": "{n}j", "vars": {"n": ["5", "6", "7", "8", "9", "12"]}},
    {"keys": "{n}k", "vars": {"n": ["5", "6", "7", "8", "9", "12"]}},
    {"keys": "{n}w", "vars": {"n": ["3", "4", "5", "6"]}},
    {"keys": "{n}b", "vars": {"n": ["3", "4", "5"]}}
  ]
}
```
