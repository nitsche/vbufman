
" Section: Script local variables {{{1
let s:tracked_bufs = []
let s:bufnum = -1
let s:maxwinsize = g:vbufman_max_window_size
let s:filter = {}
let s:bufname = 'Bufman'
let s:marker = g:vbufman_list_marker
let s:nomatches = '** NO MATCHES **'





" }}}1

" Section: Public functions {{{1
fu vbufman#init()
	aug vbufman
		au!
		au BufAdd,BufEnter * call s:trackbuf(str2nr(expand('<abuf>', 1)))
		au BufWipeout      * call s:rmbuf(str2nr(expand('<abuf>', 1)))
	aug end
endf


fu vbufman#start(...)
	let s:filter = s:new_filter(s:tracked_bufs)
	if a:0 > 0
		call s:filter.set_input(a:1)
	endif
	call s:create_window()
	call s:update()
	while s:bufnum > 0
		call s:process_input(s:getch())
	endwhile
endf


fu vbufman#stop()
	call s:destroy_window()
	call s:clear_prompt()
	let s:filter = {}
endf





" }}}1

" Section: Classes {{{1
" Class: Filter {{{2
fu s:new_filter(buffers)
	let l:filt = {}
	" attributes
	let l:filt._inp = ''
	let l:filt._rx = ['']
	let l:filt._allbufs = a:buffers
	let l:filt._bufs = copy(a:buffers)
	" methods
	let l:filt.get_input = function('s:__filter_get_input')
	let l:filt.set_input = function('s:__filter_set_input')
	let l:filt.add_input = function('s:__filter_add_input')
	let l:filt.rm_last_input = function('s:__filter_rm_last_input')
	let l:filt.regex = function('s:__filter_regex')
	let l:filt.buffers = function('s:__filter_buffers')
	let l:filt.update = function('s:__filter_update')
	return l:filt
endf



fu s:__filter_get_input() dict
	return self._inp
endf

fu s:__filter_set_input(inp) dict
	let l:parts = split(a:inp, '[/\\]')
	let self._inp = a:inp
	let self._rx = [s:__filter_to_regex(l:parts[0])]
	if len(l:parts) > 1
		for l:idx in range(1, len(l:parts)-2)
			call add(self._rx, '[^/\\]*'.s:__filter_to_regex(l:parts[l:idx]))
		endfor
		call add(self._rx, empty(l:parts[-1]) ? '' : '[^/\\]'.s:__filter_to_regex(l:parts[-1]))
	endif
	call self.update()
endf

fu s:__filter_add_input(inp) dict
	if empty(a:inp)
		return 1
	elseif a:inp =~# '^[/\\]$'
		call add(self._rx, '')
	elseif s:__filter_valid_fname(a:inp)
		let self._rx[-1] .= (len(self._rx) > 1 && empty(self._rx[-1]) ? '[^/\\]*' : '').s:__filter_to_regex(a:inp)
	else
		return 0
	endif
	let self._inp .= a:inp
	let l:rx = self.regex()
	call filter(self._bufs, 's:__filter_matchbuf(v:val, l:rx)')
	return 1
endf

fu s:__filter_rm_last_input() dict
	if self._inp =~# '[/\\]$'
		let self._inp = substitute(self._inp, '[/\\]$', '', '')
		call remove(self._rx, -1)
	else
		let self._inp = substitute(self._inp, '.$', '', '')
		if len(self._rx) == 1
			let self._rx[0] = s:__filter_to_regex(self._inp)
		else
			let l:part = strpart(self._inp, match(self._inp, '[/\\]', 0, len(self._rx)-1) + 1)
			let self._rx[-1] = empty(l:part) ? '' : '[^/\\]*'.s:__filter_to_regex(l:part)
		endif
	endif
	call self.update()
endf

fu s:__filter_regex() dict
	return join(self._rx, '[^/\\]*[/\\]')
endf

fu s:__filter_buffers() dict
	return self._bufs
endf

fu s:__filter_update() dict
	let l:rx = self.regex()
	let self._bufs = []
	for l:buf in self._allbufs
		if s:__filter_matchbuf(l:buf, l:rx)
			call add(self._bufs, l:buf)
		endif
	endfor
endf


fu s:__filter_valid_fname(str)
	return a:str =~# '^[^/\\%:]*$'
endf

fu s:__filter_matchbuf(buf, rx)
	if a:buf == s:bufnum
		return 0
	elseif !g:vbufman_show_hidden && !buflisted(a:buf)
		return 0
	else
		let l:name = bufname(a:buf)
		return !empty(l:name) && l:name =~ a:rx
	endif
endf

fu s:__filter_to_regex(str)
	let l:rx = substitute(a:str, '^[*?]\+', '', '')
	let l:rx = substitute(l:rx, '[*?]\+$', '', '')
	let l:rx = substitute(l:rx, '?', '[^/\\]', 'g')
	let l:rx = substitute(l:rx, '\*', '[^/\\]*', 'g')
	return escape(l:rx, '^$.\~[]')
