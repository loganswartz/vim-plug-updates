if exists('g:plugin_updates_loaded')
    finish
endif
let g:plugin_updates_loaded = 1

let g:plugin_updates_echo_total = 0
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
    for [name, plugin] in items(g:plugs)
        let l:options = {
            \'plugin': [name, plugin],
            \'on_exit': function('s:checkUpdates'),
        \}
        call jobstart('git -C ' . plugin.dir . ' remote update > /dev/null', l:options)
    endfor
endfunction

function! s:checkUpdates(...) dict
    let [name, plugin] = self.plugin
    let l:target = 'origin'
    if plugin.branch != ''
        let l:target = l:target . '/' . plugin.branch
    endif
    let l:options = {
        \'plugin': [name, plugin],
        \'on_stdout': function('s:processUpdateCheck'),
        \'stdout_buffered': 1,
    \}
    call jobstart('git -C ' . plugin.dir . ' rev-list HEAD..' . l:target . ' --count', l:options)
endfunction

function! s:processUpdateCheck(jobs_id, data, event) dict
    let [name, plugin] = self.plugin
    let l:diff = a:data[0]
    if s:isGitRepo(plugin.dir)
        let l:result = s:bool(str2nr(l:diff))
    else
        let l:result = 0
    endif

    let g:plugin_updates_manifest[name] = l:result
    if len(g:plugs) ==# len(g:plugin_updates_manifest)
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
    try
        let out = jobstart(['curl', '-L', l:plug_src, '-o', tmp], {'vimplug_update_check': [tmp, l:plug_path], 'on_exit': function('s:processVimPlugCheck')})
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

function! CheckForUpdates()
    call CheckForVimPlugUpdates()
    call CheckForPluginUpdates()
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
command! PluginUpdate PlugUpdate --sync | call CheckForUpdates()
command! PluginUpgrade PlugUpgrade | call CheckForUpdates()
