" --------------------------------------------
" vars
" --------------------------------------------

let s:tab_symbol           = get(g:, "registers_tab_symbol",           "·")
let s:space_symbol         = get(g:, "registers_space_symbol",         " ")
let s:return_symbol        = get(g:, "registers_return_symbol",        "⏎")
let s:register_key_sleep   = get(g:, "registers_register_key_sleep",   0)
let s:show_empty_registers = get(g:, "registers_show_empty_registers", 1)
let s:debug                = get(g:, "registers_debug",                1)

let s:logfile = "/tmp/vim_registers.log"

let s:register_map = {
      \ "selection":           ["*", "+"],
      \ "unnamed":             ["\""],
      \ "delete":              ["-"],
      \ "read-only":           [":", ".", "%"],
      \ "last search pattern": ["/"],
      \ "numbered":            ["0", "1", "2", "3", "4", "5", "7", "8", "9"],
      \ "named":               [ "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", ],
      \ "alternate buffer":    ["#"],
      \ "expression":          ["="],
      \ "black hole":          ["_"] }

let s:register_sequence = ["selection", "unnamed", "delete", "read-only", "last search pattern", "numbered", "named", "alternate buffer", "expression", "black hole"]

let s:reg_lines = []
let s:empty_reg_line = v:null
let s:empty_regs = []

let s:buf = v:null
let s:win = v:null
let s:invocation_mode = v:null
let s:operator_count = 0
let s:mappings = {}


let s:movement_keymaps = {
      \ "\<ESC>":      'ESC',
      \ "\<CR>":       'ENTER',
      \ "\<UP>":       'UP',
      \ "\<DOWN>":     'DOWN',
      \ "\<c-j>":      'DOWN',
      \ "\<c-k>":      'UP',
      \ "\<c-n>":      'NEXT',
      \ "\<c-p>":      'PREV',
      \ "\<c-b>":      'PAGEUP',
      \ "\<c-f>":      'PAGEDOWN',
      \ "\<c-u>":      'HALFUP',
      \ "\<c-d>":      'HALFDOWN',
      \ "\<PageUp>":   'PAGEUP',
      \ "\<PageDown>": 'PAGEDOWN',
      \ "G":           'BOTTOM',
      \ }

" --------------------------------------------
" funcs
" --------------------------------------------
function! s:log(msg)
  if s:debug == 1
    if type(a:msg) != v:t_string && type(a:msg) != v:t_number
      let l:msg = string(a:msg)
    else
      let l:msg = a:msg
    endif

	  if exists("*strftime")
      let l:msg = strftime("%y-%m-%d %T") .. " " .. l:msg
    endif
    call writefile([l:msg], s:logfile, "a")
  endif
endfunction

function! registers#CursorMovement(where)
	let curline = line('.')
	let endline = line('$')
	let height = winheight('.')
	if a:where == 'TOP'
		let curline = 0
	elseif a:where == 'BOTTOM'
		let curline = line('$')
	elseif a:where == 'UP'
		let curline = curline - 1
	elseif a:where == 'DOWN'
		let curline = curline + 1
	elseif a:where == 'PAGEUP'
		let curline = curline - height
	elseif a:where == 'PAGEDOWN'
		let curline = curline + height
	elseif a:where == 'HALFUP'
		let curline = curline - height / 2
	elseif a:where == 'HALFDOWN'
		let curline = curline + height / 2
	endif
	if curline < 1
		let curline = 1
	elseif curline > endline
		let curline = endline
	endif
	noautocmd exec ":" . curline
	noautocmd exec "normal! 0"
endfunc

function! s:ResetCursor()
  call cursor(0, 1)
endfunction

function! s:Round2Int(s)
  return float2nr(round(a:s))
endfunction

function! s:GetRegPreview(reg)

endfunction

function! s:EscapeContents(raw)
   let l:contents = a:raw
   let l:contents = substitute(l:contents, "\t", s:tab_symbol, "g")
   let l:contents = substitute(l:contents, " ", s:space_symbol, "g")
   let l:contents = substitute(l:contents, "[\n\r]", s:return_symbol, "g")
   return l:contents
endfunction

function! s:ReadRegisters()
  let s:empty_regs = []
  " reset ? XXX (K): <2021-07-23>
  let s:reg_lines = []

  for reg_type in s:register_sequence
    for reg in s:register_map[reg_type]
      let l:raw = getreg(reg, 1)

      if len(l:raw) > 0
        " XXX: cut the long string
        let l:line = reg .. ": " .. s:EscapeContents(l:raw)

        call add(s:reg_lines, {"register": reg, "line": l:line, "ignore": v:false})
      elseif s:show_empty_registers == 1
        call add(s:empty_regs, reg)
      endif
    endfor
  endfor

  if len(s:empty_regs) > 0
    let l:line = "Empty" .. join(s:empty_regs, " ")
    let s:empty_reg_line = {"line": l:line, "ignore": v:true}
    call add(s:reg_lines, s:empty_reg_line)
  endif

endfunction

