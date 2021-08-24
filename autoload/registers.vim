" --------------------------------------------
" vars
" --------------------------------------------

" customable configs
let s:tab_symbol           = get(g:, "registers_tab_symbol", "·")
let s:space_symbol         = get(g:, "registers_space_symbol", " ")
let s:return_symbol        = get(g:, "registers_return_symbol", "⏎")
let s:register_key_sleep   = get(g:, "registers_register_key_sleep", 0)
let s:show_empty_registers = get(g:, "registers_show_empty_registers", 1)
let s:debug                = get(g:, "registers_debug", 1)
let s:ctrl_r_literally     = get(g:, "registers_ctrl_r_literally", 1)
let s:preview_key          = get(g:, "registers_preview_key","K")
let s:preview_max_lines    = get(g:, "registers_preview_max_lines", 30)
let s:preview_max_chars    = get(g:, "registers_preview_max_chars", 2048)

" other configs
let s:logfile = "/tmp/vim_registers.log"
let s:preview_key = 'K'
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

let s:e_regs = []
let s:ne_regs = []
let s:buf_lines = []

" win/buf
let s:buf = v:null
let s:win = v:null
let s:preview_win = v:null
let s:preview_buf = v:null

let s:invocation_mode = v:null
let s:operator_count = 0
let s:mappings = {}

" keys: lnum, col, off, curswant, indent
let s:pos = {}

" --------------------------------------------
" funcs
" --------------------------------------------

function! s:PostCursorMoved()
  let ln = line('.', s:win)
  call cursor(0, 1)
  call s:CurLineReg()

  call s:ClosePreviewWin()
endfunction


function! s:CurLineReg()
  let ln = line('.', s:win)
  let reg = v:null
  if !(ln == line('$', s:win) && len(s:e_regs) > 0)
    let reg = s:ne_regs[ln-1]
  endif
  call s:log(printf("[line: %s] reg: %s", ln, reg))
  return reg
endfunction

function! registers#PreviewCurLine()
  let ln = line('.', s:win)
  if ln == line('$', s:win) && len(s:e_regs) > 0
    echo "Empty register."
  else
    let reg = s:ne_regs[ln-1]
    call s:log("Previewing " .. reg)

    let raw = getreg(l:reg)
    let c = split(raw[0:s:preview_max_chars], "\n")
    let total_lines = len(c)
    let c = c[0:s:preview_max_lines]

    let header = printf("Register: %s Length: %s Lines: %s", reg, len(raw), total_lines)
    " call insert(c, header)

    let w = 1
    for l in c
      if len(l) >= s:max_width
        let w = s:max_width
        break
      endif
      if len(l) > w
        let w = len(l)
      endif
    endfor

    if has('nvim')
      let s:preview_buf = nvim_create_buf(v:false, v:true)
      call nvim_buf_set_lines(s:preview_buf, 0, -1, v:true, c)
      call setbufvar(s:preview_buf, "&bufhidden", "wipe")
      call setbufvar(s:preview_buf, "&omnifunc", "")
      let s:preview_win = nvim_open_win(s:preview_buf, v:false, #{
            \ relative: "win",
            \ win: s:win,
            \ bufpos: [1, 5],
            \ border: "rounded",
            \ style: "minimal",
            \ focusable: 0,
            \ zindex: 200,
            \ width: w,
            \ height: len(c) > 0 ? len(c) : 1,
            \ })
    else
      " TODO (k): <2021-08-19> title
      let s:preview_win = popup_notification(c, #{
            \ title: header,
            \ scrollbar: 0,
            \ time:  3000,
            \ moved: 'any',
            \ line:  'cursor+1',
            \ col:   'cursor+4',
            \ padding: [0, 1, 0, 1],
            \ borderchars:  ['-', '|', '-', '|', '┌', '┐', '┘', '└'],
            \ })
      " call setbufvar(winbufnr(s:preview_win), '&syntax', 'txt')
      call setwinvar(s:preview_win, '&wincolor', 'PopupRegisters')
    endif
  endif
