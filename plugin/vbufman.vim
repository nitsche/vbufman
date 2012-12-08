if exists('g:loaded_vbufman')
	finish
endif
let g:loaded_vbufman = 1



" Section: Global plugin variables {{{1
if !exists('g:vbufman_mapping') || empty(g:vbufman_mapping)
	let g:vbufman_mapping = '<C-B>'
endif

if !exists('g:vbufman_show_hidden')
	let g:vbufman_show_hidden = 0
endif

if !exists('g:vbufman_split_vertical')
	let g:vbufman_split_vertical = 0
endif

if !exists('g:vbufman_max_window_size') || g:vbufman_max_window_size < 1
	let g:vbufman_max_window_size = 10
endif

if !exists('g:vbufman_list_marker')
	let g:vbufman_list_marker = "\u25ba "
endif

if !exists('g:vbufman_prompt_prefix')
	let g:vbufman_prompt_prefix = '> '
endif





"}}}1

com! -nargs=? Bufman  call vbufman#start(<f-args>)
sil! exe 'nnoremap <silent> '.g:vbufman_mapping.' :Bufman<CR>'

call vbufman#init()

" vim:fen:fdm=marker:fmr={{{,}}}
