" --------------------------------------------
" vars
" --------------------------------------------

hi PopupRegisters ctermbg=NONE guibg=NONE
hi default RegistersPreInsertVT ctermfg=12 guifg=#504945

" customable configs
let s:position             = get(g:, "registers_position", "relative")
let s:tab_symbol           = get(g:, "registers_tab_symbol", "·")
let s:space_symbol         = get(g:, "registers_space_symbol", " ")
let s:return_symbol        = get(g:, "registers_return_symbol", "⏎")
let s:register_key_sleep   = get(g:, "registers_register_key_sleep", 0)
let s:show_empty_registers = get(g:, "registers_show_empty_registers", 1)
let s:debug                = get(g:, "registers_debug", 0)
let s:ctrl_r_literally     = get(g:, "registers_ctrl_r_literally", 1)
let s:preview_key          = get(g:, "registers_preview_key", "K")
let s:preview_max_lines    = get(g:, "registers_preview_max_lines", 30)
let s:preview_max_chars    = get(g:, "registers_preview_max_chars", 2048)
let s:insert_virtual_text  = get(g:, "registers_insert_virtual_text", 0)

if s:position !~ '\v(relative|center)'
  echoerr "g:registers_position should be set to 'relative' or 'center'"
endif

" other configs
let s:logfile = "/tmp/vim_registers_" .. $USER .. strftime("_%y%m%d") .. ".log"
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

" win/buf
function! s:resetVars() abort
  let s:e_regs = []
  " also actual lines
  let s:ne_regs = []
  let s:buf_lines = []

  let s:from_line = v:null
  let s:from_win = v:null
  let s:from_buf = v:null
  let s:buf = v:null
  let s:win = v:null
  let s:preview_win = v:null
  let s:preview_buf = v:null
  let s:is_at_last = v:null

  let s:invocation_mode = v:null
  let s:operator_count = 0
  let s:mappings = {}

  " keys: lnum, col, off, curswant, indent
  let s:pos = {}
endfunction

call s:resetVars()

" --------------------------------------------
" Init
" --------------------------------------------

let s:virtual_text_support = s:insert_virtual_text && has('patch-9.0.0067')
" FIXME bugs ...
if s:virtual_text_support
  if empty(prop_type_get('RegistersPreInsertVT'))
    call prop_type_add('RegistersPreInsertVT', {'highlight': 'RegistersPreInsertVT'})
  endif
endif
let s:prop_id = 0

" --------------------------------------------
" utils
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

" --------------------------------------------
" funcs
" --------------------------------------------


function! registers#insertShowVT(ne_regs_idx) abort
  if s:from_buf == v:null
    call s:log("[warn] from_buf is null")
    return
  endif
  if !s:virtual_text_support
    return
  endif
  " FIXME (k): <2022-12-13> 
  if s:is_at_last && len(s:from_line) > 0
    return
  endif
  
  call s:log("vt prop id " .. s:prop_id)
  call s:log("showing register line: " .. a:ne_regs_idx)
  let text = s:buf_lines[a:ne_regs_idx]
  " call s:log(printf("from line: %s len: %s", s:from_line, len(s:from_line)))
  let p = #{
        \ type: 'RegistersPreInsertVT',
        \ text: text,
        \ bufnr: s:from_buf,
        \ }

  let vt_line = s:pos.lnum
  let vt_col = s:pos.col
  call s:log(printf("Show vt at line %s col %s (at last: %s)", vt_line, vt_col, s:is_at_last))
  let s:prop_id = prop_add(vt_line, vt_col, p)
endfunction


function! registers#clearVirtualText(line) abort
  if s:virtual_text_support && s:prop_id != 0
    " TODO (k): <2022-12-09> with lnr
    let p = {"id": s:prop_id, "bufnr": s:from_buf}
    if a:line != 0
      call prop_remove(p, a:line)
    else
      call prop_remove(p)
    endif
    let s:prop_id = 0
  endif
endfunction


function! registers#PreviewWinFilter(winid, key)
  " echom 'preview ' .. a:key
  if a:key =~ '`$'
    return 1
  elseif has_key(s:movement_keymaps, a:key)
    call s:ClosePreviewWin()
    let l:action = s:movement_keymaps[a:key]
    call s:log(printf("Got movement %s -> %s\n", a:key, l:action))
    call win_execute(s:win, 'call registers#CursorMovement("' .. l:action .. '")')
    " if l:action == "ESC"
    "   call s:ClosePreviewWin()
    "   " call registers#CloseWindow()
    " else
    "   call win_execute(s:win, 'call registers#CursorMovement("' .. l:action .. '")')
    " endif
  else
    call s:ClosePreviewWin()
  endif
  return 1
endfunction


function! s:GetScreenPos() abort
  let wid = win_getid()
  let l:curpos = getcurpos(wid)
  let l:scrpos = screenpos(wid, l:curpos[1], l:curpos[2])
  let istop = l:scrpos.row <= (&lines / 2)
  let isleft = l:scrpos.col <= (&columns / 2)

  call s:log(printf("Get screenpos with args (%s): %s",
        \ [wid, l:curpos[1], l:curpos[2]],
        \ [l:scrpos, istop, isleft]))

  return [l:scrpos, istop, isleft]
