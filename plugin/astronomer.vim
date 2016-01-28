" astronomer.vim - Studies space, so you don't have to.
" Author: Rich Cheng <http://whileyouweregone.co.uk>
" Homepage: http://github.com/sedm0784/vim-astronomer
" Copyright: © 2015 Rich Cheng
" Licence: Astronomer uses the Vim licence.
" Version: 0.0.1

scriptencoding utf-8

if exists('g:loaded_astronomer') || &compatible
  finish
endif
let g:loaded_astronomer = 1

" 'smarttab' allows us to work with mixed-indent lines by setting 'shiftwidth'
" differently from 'softtabstop'.
set smarttab

" FIXME: Implement smarttab/softtabstop detection.

" FIXME: Implement warnings for if you've introduced mixed-line endings.
"        Either check on paste, or, probably better, before saving the file.
"        Need to disable this warning if the file had mixed line endings to
"        start with, though.

" FIXME: For tab-indented, apply a very mild highlight to spaces that
" immediately follow tabs at the start of a line.
"
" FIXME: Also apply mild highlight to broken-indent lines in an otherwise
" "pure" file.

" FIXME: Maybe create some mappings for easily finding the culprit lines that
" have caused 'list' to be switched on.

" Checks that Astronomer settings are configured correctly.
" Returns 0 if settings are correct. Returns > 0 if there is a problem.
function! s:check_configuration()
  " Undocumented values for deciding when to set width settings
  let g:astronomer_threshold_space_proportion = 20.0
  let g:astronomer_threshold_space_lines = 10
  let g:astronomer_threshold_space_confidence = 50.0
  let g:astronomer_line_start_proximity = 9
  let g:astronomer_line_start_weighting = 0.1

  if !exists('g:astronomer_widths')
    " Set default
    let g:astronomer_widths = [1, 2, 3, 4, 5, 6, 7, 8]
  else
    " Check if g:astronomer_widths is set up correctly
    " Check it's a list
    if type(g:astronomer_widths) != type([])
      echom "Astronomer Configuration Error: g:astronomer_widths must be a list of numbers"
      return 1
    endif

    " Check the list contains numbers
    for width in g:astronomer_widths
      if type(width) != type(0)
        echom "Astronomer Configuration Error: g:astronomer_widths contains non-number: " . width
        return 2
      endif
    endfor

    " Ensure the list is sorted
    call sort(g:astronomer_widths)
  endif

  " FIXME: Test g:astronomer_excludes
  " FIXME: Document g:astronomer_excludes
  if !exists('g:astronomer_excludes')
    " Set default
    let g:astronomer_excludes = ["nerdtree"]
  else
    " Check it's a list
    if type(g:astronomer_excludes) != type([])
      echom "Astronomer Configuration Error: g:astronomer_excludes must be a list of strings"
      return 3
    endif

    " Check the list contains strings
    for exclude in g:astronomer_excludes
      if type(exclude) != type("")
        echom "Astronomer Configuration Error: g:astronomer_excludes contains non-string " . exclude
        return 4
      endif
    endfor
  endif
  return 0
endfunction

" Based on the indentation data passed in, make a guess at the correct
" 'shiftwidth' for the file. Returns the value plus a "confidence" score.
function! s:make_recommendation(indent_change_dict)
  " Make a guess at the indentation size
  let indentation = -1
  let score = -1
  let total_score = 0
  for [i, s] in items(a:indent_change_dict)
    if s > score && index(g:astronomer_widths, str2nr(i)) != -1
      let indentation = i
      let score = s
    endif
    let total_score += s
  endfor
  if total_score == 0
    let total_score = 1
  endif
  return [indentation, score * 100.0 / total_score]
endfunction

" Run the indentation analysis.
"
" If 'silent' is set to false, then also display the results to the user. If
" it's true, then don't.
function! s:star_gaze(silent)
  let result = s:analyse()
  if !a:silent
    echom result
  endif
endfunction

