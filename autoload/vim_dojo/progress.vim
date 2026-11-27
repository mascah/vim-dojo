" Writes records to the state directory. The shell reads them to schedule
" lessons; nothing here plans.
let s:cache_dir = ''
let s:pending = {}
let s:attempt = 0

function! vim_dojo#progress#Directory() abort
  let home = empty($XDG_STATE_HOME) ? expand('~/.local/state') : $XDG_STATE_HOME
  let default = empty($VIM_DOJO_STATE_DIR) ? home . '/vim-dojo' : $VIM_DOJO_STATE_DIR
  let dir = expand(get(g:, 'vim_dojo_state_dir', default))
  if dir !=# s:cache_dir
    let s:cache_dir = dir
    let s:pending = {}
  endif
  return dir
endfunction

function! vim_dojo#progress#Attempt() abort
  let s:attempt += 1
  return printf('%012d-%010d-%06d.json', localtime(), getpid(), s:attempt)
endfunction

" A goal record holds the drill id, lesson, result, key count, and
" seconds; a round record the lesson, kind, clean count, goals, whether
" it passed, and seconds. Never the keys themselves. A record that could not
" be written is tried again with the next.
function! vim_dojo#progress#Record(attempt, record) abort
  let dir = vim_dojo#progress#Directory()
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

" Friction inbox: one file per note under inbox/ in the state directory.
function! vim_dojo#progress#Note(lines, ft, note) abort
  let dir = vim_dojo#progress#Directory() . '/inbox'
  let path = dir . '/' . vim_dojo#progress#Attempt()
  let entry = {'time': localtime(), 'ft': a:ft, 'note': a:note, 'lines': a:lines}
  return s:Write(path, entry) ? path : ''
endfunction
