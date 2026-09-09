local LIB_URL = "local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/sleepyhubrblx/saess/main/UiLibrary/Library.lua"))()"
local SCRIPTS_BASE = "local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/sleepyhubrblx/saess/main/scripts/Library.lua"))()"
local CACHE_TTL = 300
local CACHE = _G.SleepyLoaderCache or {}
_G.SleepyLoaderCache = CACHE

local function FetchText(url)
    local ok, src = pcall(game.HttpGet, game, url)
    if ok and type(src) == "string" and #src >= 100 then
        return true, src
    end
    return false, nil
end

local function FetchFresh(url, marker, minBytes)
    minBytes = minBytes or 100
    for attempt = 1, 4 do
        local target = url
        if attempt > 1 then
            local sep = string.find(url, "?", 1, true) and "&" or "?"
            target = url .. sep .. "cb=" .. tostring(os.time()) .. tostring(math.random(100000, 999999))
        end
        local ok, body = FetchText(target)
        if ok and #body >= minBytes and (marker == nil or string.find(body, marker, 1, true)) then
            return true, body
        end
        if attempt < 4 then task.wait(1) end
    end
    return false, nil
end

local function LibraryUsable(lib)
    return type(lib) == "table"
        and type(lib.CreateWindow) == "function"
        and lib.ChatFree == true
end

local function LoadLibrary()
    local entry = CACHE.lib
    if entry and os.clock() - entry.at <= CACHE_TTL and LibraryUsable(entry.value) then
        return entry.value
    end
    local ok, source = FetchFresh(LIB_URL, "ChatFree", 50000)
    if not ok then
        error("[Loader] Could not fetch the current UiLibary/Libary.lua (CDN still serving the old build). Re-run in a few seconds.", 0)
    end
    local chunk, compileErr = loadstring(source)
    if not chunk then
        error("[Loader] UiLibary/Libary.lua compile error: " .. tostring(compileErr), 0)
    end
    local ok2, lib = pcall(chunk)
    if not ok2 then
        error("[Loader] UiLibary/Libary.lua execution error: " .. tostring(lib), 0)
    end
    if not LibraryUsable(lib) then
        error("[Loader] UiLibary/Libary.lua is not the current chat-free build. Re-run the script.", 0)
    end
    CACHE.lib = { at = os.clock(), value = lib }
    return lib
end

local function LoadGameScript(lib, scriptName)
    local url = SCRIPTS_BASE .. scriptName
    local ok, content = FetchFresh(url, nil, 2000)
    if not ok then
        error("[Loader] Failed to download game script: " .. scriptName, 0)
    end
    local fullSource = "Library = _G.SleepyLib;\n" .. content
    local chunk, compileErr = loadstring(fullSource)
    if not chunk then
        error("[Loader] Game script compile error (" .. scriptName .. "): " .. tostring(compileErr), 0)
    end
    local ok2, err = pcall(chunk)
    if not ok2 then
        error("[Loader] Game script runtime error (" .. scriptName .. "): " .. tostring(err), 0)
    end
end

local GAME_MAP = {
    [107778070777162]  = "StealAnEgg.lua",
    [142823291]        = "Mm2.lua",
}

local function ResolveScript(pid)
    return GAME_MAP[pid] or "Universal.lua"
end

local placeId = game.PlaceId
local scriptName = ResolveScript(placeId)

local Library = LoadLibrary()
_G.SleepyLib = Library
LoadGameScript(Library, scriptName)
