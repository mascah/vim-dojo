let s:cache_dir = ''
let s:pending = {}
let s:attempt = 0
let s:read_key = []
let s:read_cache = {}
" Leitner boxes 1 to 5 and the days until each is due again.
let s:intervals = [1, 3, 7, 14, 30]
let s:placed_box = 3
let s:round_length = 10
let s:section_length = 20
" v2 wrote solved, assisted, and recalled; they still mark a drill as tried.
let s:results = ['started', 'clean', 'unclean', 'skipped', 'round', 'placed', 'solved', 'assisted', 'recalled']

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

" A goal record holds the drill id, technique, result, key count, and
" seconds; a round record the technique, kind, clean count, goals, whether
" it passed, and seconds. Never the keys themselves.
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

" Box, due day, and rounds taken per technique. Box 0 is new. Only round
" records and section placements move a box, so v2's per-drill records,
" graded by a broken key count, count for nothing. A passed round puts a new
" technique in the first box and moves a known one up; a round that is not
" passed leaves a new technique new and sends a known one back to the first.
function! vim_dojo#progress#State(techniques) abort
  let state = {}
  for technique in a:techniques
    let state[technique.id] = {'box': 0, 'due': 0, 'last': 0, 'rounds': 0}
  endfor
  " Attempt names grow within a Vim, so they order records made in one second.
  let records = s:Read()
  let history = map(sort(keys(records)), {_, name -> records[name]})
  call sort(history, {left, right -> left.time - right.time})
  for record in history
    let item = get(state, get(record, 'technique', ''), {})
    if empty(item) || index(['round', 'placed'], record.result) < 0
      continue
    endif
    if record.result ==# 'placed'
      let item.box = max([item.box, s:placed_box])
    else
      let item.rounds += 1
      let item.box = !get(record, 'passed') ? (item.box ? 1 : 0) : min([item.box + 1, len(s:intervals)])
    endif
    if item.box
      let item.last = record.time
      let item.due = vim_dojo#progress#Day(record.time) + s:intervals[item.box - 1]
    endif
  endfor
  return state
endfunction

function! vim_dojo#progress#Fresh() abort
  return empty(filter(values(s:Read()), {_, record -> index(['round', 'placed'], record.result) >= 0}))
endfunction

" Today's session: a review round for each of up to three due techniques,
" oldest first, then a learn round on the next new one. With nothing due and
" nothing new, it reviews whatever is due soonest.
function! vim_dojo#progress#Plan(techniques) abort
  let state = vim_dojo#progress#State(a:techniques)
  let today = vim_dojo#progress#Day(localtime())
  let known = sort(filter(copy(a:techniques), {_, t -> state[t.id].box}),
        \ {left, right -> state[left.id].due - state[right.id].due})
  let review = filter(copy(known), {_, t -> state[t.id].due <= today})[: 2]
  let learn = filter(copy(a:techniques), {_, t -> !state[t.id].box})[: 0]
  if empty(review) && empty(learn)
    let review = known[: 0]
  endif
  let rounds = map(copy(review), {_, t -> vim_dojo#progress#Round(t, 'review')})
        \ + map(copy(learn), {_, t -> vim_dojo#progress#Round(t, 'learn')})
  return {'rounds': rounds, 'review': review, 'learn': learn}
endfunction

" A technique's drills, least recently tried first, and among those never
" tried, the learner's own first: a custom drill counts a second older.
function! s:Order(technique) abort
  let tried = {}
  for record in values(s:Read())
    let tried[record.id] = max([get(tried, record.id, 0), record.time])
  endfor
  return sort(copy(a:technique.drills), {left, right -> get(tried, left.id, 0) - get(left, 'custom', 0)
        \ - get(tried, right.id, 0) + get(right, 'custom', 0)})
endfunction

" Ten goals on one technique. With generators, the runner draws them as the
" round opens, and up to three of its scenarios and custom drills follow,
" after the generated run so a cursor lesson's hops are not broken.
" Otherwise it cycles through its drills. A template draws fresh values each
" time it comes round.
function! vim_dojo#progress#Round(technique, kind) abort
  let order = s:Order(a:technique)
  if has_key(a:technique, 'generators')
    return {'kind': a:kind, 'technique': a:technique.id,
          \ 'goals': repeat([{'generated': 1, 'lesson': a:technique.id}], s:round_length - len(order[: 2]))
          \   + order[: 2]}
  endif
  return {'kind': a:kind, 'technique': a:technique.id,
        \ 'goals': map(range(s:round_length), {index, _ -> order[index % len(order)]})}
endfunction

" A learn round for a new technique, a review round for a known one.
function! vim_dojo#progress#Focus(technique) abort
  let known = vim_dojo#progress#State([a:technique])[a:technique.id].box
  return vim_dojo#progress#Round(a:technique, known ? 'review' : 'learn')
endfunction

" A section's review: twenty goals drawn evenly from its lessons, shuffled.
function! vim_dojo#progress#Section(section, techniques) abort
  let lessons = filter(copy(a:techniques), {_, t -> t.skill ==# a:section})
  let goals = []
  for index in range(len(lessons))
    let share = s:section_length / len(lessons) + (index < s:section_length % len(lessons))
    call extend(goals, s:Shuffle(vim_dojo#progress#Round(lessons[index], 'section').goals)[: share - 1])
  endfor
  let name = get(filter(vim_dojo#drills#Skills(), {_, s -> s[0] ==# a:section}), 0, ['', a:section])[1]
  return {'kind': 'section', 'technique': '', 'section': a:section, 'name': name, 'goals': s:Shuffle(goals)}
endfunction

function! s:Shuffle(list) abort
  for index in range(len(a:list) - 1, 1, -1)
    let other = rand() % (index + 1)
    let [a:list[index], a:list[other]] = [a:list[other], a:list[index]]
  endfor
  return a:list
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
