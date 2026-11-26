let s:session = {}
let s:modes = ['n']
let s:last_key = reltime()
let s:pseudo_keys = ['<CursorHold>', '<Ignore>', '<FocusGained>', '<FocusLost>', '<MouseMove>']
" Registers a solution or demo may touch, restored afterwards. The unnamed
" register goes last so it points where it pointed before.
let s:registers = split('0123456789abcdefghijklmnopqrstuvwxyz-/', '\zs') + ['"']

" Resumes a session in progress; otherwise opens the skill map.
function! vim_dojo#Dojo() abort
  if !empty(s:session) && !get(s:session, 'done', 1)
        \ && (s:WindowExists('edit') || s:WindowExists('panel'))
    let had_edit = s:Open()
    if !had_edit && empty(s:session.result)
      call s:StopDemo()
      call s:Reset()
    else
      call s:Render()
    endif
    return
  endif
  call vim_dojo#map#Open()
endfunction

function! vim_dojo#Start(plan, ...) abort
  call s:StopDemo()
  let techniques = {}
  for technique in vim_dojo#drills#Techniques()
    let techniques[technique.id] = technique
  endfor
  call s:Open()
  call extend(s:session, {'plan': a:plan, 'kind': get(a:, 1, 'session'), 'techniques': techniques,
        \ 'index': 0, 'results': [], 'warning': '', 'done': 0, 'placed': 0, 'demo': {}, 'running': 0})
  call s:OpenTask()
endfunction

