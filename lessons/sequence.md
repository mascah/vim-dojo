# g Ctrl-A

In Visual mode, `Ctrl-A` adds one to the first number on every selected
line. `g Ctrl-A` adds more on each line down: one to the first line, two to
the second, three to the third. So a column of identical numbers becomes a
sequence in one go. A count sets the step: `10 g Ctrl-A` counts in tens.

| Key | What it does |
| --- | --- |
| `g Ctrl-A` | Add 1, 2, 3 and so on down the selected lines |
| `{n} g Ctrl-A` | Add `{n}`, `2{n}`, `3{n}` and so on |

## Example

The cursor, shown as `[ ]`, is on the first of four items that all say 0:

```text
steps = [
    ["]step 0",
    "step 0",
    "step 0",
    "step 0",
]
```

Type `V3j`, then `g Ctrl-A`:

```text
steps = [
    ["]step 1",
    "step 2",
    "step 3",
    "step 4",
]
```

## When to use it

To number list items, steps, ids, ports, or test cases that start out the
same. Copy one line as many times as you need, select the copies, and
number them all at once.

## The trap

Selecting the line before the first one to number, so the sequence starts
a line early. And in a Markdown list of `1.` items, select from the second
item, or the first becomes 2. Each line uses only its first number, so
start with lines where that is the number you mean.

```json
{
  "id": "sequence",
  "title": "g Ctrl-A",
  "keys": [["g Ctrl-A", "add 1, 2, 3 down the lines"], ["{n} g Ctrl-A", "count in steps of {n}"]],
  "scenarios": [
    {"id": "number-steps", "ft": "python", "start": "\"{word} 0\"",
     "vars": {"word": ["step", "stage", "phase", "task"], "list": ["steps", "plan", "pipeline"]},
     "goal": "Number the four items 1 to 4.",
     "lines": ["{list} = [", "    \"{word} 0\",", "    \"{word} 0\",", "    \"{word} 0\",", "    \"{word} 0\",", "]"],
     "solution": "V3jg<C-A>"},
    {"id": "port-range", "ft": "yaml", "start": "  - {p}",
     "vars": {"range": [{"p": "8080", "a": "8081", "c": "8083"}, {"p": "9000", "a": "9001", "c": "9003"}]},
     "goal": "Make the three ports {a} to {c}.",
     "lines": ["ports:", "  - {p}", "  - {p}", "  - {p}"],
     "solution": "Vjjg<C-A>"},
    {"id": "list-numbers", "ft": "markdown",
     "vars": {"a": ["Pull the branch", "Open the repo"], "b": ["Run the tests", "Build the image"],
              "c": ["Tag the release", "Push the tag"], "d": ["Tell the team", "Close the ticket"]},
     "goal": "Number the list 1 to 4.",
     "lines": ["1. {a}", "1. {b}", "1. {c}", "1. {d}"],
     "solution": "jVjjg<C-A>"},
    {"id": "step-ten", "ft": "sql", "start": "(0,",
     "vars": {"t": ["plans", "tiers"], "a": ["free", "basic"], "b": ["team", "pro"], "c": ["enterprise", "max"]},
     "goal": "Make the three ids 10, 20 and 30.",
     "lines": ["INSERT INTO {t} VALUES", "(0, '{a}'),", "(0, '{b}'),", "(0, '{c}');"],
     "solution": "Vjj10g<C-A>"}
  ]
}
```
