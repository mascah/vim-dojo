# { }

`}` moves forward to the next blank line, and `{` back to the previous one.
Text and code are mostly blocks separated by blank lines: paragraphs,
functions, groups of settings. So these hop a block at a time, however long
each block is.

| Key | What it does |
| --- | --- |
| `}` | Forward to the next blank line |
| `{` | Back to the previous blank line |

## Example

The cursor, shown as `[ ]`, is inside the first function:

```text
def load(path):
    with open(path) as f:
        return [j]son.load(f)

def save(path, data):
```

Type `}`:

```text
def load(path):
    with open(path) as f:
        return json.load(f)
[]
def save(path, data):
```

The cursor is on the blank line, ready for `j` into the next block or `o`
to start a new one.

## When to use it

To get past a block you are not interested in, or to the gap between two
blocks to add something there. Two or three presses cross most of a file
section.

## The trap

Expecting `}` to land on the next block's first line. It stops on the blank
line before it. And a line that holds only spaces is not blank to these
motions, so they jump past it.

```json
{
  "id": "paragraph",
  "title": "{ }",
  "keys": [["}", "next blank line"], ["{", "previous blank line"]],
  "moves": true,
  "generators": [
    {"keys": "}"},
    {"keys": "{"},
    {"keys": "}}"},
    {"keys": "{{"}
  ]
}
```
