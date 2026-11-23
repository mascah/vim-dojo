let s:cache_dir = ''
let s:pending = {}
let s:attempt = 0
let s:read_key = []
let s:read_cache = {}
" Leitner boxes 1 to 5 and the days until each is due again.
let s:intervals = [1, 3, 7, 14, 30]
let s:placed_box = 3
let s:results = ['started', 'solved', 'assisted', 'recalled', 'skipped']

function! vim_dojo#progress#Directory() abort
  let home = empty($XDG_STATE_HOME) ? expand('~/.local/state') : $XDG_STATE_HOME
  let dir = expand(get(g:, 'vim_dojo_state_dir', home . '/vim-dojo'))
  if dir !=# s:cache_dir
    let s:cache_dir = dir
    let s:pending = {}
  endif
  return dir
endfunction

" One read serves every caller until a record is written or the directory
" changes, so drawing the map does not parse a year of records six times.
function! s:Read() abort
  let dir = vim_dojo#progress#Directory()
  let key = [dir, getftime(dir)]
  if key ==# s:read_key
    return extend(copy(s:read_cache), s:pending, 'force')
  endif
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
            \ && index(s:results, get(record, 'result')) >= 0
        let history[name] = record
      endif
    catch
      " A malformed record should not prevent the next session from opening.
    endtry
  endfor
  let [s:read_key, s:read_cache] = [key, history]
  return extend(copy(history), s:pending, 'force')
endfunction

function! vim_dojo#progress#Attempt() abort
  let s:attempt += 1
  return printf('%012d-%010d-%06d.json', localtime(), getpid(), s:attempt)
endfunction

" A record holds the drill id, result and time, and from v2 the technique,
" key count, seconds, and diagnostic placement. Never the keys themselves.
function! vim_dojo#progress#Record(attempt, record) abort
  let dir = vim_dojo#progress#Directory()
  let s:read_key = []
  let s:pending[a:attempt] = extend({'time': localtime()}, a:record)
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

