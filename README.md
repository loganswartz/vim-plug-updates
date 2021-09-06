# vim-plug-updates
A simple plugin that checks for plugin updates (and vim-plug updates too).
Supports vim-plug and packer.nvim.

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
Configure your statusline to show the number of detected updates. Here's an
example from my own vimrc, using lightline.vim:
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
This will render an segment that looks like this: `▲ 3`

## Configuration
The indicator total will update automatically based on autocommands. By
default, it checks for updates on startup, as well as certain events for
vim-plug or packer.nvim. For vim-plug, it updates after any vim-plug window
closes, and for packer, it checks on the PackerComplete User autocommand. This
behavior can be modified by setting certain global variables to true (1) in
your vimrc:

|                 Variable                  |                        Description                  |
|-------------------------------------------|-----------------------------------------------------|
| `g:plugin_updates_disable_startup_check`  | Disable update check on startup                     |
| `g:plugin_updates_disable_vim_plug_check` | Disable update check on startup for vim-plug itself |
