if exists('g:loaded_vim_dojo')
  finish
endif
let g:loaded_vim_dojo = 1
command! Dojo call vim_dojo#Start()
command! DojoFree call vim_dojo#catalog#Random()
command! DojoCatalog call vim_dojo#catalog#Open()
command! DojoLessons call vim_dojo#catalog#Lessons()
