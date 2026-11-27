if exists('g:loaded_vim_dojo')
  finish
endif
let g:loaded_vim_dojo = 1
" Practice starts from the dojo shell, which runs vim_dojo#Run().
command! -range -nargs=* DojoNote call vim_dojo#Note(<line1>, <line2>, <q-args>)
