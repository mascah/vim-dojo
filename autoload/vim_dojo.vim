let s:session = {}
let s:takeaways = {
      \ 'objects': 'When replacing a quoted value today, try ci".',
      \ 'repeat': 'Make one complete edit today, then repeat it at the next spot with .',
      \ 'jumps': 'After jumping to a definition or search match, try Ctrl-O to get back.',
      \ }

function! vim_dojo#Start(...) abort
  let has_edit = s:WindowExists('edit')
  let has_panel = s:WindowExists('panel')
  if !has_edit && !has_panel
    let s:session = {}
    tabnew
    call s:EditWindow()
  elseif !has_edit
    call win_gotoid(s:session.panel)
    belowright new
    call s:EditWindow()
  endif
  call win_gotoid(s:session.edit)
  if !has_panel
    topleft 8new
    call s:Scratch()
    setlocal nonumber norelativenumber signcolumn=no foldcolumn=0
    setlocal wrap linebreak nolist nospell winfixheight nomodifiable
    let s:session.panel = win_getid()
    let s:session.panel_buf = bufnr('%')
    call win_gotoid(s:session.edit)
  endif

  if a:0 || !has_key(s:session, 'plan') || s:session.done
    let s:session.plan = a:0 ? a:1 : vim_dojo#progress#Plan(vim_dojo#drills#All())
    let s:session.index = 0
    let s:session.results = []
    let s:session.warning = ''
    let s:session.done = 0
    call s:OpenTask()
  elseif !has_edit && empty(s:session.result)
    call s:Reset()
  else
    call s:Render()
  endif
endfunction

function! s:WindowExists(kind) abort
  let win = get(s:session, a:kind, 0)
  return win > 0 && win_id2tabwin(win)[0] > 0
        \ && winbufnr(win) == get(s:session, a:kind . '_buf', -1)
endfunction

function! s:Scratch() abort
  setlocal buftype=nofile bufhidden=wipe noswapfile noundofile nobuflisted
  command! -buffer DojoCheck call vim_dojo#Action('check')
  command! -buffer DojoHint call vim_dojo#Action('hint')
  command! -buffer DojoReset call vim_dojo#Action('reset')
  command! -buffer DojoSkip call vim_dojo#Action('skip')
  command! -buffer DojoNext call vim_dojo#Action('next')
  command! -buffer DojoUsed call vim_dojo#Action('used')
  command! -buffer DojoClose call vim_dojo#Action('close')
  nnoremap <buffer> <silent> <F5> <Cmd>DojoCheck<CR>
  nnoremap <buffer> <silent> <F6> <Cmd>DojoHint<CR>
  nnoremap <buffer> <silent> <F7> <Cmd>DojoReset<CR>
  nnoremap <buffer> <silent> <F8> <Cmd>DojoSkip<CR>
  nnoremap <buffer> <silent> <F9> <Cmd>DojoUsed<CR>
endfunction

function! s:EditWindow() abort
  call s:Scratch()
  setlocal nofoldenable
  let s:session.edit = win_getid()
  let s:session.edit_buf = bufnr('%')
endfunction

function! s:OpenTask() abort
  let s:session.task = s:session.plan[s:session.index]
  let s:session.attempt = vim_dojo#progress#Attempt()
  let saved = vim_dojo#progress#Record(s:session.attempt, s:session.task.id, 'started')
  if !saved
    let s:session.warning = 'Progress could not be saved to disk.'
  endif
  let s:session.assisted = 0
  let s:session.result = ''
  call s:Reset()
endfunction

function! s:Reset() abort
  let task = s:session.task
  if &l:filetype !=# task.ft
    let &l:filetype = task.ft
  endif
  setlocal modifiable
  let undolevels = &l:undolevels
  setlocal undolevels=-1
  try
    call setline(1, task.lines)
    call deletebufline(bufnr('%'), len(task.lines) + 1, '$')
  finally
    let &l:undolevels = undolevels
  endtry
  setlocal nomodified nofoldenable
  clearjumps
  call cursor(task.position[0], task.position[1])
  normal! zz
  let s:session.step = 0
  let s:session.hint = 0
  let s:session.feedback = []
  call s:Render()
endfunction

function! vim_dojo#Action(action) abort
  if empty(s:session) || index([s:session.edit_buf, s:session.panel_buf], bufnr('%')) < 0
    return
  endif
  if a:action ==# 'close'
    tabclose
    return
  endif
  if !s:WindowExists('edit') || !s:WindowExists('panel')
    call vim_dojo#Start()
    return
  endif
  if s:session.done
    if a:action ==# 'check' || a:action ==# 'next'
      call vim_dojo#Start()
    endif
    return
  endif
  call win_gotoid(s:session.edit)
  if a:action ==# 'check' && empty(s:session.result)
    call s:Check()
  elseif a:action ==# 'hint' && empty(s:session.result)
    call s:Hint()
  elseif a:action ==# 'reset' && empty(s:session.result)
    call s:Reset()
  elseif a:action ==# 'used' && s:session.result ==# 'solved'
    call s:Record('recalled')
    call s:Advance()
  elseif a:action ==# 'skip' || !empty(s:session.result) && index(['next', 'check'], a:action) >= 0
    if empty(s:session.result)
      call s:Record('skipped')
    endif
    call s:Advance()
  endif
