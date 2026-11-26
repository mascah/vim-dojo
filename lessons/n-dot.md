# n then .

The search and the dot work together. Search for what the places to change
have in common, make the edit at the first one, then `n` to the next match
and `.` to repeat the edit there. Each further place costs two keys, however
far apart they are.

| Key | What it does |
| --- | --- |
| `n` | Jump to the next match of the search |
| `.` | Repeat the last change there |

## Example

The cursor, shown as `[ ]`, is at the top of a file with two skipped tests:

```text
[f]unc TestInventory(t *testing.T) {
    t.Skip("flaky")
    checkInventory(t)
}

func TestTotals(t *testing.T) {
    t.Skip("flaky")
```

Type `/Skip`, Enter, `dd`, then `n.`:

```text
func TestInventory(t *testing.T) {
    checkInventory(t)
}

func TestTotals(t *testing.T) {
    [c]heckTotals(t)
```

## When to use it

When the same edit belongs in scattered places that share a word, with
other lines in between that `j.` would land on. Because you press `n` and `.`
yourself, you can also skip a match with `n` alone when it should stay.

## The trap

Searching for something that also matches where you do not want a change,
then pressing `.` without looking. Glance at each match before the dot. And
make sure the edit does not destroy the next match's text, or `n` will
find nothing.

```json
{
  "id": "n-dot",
  "title": "n .",
  "keys": [["n", "next match"], [".", "repeat the change"]],
  "scenarios": [
    {"id": "unskip-tests", "ft": "go", "start": "func TestInventory",
     "vars": {"reason": ["temporary", "flaky", "slow"]},
     "goal": "Remove all the skips and keep the test bodies.",
     "lines": ["func TestInventory(t *testing.T) {", "    t.Skip(\"{reason}\")", "    checkInventory(t)", "}", "",
               "func TestTotals(t *testing.T) {", "    t.Skip(\"{reason}\")", "    checkTotals(t)", "}"],
     "solution": "/Skip<CR>ddn."},
    {"id": "rename-qty", "ft": "python", "start": "def line_total",
     "vars": {"new": ["count", "amount", "units"]},
     "goal": "Rename every qty to {new}.",
     "lines": ["def line_total(price, qty):", "    if qty <= 0:", "        return 0", "    discount = rate(price)",
               "    return price * qty - discount"],
     "solution": "/qty<CR>ciw{new}<Esc>n.n."},
    {"id": "drop-logs", "ft": "javascript", "start": "function save",
     "vars": {"what": ["here", "saving", "debug"]},
     "goal": "Delete every console.log line.",
     "lines": ["function save(order) {", "  console.log(\"{what}\", order);", "  validate(order);",
               "  db.put(order.id, order);", "  console.log(\"{what} done\");", "  return order.id;", "}"],
     "solution": "/console<CR>ddn."},
    {"id": "mark-flaky", "ft": "python", "start": "import pytest",
     "vars": {"mark": ["flaky", "slow", "network"]},
     "goal": "Put a line @pytest.mark.{mark} above each test that calls fetch.",
     "lines": ["import pytest", "", "def test_parse():", "    assert parse(\"1\") == 1", "",
               "def test_fetch_one():", "    assert fetch(1).ok", "", "def test_fetch_all():", "    assert fetch().ok"],
     "solution": "/^def test_fetch<CR>O@pytest.mark.{mark}<Esc>jn."}
  ]
}
```
