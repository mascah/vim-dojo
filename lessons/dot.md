# .

`.` repeats your last change. A change is anything that edits text: `x`,
`dd`, `ciw` and the word you typed after it, `A` and what you appended. The
dot replays all of it as one key, wherever the cursor is now.

| Key | What it does |
| --- | --- |
| `.` | Repeat the last change at the cursor |

## Example

The cursor, shown as `[ ]`, is on the first of three statuses:

```text
status["import"] = "[p]ending"
status["export"] = "pending"
status["backup"] = "pending"
```

Type `ciwqueued`, `Esc`, then `j.` twice:

```text
status["import"] = "queued"
status["export"] = "queued"
status["backup"] = "queue[d]"
```

## When to use it

Whenever you are about to make the same edit again. Make it once, as one
complete change, then move and press `.` for each of the others. The move
can be anything: `j`, `w`, a search.

## The trap

Making the first edit in pieces, so the dot repeats only the last piece.
`x` four times repeats as one `x`; `d4l` or `dw` repeats as the whole thing.
Likewise, typing `i`, moving with arrow keys inside Insert mode, and typing
more breaks the change in two. Plan the first edit so that it does
everything in one go, ending with `Esc`.

```json
{
  "id": "dot",
  "title": ".",
  "keys": [[".", "repeat the last change"]],
  "scenarios": [
    {"id": "pending-jobs", "ft": "python", "start": "pending",
     "goal": "Mark all three jobs as queued.",
     "lines": ["status[\"import\"] = \"pending\"", "status[\"export\"] = \"pending\"", "status[\"backup\"] = \"pending\""],
     "solution": "ciwqueued<Esc>j.j."},
    {"id": "retry-counts", "ft": "go", "start": "maxRetries: {old}",
     "vars": {"old": ["2", "3"], "new": ["5", "7", "9"]},
     "goal": "Set maxRetries to {new} for all three workers.",
     "lines": ["workers := []Worker{", "    {name: \"api\", maxRetries: {old}},", "    {name: \"log\", maxRetries: {old}},",
               "    {name: \"job\", maxRetries: {old}},", "}"],
     "solution": "f{old}r{new}j.j."},
    {"id": "strip-debug-args", "ft": "python", "start": "def dispatch",
     "vars": {"flag": ["debug=True", "verbose=True", "dry_run=False"]},
     "goal": "Remove the final {flag} argument from each publish() call.",
     "lines": ["def dispatch(event, config):", "    publish(event.id, {flag})", "    if config.save_archive:",
               "        publish(event.archive_id, {flag})", "    audit(event.id, {flag})",
               "    publish(config.default_id, {flag})"],
     "solution": "/publish<CR>f,dt)nf,.nf,."},
    {"id": "end-semicolons", "ft": "javascript", "start": "const {a}",
     "vars": {"a": ["host", "base"], "b": ["port", "limit"], "c": ["debug", "retries"]},
     "goal": "End each of the three lines with a semicolon.",
     "lines": ["const {a} = process.env.A", "const {b} = process.env.B", "const {c} = process.env.C", "",
               "start({a}, {b}, {c});"],
     "solution": "A;<Esc>j.j."}
  ]
}
```
