local CFG = {
    LIB_URL      = "local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/sleepyhubrblx/saess/main/UiLibrary/Library.lua"))()",
    
    SCRIPTS_BASE = "local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/sleepyhubrblx/saess/main/scripts/Library.lua"))()",
   
    FALLBACK  = "Universal.lua",
}

local GAME_NAMES = {
    [107778070777162]  = "Steal an Egg",
    [142823291]        = "MM2",
}

local LIB_MARKER  = "ChatFree"   
local CACHE_TTL   = 300          

local SLEEPY_CACHE = _G.SleepyLoaderCache or {}
_G.SleepyLoaderCache = SLEEPY_CACHE

local function cacheGet(key)
    local entry = SLEEPY_CACHE[key]
    if entry and os.clock() - entry.at <= CACHE_TTL then
        return entry.value
    end
    return nil
end
local function cacheSet(key, value)
    SLEEPY_CACHE[key] = { at = os.clock(), value = value }
end

local function urlencode(s)
    return (string.gsub(tostring(s), "[^%w%-%_%.%~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function GetUserId()
    local ok, plr = pcall(function() return game:GetService("Players").LocalPlayer end)
    if ok and plr then
        local o2, uid = pcall(function() return plr.UserId end)
        if o2 then return tostring(uid) end
    end
    return ""
end

local function GetExecutor()
    local ok, name = pcall(identifyexecutor)
    if ok and type(name) == "string" then return name end
    return ""
end

local GAME_MAP = {
    [107778070777162]  = "StealAnEgg.lua",          -- Ein Ei stehlen 🥚
    [142823291]        = "Mm2.lua",                 -- MM2 🔪
    -- [PlaceId] = "Script.lua",  ← füg neue Games hier hinzu
}

local function ResolveScript(pid, gid)
    return GAME_MAP[pid] or GAME_MAP_BY_GAMEID[gid] or CFG.FALLBACK
end

local function Track(kind)
    if not CFG.TRACK_URL then return end
    local pid = game.PlaceId
    local gid = game.GameId
    local sname = ResolveScript(pid, gid)
    local params = {
        kind = kind,
        game = GAME_NAMES[pid] or sname:gsub("%.lua$", ""),
        place_id = tostring(pid),
        game_id = tostring(gid),
        user_id = GetUserId(),
        executor = GetExecutor(),
    }
    local parts = {}
    for k, v in pairs(params) do
        parts[#parts + 1] = k .. "=" .. urlencode(v)
    end
    local url = CFG.TRACK_URL .. "?" .. table.concat(parts, "&")
    pcall(function()
        if type(request) == "function" then
            request({ Url = url, Method = "GET" })
        else
            game:HttpGet(url)
        end
    end)
end

local function FetchRaw(url)
    if type(request) == "function" then
        local ok, req = pcall(request, { Url = url, Method = "GET" })
        if ok and type(req) == "table" and req.StatusCode == 200
            and type(req.Body) == "string" and #req.Body >= 100 then
            return true, req.Body
        end
    end
    local ok, src = pcall(game.HttpGet, game, url)
    if ok and type(src) == "string" and #src >= 100 then
        return true, src
    end
    return false, nil
end

local function CacheBust(url)
    local sep = string.find(url, "?", 1, true) and "&" or "?"
    return url .. sep .. "cb=" .. tostring(os.time()) .. tostring(math.random(100000, 999999))
end

local function FetchApiRaw(apiPath)
    if type(request) ~= "function" then return false, nil end
    local ok, req = pcall(request, {
        Url = "https://api.github.com/repos/sleepyhubrblx/saess/contents/" .. apiPath,
        Method = "GET",
        Headers = {
            ["Accept"]     = "application/vnd.github.raw+json",
            ["User-Agent"] = "sleepy-hub",
        },
    })
    if ok and type(req) == "table" and req.StatusCode == 200
        and type(req.Body) == "string" and #req.Body >= 100 then
        return true, req.Body
    end
    return false, nil
    
end
local function FetchFresh(url, marker, minBytes, apiPath)
    minBytes = minBytes or 100
    for attempt = 1, 3 do
        local target = attempt == 1 and url or CacheBust(url)
        local ok, body = FetchRaw(target)
        if ok and #body >= minBytes and (marker == nil or string.find(body, marker, 1, true)) then
            return true, body, attempt
        end
        if attempt < 3 then task.wait(1) end
    end
    if apiPath then
        local ok, body = FetchApiRaw(apiPath)
        if ok and #body >= minBytes and (marker == nil or string.find(body, marker, 1, true)) then
            return true, body, 4
        end
    end
    return false, nil, 4
end

-- ══════════════════════════════════════════════════════════════════════════════
-- LOAD LIBRARY (download raw source → loadstring → execute)
-- Now fully open source: the library is served as plain Lua, no encryption.
-- ══════════════════════════════════════════════════════════════════════════════
local function LibraryUsable(lib)
    return type(lib) == "table"
        and type(lib.CreateWindow) == "function"
        and lib.ChatFree == true      -- only the current chat-free build is accepted
end

local function LoadLibrary()
   
    local cached = cacheGet("lib")
    if LibraryUsable(cached) then
        print("[Loader] Library reused from cache (v" .. tostring(cached.Version or "?") .. ") — no download needed.")
        return cached
    end

    local ok, source, attempt = FetchFresh(CFG.LIB_URL, LIB_MARKER, 50000, "UiLibary/Libary.lua")
    if not ok then
        error("[Loader] Could not fetch the CURRENT UI library — GitHub's CDN is still serving the old build. Re-run the script in a few seconds.", 0)
    end

    local chunk, compileErr = loadstring(source)
    if not chunk then
        error("[Loader] Library compile error: " .. tostring(compileErr), 0)
    end
    local ok2, lib = pcall(chunk)
    if not ok2 then
        error("[Loader] Library execution error: " .. tostring(lib), 0)
    end
    if not LibraryUsable(lib) then
        error("[Loader] Library loaded but it is NOT the current chat-free build (stale copy). Refusing to run it — re-run the script.", 0)
    end

    cacheSet("lib", lib)
    if attempt >= 4 then
        print("[Loader] CDN served a stale copy — fetched the current library from the fresh API fallback.")
    elseif attempt > 1 then
        print("[Loader] CDN served a stale copy — refetched the current library (attempt " .. attempt .. ").")
    end
    print("[Loader] Library v" .. tostring(lib.Version or "?") .. " ready.")
    return lib
end

local function LoadGameScript(lib, scriptName)
    local content = cacheGet("script:" .. scriptName)
    local fromCache = content ~= nil
    if not fromCache then
        local url = CFG.SCRIPTS_BASE .. scriptName
        local ok, body = FetchFresh(url, nil, 2000, "scripts/" .. scriptName)
        if not ok then
            error("[Loader] Failed to download game script: " .. scriptName, 0)
        end
        content = body
        cacheSet("script:" .. scriptName, content)
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
    return fromCache
end

local placeId = game.PlaceId
local gameId = game.GameId
local scriptName = ResolveScript(placeId, gameId)

print("[Loader] PlaceId:", placeId, " GameId:", gameId, "→", scriptName)

local t0 = os.clock()
local Library = LoadLibrary()

_G.SleepyLib = Library

local scriptCached = LoadGameScript(Library, scriptName)
print(string.format("[Loader] %s is now running (script %s, total %.2fs).",
    scriptName, scriptCached and "from cache" or "downloaded", os.clock() - t0))

Track("launch")
pcall(task.spawn, function()
    while true do
        task.wait(25)
        Track("heartbeat")
    end
end)
