let s:map_buf = -1
let s:symbols = ['○', '◐', '●']
let s:words = ['new', 'shaky', 'solid']

function! vim_dojo#map#Open() abort
  let windows = bufexists(s:map_buf) ? win_findbuf(s:map_buf) : []
  if !empty(windows)
    call win_gotoid(windows[0])
  else
    tabnew
    setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted nowrap cursorline nomodifiable
    let s:map_buf = bufnr('%')
    let b:dojo_open = {}
    syntax match DojoSolid /●/
    syntax match DojoShaky /◐/
    syntax match DojoNew /○/
    syntax match DojoSession /▶.*session/
    highlight default link DojoSolid String
    highlight default link DojoShaky WarningMsg
    highlight default link DojoNew Comment
    highlight default link DojoSession Title
    nnoremap <buffer> <silent> <CR> <Cmd>call <SID>Enter()<CR>
    nnoremap <buffer> <silent> d <Cmd>call <SID>Leave()<Bar>call vim_dojo#Diagnostic()<CR>
    nnoremap <buffer> <silent> q <Cmd>call <SID>Leave()<CR>
  endif
  call s:Draw(1)
  call cursor(index(map(copy(b:dojo_rows), {_, row -> has_key(row, 'session')}), 1) + 1, 3)
endfunction

" Pads by display width, which printf does not do for … and the like.
function! s:Pad(text, width) abort
  return a:text . repeat(' ', a:width - strdisplaywidth(a:text))
endfunction

function! s:Level(item) abort
  return !a:item.box ? 0 : a:item.box < 3 ? 1 : 2
endfunction

function! s:Due(item, today) abort
  let days = a:item.due - a:today
  return !a:item.box ? '' : days <= 0 ? 'due today' : days == 1 ? 'due tomorrow' : printf('due in %d days', days)
endfunction

function! s:Draw(initial) abort
  let techniques = vim_dojo#drills#Techniques()
  let state = vim_dojo#progress#State(techniques)
  let b:dojo_plan = vim_dojo#progress#Plan(techniques)
  let today = vim_dojo#progress#Day(localtime())
  let [inbox_dir, inbox] = vim_dojo#progress#Inbox()
  let due = len(filter(copy(techniques), {_, t -> state[t.id].box && state[t.id].due <= today}))
  let planned = map(b:dojo_plan.review + b:dojo_plan.learn, {_, t -> t.id})
  let by_skill = {}
  for technique in techniques
    let by_skill[technique.skill] = add(get(by_skill, technique.skill, []), technique)
    if a:initial && (s:Level(state[technique.id]) == 1 || state[technique.id].box && state[technique.id].due <= today
          \ || index(planned, technique.id) >= 0)
      let b:dojo_open[technique.skill] = 1
    endif
  endfor

  let right = printf('%d due today · %d in inbox', due, inbox)
  let rows = [['Vim Dojo' . repeat(' ', 78 - 8 - strdisplaywidth(right)) . right, {}], ['', {}]]
  if inbox
    call add(rows, ['  Inbox notes are in ' . fnamemodify(inbox_dir, ':~'), {}])
  endif
  if vim_dojo#progress#Fresh()
    call add(rows, ['  New here? Press d for a short diagnostic, or Enter to start at the beginning.', {}])
  endif
  let parts = []
  for [kind, members] in [['review', b:dojo_plan.review], ['learn', b:dojo_plan.learn]]
    if !empty(members)
      call add(parts, kind . ' ' . join(map(copy(members), {_, t -> t.keys}), ' / '))
    endif
  endfor
  call add(rows, [strcharpart(printf('  ▶ %-29s%s', 'Start today''s session', join(parts, '  ·  ')), 0, 80),
        \ {'session': 1}])
  call add(rows, ['', {}])

  for [skill, name] in vim_dojo#drills#Skills()
    let members = get(by_skill, skill, [])
    if empty(members)
      continue
    endif
    let levels = map(copy(members), {_, t -> s:Level(state[t.id])})
    let bar = join(map(levels[: 23], {_, level -> s:symbols[level]}), '')
    let solid = count(levels, 2)
    call add(rows, [printf('%-22s', name) . bar . repeat(' ', max([4, 11 - len(levels)]))
          \ . printf('%d of %d solid', solid, len(members)), {'skill': skill}])
    if get(b:dojo_open, skill)
      for technique in members
        let item = state[technique.id]
        let level = s:Level(item)
        let line = '  ' . s:symbols[level] . ' ' . s:Pad(strcharpart(technique.keys, 0, 19), 20)
              \ . s:Pad(s:words[level], 10) . s:Due(item, today)
        call add(rows, [substitute(line, '\s\+$', '', ''), {'technique': technique.id}])
      endfor
    endif
  endfor
  call add(rows, ['', {}])
  call add(rows, ['  ○ new   ◐ shaky   ● solid       Enter practise · d diagnostic · q close', {}])

  let b:dojo_rows = map(copy(rows), {_, row -> row[1]})
  setlocal modifiable
  call setline(1, map(copy(rows), {_, row -> row[0]}))
  call deletebufline('%', len(rows) + 1, '$')
  setlocal nomodifiable nomodified
endfunction

function! s:Enter() abort
  let row = get(b:dojo_rows, line('.') - 1, {})
  if has_key(row, 'session')
    let rounds = b:dojo_plan.rounds
    call s:Leave()
    call vim_dojo#Start(rounds)
  elseif has_key(row, 'skill')
    let b:dojo_open[row.skill] = !get(b:dojo_open, row.skill)
    call s:Draw(0)
    call cursor(index(b:dojo_rows, row) + 1, 1)
  elseif has_key(row, 'technique')
    call s:Leave()
    call vim_dojo#Focus(row.technique)
  endif
endfunction

function! s:Leave() abort
  if tabpagenr('$') > 1
    tabclose
  else
    enew
  endif
endfunction
