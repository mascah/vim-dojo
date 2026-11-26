" Skills in teaching order. Each built-in skill lives in
" autoload/vim_dojo/skills/{id}.vim and returns its techniques in order.
let s:skills = [['move', 'Move'], ['edit', 'Edit'], ['objects', 'Objects'],
      \ ['repeat', 'Repeat'], ['search', 'Search and jumps'], ['visual', 'Visual'],
      \ ['registers', 'Registers and macros'], ['ex', 'Ex'], ['custom', 'Custom']]
let s:special = '<\%(lt\|Esc\|CR\|BS\|Tab\|Up\|Down\|Left\|Right\|C-[^>]\+\)>'
let s:root = expand('<sfile>:p:h:h:h')
let s:filetypes = {'go': 'go', 'py': 'python', 'ts': 'typescript', 'html': 'html', 'md': 'markdown',
      \ 'yaml': 'yaml', 'toml': 'toml', 'json': 'json'}
let s:snippets = []

function! vim_dojo#drills#Skills() abort
  return deepcopy(s:skills)
endfunction

" Every technique in curriculum order, each with its drills. Custom drills
" join their declared technique, or stand as a technique of their own.
function! vim_dojo#drills#Techniques() abort
  let techniques = []
  for [skill, _] in s:skills[: -2]
    for technique in vim_dojo#skills#{skill}#Techniques()
      let technique.skill = skill
      for drill in technique.drills
        call extend(drill, {'skill': skill, 'technique': technique.id})
      endfor
      call add(techniques, technique)
    endfor
  endfor
  let by_id = {}
  for technique in techniques
    let by_id[technique.id] = technique
  endfor
  " A lesson file adds generators to the technique of its id.
  for name in readdir(s:root . '/lessons', {name -> name =~# '\.json$'})
    let lesson = json_decode(join(readfile(s:root . '/lessons/' . name), "\n"))
    call extend(by_id[lesson.id], lesson)
  endfor
  for drill in s:Custom(techniques)
    if has_key(drill, 'technique')
      let drill.skill = by_id[drill.technique].skill
      call add(by_id[drill.technique].drills, drill)
    else
      call add(techniques, {'id': drill.id, 'keys': drill.id, 'name': drill.goal,
            \ 'skill': drill.skill, 'custom': 1, 'drills': [drill]})
    endif
  endfor
  return techniques
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
    let s:snippets = map(readdir(dir), {_, name -> {'name': name,
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
function! vim_dojo#drills#Draw(lesson, snippet, from) abort
  let generator = s:Pick(a:lesson.generators)
  let moves = get(a:lesson, 'moves', v:false)
  let places = has_key(generator, 'at') ? matchstrlist(a:snippet.lines, generator.at, {'submatches': v:true}) : []
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
  let pick = s:Variant(get(generator, 'vars', {}))
  if !empty(place)
    call extend(pick, {'0': place.text})
    for index in range(1, 9)
      let pick[index] = place.submatches[index - 1]
    endfor
  endif
  let task = {'id': a:lesson.id . '-generated', 'technique': a:lesson.id, 'skill': a:lesson.skill,
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

function! s:Custom(techniques) abort
  let dir = expand(get(g:, 'vim_dojo_drill_dir', '~/.vim/vim-dojo/drills'))
  if !isdirectory(dir)
    return []
  endif
  let ids = []
  let known = {}
  for technique in a:techniques
    let known[technique.id] = technique.skill
    call extend(ids, map(copy(technique.drills), {_, drill -> drill.id}))
  endfor
  let builtin = copy(ids)
  let skills = map(copy(s:skills), {_, skill -> skill[0]})
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
      if get(task, 'ft', 'text') !~# '^\w\+$' || has_key(task, 'technique') && !has_key(known, task.technique)
        throw 'Unknown ft or technique'
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
      let clean = {'custom': 1, 'ft': 'text', 'skill': index(skills, get(task, 'skill')) >= 0 ? task.skill : 'custom'}
      for field in ['id', 'goal', 'keys', 'lines', 'expected', 'ft', 'start', 'technique', 'solution', 'target']
        if has_key(task, field)
          let clean[field] = task[field]
        endif
      endfor
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
