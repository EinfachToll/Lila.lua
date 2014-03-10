#!/usr/bin/env lua

--[[ The MIT License (MIT)

Copyright (c) 2014 Daniel Schemala

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. ]]

LILA_FILE                           = "~/lilaliste"             -- the file where Lila stores applications and other data

UPDATE_COMMAND                      = "aktualisieren"
UPDATE_DEBIAN_COMMAND               = "debian-aktualisieren"    -- the command that calls update-menus; empty string disables it
ALIAS_COMMAND                       = "ist"
REMOVE_COMMAND                      = "weg"

DMENU_POS                           = "top"                     -- "top" or "bottom"
DMENU_MATCH_CASE                    = false
DMENU_LINES                         = 0                         -- 0 means horizontally, > 0 vertically with that many lines
DMENU_EXTRA_PARAMS                  = ""
DMENU_BACKGROUND_COLOR              = "#002B36"
DMENU_FONT_COLOR                    = "#839496"
DMENU_SELECTED_BACKGROUND_COLOR     = "#657B83"
DMENU_SELECTED_FONT_COLOR           = "#EEE8D5"

TERMINAL_PROGRAM                    = "xterm -e"




function dmenuparams()
    params = {}

    if DMENU_POS == "bottom" then
        table.insert(params, "-b")
    end

    if not DMENU_MATCH_CASE then
        table.insert(params, "-i")
    end

    table.insert(params, "-l "..DMENU_LINES)

    table.insert(params, DMENU_EXTRA_PARAMS)

    table.insert(params, '-nb "'..DMENU_BACKGROUND_COLOR..'"')
    table.insert(params, '-nf "'..DMENU_FONT_COLOR..'"')
    table.insert(params, '-sb "'..DMENU_SELECTED_BACKGROUND_COLOR..'"')
    table.insert(params, '-sf "'..DMENU_SELECTED_FONT_COLOR..'"')

    return params
end


function calldmenu(commands)
    local paramstring = table.concat(dmenuparams(), " ")
    local cmd = 'dmenu '..paramstring..' <<EOF\n'..table.concat(commands, '\n')..'\nEOF'
    local f = assert(io.popen(cmd, 'r'))
    local s = assert(f:read('*a'))
    f:close()
    return s
end


function sortbyfrecency(commands)
    local result = {}
    local now = os.time()
    for cmd, access in pairs(commands) do
        --local modified_rank = -access.rank * math.log(4.02745e-7 * (now - access.time))
        local modified_rank = access.rank / (now - access.time + 1) -- +1 to avoid division by 0
        if access.term then
            cmd = cmd..";"
        end
        table.insert(result, {cmd, modified_rank})
    end
    table.sort(result, function (c1,c2) return c1[2] > c2[2] end)
    for i = 1, #result do
        result[i] = result[i][1]
    end
    return result
end


-- look for ALIAS keyword and alter aliases and commands
-- If the new alias is already an existing command, the latter is silently
-- overwritten. Do we care? No.
function processalias(command, infos)
    local foundaliascommand = false
    local target, new_alias = command:match('^(.-)%s+'..ALIAS_COMMAND..'%s+(.-)%s*$')

    if new_alias then
        foundaliascommand = true
    end

    if foundaliascommand then

        local terminal = false
        if target:sub(-1) == ";" then
            target = target:sub(1, -2)
            terminal = true
        end

        if infos.aliases[target] then                   -- rename existing alias
            infos.aliases[new_alias] = infos.aliases[target]
            infos.aliases[target] = nil
            infos.commands[new_alias] = infos.commands[target]
            infos.commands[new_alias].term = terminal
            infos.commands[target] = nil
        elseif infos.commands[target] then              -- new alias for existing command
            infos.aliases[new_alias] = target
            infos.commands[new_alias] = infos.commands[target]
            infos.commands[new_alias].term = terminal
            infos.commands[target] = nil
        else                                            -- new command plus alias
            infos.aliases[new_alias] = target
            infos.commands[new_alias] = {rank = 2, time = os.time(), term = terminal}
        end
    end

    return foundaliascommand, infos
end


function processdebianupdate(command, infos)
    if command:sub(-1) == ";" then
        command = command:sub(1, -2)
    end

    local foundupdatecommand = (command == UPDATE_DEBIAN_COMMAND)

    if foundupdatecommand then
        local now = os.time()
        local programs = assert(io.popen('update-menus --stdout', 'r'))
        for p in programs:lines() do
            local cmd, needs, title = p:match('command="([^"]+)".-needs="([^"]+)".-title="([^"]+).*')
            if cmd then
                infos.aliases[title] = cmd
                infos.commands[title] = {rank = 2, time = now, term = (needs:lower() == "text")}
            end
        end
        programs:close()
    end

    return foundupdatecommand, infos
end


