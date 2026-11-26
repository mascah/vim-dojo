# y p P

`y` yanks, which is Vim's word for copy: it takes a motion like `d` but leaves
the text where it is. `yy` yanks the whole line. `p` puts the last yanked or
deleted text after the cursor, and `P` puts it before. Whole lines go below or
above the current line instead of into it.

| Key | What it does |
| --- | --- |
| `y{motion}` | Copy over a motion |
| `yy` | Copy the whole line |
| `p` | Put after the cursor, or below the line |
| `P` | Put before the cursor, or above the line |

## Example

The cursor, shown as `[ ]`, is on the first of two steps in the wrong order:

```text
[n]pm test
npm install
npm publish
```

Type `ddp`. The line is deleted, then put back below the next one:

```text
npm install
[n]pm test
npm publish
```

## When to use it

Every time text moves or repeats. Delete then put moves it: `ddp` swaps two
lines and `xp` swaps two letters. Yank then put copies it: `yyp` duplicates
a line, ready to edit the copy.

## The trap

Yanking, deleting something else, then pressing `p` and getting the deleted
text back. Deleting also fills the register `p` reads. The registers lesson
later shows how to get the yank back; until then, put before you delete
anything else.

```json
{
  "id": "yank-put",
  "title": "y p P",
  "keys": [["y{motion}", "copy over a motion"], ["yy", "copy the line"], ["p", "put after, or below"], ["P", "put before, or above"]],
  "generators": [
    {"at": "^.*\\S.*$", "keys": "yyp", "goal": "Duplicate the highlighted line, putting the copy below it."},
    {
      "at": "\\<\\a\\w\\{3,} \\ze\\a",
      "cursor": "first",
      "keys": "ywP",
      "goal": "Repeat the highlighted word and its space, so the word appears twice."
    }
  ],
  "scenarios": [
    {"id": "swap-steps", "ft": "text",
     "vars": {"steps": [{"first": "make build", "second": "make test", "third": "make deploy"},
                        {"first": "git add .", "second": "git commit", "third": "git push"},
                        {"first": "npm install", "second": "npm test", "third": "npm publish"}]},
     "lines": ["{second}", "{first}", "{third}"],
     "goal": "Put the first two lines in order: \"{first}\" before \"{second}\".",
     "solution": "ddp"},
    {"id": "swap-letters", "ft": "text", "start": "{at}",
     "vars": {"typo": [{"line": "Open teh settings first.", "at": "eh", "good": "the"},
                       {"line": "Save adn close the file.", "at": "dn", "good": "and"},
                       {"line": "Wait fro the build.", "at": "ro", "good": "for"}]},
     "lines": ["{line}"],
     "goal": "Fix the swapped letters so the word reads \"{good}\".",
     "solution": "xp"},
    {"id": "line-to-top", "ft": "python", "start": "import {late}",
     "vars": {"late": ["os", "sys", "json"], "a": ["re", "csv"], "b": ["time", "math"]},
     "lines": ["import {a}", "import {b}", "", "def main():", "    pass", "import {late}"],
     "goal": "Move \"import {late}\" from the bottom to the very first line.",
     "solution": "ddggP"}
  ]
}
```
