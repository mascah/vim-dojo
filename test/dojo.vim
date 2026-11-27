" Run from the repository root with vim -Nu NONE -i NONE -n -es -S test/dojo.vim
" Set DOJO_SKILL=move to check the solutions of one skill only.
let s:state = tempname()
let g:vim_dojo_state_dir = s:state . '/initial'
let g:vim_dojo_drill_dir = s:state . '/custom'
let g:vim_dojo_demo_delay = 0
call setline(1, 'An unsaved edit in the original window')
let s:original = bufnr('%')
let s:root = fnamemodify(expand('<sfile>:p'), ':h:h')
execute 'set runtimepath^=' . escape(s:root, '\, ')
runtime plugin/vim_dojo.vim

function! s:Panel() abort
  return join(getbufline(winbufnr(1), 1, '$'), "\n")
endfunction

function! s:Records() abort
  let dir = g:vim_dojo_state_dir
  return map(sort(readdir(dir, {name -> name =~# '^\d\+-.*\.json$'})), 'json_decode(readfile(dir . "/" . v:val)[0])')
endfunction

function! s:Last() abort
  " The next goal's started record follows a solved one at once.
  return filter(s:Records(), 'index(["round", "started", "placed"], v:val.result) < 0')[-1]
endfunction

function! s:Drill(id) abort
  for technique in vim_dojo#drills#Techniques()
    for drill in technique.drills
      if drill.id ==# a:id
        return copy(drill)
      endif
    endfor
  endfor
  throw 'No drill ' . a:id
endfunction

" A round of the named drills, of a kind that schedules nothing by default.
function! s:Round(ids, ...) abort
  let goals = map(copy(a:ids), 's:Drill(v:val)')
  return {'kind': get(a:, 1, 'free'), 'technique': get(goals[0], 'technique', ''), 'goals': goals}
endfunction

" A lesson's round of ten as the shell lays it out: generated goals then up
" to three scenarios, or its scenarios in turn. A third argument asks for
" the first goal to be demonstrated.
function! s:Lesson(id, kind, ...) abort
  let lesson = filter(vim_dojo#drills#Techniques(), 'v:val.id ==# a:id')[0]
  let drills = lesson.drills
  let goals = has_key(lesson, 'generators')
        \ ? repeat([{'generated': 1, 'lesson': a:id}], 10 - len(drills[: 2])) + drills[: 2]
        \ : map(range(10), 'drills[v:val % len(drills)]')
  return {'kind': a:kind, 'technique': a:id, 'goals': goals, 'demo': get(a:, 1, 0)}
endfunction

" A section review of five goals from each lesson, placing `place` if passed.
function! s:Section(id, place) abort
  let goals = []
  for s:lesson in filter(vim_dojo#drills#Techniques(), 'v:val.skill ==# a:id')
    call extend(goals, s:Lesson(s:lesson.id, 'section').goals[: 4])
  endfor
  return {'kind': 'section', 'technique': '', 'section': a:id, 'name': a:id, 'goals': goals, 'place': a:place}
endfunction

function! s:Rounds() abort
  return map(filter(s:Records(), 'v:val.result ==# "round"'), '[v:val.kind, v:val.clean, v:val.passed]')
endfunction

" A headless Vim raises InsertLeave by itself but not TextChanged or
" CursorMoved, so they are raised by hand after typing.
function! s:Type(keys) abort
  call feedkeys(a:keys, 'xt')
  doautocmd TextChanged
  doautocmd CursorMoved
endfunction

function! s:Solve() abort
  call s:Type(vim_dojo#drills#Raw(vim_dojo#Task().tokens))
endfunction

" Solves the first clean goals of the round at par and skips the rest.
function! s:Play(clean) abort
  for s:goal in range(10)
    if s:goal < a:clean
      call s:Solve()
    else
      DojoSkip
    endif
  endfor
endfunction

" Whether h j k l and x alone could do a goal within the clean threshold.
" x only deletes within a line, so an edit is in reach only when each changed
" line is the old one with characters taken out, few enough to delete. A
" cursor goal is searched key by key in a scratch window.
function! s:Walkable(task) abort
  let limit = a:task.par + 2
  if a:task.lines !=# a:task.expected
    if len(a:task.lines) != len(a:task.expected)
      return 0
    endif
    let cost = 0
    for index in range(len(a:task.lines))
      let [old, new] = [a:task.lines[index], a:task.expected[index]]
      if old !=# new
        if old !~# '\V' . join(map(split(new, '\zs'), 'escape(v:val, "\\")'), '\.\{-}')
          return 0
        endif
        let cost += strchars(old) - strchars(new)
      endif
    endfor
    return cost <= limit
  endif
  new
  call setline(1, a:task.lines)
  call cursor(a:task.position)
  let frontier = [winsaveview()]
  let seen = {}
  let found = 0
  for _ in range(limit + 1)
    if !empty(filter(copy(frontier), '[v:val.lnum, v:val.col + 1] == a:task.target'))
      let found = 1
      break
    endif
    let next = []
    for view in frontier
      for key in ['h', 'j', 'k', 'l']
        call winrestview(view)
        execute 'normal!' key
        let state = filter(winsaveview(), 'index(["lnum", "col", "curswant"], v:key) >= 0')
        if !has_key(seen, string(state))
          let seen[string(state)] = 1
          call add(next, state)
        endif
      endfor
    endfor
    let frontier = next
  endfor
  bwipeout!
  return found
endfunction

" Whether a cursor goal's keys reach its target before the last one, which
" would make par more than it takes, as f then a ; that finds nothing more.
function! s:Early(task) abort
  new
  call setline(1, a:task.lines)
  let early = 0
  for length in range(1, a:task.par - 1)
    call cursor(a:task.position)
    execute 'normal!' vim_dojo#drills#Raw(a:task.tokens[: length - 1])
    let early = early || [line('.'), col('.')] == a:task.target
  endfor
  bwipeout!
  return early
endfunction

" Types into a real Vim and waits for its screen to show the pattern.
function! s:Typed(keys, pattern) abort
  call term_sendkeys(s:term, a:keys)
  for attempt in range(100)
    call term_wait(s:term, 50)
    let screen = join(map(range(1, term_getsize(s:term)[0]), 'term_getline(s:term, v:val)'), "\n")
    if screen =~# a:pattern
      break
    endif
  endfor
  call assert_match(a:pattern, screen)
  return screen
endfunction

try
  " Lessons load in outline order, Foundations first. The shell's tests check
  " the sections and the map.
  call assert_equal(['modes', 'hjkl', 'word', 'insert'], map(vim_dojo#drills#Techniques()[: 3], 'v:val.id'))
  let s:outline = json_decode(join(readfile(s:root . '/lessons/outline.json'), "\n"))
  let s:order = flattennew(map(copy(s:outline), 'v:val.lessons'))
  call assert_equal(filter(copy(s:order), 'index(map(vim_dojo#drills#Techniques(), "v:val.id"), v:val) >= 0'),
        \ map(vim_dojo#drills#Techniques(), 'v:val.id'))
  " page-shape: every page has a key table naming each pinned key, an example
  " with the text before and after, when to use it, and a trap, in about 150
  " to 250 words. Every lesson file is in the outline.
  for s:file in glob(s:root . '/lessons/*.md', 0, 1)
    call assert_true(index(s:order, fnamemodify(s:file, ':t:r')) >= 0, s:file . ' is not in the outline')
  endfor
  " lesson-files: every outline lesson is a Markdown page, and no lesson
  " content is left in Vimscript or in loose JSON.
  call assert_equal(sort(copy(s:order)), sort(map(glob(s:root . '/lessons/*.md', 0, 1), 'fnamemodify(v:val, ":t:r")')))
  call assert_equal(['outline.json'], filter(readdir(s:root . '/lessons'), 'v:val !~# "\\.md$"'))
  call assert_equal([], glob(s:root . '/autoload/vim_dojo/skills', 0, 1))
  for s:lesson in filter(vim_dojo#drills#Techniques(), 'has_key(v:val, "page")')
    let s:text = join(s:lesson.page, "\n")
    call assert_match('\n| Key | What it does |\n| --- | --- |\n| ', s:text, s:lesson.id)
    let s:cells = join(map(filter(copy(s:lesson.page), 'v:val =~# "^| "'), 'split(v:val, " | ")[0]'), "\n")
    for s:pair in s:lesson.keys
      call assert_match('\V`\s\?' . escape(s:pair[0], '\') . '\s\?`', s:cells, s:lesson.id . ' table lacks ' . s:pair[0])
    endfor
    let s:example = matchstr(s:text, '\n## Example\n\zs.\{-}\ze\n## ')
    call assert_true(count(s:example, "\n```") >= 4, s:lesson.id . ' needs a before and an after')
    call assert_match('\n## When to use it\n.*\n## The trap\n', s:text, s:lesson.id)
    call assert_inrange(150, 260, len(split(s:text)), s:lesson.id . ' page length')
  endfor

  " round-length, auto-advance, keys-pinned: a learn round of ten on the
  " first lesson, its first goal demonstrated before it is handed over.
  let s:first = vim_dojo#drills#Techniques()[0]
  call vim_dojo#Start(s:Lesson(s:first.id, 'learn', 1))
  call assert_match('Learn  ' . s:first.title . '  ·  1/10', s:Panel())
  call assert_match('Keys  i  ', s:Panel())
  call assert_match('\n      Esc  come back', s:Panel())
  call assert_notmatch('Last:', s:Panel())
  let s:task = vim_dojo#Task()
  call assert_equal(s:task.lines, getline(1, '$'))
  call assert_equal(s:task.position, [line('.'), col('.')])
  call s:Solve()
  call assert_match('2/10', s:Panel())
  call assert_match(printf('Last: %d keys · par %d · clean', s:task.par, s:task.par), s:Panel())
  call assert_match('Keys  i  ', s:Panel())
  call assert_equal('clean', s:Last().result)
  call assert_equal('', maparg('<CR>', 'n'))
  for s:goal in range(1, 9)
    call assert_match(printf('%d/10', s:goal + 1), s:Panel())
    if s:goal < 8
      call s:Solve()
    else
      DojoSkip
    endif
  endfor
  " summary: the clean count and time, each goal that was not clean, Enter out.
  call assert_match('8 of 10 clean  ·  \d:\d\d  ·  passed', s:Panel())
  call assert_match('Not clean:\n  9\. .*skipped · par \d\+ · try ', s:Panel())
  call assert_match('Last: skipped', s:Panel())
  call assert_equal('<Cmd>DojoNext<CR>', maparg('<CR>', 'n'))
  call feedkeys("\<CR>", 'xt')
  " learn-pass, as the record the shell schedules from.
  call assert_equal([['learn', 8, 1]], s:Rounds())
  call assert_equal(s:first.id, filter(s:Records(), 'v:val.result ==# "round"')[0].technique)
  call assert_equal(s:original, bufnr('%'))
  call assert_equal('An unsaved edit in the original window', getline(1))
  call assert_true(&modified)

  " teach-first-meeting, demo-not-counted, highlight, auto-check, no-f-keys.
  call vim_dojo#Start(s:Round(['quoted-item', 'quoted-item'], 'learn'))
  call assert_match('Keys  ci"  change inside the quotes', s:Panel())
  call assert_equal(s:Drill('quoted-item').lines, getline(1, '$'))
  call assert_equal('w', strpart(getline('.'), col('.') - 1, 1))
  call assert_equal(repeat([''], 6), map(['<F5>', '<F6>', '<F7>', '<F8>', '<F9>', '<CR>'], 'maparg(v:val, "n")'))
  call assert_notmatch('F\d', s:Panel())
  call assert_equal(1, len(getmatches()))
  call assert_match('"widget"', getmatches()[0].pattern)
  call assert_equal(3, search(getmatches()[0].pattern, 'nw'))
  call setline(line('.') + 1, 'Collateral edit')
  execute "normal! ciwratchet\<Esc>"
  call assert_match('Collateral edit', s:Panel())
  call feedkeys('\r', 'xt')
  call assert_match('widget', getline('.'))
  call assert_notmatch('differs', s:Panel())
  call s:Type("ci\"ratchet\<Esc>")
  call assert_match('2/2', s:Panel())
  call assert_match('Last: 11 keys · par 11 · clean', s:Panel())
  call assert_equal(['clean', 11], [s:Last().result, s:Last().keys])
  " par-grading: other keys within par plus two are clean; plus three is not.
  call s:Type("lhvecratchet\<Esc>")
  call assert_match('Last: 13 keys · par 11 · clean', s:Panel())
  call assert_equal('clean', s:Last().result)
  call vim_dojo#Start(s:Round(['quoted-item', 'quoted-item']))
  call s:Type("lhlhcwratchet\<Esc>")
  call assert_match('Last: 14 keys · par 11 · try c i " r a t c h e t <Esc>', s:Panel())
  call assert_equal('unclean', s:Last().result)
  " not-clean-shown: the summary lists it again, with the long way round.
  call s:Type("xxxxxxiratchet\<Esc>")
  call assert_match('0 of 2 clean', s:Panel())
  call assert_match('  1\. Change the first item’s name to "ratchet"\.  14 keys · par 11 · try c i "', s:Panel())
  call assert_match('  2\. .*15 keys · par 11 · try c i "', s:Panel())
  call assert_equal(1, count(s:Panel(), 'Repeated x'))
  call assert_notmatch('·  passed\|not passed', s:Panel())
  " No detection pattern remains.
  for s:file in glob(s:root . '/autoload/**/*.vim', 0, 1)
    call assert_equal([], filter(readfile(s:file), 'v:val =~? "detect"'), s:file)
  endfor
  " hint-direct: the first hint shows the keys and spoils the goal however
  " few keys follow; a second plays the demo.
  call vim_dojo#Start(s:Round(['quoted-item', 'quoted-item']))
  call feedkeys('\h', 'xt')
  call assert_match('Hint  c i " r a t c h e t <Esc>', s:Panel())
  call s:Type("ci\"ratchet\<Esc>")
  " The hint key itself counts as one.
  call assert_match('Last: 12 keys · par 11 · hint · try c i "', s:Panel())
  call assert_equal('unclean', s:Last().result)
  call feedkeys('\h', 'xt')
  normal! x
  call feedkeys('\h', 'xt')
  call assert_match('widget', getline('.'))
  call assert_notmatch('Hint  c i', s:Panel())
  " A learner's own buffer-local Enter survives the panel redrawing.
  call vim_dojo#Start(s:Round(['shipping-status']))
  nnoremap <buffer> <CR> <Nop>
  call feedkeys('\h', 'xt')
  call assert_equal('<Nop>', maparg('<CR>', 'n'))
  nunmap <buffer> <CR>
  call feedkeys('\s', 'xt')
  call assert_match('0 of 1 clean', s:Panel())
  call assert_equal('skipped', s:Last().result)

  " key-count, mapping-aware, insert-dot.
  call vim_dojo#Start(s:Round(['pending-jobs']))
  call s:Type("ciwqueued\<Esc>j.j.")
  call assert_match('Last: 14 keys · par 14 · clean', s:Panel())
  inoremap jk <Esc>
  call vim_dojo#Start(s:Round(['pending-jobs']))
  call s:Type('ciwqueuedjkj.j.')
  call assert_match('Last: 14 keys · par 14 · clean', s:Panel())
  iunmap jk
  " Keys still queued when a goal is solved cannot leak into working out the
  " next goal's target.
  nnoremap Q ci"ratchet<Esc>j
  call vim_dojo#Start(s:Round(['quoted-item', 'pending-jobs']))
  call s:Type('Q')
  call assert_match('2/2', s:Panel())
  call assert_equal(repeat(['queued'], 3), map(copy(vim_dojo#Task().expected), 'matchstr(v:val, "\"\\zs\\w\\+\\ze\"$")'))
  nunmap Q
  call vim_dojo#Start(s:Round(['pending-jobs']))
  call s:Type("ciwq.\<BS>ueued\<Esc>jciwqueued\<Esc>jciwqueued\<Esc>")
  call assert_match('Last: 34 keys · par 14 · try ', s:Panel())

  " cursor-target: a jump drill advances both steps with no check key.
  call vim_dojo#Start(s:Round(['find-loader']))
  call assert_equal([], getmatches())
  DojoCheck
  call assert_match('Move the cursor onto the definition', s:Panel())
  call s:Type("?^func loadItems\r")
  call assert_match('Found the definition', s:Panel())
  call s:Type("\<C-O>")
  call assert_match('1 of 1 clean', s:Panel())
  " Typed faster than the dojo saw the first stop.
  call vim_dojo#Start(s:Round(['find-describe']))
  call s:Solve()
  call assert_match('1 of 1 clean', s:Panel())
  " A drill with a cursor target is solved when the cursor lands on it.
  let s:task = {'id': 'to-comma', 'skill': 'custom', 'ft': 'text',
        \ 'lines': ['alpha, beta'], 'expected': ['alpha, beta'], 'target': [1, 6],
        \ 'goal': 'Move to the comma.', 'keys': 'f,'}
  call vim_dojo#Start({'kind': 'free', 'technique': '', 'goals': [s:task]})
  call assert_equal([[1, 6, 1]], map(getmatches(), 'v:val.pos1'))
  call s:Type('x')
  call s:Type('f,')
  call assert_match('differs', s:Panel())
  DojoReset
  call s:Type('l')
  call assert_notmatch('clean', s:Panel())
  call assert_match('Right line', s:Panel())
  call s:Type('f,')
  call assert_match('Last: 3 keys · clean', s:Panel())
  DojoClose

  " highlight: nothing where finding the text is the exercise, or when off.
  call vim_dojo#Start(s:Round(['catalog-string']))
  call assert_equal([], getmatches())
  let g:vim_dojo_highlight = 0
  call vim_dojo#Start(s:Round(['quoted-item']))
  call assert_equal([], getmatches())
  unlet g:vim_dojo_highlight
  DojoClose

  " nothing-raw-persisted: no state file holds any of the text typed above.
  for s:name in readdir(g:vim_dojo_state_dir)
    call assert_notmatch('ratchet\|queued\|loadItems\|ci"', join(readfile(g:vim_dojo_state_dir . '/' . s:name)))
  endfor

  " one-front-end: the shell is the only way in, and :DojoNote stays.
  call assert_equal([0, 0, 0, 0, 0, 1], map([':Dojo', ':DojoFocus', ':DojoFree', ':DojoCatalog', ':DojoLessons',
        \ ':DojoNote'], 'exists(v:val) == 2'))
  call assert_false(exists('*vim_dojo#Dojo') || exists('*vim_dojo#Focus') || exists('*vim_dojo#Free'))
  call assert_equal([], glob(s:root . '/autoload/vim_dojo/map.vim', 0, 1) + glob(s:root . '/dojo.vim', 0, 1))
  " round-length on a lesson with generators.
  call vim_dojo#Start(s:Lesson('quote', 'review'))
  for s:index in range(10)
    call assert_equal('quote', vim_dojo#Task().technique)
    call assert_match(printf('Review  i" a"  ·  %d/10', s:index + 1), s:Panel())
    DojoSkip
  endfor
  call assert_match('0 of 10 clean.*not passed', s:Panel())
  DojoClose

  " box-by-round and learn-pass: a round leaves a record of its clean count
  " and whether it passed, which the shell schedules from.
  let g:vim_dojo_state_dir = s:state . '/rounds'
  call vim_dojo#Start(s:Lesson('dot', 'learn'))
  call s:Play(7)
  call assert_match('7 of 10 clean.*not passed: 8 of 10 clean passes', s:Panel())
  call vim_dojo#Start(s:Lesson('dot', 'review'))
  call assert_match('Review  \.  ·  1/10', s:Panel())
  call assert_notmatch('Keys  ', s:Panel())
  call s:Play(8)
  call assert_equal([['learn', 7, 0], ['review', 8, 1]], s:Rounds())
  " Left early: the goals done stay in the record and no round is recorded.
  let s:clean = len(filter(s:Records(), 'v:val.result ==# "clean"'))
  call vim_dojo#Start(s:Lesson('dot', 'review'))
  call s:Solve()
  call s:Solve()
  DojoClose
  call assert_equal(s:clean + 2, len(filter(s:Records(), 'v:val.result ==# "clean"')))
  call assert_equal(2, len(s:Rounds()))

  " section-skip: a passed section review places the lessons its request
  " names; one not passed places none. The diagnostic is gone.
  let g:vim_dojo_state_dir = s:state . '/section'
  call assert_false(exists('*vim_dojo#Diagnostic') || exists('*vim_dojo#progress#Diagnostic'))
  for s:file in glob(s:root . '/autoload/**/*.vim', 0, 1) + [s:root . '/README.md']
    call assert_equal([], filter(readfile(s:file), 'v:val =~? "diagnostic"'), s:file)
  endfor
  call vim_dojo#Start(s:Section('foundations', ['modes', 'word', 'insert']))
  call assert_match('Section review  foundations  ·  1/20', s:Panel())
  call assert_notmatch('Keys  ', s:Panel())
  for s:goal in range(20)
    if s:goal < 16
      call s:Solve()
    else
      DojoSkip
    endif
  endfor
  call assert_match('16 of 20 clean.*passed', s:Panel())
  call assert_match('3 lessons placed as known', s:Panel())
  DojoClose
  call assert_equal(['insert', 'modes', 'word'], sort(map(filter(s:Records(), 'v:val.result ==# "placed"'), 'v:val.technique')))
  let g:vim_dojo_state_dir = s:state . '/section-failed'
  call vim_dojo#Start(s:Section('foundations', ['modes', 'hjkl', 'word', 'insert']))
  for s:goal in range(20)
    if s:goal < 15
      call s:Solve()
    else
      DojoSkip
    endif
  endfor
  call assert_match('15 of 20 clean.*not passed: 16 of 20 clean passes', s:Panel())
  DojoClose
  call assert_equal([], filter(s:Records(), 'v:val.result ==# "placed"'))

  " mixed-round: goals from more than one lesson with no keys shown, and a
  " round record that names no lesson, so it moves no box.
  let g:vim_dojo_state_dir = s:state . '/mixed'
  let s:goals = s:Lesson('quote', 'mixed').goals[: 1] + s:Lesson('dot', 'mixed').goals[: 1]
  call vim_dojo#Start({'kind': 'mixed', 'technique': '', 'goals': s:goals})
  call assert_match('Mixed practice  ·  1/4', s:Panel())
  call assert_notmatch('Keys  ', s:Panel())
  let s:lessons = {}
  for s:goal in range(4)
    let s:lessons[vim_dojo#Task().technique] = 1
    call s:Solve()
  endfor
  call assert_equal(['dot', 'quote'], sort(keys(s:lessons)))
  call assert_match('4 of 4 clean', s:Panel())
  call assert_notmatch('passed', s:Panel())
  DojoClose
  let s:mixed = filter(s:Records(), 'v:val.result ==# "round"')
  call assert_equal([['mixed', 'mixed', 4, 4, 0]], map(copy(s:mixed),
        \ '[v:val.id, v:val.kind, v:val.clean, v:val.goals, has_key(v:val, "technique")]'))

  " timed: at the limit the round ends where it stands, and the goal under
  " way does not count. Goals that run out first come round again.
  let g:vim_dojo_state_dir = s:state . '/timed'
  call vim_dojo#Start({'kind': 'mixed', 'technique': '', 'limit': 2, 'goals': s:goals})
  call assert_match('Mixed practice  ·  1  ·  0:0[12] left', s:Panel())
  for s:goal in range(5)
    call s:Solve()
  endfor
  call assert_match('Mixed practice  ·  6  ·', s:Panel())
  sleep 2500m
  call assert_match('5 of 5 clean  ·  0:02', s:Panel())
  DojoClose
  call assert_equal([['mixed', 5, 5]], map(filter(s:Records(), 'v:val.result ==# "round"'),
        \ '[v:val.kind, v:val.clean, v:val.goals]'))

  " A mixed round asking for more goals than it was given goes round them
  " until it has that many.
  let g:vim_dojo_state_dir = s:state . '/counted'
  call vim_dojo#Start({'kind': 'mixed', 'technique': '', 'count': 6, 'goals': s:goals})
  call assert_match('Mixed practice  ·  1/6', s:Panel())
  for s:goal in range(6)
    call s:Solve()
  endfor
  call assert_match('6 of 6 clean', s:Panel())
  DojoClose


  " Playing solutions leaves the learner's history, @:, and clipboard alone,
  " and key names cannot pass for the letters inside them.
  let g:vim_dojo_state_dir = s:state . '/isolation'
  call histadd(':', 'write /dev/null')
  call histadd('/', 'learner search')
  let s:clip = has('clipboard_working') ? getreg('+') : ''
  if has('clipboard_working')
    set clipboard=unnamedplus
  endif
  call vim_dojo#Start(s:Lesson('global', 'learn'))
  call assert_match('Learn  :g', s:Panel())
  call assert_notmatch('g/', getreg(':'))
  call vim_dojo#Start(s:Lesson('search', 'learn'))
  call assert_equal(['write /dev/null', 'learner search'], [histget(':', -1), histget('/', -1)])
  if has('clipboard_working')
    call assert_equal(s:clip, getreg('+'))
    set clipboard=
  endif
  call vim_dojo#Start({'kind': 'free', 'technique': '', 'goals': [{'id': 'line-start', 'ft': 'text',
        \ 'lines': ['total_cost = base + extra'], 'start': 'extra', 'goal': 'Move to the first column.',
        \ 'solution': '0'}]})
  let s:target = vim_dojo#Task().target
  for s:step in range(80)
    if [line('.'), col('.')] == s:target
      break
    endif
    call s:Type("\<Left>")
  endfor
  call assert_match('0 of 1 clean', s:Panel())
  call assert_match('Arrow keys', s:Panel())
  call assert_equal('unclean', s:Last().result)
  " A target that is a line is reached from any column.
  call vim_dojo#Start({'kind': 'free', 'technique': '', 'goals': [{'id': 'file-bottom', 'line': 1, 'ft': 'python',
        \ 'start': 'import', 'lines': ['import json', '', 'def load(path):', '    pass', '', 'load(None)'],
        \ 'goal': 'Move to the last line of the file.', 'solution': 'G'}]})
  call s:Type(repeat('j', 40))
  call assert_match('of 1 clean', s:Panel())
  DojoClose

  " custom-fields: new fields open with their filetype and cursor and report
  " par; a v1 file still loads; a bad file is skipped.
  let g:vim_dojo_state_dir = s:state . '/custom-state'
  call mkdir(g:vim_dojo_drill_dir, 'p')
  call writefile([json_encode({'id': 'v1-drill', 'goal': 'Replace alpha with beta',
        \ 'lines': ['alpha'], 'expected': ['beta'], 'hint': 'Change a word',
        \ 'keys': 'ciwbeta<Esc>', 'why': 'Change replaces text.'})], g:vim_dojo_drill_dir . '/v1.json')
  call writefile([json_encode({'id': 'v2-drill', 'goal': 'Rename the port', 'ft': 'python',
        \ 'start': 'port', 'skill': 'objects', 'technique': 'quote', 'solution': 'f"ci"8443<Esc>',
        \ 'lines': ['host = "local"', 'port = "8080"'], 'expected': ['host = "local"', 'port = "8443"'],
        \ 'hint': 'Change inside the quotes.', 'why': 'ci" replaces the value.'})], g:vim_dojo_drill_dir . '/v2.json')
  call writefile(['{}'], g:vim_dojo_drill_dir . '/invalid.json')
  call writefile([json_encode({'id': 'rename-variable', 'goal': 'Quote it', 'technique': 'quote',
        \ 'lines': ['x = "a"'], 'expected': ['x = "b"'], 'hint': 'Inside quotes.',
        \ 'keys': 'ci"b', 'why': 'Quotes.'})], g:vim_dojo_drill_dir . '/clash.json')
  " custom-still-loads: a custom drill joins its lesson's rounds, after the
  " generated goals, with its par shown and its solution never run. A v2
  " technique id that was renamed finds the new lesson; one that is gone
  " leaves the drill in Custom.
  let g:ran = 0
  call writefile([json_encode({'id': 'never-run', 'goal': 'Rename the host', 'technique': 'quote',
        \ 'solution': ':let g:ran = 1<CR>', 'lines': ['host = "a"'], 'expected': ['host = "b"']})],
        \ g:vim_dojo_drill_dir . '/never-run.json')
  call writefile([json_encode({'id': 'old-paren', 'goal': 'Empty it', 'technique': 'paren',
        \ 'lines': ['f(x)'], 'expected': ['f()'], 'keys': 'di('})], g:vim_dojo_drill_dir . '/paren.json')
  call writefile([json_encode({'id': 'old-gone', 'goal': 'Empty it', 'technique': 'no-such-lesson',
        \ 'lines': ['f(x)'], 'expected': ['f()'], 'keys': 'di('})], g:vim_dojo_drill_dir . '/gone.json')
  let s:by_id = {}
  for s:technique in vim_dojo#drills#Techniques()
    let s:by_id[s:technique.id] = s:technique
  endfor
  call assert_equal(1, len(filter(copy(s:by_id.bracket.drills), 'v:val.id ==# "old-paren"')))
  call assert_equal('custom', get(get(s:by_id, 'old-gone', {}), 'skill', ''))
  let s:custom = filter(copy(s:by_id.quote.drills), 'get(v:val, "custom")')
  call assert_equal(['custom-rename-variable', 'never-run', 'v2-drill'], sort(map(copy(s:custom), 'v:val.id')))
  call vim_dojo#Start({'kind': 'review', 'technique': 'quote',
        \ 'goals': repeat([{'generated': 1}], 7) + s:custom})
  for s:goal in range(10)
    if vim_dojo#Task().id ==# 'never-run'
      call assert_match('Rename the host', s:Panel())
      DojoHint
      call assert_match('Hint  : l e t', s:Panel())
    endif
    DojoSkip
  endfor
  call assert_match('try : l e t ', s:Panel())
  call assert_equal(0, g:ran)
  DojoClose
  call delete(g:vim_dojo_drill_dir . '/never-run.json')
  call vim_dojo#Start(s:Round(['v2-drill']))
  call assert_equal(['python', [2, 1]], [&l:filetype, [line('.'), col('.')]])
  call s:Type("f\"ci\"8443\<Esc>")
  call assert_match('Last: 10 keys · par 10 · clean', s:Panel())
  call assert_equal(['clean', 'quote'], [s:Last().result, s:Last().technique])
  call vim_dojo#Start(s:Round(['custom-rename-variable']))
  call s:Type("f\"ci\"b\<Esc>")
  call assert_match('Last: 7 keys · clean', s:Panel())
  call assert_equal(['clean', 'quote'], [s:Last().result, s:Last().technique])
  call vim_dojo#Start(s:Lesson('v1-drill', 'learn'))
  call assert_equal('alpha', getline(1))
  call s:Type("ciwbeta\<Esc>")
  call assert_match('2/10', s:Panel())
  call assert_match('Last: 8 keys · clean', s:Panel())
  DojoClose
  call delete(g:vim_dojo_drill_dir, 'rf')

  " inbox: a range of lines, the filetype, and the note, nothing else.
  new
  setfiletype python
  call setline(1, ['one', 'two', 'three', 'four', 'five', 'six'])
  3,5DojoNote too many keystrokes
  let s:inbox = g:vim_dojo_state_dir . '/inbox'
  call assert_equal(1, len(readdir(s:inbox)))
  let s:entry = json_decode(readfile(s:inbox . '/' . readdir(s:inbox)[0])[0])
  call assert_equal(['ft', 'lines', 'note', 'time'], sort(keys(s:entry)))
  call assert_equal(['three', 'four', 'five'], s:entry.lines)
  call assert_equal(['python', 'too many keystrokes'], [s:entry.ft, s:entry.note])
  bwipeout!

  " A blocked state directory warns, and saving resumes once it clears.
  let g:vim_dojo_state_dir = s:state . '/blocked'
  call writefile(['This file blocks the state directory.'], g:vim_dojo_state_dir)
  call vim_dojo#Start(s:Round(['quoted-item', 'shipping-status']))
  DojoSkip
  call assert_match('Progress could not be saved', s:Panel())
  call delete(g:vim_dojo_state_dir)
  call s:Solve()
  call assert_notmatch('Progress could not be saved', s:Panel())
  call assert_equal(2, len(readdir(g:vim_dojo_state_dir)))
  DojoClose

  " variants-differ and solutions-valid: every drill, and several variants of
  " every template, solved by typing its own solution, clean at par.
  let g:vim_dojo_state_dir = s:state . '/solutions'
  let s:only = $DOJO_SKILL
  for s:technique in vim_dojo#drills#Techniques()
    if !empty(s:only) && s:technique.skill !=# s:only
      continue
    endif
    " scenario-width: a lesson that relies on scenarios has four or more.
    if has_key(s:technique, 'page') && !has_key(s:technique, 'generators')
      call assert_true(len(s:technique.drills) >= 4, s:technique.id . ' needs four scenarios')
    endif
    for s:drill in s:technique.drills
      if has_key(s:drill, 'vars')
        let s:first = vim_dojo#drills#Instance(s:drill)
        let s:differs = 0
        for s:attempt in range(30)
          let s:other = vim_dojo#drills#Instance(s:drill)
          let s:differs = s:differs || s:other.lines !=# s:first.lines || s:other.goal !=# s:first.goal
        endfor
        call assert_true(s:differs, s:drill.id . ' variants differ')
      endif
      for s:attempt in range(has_key(s:drill, 'vars') ? 4 : 1)
        call vim_dojo#Start({'kind': 'free', 'technique': s:technique.id, 'goals': [s:drill]})
        let s:task = vim_dojo#Task()
        call s:Solve()
        call assert_match(printf('Last: %d keys · par %d · clean', s:task.par, s:task.par), s:Panel(),
              \ s:drill.id . ' ' . string(get(s:task, 'variant', {})))
      endfor
    endfor
  endfor
  DojoClose

  " snippet-set: at least 24 snippets of 20 to 40 lines across six kinds.
  let s:snippets = vim_dojo#drills#Snippets()
  call assert_true(len(s:snippets) >= 24, len(s:snippets) . ' snippets')
  call assert_equal([], map(filter(copy(s:snippets), 'len(v:val.lines) < 20 || len(v:val.lines) > 40'), 'v:val.name'))
  call assert_equal(['config', 'go', 'html', 'markdown', 'python', 'typescript'],
        \ uniq(sort(map(copy(s:snippets), 'index(["yaml", "toml", "json"], v:val.ft) >= 0 ? "config" : v:val.ft'))))
  let s:generated = filter(vim_dojo#drills#Techniques(), 'has_key(v:val, "generators")')

  " targets-from-vim and no-short-walk: on every snippet a lesson is offered,
  " a round of its goals is each solved clean at par by its own solution, and
  " none outside the lessons that teach them is in reach of h j k l x.
  let g:vim_dojo_state_dir = s:state . '/generated'
  for s:lesson in s:generated
    let s:walks = !empty(filter(flattennew(map(copy(s:lesson.keys), 'split(v:val[0])')),
          \ 'index(["h", "j", "k", "l", "x"], v:val) >= 0'))
    let s:suits = vim_dojo#drills#Suits(s:lesson, 10)
    call assert_true(len(s:suits) >= 2, s:lesson.id . ' has too few snippets')
    for s:snippet in s:suits
      call vim_dojo#Start({'kind': 'free', 'technique': s:lesson.id,
            \ 'goals': repeat([{'generated': 1, 'snippet': s:snippet.name}], 10)})
      for s:goal in range(10)
        let s:task = vim_dojo#Task()
        let s:what = printf('%s on %s: %s from %s', s:lesson.id, s:snippet.name, s:task.solution, string(s:task.position))
        call assert_equal(s:snippet.lines, s:task.lines, s:what)
        if !s:walks
          call assert_false(s:Walkable(s:task), s:what . ' is in reach of h j k l x')
        endif
        if s:task.moves
          call assert_false(s:Early(s:task), s:what . ' reaches its target before its last key')
        endif
        call s:Solve()
        call assert_match(printf('Last: %d keys · par %d · clean', s:task.par, s:task.par), s:Panel(), s:what)
      endfor
    endfor
  endfor

  " hop: a cursor lesson keeps the text and starts each goal where the last
  " one's target was.
  call vim_dojo#Start({'kind': 'free', 'technique': 'word', 'goals': repeat([{'generated': 1}], 10)})
  let s:tick = b:changedtick
  let s:previous = vim_dojo#Task()
  for s:goal in range(9)
    call s:Solve()
    let s:task = vim_dojo#Task()
    call assert_equal(s:previous.target, s:task.position)
    call assert_equal(s:task.position, [line('.'), col('.')])
    call assert_equal(s:tick, b:changedtick)
    let s:previous = s:task
  endfor
  DojoClose

  " generated-goal: a quotes goal highlights one string in a snippet of 20
  " lines or more and asks for a change; ci", the new text, and <Esc> solve it
  " clean. Its first learn round demonstrates the first goal.
  let g:vim_dojo_state_dir = s:state . '/generated-goal'
  let s:changed = 0
  for s:round in range(3)
    call vim_dojo#Start(s:Lesson('quote', 'learn', !s:round))
    for s:goal in range(10)
      let s:task = vim_dojo#Task()
      if !has_key(s:task, 'snippet')
        DojoSkip
        continue
      endif
      call assert_true(line('$') >= 20)
      call assert_equal(1, len(getmatches()))
      let s:mark = searchpos(getmatches()[0].pattern, 'nw')
      let s:string = matchstr(getline(s:mark[0]), '^"[^"]*"', s:mark[1] - 1)
      call assert_equal(line('.'), s:mark[0])
      call assert_true(!empty(s:string) && s:mark[1] <= col('.') && col('.') < s:mark[1] + len(s:string), s:string)
      let s:text = matchstr(s:task.goal, '^Change the highlighted string to "\zs.*\ze"\.$')
      if empty(s:text)
        DojoSkip
        continue
      endif
      let s:changed += 1
      call s:Type('ci"' . s:text . "\<Esc>")
      call assert_match('Last: \d\+ keys · par \d\+ · clean', s:Panel())
    endfor
    if s:changed
      break
    endif
  endfor
  call assert_true(s:changed > 0)

  " goals-differ: two rounds on one lesson do not give the same ten goals.
  let s:rounds = []
  for s:round in range(2)
    call vim_dojo#Start(s:Lesson('quote', 'review'))
    let s:goals = []
    for s:goal in range(10)
      call add(s:goals, [vim_dojo#Task().lines, vim_dojo#Task().position, vim_dojo#Task().solution])
      DojoSkip
    endfor
    call add(s:rounds, s:goals)
  endfor
  call assert_notequal(s:rounds[0], s:rounds[1])
  DojoClose

  " Real typing in a hidden terminal, where the main loop raises TextChanged
  " and CursorMoved and the demo runs on its timer.
  if has('terminal')
    let g:vim_dojo_state_dir = s:state . '/terminal'
    let s:vim = [v:progpath, '-Nu', 'NONE', '-i', 'NONE', '-n',
          \ '--cmd', 'set runtimepath^=' . escape(s:root, '\, '), '--cmd', 'runtime plugin/vim_dojo.vim',
          \ '--cmd', 'let g:vim_dojo_state_dir = ' . string(g:vim_dojo_state_dir),
          \ '--cmd', 'let g:vim_dojo_demo_delay = 30']
    " g:Learn starts a learn round of two goals on one drill, demonstrating
    " the first, as the shell does for a lesson never practised.
    let s:term = term_start(s:vim + ['--cmd', 'let g:Learn = {lesson, id -> vim_dojo#Start({"kind": "learn",'
          \   . ' "technique": lesson, "demo": 1, "goals": repeat(filter(flattennew(map(vim_dojo#drills#Techniques(),'
          \   . ' "v:val.drills")), {_, drill -> drill.id ==# id}), 2)})}'],
          \ {'hidden': 1, 'term_rows': 30, 'term_cols': 80})
    call s:Typed(":call g:Learn('quote', 'quoted-item')\r", 'Watch')
    call s:Typed('', 'Change the first item')
    call assert_notmatch('Watch', s:Typed('', '\\h Hint'))
    call s:Typed('x', 'differs')
    call assert_notmatch('differs', s:Typed('\r', 'Item("widget"'))
    call s:Typed("ci\"ratchet\<Esc>", 'Last: 11 keys · par 11 · clean')
    call s:Typed('', '2/2')
    call s:Typed(":call g:Learn('jumplist', 'find-loader')\r", 'Watch')
    call s:Typed('', 'loadItems')
    call s:Typed('', '\\h Hint')
    call s:Typed("?^func loadItems\r", 'Found the definition')
    call s:Typed("\<C-O>", 'Last: 18 keys · par 18 · clean')
    " Insert mode at the end of a demo is left, and a typed . there is text.
    call s:Typed(":call g:Learn('dot', 'pending-jobs')\r", 'Watch')
    call term_sendkeys(s:term, 'i')
    call assert_notmatch('-- INSERT --', s:Typed('', '\\h Hint'))
    call s:Typed("ciwq.\<BS>ueued\<Esc>jciwqueued\<Esc>jciwqueued\<Esc>", 'Last: 34 keys · par 14 · try')
    call term_sendkeys(s:term, ":qa!\r")
    call term_wait(s:term, 100)
    execute 'bwipeout!' s:term

    " shell-round, from the runner's side: vim_dojo#Run plays the request in
    " the state directory, leaves out a drill that no longer loads, records
    " the round there, and quits Vim on Enter at the summary.
    let s:run = s:state . '/run'
    call mkdir(s:run, 'p')
    call writefile([json_encode({'kind': 'review', 'technique': 'quote', 'demo': v:false, 'place': [],
          \ 'drills': s:state . '/no-drills', 'goals': [{'lesson': 'quote', 'drill': 'quoted-item'},
          \ {'lesson': 'quote', 'drill': 'gone'}]})], s:run . '/round.json')
    let s:term = term_start(s:vim + ['-c', 'call vim_dojo#Run(' . string(s:run . '/round.json') . ')'],
          \ {'hidden': 1, 'term_rows': 30, 'term_cols': 80})
    call s:Typed('', 'Review  i" a"  ·  1/1')
    call s:Typed("ci\"ratchet\<Esc>", '1 of 1 clean')
    call s:Typed("\r", '')
    for s:attempt in range(40)
      if term_getstatus(s:term) =~# 'finished'
        break
      endif
      call term_wait(s:term, 50)
    endfor
    call assert_match('finished', term_getstatus(s:term))
    let g:vim_dojo_state_dir = s:run
    call assert_equal([['review', 1, 1]], s:Rounds())
    execute 'bwipeout!' s:term
  endif
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