" This is the main function that does everything.
" It returns a string to be displayed to the user if they called :StarGaze
" manually.
function! s:analyse()
  if s:check_configuration() != 0
    return ""
  endif

  " Never run for help buffers
  if &buftype ==# 'help'
    return "Help buffer. Skipping"
  endif

  " Don't run for excluded filetypes
  if exists('g:astronomer_excludes')
    for ft in g:astronomer_excludes
      if ft ==# &filetype
        return "Filetype '" . ft . "' is in g:astronomer_excludes. Skipping."
      endif
    endfor
  endif

  let tab_lines = 0
  let space_lines = 0
  " FIXME: Implement broken lines
  let broken_lines = 0
  " A string describing Astronomer's actions for output to the screen
  let star_chart = ""

  if exists('g:astronomer_super_secret_debug_option')
    let space_indent_dict = {}
  endif

  " Maps change in indent size to score for that change size
  let indent_change_dict = {}

  " Get counting!
  let previous_indent = 0
  for line in getline(1, line("$"))
    let tab_end = matchend(line, '^\t\+')
    let space_end = matchend(line, '^ \+')

    " We want to completely ignore whitespace-only lines This is because, as
    " the user cannot see the whitespace on such lines, it could easily not
    " match the surrounding indention style/size. (Which we discovered
    " in real-world files.)
    if line =~ '^\s*$'
      continue
    endif

    if tab_end > 0
      let tab_lines += 1
    else
      " Unindented lines have 0 spaces of indentation
      if space_end < 0
        let space_end = 0
      endif

      " N.B. For the purposes of calculating tab-size, we are ignoring
      " tab-indented lines entirely. This could technically result in
      " picking a multiple of the correct value (if all the lines at the
      " intermediate indentation are tab-indented), but we'd be unlucky to
      " actually come across such a file.

      if space_end != previous_indent
        " Weight changes close to start of line heavier than ones far away,
        " as they are more likely to be program-flow indentation and not
        " alignment indentation.
        let indent_change_score = 1.0
        if space_end < g:astronomer_line_start_proximity && previous_indent < g:astronomer_line_start_proximity
         let indent_change_score += g:astronomer_line_start_weighting * (space_end + previous_indent) / 2.0
        endif

        " Because of languages like Python where you can outdent multiple
        " levels in a single line, should we weight indents more heavily
        " than outdents? It will require multiple indents to get to a single
        " larger outdent, so perhaps this happens naturally.

        let indent_change = abs(space_end - previous_indent)
        let previous_indent = space_end
        if has_key(indent_change_dict, indent_change)
          let indent_change_dict[indent_change] += indent_change_score
        else
          let indent_change_dict[indent_change] = indent_change_score
        endif
      endif

      if space_end > 0
        let space_lines += 1
        if exists('g:astronomer_super_secret_debug_option')
          if has_key(space_indent_dict, space_end)
            let space_indent_dict[space_end] += 1
          else
            let space_indent_dict[space_end] = 1
          endif
        endif
      endif
    endif
  endfor

  let total_lines = tab_lines + space_lines + broken_lines

  if total_lines == 0
    return "Must be cloudy. (No indented lines found.)"
  endif

  let recommendation = -1

  " FIXME: When calculating changes, we completely ignore tab-indented lines.
  " Is this correct? Can we do better? (because the conceptual level of
  " indentation might be changing in the tab lines).

  " Apply settings
  if space_lines > 0

    " Take a guess at the shiftwidth.
    let [recommendation, confidence] = s:make_recommendation(indent_change_dict)

    " Are there enough space-indented lines for it to be a good idea for us to
    " set the width settings?
    let sufficient_space_indentation = 0

    if space_lines * 100.0 / total_lines < g:astronomer_threshold_space_proportion
      " If the file is heavily weighted away from space-indentation, only set
      " shift widths if:
      "
      "   a). There are a good absolute number of space indented lines.
      "
      "   b). We're confident in our guess (i.e. there's not lots of
      "       conflicting sizes of space indentation).
      "
      " We don't want to base it *only* on percentage because if e.g. we have
      " 100 space-indented lines in a 10,000 line file that are all indented
      " consistently, we *do* want to set the widths, even though they only
      " make up 1% of the total.
      "
      if space_lines >= g:astronomer_threshold_space_lines && confidence >= g:astronomer_threshold_space_confidence
        let sufficient_space_indentation = 1
      endif
    else
      let sufficient_space_indentation = 1
    endif

    if sufficient_space_indentation && recommendation > 0
      exec "setlocal shiftwidth=" . recommendation . " tabstop=". recommendation
      let star_chart = printf("shiftwidth=%d tabstop=%d ", recommendation, recommendation)
    endif
  endif

  if space_lines > 0 && tab_lines > 0
    " This file has mixed indentation
    setlocal list
    let star_chart = star_chart . "list "

    if space_lines > tab_lines
      " Mostly space-indented
      setlocal expandtab
      let star_chart = star_chart . "expandtab "
    elseif tab_lines > space_lines
      " Mostly tab-indented
      setlocal noexpandtab
      let star_chart = star_chart . "noexpandtab "
    endif
  else
    " This file has "pure" indentation
    setlocal nolist
    let star_chart = star_chart . "nolist "

    if space_lines > 0
      " This file is space-indented
      setlocal expandtab
      let star_chart = star_chart . "expandtab "
    elseif tab_lines > 0
      " This file is tab-indented
      setlocal noexpandtab
      let star_chart = star_chart . "noexpandtab "
    endif
  endif

  " Chop off trailing space
  let star_chart = substitute(star_chart, " *$", "", "")

  " Debug output
  if exists('g:astronomer_super_secret_debug_option')
    call astronomer#sunset(tab_lines, space_lines, broken_lines, indent_change_dict, space_indent_dict, recommendation, star_chart)
  endif

  if len(star_chart) == 0
    " This isn't possible. We'll always set list or nolist.
    return "Must be cloudy."
  else
    return ":set " . star_chart
  endif
endfunction

" Set up automatic commands
augroup astronomer
  autocmd!
  autocmd BufRead * call s:star_gaze(1)
  if exists('g:astronomer_super_secret_debug_option')
    autocmd WinEnter * call astronomer#check_for_morning()
  endif
augroup END

" Set up command line commands.
" Adding the g:astronomer_dark_matter variable to your vimrc prevents this.
if !exists('g:astronomer_dark_matter')
  command! StarGaze call s:star_gaze(0)
  command! -nargs=1 -complete=file Astronomize call astronomer#astronomize("<args>")

  " Add an extra command that removes lines with no change in indentation from
  " the output file. (Used during dev.)
  if exists('g:astronomer_super_secret_debug_option')
    command! -nargs=1 -complete=file AstronomerReduce call astronomer#reduce_file("<args>")
  endif
endif

