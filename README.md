# registers.vim

**CURRENT STATUS: stable**

Enhanced viewable registers powered by floating window, for both Vim8 and NeoVim. With this plugin you should be no longer troubled by tens of confusing registers in Vim.

This plugin was inspired by [registers.nvim](https://github.com/tversteeg/registers.nvim).

## Install

Vim 8.2+ is required.

- use [vim-plug](https://github.com/junegunn/vim-plug):
    ```vim
    Plug 'karmenzind/registers.vim'
    ```
- use Dein
    ```vim
    call dein#add('karmenzind/registers.vim')
    ```
- use [Vundle](https://github.com/VundleVim/Vundle.vim):
    ```vim
    Plugin 'karmenzind/registers.vim'
    ```

## Configuration

Here are configration and default values.

```vim
" In insert mode, applying a register will insert the text literally by using 'CTRL-R CTRL-R {register}' (see `:help i_CTRL-R_CTRL-R`).
" This differs from original 'CTRL-R {register}' (see `:help i_CTRL-R`) but could be more friendly.
" Turn it off and choose `i_CTRL-R` by setting this to 0.
let g:registers_ctrl_r_literally = 1

" the key to preview register corresponding to current line
let g:registers_preview_key = "K"
" limit the content
let g:registers_preview_max_lines = 30
let g:registers_preview_max_chars = 2048

" customize the symbols
let g:registers_tab_symbol = "·"
let g:registers_space_symbol = " "
let g:registers_return_symbol = "⏎"

" show empty registers or not
let g:registers_show_empty_registers = 1

" Write some debug information to log file `/tmp/vim_registers.log`.
let g:registers_debug = 1

" This controls the position to show the popup
" 'relative': close to the cursor
" 'center': in the center of the Vim window (Vim8 only)
let g:registers_position = "relative"
```

## Known Error

- register popups didn't work with macros

## TODO

- terminal mode
- theme setup
- support opening register window in a floating Tmux pane
- redraw floating window when buffer/window size changed
- verbose mode
- center mode
