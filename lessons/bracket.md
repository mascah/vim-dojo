# Brackets

`i(` is everything inside a pair of parentheses, and `a(` the same with the
parentheses. `i[` and `i{` work on square brackets and braces, and `ib` and
`iB` are other names for `i(` and `i{`. The cursor can be anywhere inside,
even on a line of its own between braces that span several lines.

| Key | What it does |
| --- | --- |
| `ci(` | Change what is inside the parentheses |
| `di(` | Empty them |
| `ci{` | Change what is inside the braces |
| `ci[` | Change what is inside the square brackets |

## Example

The cursor, shown as `[ ]`, is somewhere inside a condition:

```text
if (count [>] 0) {
```

Type `ci(`, then `!items.length`, then `Esc`:

```text
if (!items.lengt[h]) {
```

## When to use it

On call arguments, conditions, indexes, object literals, and blocks. With
nested brackets, the object is the innermost pair around the cursor, so
step out a level by moving onto the outer bracket, or by giving a count:
`c2i(` changes inside the second pair out.

## The trap

Changing an argument list by hand, a comma at a time. `ci(` replaces the lot
from anywhere inside. On a block, `di{` empties every line between the
braces at once, which no single motion does.

```json
{
  "id": "bracket",
  "title": "i( i{ i[",
  "keys": [["ci(", "change inside the parentheses"], ["di(", "empty the parentheses"],
           ["ci{", "change inside the braces"], ["ci[", "change inside the square brackets"]],
  "generators": [
    {
      "at": "(\\zs[^()]\\+\\ze)",
      "keys": "ci({text}<Esc>",
      "vars": {"text": ["ctx", "items", "user.id", "0, 10", "err", "req, res", "path", "cfg"]},
      "goal": "Change the highlighted text inside the parentheses to {text}."
    },
    {
      "at": "(\\zs[^()]\\+\\ze)",
      "keys": "di(",
      "goal": "Delete the highlighted text, keeping the parentheses."
    },
    {
      "at": "\\[\\zs[^][]\\+\\ze\\]",
      "keys": "ci[{text}<Esc>",
      "vars": {"text": ["0", "-1", "\"id\"", "key", "1:"]},
      "goal": "Change the highlighted text inside the square brackets to {text}."
    },
    {
      "at": "{\\zs[^{}]\\+\\ze}",
      "keys": "ci{{text}<Esc>",
      "vars": {"text": ["id: 1", "Name: \"x\"", "ok: true", "...rest"]},
      "goal": "Change the highlighted text inside the braces to {text}."
    }
  ],
  "scenarios": [
    {"id": "call-arguments", "ft": "python", "start": "def total_price",
     "goal": "Make sum() take prices as its only argument in total_price().",
     "lines": ["def total_price(items: list[Item]) -> float:", "    prices = [item.price for item in items]",
               "    return sum(float(item.price) for item in items)"],
     "solution": "Gf(ci(prices<Esc>"},
    {"id": "rewrite-condition", "ft": "javascript", "start": "{at}",
     "vars": {"cond": [{"old": "user == null", "at": "null"}, {"old": "count > 0", "at": ">"},
                       {"old": "items.length !== 0", "at": "length"}],
              "new": ["!user", "done", "isEmpty(items)"]},
     "lines": ["if ({old}) {", "  return null;", "}"],
     "goal": "Make the if condition read ({new}).",
     "solution": "ci({new}<Esc>"},
    {"id": "empty-body", "ft": "go", "start": "{body}",
     "vars": {"name": ["initCache", "loadConfig", "startWorker"],
              "body": ["log.Println(\"start\")", "cache.Reset()", "defer wg.Done()"]},
     "lines": ["func {name}() error {", "    {body}", "    return nil", "}"],
     "goal": "Empty the body of {name}(), keeping its braces.",
     "solution": "di{"},
    {"id": "replace-options", "ft": "javascript", "start": "{at}",
     "vars": {"name": ["opts", "config", "settings"],
              "obj": [{"old": "debug: true", "at": "debug"}, {"old": "mode: \"dev\", port: 3000", "at": "port"},
                      {"old": "cache: false", "at": "false"}],
              "new": ["retries: 3", "timeout: 30", "verbose: false"]},
     "lines": ["const {name} = {{old}};"],
     "goal": "Make the object hold only {new}.",
     "solution": "ci{{new}<Esc>"}
  ]
}
```