endfunction

function! s:Check() abort
  let task = s:session.task
  let actual = getline(1, '$')
  if actual !=# task.expected
    let s:session.feedback = ['The buffer still differs from the target.']
          \ + s:Diff(actual, task.expected)
  elseif has_key(task, 'destination') && s:session.step == 0
    if line('.') == task.destination
      let s:session.step = 1
      let s:session.hint = 0
      let s:session.feedback = ['Found the definition.']
    else
      let s:session.feedback = ['Move the cursor onto the definition, then check.']
    endif
  elseif has_key(task, 'destination') && line('.') != task.position[0]
    let s:session.feedback = ['Return to the original call, then check.']
  else
    call s:Record(s:session.assisted ? 'assisted' : 'solved')
    let s:session.feedback = ['Solved. ' . task.why, task.keys]
    setlocal nomodifiable
  endif
  call s:Render()
endfunction

function! s:Diff(actual, expected) abort
  if exists('*diff')
    let delta = diff(a:actual, a:expected)
    if type(delta) == v:t_string && !empty(delta)
      let lines = split(delta, "\n")
      return len(lines) > 5 ? lines[:3] + ['…'] : lines
    endif
  endif
  let index = 0
  while index < min([len(a:actual), len(a:expected)]) && a:actual[index] ==# a:expected[index]
    let index += 1
  endwhile
  return ['Line ' . (index + 1), '- ' . get(a:actual, index, '(end of buffer)'),
        \ '+ ' . get(a:expected, index, '(end of buffer)')]
endfunction

function! s:Hint() abort
  let task = s:session.task
  let s:session.assisted = 1
  let s:session.hint += 1
  if s:session.step > 0
    let hint = s:session.hint == 1 ? 'Vim keeps a list of the places you jump from.' : 'Press Ctrl-O.'
  else
    let hint = s:session.hint == 1 ? task.hint : task.keys
  endif
  let s:session.feedback = ['Hint  ' . hint]
  call s:Render()
endfunction

function! s:Record(result) abort
  let s:session.result = a:result
  let saved = vim_dojo#progress#Record(s:session.attempt, s:session.task.id, a:result)
  let s:session.warning = saved ? '' : 'Progress could not be saved to disk.'
endfunction

function! s:Advance() abort
  call add(s:session.results, s:session.result)
  let s:session.index += 1
  if s:session.index < len(s:session.plan)
    call s:OpenTask()
  else
    let s:session.done = 1
    setlocal nomodifiable
    call s:Render()
  endif
endfunction

function! s:Render() abort
  let total = len(s:session.plan)
  if s:session.done
    let solved = total - count(s:session.results, 'skipped')
    let recalled = count(s:session.results, 'recalled')
    let lines = ['Vim Dojo  ·  Session complete', '',
          \ printf('%d of %d solved  ·  %d independently recalled', solved, total, recalled),
          \ '', get(s:takeaways, s:session.task.skill, s:session.task.why), '',
          \ 'F5 / :Dojo  New session     :DojoClose  Return to your work']
  else
    let task = s:session.task
    let goal = s:session.step > 0 ? 'Return to the original call.' : task.goal
    let lines = [printf('Vim Dojo  ·  %d/%d  ·  %s', s:session.index + 1, total, task.phase),
          \ '', goal, ''] + s:session.feedback
    if empty(s:session.result)
      call add(lines, 'F5 Check   F6 Hint   F7 Reset   F8 Skip   :DojoClose')
    else
      call add(lines, 'F5 / :DojoNext  Continue')
      if s:session.result ==# 'solved'
        call add(lines, 'F9 / :DojoUsed  I used that technique on my own')
      endif
    endif
  endif
  if !empty(s:session.warning)
    call add(lines, s:session.warning)
  endif
  let buf = s:session.panel_buf
  call setbufvar(buf, '&modifiable', 1)
  call setbufline(buf, 1, lines)
  call deletebufline(buf, len(lines) + 1, '$')
  call setbufvar(buf, '&modified', 0)
  call setbufvar(buf, '&modifiable', 0)
  let height = min([len(lines) + 1, max([3, &lines / 2])])
  call win_execute(s:session.panel, 'resize ' . height . ' | normal! gg0')
endfunction