-- look for UPDATE keyword and, if present, add not yet existing commands to our table
function processupdate(command, infos)

    if command:sub(-1) == ";" then
        command = command:sub(1, -2)
    end

    local foundupdatecommand = (command == UPDATE_COMMAND)

    if foundupdatecommand then
        local now = os.time()
        -- ask the program 'dmenu_path' for a list of available commands
        local programs = assert(io.popen('dmenu_path', 'r'))
        for p in programs:lines() do
            if not infos.commands[p] and not infos.exclude[p] then
                infos.commands[p] = {rank = 1, time = now, term = false}
            end
        end

        -- don't forget to include the UPDATE_COMMAND itself
        if not infos.commands[UPDATE_COMMAND] and not infos.exclude[UPDATE_COMMAND] then
            infos.commands[UPDATE_COMMAND] = {rank = 0, time = now, term = false}
        end
        if UPDATE_DEBIAN_COMMAND ~= "" and not infos.commands[UPDATE_DEBIAN_COMMAND] and not infos.exclude[UPDATE_DEBIAN_COMMAND] then
            infos.commands[UPDATE_COMMAND] = {rank = 0, time = now, term = false}
        end

        programs:close()
    end

    return foundupdatecommand, infos
end


-- look for REMOVE keyword for removing aliases or commands
function processremove(command, infos)
    local foundremovecommand = false
    local remove_this = command:match('^(.-)%s+'..REMOVE_COMMAND..'%s*')

    if remove_this then
        foundremovecommand = true
    end

    if foundremovecommand then

        if remove_this:sub(-1) == ";" then
            remove_this = remove_this:sub(1, -2)
        end

        if infos.aliases[remove_this] then                 -- remove alias
            local target = infos.aliases[remove_this]
            infos.commands[target] = infos.commands[remove_this]
            infos.commands[remove_this] = nil
            infos.aliases[remove_this] = nil
        elseif infos.commands[remove_this] then            -- remove command
            infos.exclude[remove_this] = true
            infos.commands[remove_this] = nil
        end
    end

    return foundremovecommand, infos
end


function executecommand(chosenresult, infos)

    local terminal = false
    if chosenresult:sub(-1) == ";" then
        chosenresult = chosenresult:sub(1, -2)
        terminal = true
    end

    local cmd = infos.aliases[chosenresult] or chosenresult

    if infos.exclude[cmd] then
        infos.exclude[cmd] = nil
    end

    if terminal then
        cmd = TERMINAL_PROGRAM.." "..cmd
    end

    local success = os.execute(cmd.." &")

    if success then
        if infos.commands[chosenresult] then
            local old_rank = infos.commands[chosenresult].rank
            infos.commands[chosenresult].rank = old_rank + 1
            infos.commands[chosenresult].time = os.time()
            infos.commands[chosenresult].term = terminal
        else
            infos.commands[chosenresult] = {rank = 2, time = os.time(), term = terminal}
        end
    end
    return infos
end


function readlilafile()
    local lilafileexists, lilafilehandle = pcall(io.input, LILA_FILE)

    local infos = {aliases = {}, commands = {}, exclude = {}}

    if lilafileexists then
        for aliasdefinition in lilafilehandle:lines() do
            if aliasdefinition == "-" then
                break
            end

            local alias, target = aliasdefinition:match("([^\t]+)\t(.+)")
            infos.aliases[alias] = target
        end

        for commanddef in lilafilehandle:lines() do
            if commanddef == "-" then
                break
            end

            local ra, ti, te, cmd = commanddef:match("(%S+)\t(%S+)\t(.)\t(.+)")
            infos.commands[cmd] = {rank = ra, time = ti, term = (te == "T")}
        end

        for excludedef in lilafilehandle:lines() do
            infos.exclude[excludedef] = true
        end

        lilafilehandle:close()
    else
        -- at least include the UPDATE_COMMAND
        infos.commands[UPDATE_COMMAND] = {rank = 0, time = os.time(), term = false}
        if UPDATE_DEBIAN_COMMAND ~= "" then
            infos.commands[UPDATE_DEBIAN_COMMAND] = {rank = 0, time = os.time(), term = false}
        end
    end

    return infos
end


function writelilafile(infos)
    local aliasdefinitions = {}
    for alias, target in pairs(infos.aliases) do
        table.insert(aliasdefinitions, alias.."\t"..target.."\n")
    end

    local commanddefinitions = {}
    for cmd, access in pairs(infos.commands) do
        table.insert(commanddefinitions, access.rank.."\t"..access.time..(access.term and "\tT\t" or "\tX\t")..cmd.."\n")
    end

    local excludedefinitions = {}
    for cmd, _ in pairs(infos.exclude) do
        table.insert(excludedefinitions, cmd)
    end

    local lilafileexists, lilafilehandle = pcall(io.output, LILA_FILE)
    lilafilehandle:write(table.concat(aliasdefinitions))
    lilafilehandle:write("-\n")
    lilafilehandle:write(table.concat(commanddefinitions))
    lilafilehandle:write("-\n")
    lilafilehandle:write(table.concat(excludedefinitions, "\n"))
    lilafilehandle:close()
end


function main()
    if LILA_FILE:sub(1, 2) == "~/" then
        LILA_FILE = LILA_FILE:gsub("^~/", "/home/"..os.getenv("USER").."/", 1)
    end
    local infos = readlilafile()
    local sortedcommands = sortbyfrecency(infos.commands)
    local chosenresult = calldmenu(sortedcommands)

    if chosenresult == '' then
        return
    end

    local processed, infos = processalias(chosenresult, infos)

    if not processed then
        processed, infos = processremove(chosenresult, infos)
    end

    if not processed then
        processed, infos = processupdate(chosenresult, infos)
    end

    if not processed then
        processed, infos = processdebianupdate(chosenresult, infos)
    end

    if not processed then
        infos = executecommand(chosenresult, infos)
    end

    writelilafile(infos)
end


main()
