# Ctrl-O Ctrl-I

Vim remembers where you were before each jump: a search, `G`, `%`, a mark.
`Ctrl-O` takes you back to the previous place in that list, and `Ctrl-I`
forward again. So you can go and look something up and come straight back.

| Key | What it does |
| --- | --- |
| `Ctrl-O` | Back to where you were before the last jump |
| `Ctrl-I` | Forward again, undoing a `Ctrl-O` |

## Example

The cursor, shown as `[ ]`, is on a call, and you want to read the function
it calls, which is defined above:

```text
func loadItems() []Item {
    ...
    items := [l]oadItems()
```

Type `?^func loadItems` and Enter to jump to the definition, read it, then
`Ctrl-O` to return:

```text
func loadItems() []Item {
    ...
    items := [l]oadItems()
```

## When to use it

Whenever you leave the place you are working to check something: a
definition, an import, a setting at the top of the file. Do not scroll back
or search again. `Ctrl-O` knows the way.

## The trap

Expecting `Ctrl-O` to undo small moves. `j`, `w`, and `f` are not jumps and
are not remembered; only motions that can go far, such as searches, `G`,
`%`, and `{`, add to the list. In many terminals `Ctrl-I` is the same key as
Tab, which some setups map to something else.

```json
{
  "id": "jumplist",
  "title": "Ctrl-O Ctrl-I",
  "keys": [["Ctrl-O", "back before the last jump"], ["Ctrl-I", "forward again"]],
  "scenarios": [
    {"id": "find-loader", "ft": "go", "start": "items :=", "find": "func loadItems",
     "goal": "Go to the definition of loadItems from its call in main(), then come back.",
     "lines": ["func loadItems() []Item {", "    return []Item{{Name: \"widget\", Price: 9.99}}", "}", "",
               "func main() {", "    items := loadItems()", "    fmt.Println(totalPrice(items))", "}"],
     "solution": "?^func loadItems<CR><C-O>"},
    {"id": "find-describe", "ft": "python", "start": "print(describe", "find": "def describe",
     "goal": "Go to the definition of describe from its call in render(), then come back.",
     "lines": ["def render(items):", "    for item in items:", "        print(describe(item))", "",
               "def describe(item):", "    return f\"{item.name}: ${item.price:.2f}\""],
     "solution": "/^def describe<CR><C-O>"},
    {"id": "find-fallback", "ft": "go", "start": "fmt.Println(fallback", "find": "func fallback",
     "goal": "From the print call, jump to the definition of fallback(), then come back.",
     "lines": ["func fallback() string {", "    return \"default\"", "}", "",
               "// Use fallback when a request times out.", "func printResult() {", "    value, err := fetch()",
               "    if err != nil {", "        fmt.Println(fallback())", "        return", "    }",
               "    fmt.Println(value)", "}"],
     "solution": "?^func fallback<CR><C-O>"},
    {"id": "find-total", "ft": "python", "start": "print(total_price", "find": "def total_price",
     "goal": "From the print call, jump to the definition of total_price(), then come back.",
     "lines": ["def total_price(items):", "    return sum(item.price for item in items)", "",
               "def render(items):", "    value = total_price(items)", "    if value > 0:",
               "        print(total_price(items))", "", "# total_price is also used by the daily summary."],
     "solution": "?^def total_price<CR><C-O>"}
  ]
}
```
