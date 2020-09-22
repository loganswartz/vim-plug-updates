if exists('g:plugin_updates_loaded')
	finish
endif
" let g:plugin_updates_loaded = 1

let g:plugin_updates_echo_total = 0
let g:plugin_updates_manifest = {}   " manifest of plugins and if they have updates
let s:check_results = {}   " temp manifest while checks are running


" Utils ===============================================

function! s:compareFiles(a, b)
	if readfile(a:a) ==# readfile(a:b)
		return 1   " true if identical
	else
		return 0   " otherwise false
	endif
endfunction


function! s:bool(var)
	if a:var
		return 1
	else
		return 0
endfunction


function! s:sum(numbers)
	return eval(join(a:numbers, '+'))
endfunction


" plug_call() from Vim-Plug
function! s:call(fn, ...)
	let shellslash = &shellslash
	try
		set noshellslash
		return call(a:fn, a:000)
	finally
		let &shellslash = shellslash
	endtry
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
	let s:check_results = {}
	for [name, plugin] in items(g:plugs)
		call jobstart('git -C ' . plugin.dir . ' remote update > /dev/null', {'plugin': [name, plugin], 'on_exit': function('s:checkUpdates')})
	endfor
endfunction


function! s:checkUpdates(...) dict
	let [name, plugin] = self.plugin
	let l:target = 'origin'
	if plugin.branch
		let l:target += '/' . plugin.branch
	endif
	call jobstart('git -C ' . plugin.dir . ' rev-list HEAD..' . l:target . ' --count', {'plugin': [name, plugin], 'on_exit': function('s:processUpdateCheck')})
endfunction


function! s:processUpdateCheck(jobs_id, data, event) dict
	let [name, plugin] = self.plugin
	if s:isGitRepo(plugin.dir)
		let l:result = s:bool(str2nr(a:data))
	else
		let l:result = 0
	endif

	let s:check_results[name] = l:result
	if len(g:plugs) ==# len(s:check_results)
		let g:plugin_updates_manifest = s:check_results
		call s:showPluginUpdates()
	endif
endfunction


function! s:checkVimPlugUpdate()
	let l:plug_src = 'https://github.com/junegunn/vim-plug.git'
	let l:plug_path = s:getVimPlugPath()
	if len(l:plug_path) < 0
		return 0
	endif

	let tmp = s:call('tempname') . '/plug.vim'
	try
		let out = jobstart(['git', 'clone', '--depth', '1', l:plug_src, tmp], {'vimplug_update_check': [tmp, l:plug_path], 'on_exit': function('s:processVimPlugCheck')})
	finally
		call delete(tmp)
	endtry
endfunction


function! s:processVimPlugCheck(job_id, data, event) dict
	let [new, old] = self.vimplug_update_check
	let g:vimplugHasUpdate = s:compareFiles(new, old)
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

