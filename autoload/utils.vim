
" --------------------------------------------
" map
" --------------------------------------------
let s:maps = {
      \ "\<ESC>": 'ESC',
      \ "\<CR>": 'ENTER',
      \ "\<UP>": 'UP',
      \ "\<DOWN>": 'DOWN',
      \ "\<c-j>": 'DOWN',
      \ "\<c-k>": 'UP',
      \ "\<c-n>": 'NEXT',
      \ "\<c-p>": 'PREV',
      \ "\<c-b>": 'PAGEUP',
      \ "\<c-f>": 'PAGEDOWN',
      \ "\<c-u>": 'HALFUP',
      \ "\<c-d>": 'HALFDOWN',
      \ "\<PageUp>": 'PAGEUP',
      \ "\<PageDown>": 'PAGEDOWN',
      \ }
" let s:maps["\<SPACE>"] = 'ENTER'
" let s:maps["K"] = 'PREVIEW'
" let s:maps["\<LEFT>"] = 'LEFT'
" let s:maps["\<RIGHT>"] = 'RIGHT'
" let s:maps["\<HOME>"] = 'HOME'
" let s:maps["\<END>"] = 'END'
" let s:maps["\<c-h>"] = 'LEFT'
" let s:maps["\<c-l>"] = 'RIGHT'
" let s:maps["\<c-g>"] = 'NOHL'
" let s:maps['j'] = 'DOWN'
" let s:maps['k'] = 'UP'
" let s:maps['h'] = 'LEFT'
" let s:maps['l'] = 'RIGHT'
" let s:maps['J'] = 'HALFDOWN'
" let s:maps['K'] = 'HALFUP'
" let s:maps['H'] = 'PAGEUP'
" let s:maps['L'] = 'PAGEDOWN'
" let s:maps["g"] = 'TOP'
" let s:maps["G"] = 'BOTTOM'
" let s:maps['q'] = 'ESC'
" let s:maps['n'] = 'NEXT'
" let s:maps['N'] = 'PREV'

function! registers#utils#keymap()
	return deepcopy(s:maps)
endfunc
