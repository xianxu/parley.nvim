-- Native manual folds, walked in one guarded Lua→VimL crossing per slice (#264).
-- Moved from tool_folds so the walk has one home; `tool_folds` owns *what* the
-- folds should be, this module owns how Neovim's native folds are read and changed.
local M={}
local line_reader=require('parley.line_reader')
function M.valid_target(buf,win)
    return vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_win_is_valid(win)
        and vim.api.nvim_win_get_buf(win)==buf
end
local valid_target=M.valid_target
-- A slice owns temporary editor state even after it loses publication authority.
-- Cleanup targets the captured window, never whichever window a callback selects.
function M.restore_window(buf,win,enabled,view,owner)
    if not valid_target(buf,win) then return end
    local ok,err=true,nil
    -- Retirement may run inside an option callback. Once it restores the
    -- operator preference, nested slices must not reinstate temporary suspension.
    if not (owner and owner.released_preference) then
        ok,err=pcall(vim.api.nvim_set_option_value,'foldenable',enabled,{win=win})
    end
    if valid_target(buf,win) then
        local restored,failure=pcall(vim.api.nvim_win_call,win,function()vim.fn.winrestview(view)end)
        if not restored and ok then ok,err=false,failure end
    end
    if not ok then error(err,0) end
end

-- mode 'delete' (default) removes every fold group in the span with zD.
-- mode 'inventory' changes nothing and returns each top-level group as
-- {start_0,end_0,open,nested} (#264): the outer fold's open state is preserved;
-- a nested group's inner folds are not (FoldDiff always recreates nested groups).
function M.walk(buf, win, first_0, last_0, command_limit, remember, current, owner, mode)
    mode = mode or 'delete'
    -- Reset first: an early return must not leave a previous call's count
    -- readable as if it described this one.
    M.last_iters = nil
    if not valid_target(buf, win) then return end
    if first_0 == nil or last_0 == nil or last_0 < first_0 then return end
    local next_row,done,folds
    local tick=vim.api.nvim_buf_get_changedtick(buf)
    local owner_generation=vim.b[buf].parley_fold_generation or 0
    local function live()
        return valid_target(buf,win) and vim.api.nvim_buf_get_changedtick(buf)==tick
            and (vim.b[buf].parley_fold_generation or 0)==owner_generation and (not current or current())
    end
    vim.api.nvim_win_call(win, function()
        if not live() then return end
        local line_count = vim.api.nvim_buf_line_count(buf)
        local last_row = math.min(last_0 + 1, line_count)
        local first_row = math.max(first_0 + 1, 1)
        if first_row > last_row then return end
        -- Cursor excursions also change topline/skipcol with an attached UI.
        -- Preserve only this fold walk's view, so intentional follow movement
        -- inside with_exchange_update's mutation remains effective.
        local view = vim.fn.winsaveview()
        local foldenable = vim.api.nvim_get_option_value("foldenable", { win = win })
        -- Walk fold-to-fold, not row-to-row, in ONE Lua→VimL crossing.
        -- chat_respond wraps every streamed chunk in with_exchange_update, so
        -- this is a per-chunk cost and it must not scale with exchange length:
        -- probing every row costs O(span) (3.7ms from Lua, 1.2ms natively, on a
        -- 600-row exchange), while `zj` jumps straight to the next fold start,
        -- making it O(number of folds present). zD deletes nested folds at the
        -- cursor too. If zj cannot move there is no further fold below, so stop.
        -- s:guard bounds the loop absolutely: `zD` refuses under a non-manual
        -- 'foldmethod' (E350), which would otherwise leave foldlevel unchanged
        -- and spin here forever. Bounding by the span means the worst case
        -- degrades to the row-walk cost rather than hanging the editor.
        -- 'foldenable' must be on for this walk: with it off, zj does not
        -- navigate and zD does not delete, so the loop silently no-ops and a
        -- stale fold survives the reconcile that exists to remove it —
        -- including one anchored on a question, the exact reported symptom.
        -- Reachable from a user's `set nofoldenable`, `zi`, or parley's own
        -- chat_toggle_tool_folds. Saved and restored so the operator's setting
        -- is not changed underneath them.
        local command = string.format([[
            let s:owner_buf = %d
            let s:owner_win = %d
            let s:owner_tick = %d
            let s:owner_generation = %d
            setlocal foldenable
            if bufnr() == s:owner_buf && win_getid() == s:owner_win && b:changedtick == s:owner_tick && get(b:, 'parley_fold_generation', 0) == s:owner_generation
            execute %d
            let s:guard = 0
            let s:eof = 0
            let s:broken = 0
            let s:states = []
            let s:groups = 0
            let s:ops = 0
            let s:limit = %d
            while line('.') <= %d && s:guard < s:limit && s:ops + 2 < s:limit
              if bufnr() != s:owner_buf || win_getid() != s:owner_win || b:changedtick != s:owner_tick || get(b:, 'parley_fold_generation', 0) != s:owner_generation | break | endif
              let s:guard += 1
              let s:level = foldlevel(line('.'))
              if bufnr() != s:owner_buf || win_getid() != s:owner_win || b:changedtick != s:owner_tick || get(b:, 'parley_fold_generation', 0) != s:owner_generation | break | endif
              if s:level > 0
                let s:groups += 1
                let s:ops += 1
                if %s
                  let s:before_s = foldclosed(line('.'))
                  let s:before_e = foldclosedend(line('.'))
                  silent! normal! zC
                  if bufnr() != s:owner_buf || win_getid() != s:owner_win || b:changedtick != s:owner_tick || get(b:, 'parley_fold_generation', 0) != s:owner_generation | break | endif
                  let s:fs = foldclosed(line('.'))
                  let s:fe = foldclosedend(line('.'))
                  if s:fs == -1 | let s:broken = line('.') | break | endif
                  let s:outer_open = s:before_s == -1 || s:before_s != s:fs || s:before_e != s:fe
                  silent! normal! zo
                  execute s:fs
                  let s:nested = foldlevel(s:fs) > 1
                  if !s:nested
                    silent! normal! zj
                    if line('.') > s:fs && line('.') <= s:fe | let s:nested = 1 | endif
                    execute s:fs
                  endif
                  if !s:outer_open
                    silent! normal! zC
                  endif
                  if bufnr() != s:owner_buf || win_getid() != s:owner_win || b:changedtick != s:owner_tick || get(b:, 'parley_fold_generation', 0) != s:owner_generation | break | endif
                  let s:ops += 4
                  call add(s:states, [s:fs - 1, s:fe - 1, s:outer_open, s:nested])
                  if s:fe >= line('$') | execute s:fe | let s:eof = 1 | break | endif
                  execute (s:fe + 1)
                  continue
                endif
                let s:was_open = foldclosed(line('.')) == -1
                if bufnr() != s:owner_buf || win_getid() != s:owner_win || b:changedtick != s:owner_tick || get(b:, 'parley_fold_generation', 0) != s:owner_generation | break | endif
                if s:was_open
                  silent! normal! zc
                  if bufnr() != s:owner_buf || win_getid() != s:owner_win || b:changedtick != s:owner_tick || get(b:, 'parley_fold_generation', 0) != s:owner_generation | break | endif
                  let s:ops += 1
                endif
                call add(s:states, [foldclosed(line('.')) - 1, s:was_open])
                if bufnr() != s:owner_buf || win_getid() != s:owner_win || b:changedtick != s:owner_tick || get(b:, 'parley_fold_generation', 0) != s:owner_generation | break | endif
                silent! normal! zD
                if bufnr() != s:owner_buf || win_getid() != s:owner_win || b:changedtick != s:owner_tick || get(b:, 'parley_fold_generation', 0) != s:owner_generation | break | endif
                if foldlevel(line('.')) > 0
                  break
                endif
              else
                let s:before = line('.')
                let s:ops += 1
                silent! normal! zj
                if bufnr() != s:owner_buf || win_getid() != s:owner_win || b:changedtick != s:owner_tick || get(b:, 'parley_fold_generation', 0) != s:owner_generation | break | endif
                if line('.') == s:before
                  break
                endif
              endif
            endwhile
            let b:parley_fold_clear_states = s:states
            let b:parley_fold_clear_iters = s:guard
            let b:parley_fold_clear_work = [s:groups, s:ops]
            let b:parley_fold_clear_next = line('.')
            let b:parley_fold_inventory_broken = s:broken
            let b:parley_fold_clear_done = s:eof || (s:guard < s:limit && s:ops + 2 < s:limit) || line('.') > %d
            endif
        ]], buf, win, tick, owner_generation, first_row, command_limit or (last_row - first_row + 2) * 2, last_row,
            mode == 'inventory' and 1 or 0, last_row)
        local ok, err = pcall(vim.api.nvim_exec2, command, {})
        -- Restore both even if the walk fails; its temporary editor state must
        -- not become the reader's new position or folding preference.
        M.restore_window(buf,win,foldenable,view,owner)
        if not ok then error(err, 0) end
        if not live() then return end
        -- Loop iterations, exposed so a test can assert this walks folds rather
        -- than rows without timing anything. A wall-clock assertion measures the
        -- machine as much as the algorithm.
        M.last_iters = vim.b[buf].parley_fold_clear_iters
        -- Count the existing native walk, including unsuccessful commands.
        -- Nested folds deleted together by zD constitute one outer group.
        local work = vim.b[buf].parley_fold_clear_work
        line_reader.record_work(buf, { fold_groups_visited = work[1], native_fold_ops = work[2] })
        if mode == 'inventory' then
            -- A fold that zC can't close (e.g. a non-manual foldmethod) would
            -- otherwise end the walk early while reporting it done.
            local broken = vim.b[buf].parley_fold_inventory_broken
            if broken and broken ~= 0 then error('fold inventory could not close the fold at row '..broken, 0) end
            folds = {}
            for _,entry in ipairs(vim.b[buf].parley_fold_clear_states or {}) do
                folds[#folds+1] = { start_0 = entry[1], end_0 = entry[2], open = entry[3] == 1, nested = entry[4] == 1 }
            end
        elseif remember then
            for _,entry in ipairs(vim.b[buf].parley_fold_clear_states or {}) do remember(entry[1],entry[2]==1) end
        end
        next_row=vim.b[buf].parley_fold_clear_next-1
        done=vim.b[buf].parley_fold_clear_done==1
    end)
    if mode == 'inventory' then return folds, next_row, done end
    return next_row,done
end

return M
