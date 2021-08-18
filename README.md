# registers.vim

**CURRENT STATUS: in development**

Enhanced viewable registers powered by floating window, for both Vim8 and NeoVim. With this plugin you should be no longer troubled by tens of confusing registers in Vim.

This plugin was inspired by [registers.nvim](https://github.com/tversteeg/registers.nvim) and some NeoVim functions were rewritten from tversteeg's Lua code into pure VimScript.

## Install

Vim 8.2+ or NeoVim 0.4.4+ is required.

- use [vim-plug](https://github.com/junegunn/vim-plug):
    ```vim
    Plug 'karmenzind/registers.vim'
    ```
- use Packer
    ```vim
    use 'karmenzind/registers.vim'
    ```
- use Paq
    ```vim
    paq 'karmenzind/registers.vim'
    ```
- use Dein
    ```vim
    call dein#add('karmenzind/registers.vim')
    ```
- use [Vundle](https://github.com/VundleVim/Vundle.vim):
    ```vim
    Plugin 'karmenzind/registers.vim'
    ```

## TODO

- preview full content in the second floating window
- terminal mode
- theme setup
- support opening register window in a floating Tmux pane
- redraw floating window when buffer/window size changed

Bugs:

- vim8: window disappear after secs
- vim8: weird popup size in different window