function! vim_dojo#Focus(id) abort
  let matches = filter(vim_dojo#drills#Techniques(), {_, t -> t.id ==# a:id})
  if empty(matches)
    echohl ErrorMsg | echo 'Vim Dojo has no technique called ' . a:id | echohl None
    return
  endif
  call vim_dojo#Start(vim_dojo#progress#Focus(matches[0]), 'focus')
endfunction

function! vim_dojo#Free() abort
  let drills = []
  for technique in vim_dojo#drills#Techniques()
    call extend(drills, technique.drills)
  endfor
  let drill = drills[rand() % len(drills)]
  call vim_dojo#Start([extend(copy(drill), {'phase': 'Free practice · ' . drill.id})], 'free')
endfunction

function! vim_dojo#Diagnostic() abort
  call vim_dojo#Start(vim_dojo#progress#Diagnostic(vim_dojo#drills#Techniques()), 'diagnostic')
endfunction

" The drill being practised, as the test suite and any tooling can read it.
function! vim_dojo#Task() abort
  return deepcopy(get(s:session, 'task', {}))
endfunction

function! vim_dojo#Complete(lead, ...) abort
  return filter(map(vim_dojo#drills#Techniques(), {_, t -> t.id}), {_, id -> id =~# '^' . a:lead})
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
  return !empty(s:session) && has_key(s:session, 'log') && empty(s:session.result)
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

function! s:OpenTask() abort
  call s:StopDemo()
  let task = vim_dojo#drills#Instance(s:session.plan[s:session.index])
  call extend(s:session, {'task': task, 'attempt': vim_dojo#progress#Attempt(),
        \ 'assisted': 0, 'result': '', 'card': [], 'step': 0, 'hint': 0, 'feedback': []})
  call s:Save('started')
  call s:Prepare()
  let technique = get(s:session.techniques, get(task, 'technique', ''), {})
  if s:session.kind !=# 'diagnostic' && has_key(task, 'tokens') && !get(task, 'custom') && has_key(technique, 'card')
        \ && !vim_dojo#progress#State([technique])[technique.id].box
    let s:session.card = [printf('New technique  %s  ·  %s', technique.keys, technique.name)]
          \ + technique.card + ['']
    call s:Demo()
  else
    call s:Reset()
  endif
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
" to, oldest first, and `redo` later ones that have been undone.
function! s:Load() abort
  let task = s:session.task
  if &l:filetype !=# task.ft
    let &l:filetype = task.ft
  endif
  setlocal modifiable
  let undolevels = &l:undolevels
  let states = get(task, 'history', []) + [task.lines] + get(task, 'redo', [])
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
  setlocal nomodified nofoldenable
  call cursor(task.position[0], task.position[1])
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
" state, and marks.
function! s:Isolated(Plays) abort
  let snapshot = s:Snapshot()
  let clipboard = &clipboard
  set clipboard=
  try
    let result = a:Plays()
    if histnr(':') != snapshot.history[':'][0]
      " @: cannot be set, so leave it repeating something harmless.
      let s:session.running = 1
      call feedkeys(":echo\<CR>", 'ntx')
      let s:session.running = 0
    endif
  finally
    let &clipboard = clipboard
    call s:Restore(snapshot)
  endtry
  return result
endfunction

function! s:Snapshot() abort
  let history = {}
  for type in ['/', ':']
    let entries = map(range(1, &history), {_, back -> histget(type, -back)})
    let history[type] = [histnr(type), reverse(filter(entries, '!empty(v:val)'))]
  endfor
  return {'registers': map(copy(s:registers), {_, name -> [name, getreginfo(name)]}),
        \ 'history': history, 'char': getcharsearch(),
        \ 'hlsearch': v:hlsearch, 'forward': v:searchforward}
endfunction

function! s:Restore(snapshot) abort
  for [name, info] in a:snapshot.registers
    call setreg(name, info)
  endfor
  for [type, saved] in items(a:snapshot.history)
    if histnr(type) != saved[0]
      call histdel(type)
      for entry in saved[1]
        call histadd(type, entry)
      endfor
    endif
  endfor
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
  normal! zz
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
  if now ==# s:session.seen || !empty(s:session.result) || !s:WindowExists('panel')
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
" as its edit is made. A cursor drill marks its target instead.
function! s:Highlight() abort
  for id in get(w:, 'dojo_matches', [])
    silent! call matchdelete(id)
  endfor
  let w:dojo_matches = []
  let task = s:session.task
  if !get(g:, 'vim_dojo_highlight', 1) || get(task, 'locate', 0) || has_key(task, 'destination')
    return
  endif
  highlight default link DojoTarget DiffText
  if type(get(task, 'target')) == v:t_list
    call add(w:dojo_matches, matchaddpos('DojoTarget', [get(task, 'line') ? task.target[0] : task.target]))
    return
  endif
  for pattern in s:Changes(task.lines, task.expected)
    call add(w:dojo_matches, matchadd('DojoTarget', pattern))
  endfor
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
    call vim_dojo#Dojo()
    return
  endif
  if s:session.done
    if a:action ==# 'check' || a:action ==# 'next'
      call s:Close()
      call vim_dojo#map#Open()
    endif
    return
  endif
  call win_gotoid(s:session.edit)
  if !empty(s:session.demo) && a:action !=# 'skip'
    " Any dojo key during a demo ends it and hands the drill over.
    call s:StopDemo()
    call s:Reset()
  elseif a:action ==# 'check' && empty(s:session.result)
    call s:Check(1)
  elseif a:action ==# 'hint' && empty(s:session.result)
    call s:Hint()
  elseif a:action ==# 'reset' && empty(s:session.result)
    call s:Reset()
  elseif a:action ==# 'skip' || !empty(s:session.result) && index(['next', 'check'], a:action) >= 0
    if empty(s:session.result)
      call s:Save('skipped', s:session.kind ==# 'diagnostic' ? {'diagnostic': 1} : {})
    endif
    call s:Advance()
  endif
endfunction

function! s:Close() abort
  call s:StopDemo()
  autocmd! vim_dojo_capture
  if s:WindowExists('edit')
    call win_gotoid(s:session.edit)
  endif
  tabclose
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

function! s:Solved() abort
  let task = s:session.task
  let technique = get(s:session.techniques, get(task, 'technique', ''), {})
  let streams = s:Streams()
  let typed = map(copy(s:session.log), 'v:val[1]')
  let result = s:session.assisted ? 'assisted'
        \ : has_key(task, 'tokens') && vim_dojo#drills#Detect(technique, streams) ? 'recalled' : 'solved'
  let extra = {'keys': len(typed), 'seconds': localtime() - s:session.started}
  if s:session.kind ==# 'diagnostic'
    let extra.diagnostic = 1
    if result ==# 'recalled' && len(typed) <= get(task, 'par', 0) + 2
      let extra.placed = 1
      let s:session.placed += 1
    endif
  endif
  call s:Save(result, extra)
  let feedback = [has_key(task, 'par') ? printf('Solved in %d keys · par %d', len(typed), task.par)
        \ : printf('Solved in %d keys.', len(typed))]
  call add(feedback, 'You: ' . vim_dojo#drills#Show(len(typed) > 40 ? typed[: 39] + ['…'] : typed))
  if has_key(task, 'tokens')
    call add(feedback, 'Try: ' . vim_dojo#drills#Show(task.tokens))
  endif
  if result ==# 'solved' && has_key(technique, 'detect')
    call add(feedback, printf('This drill practises %s (%s).', technique.keys, tolower(technique.name)))
  endif
  call extend(feedback, s:Advice(streams) + [task.why])
  let s:session.feedback = feedback
  setlocal nomodifiable
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

" Clue, then keys, then the demo.
function! s:Hint() abort
  let task = s:session.task
  if s:session.kind ==# 'diagnostic'
    let s:session.feedback = ['No hints in the diagnostic. Skip a drill you do not know.']
    call s:Render()
    return
  endif
  let s:session.assisted = 1
  let s:session.hint += 1
  if s:session.step > 0
    let hint = s:session.hint == 1 ? 'Vim keeps a list of the places you jump from.' : 'Press Ctrl-O.'
  elseif s:session.hint == 1
    let hint = task.hint
  elseif s:session.hint == 2 || !has_key(task, 'tokens') || get(task, 'custom')
    let hint = has_key(task, 'tokens') ? vim_dojo#drills#Show(task.tokens) : task.keys
  else
    call s:Demo()
    return
  endif
  let s:session.feedback = ['Hint  ' . hint]
  call s:Render()
endfunction

" Shows the solution being typed. Every frame is worked out first, so the
" timer only paints text and never sends keys.
function! s:Demo() abort
  let tokens = s:session.task.tokens
  let frames = s:Isolated({-> map(range(1, len(tokens)), {_, count -> s:Play(tokens[: count - 1])})})
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

function! s:Save(result, ...) abort
  let task = s:session.task
  if a:result !=# 'started'
    let s:session.result = a:result
  endif
  let record = extend({'id': task.id, 'result': a:result}, get(a:, 1, {}))
  if has_key(task, 'technique')
    let record.technique = task.technique
  endif
  let saved = vim_dojo#progress#Record(s:session.attempt, record)
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
  let diagnostic = s:session.kind ==# 'diagnostic'
  if s:session.done
    let solved = total - count(s:session.results, 'skipped')
    let recalled = count(s:session.results, 'recalled')
    let lines = ['Vim Dojo  ·  ' . (diagnostic ? 'Diagnostic' : 'Session') . ' complete', '',
          \ printf('%d of %d solved  ·  %d recalled on your own', solved, total, recalled), '']
    if diagnostic
      call add(lines, printf('%d %s placed as already known. The rest are taught as you meet them.',
            \ s:session.placed, s:session.placed == 1 ? 'technique' : 'techniques'))
    else
      call add(lines, s:session.task.why)
    endif
    call extend(lines, ['', 'Enter / :DojoNext  Skill map     :DojoClose  Return to your work'])
  else
    let task = s:session.task
    let goal = s:session.step > 0 ? 'Return to the original call.' : task.goal
    let lines = [printf('Vim Dojo  ·  %d/%d  ·  %s', s:session.index + 1, total, task.phase), '']
          \ + s:session.card + [goal, '']
    let demo = s:session.demo
    if !empty(demo)
      call add(lines, 'Watch  ' . vim_dojo#drills#Show(task.tokens[: demo.shown - 1]))
      call add(lines, 'The drill is yours when the demo ends.')
    else
      call extend(lines, s:session.feedback)
      if !empty(s:session.result)
        call add(lines, 'Enter / :DojoNext  Continue')
      else
        let leader = keytrans(get(g:, 'maplocalleader', '\'))
        call add(lines, diagnostic
              \ ? printf('%ss Skip   :DojoClose  Stop the diagnostic', leader)
              \ : printf('%sh Hint   %sr Reset   %ss Skip   :DojoClose', leader, leader, leader))
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
  " Enter is mapped only while there is something to continue from. Until
  " then it is not ours, so it stays whatever the learner has it set to.
  " ponytail: a learner <buffer> <CR> map is lost once we map over it on
  " solve; save and mapset() it back if that ever matters.
  let ours = !empty(s:session.result) || s:session.done
  for win in [s:session.edit, s:session.panel]
    " A list, not '|': :nunmap would swallow '| endif' as part of the lhs.
    call win_execute(win, ours ? 'nnoremap <buffer> <silent> <CR> <Cmd>DojoNext<CR>'
          \ : ['if maparg("<CR>", "n", 0, 1)->get("rhs", "") =~# "DojoNext"', 'nunmap <buffer> <CR>', 'endif'])
  endfor
endfunction
