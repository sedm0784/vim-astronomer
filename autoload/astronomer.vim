scriptencoding

" Debug function that opens a debug buffer "__NightSky__"" in a split and
" outputs results
function! astronomer#sunset(tab_lines, space_lines, broken_lines, indent_change_dict, space_indent_dict, recommendation, star_chart)
  let total_lines = a:tab_lines + a:space_lines + a:broken_lines
  let this_window = winnr()
  let scratch_window = bufwinnr("__NightSky__")
  if (scratch_window == -1)
    botright split __NightSky__
    setlocal buftype=nofile
    setlocal bufhidden=delete
    setlocal nobuflisted
    setlocal noswapfile
    setlocal nospell
    let b:night_sky = 1
    diffoff
  else
    " Switch to buffer
    execute scratch_window . "wincmd w"
  endif
  setlocal noreadonly
  setlocal modifiable
  %d
  execute "resize " . (7)
  setlocal nowrap
  call setline(1, printf("   Tab lines: %4d: %3d%%", a:tab_lines, float2nr(a:tab_lines * 100.0 / total_lines)))
  call setline(2, printf(" Space lines: %4d: %3d%%", a:space_lines, float2nr(a:space_lines * 100.0 / total_lines)))
  call setline(3, printf("Broken lines: %4d: %3d%%", a:broken_lines, float2nr(a:broken_lines * 100.0 / total_lines)))
  call setline(4, printf("Raw Indents: %s", string(a:space_indent_dict)))
  let l = 5
  if a:space_lines > 0
    " Output information about method 3
    call setline(5, printf("Changes: %s", string(a:indent_change_dict)))
    call setline(6, printf("Recommendation: %d", a:recommendation))
    let l += 2
  endif
  call setline(l, a:star_chart)
  " Switch back to previous window. Not using `wincmd p` because minibufexpl seems to break it
  setlocal nomodifiable
  setlocal readonly
  setlocal nomodified
  execute this_window . "wincmd w"
endfunction

" Closes the __NightSky__ debug window if it's the last window left in the
" layout (effectively quitting Vim).
function! astronomer#check_for_morning()
  if winnr('$') == 1 && exists("b:night_sky") && b:night_sky == 1
    quit
  endif
endfunction

" Deletes lines that aren't space indented and lines where the
" space-indentation doesn't change.
function! astronomer#reduce_line(l)
  let line = getline(".")

  " Delete tab indented
  if line =~ '^\t'
    normal! dd
    return
  endif

  " Delete white-space only
  if line =~ '^\s*$'
    normal! dd
    return
  endif

  " Check indentation
  let space_end = matchend(line, '^ \+')
  if space_end < 0
    let space_end = 0
  endif

  " Delete lines where indentation doesn't change
  if space_end == s:current_indentation
    normal! dd
    return
  endif

  let indent_change = abs(space_end - s:current_indentation)
  let s:current_indentation = space_end

  " We're keeping this line. Update it with some info.
  execute "normal! I" . a:l . " (\<Esc>"
  execute "normal! a" . indent_change . ") "
  normal! j
  return
endfunction

" Creates a new file with name "file_name", and copies in only the lines where
" the space-indentation changes.
function! astronomer#reduce_file(file_name)
  try
    silent execute "saveas " . a:file_name
    call astronomer#reduce_to_changes()
    silent write
    echo "Reduced!"
  catch /^Vim\%((\a\+)\)\=:E13/
    echohl ErrorMsg
    echo "E13: File exists"
    echohl None
  catch
    echohl ErrorMsg
    echo v:exception
    echohl None
  endtry
endfunction

" Removes all the lines where the space-indentation doesn't change.
function! astronomer#reduce_to_changes()
  execute "normal! gg"
  let l = 1
  let s:current_indentation = 0
  while line("$") != line(".")
    call astronomer#reduce_line(l)
    let l += 1
  endwhile
  " Don't forget the last line
  call astronomer#reduce_line(l)
endfunction

" Creates a new file based on the current file, and copies in a version where
" all the non-indentation content is replaced with single 'x' characters.
function! astronomer#astronomize(file_name)
  try
    silent execute "saveas " . a:file_name
    call astronomer#anonomize()
    silent write
    echo "Astronomized!"
  catch /^Vim\%((\a\+)\)\=:E13/
    echohl ErrorMsg
    echo "E13: File exists"
    echohl None
  catch
    echohl ErrorMsg
    echo v:exception
    echohl None
  endtry
endfunction

" Replace all content after indentation with "x"
function! astronomer#anonomize()
  " \v    <- very magic
  " ^     <- start of line
  " (\s*) <- any amount of indentation (including none)
  " \S    <- one non-whitespace character
  " .*    <- any amount of anything else
  " $     <- end of line
  silent %substitute/\v^(\s*)\S.*$/\1x/
endfunction
