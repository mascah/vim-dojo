let s:skills = ['objects', 'repeat', 'jumps']
let s:cache_dir = ''
let s:pending = {}
let s:attempt = 0

function! s:Directory() abort
  let home = empty($XDG_STATE_HOME) ? expand('~/.local/state') : $XDG_STATE_HOME
  let dir = expand(get(g:, 'vim_dojo_state_dir', home . '/vim-dojo'))
  if dir !=# s:cache_dir
    let s:cache_dir = dir
    let s:pending = {}
  endif
  return dir
endfunction

function! s:Read() abort
  let dir = s:Directory()
  let history = {}
  let names = []
  try
    if isdirectory(dir)
      let names = readdir(dir, {name -> name =~# '^\d\+-\d\+-\d\+\.json$'})
    endif
  catch
    " Continue with any progress recorded in this Vim instance.
  endtry
  for name in names
    try
      let record = json_decode(get(readfile(dir . '/' . name, '', 1), 0, ''))
      if type(record) == v:t_dict && type(get(record, 'id')) == v:t_string
            \ && type(get(record, 'time')) == v:t_number
            \ && index(['started', 'solved', 'assisted', 'recalled', 'skipped'], get(record, 'result')) >= 0
        let history[name] = record
      endif
    catch
      " A malformed record should not prevent the next session from opening.
    endtry
  endfor
  return extend(history, s:pending, 'force')
endfunction

function! vim_dojo#progress#Attempt() abort
  let s:attempt += 1
  return printf('%012d-%010d-%06d.json', localtime(), getpid(), s:attempt)
endfunction

function! vim_dojo#progress#Record(attempt, id, result) abort
  let dir = s:Directory()
  let s:pending[a:attempt] = {'id': a:id, 'result': a:result, 'time': localtime()}
  for [attempt, record] in items(s:pending)
    if s:Write(dir . '/' . attempt, record)
      call remove(s:pending, attempt)
    endif
  endfor
  return empty(s:pending)
endfunction

function! s:Write(path, record) abort
  let staging = a:path . '.tmp'
  try
    call mkdir(fnamemodify(a:path, ':h'), 'p', 0700)
    return writefile([json_encode(a:record)], staging) == 0 && rename(staging, a:path) == 0
  catch
    return 0
  finally
    call delete(staging)
  endtry
endfunction

function! s:Due(record) abort
  return a:record.time + (a:record.result ==# 'recalled' ? 3 : 1) * 86400
endfunction

function! vim_dojo#progress#Plan(drills) abort
  let history = s:Read()
  let by_id = {}
  for task in a:drills
    let by_id[task.id] = task
  endfor
  let seen = {}
  let latest = {}
  let attempts = sort(keys(history))
  call sort(attempts, {left, right -> history[left].time - history[right].time})
  for index in range(len(attempts))
    let record = history[attempts[index]]
    if record.result !=# 'started' && has_key(by_id, record.id)
      let seen[record.id] = index
      let latest[by_id[record.id].skill] = record
    endif
  endfor

  let known = filter(copy(s:skills), {_, skill -> has_key(latest, skill)})
  call sort(known, {left, right -> s:Due(latest[left]) - s:Due(latest[right])})
  let new = filter(copy(s:skills), {_, skill -> !has_key(latest, skill)})
  let focus = get(new, 0, get(known, 0, 'objects'))
  let review = !empty(known) && s:Due(latest[known[0]]) <= localtime()
  let first = s:Pick(a:drills, seen, review ? known[0] : focus, review ? -1 : 0, [])
  let second = s:Pick(a:drills, seen, focus, 0, [first.id])
  let third = s:Pick(a:drills, seen, focus, 1, [first.id, second.id])
  return [extend(copy(first), {'phase': review ? 'Review' : 'Warm-up'}),
        \ extend(copy(second), {'phase': 'Practice'}),
        \ extend(copy(third), {'phase': 'Apply'})]
endfunction

function! s:Pick(drills, seen, skill, application, exclude) abort
  let pick = {}
  let oldest = -1
  for task in a:drills
    if task.skill !=# a:skill || index(a:exclude, task.id) >= 0
          \ || (a:application >= 0 && task.application != a:application)
      continue
    endif
    let tried = get(a:seen, task.id, -1)
    if empty(pick) || tried < oldest
      let pick = task
      let oldest = tried
    endif
  endfor
  return pick
endfunction

function! vim_dojo#progress#Stats() abort
  let stats = {}
  for record in values(s:Read())
    let item = get(stats, record.id, {'attempts': 0, 'done': 0})
    let item.attempts += 1
    let item.done = item.done || index(['solved', 'assisted', 'recalled'], record.result) >= 0
    let stats[record.id] = item
  endfor
  return stats
endfunction
