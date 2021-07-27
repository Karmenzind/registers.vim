" --------------------------------------------
" vars
" --------------------------------------------

let s:tab_symbol = get(g:, "registers_tab_symbol", "·")
let s:space_symbol = get(g:, "registers_space_symbol", " ")
let s:return_symbol = get(g:, "registers_return_symbol", "⏎")
let s:register_key_sleep = get(g:, "registers_register_key_sleep", 0)
let s:show_empty_registers = get(g:, "registers_show_empty_registers", 1)

let s:register_map = { "selection": ["*", "+"],
      \ "unnamed": ["\""],
      \ "delete": ["-"],
      \ "read-only": [":", ".", "%"],
      \ "last search pattern": ["/"],
      \ "numbered": ["0", "1", "2", "3", "4", "5", "7", "8", "9"],
      \ "named": [ "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", ],
      \ "alternate buffer": ["#"],
      \ "expression": ["="],
      \ "black hole": ["_"] }

let s:register_sequence = ["selection", "unnamed", "delete", "read-only", "last search pattern", "numbered", "named", "alternate buffer", "expression", "black hole"]

let s:reg_lines = []

let s:buf = v:null
let s:win = v:null
let s:invocation_mode = v:null
let s:operator_count = 0

" --------------------------------------------
" funcs
" --------------------------------------------

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
  let l:empty_regs = []
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
        call add(l:empty_regs, reg)

      endif
    endfor
  endfor

  if len(l:empty_regs) > 0
    let l:line = "Empty" .. join(l:empty_regs, " ")
    call add(s:reg_lines, {"line": l:line, "ignore": v:true})
  endif

endfunction

function! registers#OpenWindow()
  call s:ReadRegisters()

  let s:buf = nvim_create_buf(v:false, v:true)

  call nvim_buf_set_option(s:buf, "bufhidden", "wipe")
  call nvim_buf_set_option(s:buf, "filetype", "registers")
	call nvim_buf_set_option(s:buf, "omnifunc", "")

	let l:width = &columns
	let l:height = &lines

  let l:win_line = winline()

	" Calculate the floating window size
  " If the whole buffer doesn't fit, use the size from the current line to the height
	let l:win_height = min([len(s:reg_lines), min([l:height - l:win_line, s:Round2Int(ceil(l:height * 0.8 - 4))])])
	let l:win_width = s:Round2Int(ceil(l:width * 0.8))

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

  let s:win = nvim_open_win(s:buf, v:true, l:opts)
	let s:max_width = nvim_win_get_width(s:win) - 2

	augroup registers_specifics
	autocmd! BufLeave <buffer> call registers#CloseWindow()
	autocmd! CursorMoved <buffer> call cursor(0, 1)
	augroup END

	call nvim_win_set_option(s:win, "cursorline", v:true)
	call nvim_win_set_option(s:win, "number", v:false)
	call nvim_win_set_option(s:win, "relativenumber", v:false)

  " XXX (k): <2021-07-27> 
  if s:invocation_mode == "i"
    call feedkeys("\<C-[>", "n")
  endif
endfunction

function! registers#CloseWindow()
  if s:win is v:null
    return
  endif

  call nvim_win_close(s:win, v:true)
  let s:win = v:null
endfunction

function! registers#SetMappings()
  " FIXME (k): <2021-07-27> [] ?
  let l:mappings = {
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
      let l:mappings[l:reg] = printf("ApplyRegister(\"%s\")", l:arg)
    endfor
  endfor

	let l:map_options = {
        \ "nowait": v:true,
		    \ "noremap": v:true,
		    \ "silent": v:true,
        \ }

  for [key, func] in items(l:mappings)
		" let l:callback = ("<cmd>lua require\"registers\".%s<cr>"):format(func)
		let l:callback = printf(":call registers#%s<cr>", func)
		" Map to both normal mode and insert mode for <C-R>
		call nvim_buf_set_keymap(s:buf, "n", key, l:callback, l:map_options)
		call nvim_buf_set_keymap(s:buf, "i", key, l:callback, l:map_options)
		call nvim_buf_set_keymap(s:buf, "v", key, l:callback, l:map_options)
  endfor

	" Map <c-k> & <c-j> for moving up and down
	call nvim_buf_set_keymap(s:buf, "n", "<c-k>", "<up>", l:map_options)
	call nvim_buf_set_keymap(s:buf, "i", "<c-k>", "<up>", l:map_options)
	call nvim_buf_set_keymap(s:buf, "n", "<c-j>", "<down>", l:map_options)
	call nvim_buf_set_keymap(s:buf, "i", "<c-j>", "<down>", l:map_options)

	" Map <c-p> & <c-n> for moving up and down
	call nvim_buf_set_keymap(s:buf, "n", "<c-p>", "<up>", l:map_options)
	call nvim_buf_set_keymap(s:buf, "i", "<c-p>", "<up>", l:map_options)
	call nvim_buf_set_keymap(s:buf, "n", "<c-n>", "<down>", l:map_options)
	call nvim_buf_set_keymap(s:buf, "i", "<c-n>", "<down>", l:map_options)

endfunction

function! registers#ApplyRegister(reg)
  let l:line = 0
  let l:sleep = v:true
  let l:reg = a:reg

  if l:reg is v:null
		let l:line = line(".")
    let l:sleep = v:false

    let l:reg_line = s:reg_lines[l:line - 1]
    if l:reg_line["ignore"] is v:true
      call registers#CloseWindow()
    endif

    let l:reg = l:reg_line["register"]
  else
    let l:idx = 0
		for reg_line in s:reg_lines
			if reg_line["register"] == l:reg
				let l:line = l:idx + 1
				break
      endif
      let l:idx = l:idx + 1
    endfor
  endif

  if l:sleep is v:true && l:line > 0 && s:register_key_sleep > 0
		" Move the cursor
		call nvim_win_set_cursor(s:win, [l:line, 0])

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

	" Write the lines to the buffer
	call nvim_buf_set_lines(s:buf, 0, -1, v:false, l:lines)

	" Don't allow the buffer to be modified
	call nvim_buf_set_option(s:buf, "modifiable", v:false)

endfunction


function! registers#InvokeRegisters(mode)

  " let l:mode = a:0 > 0 ? a:1 : "n"

	" Keep track of the mode that's used to open the popup
  let s:invocation_mode = a:mode

	" Keep track of the count that's used to invoke the window so it can be applied again
  let s:operator_count = get(v:, "count")

	" Keep track of whether the cursor is at the last character of the line in insert mode
  if a:mode == "i"
    let s:cursor_is_last = col(".") == col("$") - 1
  endif

	" Close the old window if it's still open
  call registers#CloseWindow()

  call registers#OpenWindow()
  call registers#SetMappings()
  call registers#UpdateView()

endfunction
