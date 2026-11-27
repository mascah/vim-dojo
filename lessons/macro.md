# q @

`qa` starts recording everything you type into register `a`, and `q` stops.
`@a` plays the keys back, and `3@a` plays them three times. A macro is
just keys, so anything you can do by hand, moves and edits and searches,
you can record once and repeat.

| Key | What it does |
| --- | --- |
| `q{a}` | Start recording into register `{a}` |
| `q` | Stop recording |
| `@{a}` | Play register `{a}` |
| `{n}@{a}` | Play it `{n}` times |

## Example

The cursor, shown as `[ ]`, is at the start of a list of bare words:

```text
[a]pple
banana
cherry
damson
```

Type `qa`, `I"`, `Esc`, `A",`, `Esc`, `j`, `q`, then `3@a`:

```text
"apple",
"banana",
"cherry",
"damson",
```

## When to use it

When the same several-step edit is needed on many lines or places, and
`.` is not enough because the edit is more than one change. End the
recording with the move to the next place, here `j`, so each play leaves
the cursor ready for the next.

## The trap

Recording moves that only work on the first line, such as `5l` to reach a
word that sits elsewhere on other lines. Use moves that find their place:
`0`, `f,`, `w`, `A`, a search. And start each line's edit from a known
spot, like `0` or `I`, rather than wherever the last one left you.

```json
{
  "id": "macro",
  "title": "q @",
  "keys": [["q{a}", "record into {a}"], ["q", "stop"], ["@{a}", "play {a}"], ["{n}@{a}", "play it {n} times"]],
  "scenarios": [
    {"id": "quote-list", "ft": "python",
     "vars": {"words": [{"a": "apple", "b": "banana", "c": "cherry", "d": "damson"},
                        {"a": "red", "b": "green", "c": "blue", "d": "violet"},
                        {"a": "north", "b": "south", "c": "east", "d": "west"}]},
     "goal": "Turn every line into a quoted string followed by a comma, like \"{a}\",",
     "lines": ["{a}", "{b}", "{c}", "{d}"],
     "solution": "qaI\"<Esc>A\",<Esc>jq3@a"},
    {"id": "drop-column", "ft": "text",
     "vars": {"names": [{"a": "Ana", "b": "Ravi", "c": "Mei", "d": "Tom"}, {"a": "Lee", "b": "Sam", "c": "Kai", "d": "Ola"}]},
     "goal": "Delete the name column, with its comma, from every row.",
     "lines": ["1042,{a},Lisbon", "2177,{b},Pune", "3051,{c},Osaka", "4410,{d},Leeds"],
     "solution": "qa0f,dt,jq3@a"},
    {"id": "upper-keys", "ft": "dosini",
     "vars": {"a": ["host", "addr"], "b": ["port", "listen"], "c": ["user", "owner"]},
     "goal": "Make the name of every setting uppercase.",
     "lines": ["{a} = 0.0.0.0", "{b} = 8080", "{c} = app", "mode = strict"],
     "solution": "qagUiwjq3@a"},
    {"id": "export-lines", "ft": "sh",
     "vars": {"p": ["APP", "SHOP"]},
     "goal": "Put export in front of every line.",
     "lines": ["{p}_HOST=localhost", "{p}_PORT=8080", "{p}_USER=app", "{p}_MODE=dev"],
     "solution": "qaIexport <Esc>jq3@a"}
  ]
}
```
