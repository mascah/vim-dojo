let s:special = '<\%(lt\|Esc\|CR\|BS\|Tab\|Up\|Down\|Left\|Right\|C-[^>]\+\)>'
let s:root = expand('<sfile>:p:h:h:h')
let s:filetypes = {'go': 'go', 'py': 'python', 'ts': 'typescript', 'html': 'html', 'md': 'markdown',
      \ 'yaml': 'yaml', 'toml': 'toml', 'json': 'json'}
let s:snippets = []
let s:lessons = []
" v2 technique ids whose lesson took another id. A custom drill that names
" one joins the new lesson.
let s:renamed = {'counts': 'count-lines', 'join': 'line-ops', 'paren': 'bracket', 'brace': 'bracket',
      \ 'insert-at': 'insert-line', 'put': 'yank-put'}

function! s:Outline() abort
  return json_decode(join(readfile(s:root . '/lessons/outline.json'), "\n"))
endfunction

" Every lesson in outline order, each with its scenarios as `drills`.
" Custom drills join their declared lesson, or stand as a lesson of their own.
function! vim_dojo#drills#Lessons() abort
  if empty(s:lessons)
    let s:lessons = s:Read()
  endif
  let lessons = deepcopy(s:lessons)
  let by_id = {}
  for lesson in lessons
    let by_id[lesson.id] = lesson
  endfor
  for drill in s:Custom(lessons)
    if has_key(drill, 'lesson')
      let drill.section = by_id[drill.lesson].section
      call add(by_id[drill.lesson].drills, drill)
    else
      call add(lessons, {'id': drill.id, 'title': drill.id, 'keys': [],
            \ 'section': 'custom', 'custom': 1, 'drills': [drill]})
    endif
  endfor
  return lessons
endfunction

function! s:Read() abort
  let lessons = []
  for section in s:Outline()
    for id in section.lessons
      let lesson = vim_dojo#drills#Lesson(s:root . '/lessons/' . id . '.md')
      let lesson.section = section.id
      for drill in lesson.drills
        call extend(drill, {'section': section.id, 'lesson': id})
      endfor
      call add(lessons, lesson)
    endfor
  endfor
  return lessons
endfunction

" A lesson file is its page in Markdown, ending with one ```json block that
" holds the lesson: id, title, keys as [key, what it does] pairs, and its
" generators and scenarios. The page is everything above that block.
function! vim_dojo#drills#Lesson(path) abort
  let lines = readfile(a:path)
  let open = len(lines) - 1 - match(reverse(copy(lines)), '^```json\s*$')
  let close = match(lines, '^```\s*$', open + 1)
  if open >= len(lines) || close < 0 || !empty(filter(lines[close + 1 :], 'v:val =~# "\\S"'))
    throw 'Vim Dojo: ' . a:path . ' does not end with one ```json block'
  endif
  let lesson = json_decode(join(lines[open + 1 : close - 1], "\n"))
  let page = lines[: open - 1]
  while !empty(page) && page[-1] !~# '\S'
    call remove(page, -1)
  endwhile
  return extend(lesson, {'page': page, 'drills': get(lesson, 'scenarios', [])})
endfunction

" Fills a drill's template variables and works out everything that can be
" known before the drill is played: start cursor, solution keys and par.
function! vim_dojo#drills#Instance(drill) abort
  let task = deepcopy(a:drill)
  if has_key(task, 'vars')
    let pick = s:Variant(task.vars)
    let task.variant = pick
    call remove(task, 'vars')
    call map(task, {_, field -> s:Fill(field, pick)})
  endif
  let task.position = has_key(task, 'start') ? s:Position(task.lines, task.start) : [1, 1]
  if has_key(task, 'solution')
    let task.tokens = vim_dojo#drills#Tokens(task.solution)
    let task.par = len(task.tokens)
  endif
  if has_key(task, 'find')
    let task.destination = s:Position(task.lines, task.find)[0]
  endif
  " Marks a scenario sets before it starts, by name and the text they sit on.
  if has_key(task, 'marked')
    call map(task.marked, {_, anchor -> s:Position(task.lines, anchor)})
  endif
  if type(get(task, 'target')) == v:t_string
    let task.target = s:Position(task.lines, task.target)
  endif
  return task
endfunction

" One value for each variable. A value that is a dict sets several at once.
function! s:Variant(vars) abort
  let pick = {}
  for [name, values] in items(a:vars)
    let value = s:Pick(values)
    if type(value) == v:t_dict
      call extend(pick, value)
    else
      let pick[name] = value
    endif
  endfor
  return pick
endfunction

function! s:Pick(list) abort
  return empty(a:list) ? {} : a:list[rand() % len(a:list)]
endfunction