" Days since the epoch in local time, so "due tomorrow" follows the calendar.
function! vim_dojo#progress#Day(time) abort
  let zone = strftime('%z', a:time)
  let offset = (zone[1:2] * 3600 + zone[3:4] * 60) * (zone[0] ==# '-' ? -1 : 1)
  return (a:time + offset) / 86400
endfunction

" Box and due day per technique. Box 0 is new. A diagnostic attempt counts
" only when it placed the technique; otherwise it is as if it never happened.
function! vim_dojo#progress#State(techniques) abort
  let owner = {}
  let state = {}
  for technique in a:techniques
    let state[technique.id] = {'box': 0, 'due': 0, 'last': 0}
    for drill in technique.drills
      let owner[drill.id] = technique.id
    endfor
  endfor
  " Attempt names grow within a Vim, so they order records made in one second.
  let records = s:Read()
  let history = map(sort(keys(records)), {_, name -> records[name]})
  call sort(history, {left, right -> left.time - right.time})
  for record in history
    let id = get(record, 'technique', get(owner, record.id, ''))
    if record.result ==# 'started' || !has_key(state, id)
          \ || get(record, 'diagnostic') && !get(record, 'placed')
      continue
    endif
    let item = state[id]
    if get(record, 'placed')
      let item.box = max([item.box, s:placed_box])
    elseif record.result ==# 'recalled'
      let item.box = min([item.box + 1, len(s:intervals)])
    elseif record.result ==# 'skipped'
      let item.box = 1
    else
      let item.box = max([item.box, 1])
    endif
    let item.last = record.time
    let item.due = vim_dojo#progress#Day(record.time) + s:intervals[item.box - 1]
  endfor
  return state
endfunction

function! vim_dojo#progress#Fresh() abort
  return empty(filter(values(s:Read()), {_, record -> record.result !=# 'started'}))
endfunction

" Today's session: due techniques first, then the next new technique in
" curriculum order, in the shape review or warm-up, practice, apply.
function! vim_dojo#progress#Plan(techniques) abort
  let state = vim_dojo#progress#State(a:techniques)
  let today = vim_dojo#progress#Day(localtime())
  let due = filter(copy(a:techniques), {_, t -> state[t.id].box && state[t.id].due <= today})
  call sort(due, {left, right -> state[left.id].due - state[right.id].due})
  let new = filter(copy(a:techniques), {_, t -> !state[t.id].box})
  let met = filter(copy(a:techniques), {_, t -> state[t.id].box})
  let review = due[: 1]
  let rest = new + due[2 :] + sort(copy(met), {left, right -> state[left.id].box - state[right.id].box})
  let reviewing = map(copy(review), {_, t -> t.id})
  let focus = get(filter(rest, {_, t -> index(reviewing, t.id) < 0}), 0, a:techniques[0])
  if empty(review)
    let latest = sort(copy(met), {left, right -> state[right.id].last - state[left.id].last})
    let first = map(latest[: 0], {_, t -> [t, 'Warm-up']})
  else
    let first = map(copy(review), {_, t -> [t, 'Review']})
  endif
  let drills = []
  for [technique, phase] in first + [[focus, 'Practice'], [focus, 'Apply']]
    let exclude = map(filter(copy(drills), {_, d -> get(d, 'technique', d.id) ==# technique.id}), {_, d -> d.id})
    call add(drills, extend(copy(s:Pick(technique, exclude)), {'phase': phase}))
  endfor
  return {'drills': drills, 'review': review, 'learn': state[focus.id].box ? [] : [focus]}
endfunction

" The least recently tried drill of a technique, avoiding those excluded
" unless nothing else is left.
function! s:Pick(technique, exclude) abort
  let tried = {}
  for record in values(s:Read())
    let tried[record.id] = max([get(tried, record.id, 0), record.time])
  endfor
  let choices = filter(copy(a:technique.drills), {_, drill -> index(a:exclude, drill.id) < 0})
  let choices = empty(choices) ? copy(a:technique.drills) : choices
  return sort(choices, {left, right -> get(tried, left.id, 0) - get(tried, right.id, 0)})[0]
endfunction

function! vim_dojo#progress#Focus(technique) abort
  let drills = []
  for index in range(3)
    let exclude = map(copy(drills), {_, drill -> drill.id})
    call add(drills, extend(copy(s:Pick(a:technique, exclude)), {'phase': 'Focus · ' . a:technique.keys}))
  endfor
  return drills
endfunction

" About ten built-in techniques, taken in turn from each skill.
function! vim_dojo#progress#Diagnostic(techniques) abort
  let by_skill = {}
  let order = []
  for technique in filter(copy(a:techniques), {_, t -> !get(t, 'custom')})
    if !has_key(by_skill, technique.skill)
      let by_skill[technique.skill] = []
      call add(order, technique.skill)
    endif
    call add(by_skill[technique.skill], technique)
  endfor
  let picked = []
  let round = 0
  while len(picked) < 10 && round < 10
    for skill in order
      if len(picked) < 10 && round < len(by_skill[skill])
        call add(picked, by_skill[skill][round])
      endif
    endfor
    let round += 1
  endwhile
  return map(picked, {_, t -> extend(copy(s:Pick(t, [])), {'phase': 'Diagnostic'})})
endfunction

" Friction inbox: one file per note under inbox/ in the state directory.
function! vim_dojo#progress#Note(lines, ft, note) abort
  let dir = vim_dojo#progress#Directory() . '/inbox'
  let path = dir . '/' . vim_dojo#progress#Attempt()
  let entry = {'time': localtime(), 'ft': a:ft, 'note': a:note, 'lines': a:lines}
  return s:Write(path, entry) ? path : ''
endfunction

function! vim_dojo#progress#Inbox() abort
  let dir = vim_dojo#progress#Directory() . '/inbox'
  try
    return [dir, isdirectory(dir) ? len(readdir(dir, {name -> name =~# '\.json$'})) : 0]
  catch
    return [dir, 0]
  endtry
endfunction
