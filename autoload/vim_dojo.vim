let s:session = {}
let s:modes = ['n']
let s:last_key = reltime()
let s:pseudo_keys = ['<CursorHold>', '<Ignore>', '<FocusGained>', '<FocusLost>', '<MouseMove>']
" Registers a solution or demo may touch, restored afterwards. The unnamed
" register goes last so it points where it pointed before.
let s:history_saved = 0
let s:registers = split('0123456789abcdefghijklmnopqrstuvwxyz-/', '\zs') + ['"']

" A goal is clean when it is solved without a hint in at most par plus this
" many keys, and a round is passed with this many clean goals in ten.
let s:margin = 2
let s:pass = 8
" Ctrl-D and Ctrl-U move by 'scroll', which Vim resets to half the window
" whenever it resizes, as the panel does. Set again before each key the
" learner types, and before playing a solution, a scroll goal's target does
" not depend on the window's size.
let s:scroll = 8

" Runs the round the shell wrote to `path`, in the state directory, and
" quits Vim when it is done. The request names its goals by lesson, as
" generated or as a drill id; `drills` is the custom drill directory, so
" both sides read the same one. A drill that no longer loads is left out.
function! vim_dojo#Run(path) abort
  if !has('patch-9.1.0597')
    " KeyInputPre arrived in 9.1.0563 and its typedchar, which the key count
    " relies on, in 9.1.0597.
    echohl ErrorMsg | echo 'Vim Dojo needs Vim 9.1.0597 or later.' | echohl None
    return
  endif
  let round = json_decode(join(readfile(a:path), "\n"))
  let g:vim_dojo_state_dir = fnamemodify(a:path, ':p:h')
  let g:vim_dojo_drill_dir = round.drills
  let s:run = 1
  let drills = {}
  for lesson in vim_dojo#drills#Lessons()
    for drill in lesson.drills
      let drills[lesson.id . ' ' . drill.id] = drill
    endfor
  endfor
  call map(round.goals, {_, goal -> get(goal, 'generated') ? {'generated': 1, 'lesson': goal.lesson}
        \ : get(drills, goal.lesson . ' ' . goal.drill, {})})
  call filter(round.goals, '!empty(v:val)')
  if empty(round.goals)
    echohl ErrorMsg | echo 'Vim Dojo: none of this round''s drills load; see :messages.' | echohl None
    return
  endif
  call vim_dojo#Start(round)
  " The empty tab Vim started with would be left behind on :q.
  silent! tabonly
endfunction

" Runs a round: {'kind', 'lesson', 'goals'}, where kind is learn,
" review, section, mixed, or free, and goals is a list of drills. `demo` asks
" for the first goal to be demonstrated. A section round also names its
" `section`, the section's `name`, and in `place` the lessons a pass places.
" A `limit` in seconds ends the round there, if its goals last that long.
" A `count` larger than the goals repeats them up to that many.
function! vim_dojo#Start(round) abort
  call s:StopDemo()
  let lessons = {}
  for lesson in vim_dojo#drills#Lessons()
    let lessons[lesson.id] = lesson
  endfor
  call s:Open()
  call extend(s:session, {'lessons': lessons, 'warning': '', 'demo': {}, 'running': 0})
  call s:OpenRound(a:round)
endfunction

" Puts back a window the learner closed during a round.
function! s:Resume() abort
  let had_edit = s:Open()
  if !had_edit && !s:session.summary
    call s:StopDemo()
    call s:Reset()
  else
    call s:Render()
  endif
endfunction

" The drill being practised, as the test suite and any tooling can read it.
function! vim_dojo#Task() abort
  return deepcopy(get(s:session, 'task', {}))
endfunction

function! vim_dojo#Note(first, last, note) abort
  let path = vim_dojo#progress#Note(getline(a:first, a:last), &filetype, a:note)
  if empty(path)
    echohl ErrorMsg | echo 'Vim Dojo could not save the note.' | echohl None
  else
    echo 'Saved to the Vim Dojo inbox: ' . fnamemodify(path, ':~')
  endif
endfunction

" Opens whichever of the two windows is missing and returns whether the
" practice window was already there.
function! s:Open() abort
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
  call s:Capture()
  return has_edit
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
  command! -buffer DojoClose call vim_dojo#Action('close')
  nnoremap <buffer> <silent> <LocalLeader>h <Cmd>DojoHint<CR>
  nnoremap <buffer> <silent> <LocalLeader>r <Cmd>DojoReset<CR>
  nnoremap <buffer> <silent> <LocalLeader>s <Cmd>DojoSkip<CR>
endfunction

function! s:EditWindow() abort
  call s:Scratch()
  setlocal nofoldenable
  autocmd TextChanged,InsertLeave,CursorMoved <buffer> call s:Auto()
  let s:session.edit = win_getid()
  let s:session.edit_buf = bufnr('%')
endfunction

" The only code that reads the learner's keys; a Neovim port replaces this
" function. Mode is tracked with autocommands because mode() inside
" KeyInputPre is unreliable outside a terminal.
function! s:Capture() abort
  augroup vim_dojo_capture
    autocmd!
    autocmd InsertEnter * let s:modes[-1] = 'i'
    autocmd InsertLeave * let s:modes[-1] = 'n'
    autocmd CmdlineEnter * call add(s:modes, 'c')
    autocmd CmdlineLeave * call s:Command(getcmdtype() . getcmdline(), get(v:event, 'abort'))
    autocmd KeyInputPre * call s:Key(keytrans(v:char), v:event.typedchar)
  augroup END