endf





" }}}2
" }}}1

" Section: Private functions {{{1
fu s:trackbuf(bufnum)
	if a:bufnum <= 0 || empty(bufname(a:bufnum))
		return
	elseif empty(s:tracked_bufs) || s:tracked_bufs[-1] != a:bufnum
		call s:rmbuf(a:bufnum)
		call add(s:tracked_bufs, a:bufnum)
	endif
endf


fu s:rmbuf(bufnum)
	let l:idx = index(s:tracked_bufs, a:bufnum)
	if l:idx >= 0
		call remove(s:tracked_bufs, l:idx)
	endif
endf


fu s:create_window()
	sil! exe 'botright 1new '.s:bufname
	" buffer options
	abc <buffer>
	setl noswapfile
	setl buftype=nofile
	setl bufhidden=wipe
	setl nobuflisted
	setl winfixheight
	setl nonumber
	setl nowrap
	setl nospell
	setl cursorline
	setl nocursorcolumn
	setl nomodifiable
	let &l:statusline = s:bufname
	let s:bufnum = bufnr('%')

	if s:has_syntax()
		call s:def_syntax()
	endif
endf


fu s:destroy_window()
	sil! exe 'bwipe! '.s:bufnum
	let s:bufnum = -1
endf


fu s:paint_prompt()
	redraw
	echo g:vbufman_prompt_prefix.s:filter.get_input()
endf


fu s:clear_prompt()
	redraw
	echo ''
endf


fu s:update()
	let l:lines = []
	let l:prefix = repeat(' ', strwidth(s:marker))
	for l:buf in s:filter.buffers()
		call add(l:lines, l:prefix.bufname(l:buf))
	endfor

	setl modifiable
	let l:lastln = len(l:lines)
	sil! exe '%d _'
	sil! exe 'resize '.min([l:lastln == 0 ? 1 : l:lastln, s:maxwinsize])
	if empty(l:lines)
		call setline(1, s:nomatches)
	else
		call setline(1, l:lines)
	endif
	sil! exe l:lastln.'normal! zb'
	setl nomodifiable

	if s:has_syntax()
		call s:highlight()
	endif
	call s:select_line(l:lastln)
endf


fu s:has_syntax()
	return has('syntax') && exists('g:syntax_on')
endf


fu s:def_syntax()
	sil! exe 'sy match vbufmanListMarker ''^\V'.escape(s:marker, '\').''''
	sil! exe 'sy match vbufmanNoMatches  ''^\V'.escape(s:nomatches, '\').'$'''

	sil! exe 'hi link vbufmanMatch      Special'
	sil! exe 'hi link vbufmanListMarker Delimiter'
endf


fu s:highlight()
	call clearmatches()
	call matchadd('vbufmanMatch', '^.*\zs'.s:filter.regex().'\ze.*$')
endf


fu s:selected_buf()
	let l:idx = line('.') - 1
	let l:bufs = s:filter.buffers()
	return l:bufs[l:idx]
endf


fu s:select_line(line)
	if !empty(s:filter.buffers())
		let l:curln = line('.')
		let l:newln = a:line < 1 ? 1 : a:line > line('$') ? line('$') : a:line

		setl modifiable
		let l:markerwidth = strwidth(s:marker)
		call setline(l:curln, substitute(getline(l:curln), '^'.s:marker, repeat(' ', l:markerwidth), ''))
		call setline(l:newln, substitute(getline(l:newln), '^\s\{'.l:markerwidth.'}', s:marker, ''))
		call cursor(l:newln, 1)
		setl nomodifiable
	endif
	call s:paint_prompt()
endf


fu s:open_buf(buf, dosplit)
	call vbufman#stop()

	let l:cmd = !a:dosplit ? 'b' : g:vbufman_split_vertical ? 'vertical sb' : 'sb'
	exe l:cmd.' '.a:buf
endf


fu s:getch()
	try
		let l:chr = getchar()
		return type(l:chr) == type(0) ? nr2char(l:chr) : l:chr
	catch /^Vim:Interrupt$/
		return "\<Esc>"
	endtry
endf


fu s:process_input(key)
	if a:key ==? "\<Esc>" || a:key ==? "\<C-C>"
		call vbufman#stop()
		return
	elseif a:key ==? "\<Return>" || a:key ==? "\<C-Return>"
		let l:buf = s:selected_buf()
		call s:open_buf(l:buf, getcharmod() == 4)
		return
	elseif a:key ==? "\<Up>"
		call s:select_line(line('.')-1)
		return
	elseif a:key ==? "\<Down>"
		call s:select_line(line('.')+1)
		return
	elseif a:key ==? "\<BS>"
		call s:filter.rm_last_input()
		call s:update()
		return
	elseif a:key[0] !=# "\x80" && s:filter.add_input(a:key)
		call s:update()
		return
	endif
endf





" }}}1

" vim:fen:fdm=marker:fmr={{{,}}}