" Realistic text that generated goals are placed on, one snippet per file,
" its filetype taken from the extension.
function! vim_dojo#drills#Snippets() abort
  if empty(s:snippets)
    let dir = s:root . '/snippets'
    let names = readdir(dir, {name -> has_key(s:filetypes, fnamemodify(name, ':e'))})
    let s:snippets = map(names, {_, name -> {'name': name,
          \ 'ft': s:filetypes[fnamemodify(name, ':e')], 'lines': readfile(dir . '/' . name)}})
  endif
  return deepcopy(s:snippets)
endfunction

" The snippets a lesson is offered: those of its filetypes, and for a lesson
" that edits, only those where its generators find at least `count` places.
function! vim_dojo#drills#Suits(lesson, count) abort
  let filetypes = get(a:lesson, 'snippets', [])
  return filter(vim_dojo#drills#Snippets(), {_, snippet -> (empty(filetypes) || index(filetypes, snippet.ft) >= 0)
        \ && (get(a:lesson, 'moves') || s:Count(a:lesson, snippet.lines) >= a:count)})
endfunction

function! s:Count(lesson, lines) abort
  let places = {}
  for generator in a:lesson.generators
    for place in matchstrlist(a:lines, generator.at)
      let places[place.idx . ':' . place.byteidx] = 1
    endfor
  endfor
  return len(places)
endfunction