endfunction

function! s:ClosePreviewWin()
  if s:preview_win is v:null
    return
  endif
  if has('nvim')
    call nvim_win_close(s:preview_win, v:true)
  else
    call popup_close(s:preview_win)
  endif
  let s:preview_win = v:null
endfunction

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
  let s:buf_lines = []
  let s:e_regs = []
  let s:buf_lines = []

  for reg_type in s:register_sequence
    for reg in s:register_map[reg_type]
      let l:raw = getreg(reg, 1)

      let l:idx = 0
      if len(l:raw) > 0
        " XXX: cut the long string
        let l:line = reg .. ": " .. s:EscapeContents(l:raw)
        let l:line = l:line[0:s:max_width]

        call add(s:ne_regs, reg)
        call add(s:buf_lines, l:line)
      elseif s:show_empty_registers == 1
        call add(s:e_regs, reg)
      endif
    endfor
  endfor

  if len(s:e_regs) > 0
    let l:line = "Empty" .. join(s:e_regs, " ")
    call add(s:buf_lines, l:line)
  endif

endfunction

function! registers#OpenWindow()
	let l:width = &columns
	let l:height = &lines
  let l:win_line = winline()
  let l:win_width = s:Round2Int(ceil(l:width * 0.8))
	let s:max_width = l:win_width

  call s:ReadRegisters()

  " let s:buf = nvim_create_buf(v:false, v:true)
  let s:buf = bufadd("")
  silent call bufload(s:buf)
  call s:log("Opened register in buffer " .. s:buf)

  call setbufvar(s:buf, "&bufhidden", "wipe")
  call setbufvar(s:buf, "&filetype", "registers")
  call setbufvar(s:buf, "&omnifunc", "")

	let l:win_height = min([len(s:buf_lines), min([l:height - l:win_line, s:Round2Int(ceil(l:height * 0.8 - 4))])])

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
  if has('nvim')
    let l:float_opts = #{
          \ border:   "rounded",
          \ style:    "minimal",
          \ relative: "cursor",
          \ width:    l:win_width,
          \ height:   l:win_height,
          \ row:      l:opts_row,
          \ col:      0
          \}
    let s:win = nvim_open_win(s:buf, v:true, l:float_opts)
  else
    let l:popup_opts = #{
          \ wrap:         0,
          \ mapping:      0,
          \ zindex:       100,
          \ moved:        'any',
          \ hidden:       0,
          \ cursorline:   1,
          \ cursorcolumn: 1,
          \ maxwidth:     l:win_width,
          \ maxheight:    l:win_height,
          \ close:        'none',
          \ scrollbar:    1,
          \ border:       [1,1,1,1],
          \ borderchars:  ['-', '|', '-', '|', '╭', '╮', '╯', '╰'],
          \ time:         100000,
          \ title:        ' Registers ',
          \ }
          " \ borderchars:  ['-', '|', '-', '|', '┌', '┐', '┘', '└'],
          " \ borderchars:  ['-', '|', '-', '|', '╭', '╮', '╯', '╰'],
          " \ line:         'cursor+1',
          " \ col:          'cursor+1',
    " let s:win = popup_create(s:buf, l:popup_opts)
    let s:win = popup_atcursor(s:buf, l:popup_opts)
    call s:log("Popup info " .. string(popup_getoptions(s:win)))
  endif
  call s:log("Created win " .. s:win)

  if has('nvim')
    augroup registers_specifics
    " XXX conficts with previewing
    " autocmd! BufLeave <buffer> call registers#CloseWindow()
    autocmd! WinLeave <buffer> call registers#CloseWindow()
    autocmd! CursorMoved,CursorMovedI <buffer> call s:PostCursorMoved()
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
  call s:ClosePreviewWin()
  if s:win is v:null
    return
  endif

  if has("nvim")
    call nvim_win_close(s:win, v:true)
  else
    call popup_close(s:win)
  endif

  let s:win = v:null
endfunction

