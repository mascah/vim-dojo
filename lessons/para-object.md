# ip ap

`ip` is the paragraph around the cursor: the run of lines between blank
lines. `ap` is the same with the blank line after it. In code a paragraph is
usually a function or a group of settings, and in prose it is a paragraph.
The cursor can be on any of its lines.

| Key | What it does |
| --- | --- |
| `dap` | Delete the paragraph and the blank line after it |
| `cip` | Replace the paragraph's lines |
| `yap` | Copy the paragraph with its blank line |

## Example

The cursor, shown as `[ ]`, is on a line inside a function that is no
longer used:

```text
def keep():
    return 1

def legacy_total():
    [p]ass
    return 0

def also_keep():
```

Type `dap`:

```text
def keep():
    return 1

[d]ef also_keep():
```

## When to use it

To delete, replace, or copy a whole block at once: a function, a list, a
section of config, a paragraph of a note. It does not matter how many lines
the block has or where in it you are.

## The trap

Using `dip` to delete a block and leaving two blank lines together. `dap`
takes one blank line with it, so the blocks around stay one line apart.
Use `ip` with `c` instead, where you want the gap kept for the new text.

```json
{
  "id": "para-object",
  "title": "ip ap",
  "keys": [["dap", "delete the paragraph and its blank line"], ["cip", "replace the paragraph"],
           ["yap", "copy the paragraph"]],
  "scenarios": [
    {"id": "drop-function", "ft": "python", "start": "pass",
     "vars": {"old": ["legacy_total", "old_parse", "unused_helper"]},
     "lines": ["def keep():", "    return 1", "", "def {old}():", "    pass", "    return 0", "",
               "def also_keep():", "    return 2"],
     "goal": "Delete {old}() and the blank line after it.",
     "solution": "dap"},
    {"id": "rewrite-notes", "ft": "markdown", "start": "{second}",
     "vars": {"first": ["Draft notes go here.", "Old summary line one."],
              "second": ["More draft text.", "Old summary line two."],
              "new": ["Shipped on Friday.", "Moved to the new server."]},
     "lines": ["# Notes", "", "{first}", "{second}", "", "## Next"],
     "goal": "Replace the two lines under Notes with the single line \"{new}\".",
     "solution": "cip{new}<Esc>"},
    {"id": "drop-list", "ft": "markdown", "start": "{item}",
     "vars": {"item": ["Rotate the keys", "Clear the cache", "Archive the logs"]},
     "lines": ["## Done", "", "- Ship the search page", "- Fix the import job", "", "## Dropped", "",
               "- {item}", "- Rename the staging bucket", "- Move the cron jobs", "", "## Next week", "",
               "- Plan the review rota"],
     "goal": "Delete the list under Dropped, with the blank line after it.",
     "solution": "dap"},
    {"id": "copy-block", "ft": "yaml", "start": "name: {from}",
     "vars": {"from": ["api", "worker", "web"]},
     "lines": ["services:", "", "  - name: {from}", "    image: shop/{from}:1.4", "    replicas: 2", "",
               "  - name: db", "    image: postgres:16"],
     "goal": "Duplicate the {from} block, blank line and all, so it appears twice.",
     "solution": "yapP"}
  ]
}
```
