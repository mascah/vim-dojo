" Skills in teaching order. Each built-in skill lives in
" autoload/vim_dojo/skills/{id}.vim and returns its techniques in order.
let s:skills = [['move', 'Move'], ['edit', 'Edit'], ['objects', 'Objects'],
      \ ['repeat', 'Repeat'], ['search', 'Search and jumps'], ['visual', 'Visual'],
      \ ['registers', 'Registers and macros'], ['ex', 'Ex'], ['custom', 'Custom']]
let s:special = '<\%(lt\|Esc\|CR\|BS\|Tab\|Up\|Down\|Left\|Right\|C-[^>]\+\)>'

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
    let pick = {}
    for [name, values] in items(task.vars)
      let value = values[rand() % len(values)]
      if type(value) == v:t_dict
        call extend(pick, value)
      else
        let pick[name] = value
      endif
    endfor
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