function! registers#SetMappings()
  " FIXME (k): <2021-07-27> [] ?
  if has('nvim')
    let s:mappings = {
          \ "<CR>":  "ApplyRegister(v:null)",
          \ "<ESC>": "CloseWindow()",
          \ }
  else
    let s:mappings = {
          \ "\<CR>":  "ApplyRegister(v:null)",
          \ "\<ESC>": "CloseWindow()",
          \ }
  endif
  let s:mappings["K"] = "PreviewCurLine()"

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
      call s:ClosePreviewWin()
      let l:a = (type(a:key) == v:t_number)? nr2char(a:key) : a:key
      call s:log("Typed key: " .. a:key .. " Escaped: " .. l:a .. "\r")

      if has_key(s:mappings, a:key)
        execute printf("call registers#%s", s:mappings[a:key])
      elseif has_key(s:movement_keymaps, a:key)
        let l:action = s:movement_keymaps[a:key]
        call s:log(printf("Got movement %s -> %s\n", a:key, l:action))
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
  call s:ClosePreviewWin()
  call s:log("Applying register " .. a:reg)
  let l:ln = 0
  let l:sleep = v:true
  if a:reg is v:null
    let l:reg = s:CurLineReg()
    if l:reg is v:null
      " empty reg, nothing to do
      return registers#CloseWindow()
    endif
  else
    let l:reg = a:reg
  endif

  " empty
  if index(s:e_regs, l:reg) >= 0
    let l:sleep = v:false
    call registers#CloseWindow()
  else
    let l:ln = index(s:ne_regs, l:reg) + 1
  endif

  if l:sleep is v:true && l:ln > 0 && s:register_key_sleep > 0
		" Move the cursor
    call cursor(l:ln, 0)
		" call nvim_win_set_cursor(s:win, [l:ln, 0])

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
      " call cursor(s:curpos[1], s:curpos[2], s:curpos[3], s:curpos[4])
      if l:reg == "="
        let l:key = nvim_replace_termcodes("<c-r>", v:true, v:true, v:true)
        " call nvim_feedkeys("i" .. l:key .. l:reg, "n", v:true)
        call feedkeys("i" .. l:key .. l:reg, "n")
      endif

      if l:ln == 0
        return
      endif

      " XXX (k): <2021-07-27>
      let l:lines = split(getreg(l:reg), "\n")
      " XXX (k): <2021-07-27> friendly but didn't act like origin neovim
      call nvim_put(l:lines, "b", 1, v:true)
      
      " XXX (k): <2021-07-27> Use P?
      " call nvim_put(l:lines, "b", s:cursor_is_last, v:true)
      call feedkeys("a")
    else
      if s:ctrl_r_literally == 1
        call feedkeys("" .. l:reg, "n")
      else
        call feedkeys("" .. l:reg, "n")
      endif
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
  if has("nvim")
    call nvim_buf_set_lines(s:buf, 0, -1, v:false, s:buf_lines)
  else
    call popup_settext(s:win, s:buf_lines)
  endif

  let s:buf_lines = []

  call setbufvar(s:buf, "&modifiable", 0)
endfunction


function! registers#Invoke(mode)
  " [0, lnum, col, off, curswant] 
  let curpos = getcurpos()
  let s:pos['lnum'] = curpos[1]
  let s:pos['col'] = curpos[2]
  let s:pos['off'] = curpos[3]
  let s:pos['curswant'] = curpos[4]
  let s:pos['indent'] = indent(s:pos['lnum'])

  " if s:curpos[2] > 0 && len(getline(s:curpos)) == 0
  " endif
  
  call s:log("Current position " .. string(s:pos))
  call s:log("Current buffer line " .. string(getline(s:pos.lnum)))
  let s:invocation_mode = a:mode

  let s:operator_count = get(v:, "count")

  if a:mode == "i"
    let s:cursor_is_last = col(".") == col("$") - 1
    call s:log("cursor is last " .. string(s:cursor_is_last))
  endif

  call registers#CloseWindow()
  call registers#OpenWindow()
  call registers#SetMappings()
  call registers#UpdateView()
endfunction