endfunction

function! s:Listening() abort
  return !empty(s:session) && has_key(s:session, 'log') && !s:session.summary
        \ && !s:session.running && empty(s:session.demo) && bufnr('%') == s:session.edit_buf
endfunction

" Keys with a typedchar were pressed by the learner. The rest are Vim
" replaying a change for . or a register for @, expanding x into dl, or the
" tail of a mapping, whose first key already carries what was typed. But
" after waiting 'updatetime' for a key, Vim writes a NUL ahead of it in
" typedchar, which then reads empty; replays and mapping tails never wait,
" so a key that came after such a wait was typed too. Pseudo-keys such as
" <CursorHold> carry a typedchar and are never counted.
" ponytail: a replayed command slower than 'updatetime' makes the next
" replayed key count; only a tiny 'updatetime' gets near that.
function! s:Key(key, typed) abort
  let waited = reltimefloat(reltime(s:last_key)) * 1000 >= &updatetime
  let s:last_key = reltime()
  if (!empty(a:typed) || waited) && index(s:pseudo_keys, a:key) < 0 && s:Listening()
    call add(s:session.log, [s:modes[-1], a:key])
    let &l:scroll = s:scroll
  endif
endfunction

function! s:Command(line, abort) abort
  if len(s:modes) > 1
    call remove(s:modes, -1)
  endif
  if !a:abort && s:Listening()
    call add(s:session.commands, a:line)
  endif
endfunction

function! s:Streams() abort
  let streams = {'n': '', 'i': '', 'c': join(s:session.commands, "\n")}
  for [mode, key] in s:session.log
    if mode !=# 'c'
      let streams[mode] .= vim_dojo#drills#Code(key)
    endif
  endfor
  return streams
endfunction

" Every goal's target is worked out when the round opens. A goal solved
" mid-mapping or mid-burst opens the next with keys still queued, and
" playing a solution then would run them too.
" A goal {'generated': 1} is drawn from the generators of its `lesson`, or
" of the round's lesson, and the rest are drills.
function! s:OpenRound(round) abort
  let round = a:round
  let lesson = get(s:session.lessons, round.lesson, {})
  let generated = {}
  for goal in filter(copy(round.goals), 'get(v:val, "generated")')
    let id = get(goal, 'lesson', round.lesson)
    let generated[id] = add(get(generated, id, []), goal)
  endfor
  " Playing solutions only adds to the history, and copying a long one is
  " slow, so it is copied once for the whole round, not for each play.
  let history = s:History()
  let s:history_saved = 1
  try
    for [id, goals] in items(generated)
      let generated[id] = s:Generated(s:session.lessons[id], goals)
    endfor
    let tasks = []
    for goal in round.goals
      if get(goal, 'generated')
        call add(tasks, remove(generated[get(goal, 'lesson', round.lesson)], 0))
      else
        let s:session.task = vim_dojo#drills#Instance(goal)
        call s:Prepare()
        call add(tasks, s:session.task)
      endif
    endfor
  finally
    let s:history_saved = 0
    call s:PutHistory(history)
  endtry
  " A mixed round asking for more goals than its lessons could give goes
  " round them, as a timed one does.
  let base = copy(tasks)
  while len(tasks) < get(round, 'count', 0)
    call extend(tasks, deepcopy(base))
  endwhile
  let tasks = tasks[: max([get(round, 'count', 0), len(base)]) - 1]
  call extend(s:session, {'round': round, 'tasks': tasks, 'lesson': lesson, 'index': 0,
        \ 'results': [], 'summary': 0, 'last': '', 'round_started': localtime(),
        \ 'demo_first': get(round, 'demo', 0), 'limit': get(round, 'limit', 0)})
  if s:session.limit > 0
    let s:session.limit_timer = timer_start(s:session.limit * 1000, function('s:TimeUp'))
  endif
  call s:OpenTask()
endfunction

function! s:OpenTask() abort
  call s:StopDemo()
  let task = s:session.tasks[s:session.index]
  call extend(s:session, {'task': task, 'attempt': vim_dojo#progress#Attempt(),
        \ 'hinted': 0, 'step': 0, 'hint': 0, 'feedback': []})
  call s:Save('started')
  if s:session.demo_first && s:session.index == 0 && has_key(task, 'tokens') && !get(task, 'custom')
    call s:Demo()
  else
    call s:Reset()
  endif
endfunction

