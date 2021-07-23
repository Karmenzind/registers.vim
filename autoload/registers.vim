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

" --------------------------------------------
" funcs
" --------------------------------------------

function! s:ReadRegisters()
  let l:empty_regs = []
  " reset ? XXX (K): <2021-07-23>
  let l:reg_lines = []

  for reg_type in s:register_sequence

    for reg in s:register_map[reg_type]
      let l:raw = getreg(reg, 1)

      if len(l:raw) > 0
        let l:contents = l:raw->substitute("\t", s:tab_symbol, "g")
              \ ->substitute(" ", s:space_symbol, "g")
              \ ->substitute("[\n\r]", s:return_symbol, "g")

        let l:line = reg .. ": " .. l:contents

        call add(l:reg_lines, {"register": reg, "line": l:line, "data": l:raw})
      elseif s:show_empty_registers == 1
        call add(l:empty_regs, reg)

      endif
    endfor
  endfor

  if len(l:empty_regs) > 0
    let l:line = "Empty:" .. join(l:empty_regs, " ")
    call add(reg_lines, {"line": l:line, "ignore": v:true})
  endif

endfunction

function! registers#OpenWindow()
  call s:ReadRegisters()

  " let s:buf = 

endfunction

function! registers#CloseWindow()
  " if not s:win

endfunction


function! registers#SetMappings()

endfunction

function! registers#UpdateView()

endfunction


function! registers#InvokeRegisters(mode)
  call s:ReadRegisters()
  return

  " let l:mode = a:0 > 0 ? a:1 : "n"

	" Keep track of the mode that's used to open the popup
  let l:mode = a:mode
  "
	" Keep track of the count that's used to invoke the window so it can be applied again
  let l:operator_count = get(v:, "count")

	" Keep track of whether the cursor is at the last character of the line in insert mode
  if l:mode == "i"
    let cursor_is_last = col(".") == col("$") - 1
  endif

	" Close the old window if it's still open
  registers#CloseWindow()

  registers#OpenWindow()
  registers#SetMappings()
  registers#UpdateView()

endfunction
