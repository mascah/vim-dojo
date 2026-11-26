# ; after f

`;` repeats the last `f`, `F`, `t` or `T` on the line, in the same
direction, and `,` repeats it the other way. So when the character you want
is the third comma, not the first, type `f,` once and `;` until you land.

| Key | What it does |
| --- | --- |
| `;` | Repeat the last `f` `F` `t` `T` |
| `,` | Repeat it in the other direction |

## Example

The cursor, shown as `[ ]`, is at the start of a row of CSV, and the plan
in the fourth column should change:

```text
[1]042,Ana,Lisbon,basic,active
```

Type `f,;;` to reach the third comma, then `l`, then `cwpro` and `Esc`:

```text
1042,Ana,Lisbon,pr[o],active
```

## When to use it

On lines with repeated punctuation: arguments, CSV fields, paths, chained
calls. `f` plus a few `;` is often shorter than counting with `3f,`, because
you can watch each step land and stop when it is right.

## The trap

Typing `f,` again instead of `;`. It works, but it is twice the keys, and it
loses the habit. If you go one too far, `,` steps back one without starting
over. After `t`, `;` jumps past the character it stopped before, to the
next one, so it does not get stuck.

```json
{
  "id": "semicolon",
  "title": ";",
  "keys": [[";", "repeat the last f t F T"], [",", "repeat it the other way"]],
  "scenarios": [
    {"id": "csv-plan", "ft": "text", "start": "{id},",
     "vars": {"id": ["1042", "2177", "3051"], "name": ["Ana", "Ravi", "Mei"], "city": ["Lisbon", "Pune", "Osaka"],
              "plan": [{"old": "basic", "new": "pro"}, {"old": "trial", "new": "team"}, {"old": "pro", "new": "enterprise"}]},
     "goal": "Change {name}’s plan from {old} to {new}.",
     "lines": ["id,name,city,plan,status", "{id},{name},{city},{old},active"],
     "solution": "f,;;lcw{new}<Esc>"},
    {"id": "printf-arg", "ft": "go", "start": "fmt",
     "vars": {"arg": [{"old": "total", "new": "sum"}, {"old": "price", "new": "cost"}, {"old": "limit", "new": "max"}],
              "first": ["name", "user", "label"]},
     "goal": "Rename the last argument from {old} to {new}.",
     "lines": ["fmt.Printf(\"%s %d %v\\n\", {first}, count, {old})"],
     "solution": "f,;;wcw{new}<Esc>"},
    {"id": "release-dir", "ft": "sh", "start": "ROOT",
     "vars": {"dir": [{"old": "releases", "new": "builds"}, {"old": "current", "new": "staging"}, {"old": "deploys", "new": "archive"}]},
     "goal": "In ROOT, change the directory {old} to {new}.",
     "lines": ["ROOT=/srv/shop/{old}/app", "LOG=/var/log/shop"],
     "solution": "f/;;lcw{new}<Esc>"},
    {"id": "back-to-arg", "ft": "python", "start": "{last})",
     "vars": {"a": ["order", "cart"], "b": ["user", "account"], "last": ["notify", "dry_run"]},
     "goal": "Put the cursor on the comma just after {a}.",
     "lines": ["checkout({a}, {b}, region, {last})"],
     "solution": "F,;;"}
  ]
}
```
