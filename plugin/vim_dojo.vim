if exists('g:loaded_vim_dojo')
  finish
endif
let g:loaded_vim_dojo = 1
" KeyInputPre arrived in 9.1.0563 and its typedchar, which the key count
" relies on, in 9.1.0597.
if !has('patch-9.1.0597')
  command! Dojo echo 'Vim Dojo needs Vim 9.1.0597 or later.'
  finish
endif
command! Dojo call vim_dojo#Dojo()
command! DojoFree call vim_dojo#Free()
command! -nargs=1 -complete=customlist,vim_dojo#Complete DojoFocus call vim_dojo#Focus(<q-args>)
command! -range -nargs=* DojoNote call vim_dojo#Note(<line1>, <line2>, <q-args>)