" Draws a round of generated goals on one snippet, playing each to find its
" target and throwing away any that fails, does not do what its lesson
" does, repeats a goal, or is in reach of h j k l x. A goal may name the
" snippet. A cursor lesson starts each goal on the last one's target, and
" somewhere fresh when nothing fits there.
function! s:Generated(lesson, goals) abort
  let names = filter(map(copy(a:goals), 'get(v:val, "snippet", "")'), '!empty(v:val)')
  let snippets = filter(vim_dojo#drills#Suits(a:lesson, len(a:goals)),
        \ {_, snippet -> empty(names) || index(names, snippet.name) >= 0})
  let walks = !empty(filter(flattennew(map(copy(a:lesson.keys), 'split(v:val[0])')),
        \ 'index(["h", "j", "k", "l", "x"], v:val) >= 0'))
  let first = empty(snippets) ? 0 : rand() % len(snippets)
  for snippet in slice(snippets, first) + slice(snippets, 0, first)
    let [tasks, seen, tried, from, misses] = [[], {}, {}, [], 0]
    while len(tasks) < len(a:goals) && misses < 160
      let task = vim_dojo#drills#Draw(a:lesson, snippet, from, tried)
      if s:Keep(task, seen, walks)
        call add(tasks, task)
        let [from, misses] = [task.moves ? task.target : [], 0]
      else
        let misses += 1
        let from = misses % 40 ? from : []
      endif
    endwhile
    if len(tasks) == len(a:goals)
      return tasks
    endif
  endfor
  throw 'Vim Dojo: no snippet fills a round of ' . a:lesson.id
endfunction

