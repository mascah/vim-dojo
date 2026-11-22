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

try
  execute 'source ' . fnameescape(s:root . '/dojo.vim')
  call assert_equal('nofile', &l:buftype)
  call assert_match('1/3', s:Panel())
  call assert_match('ratchet', s:Panel())
  call assert_equal('w', strpart(getline('.'), col('.') - 1, 1))

  execute "normal! ciwratchet\<Esc>"
  call setline(line('.') + 1, 'Collateral edit')
  call feedkeys("\<F5>", 'xt')
  call assert_match('Collateral edit', s:Panel())
  DojoReset
  call assert_match('widget', getline('.'))
  silent! undo
  call assert_match('widget', getline('.'))
  execute "normal! ciwratchet\<Esc>"
  DojoCheck
  call assert_match('Solved', s:Panel())
  call assert_match('ci"', s:Panel())
  tabfirst
  Dojo
  call assert_match('Solved', s:Panel())
  DojoUsed
  call assert_match('2/3', s:Panel())
  DojoHint
  DojoHint
  call assert_match('ci"', s:Panel())
  DojoReset
  execute "normal! ci\"ready to ship\<Esc>"
  DojoCheck
  call assert_match('Solved', s:Panel())
  call assert_notmatch('DojoUsed', s:Panel())
  DojoNext
  call assert_match('3/3', s:Panel())
  DojoSkip
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
  DojoCheck
  DojoUsed
  call assert_match('Practice', s:Panel())
  call assert_match('jobs as queued', s:Panel())
  execute "normal! ciwqueued\<Esc>j.j."
  DojoCheck
  call assert_match('Solved', s:Panel())
  DojoUsed
  call assert_match('Apply', s:Panel())
  execute "normal! /publish\<CR>f,dt)/publish\<CR>f,./publish\<CR>f,."
  DojoCheck
  call assert_match('Solved', s:Panel())
  DojoUsed
  call assert_match('3 of 3 solved', s:Panel())

  Dojo
  call assert_match('definition of loadItems', s:Panel())
  DojoCheck
  call assert_match('Move the cursor onto the definition', s:Panel())
  execute "normal! ?^func loadItems\<CR>"
  DojoCheck
  call assert_match('Return to the original call', s:Panel())
  DojoCheck
  call assert_notmatch('Solved', s:Panel())
  execute "normal! \<C-O>"
  DojoCheck
  call assert_match('Solved', s:Panel())
  DojoNext
  call assert_match('definition of describe', s:Panel())
  close
  Dojo
  call assert_match('definition of describe', s:Panel())
  call assert_match('print(describe', getline('.'))
  execute "normal! /^def describe\<CR>"
  DojoCheck
  execute "normal! \<C-O>"
  DojoCheck
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
  DojoCheck
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
  DojoCheck
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
  Dojo
  DojoSkip
  call assert_match('Progress could not be saved', s:Panel())
  call delete(g:vim_dojo_state_dir)
  execute "normal! ci\"ready to ship\<Esc>"
  DojoCheck
  call assert_notmatch('Progress could not be saved', s:Panel())
  call assert_equal(2, len(readdir(g:vim_dojo_state_dir)))
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
