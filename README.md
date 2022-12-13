# registers.vim

Viewable registers for Vim8, powered by floating window. With this plugin you should be no longer troubled by confusing registers in Vim.

Inspired by [registers.nvim](https://github.com/tversteeg/registers.nvim).

## Usage

- Press `"` (normal/visual mode) or `ctrl-r` (insert mode) to trigger.
- Press `ctrl-j/k/f/b/u/d` to move. Preview current register with `K`.

![](https://raw.githubusercontent.com/Karmenzind/i/master/registers.vim/registers-preview.gif)

## Install

Vim 8.2+ (with feature `+popupwin`) is required.

- use [vim-plug](https://github.com/junegunn/vim-plug):
    ```
    Plug 'karmenzind/registers.vim'
    ```
- use Dein
    ```
    call dein#add('karmenzind/registers.vim')
    ```

## Configuration

Here are configration and default values.

```vim
" customize the symbols
let g:registers_tab_symbol = "·"
let g:registers_space_symbol = " "
let g:registers_return_symbol = "⏎"

" the key to preview register corresponding to current line
let g:registers_preview_key = "K"

" limit the content to preview
let g:registers_preview_max_lines = 30
let g:registers_preview_max_chars = 2048

" show empty registers or not
let g:registers_show_empty_registers = 1

" This controls the position to show the popup
" 'relative': close to the cursor
" 'center': in the center of the Vim window
let g:registers_position = "relative"

" In insert mode, applying a register will insert the text literally by using 'CTRL-R CTRL-R {register}' (see `:help i_CTRL-R_CTRL-R`).
" This differs from original 'CTRL-R {register}' (see `:help i_CTRL-R`) but could be more friendly.
" Turn it off and choose `i_CTRL-R` by setting this to 0.
let g:registers_ctrl_r_literally = 1

" Write some debug information to log file `/tmp/vim_registers.log`.
let g:registers_debug = 0

" (experimental) show virtual text in insert mode
let g:registers_insert_virtual_text = 0
```

## Known Bugs

- register popups didn't work with macros
- previewing `=` register shows empty
- virtual text didn't work at end of line or before the last char