" A cursor goal must move the cursor and leave the text; an edit must change
" only the place it highlights. Lines above and below the place's line stay
" as they were, and what that line became keeps the text before and after
" the place, or, when lines were added, keeps the line itself.
" A round does not repeat a cursor goal, nor an edit's place.
function! s:Keep(task, seen, walks) abort
  if empty(a:task)
    return 0
  endif
  let key = string(a:task.moves ? [a:task.position, a:task.solution] : a:task.place[: 1])
  if has_key(a:seen, key)
    return 0
  endif
  let s:session.task = a:task
  try
    call s:Prepare()
  catch /^Vim Dojo:/
    return 0
  endtry
  let [lines, expected] = [a:task.lines, a:task.expected]
  if a:task.moves
    " Keys that reach the target before they end, as f then a ; that finds
    " nothing more, would overstate par.
    let kept = lines ==# expected && type(get(a:task, 'target')) == v:t_list
          \ && index(s:Isolated({-> map(range(1, a:task.par - 1),
          \   {_, length -> s:Play(a:task.tokens[: length - 1])[1]})}), a:task.target) < 0
          \ && s:Steady(a:task)
  else
    let [lnum, col, text] = a:task.place
    let old = lines[lnum - 1]
    let below = len(lines) - lnum
    let region = slice(expected, lnum - 1, len(expected) - below)
    let new = join(region, "\n")
    let [head, tail] = [strpart(old, 0, col - 1), strpart(old, col - 1 + len(text))]
    let kept = lines !=# expected && len(expected) - below >= lnum - 1
          \ && slice(lines, 0, lnum - 1) ==# slice(expected, 0, lnum - 1)
          \ && slice(lines, lnum) ==# slice(expected, len(expected) - below)
          \ && (len(region) > 1 && index(region, old) >= 0 || len(new) >= len(head) + len(tail)
          \     && strpart(new, 0, len(head)) ==# head && strpart(new, len(new) - len(tail)) ==# tail)
  endif
  if !kept || !a:walks && s:Walkable(a:task, a:task.par + s:margin)
    return 0
  endif
  let a:seen[key] = 1
  return 1
endfunction

" Whether a cursor goal's target stays put when the window is a little
" taller or shorter, as it is once the panel changes. From a wrapped line,
" Ctrl-D lands on a line that depends on the window's height.
function! s:Steady(task) abort
  let height = winheight(0)
  try
    for other in [height - 2, height + 2]
      execute 'resize' other
      if s:Isolated({-> s:Play(a:task.tokens)})[1] != a:task.target
        return 0
      endif
    endfor
    return 1
  finally
    execute 'resize' height
  endtry
endfunction

" Whether h j k l and x alone could do a goal in `limit` keys. x only
" deletes within a line, so an edit is in reach only when each changed line
" is the old one with few enough characters taken out. A cursor goal is
" searched key by key from its start, with the text still loaded.
function! s:Walkable(task, limit) abort
  if len(a:task.lines) != len(a:task.expected)
    return 0
  elseif a:task.lines !=# a:task.expected
    let deleted = 0
    for index in range(len(a:task.lines))
      let [old, new] = [a:task.lines[index], a:task.expected[index]]
      if old !=# new
        if old !~# '\V' . join(map(split(new, '\zs'), 'escape(v:val, "\\")'), '\.\{-}')
          return 0
        endif
        let deleted += strchars(old) - strchars(new)
      endif
    endfor
    return deleted <= a:limit
  elseif abs(a:task.target[0] - a:task.position[0]) > a:limit
    " Each line up or down takes a key.
    return 0
  endif
  let s:session.running = 1
  " The search's own keys fire no autocommands, the key count's included.
  let eventignore = &eventignore
  set eventignore=all
  try
    call cursor(a:task.position)
    let frontier = [winsaveview()]
    let seen = {}
    for depth in range(a:limit + 1)
      if !empty(filter(copy(frontier), {_, view -> [view.lnum, view.col + 1] == a:task.target}))
        return 1
      endif
      let next = []
      for view in frontier
        for key in ['h', 'j', 'k', 'l']
          call winrestview(view)
          execute 'normal!' key
          let state = filter(winsaveview(), {name, _ -> index(['lnum', 'col', 'curswant'], name) >= 0})
          " A line too far from the target for the keys left is a dead end.
          if !has_key(seen, string(state)) && abs(state.lnum - a:task.target[0]) < a:limit - depth
            let seen[string(state)] = 1
            call add(next, state)
          endif
        endfor
      endfor
      let frontier = next
    endfor
    return 0
  finally
    let &eventignore = eventignore
    let s:session.running = 0
  endtry
endfunction

" Plays the solution once to learn the expected buffer, or for a drill that
" leaves the text alone, the cursor target.
function! s:Prepare() abort
  let task = s:session.task
  if has_key(task, 'tokens') && !get(task, 'custom') && type(get(task, 'target')) != v:t_list
    let [task.expected, end, error] = s:Isolated({-> s:Play(task.tokens)})
    if !empty(error)
      throw printf('Vim Dojo: the solution for %s failed: %s', task.id, error)
    elseif has_key(task, 'destination')
      if task.expected !=# task.lines
        throw 'Vim Dojo: the jump drill ' . task.id . ' changes the buffer'
      endif
    elseif task.expected ==# task.lines
      if end ==# task.position
        throw 'Vim Dojo: the solution for ' . task.id . ' changes nothing'
      endif
      let task.target = end
    endif
  elseif !has_key(task, 'expected')
    let task.expected = copy(task.lines)
  endif
endfunction

" Puts the drill's starting text and cursor in the practice buffer. A drill
" may also bring undo history: `history` lists earlier buffers to undo back
" to, oldest first, and `redo` later ones that have been undone, and marks
" already set.
function! s:Load() abort
  let task = s:session.task
  if &l:filetype !=# task.ft
    let &l:filetype = task.ft
  endif
  setlocal modifiable
  let undolevels = &l:undolevels
  let states = get(task, 'history', []) + [task.lines] + get(task, 'redo', [])
  " A cursor lesson keeps its text between goals.
  if !get(task, 'moves') || getline(1, '$') !=# task.lines
    setlocal undolevels=-1
    try
      call s:Fill(states[0])
      let &l:undolevels = undolevels
      for state in states[1 :]
        " Setting undolevels ends an undo block, so each state is its own step.
        let &g:undolevels = &g:undolevels
        call s:Fill(state)
      endfor
      for _ in get(task, 'redo', [])
        silent undo
      endfor
    finally
      let &l:undolevels = undolevels
    endtry
  endif
  setlocal nomodified nofoldenable
  for [name, at] in items(get(task, 'marked', {}))
    call setpos("'" . name, [0, at[0], at[1], 0])
  endfor
  call cursor(task.position[0], task.position[1])
  let &l:scroll = s:scroll
  normal! zz
endfunction

function! s:Fill(lines) abort
  call setline(1, a:lines)
  call deletebufline(bufnr('%'), len(a:lines) + 1, '$')
endfunction

" Runs built-in keys from the starting state and puts back what they changed
" outside the buffer. Returns the resulting lines, cursor, and any error.
" Custom drills never get here: their keys come from a file and are only
" shown and counted, never run.
function! s:Play(tokens) abort
  call s:Load()
  let s:session.running = 1
  let error = ''
  clearjumps
  try
    call feedkeys(vim_dojo#drills#Raw(a:tokens), 'ntx')
  catch
    let error = v:exception
  finally
    if reg_recording() !=# ''
      call feedkeys('q', 'ntx')
    endif
    let result = [getline(1, '$'), [line('.'), col('.')], error]
    " An empty insert leaves . with nothing to repeat from these keys.
    call feedkeys("i\<Esc>", 'ntx')
    let s:session.running = 0
  endtry
  return result
endfunction

" Runs plays with the clipboard out of reach, then puts back what they
" changed outside the buffer: registers, history, the last f or t, search
" state, and marks. Searches do not wrap, so a goal that says "after the
" cursor" never lands before it; a solution that would wrap fails instead.
function! s:Isolated(Plays) abort
  let snapshot = s:Snapshot()
  let [clipboard, wrapscan] = [&clipboard, &wrapscan]
  set clipboard= nowrapscan
  try
    let result = a:Plays()
  finally
    let [&clipboard, &wrapscan] = [clipboard, wrapscan]
    call s:Restore(snapshot)
  endtry
  return result
endfunction

function! s:Snapshot() abort
  " Only these keys can add to the history, and copying a long one is slow.
  let touches = !s:history_saved && join(get(s:session.task, 'tokens', [':']), '') =~# '[/?:*#@]'
  return {'registers': map(copy(s:registers), {_, name -> [name, getreginfo(name)]}),
        \ 'history': touches ? s:History() : {}, 'char': getcharsearch(),
        \ 'hlsearch': v:hlsearch, 'forward': v:searchforward}
endfunction

" The search and command history, oldest first, with each one's count.
function! s:History() abort
  let history = {}
  for type in ['/', ':']
    let entries = map(range(1, &history), {_, back -> histget(type, -back)})
    let history[type] = [histnr(type), reverse(filter(entries, '!empty(v:val)'))]
  endfor
  return history
endfunction

" Puts back a history s:History() copied. @: cannot be set, so when a
" command ran it is left repeating something harmless.
function! s:PutHistory(history) abort
  if empty(a:history)
    return
  endif
  if histnr(':') != a:history[':'][0]
    let s:session.running = 1
    call feedkeys(":echo\<CR>", 'ntx')
    let s:session.running = 0
  endif
  for [type, saved] in items(a:history)
    if histnr(type) != saved[0]
      call histdel(type)
      for entry in saved[1]
        call histadd(type, entry)
      endfor
    endif
  endfor
endfunction

function! s:Restore(snapshot) abort
  for [name, info] in a:snapshot.registers
    call setreg(name, info)
  endfor
  call s:PutHistory(a:snapshot.history)
  call setcharsearch(a:snapshot.char)
  let v:hlsearch = a:snapshot.hlsearch
  let v:searchforward = a:snapshot.forward
  delmarks!
  silent! delmarks .^[]<>
endfunction

" Reset sends no keys, so the demo's timer can call it safely.
function! s:Reset() abort
  call s:Load()
  " A command line that never reported leaving cannot skew later drills.
  let s:modes = ['n']
  clearjumps
  call extend(s:session, {'step': 0, 'hint': 0, 'feedback': [], 'log': [], 'commands': [],
        \ 'started': localtime()})
  let s:session.seen = s:Now()
  call s:Highlight()
  call s:Render()
endfunction

" Reset leaves the buffer and cursor exactly as `seen` records them, so the
" events its own setline() and cursor() raise stop here without a check.
function! s:Auto() abort
  if empty(s:session) || !has_key(s:session, 'seen') || s:session.running || !empty(s:session.demo)
    return
  endif
  let now = s:Now()
  if now ==# s:session.seen || s:session.summary || !s:WindowExists('panel')
    return
  endif
  let edited = now[0] != s:session.seen[0]
  let s:session.seen = now
  call s:Check(edited)
endfunction

" The jump list length is part of it so a search and Ctrl-O typed in one
" burst, which leave the cursor where it started, still count as movement.
function! s:Now() abort
  return [b:changedtick, line('.'), col('.'), len(getjumplist()[0])]
endfunction

" Marks what still has to change, by line and text, so each mark goes away
" as its edit is made: a generated edit's place, or the changed text. A
" cursor drill marks its target instead.
function! s:Highlight() abort
  call s:Unmark()
  let task = s:session.task
  if !get(g:, 'vim_dojo_highlight', 1) || get(task, 'locate', 0) || has_key(task, 'destination')
    return
  endif
  highlight default link DojoTarget DiffText
  if type(get(task, 'target')) == v:t_list
    call add(w:dojo_matches, matchaddpos('DojoTarget', [get(task, 'line') ? task.target[0] : task.target]))
    return
  endif
  for pattern in get(task, 'marks', s:Changes(task.lines, task.expected))
    call add(w:dojo_matches, matchadd('DojoTarget', pattern))
  endfor
endfunction

function! s:Unmark() abort
  for id in get(w:, 'dojo_matches', [])
    silent! call matchdelete(id)
  endfor
  let w:dojo_matches = []
endfunction

function! s:Changes(old, new) abort
  let patterns = []
  for hunk in diff(a:old, a:new, {'output': 'indices'})
    for offset in range(hunk.from_count)
      let index = hunk.from_idx + offset
      let line = a:old[index]
      if hunk.from_count == hunk.to_count
        let [start, end] = s:Span(line, a:new[hunk.to_idx + offset])
        if end > start
          call add(patterns, '\%' . (index + 1) . 'l\V' . escape(strpart(line, start, end - start), '\'))
        endif
      elseif line =~# '\S'
        call add(patterns, '\%' . (index + 1) . 'l\V\^' . escape(line, '\') . '\$')
      endif
    endfor
  endfor
  return patterns
endfunction

" The changed part of a line, widened to whole words and to the quotes
" around them, so "widget" is marked rather than widge.
function! s:Span(old, new) abort
  let start = 0
  while start < len(a:old) && start < len(a:new) && a:old[start] ==# a:new[start]
    let start += 1
  endwhile
  let tail = 0
  while tail < len(a:old) - start && tail < len(a:new) - start
        \ && a:old[len(a:old) - 1 - tail] ==# a:new[len(a:new) - 1 - tail]
    let tail += 1
  endwhile
  let end = len(a:old) - tail
  if end <= start
    return [start, start]
  endif
  while start > 0 && a:old[start - 1] =~# '\k'
    let start -= 1
  endwhile
  while end < len(a:old) && a:old[end] =~# '\k'
    let end += 1
  endwhile
  if start > 0 && end < len(a:old) && a:old[start - 1] =~# '["'']' && a:old[start - 1] ==# a:old[end]
    return [start - 1, end + 1]
  endif
  return [start, end]
endfunction

function! vim_dojo#Action(action) abort
  if empty(s:session) || !has_key(s:session, 'edit_buf')
        \ || index([s:session.edit_buf, s:session.panel_buf], bufnr('%')) < 0
    return
  endif
  if a:action ==# 'close'
    call s:Close()
    return
  endif
  if !s:WindowExists('edit') || !s:WindowExists('panel')
    call s:Resume()
    return
  endif
  call win_gotoid(s:session.edit)
  if s:session.summary
    if a:action ==# 'check' || a:action ==# 'next'
      call s:Close()
    endif
  elseif !empty(s:session.demo) && a:action !=# 'skip'
    " Any dojo key during a demo ends it and hands the goal over.
    call s:StopDemo()
    call s:Reset()
  elseif a:action ==# 'check'
    call s:Check(1)
  elseif a:action ==# 'hint'
    call s:Hint()
  elseif a:action ==# 'reset'
    call s:Reset()
  elseif a:action ==# 'skip'
    call s:Save('skipped')
    call s:Finish(0, -1)
  endif
endfunction

" A round the shell started ends by quitting Vim, which asks first about
" any file the learner changed meanwhile.
function! s:Close() abort
  call s:StopDemo()
  call timer_stop(get(s:session, 'limit_timer', -1))
  autocmd! vim_dojo_capture
  if get(s:, 'run')
    confirm qall
    return
  endif
  if s:WindowExists('edit')
    call win_gotoid(s:session.edit)
  endif
  tabclose
endfunction

" At the limit the round ends where it stands; the goal under way is not
" counted. A round closed meanwhile is left alone, and a window the learner
" closed is put back to show the summary.
function! s:TimeUp(timer) abort
  if get(s:session, 'limit_timer', -1) != a:timer || s:session.summary
        \ || !s:WindowExists('edit') && !s:WindowExists('panel')
    return
  endif
  call s:StopDemo()
  if !s:WindowExists('edit') || !s:WindowExists('panel')
    call s:Open()
  endif
  " Leave Insert, Visual, or the command line; the key is not counted.
  if mode() !=# 'n'
    call feedkeys("\<Esc>", 'n')
  endif
  call s:EndRound()
endfunction

" Says where the attempt stands when asked to report. A cursor move that gets
" nowhere stays quiet, so it cannot wipe a hint or a diff off the panel.
function! s:Check(report) abort
  let task = s:session.task
  let actual = getline(1, '$')
  let step = s:session.step
  let jumped = has_key(task, 'destination')
  if actual !=# task.expected
    let feedback = ['The buffer still differs from the target.']
          \ + s:Diff(actual, task.expected)
  elseif jumped && step == 0 && line('.') == task.position[0]
        \ && !empty(filter(getjumplist()[0], {_, jump -> jump.lnum == task.destination}))
    " Both stops typed before the dojo saw the first, as a fast typist can.
    return s:Solved()
  elseif jumped && step == 0 && line('.') != task.destination
    let feedback = ['Move the cursor onto the definition.']
  elseif jumped && step == 0
    let s:session.step = 1
    let s:session.hint = 0
    let feedback = ['Found the definition.']
  elseif jumped && line('.') != task.position[0]
    let feedback = ['Return to the original call.']
  elseif type(get(task, 'target')) == v:t_list && line('.') != task.target[0]
    let feedback = ['Move the cursor onto the highlighted ' . (get(task, 'line') ? 'line.' : 'character.')]
  elseif type(get(task, 'target')) == v:t_list && !get(task, 'line') && col('.') != task.target[1]
    let feedback = ['Right line. The target is the highlighted character.']
    " Said on a plain cursor move too, or the learner sits on the line wondering.
    let loud = 1
  else
    return s:Solved()
  endif
  if a:report || step != s:session.step || exists('loud')
    let s:session.feedback = feedback
    call s:Render()
  endif
endfunction

" Which keys were used does not matter, only how many. A goal with no par,
" a custom drill without a solution, is clean when solved without a hint.
function! s:Solved() abort
  let task = s:session.task
  let keys = len(s:session.log)
  let clean = !s:session.hinted && keys <= get(task, 'par', keys) + s:margin
  call s:Save(clean ? 'clean' : 'unclean', {'keys': keys, 'seconds': localtime() - s:session.started})
  call s:Finish(clean, keys)
endfunction

" Moves on to the next goal with no key pressed, or after the last one to
" the round's summary. Keys of -1 means the goal was skipped.
function! s:Finish(clean, keys) abort
  let task = s:session.task
  let entry = {'clean': a:clean, 'keys': a:keys, 'par': get(task, 'par', -1), 'hinted': s:session.hinted,
        \ 'goal': task.goal, 'solution': has_key(task, 'tokens') ? vim_dojo#drills#Show(task.tokens) : task.keys,
        \ 'advice': a:clean || a:keys < 0 ? [] : s:Advice(s:Streams())}
  call add(s:session.results, entry)
  let s:session.last = 'Last: ' . s:Outcome(entry)
  let s:session.index += 1
  " A timed round whose goals run out before its limit goes round them
  " again. Their targets were worked out as it opened, so no solution is
  " played while the learner's keys may still be queued.
  if s:session.limit > 0 && s:session.index == len(s:session.tasks)
    call extend(s:session.tasks, deepcopy(s:session.tasks[: len(s:session.round.goals) - 1]))
  endif
  if s:session.index < len(s:session.tasks)
    call s:OpenTask()
  else
    call s:EndRound()
  endif
endfunction

" How a goal went: keys against par, and the par solution if not clean.
function! s:Outcome(entry) abort
  let parts = [a:entry.keys < 0 ? 'skipped' : printf('%d keys', a:entry.keys)]
  if a:entry.par >= 0
    call add(parts, 'par ' . a:entry.par)
  endif
  if a:entry.hinted
    call add(parts, 'hint')
  endif
  call add(parts, a:entry.clean ? 'clean' : 'try ' . a:entry.solution)
  return join(parts, ' · ')
endfunction

" A learn or review round leaves a record that schedules its lesson; a
" mixed round's names none, so it feeds stats only. Leaving a round early
" leaves none, so it changes no schedule.
function! s:EndRound() abort
  call timer_stop(get(s:session, 'limit_timer', -1))
  let round = s:session.round
  let clean = len(filter(copy(s:session.results), 'v:val.clean'))
  let goals = len(s:session.results)
  let s:session.passed = clean * 10 >= s:pass * goals
  let s:session.seconds = localtime() - s:session.round_started
  let record = {'result': 'round', 'kind': round.kind, 'clean': clean, 'goals': goals,
        \ 'passed': s:session.passed, 'seconds': s:session.seconds}
  if index(['learn', 'review'], round.kind) >= 0
    call s:Write(extend(record, {'id': round.lesson, 'technique': round.lesson}))
  elseif round.kind ==# 'mixed'
    call s:Write(extend(record, {'id': 'mixed'}))
  endif
  " A passed section review places the lessons its request names, the
  " section's new ones, as known. Its own record names no lesson, so it
  " moves no box.
  let s:session.placed = []
  if round.kind ==# 'section'
    call s:Write(extend(record, {'id': round.section, 'section': round.section}))
    let s:session.placed = s:session.passed ? get(round, 'place', []) : []
    for id in s:session.placed
      call s:Write({'id': id, 'technique': id, 'result': 'placed'})
    endfor
  endif
  let s:session.summary = 1
  " The time limit can end a round from outside the practice window.
  call setbufvar(s:session.edit_buf, '&modifiable', 0)
  call s:Render()
endfunction

" Calls out the obvious long way round, with the shorter one.
function! s:Advice(streams) abort
  let repeated = matchlist(a:streams.n, '\C\([hjklwbe]\)\1\{3,}')
  if !empty(repeated)
    return [printf('You pressed %s %d times in a row; a count like %d%s, or a bigger motion, does it at once.',
          \ repeated[1], len(repeated[0]), len(repeated[0]), repeated[1])]
  elseif a:streams.n . a:streams.i =~# '[' . vim_dojo#drills#Code('<Left><Right><Up><Down>') . ']'
    return ['Arrow keys work, but h j k l and motions keep your hands on the home row.']
  elseif a:streams.n =~# '\Cxxx'
    return ['Repeated x deletes one character at a time; dw, a text object, or a count does it in one.']
  endif
  return []
endfunction

function! s:Diff(actual, expected) abort
  let delta = diff(a:actual, a:expected)
  if type(delta) == v:t_string && !empty(delta)
    let lines = split(delta, "\n")
    return len(lines) > 5 ? lines[:3] + ['…'] : lines
  endif
  return []
endfunction

" The keys, then the demo. Any hint makes the goal not clean.
function! s:Hint() abort
  let task = s:session.task
  let s:session.hinted = 1
  let s:session.hint += 1
  if s:session.hint == 1 || !has_key(task, 'tokens') || get(task, 'custom')
    let s:session.feedback = ['Hint  ' . (has_key(task, 'tokens') ? vim_dojo#drills#Show(task.tokens) : task.keys)]
    call s:Render()
  else
    call s:Demo()
  endif
endfunction

" Shows the solution being typed. Every frame is worked out first, so the
" timer only paints text and never sends keys.
function! s:Demo() abort
  let tokens = s:session.task.tokens
  let frames = s:Isolated({-> map(range(1, len(tokens)), {_, length -> s:Play(tokens[: length - 1])})})
  call s:Load()
  let s:session.demo = {'frames': frames, 'shown': 0, 'timer': -1}
  let s:session.feedback = []
  call s:Render()
  let delay = get(g:, 'vim_dojo_demo_delay', 400)
  if delay <= 0
    call s:EndDemo()
  else
    let s:session.demo.timer = timer_start(delay, function('s:DemoStep'), {'repeat': -1})
  endif
endfunction

function! s:DemoStep(timer) abort
  let demo = get(s:session, 'demo', {})
  if empty(demo) || demo.timer != a:timer || !s:WindowExists('edit') || !s:WindowExists('panel')
    call timer_stop(a:timer)
    return
  endif
  if demo.shown == len(demo.frames)
    " Hand over only from Normal mode, so the mode the dojo tracks is true.
    " :stopinsert does not act from a timer while Insert mode waits for a key,
    " so queue an <Esc>; the next tick finds Normal mode.
    if mode() =~# '^[iR]'
      call feedkeys("\<Esc>", 'n')
    elseif mode() ==# 'n'
      call s:EndDemo()
    endif
    return
  endif
  let [lines, cursor, _] = demo.frames[demo.shown]
  let demo.shown += 1
  let buf = s:session.edit_buf
  let undolevels = getbufvar(buf, '&undolevels')
  call setbufvar(buf, '&undolevels', -1)
  call setbufline(buf, 1, lines)
  call deletebufline(buf, len(lines) + 1, '$')
  call setbufvar(buf, '&undolevels', undolevels)
  call win_execute(s:session.edit, printf('call cursor(%d, %d)', cursor[0], cursor[1]))
  call s:Render()
  redraw
endfunction

function! s:EndDemo() abort
  call s:StopDemo()
  if s:WindowExists('edit')
    call win_gotoid(s:session.edit)
    call s:Reset()
  endif
endfunction

function! s:StopDemo() abort
  let demo = get(s:session, 'demo', {})
  if !empty(demo)
    call timer_stop(demo.timer)
    let s:session.demo = {}
  endif
endfunction

" Records the current goal under its attempt name.
function! s:Save(result, ...) abort
  let task = s:session.task
  let record = extend({'id': task.id, 'result': a:result}, get(a:, 1, {}))
  " Records keep the v2 field name.
  if has_key(task, 'lesson')
    let record.technique = task.lesson
  endif
  call s:Write(record, s:session.attempt)
endfunction

function! s:Write(record, ...) abort
  let saved = vim_dojo#progress#Record(a:0 ? a:1 : vim_dojo#progress#Attempt(), a:record)
  let s:session.warning = saved ? '' : 'Progress could not be saved to disk.'
endfunction

function! s:Title() abort
  let kind = s:session.round.kind
  let lesson = s:session.lesson
  let title = kind ==# 'learn' ? 'Learn  ' . lesson.title
        \ : kind ==# 'review' ? 'Review  ' . lesson.title
        \ : kind ==# 'section' ? 'Section review  ' . s:session.round.name
        \ : kind ==# 'mixed' ? 'Mixed practice' : 'Free practice'
  return 'Vim Dojo  ·  ' . title
endfunction

" How many goals were clean, the time taken, each goal that was not clean
" with its par solution, and the first long way round, said once.
function! s:Summary() abort
  let results = s:session.results
  let clean = len(filter(copy(results), 'v:val.clean'))
  let kind = s:session.round.kind
  let lines = [s:Title() . '  ·  done', '', s:session.last, '',
        \ printf('%d of %d clean  ·  %d:%02d', clean, len(results), s:session.seconds / 60, s:session.seconds % 60)
        \ . (index(['learn', 'review', 'section'], kind) < 0 ? '' : s:session.passed ? '  ·  passed'
        \   : printf('  ·  not passed: %d of %d clean passes', (s:pass * len(results) + 9) / 10, len(results)))]
  if kind ==# 'section' && s:session.passed
    let placed = len(s:session.placed)
    call add(lines, printf('%d %s placed as known, in review rounds from now on.',
          \ placed, placed == 1 ? 'lesson' : 'lessons'))
  endif
  let missed = filter(map(copy(results), {index, entry -> entry.clean ? ''
        \ : printf('  %d. %s  %s', index + 1, entry.goal, s:Outcome(entry))}), '!empty(v:val)')
  if !empty(missed)
    call extend(lines, ['', 'Not clean:'] + missed)
  endif
  let advice = filter(map(copy(results), 'v:val.advice'), '!empty(v:val)')
  if !empty(advice)
    call extend(lines, [''] + advice[0])
  endif
  return lines + ['', 'Enter / :DojoNext  Back to the dashboard']
endfunction

function! s:Render() abort
  if s:session.summary
    let lines = s:Summary()
  else
    let task = s:session.task
    let lesson = s:session.lesson
    let goal = s:session.step > 0 ? 'Return to the original call.' : task.goal
    if s:session.limit > 0
      let left = max([0, s:session.limit - (localtime() - s:session.round_started)])
      let lines = [printf('%s  ·  %d  ·  %d:%02d left', s:Title(), s:session.index + 1, left / 60, left % 60), '']
    else
      let lines = [printf('%s  ·  %d/%d', s:Title(), s:session.index + 1, len(s:session.tasks)), '']
    endif
    if s:session.round.kind ==# 'learn'
      " A learn round keeps the lesson's keys in view for every goal.
      let width = max(map(copy(lesson.keys), 'strdisplaywidth(v:val[0])'))
      call extend(lines, map(copy(lesson.keys), {index, pair -> (index ? '      ' : 'Keys  ')
            \ . pair[0] . repeat(' ', width - strdisplaywidth(pair[0])) . '  ' . pair[1]}) + [''])
    endif
    if !empty(s:session.last)
      call extend(lines, [s:session.last, ''])
    endif
    call extend(lines, [goal, ''])
    let demo = s:session.demo
    if !empty(demo)
      call add(lines, 'Watch  ' . vim_dojo#drills#Show(task.tokens[: demo.shown - 1]))
      call add(lines, 'The goal is yours when the demo ends.')
    else
      call extend(lines, s:session.feedback)
      let leader = keytrans(get(g:, 'maplocalleader', '\'))
      call add(lines, printf('%sh Hint   %sr Reset   %ss Skip   :DojoClose', leader, leader, leader))
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
  " Enter is mapped only on a round's summary. Otherwise it is not ours, so
  " it stays whatever the learner has it set to.
  " ponytail: a learner <buffer> <CR> map is lost once we map over it at a
  " summary; save and mapset() it back if that ever matters.
  let ours = s:session.summary
  for win in [s:session.edit, s:session.panel]
    " A list, not '|': :nunmap would swallow '| endif' as part of the lhs.
    call win_execute(win, ours ? 'nnoremap <buffer> <silent> <CR> <Cmd>DojoNext<CR>'
          \ : ['if maparg("<CR>", "n", 0, 1)->get("rhs", "") =~# "DojoNext"', 'nunmap <buffer> <CR>', 'endif'])
  endfor
endfunction
