" Run from the repository root with vim -Nu NONE -i NONE -n -es -S test/dojo.vim
" Set DOJO_SKILL=move to check the solutions of one skill only.
let s:state = tempname()
let g:vim_dojo_state_dir = s:state . '/initial'
let g:vim_dojo_drill_dir = s:state . '/custom'
let g:vim_dojo_demo_delay = 0
call setline(1, 'An unsaved edit in the original window')
let s:original = bufnr('%')
let s:root = fnamemodify(expand('<sfile>:p'), ':h:h')

function! s:Panel() abort
  return join(getbufline(winbufnr(1), 1, '$'), "\n")
endfunction

function! s:Records() abort
  let dir = g:vim_dojo_state_dir
  return map(sort(readdir(dir, {name -> name =~# '\.json$'})), 'json_decode(readfile(dir . "/" . v:val)[0])')
endfunction

function! s:Last() abort
  return s:Records()[-1]
endfunction

function! s:Drill(id) abort
  for technique in vim_dojo#drills#Techniques()
    for drill in technique.drills
      if drill.id ==# a:id
        return extend(copy(drill), {'phase': 'Test'})
      endif
    endfor
  endfor
  throw 'No drill ' . a:id
endfunction

" A headless Vim raises InsertLeave by itself but not TextChanged or
" CursorMoved, so they are raised by hand after typing.
function! s:Type(keys) abort
  call feedkeys(a:keys, 'xt')
  doautocmd TextChanged
  doautocmd CursorMoved
endfunction

function! s:Solve() abort
  call s:Type(vim_dojo#drills#Raw(vim_dojo#Task().tokens))
endfunction

" Types into a real Vim and waits for its screen to show the pattern.
function! s:Typed(keys, pattern) abort
  call term_sendkeys(s:term, a:keys)
  for attempt in range(100)
    call term_wait(s:term, 50)
    let screen = join(map(range(1, term_getsize(s:term)[0]), 'term_getline(s:term, v:val)'), "\n")
    if screen =~# a:pattern
      break
    endif
  endfor
  call assert_match(a:pattern, screen)
  return screen
endfunction

try
  " map-readable and map-states on a fresh state directory.
  execute 'source ' . fnameescape(s:root . '/dojo.vim')
  call assert_equal('nofile', &l:buftype)
  let s:map = getline(1, '$')
  call assert_equal([], filter(copy(s:map), 'strdisplaywidth(v:val) > 80'))
  call assert_match('○ new.*◐ shaky.*● solid.*Enter.*d diagnostic.*q close', s:map[-1])
  call assert_match('▶ Start today''s session', getline('.'))
  call assert_match('New here', join(s:map))
  let s:skills = filter(copy(s:map), 'v:val =~# "^\\S.*of \\d\\+ solid"')
  call assert_true(len(s:skills) >= 4)
  call assert_equal([], filter(copy(s:skills), 'v:val !~# "^\\S.\\{-}  [○◐●]\\+ \\+0 of"'))
  call assert_equal([], filter(copy(s:map), 'v:val =~# "^  \\%(◐\\|●\\)"'))
  let s:rows = filter(s:map[: -2], 'v:val =~# "^  ○ "')
  call assert_true(len(s:rows) > 1)
  call assert_equal([], filter(copy(s:rows), 'v:val !~# " new\\s*$"'))
  " Enter on a closed skill opens it, and again closes it.
  let s:closed = search('^Objects ', 'n')
  let s:before = line('$')
  call cursor(s:closed, 1)
  call feedkeys("\<CR>", 'xt')
  call assert_true(line('$') > s:before)
  call assert_match('^  ○ .*new', getline(s:closed + 1))
  call feedkeys("\<CR>", 'xt')
  call assert_equal(s:before, line('$'))
  " Enter on the session row starts today's session, which teaches first.
  call cursor(search('▶'), 1)
  call feedkeys("\<CR>", 'xt')
  call assert_match('1/2  ·  Practice', s:Panel())
  call assert_match('New technique', s:Panel())
  let s:task = vim_dojo#Task()
  call assert_equal(s:task.lines, getline(1, '$'))
  call assert_equal(s:task.position, [line('.'), col('.')])
  call s:Solve()
  call assert_match(printf('Solved in %d keys · par %d', s:task.par, s:task.par), s:Panel())
  call assert_equal('recalled', s:Last().result)
  call feedkeys("\<CR>", 'xt')
  call assert_match('2/2  ·  Apply', s:Panel())
  call assert_notmatch('New technique', s:Panel())
  call feedkeys('\s', 'xt')
  call assert_match('1 of 2 solved', s:Panel())
  " Enter after the session goes back to the map, where the technique is shaky.
  call feedkeys("\<CR>", 'xt')
  call assert_match('◐ .*shaky\s\+due tomorrow', join(getline(1, '$'), "\n"))
  call feedkeys('q', 'xt')
  call assert_equal(s:original, bufnr('%'))
  call assert_equal('An unsaved edit in the original window', getline(1))
  call assert_true(&modified)

  " teach-first-meeting, demo-not-counted, highlight, auto-check, no-f-keys.
  call vim_dojo#Start([s:Drill('quoted-item')])
  call assert_match('New technique  i" a"', s:Panel())
  call assert_equal(s:Drill('quoted-item').lines, getline(1, '$'))
  call assert_equal('w', strpart(getline('.'), col('.') - 1, 1))
  call assert_equal(repeat([''], 6), map(['<F5>', '<F6>', '<F7>', '<F8>', '<F9>', '<CR>'], 'maparg(v:val, "n")'))
  call assert_notmatch('F\d', s:Panel())
  call assert_equal(1, len(getmatches()))
  call assert_match('"widget"', getmatches()[0].pattern)
  call assert_equal(3, search(getmatches()[0].pattern, 'nw'))
  call setline(line('.') + 1, 'Collateral edit')
  execute "normal! ciwratchet\<Esc>"
  call assert_match('Collateral edit', s:Panel())
  call feedkeys('\r', 'xt')
  call assert_match('widget', getline('.'))
  call assert_notmatch('differs', s:Panel())
  call s:Type("ci\"ratchet\<Esc>")
  call assert_match('Solved in 11 keys · par 11', s:Panel())
  call assert_match('You: c i " r a t c h e t <Esc>', s:Panel())
  call assert_equal('recalled', s:Last().result)
  call assert_equal(11, s:Last().keys)
  call assert_equal('<Cmd>DojoNext<CR>', maparg('<CR>', 'n'))

  " The second drill of a technique shows neither card nor demo.
  call vim_dojo#Start([s:Drill('shipping-status')])
  call assert_notmatch('New technique', s:Panel())
  " recalled-detected: another route solves but is not recalled.
  call vim_dojo#Start([s:Drill('quoted-item')])
  call s:Type("xxxxxxiratchet\<Esc>")
  call assert_match('Solved in 15 keys · par 11', s:Panel())
  call assert_match('This drill practises i" a"', s:Panel())
  call assert_match('Repeated x', s:Panel())
  call assert_equal('solved', s:Last().result)
  " Three-step hints: clue, keys, demo. Any hint makes the attempt assisted.
  call vim_dojo#Start([s:Drill('quoted-item')])
  call feedkeys('\h', 'xt')
  call assert_match('Hint  A text object', s:Panel())
  call feedkeys('\h', 'xt')
  call assert_match('Hint  c i " r a t c h e t <Esc>', s:Panel())
  normal! x
  call feedkeys('\h', 'xt')
  call assert_match('widget', getline('.'))
  call assert_notmatch('Hint  c i', s:Panel())
  call s:Type("ci\"ratchet\<Esc>")
  call assert_match('Solved in 11 keys', s:Panel())
  call assert_equal('assisted', s:Last().result)
  " A learner's own buffer-local Enter survives the panel redrawing.
  call vim_dojo#Start([s:Drill('shipping-status')])
  nnoremap <buffer> <CR> <Nop>
  call feedkeys('\h', 'xt')
  call assert_equal('<Nop>', maparg('<CR>', 'n'))
  nunmap <buffer> <CR>
  call feedkeys('\s', 'xt')
  call assert_match('0 of 1 solved', s:Panel())
  call assert_equal('skipped', s:Last().result)

  " key-count, mapping-aware, insert-dot.
  call vim_dojo#Start([s:Drill('pending-jobs')])
  call s:Type("ciwqueued\<Esc>j.j.")
  call assert_match('Solved in 14 keys · par 14', s:Panel())
  call assert_equal('recalled', s:Last().result)
  inoremap jk <Esc>
  call vim_dojo#Start([s:Drill('pending-jobs')])
  call s:Type('ciwqueuedjkj.j.')
  call assert_match('Solved in 14 keys', s:Panel())
  call assert_match('You: c i w q u e u e d <Esc> j \. j \.', s:Panel())
  call assert_equal('recalled', s:Last().result)
  iunmap jk
  call vim_dojo#Start([s:Drill('pending-jobs')])
  call s:Type("ciwq.\<BS>ueued\<Esc>jciwqueued\<Esc>jciwqueued\<Esc>")
  call assert_match('Solved', s:Panel())
  call assert_equal('solved', s:Last().result)

  " cursor-target: a jump drill advances both steps with no check key.
  call vim_dojo#Start([s:Drill('find-loader')])
  call assert_equal([], getmatches())
  DojoCheck
  call assert_match('Move the cursor onto the definition', s:Panel())
  call s:Type("?^func loadItems\r")
  call assert_match('Found the definition', s:Panel())
  call s:Type("\<C-O>")
  call assert_match('Solved', s:Panel())
  call assert_equal('recalled', s:Last().result)
  " Typed faster than the dojo saw the first stop.
  call vim_dojo#Start([s:Drill('find-describe')])
  call s:Solve()
  call assert_match('Solved', s:Panel())
  " A drill with a cursor target is solved when the cursor lands on it.
  let s:task = {'id': 'to-comma', 'phase': 'Test', 'skill': 'custom', 'ft': 'text',
        \ 'lines': ['alpha, beta'], 'expected': ['alpha, beta'], 'target': [1, 6],
        \ 'goal': 'Move to the comma.', 'hint': 'Find a character.', 'keys': 'f,', 'why': 'f lands on it.'}
  call vim_dojo#Start([s:task])
  call assert_equal([[1, 6, 1]], map(getmatches(), 'v:val.pos1'))
  call s:Type('x')
  call s:Type('f,')
  call assert_match('differs', s:Panel())
  DojoReset
  call s:Type('l')
  call assert_notmatch('Solved', s:Panel())
  call assert_match('Right line', s:Panel())
  call s:Type('f,')
  call assert_match('Solved', s:Panel())
  DojoClose

  " highlight: nothing where finding the text is the exercise, or when off.
  call vim_dojo#Start([s:Drill('catalog-string')])
  call assert_equal([], getmatches())
  let g:vim_dojo_highlight = 0
  call vim_dojo#Start([s:Drill('quoted-item')])
  call assert_equal([], getmatches())
  unlet g:vim_dojo_highlight
  DojoClose

  " nothing-raw-persisted: no state file holds any of the text typed above.
  for s:name in readdir(g:vim_dojo_state_dir)
    call assert_notmatch('ratchet\|queued\|loadItems\|ci"', join(readfile(g:vim_dojo_state_dir . '/' . s:name)))
  endfor

  " commands-removed and focus.
  call assert_equal([0, 0], [exists(':DojoCatalog'), exists(':DojoLessons')])
  DojoFree
  call assert_match('1/1.*Free practice', s:Panel())
  call assert_equal(0, exists(':DojoUsed'))
  DojoClose
  DojoFocus quote
  for s:index in range(3)
    call assert_equal('quote', vim_dojo#Task().technique)
    call assert_match('Focus', s:Panel())
    DojoSkip
  endfor
  call assert_match('0 of 3 solved', s:Panel())
  DojoClose
  call assert_equal(['quote'], vim_dojo#Complete('quo'))

  " schedule-per-technique and old-state-loads, from records written by hand.
  let g:vim_dojo_state_dir = s:state . '/schedule'
  call mkdir(g:vim_dojo_state_dir, 'p')
  let s:now = localtime()
  let s:old = s:now - 4 * 86400
  for [s:file, s:record] in [
        \ ['000000000001-0000000001-000001.json', {'id': 'quoted-item', 'result': 'recalled', 'time': s:old}],
        \ ['000000000002-0000000001-000002.json', {'id': 'pending-jobs', 'result': 'recalled', 'time': s:old}],
        \ ['000000000003-0000000001-000003.json', {'id': 'retry-counts', 'result': 'recalled', 'time': s:now, 'technique': 'dot', 'keys': 8, 'seconds': 5}],
        \ ['000000000004-0000000001-000004.json', {'id': 'find-loader', 'result': 'skipped', 'time': s:now}]]
    call writefile([json_encode(s:record)], g:vim_dojo_state_dir . '/' . s:file)
  endfor
  let s:today = vim_dojo#progress#Day(s:now)
  let s:state_now = vim_dojo#progress#State(vim_dojo#drills#Techniques())
  call assert_equal([1, 2, 1], [s:state_now.quote.box, s:state_now.dot.box, s:state_now.jumplist.box])
  call assert_equal(3, s:state_now.dot.due - s:today)
  call assert_equal(1, s:state_now.jumplist.due - s:today)
  call assert_true(s:state_now.quote.due <= s:today)
  " The v1 record makes quote due today, so the session reviews it first.
  Dojo
  call assert_match('1 due today', getline(1))
  call assert_match('review i" a"', getline(search('▶')))
  call assert_match('◐ i" a"\s\+shaky\s\+due today', join(getline(1, '$'), "\n"))
  call assert_match('◐ \.\s\+shaky\s\+due in 3 days', join(getline(1, '$'), "\n"))
  call cursor(search('▶'), 1)
  call feedkeys("\<CR>", 'xt')
  call assert_match('1/3  ·  Review', s:Panel())
  call assert_equal('quote', vim_dojo#Task().technique)
  call assert_notmatch('New technique', s:Panel())
  DojoClose

  " diagnostic-places: recalled at par places a technique; the rest still teach.
  let g:vim_dojo_state_dir = s:state . '/diagnostic'
  Dojo
  call feedkeys('d', 'xt')
  call assert_match('1/\d\+  ·  Diagnostic', s:Panel())
  call assert_notmatch('New technique\|Hint', s:Panel())
  let s:placed = vim_dojo#Task().technique
  call feedkeys('\h', 'xt')
  call assert_match('No hints', s:Panel())
  call s:Solve()
  call assert_match('Solved', s:Panel())
  call assert_equal(1, s:Last().placed)
  DojoNext
  let s:unplaced = vim_dojo#Task().technique
  DojoSkip
  DojoClose
  call vim_dojo#Focus(s:placed)
  call assert_notmatch('New technique', s:Panel())
  call vim_dojo#Focus(s:unplaced)
  call assert_match('New technique', s:Panel())
  DojoClose
  let s:state_now = vim_dojo#progress#State(vim_dojo#drills#Techniques())
  call assert_equal([3, 0], [s:state_now[s:placed].box, s:state_now[s:unplaced].box])

  " Playing solutions leaves the learner's history, @:, and clipboard alone,
  " and key names cannot pass for the letters inside them.
  let g:vim_dojo_state_dir = s:state . '/isolation'
  call histadd(':', 'write /dev/null')
  call histadd('/', 'learner search')
  let s:clip = has('clipboard_working') ? getreg('+') : ''
  if has('clipboard_working')
    set clipboard=unnamedplus
  endif
  DojoFocus global
  call assert_match('New technique', s:Panel())
  call assert_notmatch('g/', getreg(':'))
  DojoFocus search
  call assert_equal(['write /dev/null', 'learner search'], [histget(':', -1), histget('/', -1)])
  if has('clipboard_working')
    call assert_equal(s:clip, getreg('+'))
    set clipboard=
  endif
  call vim_dojo#Start([s:Drill('word-back')])
  let s:target = vim_dojo#Task().target
  for s:step in range(80)
    if [line('.'), col('.')] == s:target
      break
    endif
    call s:Type("\<Left>")
  endfor
  call assert_match('Solved', s:Panel())
  call assert_match('Arrow keys', s:Panel())
  call assert_equal('solved', s:Last().result)
  " A target that is a line is reached from any column.
  call vim_dojo#Start([s:Drill('file-bottom')])
  call s:Type(repeat('j', 40))
  call assert_match('Solved', s:Panel())
  DojoClose

  " custom-fields: new fields open with their filetype and cursor and report
  " par; a v1 file still loads; a bad file is skipped.
  let g:vim_dojo_state_dir = s:state . '/custom-state'
  call mkdir(g:vim_dojo_drill_dir, 'p')
  call writefile([json_encode({'id': 'v1-drill', 'goal': 'Replace alpha with beta',
        \ 'lines': ['alpha'], 'expected': ['beta'], 'hint': 'Change a word',
        \ 'keys': 'ciwbeta<Esc>', 'why': 'Change replaces text.'})], g:vim_dojo_drill_dir . '/v1.json')
  call writefile([json_encode({'id': 'v2-drill', 'goal': 'Rename the port', 'ft': 'python',
        \ 'start': 'port', 'skill': 'objects', 'technique': 'quote', 'solution': 'f"ci"8443<Esc>',
        \ 'lines': ['host = "local"', 'port = "8080"'], 'expected': ['host = "local"', 'port = "8443"'],
        \ 'hint': 'Change inside the quotes.', 'why': 'ci" replaces the value.'})], g:vim_dojo_drill_dir . '/v2.json')
  call writefile(['{}'], g:vim_dojo_drill_dir . '/invalid.json')
  call writefile([json_encode({'id': 'rename-variable', 'goal': 'Quote it', 'technique': 'quote',
        \ 'lines': ['x = "a"'], 'expected': ['x = "b"'], 'hint': 'Inside quotes.',
        \ 'keys': 'ci"b', 'why': 'Quotes.'})], g:vim_dojo_drill_dir . '/clash.json')
  call assert_match('no technique', execute('DojoFocus v2-drill'))
  call vim_dojo#Start([s:Drill('v2-drill')])
  call assert_equal(['python', [2, 1]], [&l:filetype, [line('.'), col('.')]])
  call assert_notmatch('New technique', s:Panel())
  call s:Type("f\"ci\"8443\<Esc>")
  call assert_match('Solved in 10 keys · par 10', s:Panel())
  call assert_equal(['recalled', 'quote'], [s:Last().result, s:Last().technique])
  call vim_dojo#Start([s:Drill('custom-rename-variable')])
  call s:Type("f\"ci\"b\<Esc>")
  call assert_match('Solved in 7 keys\.', s:Panel())
  call assert_equal(['solved', 'quote'], [s:Last().result, s:Last().technique])
  DojoFocus v1-drill
  call assert_equal('alpha', getline(1))
  call s:Type("ciwbeta\<Esc>")
  call assert_match('Solved in 8 keys\.', s:Panel())
  call assert_equal('solved', s:Last().result)
  DojoClose
  Dojo
  call assert_match('^Custom ', getline(search('^Custom ')))
  call feedkeys('q', 'xt')
  call delete(g:vim_dojo_drill_dir, 'rf')

  " inbox: a range of lines, the filetype, and the note, nothing else.
  new
  setfiletype python
  call setline(1, ['one', 'two', 'three', 'four', 'five', 'six'])
  3,5DojoNote too many keystrokes
  let s:inbox = g:vim_dojo_state_dir . '/inbox'
  call assert_equal(1, len(readdir(s:inbox)))
  let s:entry = json_decode(readfile(s:inbox . '/' . readdir(s:inbox)[0])[0])
  call assert_equal(['ft', 'lines', 'note', 'time'], sort(keys(s:entry)))
  call assert_equal(['three', 'four', 'five'], s:entry.lines)
  call assert_equal(['python', 'too many keystrokes'], [s:entry.ft, s:entry.note])
  bwipeout!
  Dojo
  call assert_match('1 in inbox', getline(1))
  call assert_match('inbox', getline(3))
  call feedkeys('q', 'xt')

  " A blocked state directory warns, and saving resumes once it clears.
  let g:vim_dojo_state_dir = s:state . '/blocked'
  call writefile(['This file blocks the state directory.'], g:vim_dojo_state_dir)
  call vim_dojo#Start([s:Drill('quoted-item'), s:Drill('shipping-status')])
  DojoSkip
  call assert_match('Progress could not be saved', s:Panel())
  call delete(g:vim_dojo_state_dir)
  call s:Solve()
  call assert_notmatch('Progress could not be saved', s:Panel())
  call assert_equal(2, len(readdir(g:vim_dojo_state_dir)))
  DojoClose

  " variants-differ and solutions-valid: every drill, and several variants of
  " every template, solved by typing its own solution, at par and recalled.
  let g:vim_dojo_state_dir = s:state . '/solutions'
  let s:only = $DOJO_SKILL
  for s:technique in vim_dojo#drills#Techniques()
    if !empty(s:only) && s:technique.skill !=# s:only
      continue
    endif
    call assert_true(len(s:technique.drills) >= 3 || !empty(filter(copy(s:technique.drills), 'has_key(v:val, "vars")')),
          \ s:technique.id . ' needs a template or three drills')
    call assert_equal(2, len(s:technique.card), s:technique.id . ' card')
    for s:drill in s:technique.drills
      if has_key(s:drill, 'vars')
        let s:first = vim_dojo#drills#Instance(s:drill)
        let s:differs = 0
        for s:attempt in range(30)
          let s:other = vim_dojo#drills#Instance(s:drill)
          let s:differs = s:differs || s:other.lines !=# s:first.lines || s:other.goal !=# s:first.goal
        endfor
        call assert_true(s:differs, s:drill.id . ' variants differ')
      endif
      for s:attempt in range(has_key(s:drill, 'vars') ? 4 : 1)
        call vim_dojo#Start([extend(copy(s:drill), {'phase': 'Test'})])
        let s:task = vim_dojo#Task()
        call s:Solve()
        call assert_match(printf('Solved in %d keys · par %d', s:task.par, s:task.par), s:Panel(),
              \ s:drill.id . ' ' . string(get(s:task, 'variant', {})))
        call assert_equal('recalled', s:Last().result, s:drill.id . ' detected')
      endfor
    endfor
  endfor
  DojoClose

  " Real typing in a hidden terminal, where the main loop raises TextChanged
  " and CursorMoved and the demo runs on its timer.
  if has('terminal')
    let g:vim_dojo_state_dir = s:state . '/terminal'
    let s:term = term_start([v:progpath, '-Nu', 'NONE', '-i', 'NONE', '-n',
          \ '--cmd', 'let g:vim_dojo_state_dir = ' . string(g:vim_dojo_state_dir),
          \ '--cmd', 'let g:vim_dojo_demo_delay = 30',
          \ '-S', s:root . '/dojo.vim'], {'hidden': 1, 'term_rows': 30, 'term_cols': 80})
    call s:Typed('', 'Start today')
    call s:Typed(":DojoFocus quote\r", 'Watch')
    call s:Typed('', 'Change the first item')
    call assert_notmatch('Watch', s:Typed('', '\\h Hint'))
    call s:Typed('x', 'differs')
    call assert_notmatch('differs', s:Typed('\r', 'Item("widget"'))
    call s:Typed("ci\"ratchet\<Esc>", 'Solved in 11 keys')
    call s:Typed("\r", '2/3')
    call s:Typed(":DojoFocus jumplist\r", 'loadItems')
    call s:Typed('', '\\h Hint')
    call s:Typed("?^func loadItems\r", 'Found the definition')
    call s:Typed("\<C-O>", 'Solved')
    " Insert mode at the end of a demo is left, and a typed . there is text.
    call s:Typed(":DojoFocus dot\r", 'Watch')
    call term_sendkeys(s:term, 'i')
    call assert_notmatch('-- INSERT --', s:Typed('', '\\h Hint'))
    call s:Typed("ciwq.\<BS>ueued\<Esc>jciwqueued\<Esc>jciwqueued\<Esc>", 'This drill practises')
    call term_sendkeys(s:term, ":qa!\r")
    call term_wait(s:term, 100)
    execute 'bwipeout!' s:term
  endif
catch
  call add(v:errors, v:exception . ' at ' . v:throwpoint)
finally
  call delete(s:state, 'rf')
endtry

if !empty(v:errors)
  for s:error in v:errors
    echomsg s:error
  endfor
  cquit
endif
qa!
