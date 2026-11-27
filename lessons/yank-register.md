# "0

Every yank and every delete goes into the unnamed register, which is what
`p` puts. So yank a word, delete another, and `p` puts the deleted one.
Register `0` is different: it holds only your last yank, and deletes never
touch it. `"0p` puts what you copied, however much you deleted since.

| Key | What it does |
| --- | --- |
| `"0p` | Put the last yank after the cursor |
| `"0P` | Put the last yank before the cursor |

## Example

The cursor, shown as `[ ]`, is on the region you want in both other lines:

```text
primary = "[e]u-west-1"
backup = "TBD"
fallback = "TBD"
```

Type `yi"`, then `j`, `di"` and `"0P`, then the same again on the last line:

```text
primary = "eu-west-1"
backup = "eu-west-1"
fallback = "eu-west-[1]"
```

## When to use it

Whenever you copy something and then delete other text before putting it:
replacing several placeholders with one value, or overwriting a line with
a copy of another. `p` would put the placeholder you just deleted; `"0p`
puts the copy.

## The trap

Pressing `p`, getting the deleted text back, and starting again with a
fresh yank. You have not lost the copy: it is in `"0`. The same happens
when you paste over a selection, since the replaced text becomes the
unnamed register, so the second paste needs `"0p`.

```json
{
  "id": "yank-register",
  "title": "\"0",
  "keys": [["\"0p", "put the last yank"], ["\"0P", "put it before the cursor"]],
  "scenarios": [
    {"id": "copy-region", "ft": "python",
     "vars": {"region": ["eu-west-1", "us-east-2", "ap-south-1"],
              "names": [{"a": "primary", "b": "backup", "c": "fallback"}, {"a": "main", "b": "replica", "c": "standby"}]},
     "goal": "Replace both TBD values with \"{region}\".",
     "lines": ["{a} = \"{region}\"", "{b} = \"TBD\"", "{c} = \"TBD\""],
     "solution": "yi\"jdi\"\"0Pjdi\"\"0P"},
    {"id": "replace-name", "ft": "python", "start": "{new}",
     "vars": {"new": ["fetch_all", "load_rows", "read_batch"], "old": ["get_rows", "read_all"]},
     "goal": "Replace {old} with {new} in both calls.",
     "lines": ["NEW = {new}", "", "{old}(1)", "{old}(2)"],
     "solution": "yiwjjviw\"0pj0viw\"0p"},
    {"id": "fill-args", "ft": "python", "start": "{id}",
     "vars": {"id": ["user_id", "order_id", "tenant"]},
     "goal": "Replace both TBD arguments with {id}.",
     "lines": ["{id} = request.{id}", "audit(TBD)", "notify(TBD)"],
     "solution": "yiw+f(ldiw\"0P+f(ldiw\"0P"},
    {"id": "fix-run-line", "ft": "yaml",
     "vars": {"cmd": ["make test", "npm test", "go test ./..."], "last": ["make deploy", "make release"]},
     "goal": "Replace the TODO run line with a copy of the first run line.",
     "lines": ["steps:", "  - run: {cmd}", "  - run: TODO", "  - run: {last}"],
     "solution": "jyyjdd\"0P"}
  ]
}
```