endfunction


function! s:GetRegCurPos()
  let ln = line('.', s:win)
  let scrpos = screenpos(s:win, ln, 2)
  let is_top = scrpos.row <= (&lines / 2)
  let is_left = scrpos.col <= (&columns / 2)

  let arg = [s:preview_win, ln, 2]

  let ret = [scrpos, is_top, is_left]
  call s:log(printf("Get reg info screenpos with args (%s): %s", arg, ret))

  return [scrpos, is_top, is_left]
endfunction


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


function! registers#PreviewCurLine() abort
  let ln = line('.', s:win)
  if ln == line('$', s:win) && len(s:e_regs) > 0
    echo "Empty register."
  else
    let reg = s:ne_regs[ln-1]
    call s:log("Previewing " .. reg)
    call s:log(s:ne_regs)

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

    let [regpos, isleft, isright] = s:GetRegCurPos()
    call s:log(s:GetRegCurPos())

    let floatrow = regpos.row > 1? regpos.row - 1: regpos.row
    let floatcol = regpos.col + 2

    " preview window
    let preview_opts = #{
          \ title:       header,
          \ scrollbar:   0,
          \ hidden:      0,
          \ moved:       'any',
          \ close:       'none',
          \ line:        floatrow + 1,
          \ col:         floatcol,
          \ highlight:   'Pmenu',
          \ zindex:      300,
          \ padding:     [0, 1, 0, 1],
          \ borderchars: ['-', '|', '-', '|', '┌', '┐', '┘', '└'],
          \ }
          " \ border:      [1,1,1,1],
    let s:preview_win = popup_create(c, preview_opts)
    " call setwinvar(s:preview_win, '&wincolor', 'PopupRegisters')
    call popup_setoptions(s:preview_win, {
          \ 'filtermode': 'nvi',
          \ 'filter': 'registers#PreviewWinFilter',
          \})
  endif
endfunction


function! s:ClosePreviewWin() abort
  if s:preview_win is v:null
    return
  endif
  call popup_close(s:preview_win)
  let s:preview_win = v:null
endfunction


function! registers#CursorMovement(where) abort
  if s:invocation_mode == 'i'
    call registers#clearVirtualText(s:pos.lnum)
  endif

  let endline = line('$')
  if type(a:where) == type(0)
    let curline = a:where
  else
    let curline = line('.')
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
  endif
	if curline < 1
		let curline = 1
	elseif curline > endline
		let curline = endline
	endif
  if s:invocation_mode == 'i' && curline < endline
    call registers#insertShowVT(curline-1)
    " call s:log("show vt with register no: " .. curline)
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


function! s:ReadRegisters() abort
  let s:e_regs = []
  let s:ne_regs = []
  let s:buf_lines = []

  for reg_type in s:register_sequence
    for reg in s:register_map[reg_type]
      let l:raw = getreg(reg, 1)
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
    let l:line = "Empty: " .. join(s:e_regs, " ")
    call add(s:buf_lines, l:line)
  endif

endfunction


function! registers#OpenWindow() abort
  let [curpos, istop, isleft] = s:GetScreenPos()
	let l:width = &columns
	let l:height = &lines
  let l:win_line = winline()
  let l:win_width = s:Round2Int(ceil(l:width * 0.8))
	let s:max_width = l:win_width

  call s:ReadRegisters()

  if s:invocation_mode == "i" && s:virtual_text_support
    call registers#clearVirtualText(s:pos.lnum)
    call registers#insertShowVT(0)
  endif

  let s:buf = bufadd("")
  silent call bufload(s:buf)
  " call s:log("Opened register in buffer " .. s:buf)

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
  " let pos = ['bot', 'top'][istop] .. ['right', 'left'][isleft]
  let pos = (istop? 'top': 'bot') .. (isleft? 'left': 'right')

  let line = istop? 'cursor+1': 'cursor-1'
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
        \ col:          'cursor',
        \ line:         line,
        \ pos:          pos,
        \ }
        " \ title:        ' Registers ',
        " \ borderchars:  ['-', '|', '-', '|', '┌', '┐', '┘', '└'],
        " \ borderchars:  ['-', '|', '-', '|', '╭', '╮', '╯', '╰'],

  if s:position == 'center'
    let l:popup_opts.pos = 'center'
  endif
  let s:win = popup_create(s:buf, l:popup_opts)
  " let s:win = popup_atcursor(s:buf, l:popup_opts)
  call s:log("Popup info " .. string(popup_getoptions(s:win)))
  " call s:log("Created win " .. s:win)

  call setbufvar(s:buf, "&number", 0)
  call setbufvar(s:buf, "&cursorline", 1)
  call setbufvar(s:buf, "&relativenumber", 0)
  call setwinvar(s:win, '&wincolor', 'PopupRegisters')
endfunction


function! registers#CloseWindow()
  call s:ClosePreviewWin()
  if s:win is v:null
    return
  endif

  call popup_close(s:win)
  call registers#clearVirtualText(s:pos.lnum)

endfunction


