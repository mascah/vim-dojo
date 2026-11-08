# vim dojo

A disposable practice repo for the config in `~/.vimrc`. Nothing here matters, break it freely.

Start a session:

    cd ~/GitHub/mascah/vim-dojo && vim

Reset to the starting state (dirty on purpose, so git hunks exist) at any time:

    git checkout -- . && git apply dirty.patch

## How to use this

- Fifteen minutes a day. One week per section. Repeat a section until the keys come out without thinking.
- Pick ONE thing from the current week and force yourself to use it in real work all day. That is where muscle memory forms. Write it on the last line of this file each morning.
- Every drill names a marker like `DRILL 1.1`. Find it with `Space /` and type the marker. That is itself drill 2.3.
- When you catch yourself pressing the same key more than three times (jjjj, llll, xxxx), stop. There is a motion for that. Find it before continuing.
- The grammar is verb then noun. Verbs: `d` delete, `c` change, `y` yank, `>` indent, `gc` comment. Nouns: `w` word, `iw`/`aw` inner/around word, `i"`/`a"` quotes, `i(`/`a(` parens, `ip`/`ap` paragraph, `it`/`at` tag, any motion, any search. Every noun you learn multiplies every verb you already know.

## Week 1: motions and text objects (app.py)

- [ ] 1.1  `ci"` inside "widget" changes the string. Type a name, Esc, `u`. Try `ca"` to see the difference: a is around, i is inside.
- [ ] 1.2  `di(` inside the sum( ) parens deletes the arguments. `u`. Then `yi(` and watch hlyank flash exactly what was copied.
- [ ] 1.3  `gcip` comments the paragraph (ip = inner paragraph). `gcip` again restores it.
- [ ] 1.4  Read the relative number beside a line six below you and type `6j`. Then `d3j` deletes four lines. `u`.
- [ ] 1.5  `f,` jumps to the next comma on the line, `;` repeats, `,` goes back. `t,` stops one short. `dt,` deletes up to the comma.
- [ ] 1.6  `ciw` on a word, type a replacement, Esc. Move to another word and press `.` to repeat the whole change. This is why `ciw` beats `cw`.
- [ ] 1.7  `dap` deletes a paragraph including its blank line. `yap` then `P` duplicates a function.
- [ ] 1.8  `0` line start, `^` first non-blank, `$` line end. `I` and `A` enter insert mode there.
- [ ] 1.9  `V` selects lines, `>` indents them, `.` indents again. `vi(` selects inside parens visually.

## Week 2: files, buffers, jumps

- [ ] 2.1  `Space f`, type `mai`, Enter. `Space f`, type `app`, Enter. `Ctrl-^` flips between them. Do it ten times.
- [ ] 2.2  `Space b` shows both buffers. `:bd` closes one. `Space o` brings it back from history.
- [ ] 2.3  `Space /`, type `DRILL 2`, pick one. BLines is a fuzzy `/` with a list.
- [ ] 2.4  In main.go, cursor on findByTag's opening `{`, press `%`. Press `%` again.
- [ ] 2.5  Cursor on `loadItems`, press `*`. It searches the word under the cursor. `n` next, `N` previous. `Ctrl-O` returns to where you started, `Ctrl-I` goes forward again.
- [ ] 2.6  `gg` top, `G` bottom, `25G` line 25, `Ctrl-D` and `Ctrl-U` half pages. `''` bounces back to where you were.
- [ ] 2.7  `ma` sets mark a. Go anywhere. `'a` returns. Capital marks like `mA` work across files.
- [ ] 2.8  `:vs app.py` opens a vertical split. `Ctrl-h` and `Ctrl-l` move between them. `:q` closes one.
- [ ] 2.9  `Ctrl-t` toggles NERDTree. Notice how often you still want it once 2.1 is automatic.

## Week 3: search, replace, quickfix

- [ ] 3.1  `/item` Enter, then `n` `n` `n`. `Space Space` clears the highlight.
- [ ] 3.2  `:%s/item/thing/gc` replaces with a y/n prompt per match. `u` undoes all of it at once.
- [ ] 3.3  `V` select a few lines, press `:` and vim fills in `'<,'>`. Type `s/Price/Cost/g`. Only the selection changes.
- [ ] 3.4  `:grep TODO` then `:copen`. Enter on a row jumps there. `:cn` and `:cp` step without the window. `:cclose`.
- [ ] 3.5  `:grep TODO` then `:cdo s/TODO/FIXME/g | update`. Every match in every file is changed and saved. Check the gutter, then reset the dojo.
- [ ] 3.6  `Space g`, type `Price`. Same search, interactive, one result at a time. Rg to jump somewhere, grep to work through a list.
- [ ] 3.7  Search is a motion: `d/return` Enter deletes from the cursor up to the word return. `u`.
- [ ] 3.8  `:Maps`, type `hunk`. `:Helptags`, type `text-objects`. These two answer "what does X do" forever.

## Week 4: git and LSP

The repo starts dirty on purpose. If `]c` does nothing, run the reset command at the top.

- [ ] 4.1  Open main.go. Gutter signs mark changed lines: `+` added, `~` changed, `_` a deletion below. `]c` and `[c` jump between hunks. `Space hp` previews the hunk's diff; `Ctrl-W z` closes the preview.
- [ ] 4.2  `Space hs` stages one hunk. `:G` opens fugitive's status and the hunk is under Staged. In that window `s` stages, `u` unstages, `=` shows the diff inline, `cc` opens a commit message. `:G blame` shows who last touched each line.
- [ ] 4.3  `Space hu` reverts a hunk to what git has. That is `git checkout -p` for one hunk.
- [ ] 4.4  In app.py, `]d` jumps to the type error at `count: int = "three"`. `Space d` prints the full message. `K` on `field` shows its docs. `gd` on `describe` goes to its definition, `Ctrl-O` returns, `gr` lists every reference.
- [ ] 4.5  Cursor on `describe`, `Space rn`, type `render`, Enter. Both the definition and the call in main change.
- [ ] 4.6  In main.go on the marked blank line, `i` then type `fmt.Pr`. The popup lists candidates. `Tab` moves down, `Shift-Tab` up, Enter accepts the highlighted one. With nothing highlighted Enter is a plain newline. `Ctrl-E` closes the popup.
- [ ] 4.7  `Space ca` on a line with a diagnostic lists code actions when the server offers any.

## Beyond this file

- `vimtutor` in your terminal. Thirty minutes, built in. Do it once even if parts feel basic; it covers registers, visual mode and text objects in a way that sticks.
- Practical Vim by Drew Neil. Written as 120 short tips, each one a workflow people actually use daily. One tip a day.
- vimgolf.com. Each challenge is one edit. After you submit you see solutions in fewer keystrokes. Fastest cure for not knowing what you don't know.
- `:help` is the manual. Options go in quotes, commands keep their colon, keys as the docs write them: `:help 'scrolloff'`, `:help :cdo`, `:help CTRL-O`, `:help text-objects`.

## Today's one thing

