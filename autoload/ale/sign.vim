scriptencoding utf8
" Author: w0rp <devw0rp@gmail.com>
" Description: Draws error and warning signs into signcolumn

let b:dummy_sign_set_map = {}

if !hlexists('ALEErrorSign')
    highlight link ALEErrorSign error
endif

if !hlexists('ALEWarningSign')
    highlight link ALEWarningSign todo
endif

if !hlexists('ALEError')
    highlight link ALEError SpellBad
endif

if !hlexists('ALEWarning')
    highlight link ALEWarning SpellCap
endif

" Signs show up on the left for error markers.
execute 'sign define ALEErrorSign text=' . g:ale_sign_error
\   . ' texthl=ALEErrorSign'
execute 'sign define ALEWarningSign text=' . g:ale_sign_warning
\   . ' texthl=ALEWarningSign'
sign define ALEDummySign

function! ale#sign#FindCurrentSigns(buffer) abort
    " Matches output like :
    " line=4  id=1  name=ALEErrorSign
    " строка=1  id=1000001  имя=ALEErrorSign
    let l:pattern = 'id=\(\d\+\).*=ALE\(Warning\|Error\)Sign'

    redir => l:output
       silent exec 'sign place buffer=' . a:buffer
    redir END

    let l:id_list = []

    for l:line in split(l:output, "\n")
        let l:match = matchlist(l:line, l:pattern)

        if len(l:match) > 0
            call add(l:id_list, l:match[1] + 0)
        endif
    endfor

    return l:id_list
endfunction

" Given a loclist, combine the loclist into a list of signs such that only
" one sign appears per line. Error lines will take precedence.
" The loclist will have been previously sorted.
function! ale#sign#CombineSigns(loclist) abort
    let l:signlist = []

    for l:obj in a:loclist
        let l:should_append = 1

        if l:obj.lnum < 1
            " Skip warnings and errors at line 0, etc.
            continue
        endif

        if len(l:signlist) > 0 && l:signlist[-1].lnum == l:obj.lnum
            " We can't add the same line twice, because signs must be
            " unique per line.
            let l:should_append = 0

            if l:signlist[-1].type ==# 'W' && l:obj.type ==# 'E'
                " If we had a warning previously, but now have an error,
                " we replace the object to set an error instead.
                let l:signlist[-1] = l:obj
            endif
        endif

        if l:should_append
            call add(l:signlist, l:obj)
        endif
    endfor

    return l:signlist
endfunction

" This function will set the signs which show up on the left.
function! ale#sign#SetSigns(buffer, loclist) abort
    let l:signlist = ale#sign#CombineSigns(a:loclist)

    if len(l:signlist) > 0 || g:ale_sign_column_always
        if !get(g:ale_buffer_sign_dummy_map, a:buffer, 0)
            " Insert a dummy sign if one is missing.
            execute 'sign place ' .  g:ale_sign_offset
            \   . ' line=1 name=ALEDummySign buffer='
            \   . a:buffer

            let g:ale_buffer_sign_dummy_map[a:buffer] = 1
        endif
    endif

    " Find the current signs with the markers we use.
    let l:current_id_list = ale#sign#FindCurrentSigns(a:buffer)

    " Remove those markers.
    for l:current_id in l:current_id_list
        exec 'sign unplace ' . l:current_id . ' buffer=' . a:buffer
    endfor

    " Now set all of the signs.
    for l:index in range(0, len(l:signlist) - 1)
        let l:sign = l:signlist[l:index]
        let l:type = l:sign['type'] ==# 'W' ? 'ALEWarningSign' : 'ALEErrorSign'

        let l:sign_line = 'sign place ' . (l:index + g:ale_sign_offset + 1)
            \. ' line=' . l:sign['lnum']
            \. ' name=' . l:type
            \. ' buffer=' . a:buffer

        exec l:sign_line
    endfor

    if !g:ale_sign_column_always && len(l:signlist) > 0
        if get(g:ale_buffer_sign_dummy_map, a:buffer, 0)
            execute 'sign unplace ' . g:ale_sign_offset . ' buffer=' . a:buffer

            let g:ale_buffer_sign_dummy_map[a:buffer] = 0
        endif
    endif
endfunction