function! registers#OpenWindow()
  call s:ReadRegisters()

  " let s:buf = nvim_create_buf(v:false, v:true)
  let s:buf = bufadd("")
  silent call bufload(s:buf)
  call s:log("Opened register in buffer " .. s:buf)

  call setbufvar(s:buf, "&bufhidden", "wipe")
  call setbufvar(s:buf, "&filetype", "registers")
  call setbufvar(s:buf, "&omnifunc", "")

	let l:width = &columns
	let l:height = &lines

  let l:win_line = winline()

	" Calculate the floating window size
  " If the whole buffer doesn't fit, use the size from the current line to the height
	let l:win_height = min([len(s:reg_lines), min([l:height - l:win_line, s:Round2Int(ceil(l:height * 0.8 - 4))])])
  if has("nvim")
    let l:win_width = s:Round2Int(ceil(l:width * 0.8))
  else
    let l:win_width = s:Round2Int(ceil(l:width * 0.8))
  endif

	" Set window at cursor position, unless the cursor is too close the bottom of the window
	" Too close is what the user set as scrolloff
	let l:user_scrolloff = &scrolloff

  if l:user_scrolloff >= 30
    let l:user_scrolloff = 0
  endif

	let l:opts_row = 1
  if l:win_height < l:user_scrolloff
		let l:win_height = l:user_scrolloff
		let l:opts_row = l:win_line - l:user_scrolloff
  endif

  " Position it next to the cursor
	let l:opts = {
        \ "border": "rounded",
        \ "style": "minimal",
        \ "relative": "cursor",
        \ "width":  l:win_width,
        \ "height":  l:win_height,
        \ "row":  l:opts_row,
        \ "col":  0
        \}

  if has('nvim')
    let s:win = nvim_open_win(s:buf, v:true, l:opts)
  else
    let l:popup_opts = {
          \ 'wrap':0,
          \ 'mapping':0,
          \ 'zindex': 100,
          \ 'moved': 'any',
          \ 'hidden':0,
          \ 'cursorline':1,
          \ 'cursorcolumn':1,
          \ 'line': 'cursor+1', 'col': 'cursor+1',
          \ 'maxwidth': l:win_width, 'maxheight': l:win_height,
          \ 'close': 'none',
          \ 'scrollbar': 1,
          \ 'border': [1,1,1,1],
          \ 'borderchars': ['-', '|', '-', '|', '┌', '┐', '┘', '└'],
          \ }
    let s:win = popup_create(s:buf, l:popup_opts)
  endif
  call s:log("Created win " .. s:win)

	let s:max_width = l:win_width

  if has('nvim')
    augroup registers_specifics
    autocmd! BufLeave <buffer> call registers#CloseWindow()
    autocmd! CursorMoved <buffer> call cursor(0, 1)
    augroup END
  endif

  call setbufvar(s:buf, "&number", 0)
  call setbufvar(s:buf, "&cursorline", 1)
  call setbufvar(s:buf, "&relativenumber", 0)

  " XXX (k): <2021-07-27>
  if has('nvim') && s:invocation_mode == "i"
    call feedkeys("\<C-[>", "n")
  endif

  if !has('nvim')
    hi PopupRegisters ctermbg=NONE guibg=NONE
    call setwinvar(s:win, '&wincolor', 'PopupRegisters')
  endif
endfunction

function! registers#CloseWindow()
  if s:win is v:null
    return
  endif

  if has("nvim")
    call nvim_win_close(s:win, v:true)
  else
    call popup_close(s:win)
  endif

  " execute "q!"
  " XXX (k): <2021-07-30> didn't work. why?
  " execute s:win.'wincmd c'
  let s:win = v:null
endfunction

function! registers#SetMappings()
  " FIXME (k): <2021-07-27> [] ?
  let s:mappings = {
        \ "<CR>": "ApplyRegister(v:null)",
		    \ "<ESC>": "CloseWindow()",
        \ }

  for registers in values(s:register_map)
    for l:reg in registers
      if l:reg == "\""
        let l:arg = "\\\""
      else
        let l:arg = l:reg
      endif
      let s:mappings[l:reg] = printf("ApplyRegister(\"%s\")", l:arg)
    endfor
  endfor

	let l:map_options = {
        \ "nowait": v:true,
		    \ "noremap": v:true,
		    \ "silent": v:true,
        \ }

  if has('nvim')
    " call s:log("Got s:mappings: " .. string(s:mappings))
    for [key, func] in items(s:mappings)
      " let l:callback = ("<cmd>lua require\"registers\".%s<cr>"):format(func)
      let l:callback = printf(":call registers#%s<cr>", func)
      " Map to both normal mode and insert mode for <C-R>
      call nvim_buf_set_keymap(s:buf, "n", key, l:callback, l:map_options)
      call nvim_buf_set_keymap(s:buf, "i", key, l:callback, l:map_options)
      call nvim_buf_set_keymap(s:buf, "v", key, l:callback, l:map_options)
    endfor

    " moving
    call nvim_buf_set_keymap(s:buf, "n", "<c-k>", "<up>", l:map_options)
    call nvim_buf_set_keymap(s:buf, "i", "<c-k>", "<up>", l:map_options)
    call nvim_buf_set_keymap(s:buf, "n", "<c-j>", "<down>", l:map_options)
    call nvim_buf_set_keymap(s:buf, "i", "<c-j>", "<down>", l:map_options)
    call nvim_buf_set_keymap(s:buf, "n", "<c-p>", "<up>", l:map_options)
    call nvim_buf_set_keymap(s:buf, "i", "<c-p>", "<up>", l:map_options)
    call nvim_buf_set_keymap(s:buf, "n", "<c-n>", "<down>", l:map_options)
    call nvim_buf_set_keymap(s:buf, "i", "<c-n>", "<down>", l:map_options)
  else
    function! RegisterPopupFilter(winid, key)
      let l:a = (type(a:key) == v:t_number)? nr2char(a:key) : a:key
      call s:log("Typed key: " .. a:key .. " Escaped: " .. l:a)

      if has_key(s:mappings, a:key)
        call registers#ApplyRegister(l:a)
      elseif has_key(s:movement_keymaps, a:key)
        let l:action = s:movement_keymaps[a:key]
        if l:action == "ESC"
          call registers#CloseWindow()
        else
          call win_execute(s:win, 'call registers#CursorMovement("' .. l:action .. '")')
        endif
      else
        call registers#CloseWindow()
      endif
      return 1
    endfunction
    call popup_setoptions(s:win, {
          \ 'filtermode': 'nvi',
          \ 'filter': 'RegisterPopupFilter',
          \})
  endif

