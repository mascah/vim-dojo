# Marks

`m` followed by a letter sets a mark at the cursor: `ma` marks the spot as
`a`. Later, `'a` jumps to that line's first non-blank and `` `a `` to the exact
spot. A mark is also a motion, so `d'a` deletes every line from the mark to
the cursor.

| Key | What it does |
| --- | --- |
| `m{a}` | Set mark `{a}` at the cursor |
| `'{a}` | Jump to the line of mark `{a}` |
| `` `{a} `` | Jump to the exact spot of mark `{a}` |

## Example

The cursor, shown as `[ ]`, is on the line that opens a generated block:

```text
[#] BEGIN generated
retries = 3
backoff = 1.5
# END generated
run(config)
```

Type `ma`, then `/# END` and Enter, then `d'a`:

```text
[r]un(config)
```

## When to use it

When a place matters and you are about to leave it: the top of a block you
will delete, a line you will come back to after reading elsewhere. Use `'`
when the line is enough and `` ` `` when the column matters.

## The trap

Setting a mark and then reaching for it with a search or scrolling anyway.
The mark is there to be used. Note that `'a` and `` `a `` are different keys
with different targets: the line's first non-blank, or the very spot you
marked.

```json
{
  "id": "marks",
  "title": "m ' `",
  "keys": [["m{a}", "set mark {a}"], ["'{a}", "jump to its line"], ["`{a}", "jump to its spot"]],
  "scenarios": [
    {"id": "delete-block", "ft": "python", "start": "# BEGIN",
     "vars": {"tag": ["generated", "vendored", "autogen"], "x": ["retries", "limit"], "y": ["backoff", "delay"]},
     "goal": "Delete the {tag} block, from the BEGIN line to the END line.",
     "lines": ["config = load()", "# BEGIN {tag}", "{x} = 3", "{y} = 1.5", "mode = \"strict\"",
               "# END {tag}", "run(config)"],
     "solution": "ma/# END<CR>d'a"},
    {"id": "back-to-spot", "ft": "go", "start": "return nil",
     "vars": {"name": [{"field": "Timeout", "value": "30"}, {"field": "Retries", "value": "5"},
                       {"field": "Workers", "value": "8"}]},
     "marked": {"a": "{value},"},
     "goal": "Mark a is on the {field} value you were editing. Go back to that exact spot.",
     "lines": ["func defaults() *Config {", "    return &Config{", "        Name:    \"orders\",",
               "        {field}: {value},", "    }", "}", "", "func validate(c *Config) error {",
               "    if c.Name == \"\" {", "        return errNoName", "    }", "    return nil", "}"],
     "solution": "`a"},
    {"id": "line-of-mark", "ft": "markdown", "start": "## Notes",
     "vars": {"mark": ["b", "t", "q"], "step": ["Install", "Configure", "Deploy"]},
     "marked": {"{mark}": "{step} the"},
     "goal": "Mark {mark} is on the \"{step}\" step. Jump to the start of its line.",
     "lines": ["# Release checklist", "", "1. {step} the service from the release branch.",
               "2. Check the dashboards for an hour.", "3. Tell the support channel.", "", "## Notes", "",
               "Ask in the team channel if a step fails."],
     "solution": "'{mark}"},
    {"id": "delete-to-mark", "ft": "yaml", "start": "    run: make {job}",
     "vars": {"job": ["lint", "audit", "bench"]},
     "marked": {"s": "  - name: {job}"},
     "goal": "Mark s is on the {job} step's name. Delete the whole step, from the mark down to the cursor's line.",
     "lines": ["steps:", "  - name: build", "    run: make build", "  - name: {job}", "    run: make {job}",
               "  - name: cleanup", "    run: make clean", "  - name: test", "    run: make test"],
     "solution": "d's"}
  ]
}
```
