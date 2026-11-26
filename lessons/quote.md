# i" a"

`i"` is the text between a pair of double quotes, and `a"` the same with
the quotes. The cursor can be anywhere inside the string, and if it is before
the first quote on the line, Vim uses the first string it finds. `i'` and
`` i` `` do the same for single quotes and backticks.

| Key | What it does |
| --- | --- |
| `ci"` | Change the text inside the quotes |
| `di"` | Empty the string, keeping its quotes |
| `da"` | Delete the string with its quotes |

## Example

The cursor, shown as `[ ]`, is somewhere in a status string:

```text
order["status"] = "awaiting [p]ickup"
```

Type `ci"`, then `ready to ship`, then `Esc`:

```text
order["status"] = "ready to shi[p]"
```

## When to use it

On any string value: a message, a key, a URL, a path. It is the shortest way
to replace a string from anywhere inside it, and it never touches the quotes,
so there is nothing to retype.

## The trap

Starting outside the string you meant. From before the first quote on a
line, Vim picks the first string, which may not be yours: here, from the
start of the line `ci"` would change `status`. Get onto or just before the
right string first, with `f"` or a search.

```json
{
  "id": "quote",
  "title": "i\" a\"",
  "keys": [["ci\"", "change inside the quotes"], ["di\"", "empty the string"], ["da\"", "delete it with its quotes"]],
  "generators": [
    {
      "at": "\\v\"[^\"]+\"",
      "keys": "ci\"{text}<Esc>",
      "vars": {"text": ["timeout", "en-US", "/healthz", "retry later", "v2.4.1", "us-east-1",
                        "primary", "read-only", "Saved", "utf-8", "info", "nightly"]},
      "goal": "Change the highlighted string to \"{text}\"."
    },
    {
      "at": "\\v\"[^\"]+\"",
      "keys": "di\"",
      "goal": "Empty the highlighted string, keeping its quotes."
    }
  ],
  "scenarios": [
    {"id": "quoted-item", "ft": "python", "start": "widget",
     "goal": "Change the first item’s name to \"ratchet\".",
     "lines": ["def load_items() -> list[Item]:", "    return [", "        Item(\"widget\", 9.99, [\"tools\", \"small\"]),",
               "        Item(\"gadget\", 24.50, [\"tools\"]),", "    ]"],
     "solution": "ci\"ratchet<Esc>"},
    {"id": "shipping-status", "ft": "python", "start": "{second}",
     "vars": {"first": ["awaiting", "pending"], "second": ["pickup", "review", "payment"],
              "new": ["ready to ship", "on hold", "in transit"]},
     "goal": "Change the shipping status to \"{new}\".",
     "lines": ["order = {", "    \"customer\": \"Sam Lee\",", "    \"status\": \"{first} {second}\",", "}"],
     "solution": "ci\"{new}<Esc>"},
    {"id": "catalog-string", "ft": "go", "start": "return []Item", "locate": 1,
     "goal": "In the catalog below, rename \"bulk spacer\" to \"steel washer\".",
     "lines": ["func loadItems() []Item {", "    return []Item{",
               "        {Name: \"widget\", Price: 9.99, Tags: []string{\"tools\", \"small\"}},",
               "        {Name: \"bulk spacer\", Price: 3.25, Tags: []string{\"tools\"}},",
               "        {Name: \"gadget\", Price: 24.50, Tags: []string{\"tools\"}},", "    }", "}"],
     "solution": "/bulk<CR>ci\"steel washer<Esc>"},
    {"id": "quoted-endpoint", "ft": "python", "start": "API_URL",
     "vars": {"host": ["api.example.test", "staging.example.test"], "version": ["v2", "v3"]},
     "goal": "Change API_URL to \"https://{host}/{version}\".",
     "lines": ["API_URL = \"http://localhost:8080/api\"", "HEALTH_URL = \"http://localhost:8080/health\"", "TIMEOUT = 15"],
     "solution": "ci\"https://{host}/{version}<Esc>"}
  ]
}
```