function! registers#SetMappings()
  let s:mappings = {
        \ "\<CR>":  "ApplyRegister(v:null)",
        \ "\<ESC>": "CloseWindow()",
        \ }
  let s:mappings["K"] = "PreviewCurLine()"

  for registers in values(s:register_map)
    for l:reg in registers
      if l:reg == "\""
        let l:arg = "\\\""
      else
        let l:arg = l:reg
      endif
      let s:mappings[l:reg] = printf("ApplyRegister(\"%s\")", l:arg)
      " call s:log(printf("Set mapping: %s", l:reg))
    endfor
  endfor

	let l:map_options = {
        \ "nowait": v:true,
		    \ "noremap": v:true,
		    \ "silent": v:true,
        \ }

  function! RegisterPopupFilter(winid, key)
    call s:ClosePreviewWin()
    let l:a = (type(a:key) == v:t_number)? nr2char(a:key) : a:key
    call s:log(printf("Typed key '%s' Escaped '%s'", a:key, l:a))
    " call s:log(l:a == '<80><fd>`')
    " call s:log(l:a =~ '`$')
    " echom l:a

    if has_key(s:mappings, a:key)
      " let reg_idx = index(s:ne_regs, a:key)
      " if reg_idx >= 0
      "   call win_execute(s:win, 'call registers#CursorMovement(' .. reg_idx .. ')')
      " endif
      execute printf("call registers#%s", s:mappings[a:key])
    elseif has_key(s:movement_keymaps, a:key)
      let l:action = s:movement_keymaps[a:key]
      " call s:log(printf("Got movement %s -> %s\n", a:key, l:action))
      if l:action == "ESC"
        call registers#CloseWindow()
      else
        call win_execute(s:win, 'call registers#CursorMovement("' .. l:action .. '")')
      endif
    " elseif l:a == "\`" || a:key == "\`"
    "   " XXX (k): <2022-12-05> received ` soon with coc.nvim installed. Didn't know why
    "   return 1
    else
      " call registers#CloseWindow()
    endif
    return 1
  endfunction
  call popup_setoptions(s:win, {
        \ 'filtermode': 'nvi',
        \ 'filter': 'RegisterPopupFilter',
        \})

  call s:log("Setting mappings finished")

endfunction


function! registers#ApplyRegister(reg)
  call s:ClosePreviewWin()
  " let reg_idx = index(s:ne_regs, a:reg)

  " call win_gotoid(s:win)
  " call win_execute(s:win, 'call cursor(11, 0)')

  " execute reg_idx
  " silent! redraw
  " silent! sleep 1

  call s:log("Applying register " .. a:reg)
  " call s:log("Index " .. reg_idx)
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

  " if l:sleep is v:true && l:ln > 0 && s:register_key_sleep > 0
		" " Move the cursor
  "   " call cursor(l:ln, 0)
  "   " call cursor(reg_idx, 0)
  "   execute s:win .. "wincmd " .. reg_idx

		" " Redraw so the line get's highlighted
  "   silent! redraw

  "   " XXX (k): <2021-07-27>
		" " Wait for some time before closing the window
  "   " execute "sleep" .. s:register_key_sleep
  "   noautocmd exec ":sleep 100m"
  "   " silent! sleep s:register_key_sleep
  " endif

  " empty
  if index(s:e_regs, l:reg) >= 0
    let l:sleep = v:false
    call registers#CloseWindow()
  else
    let l:ln = index(s:ne_regs, l:reg) + 1
  endif

  call registers#CloseWindow()

  call s:log("Mode "..s:invocation_mode)
  if s:invocation_mode == "i"
    if s:ctrl_r_literally == 1
      call feedkeys("" .. l:reg, "n")
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


function! registers#UpdateView() abort
  call popup_settext(s:win, s:buf_lines)
  " let s:buf_lines = []
  call setbufvar(s:buf, "&modifiable", 0)
  call s:log("updating view finished")
endfunction


function! registers#Invoke(mode)
  call s:log("------- start --------")

  call registers#CloseWindow()
  " if reg_executing() != ''
  "   call s:log("Executing macro: " .. a:mode)
  "   if a:mode == 'i'
  "     call feedkeys('', "n")
  "   else
  "     call feedkeys('"', "n")
  "   endif
  "   return
  " endif

  let s:from_line = getline('.')
  let s:from_win = winnr()
  let s:from_buf = bufnr()

  " [0, lnum, col, off, curswant]
  let curpos = getcurpos()

  let s:pos.lnum     = curpos[1]
  let s:pos.col      = curpos[2]
  let s:pos.off      = curpos[3]
  let s:pos.curswant = curpos[4]
  let s:pos.indent   = indent(s:pos['lnum'])

  " XXX (k): <2022-12-13> at $ / $-1
  let s:is_at_last = col(".") >= col("$") - 1

  call s:log(printf("[invoke] Current pos %s Col$: %s virtcol: %s", s:pos, col('$'), virtcol('.')))
  let s:invocation_mode = a:mode
  let s:operator_count = get(v:, "count")

  call registers#OpenWindow()
  call registers#UpdateView()
  call registers#SetMappings()
endfunction
