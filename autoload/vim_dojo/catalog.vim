function! s:Motion(id, lines, expected, goal, hint, keys, why) abort
  return {'id': a:id, 'lines': a:lines, 'expected': a:expected, 'goal': a:goal,
        \ 'hint': a:hint, 'keys': a:keys, 'why': a:why, 'position': [1, 1],
        \ 'skill': 'motions', 'ft': 'text'}
endfunction

function! s:Builtins() abort
  return [
        \ s:Motion('delete-word', ['draft release notes'], ['release notes'],
        \ 'Remove the word draft and its following space.', 'Combine delete with a word motion.',
        \ 'dw', 'w takes the operator to the start of the next word.'),
        \ s:Motion('append-unit', ['timeout = 30'], ['timeout = 30s'],
        \ 'Append the unit s to the timeout.', 'Enter Insert mode at the end of the line.',
        \ 'As<Esc>', 'A appends from anywhere on the line.'),
        \ s:Motion('join-title', ['Practice', 'log'], ['Practice log'],
        \ 'Join the two lines with one space.', 'Use the Normal mode join command.',
        \ 'J', 'J joins the following line and handles the space.')
        \ ] + vim_dojo#drills#All()
endfunction

function! s:Catalog() abort
  let tasks = s:Builtins()
  let dir = expand(get(g:, 'vim_dojo_drill_dir', '~/.vim/vim-dojo/drills'))
  if !isdirectory(dir)
    return tasks
  endif
  let ids = map(copy(tasks), {_, task -> task.id})
  for name in readdir(dir, {name -> name =~# '\.json$'})
    try
      let task = json_decode(join(readfile(dir . '/' . name), "\n"))
      for field in ['id', 'goal', 'hint', 'keys', 'why']
        if type(get(task, field)) != v:t_string || empty(task[field]) || task[field] =~# '[[:cntrl:]]'
          throw 'Invalid ' . field
        endif
      endfor
      if task.id !~# '^[a-z0-9-]\+$' || index(ids, task.id) >= 0
        throw 'Invalid or duplicate id'
      endif
      for field in ['lines', 'expected']
        if type(get(task, field)) != v:t_list || empty(task[field])
              \ || !empty(filter(copy(task[field]), {_, line -> type(line) != v:t_string || line =~# '[\r\n]'}))
          throw 'Invalid ' . field
        endif
      endfor
      if task.lines ==# task.expected
        throw 'Expected buffer must differ'
      endif
      let clean = {'position': [1, 1], 'ft': 'text', 'skill': 'custom'}
      for field in ['id', 'goal', 'hint', 'keys', 'why', 'lines', 'expected']
        let clean[field] = task[field]
      endfor
      call add(tasks, clean)
      call add(ids, clean.id)
    catch
      echomsg 'Vim Dojo skipped ' . name . ' (' . v:exception . ')'
    endtry
  endfor
  return tasks
endfunction

function! s:Practice(task) abort
  call vim_dojo#Start([extend(copy(a:task), {'phase': 'Free practice · ' . a:task.id})])
endfunction

function! vim_dojo#catalog#Random() abort
  let tasks = s:Catalog()
  call s:Practice(tasks[rand() % len(tasks)])
endfunction

function! vim_dojo#catalog#Lessons() abort
  let stats = vim_dojo#progress#Stats()
  let path = filter(s:Builtins(), {_, task -> !get(get(stats, task.id, {}), 'done', 0)})
  if empty(path)
    echo 'All lessons complete! Use :DojoCatalog to revisit any drill.'
    return
  endif
  call vim_dojo#Start(map(path, {_, task -> extend(task, {'phase': 'Lesson · ' . task.skill})}))
endfunction

function! vim_dojo#catalog#Open() abort
  if exists('b:dojo_tasks')
    return
  endif
  let stats = vim_dojo#progress#Stats()
  tabnew
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted nowrap cursorline
  let b:dojo_tasks = s:Catalog()
  let rows = []
  for task in b:dojo_tasks
    let item = get(stats, task.id, {'attempts': 0, 'done': 0})
    let status = item.done ? 'done' : item.attempts ? 'tried' : 'new'
    call add(rows, printf('%-7s %3d  %-8s %s', status, item.attempts, task.skill, task.goal))
  endfor
  call setline(1, rows)
  setlocal nomodifiable nomodified
  nnoremap <buffer> <silent> <CR> <Cmd>call <SID>Select()<CR>
  nnoremap <buffer> <silent> q <Cmd>tabclose<CR>
  echo 'Attempts by drill · Enter to practice · q to return'
endfunction

function! s:Select() abort
  let task = b:dojo_tasks[line('.') - 1]
  tabclose
  call s:Practice(task)
endfunction
