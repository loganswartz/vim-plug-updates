if exists('g:plugin_updates_loaded')
    finish
endif
let g:plugin_updates_loaded = 1

let g:plugin_updates_echo_total = 0
let g:plugin_updates_manifest = {}   " manifest of plugins and if they have updates

" Utils ===============================================
function! g:DeterminePluginManager()
    if exists('g:plugs')
        return 'vim_plug'
    elseif exists(':PackerCompile')
        return 'packer'
    else
        return 0
    endif
endfunction

function! s:getPluginManagerInfo(key)
    let s:manager = g:DeterminePluginManager()

    let l:managers = {}
    let l:managers['vim_plug'] = {
                \ 'default_plugin_dir': stdpath('data') . '/plugged',
                \ 'plugins': s:getVimPlugPlugins()
                \ }
    let l:managers['packer'] = {
                \ 'default_plugin_dir': stdpath('data') . '/site/pack/packer',
                \ 'plugins': s:getPackerPlugins()
                \ }

    return l:managers[s:manager][a:key]
endfunction

function! s:getVimPlugPlugins()
    if g:DeterminePluginManager() != 'vim_plug'
        return {}
    endif

    let l:mapped = {}
    for [plugin, info] in items(g:plugs)
        let l:mapped[plugin] = info['dir']
    endfor
    return l:mapped
endfunction

function! s:getPackerPlugins()
    if g:DeterminePluginManager() != 'packer'
        return {}
    endif

    let l:data = luaeval('packer_plugins')
    let l:mapped = {}
    for [plugin, info] in items(l:data)
        let l:mapped[plugin] = info['path']
    endfor
    return l:mapped
endfunction

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
    return eval(join(a:numbers, '+'))
endfunction

function! s:getVimPlugPath()
    let l:plug_path = split(globpath(&rtp, '**/plug.vim'), '\n')
    if len(l:plug_path) != 1
        return ''
    else
        return l:plug_path[0]
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

" Internal funcs ======================================
function! s:checkRemotes()
    let g:plugin_updates_manifest = {}
    for [plugin, path] in items(s:getPluginManagerInfo('plugins'))
        let l:options = {
            \'plugin': [plugin, path],
            \'on_exit': function('s:checkUpdates'),
        \}
        call jobstart(['git', '-C', path, 'remote', 'update'], l:options)
    endfor
endfunction

function s:getCurrentBranch(path)
    return trim(system(['git', '-C', a:path, 'symbolic-ref', '--short', 'HEAD']))
endfunction

function! s:checkUpdates(...) dict
    let [plugin, path] = self.plugin
    let l:target = 'origin/' . s:getCurrentBranch(path)
    let l:options = {
        \ 'plugin': [plugin, path],
        \ 'on_stdout': function('s:processUpdateCheck'),
        \ 'stdout_buffered': 1,
    \}
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
    if len(s:getPluginManagerInfo('plugins')) ==# len(g:plugin_updates_manifest)
        call s:showPluginUpdates()
    endif
endfunction

function! s:checkVimPlugUpdate()
    let l:plug_src = 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
    let l:plug_path = s:getVimPlugPath()
    if len(l:plug_path) < 0
        return 0
    endif

    let tmp = tempname()
    let l:options = {
        \'vimplug_update_check': [tmp, l:plug_path],
        \'on_exit': function('s:processVimPlugCheck')
    \}
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

function! s:showPluginUpdates()
    let g:totalPluginUpdates = s:sum(values(g:plugin_updates_manifest))
    if exists('g:plugin_updates_echo_total') && g:plugin_updates_echo_total
        echo 'Updates: ' . g:totalPluginUpdates
    endif
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
    if exists('g:totalPluginUpdates') && g:totalPluginUpdates > 0
        return  '▲ ' . g:totalPluginUpdates
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
command! PluginUpdate PlugUpdate --sync | call CheckForPluginUpdates()
command! PluginUpgrade PlugUpgrade | call CheckForPluginUpdates()
