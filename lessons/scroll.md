# Ctrl-D Ctrl-U

`Ctrl-D` scrolls down half a screen and takes the cursor with it, the same
number of lines. `Ctrl-U` scrolls up. They are for reading through a file
when you do not know exactly where the thing you want is.

| Key | What it does |
| --- | --- |
| `Ctrl-D` | Down half a screen |
| `Ctrl-U` | Up half a screen |

## Example

In the dojo, the practice window always moves eight lines, so the goals do
not depend on the size of your window. The cursor, shown as `[ ]`, is on
line 3:

```text
 3 [i]mport "fmt"
```

Type `Ctrl-D`:

```text
11 [f]unc main() {
```

In your own editing, the distance is half the window's height, set by the
`scroll` option.

## When to use it

When you are looking for something and will know it when you see it: the
next function, the test you remember is somewhere below. Press `Ctrl-D` and
read as the text goes by. Once you can see the target, switch to a motion
that lands on it.

## The trap

Using `Ctrl-D` to reach a line you already know. A count with `G`, a search,
or `}` is exact; scrolling gets you near and leaves you to finish the move.
And a count before `Ctrl-D` changes the distance for every later press too,
until the window is resized.

```json
{
  "id": "scroll",
  "title": "Ctrl-D Ctrl-U",
  "keys": [["Ctrl-D", "down half a screen"], ["Ctrl-U", "up half a screen"]],
  "moves": true,
  "generators": [
    {"keys": "<C-D>"},
    {"keys": "<C-U>"},
    {"keys": "<C-D><C-D>"}
  ]
}
```