endfunction

function! registers#ApplyRegister(reg)
  call s:log("Start applying register " .. a:reg)
  let l:line = 0
  let l:sleep = v:true
  let l:reg = a:reg

  if l:reg is v:null || index(s:empty_regs, l:reg) >= 0
    let l:sleep = v:false

		let l:line = line(".")

    if l:reg is v:null
      " let l:reg_line = s:reg_lines[l:line - 1]
      let l:reg_line = s:reg_lines[-1]
    else
      let l:reg_line = s:empty_reg_line
    endif

    " XXX (k): <2021-08-18>
    if l:reg_line["ignore"] is v:true
      call registers#CloseWindow()
    endif

    if l:reg is v:null
      let l:reg = l:reg_line["register"]
    endif
  else
    let l:idx = 0
		for reg_line in s:reg_lines
      " call s:log(reg_line)
			if reg_line["register"] == l:reg
				let l:line = l:idx + 1
				break
      endif
      let l:idx = l:idx + 1
    endfor
  endif

  if l:sleep is v:true && l:line > 0 && s:register_key_sleep > 0
		" Move the cursor
    call cursor(l:line, 0)
		" call nvim_win_set_cursor(s:win, [l:line, 0])

		" Redraw so the line get's highlighted
    silent! redraw

    " XXX (k): <2021-07-27>
		" Wait for some time before closing the window
    " execute "sleep" .. s:register_key_sleep

    " silent! sleep s:register_key_sleep
    " call nvim_command(("silent! sleep %d"):format(config().register_key_sleep))
  endif

  call registers#CloseWindow()

  if s:invocation_mode == "i"
    if has("nvim")
      " start from normal mode
      if l:reg == "="
        let l:key = nvim_replace_termcodes("<c-r>", v:true, v:true, v:true)
        " call nvim_feedkeys("i" .. l:key .. l:reg, "n", v:true)
        call feedkeys("i" .. l:key .. l:reg, "n")
      endif

      if l:line == 0
        return
      endif


      " XXX (k): <2021-07-27>
      let l:lines = split(getreg(l:reg), "\n")
      " XXX (k): <2021-07-27> friendly but didn't act like origin neovim
      call nvim_put(l:lines, "b", s:cursor_is_last, v:true)
      call feedkeys("a")
    else
      call feedkeys("" .. l:reg, "n")
    endif
  else
    let l:keys = ""
    if s:invocation_mode == "n"
      if s:operator_count > 0
        let l:keys = s:operator_count .. "\"" .. l:reg
      else
        let l:keys = "\"" .. l:reg
      endif
    elseif s:invocation_mode == "v"
      let l:keys = "gv\"" .. l:reg
    else
      let l:keys = "\"" .. l:reg .. "p"
    endif

    let l:cur_mode = mode()

    call feedkeys(l:keys, "n")
  endif

endfunction

function! registers#UpdateView()
	" Create a array of lines from all the registers
	let l:lines = []

  for reg in s:reg_lines
    let l:line = reg["line"][0:s:max_width]
    let l:lines = add(l:lines, l:line)
  endfor

  if has("nvim")
    call nvim_buf_set_lines(s:buf, 0, -1, v:false, l:lines)
  else
    call popup_settext(s:win, l:lines)
  endif

  call setbufvar(s:buf, "&modifiable", 0)

endfunction


function! registers#InvokeRegisters(mode)
  let s:invocation_mode = a:mode

  let s:operator_count = get(v:, "count")

  if a:mode == "i"
    let s:cursor_is_last = col(".") == col("$") - 1
  endif

  call registers#CloseWindow()
  call registers#OpenWindow()
  call registers#SetMappings()
  call registers#UpdateView()

endfunction
