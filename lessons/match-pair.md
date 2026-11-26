# %

`%` jumps from a bracket to its partner: `(` to `)`, `[` to `]`, `{` to
`}`, and back. If the cursor is not on a bracket, it first finds the next one
on the line and jumps from there.

| Key | What it does |
| --- | --- |
| `%` | Jump to the bracket that matches the one under or after the cursor |

## Example

The cursor, shown as `[ ]`, is on the brace that opens a function:

```text
func (s *Store) Get(id int) (Order, error) [{]
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.orders[id], nil
}
```

Type `%`:

```text
func (s *Store) Get(id int) (Order, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.orders[id], nil
[}]
```

## When to use it

To find where a call, list, or block ends, or to check that brackets are
balanced. With `f(` first, `f(%` takes you to the end of a call's arguments
however long they are. With an operator, `d%` deletes everything from one
bracket to its partner.

## The trap

Pressing `%` in the middle of a line and landing somewhere unexpected. From
off a bracket it jumps from the next bracket on the line, which may not be
the pair you meant. Put the cursor on the bracket first, or use `f(` to get
there.

```json
{
  "id": "match-pair",
  "title": "%",
  "keys": [["%", "jump to the matching bracket"]],
  "moves": true,
  "snippets": ["go", "python", "typescript", "json"],
  "generators": [
    {"keys": "%"},
    {"at": "[([{]", "side": "after", "keys": "f{0}%"}
  ]
}
```
