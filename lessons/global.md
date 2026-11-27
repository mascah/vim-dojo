# :g

`:g/pattern/command` runs an Ex command on every line that matches the
pattern. `:g/print/d` deletes every line that contains `print`, wherever
they are. `:v` is the opposite: it runs the command on every line that does
not match. Any Ex command can follow: `d`, `m$` to move, `s` to substitute.

| Key | What it does |
| --- | --- |
| `:g/{pattern}/d` | Delete every matching line |
| `:v/{pattern}/d` | Delete every line that does not match |
| `:g/{pattern}/m$` | Move every matching line to the end |

## Example

Three debug prints are scattered through a function:

```text
def checkout(order):
    print("start", order)
    total = order.total()
    print("total", total)
    return total
```

Type `:g/print/d` and Enter:

```text
def checkout(order):
    total = order.total()
    return total
```

## When to use it

To clear out lines by what they contain: debug output, blank lines,
comments, log noise. Or to gather them, with `m$`, keeping their order.
With `:v`, keep only the lines you care about, such as the errors in a log.

## The trap

A pattern that matches more than you meant, such as `print` also matching
`blueprint`. Search for the pattern with `/` first: every highlighted line is
a line `:g` will touch. If it went wrong, `u` undoes the whole `:g` at once.

```json
{
  "id": "global",
  "title": ":g",
  "keys": [[":g/{pattern}/d", "delete matching lines"], [":v/{pattern}/d", "delete the other lines"],
           [":g/{pattern}/m$", "move matching lines to the end"]],
  "scenarios": [
    {"id": "drop-debug", "ft": "python",
     "vars": {"fn": ["checkout", "invoice", "refund"], "call": ["print", "log.debug", "trace"]},
     "goal": "Delete every line that calls {call}.",
     "lines": ["def {fn}(order):", "    {call}(\"start\", order)", "    total = order.total()", "    {call}(\"total\", total)",
               "    tax = total * 0.2", "    {call}(\"tax\", tax)", "    return total + tax"],
     "solution": ":g/{call}/d<CR>"},
    {"id": "keep-errors", "ft": "text",
     "vars": {"svc": ["api", "worker", "billing"]},
     "goal": "Keep only the lines with ERROR.",
     "lines": ["09:00 INFO {svc} started", "09:01 ERROR {svc} lost the database", "09:01 INFO retrying",
               "09:02 WARN slow query", "09:03 ERROR {svc} gave up", "09:04 INFO shutting down"],
     "solution": ":v/ERROR/d<CR>"},
    {"id": "gather-todos", "ft": "go",
     "vars": {"a": ["retry on timeout", "check the token"], "b": ["log the size", "close the body"]},
     "goal": "Move every TODO line to the end of the file, keeping their order.",
     "lines": ["func fetch(url string) ([]byte, error) {", "    // TODO: {a}", "    resp, err := http.Get(url)",
               "    // TODO: {b}", "    return io.ReadAll(resp.Body)", "}"],
     "solution": ":g/TODO/m$<CR>"},
    {"id": "drop-blanks", "ft": "dosini",
     "vars": {"db": ["shop", "app", "orders"]},
     "goal": "Delete every blank line.",
     "lines": ["[server]", "", "host = 0.0.0.0", "", "port = 8080", "", "[database]", "", "name = {db}"],
     "solution": ":g/^$/d<CR>"}
  ]
}
```
