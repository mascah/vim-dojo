" Run from the repository root with vim -Nu NONE -i NONE -n -es -S test/dojo.vim
" Set DOJO_SKILL=move to check the solutions of one skill only.
let s:state = tempname()
let g:vim_dojo_state_dir = s:state . '/initial'
let g:vim_dojo_drill_dir = s:state . '/custom'
let g:vim_dojo_demo_delay = 0
call setline(1, 'An unsaved edit in the original window')
let s:original = bufnr('%')
let s:root = fnamemodify(expand('<sfile>:p'), ':h:h')

function! s:Panel() abort
  return join(getbufline(winbufnr(1), 1, '$'), "\n")
endfunction

function! s:Records() abort
  let dir = g:vim_dojo_state_dir
  return map(sort(readdir(dir, {name -> name =~# '\.json$'})), 'json_decode(readfile(dir . "/" . v:val)[0])')
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
  return [{'kind': get(a:, 1, 'free'), 'technique': get(goals[0], 'technique', ''), 'goals': goals}]
endfunction

function! s:Box(id) abort
  return vim_dojo#progress#State(vim_dojo#drills#Techniques())[a:id]
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
  " map-readable and map-states on a fresh state directory.
  execute 'source ' . fnameescape(s:root . '/dojo.vim')
  call assert_equal('nofile', &l:buftype)
  let s:map = getline(1, '$')
  call assert_equal([], filter(copy(s:map), 'strdisplaywidth(v:val) > 80'))
  call assert_match('○ new.*◐ shaky.*● solid.*Enter.*d diagnostic.*q close', s:map[-1])
  call assert_match('▶ Start today''s session.*learn ', getline('.'))
  call assert_match('New here', join(s:map))
  let s:skills = filter(copy(s:map), 'v:val =~# "^\\S.*of \\d\\+ solid"')
  call assert_true(len(s:skills) >= 4)
  call assert_equal([], filter(copy(s:skills), 'v:val !~# "^\\S.\\{-}  [○◐●]\\+ \\+0 of"'))
  call assert_equal([], filter(copy(s:map), 'v:val =~# "^  \\%(◐\\|●\\)"'))
  let s:rows = filter(s:map[: -2], 'v:val =~# "^  ○ "')
  call assert_true(len(s:rows) > 1)
  call assert_equal([], filter(copy(s:rows), 'v:val !~# " new\\s*$"'))
  " Enter on a closed skill opens it, and again closes it.
  let s:closed = search('^Objects ', 'n')
  let s:before = line('$')
  call cursor(s:closed, 1)
  call feedkeys("\<CR>", 'xt')
  call assert_true(line('$') > s:before)
  call assert_match('^  ○ .*new', getline(s:closed + 1))
  call feedkeys("\<CR>", 'xt')
  call assert_equal(s:before, line('$'))
  " round-length, auto-advance, keys-pinned, learn-pass: today's session on a
  " fresh state is a learn round of ten on the first technique.
  let s:first = vim_dojo#drills#Techniques()[0]
  call cursor(search('▶'), 1)
  call feedkeys("\<CR>", 'xt')
  call assert_match('Learn  ' . escape(s:first.keys, '\') . '  ·  1/10', s:Panel())
  call assert_match('Keys  ' . escape(s:first.keys, '\'), s:Panel())
  call assert_notmatch('Last:', s:Panel())
  let s:task = vim_dojo#Task()
  call assert_equal(s:task.lines, getline(1, '$'))
  call assert_equal(s:task.position, [line('.'), col('.')])
  call s:Solve()
  call assert_match('2/10', s:Panel())
  call assert_match(printf('Last: %d keys · par %d · clean', s:task.par, s:task.par), s:Panel())
  call assert_match('Keys  ' . escape(s:first.keys, '\'), s:Panel())
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
  call assert_match('◐ .*shaky\s\+due tomorrow', join(getline(1, '$'), "\n"))
  call assert_equal(vim_dojo#progress#Day(localtime()) + 1, s:Box(s:first.id).due)
  call feedkeys('q', 'xt')
  call assert_equal(s:original, bufnr('%'))
  call assert_equal('An unsaved edit in the original window', getline(1))
  call assert_true(&modified)

  " teach-first-meeting, demo-not-counted, highlight, auto-check, no-f-keys.
  call vim_dojo#Start(s:Round(['quoted-item', 'quoted-item'], 'learn'))
  call assert_match('Keys  i" a"', s:Panel())
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
  call vim_dojo#Start([{'kind': 'free', 'technique': '', 'goals': [s:task]}])
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

  " commands-removed, focus, and round-length from :DojoFocus, which reviews
  " quote now that the learn round above passed.
  call assert_equal([0, 0], [exists(':DojoCatalog'), exists(':DojoLessons')])
  DojoFree
  call assert_match('Free practice  ·  1/1', s:Panel())
  call assert_equal(0, exists(':DojoUsed'))
  DojoClose
  DojoFocus quote
  for s:index in range(10)
    call assert_equal('quote', vim_dojo#Task().technique)
    call assert_match(printf('Review  Inside or around quotes  ·  %d/10', s:index + 1), s:Panel())
    DojoSkip
  endfor
  call assert_match('0 of 10 clean.*not passed', s:Panel())
  DojoClose
  call assert_equal(['quote'], vim_dojo#Complete('quo'))

  " box-by-round and learn-pass, by playing rounds on a fresh state.
  let g:vim_dojo_state_dir = s:state . '/rounds'
  let s:today = vim_dojo#progress#Day(localtime())
  DojoFocus dot
  call s:Play(7)
  call assert_match('7 of 10 clean.*not passed, 8 clean in ten passes', s:Panel())
  call assert_equal(0, s:Box('dot').box)
  DojoFocus dot
  call assert_match('Learn', s:Panel())
  call s:Play(8)
  call assert_equal([1, s:today + 1], [s:Box('dot').box, s:Box('dot').due])
  DojoFocus dot
  call assert_match('Review  Repeat the last change  ·  1/10', s:Panel())
  call assert_notmatch('Keys  \|Make one complete edit', s:Panel())
  call s:Play(8)
  call assert_equal([2, s:today + 3], [s:Box('dot').box, s:Box('dot').due])
  DojoFocus dot
  call s:Play(7)
  call assert_equal([1, s:today + 1], [s:Box('dot').box, s:Box('dot').due])
  " Left early: the goals done stay in the record and nothing moves.
  let s:clean = len(filter(s:Records(), 'v:val.result ==# "clean"'))
  DojoFocus dot
  call s:Solve()
  call s:Solve()
  DojoClose
  call assert_equal(s:clean + 2, len(filter(s:Records(), 'v:val.result ==# "clean"')))
  call assert_equal(1, s:Box('dot').box)
  call assert_equal(4, len(filter(s:Records(), 'v:val.result ==# "round"')))

  " Today's session reviews up to three due techniques, oldest first, then
  " teaches the next new one. v2 records count for nothing.
  let g:vim_dojo_state_dir = s:state . '/schedule'
  call mkdir(g:vim_dojo_state_dir, 'p')
  let s:now = localtime()
  let s:records = [{'id': 'quoted-item', 'result': 'recalled', 'time': s:now - 9 * 86400}]
  for [s:id, s:days] in [['global', 5], ['dot', 4], ['jumplist', 3], ['substitute', 2]]
    call add(s:records, {'id': s:id, 'technique': s:id, 'result': 'round', 'kind': 'learn',
          \ 'clean': 9, 'goals': 10, 'passed': v:true, 'seconds': 60, 'time': s:now - s:days * 86400})
  endfor
  call add(s:records, extend(copy(s:records[-1]), {'kind': 'review', 'time': s:now - 86400}))
  for s:index in range(len(s:records))
    call writefile([json_encode(s:records[s:index])],
          \ printf('%s/%012d-0000000001-%06d.json', g:vim_dojo_state_dir, s:index + 1, s:index + 1))
  endfor
  let s:state_now = vim_dojo#progress#State(vim_dojo#drills#Techniques())
  call assert_equal([0, 1, 1, 2], map(['quote', 'global', 'dot', 'substitute'], 's:state_now[v:val].box'))
  call assert_equal(2, s:state_now.substitute.due - vim_dojo#progress#Day(s:now))
  let s:plan = vim_dojo#progress#Plan(vim_dojo#drills#Techniques())
  call assert_equal(['global', 'dot', 'jumplist'], map(copy(s:plan.review), 'v:val.id'))
  call assert_equal([s:first.id], map(copy(s:plan.learn), 'v:val.id'))
  call assert_equal(['review', 'review', 'review', 'learn'], map(copy(s:plan.rounds), 'v:val.kind'))
  Dojo
  call assert_match('3 due today', getline(1))
  call assert_match('review :g / \. / Ctrl-O Ctrl-I.*learn ', getline(search('▶')))
  call cursor(search('▶'), 1)
  call feedkeys("\<CR>", 'xt')
  call assert_match('Review  Run a command on matching lines  ·  round 1 of 4  ·  1/10', s:Panel())
  call assert_notmatch('Keys  ', s:Panel())
  call s:Play(0)
  call assert_match('Enter / :DojoNext  Next round', s:Panel())
  call feedkeys("\<CR>", 'xt')
  call assert_match('Review  Repeat the last change  ·  round 2 of 4  ·  1/10', s:Panel())
  call assert_notmatch('Last:', s:Panel())
  DojoClose

  " diagnostic-places: a clean goal places its technique; the rest still teach.
  let g:vim_dojo_state_dir = s:state . '/diagnostic'
  Dojo
  call feedkeys('d', 'xt')
  call assert_match('Diagnostic  ·  1/\d\+', s:Panel())
  call assert_notmatch('Keys  \|Hint', s:Panel())
  let s:placed = vim_dojo#Task().technique
  call feedkeys('\h', 'xt')
  call assert_match('No hints', s:Panel())
  call s:Solve()
  call assert_match('Diagnostic  ·  2/\d\+', s:Panel())
  call assert_match('Last: \d\+ keys · par \d\+ · clean', s:Panel())
  let s:unplaced = vim_dojo#Task().technique
  DojoSkip
  DojoClose
  call vim_dojo#Focus(s:placed)
  call assert_match('Review  ', s:Panel())
  call vim_dojo#Focus(s:unplaced)
  call assert_match('Learn  ', s:Panel())
  DojoClose
  let s:state_now = vim_dojo#progress#State(vim_dojo#drills#Techniques())
  call assert_equal([3, 0], [s:state_now[s:placed].box, s:state_now[s:unplaced].box])

  " Playing solutions leaves the learner's history, @:, and clipboard alone,
  " and key names cannot pass for the letters inside them.
  let g:vim_dojo_state_dir = s:state . '/isolation'
  call histadd(':', 'write /dev/null')
  call histadd('/', 'learner search')
  let s:clip = has('clipboard_working') ? getreg('+') : ''
  if has('clipboard_working')
    set clipboard=unnamedplus
  endif
  DojoFocus global
  call assert_match('Learn  :g', s:Panel())
  call assert_notmatch('g/', getreg(':'))
  DojoFocus search
  call assert_equal(['write /dev/null', 'learner search'], [histget(':', -1), histget('/', -1)])
  if has('clipboard_working')
    call assert_equal(s:clip, getreg('+'))
    set clipboard=
  endif
  call vim_dojo#Start(s:Round(['word-back']))
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
  call vim_dojo#Start(s:Round(['file-bottom']))
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
  call assert_match('no technique', execute('DojoFocus v2-drill'))
  call vim_dojo#Start(s:Round(['v2-drill']))
  call assert_equal(['python', [2, 1]], [&l:filetype, [line('.'), col('.')]])
  call s:Type("f\"ci\"8443\<Esc>")
  call assert_match('Last: 10 keys · par 10 · clean', s:Panel())
  call assert_equal(['clean', 'quote'], [s:Last().result, s:Last().technique])
  call vim_dojo#Start(s:Round(['custom-rename-variable']))
  call s:Type("f\"ci\"b\<Esc>")
  call assert_match('Last: 7 keys · clean', s:Panel())
  call assert_equal(['clean', 'quote'], [s:Last().result, s:Last().technique])
  DojoFocus v1-drill
  call assert_equal('alpha', getline(1))
  call s:Type("ciwbeta\<Esc>")
  call assert_match('2/10', s:Panel())
  call assert_match('Last: 8 keys · clean', s:Panel())
  DojoClose
  Dojo
  call assert_match('^Custom ', getline(search('^Custom ')))
  call feedkeys('q', 'xt')
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
  Dojo
  call assert_match('1 in inbox', getline(1))
  call assert_match('inbox', getline(3))
  call feedkeys('q', 'xt')

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
    call assert_true(len(s:technique.drills) >= 3 || !empty(filter(copy(s:technique.drills), 'has_key(v:val, "vars")')),
          \ s:technique.id . ' needs a template or three drills')
    call assert_equal(2, len(s:technique.card), s:technique.id . ' card')
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
        call vim_dojo#Start([{'kind': 'free', 'technique': s:technique.id, 'goals': [s:drill]}])
        let s:task = vim_dojo#Task()
        call s:Solve()
        call assert_match(printf('Last: %d keys · par %d · clean', s:task.par, s:task.par), s:Panel(),
              \ s:drill.id . ' ' . string(get(s:task, 'variant', {})))
      endfor
    endfor
  endfor
  DojoClose

  " Real typing in a hidden terminal, where the main loop raises TextChanged
  " and CursorMoved and the demo runs on its timer.
  if has('terminal')
    let g:vim_dojo_state_dir = s:state . '/terminal'
    let s:term = term_start([v:progpath, '-Nu', 'NONE', '-i', 'NONE', '-n',
          \ '--cmd', 'let g:vim_dojo_state_dir = ' . string(g:vim_dojo_state_dir),
          \ '--cmd', 'let g:vim_dojo_demo_delay = 30',
          \ '-S', s:root . '/dojo.vim'], {'hidden': 1, 'term_rows': 30, 'term_cols': 80})
    call s:Typed('', 'Start today')
    call s:Typed(":DojoFocus quote\r", 'Watch')
    call s:Typed('', 'Change the first item')
    call assert_notmatch('Watch', s:Typed('', '\\h Hint'))
    call s:Typed('x', 'differs')
    call assert_notmatch('differs', s:Typed('\r', 'Item("widget"'))
    call s:Typed("ci\"ratchet\<Esc>", 'Last: 11 keys · par 11 · clean')
    call s:Typed('', '2/10')
    call s:Typed(":DojoFocus jumplist\r", 'loadItems')
    call s:Typed('', '\\h Hint')
    call s:Typed("?^func loadItems\r", 'Found the definition')
    call s:Typed("\<C-O>", 'Last: 18 keys · par 18 · clean')
    " Insert mode at the end of a demo is left, and a typed . there is text.
    call s:Typed(":DojoFocus dot\r", 'Watch')
    call term_sendkeys(s:term, 'i')
    call assert_notmatch('-- INSERT --', s:Typed('', '\\h Hint'))
    call s:Typed("ciwq.\<BS>ueued\<Esc>jciwqueued\<Esc>jciwqueued\<Esc>", 'Last: 34 keys · par 14 · try')
    call term_sendkeys(s:term, ":qa!\r")
    call term_wait(s:term, 100)
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
