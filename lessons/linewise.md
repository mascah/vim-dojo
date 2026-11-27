# V

`V` selects whole lines, starting with the cursor's line. Move up or down to
add more, with `j`, `k`, `}`, or a search, and then act on all of them at
once: `>` and `<` shift them, `d` deletes them, `y` copies them. Where in
the line the cursor sits does not matter.

| Key | What it does |
| --- | --- |
| `V` | Select whole lines |
| `>` `<` | Shift the selected lines right or left |
| `d` `y` | Delete or copy the selected lines |

## Example

The cursor, shown as `[ ]`, is on the first of two lines that belong under
the `if`:

```text
for item in items:
    if item.paid:
    [c]ount += 1
    total += item.price
    log(item)
```

Type `Vj>`:

```text
for item in items:
    if item.paid:
        [c]ount += 1
        total += item.price
    log(item)
```

## When to use it

To shift, delete or copy a block of lines you can see, especially when you
are counting lines by eye. The highlight shows you the block before you act,
and a search grows it to a line you can name but cannot count to.

## The trap

Using `V` and then reaching for `v` motions such as `w` or `e`, expecting
part of a line. In `V` mode every line is whole. Press `v` while selecting
to switch to characters without starting again, or `V` to switch back.

```json
{
  "id": "linewise",
  "title": "V",
  "keys": [["V", "select whole lines"], [">", "shift right"], ["<", "shift left"], ["d", "delete them"],
           ["y", "copy them"]],
  "scenarios": [
    {"id": "indent-body", "ft": "python", "start": "count",
     "vars": {"attr": ["active", "paid", "shipped"], "list": ["items", "orders"]},
     "goal": "Indent the two lines after the if, so they belong to it.",
     "lines": ["for item in {list}:", "    if item.{attr}:", "    count += 1", "    total += item.price", "    log(item)",
               "print(total)"],
     "solution": "Vj>"},
    {"id": "outdent-args", "ft": "python", "start": "{a},",
     "vars": {"a": ["url", "path", "query"], "b": ["timeout=5", "retries=3", "verify=False"]},
     "goal": "Shift the two argument lines one level left.",
     "lines": ["def load():", "    return fetch(", "                {a},", "                {b},", "    )"],
     "solution": "Vj<"},
    {"id": "copy-settings", "ft": "yaml", "start": "  retries",
     "vars": {"r": ["3", "5"], "t": ["30s", "1m", "90s"]},
     "goal": "Copy the two lines under defaults to the end of the file.",
     "lines": ["defaults:", "  retries: {r}", "  timeout: {t}", "", "jobs:", "  import:", "    schedule: hourly"],
     "solution": "VjyGp"},
    {"id": "drop-draft", "ft": "markdown", "start": "<!-- draft",
     "vars": {"a": ["Faster imports", "Smaller pages"], "b": ["New export page", "Dark theme", "Bulk edit"]},
     "goal": "Delete the draft, from its first comment line to the end comment.",
     "lines": ["## Changelog", "", "<!-- draft -->", "- {a}", "- {b}", "<!-- end draft -->", "", "## 1.4", "",
               "- Fixed the login loop"],
     "solution": "V/end draft<CR>d"}
  ]
}
```