" Draws one goal from a lesson's generators on a snippet, not yet played, so
" its target is still unknown. An edit starts in a place its generator's `at`
" pattern matches, which is highlighted. A cursor lesson starts at `from`, or
" on any non-blank character when that is empty, and its `at` place, on the
" `side` of the cursor if one is given, only fills in the keys: {0} is the
" place's text and {1} to {9} its submatches. Returns {} when no place fits.
" An edit never draws a generator's place listed in `tried`, and adds the one
" it draws, so a round runs out of places rather than drawing them again.
function! vim_dojo#drills#Draw(lesson, snippet, from, tried) abort
  let generator = s:Pick(a:lesson.generators)
  let moves = get(a:lesson, 'moves', v:false)
  let places = has_key(generator, 'at') ? matchstrlist(a:snippet.lines, generator.at, {'submatches': v:true}) : []
  let Key = {place -> generator.keys . ' ' . place.idx . ':' . place.byteidx}
  if !moves
    call filter(places, {_, place -> !has_key(a:tried, Key(place))})
  endif
  if moves
    let from = !empty(a:from) ? a:from : s:Start(s:Pick(matchstrlist(a:snippet.lines, '\S')), 'first')
    let side = get(generator, 'side', '')
    call filter(places, {_, place -> empty(side) || place.idx + 1 == from[0] && (side ==# 'after'
          \ ? place.byteidx + 1 > from[1] : place.byteidx + len(place.text) < from[1])})
  endif
  let place = s:Pick(places)
  if has_key(generator, 'at') && empty(place)
    return {}
  endif
  if !moves
    let a:tried[Key(place)] = 1
  endif
  let pick = s:Variant(get(generator, 'vars', {}))
  if !empty(place)
    call extend(pick, {'0': place.text})
    for index in range(1, 9)
      let pick[index] = place.submatches[index - 1]
    endfor
  endif
  let task = {'id': a:lesson.id . '-generated', 'lesson': a:lesson.id, 'section': a:lesson.section,
        \ 'ft': a:snippet.ft, 'snippet': a:snippet.name, 'lines': a:snippet.lines, 'moves': moves,
        \ 'solution': s:Fill(generator.keys, pick),
        \ 'goal': s:Fill(get(generator, 'goal', 'Move onto the highlighted character.'), pick)}
  let task.tokens = vim_dojo#drills#Tokens(task.solution)
  let task.par = len(task.tokens)
  if moves
    let task.position = from
  else
    let task.position = s:Start(place, get(generator, 'cursor', 'inside'))
    let task.place = [place.idx + 1, place.byteidx + 1, place.text]
    let task.marks = [printf('\%%%dl\%%%dc\V%s', place.idx + 1, place.byteidx + 1, escape(place.text, '\'))]
  endif
  return task
endfunction

" A cursor position on a place's first, last, or any character.
function! s:Start(place, where) abort
  let chars = strchars(a:place.text)
  let char = a:where ==# 'first' || !chars ? 0 : a:where ==# 'last' ? chars - 1 : rand() % chars
  return [a:place.idx + 1, a:place.byteidx + byteidx(a:place.text, char) + 1]
endfunction

function! s:Fill(field, pick) abort
  if type(a:field) == v:t_list
    return map(copy(a:field), {_, item -> s:Fill(item, a:pick)})
  elseif type(a:field) == v:t_dict
    let filled = {}
    for [key, value] in items(a:field)
      let filled[s:Fill(key, a:pick)] = s:Fill(value, a:pick)
    endfor
    return filled
  elseif type(a:field) != v:t_string
    return a:field
  endif
  return substitute(a:field, '{\(\w\+\)}',
        \ '\=has_key(a:pick, submatch(1)) ? a:pick[submatch(1)] : submatch(0)', 'g')
endfunction

function! s:Position(lines, anchor) abort
  for index in range(len(a:lines))
    let column = stridx(a:lines[index], a:anchor)
    if column >= 0
      return [index + 1, column + 1]
    endif
  endfor
  throw 'Missing drill anchor: ' . a:anchor
endfunction

" Solutions are written in key notation, such as ci"ratchet<Esc>. A literal
" < in the text is written <lt>.
function! vim_dojo#drills#Tokens(keys) abort
  let tokens = []
  let rest = a:keys
  while !empty(rest)
    let token = matchstr(rest, '^\%(' . s:special . '\|.\)')
    call add(tokens, token)
    let rest = strpart(rest, len(token))
  endwhile
  return tokens
endfunction

function! vim_dojo#drills#Raw(tokens) abort
  return join(map(copy(a:tokens), {_, token -> token =~# '^' . s:special . '$'
        \ ? eval('"\' . token . '"') : token}), '')
endfunction

function! vim_dojo#drills#Show(tokens) abort
  return join(map(copy(a:tokens), {_, token -> token ==# '<lt>' ? '<' : token =~# '^\%( \|<Space>\)$' ? '␣' : token}))
endfunction

let s:codes = {}

" Turns each key name such as <Left> into one character, so a pattern like
" [hjkl] over typed keys cannot match the l inside it.
function! vim_dojo#drills#Code(text) abort
  return substitute(a:text, '<[A-Za-z][-A-Za-z0-9]*>', '\=s:Code(submatch(0))', 'g')
endfunction

function! s:Code(name) abort
  if !has_key(s:codes, a:name)
    let s:codes[a:name] = nr2char(0xE000 + len(s:codes))
  endif
  return s:codes[a:name]
endfunction

function! s:Custom(lessons) abort
  let dir = expand(get(g:, 'vim_dojo_drill_dir', empty($VIM_DOJO_DRILL_DIR) ? '~/.vim/vim-dojo/drills' : $VIM_DOJO_DRILL_DIR))
  if !isdirectory(dir)
    return []
  endif
  let ids = []
  let known = {}
  for lesson in a:lessons
    let known[lesson.id] = lesson.section
    call extend(ids, map(copy(lesson.drills), {_, drill -> drill.id}))
  endfor
  let builtin = copy(ids)
  let drills = []
  for name in readdir(dir, {name -> name =~# '\.json$'})
    try
      let task = json_decode(join(readfile(dir . '/' . name), "\n"))
      if type(task) != v:t_dict
        throw 'Not an object'
      endif
      " v2 files also carry hint and why, which are no longer shown.
      let required = ['id', 'goal'] + (has_key(task, 'solution') ? [] : ['keys'])
      for field in required + ['keys', 'ft', 'start', 'skill', 'technique', 'solution', 'target']
        if (index(required, field) >= 0 || has_key(task, field)) && (type(get(task, field)) != v:t_string
              \ || empty(task[field]) || task[field] =~# '[[:cntrl:]]')
          throw 'Invalid ' . field
        endif
      endfor
      if type(get(task, 'id')) == v:t_string && (index(builtin, task.id) >= 0 || has_key(known, task.id))
        " A built-in added since this file was written took the name.
        let task.id = 'custom-' . task.id
      endif
      if task.id !~# '^[a-z0-9-]\+$' || index(ids, task.id) >= 0 || has_key(known, task.id)
        throw 'Invalid or duplicate id'
      endif
      if get(task, 'ft', 'text') !~# '^\w\+$'
        throw 'Unknown ft'
      endif
      for field in ['lines'] + (has_key(task, 'target') ? [] : ['expected'])
        if type(get(task, field)) != v:t_list || empty(task[field])
              \ || !empty(filter(copy(task[field]), {_, line -> type(line) != v:t_string || line =~# '[\r\n]'}))
          throw 'Invalid ' . field
        endif
      endfor
      if !has_key(task, 'target') && task.lines ==# task.expected
        throw 'Expected buffer must differ'
      endif
      " v2 files may name a skill, which no longer places them.
      let clean = {'custom': 1, 'ft': 'text', 'section': 'custom'}
      for field in ['id', 'goal', 'keys', 'lines', 'expected', 'ft', 'start', 'solution', 'target']
        if has_key(task, field)
          let clean[field] = task[field]
        endif
      endfor
      " A file names its lesson as `technique`; one that is no lesson's leaves
      " the drill in Custom.
      let named = get(s:renamed, get(task, 'technique', ''), get(task, 'technique', ''))
      if has_key(known, named)
        let clean.lesson = named
      endif
      if !has_key(clean, 'keys')
        let clean.keys = clean.solution
      endif
      if has_key(clean, 'target')
        let clean.expected = copy(clean.lines)
      endif
      call vim_dojo#drills#Instance(clean)
      call add(drills, clean)
      call add(ids, clean.id)
    catch
      echomsg 'Vim Dojo skipped ' . name . ' (' . v:exception . ')'
    endtry
  endfor
  return drills
endfunction
