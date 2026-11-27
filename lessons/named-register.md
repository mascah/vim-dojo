# Named registers

Put `"a` before a yank or a delete, and the text goes into register `a`,
where it stays until you replace it. `"ap` puts it back, however many other
yanks and deletes happen in between. There are 26 of them, `a` to `z`, and
the capital letter appends: `"Ayy` adds a line to what `a` already holds.

| Key | What it does |
| --- | --- |
| `"ayy` | Copy the line into register `a` |
| `"Ayy` | Add the line to the end of register `a` |
| `"ap` | Put register `a` after the cursor |

## Example

The cursor, shown as `[ ]`, is on a constant that should move to the end of
the file, and a debugging line should go:

```text
[L]ICENSE = "MIT"
DEBUG_ONLY = True
def main():
    pass
```

Type `"ayy`, `j`, `dd`, `G` and `"ap`:

```text
LICENSE = "MIT"
def main():
    pass
[L]ICENSE = "MIT"
```

The `dd` did not disturb register `a`.

## When to use it

When you need to keep a piece of text safe while you delete other things,
or to carry two pieces at once, one in `a` and one in `b`. Collecting
scattered lines with `"A` puts them all down in one go.

## The trap

Forgetting which letter holds what. Use few, and pick them by meaning: `t`
for the title, `u` for the URL. `:registers` lists what each one holds.

```json
{
  "id": "named-register",
  "title": "\"a \"A",
  "keys": [["\"ayy", "copy the line into a"], ["\"Ayy", "add the line to a"], ["\"ap", "put a"]],
  "scenarios": [
    {"id": "keep-constant", "ft": "python",
     "vars": {"const": [{"name": "LICENSE", "value": "\"MIT\""}, {"name": "AUTHOR", "value": "\"Sam Lee\""},
                        {"name": "VERSION", "value": "\"2.1\""}],
              "junk": ["DEBUG_ONLY = True", "TRACE = 1", "SKIP_AUTH = True"]},
     "goal": "Delete the line {junk}, then copy the {name} line to the end of the file.",
     "lines": ["{name} = {value}", "{junk}", "def main():", "    pass"],
     "solution": "\"ayyjddG\"ap"},
    {"id": "collect-items", "ft": "markdown",
     "vars": {"a": ["add retries", "fix the import"], "b": ["write the runbook", "rotate the keys", "tag the release"]},
     "goal": "Copy both unchecked items to the end of the file, in order.",
     "lines": ["Shipped the importer.", "- [ ] {a}", "Talked about the cache.", "- [ ] {b}", "", "## Actions"],
     "solution": "j\"ayyjj\"AyyG\"ap"},
    {"id": "move-past-delete", "ft": "python",
     "vars": {"const": ["LICENSE = \"MIT\"", "OWNER = \"platform\"", "TIER = 2"], "flag": ["DEBUG", "TRACE"]},
     "goal": "Move the first line to the end of the file, and delete the {flag} line.",
     "lines": ["{const}", "import os", "import sys", "", "{flag} = False", "", "def main():", "    pass"],
     "solution": "\"add/{flag}<CR>ddG\"ap"},
    {"id": "two-settings", "ft": "python",
     "vars": {"h": ["localhost", "db.internal"], "p": ["5432", "6379", "3306"]},
     "goal": "Copy both settings to the end of the file, PORT above HOST.",
     "lines": ["HOST = \"{h}\"", "PORT = {p}", "", "def connect():", "    return open_socket(HOST, PORT)"],
     "solution": "\"ayyj\"byyG\"bp\"ap"}
  ]
}
```
