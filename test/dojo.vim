" Run from the repository root with vim -Nu NONE -i NONE -n -es -S test/dojo.vim
let s:state = tempname()
let g:vim_dojo_state_dir = s:state . '/initial'
let g:vim_dojo_drill_dir = s:state . '/custom'
call setline(1, 'An unsaved edit in the original window')
let s:original = bufnr('%')
let s:root = fnamemodify(expand('<sfile>:p'), ':h:h')

function! s:Panel() abort
  return join(getbufline(winbufnr(1), 1, '$'), "\n")
endfunction

" Types into a real Vim and waits for its screen to show the pattern.
function! s:Typed(keys, pattern) abort
  call term_sendkeys(s:term, a:keys)
  for attempt in range(100)
    call term_wait(s:term, 50)
    let screen = join(map(range(1, 24), 'term_getline(s:term, v:val)'), "\n")
    if screen =~# a:pattern
      break
    endif
  endfor
  call assert_match(a:pattern, screen)
  return screen
endfunction

try
  execute 'source ' . fnameescape(s:root . '/dojo.vim')
  call assert_equal('nofile', &l:buftype)
  call assert_match('1/3', s:Panel())
  call assert_match('ratchet', s:Panel())
  call assert_equal('w', strpart(getline('.'), col('.') - 1, 1))

  " no-f-keys, and Enter is left alone until there is something to continue.
  call assert_equal(repeat([''], 6), map(['<F5>', '<F6>', '<F7>', '<F8>', '<F9>', '<CR>'], 'maparg(v:val, "n")'))
  call assert_notmatch('F\d', s:Panel())
  " highlight
  call assert_equal(['DojoTarget'], map(getmatches(), 'v:val.group'))
  call assert_equal(['"widget"'], map(getmatches(), 'matchstr(getline("."), v:val.pattern)'))

  " auto-check. Leaving Insert mode is the one check event a headless Vim
  " raises by itself; TextChanged and CursorMoved are raised by hand below and
  " for real in the terminal block.
  call setline(line('.') + 1, 'Collateral edit')
  execute "normal! ciwratchet\<Esc>"
  call assert_match('Collateral edit', s:Panel())
  call feedkeys('\r', 'xt')
  call assert_match('widget', getline('.'))
  doautocmd TextChanged
  doautocmd CursorMoved
  call assert_notmatch('differs', s:Panel())
  silent! undo
  call assert_match('widget', getline('.'))
  execute "normal! ci\"ratchet\<Esc>"
  call assert_match('Solved', s:Panel())
  call assert_match('ci"', s:Panel())
  tabfirst
  Dojo
  call assert_match('Solved', s:Panel())
  DojoUsed
  call assert_match('2/3', s:Panel())
  call feedkeys("\<CR>", 'xt')
  call assert_match('2/3', s:Panel())
  call assert_match('^}', getline('.'))
  nnoremap <buffer> <CR> <Nop>
  call feedkeys('\h\h', 'xt')
  call assert_match('ci"', s:Panel())
  call assert_equal('<Nop>', maparg('<CR>', 'n'))
  normal! k
  doautocmd CursorMoved
  call assert_match('ci"', s:Panel())
  DojoReset
  execute "normal! ci\"ready to ship\<Esc>"
  call assert_match('Solved', s:Panel())
  call assert_notmatch('DojoUsed', s:Panel())
  call feedkeys("\<CR>", 'xt')
  call assert_match('3/3', s:Panel())
  call assert_match('bulk spacer', s:Panel())
  call assert_equal([], getmatches())
  call feedkeys('\s', 'xt')
  call assert_match('2 of 3 solved', s:Panel())
  call assert_match('1 independently recalled', s:Panel())

  DojoClose
  call assert_equal(s:original, bufnr('%'))
  call assert_equal('An unsaved edit in the original window', getline(1))
  call assert_true(&modified)
  let s:results = sort(map(readdir(g:vim_dojo_state_dir),
        \ 'json_decode(readfile(g:vim_dojo_state_dir . "/" . v:val)[0]).result'))
  call assert_equal(['assisted', 'recalled', 'skipped'], s:results)

  let g:vim_dojo_state_dir = s:state . '/later'
  call mkdir(g:vim_dojo_state_dir, 'p')
  let s:old = localtime() - 4 * 86400
  for [s:index, s:id] in items(['quoted-item', 'shipping-status', 'catalog-string'])
    let s:time = s:old + s:index
    call writefile([json_encode({'id': s:id, 'result': 'recalled', 'time': s:time})],
          \ g:vim_dojo_state_dir . '/' . printf('%012d-0000000001-000001.json', s:time))
  endfor
  Dojo
  call assert_match('Review', s:Panel())
  call assert_match('API_URL', s:Panel())
  execute "normal! f\"lci\"https://api.example.test/v2\<Esc>"
  DojoUsed
  call assert_match('Practice', s:Panel())
  call assert_match('jobs as queued', s:Panel())
  execute "normal! ciwqueued\<Esc>j.j."
  call assert_match('Solved', s:Panel())
  DojoUsed
  call assert_match('Apply', s:Panel())
  call assert_equal([], getmatches())
  execute "normal! /publish\<CR>f,dt)/publish\<CR>f,./publish\<CR>f,."
  doautocmd TextChanged
  call assert_match('Solved', s:Panel())
  DojoUsed
  call assert_match('3 of 3 solved', s:Panel())

  Dojo
  call assert_match('definition of loadItems', s:Panel())
  DojoCheck
  call assert_match('Move the cursor onto the definition', s:Panel())
  execute "normal! ?^func loadItems\<CR>"
  doautocmd CursorMoved
  call assert_match('Return to the original call', s:Panel())
  doautocmd CursorMoved
  call assert_notmatch('Solved', s:Panel())
  execute "normal! \<C-O>"
  doautocmd CursorMoved
  call assert_match('Solved', s:Panel())
  DojoNext
  call assert_match('definition of describe', s:Panel())
  close
  Dojo
  call assert_match('definition of describe', s:Panel())
  call assert_match('print(describe', getline('.'))
  execute "normal! /^def describe\<CR>"
  doautocmd CursorMoved
  execute "normal! \<C-O>"
  doautocmd CursorMoved
  call assert_match('Solved', s:Panel())
  DojoClose

  " The same anchors typed into a real Vim, where the main loop raises
  " TextChanged and CursorMoved. This state directory opens on a jump drill.
  if has('terminal')
    let s:term = term_start([v:progpath, '-Nu', 'NONE', '-i', 'NONE', '-n',
          \ '--cmd', 'let g:vim_dojo_state_dir = ' . string(g:vim_dojo_state_dir),
          \ '-S', s:root . '/dojo.vim'], {'hidden': 1, 'term_rows': 24, 'term_cols': 80})
    call s:Typed('', 'definition of loadItems')
    call s:Typed('x', 'differs')
    call assert_notmatch('differs', s:Typed("\\r:echo 'was reset'\r", 'was reset'))
    call s:Typed("?^func loadItems\r", 'Found the definition')
    call s:Typed("\<C-O>", 'Solved')
    call s:Typed("\r", '2/3')
    call term_sendkeys(s:term, ":qa!\r")
    call term_wait(s:term, 100)
    execute 'bwipeout!' s:term
  endif

  let s:task = {'id': 'to-comma', 'phase': 'Test', 'skill': 'motions', 'ft': 'text',
        \ 'lines': ['alpha, beta'], 'expected': ['alpha, beta'], 'position': [1, 1], 'target': [1, 6],
        \ 'goal': 'Move to the comma.', 'hint': 'Find a character.', 'keys': 'f,', 'why': 'f lands on it.'}
  call vim_dojo#Start([s:task])
  normal! x
  doautocmd TextChanged
  normal! f,
  doautocmd CursorMoved
  call assert_match('differs', s:Panel())
  DojoReset
  normal! l
  doautocmd CursorMoved
  call assert_notmatch('Solved', s:Panel())
  normal! f,
  doautocmd CursorMoved
  call assert_match('Solved', s:Panel())
  DojoClose

  let g:vim_dojo_state_dir = s:state . '/modes'
  DojoFree
  call assert_match('1/1.*Free practice', s:Panel())
  DojoSkip
  call assert_match('0 of 1 solved', s:Panel())
  DojoClose
  DojoLessons
  call assert_match('Lesson.*motions', s:Panel())
  normal! dw
  doautocmd TextChanged
  call assert_match('Solved', s:Panel())
  DojoClose
  DojoLessons
  call assert_match('append', tolower(s:Panel()))
  DojoClose
  call mkdir(g:vim_dojo_drill_dir, 'p')
  let s:custom = {'id': 'custom-drill', 'goal': 'Replace alpha with beta',
        \ 'lines': ['alpha'], 'expected': ['beta'], 'hint': 'Change a word',
        \ 'keys': 'ciwbeta<Esc>', 'why': 'Change replaces text.'}
  call writefile([json_encode(s:custom)], g:vim_dojo_drill_dir . '/custom.json')
  call writefile(['{}'], g:vim_dojo_drill_dir . '/invalid.json')
  DojoCatalog
  call assert_equal(17, line('$'))
  normal! G
  call feedkeys("\<CR>", 'xt')
  call assert_equal('alpha', getline(1))
  call setline(1, 'beta')
  doautocmd TextChanged
  call assert_match('Solved', s:Panel())
  DojoClose
  DojoCatalog
  call assert_match('done', join(getline(1, '$')))
  normal gg
  call feedkeys("\<CR>", 'xt')
  call assert_match('Free practice', s:Panel())
  DojoClose

  let g:vim_dojo_state_dir = s:state . '/blocked'
  call writefile(['This file blocks the state directory.'], g:vim_dojo_state_dir)
  let g:vim_dojo_highlight = 0
  Dojo
  call assert_match('ratchet', s:Panel())
  call assert_equal([], getmatches())
  DojoSkip
  call assert_match('Progress could not be saved', s:Panel())
  call delete(g:vim_dojo_state_dir)
  execute "normal! ci\"ready to ship\<Esc>"
  call assert_notmatch('Progress could not be saved', s:Panel())
  call assert_equal(2, len(readdir(g:vim_dojo_state_dir)))
  DojoNext
  call assert_match('bulk spacer', s:Panel())
  call assert_equal([], getmatches())
  DojoClose
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
