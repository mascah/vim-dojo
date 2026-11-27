# @@

`@@` plays whichever macro you played last. After one `@a`, keep going with
`@@`, a line at a time, looking at each result before you go on. It saves
remembering the register, and it is two keys on the same hand.

| Key | What it does |
| --- | --- |
| `@@` | Play the last macro again |

## Example

The cursor, shown as `[ ]`, is on the first of three calls that need
`await`:

```text
[f]etch_users()
fetch_orders()
fetch_items()
```

Type `qa`, `Iawait `, `Esc`, `j`, `q` to record on the first line, then
`@a` for the second and `@@` for the third:

```text
await fetch_users()
await fetch_orders()
[a]wait fetch_items()
```

## When to use it

When you would rather step than count: the lines are not all alike, some
may need skipping, or you are not sure the macro is right yet. Play it with
`@a` once, check, then `@@` as often as each line deserves, and `j` past the
ones that should stay.

## The trap

Pressing `@@` before any macro has been played in this session, which does
nothing useful. The first play must name the register, `@a`; only after
that does `@@` know what to repeat. If you counted, `3@a` is shorter than
three presses of `@@`.

```json
{
  "id": "macro-again",
  "title": "@@",
  "keys": [["@@", "play the last macro again"]],
  "scenarios": [
    {"id": "await-calls", "ft": "python",
     "vars": {"calls": [{"a": "fetch_users()", "b": "fetch_orders()", "c": "fetch_items()"},
                        {"a": "load_config()", "b": "open_cache()", "c": "warm_index()"},
                        {"a": "send_email()", "b": "send_sms()", "c": "send_push()"}],
              "word": ["await ", "yield "]},
     "goal": "Put {word}before each of the three calls.",
     "lines": ["{a}", "{b}", "{c}"],
     "solution": "qaI{word}<Esc>jq@a@@"},
    {"id": "drop-prefix", "ft": "python",
     "vars": {"prefix": ["old_", "tmp_", "legacy_"]},
     "goal": "Remove {prefix} from the start of every name.",
     "lines": ["{prefix}user = None", "{prefix}order = None", "{prefix}item = None", "{prefix}cart = None"],
     "solution": "qadf_jq@a@@@@"},
    {"id": "add-retries", "ft": "python",
     "vars": {"n": ["3", "5"], "a": ["fetch", "pull"], "b": ["save", "store"]},
     "goal": "Give each retry() call a second argument, {n}.",
     "lines": ["retry({a})", "retry({b})", "retry(load)"],
     "solution": "qa0f)i, {n}<Esc>jq@a@@"},
    {"id": "comment-out", "ft": "go",
     "vars": {"fn": ["trace", "dump", "debugf"]},
     "goal": "Comment out the three {fn} calls with // at the start of each line.",
     "lines": ["{fn}(\"start\")", "{fn}(\"items\", items)", "{fn}(\"done\")"],
     "solution": "qaI// <Esc>jq@a@@"}
  ]
}
```
