" astronomer.vim - Studies space, so you don't have to.
" Author: Rich Cheng <http://whileyouweregone.co.uk>
" Homepage: http://github.com/sedm0784/vim-astronomer
" Copyright: © 2015 Rich Cheng
" Licence: Astronomer uses the Vim licence.
" Version: 0.1.0

scriptencoding utf-8

if exists('g:loaded_astronomer') || &compatible
  finish
endif
let g:loaded_astronomer = 1

" FIXME: Implement warnings for if you've introduced mixed-line endings.
"        Either check on paste, or, probably better, before saving the file.
"        Need to disable this warning if the file had mixed line endings to
"        start with, though.

" FIXME: For tab-indented, (but not smarttab) apply a very mild highlight to
" spaces that immediately follow tabs at the start of a line.
"
" FIXME: Also apply mild highlight to broken-indent lines in an otherwise
" "pure" file.

" FIXME: If we turn on list, also set up commands (not mappings) that find
" tab-indented, space-indented, or broken indent lines. Probably makes sense
" to just have two, and include broken indent lines in *both*.

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
" 'shiftwidth' and 'tabstop' for the file. Returns the value plus a
" "confidence" score.
function! s:make_recommendation(indent_change_dict)
  " Make a guess at the indentation size
  let shiftwidth = -1
  let tabstop = -1
  let sw_score = -1
  let ts_score = -1
  let total_sw_score = 0
  let total_ts_score = 0
  for [tabs, tab_dict] in items(a:indent_change_dict)
    for [spaces, s] in items(tab_dict)
      if tabs == 0 && spaces == 0
        echom "Astronomer Error: Please report this to the author quoting error number #52"
      elseif (tabs == 1 && spaces < 0)
        " Looks like a smarttab!
        " FIXME: What about astronomer_widths in here?! Presumably need an extra
        "        setting for allowed tabstops.
        if s > ts_score
          let tabstop = 0 - spaces
          let ts_score = s
        endif
        let total_ts_score += s
      elseif (tabs == 0)
        " Space change
        if s > sw_score && index(g:astronomer_widths, str2nr(spaces)) != -1
          let shiftwidth = spaces
          let sw_score = s
        endif
        let total_sw_score += s
      elseif spaces != 0
        " Something else
        echom "Astronomer Error: Please report this to the author quoting error number #53"
      endif
    endfor
  endfor
  if total_sw_score == 0
    let total_sw_score = 1
  endif
  if total_ts_score == 0
    let total_ts_score = 1
  endif
  if tabstop == -1
    let tabstop = 0
  endif
  if ts_score == -1
    " FIXME: Is this right? Do we need something more clever?
    let ts_score = 0
  endif
  return [shiftwidth, sw_score * 100.0 / total_sw_score, tabstop + shiftwidth, ts_score * 100.0 / total_ts_score]
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
  let tabspace_lines = 0
  let broken_lines = 0
  if exists('g:astronomer_super_secret_debug_option')
    let space_indent_dict = {}
  endif

  " Maps change in indent to score for that change
  " It is a dictionary of dictionaries. The outer key is number of tabs
  " change, and the inner is the number of spaces change. (A single key would
  " be easier to read for debug purposes, but would require string parsing.)
  let indent_change_dict = {}

  " The number of changes which are consistent with smarttab indentation or
  " plain tab indentation, respectively
  let smarttab_changes = 0
  let tabindent_changes = 0

  " Get counting!
  let previous_indent = [0, 0]
  let previous_indent_end = 0
  for line in getline(1, line("$"))
    " We want to completely ignore whitespace-only lines This is because, as
    " the user cannot see the whitespace on such lines, it could easily not
    " match the surrounding indention style/size. (Which we discovered
    " in real-world files.)
    if line =~ '^\s*$'
      continue
    endif

    " Indentation can be null, tabs only, spaces only, tabs followed by
    " spaces, or "broken"
    let space_end = matchend(line, '^ \+')
    let tab_end = 0
    let indent_end = 0

    if line =~ '^\S'
      " Not indented
      let indent = [0, 0]
    elseif line =~ '^ \+\S'
      " Space indented
      let space_lines += 1
      let space_end = matchend(line, '^ \+')
      let indent_end = space_end
      let indent = [0, space_end]
    elseif line =~ '^\t\+ \+\S'
      " Tabspace indented
      let tabspace_lines += 1
      let tab_end = matchend(line, '^\t\+')
      let space_end = matchend(line, '^\t\+ \+')
      " FIXME: Not sure about this. Possibly only makes sense for
      " space-indented lines?
      let indent_end = space_end
      let indent = [tab_end, space_end - tab_end]
    elseif line =~ '^\t\+\S'
      " Tab indented
      let tab_lines += 1
      let tab_end = matchend(line, '^\t\+')
      let indent_end = tab_end
      let indent = [tab_end, 0]
    else
      let broken_lines += 1
    endif

    " Calculate the change in indentation and save it in the dictionary
    let tab_change = indent[0] - previous_indent[0]
    let space_change = indent[1] - previous_indent[1]
    if tab_change != 0 || space_change != 0
      " Consolidate indents and outdents: they should both be considered at
      " the same time and scored equally.
      if tab_change == 0
        let space_change = abs(space_change)
      elseif space_change == 0
        let tab_change = abs(tab_change)
      elseif tab_change == -1 && space_change > 0
        let tab_change = 1
        let space_change = -space_change
      endif
      if tab_change == 1 && space_change < 0
        let smarttab_changes += 1
      elseif space_change == 0 && (tab_change == 1 || tab_change == -1)
        " FIXME: this isn't quite right. It's not that space_change should be
        " zero--it's more that it shouldn't be a tabspace_line: test both if
        " necessary.
        let tabindent_changes += 1
      endif
      " FIXME: Maybe find changes which *aren't* consistent with smarttab, and
      " use these as evidence that the file is mixed indentation and not
      " smarttab

      " FIXME: smarttab changes must change from/to zero spaces, not just have
      " *any* change in spaces
      "
      " FIXME: Make sure we turn on list if there are ANY suspicious indent
      " changes when smarttab is enabled. (Not sure if we can detect this, but
      " try.)

      " We are only interested in "smarttab" lines (where tab_change = 1 and
      " space_change is negative, tab-only lines, and lines with no tabs at
      " all. (If performance is an issue, try ignoring tab-only lines: we
      " don't actually use them in make_recommendation()).
      if tab_change == 1 || space_change == 0 || (tab_change == 0 && tab_end == 0)

        " Weight changes close to start of line heavier than ones far away,
        " as they are more likely to be program-flow indentation and not
        " alignment indentation.
        let indent_change_score = 1.0
        if indent_end < g:astronomer_line_start_proximity && previous_indent_end < g:astronomer_line_start_proximity
         let indent_change_score += g:astronomer_line_start_weighting * (indent_end + previous_indent_end) / 2.0
        endif

        " Because of languages like Python where you can outdent multiple
        " levels in a single line, should we weight indents more heavily than
        " outdents? It will require multiple indents to get to a single larger
        " outdent, so perhaps this happens naturally.

        if has_key(indent_change_dict, tab_change)
          let tab_dict = indent_change_dict[tab_change]
        else
          let tab_dict = {}
        endif

        if has_key(tab_dict, space_change)
          let tab_dict[space_change] += indent_change_score
        else
          let tab_dict[space_change] = indent_change_score
        endif

        let indent_change_dict[tab_change] = tab_dict
      endif
    endif

    if exists('g:astronomer_super_secret_debug_option')
      " Make a note of the raw indent, for testing/debug
      if has_key(space_indent_dict, string(indent))
        let space_indent_dict[string(indent)] += 1
      else
        let space_indent_dict[string(indent)] = 1
      endif
    endif

    " FIXME: We probably need to do something clever to carry over the old
    " previous space indent if we switch between tab/space other indents in a
    " way that *doesn't* look like a smarttab, in order to handle mixed indent
    " files well.

    " FIXME: Maybe we even need to let the user configure which types of tabs
    " they want to detect/allow. And/or which types cause 'list' to be turned
    " on.

    let previous_indent = indent
    let previous_indent_end = indent_end

    " FIXME: Old comment. Still true?
    " N.B. For the purposes of calculating tab-size, we are ignoring
    " tab-indented lines entirely. This could technically result in
    " picking a multiple of the correct value (if all the lines at the
    " intermediate indentation are tab-indented), but we'd be unlucky to
    " actually come across such a file.
  endfor

  let total_lines = tabspace_lines + tab_lines + space_lines + broken_lines

  if total_lines == 0
    return "Must be cloudy. (No indented lines found.)"
  endif

  let [sw_recommendation, sw_confidence, ts_recommendation, ts_confidence] = s:make_recommendation(indent_change_dict)

  " FIXME: When calculating changes, we completely ignore switches between
  " space-indented and tab-indented. This is wrong Can we do better? (because
  " the conceptual level of indentation might be changing in the tab
  " lines).

  " Are there enough space-indented lines for it to be a good idea for us to
  " set the shiftwidth setting?
  let sufficient_space_indentation = 0

  if space_lines * 100.0 / (space_lines + tab_lines) < g:astronomer_threshold_space_proportion
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
    if space_lines >= g:astronomer_threshold_space_lines && sw_confidence >= g:astronomer_threshold_space_confidence
      let sufficient_space_indentation = 1
    endif
  else
    let sufficient_space_indentation = 1
  endif

  " A string describing Astronomer's actions for output to the screen
  let star_chart = ""
  let shiftwidth_set = 0

  if sw_recommendation > 0 && sufficient_space_indentation
    exec "setlocal shiftwidth=" . sw_recommendation
    let star_chart = star_chart . printf("shiftwidth=%d ", sw_recommendation)
    let shiftwidth_set = 1
  endif
  if shiftwidth_set
    " FIXME: Does it ever make sense to set tabstop if shiftwidth was not set?
    " I'm guessing not. If we do, make sure we also set smarttab and
    " softtabstop in next if block, below.
    if smarttab_changes > tabindent_changes && ts_recommendation > 0 && ts_confidence > g:astronomer_threshold_space_confidence
      " We set tabstop if we think smarttab is on and we are confident about our
      " guess.
      exec "setlocal tabstop=" . ts_recommendation
      let star_chart = star_chart . printf("tabstop=%d ", ts_recommendation)
    else
      exec "setlocal tabstop=" . &l:shiftwidth
      let star_chart = star_chart . printf("tabstop=%d ", &l:shiftwidth)
    endif
  endif

  if shiftwidth_set
    " 'smarttab' allows us to work with mixed-indent lines by setting 'shiftwidth'
    " differently from 'tabstop'.
    set smarttab
    set softtabstop=0
  endif

  " FIXME: Can we really detect smarttab simply by checking if sw matches ts?
  let smarttab = &l:shiftwidth != &l:tabstop

  if broken_lines > 0 || (!smarttab && space_lines > 0 && tab_lines > 0)
    " This file has mixed or broken indentation
    setlocal list
    let star_chart = star_chart . "list "

    if !smarttab && space_lines > tab_lines
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

    if !smarttab && space_lines > 0
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
    call astronomer#sunset(tabspace_lines, tab_lines, space_lines, broken_lines, indent_change_dict, space_indent_dict, sw_recommendation, sw_confidence, ts_recommendation, ts_confidence, star_chart)
  endif

  if len(star_chart) == 0
    " This isn't possible. We'll always set list or nolist.
    return "Must be cloudy. (Please report this to the author quoting error number #54)"
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
