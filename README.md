# vim-plug-updates
A simple plugin that checks for plugin updates (and vim-plug updates too). Supports vim-plug and packer.nvim.

## Installation
Using vim-plug:
```vimscript
Plug 'loganswartz/vim_plug_updates'
```
Using packer.nvim:
```vimscript
use 'loganswartz/vim_plug_updates'
```

## Usage
In your vimrc:
```vimscript
augroup updates
    autocmd VimEnter * call CheckForPluginUpdates()
    " if using vim-plug
    autocmd VimEnter * call CheckForVimPlugUpdates()
augroup END
```
Now you can configure your statusline to show the number of detected updates.
Here's an example with lightline.vim:
```vimscript
let g:lightline = {
\     'colorscheme': 'onedark',
\     'active': {
\         'left': [
\             [ 'mode', 'paste' ],
\             [ 'gitbranch', 'readonly', 'filename', 'modified' ],
\             [ 'pluginupdates', 'vimplugupdate' ]
\         ]
\     },
\     'component_function': {
\         'gitbranch': 'fugitive#head',
\         'pluginupdates': 'PluginUpdatesIndicator',
\         'vimplugupdate': 'VimPlugUpdatesIndicator'
\     },
\ }
```
Then, when an update is detected, call `:PluginUpdate` or `:PluginUpgrade` to
run the appropriate update hook and refresh the update indicator.
