let s:root = fnamemodify(expand('<sfile>:p'), ':h')
if index(split(&runtimepath, ','), s:root) < 0
  execute 'set runtimepath^=' . escape(s:root, '\, ')
endif
runtime plugin/vim_dojo.vim
Dojo
