if exists('g:plugin_updates_loaded')
    finish
endif
let g:plugin_updates_loaded = 1

let g:plugin_updates_manifest = {}   " manifest of plugins and if they have updates

" Utils ===============================================
function! s:compareFiles(a, b)
    let output = system(['cmp', '-s', a:a, a:b])
    return v:shell_error
endfunction

function! s:bool(var)
    if a:var
        return 1
    else
        return 0
    endif
endfunction

function! s:sum(numbers)
    if len(a:numbers) > 0
        return eval(join(a:numbers, '+'))
    else
        return 0
    endif
endfunction

function! s:isGitRepo(path)
    let result = trim(system(['git', '-C', a:path, 'rev-parse', '--is-inside-work-tree']))
    if result ==# 'true'
        return 1
    else
        return 0
    endif
endfunction

function s:getCurrentBranch(path)
    return trim(system(['git', '-C', a:path, 'symbolic-ref', '--short', 'HEAD']))
endfunction

" Plugins =============================================
function! s:determinePluginManager()
    if exists('g:plugs')
        return 'vim_plug'
    elseif exists(':PackerCompile')
        return 'packer'
    else
        return 0
    endif
endfunction

function! s:getPluginManagerInfo(key)
    let s:manager = s:determinePluginManager()

    let l:managers = {}
    let l:managers['vim_plug'] = {
                \ 'default_plugin_dir': stdpath('data') . '/plugged',
                \ 'plugins': s:getVimPlugPlugins(),
                \ 'update_hook': {-> execute('PlugUpdate --sync')},
                \ 'upgrade_hook': {-> execute('PlugUpgrade')},
                \ }
    let l:managers['packer'] = {
                \ 'default_plugin_dir': stdpath('data') . '/site/pack/packer',
                \ 'plugins': s:getPackerPlugins(),
                \ 'update_hook': {-> execute('lua require("packer").update()')},
                \ 'upgrade_hook': {-> execute('lua require("packer").update("packer.nvim")')},
                \ }

    return l:managers[s:manager][a:key]
endfunction

function! s:getVimPlugPlugins()
    if s:determinePluginManager() != 'vim_plug'
        return {}
    endif

    let l:mapped = {}
    for [plugin, info] in items(g:plugs)
        let l:mapped[plugin] = info['dir']
    endfor
    return l:mapped
endfunction

function! s:getPackerPlugins()
    if s:determinePluginManager() != 'packer'
        return {}
    endif

    let l:data = luaeval('packer_plugins')
    let l:mapped = {}
    for [plugin, info] in items(l:data)
        let l:mapped[plugin] = info['path']
    endfor
    return l:mapped
endfunction

function! s:getVimPlugPath()
    let l:plug_path = split(globpath(&rtp, '**/plug.vim'), '\n')
    if len(l:plug_path) != 1
        return ''
    else
        return l:plug_path[0]
    endif
endfunction

function! s:checkRemotes()
    let g:plugin_updates_manifest = {}
    for [plugin, path] in items(s:getPluginManagerInfo('plugins'))
        let l:options = {
            \ 'plugin': [plugin, path],
            \ 'on_exit': function('s:checkUpdates'),
        \ }
        call jobstart(['git', '-C', path, 'remote', 'update'], l:options)
    endfor
endfunction

function! s:checkUpdates(...) dict
    let [plugin, path] = self.plugin
    let l:target = 'origin/' . s:getCurrentBranch(path)
    let l:options = {
        \ 'plugin': [plugin, path],
        \ 'on_stdout': function('s:processUpdateCheck'),
        \ 'stdout_buffered': 1,
    \ }
    call jobstart(['git', '-C', path, 'rev-list', 'HEAD..' . l:target, '--count'], l:options)
endfunction

function! s:processUpdateCheck(jobs_id, data, event) dict
    let [plugin, path] = self.plugin
    let l:diff = a:data[0]
    if s:isGitRepo(path)
        let l:result = s:bool(str2nr(l:diff))
    else
        let l:result = 0
    endif

    let g:plugin_updates_manifest[plugin] = l:result
endfunction

function! s:checkVimPlugUpdate()
    let l:plug_src = 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
    let l:plug_path = s:getVimPlugPath()
    if len(l:plug_path) < 0
        return 0
    endif

    let tmp = tempname()
    let l:options = {
        \ 'vimplug_update_check': [tmp, l:plug_path],
        \ 'on_exit': function('s:processVimPlugCheck')
    \ }
    try
        let out = jobstart(['curl', '-L', l:plug_src, '-o', tmp], l:options)
    finally
        call delete(tmp)
    endtry
endfunction

function! s:processVimPlugCheck(job_id, data, event) dict
    let [new, old] = self.vimplug_update_check
    try
        let g:vimplugHasUpdate = s:compareFiles(new, old)
    catch E484
    endtry
endfunction

function! TotalPluginUpdates()
    return s:sum(values(g:plugin_updates_manifest))
endfunction

" Public functions ====================================
function! CheckForPluginUpdates()
    call s:checkRemotes()
endfunction

function! CheckForVimPlugUpdates()
    call s:checkVimPlugUpdate()
endfunction

function! HasUpdates(plugin)
    return get(g:plugin_updates_manifest, plugin, 0)
endfunction

function! PluginsWithUpdates()
    let l:has_updates = []
    for [name, has_update] in items(g:plugin_updates_manifest)
        if has_update
            call add(l:has_updates, name)
        endif
    endfor
    return l:has_updates
endfunction

function! PluginUpdatesIndicator()
    let l:updates = TotalPluginUpdates()
    if l:updates > 0
        return  '▲ ' . l:updates
    else
        return ''
    endif
endfunction

function! VimPlugUpdatesIndicator()
    if exists('g:vimplugHasUpdate') && g:vimplugHasUpdate
        return '🔌 Update Available'
    else
        return ''
    endif
endfunction

command! PluginsWithUpdates echo PluginsWithUpdates()
command! CheckForPluginUpdates call CheckForPluginUpdates()

augroup plugin_updates
    if !exists('g:plugin_updates_disable_startup_check')
        autocmd VimEnter * call CheckForPluginUpdates()
    endif
    if !exists('g:plugin_updates_disable_vim_plug_check') && s:determinePluginManager() ==? 'vim-plug'
        autocmd VimEnter * call CheckForVimPlugUpdates()
    endif

    if s:determinePluginManager() ==? 'packer'
        autocmd User PackerComplete call CheckForPluginUpdates()
    elseif s:determinePluginManager() ==? 'vim-plug'
        autocmd BufWinLeave * if &ft ==? 'vim-plug' | call CheckForPluginUpdates()
    endif
augroup END
