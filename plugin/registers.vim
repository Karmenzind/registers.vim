" Maintainer:  kmz <valesail7@gmail.com>

if !has('nvim') | finish | endif

" Prevent loading file twice
if exists('g:registers_loaded') | finish | endif

" Save user coptions
let s:save_cpo = &cpo
" Reset them to defaults
set cpo&vim

" Command completion options
function! s:arg_opts(A, L, P)
    return "n\ni\nv"
endfunction

" Command to run our plugin
command! -nargs=? -complete=custom,s:arg_opts Registers call registers#InvokeRegisters(<f-args>)

" " Open the popup window when pressing <C-R> in insert mode
inoremap <silent> <C-R> <C-O><cmd>Registers i<CR>

" " Open the popup window when pressing " in regular mode
nnoremap <silent> " <cmd>Registers n<CR>

" " Open the popup window when pressing " in visual mode
xnoremap <silent> " <esc><cmd>Registers v<CR>

" Restore after
let &cpo = s:save_cpo
unlet s:save_cpo

let g:registers_loaded = 1
