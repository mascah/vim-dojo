# x r

Two keys for one character, without going into Insert mode. `x` deletes the
character under the cursor. `r` followed by a character replaces the one under
the cursor with it, and leaves you in Normal mode, so no `Esc` is needed.

| Key | What it does |
| --- | --- |
| `x` | Delete the character under the cursor |
| `r{c}` | Replace the character under the cursor with `{c}` |

## Example

The cursor, shown as `[ ]`, is on the `!` of a test that should be for
equality:

```text
if retries [!]= limit:
```

Type `r=`:

```text
if retries [=]= limit:
```

On a doubled letter, as in `priint`, `x` on either `i` takes it out.

## When to use it

For one-character fixes: a doubled letter, a stray comma, the wrong digit, a
`!=` that should be `==`. Both keys keep you in Normal mode, ready for the
next move, and `.` repeats either one.

## The trap

Reaching for `x` to delete more than a character or two. Every press is one
character, and five presses are five keys that `dw`, a text object, or a
count would do in one go. The same goes for `r`: when the new text is longer
than one character, the next lesson's `s` is the key.

```json
{
  "id": "x-r",
  "title": "x r",
  "keys": [["x", "delete the character under the cursor"], ["r{c}", "replace it with {c}"]],
  "generators": [
    {"at": "[.,;:]", "keys": "x", "goal": "Delete the highlighted character."},
    {
      "at": "\\<\\d\\>",
      "keys": "r{d}",
      "vars": {"d": ["0", "1", "2", "3", "5", "8", "9"]},
      "goal": "Change the highlighted digit to {d}."
    },
    {"at": "\\w\\zs_\\ze\\w", "keys": "r-", "goal": "Change the highlighted underscore to a hyphen."}
  ],
  "scenarios": [
    {"id": "extra-letter", "ft": "python", "start": "{at}",
     "vars": {"typo": [{"bad": "priint", "good": "print", "at": "ii"},
                       {"bad": "loggger", "good": "logger", "at": "ggg"},
                       {"bad": "appennd", "good": "append", "at": "nn"}]},
     "lines": ["for item in items:", "    {bad}(item)"],
     "goal": "Remove the extra letter so the call reads {good}(item).",
     "solution": "x"},
    {"id": "fix-operator", "ft": "python", "start": "!",
     "vars": {"name": ["retries", "count", "attempts"], "limit": ["0", "3", "10"],
              "action": ["stop", "retry", "log_error"]},
     "lines": ["if {name} != {limit}:", "    {action}()"],
     "goal": "Make the condition test for equality (==).",
     "solution": "r="}
  ]
}
```
