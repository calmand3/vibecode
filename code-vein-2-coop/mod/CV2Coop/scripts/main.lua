-- CV2Coop probe (phase 0)
--
-- Answers one question: can Unreal's built-in networking be switched on in
-- Code Vein II, and how far does a second player get?
--
-- Console commands (the hotkeys below do not work yet):
--   coop_host        HOST: at the title screen, enter the hub as a LAN host
--   coop_join [ip]   GUEST: at the title screen, connect to the host
--   coop_dump        dump what the game is running (classes, map, net role)
--   coop_state       session and network status
-- Everything is logged with the prefix [CV2Coop] in UE4SS.log.

local UEHelpers = require("UEHelpers")
local config = require("config")

local function log(msg)
    print("[CV2Coop] " .. tostring(msg) .. "\n")
end

local function valid(obj)
    return obj ~= nil and obj:IsValid()
end

local function full_name(obj)
    if valid(obj) then
        return obj:GetFullName()
    end
    return "<none>"
end

-- Run fn, logging the error instead of taking the game down.
local function safely(label, fn)
    local ok, err = pcall(fn)
    if not ok then
        log(label .. " failed: " .. tostring(err))
    end
end

local function console(cmd)
    local pc = UEHelpers.GetPlayerController()
    if not valid(pc) then
        log("no player controller yet - load into the game world first")
        return
    end
    log("running console command: " .. cmd)
    UEHelpers.GetKismetSystemLibrary():ExecuteConsoleCommand(pc, cmd, pc)
end

local function current_map()
    local world = UEHelpers.GetWorld()
    local name = UEHelpers.GetGameplayStatics():GetCurrentLevelName(world, true)
    return name:ToString()
end

local function dump()
    log("---- dump ----")
    safely("engine version", function()
        log("engine: UE " .. UnrealVersion.GetMajor() .. "." .. UnrealVersion.GetMinor())
    end)

    local pc = UEHelpers.GetPlayerController()
    local world = UEHelpers.GetWorld()
    log("world:      " .. full_name(world))
    log("controller: " .. full_name(pc))

    safely("map name", function()
        log("map:        " .. current_map())
    end)
    safely("net role", function()
        local ksl = UEHelpers.GetKismetSystemLibrary()
        log("standalone: " .. tostring(ksl:IsStandalone(world)))
        log("is server:  " .. tostring(ksl:IsServer(world)))
    end)
    safely("pawn", function()
        local pawn = pc.Pawn
        log("pawn:       " .. full_name(pawn))
        if valid(pawn) then
            local loc = pawn:K2_GetActorLocation()
            log(string.format("position:   %.0f, %.0f, %.0f", loc.X, loc.Y, loc.Z))
        end
    end)
    safely("game mode", function()
        local gm = UEHelpers.GetGameplayStatics():GetGameMode(world)
        log("game mode:  " .. full_name(gm))
        -- The options the game itself passed when it opened this map.
        log("map options: '" .. gm.OptionsString:ToString() .. "'")
    end)
    safely("game instance", function()
        log("game instance: " .. full_name(FindFirstOf("GameInstance")))
    end)
    safely("pawn state", function()
        local pawn = pc.Pawn
        if valid(pawn) then
            log("pawn hidden: " .. tostring(pawn.bHidden))
        end
    end)
    safely("game state", function()
        local gs = UEHelpers.GetGameplayStatics():GetGameState(world)
        log("game state: " .. full_name(gs))
    end)
    safely("controllers", function()
        local all = FindAllOf("PlayerController")
        log("player controllers in world: " .. (all and #all or 0))
        for i, c in ipairs(all or {}) do
            log("  [" .. i .. "] " .. full_name(c) .. " -> pawn " .. full_name(c.Pawn))
        end
    end)
    log("---- end dump ----")
end

-- Every live UI widget whose name contains `needle` (lower-case), or every
-- top-level one when no needle is given.
local function each_widget(needle, fn)
    for _, w in ipairs(FindAllOf("UserWidget") or {}) do
        if valid(w) then
            local name = w:GetFullName()
            local top = w:IsInViewport()
            local matches = needle and name:lower():find(needle, 1, true)
            if matches or (not needle and top) then
                fn(w, name, top)
            end
        end
    end
end

-- List UI widgets, to find whatever is drawing the stuck loading screen.
local function widgets(needle)
    log("---- widgets" .. (needle and (" matching '" .. needle .. "'") or " on screen") .. " ----")
    local count = 0
    each_widget(needle, function(w, name, top)
        count = count + 1
        log(string.format("%s%s visible=%s", top and "[top] " or "      ", name, tostring(w:IsVisible())))
    end)
    log("---- " .. count .. " widgets ----")
end

-- Collapse matching widgets (ESlateVisibility::Collapsed = 1).
local function hide(needle)
    if not needle then
        log("usage: coop_hide <part of widget name>")
        return
    end
    each_widget(needle, function(w, name)
        log("hiding " .. name)
        w:SetVisibility(1)
    end)
end

local function show(value)
    if type(value) == "userdata" then
        local ok, text = pcall(function() return value:ToString() end)
        if ok then return text end
        ok, text = pcall(function() return value:GetFullName() end)
        if ok then return text end
    end
    return tostring(value)
end

-- Short names for the objects we call most.
local ALIASES = {
    session = "BP_AppOnlineSessionManager_C",
    user = "OnlineUserSubsystem",
    players = "PlayerManager",
}

local function target_object(kind)
    kind = kind and (ALIASES[kind:lower()] or kind)
    local pc = UEHelpers.GetPlayerController()
    local world = UEHelpers.GetWorld()
    local statics = UEHelpers.GetGameplayStatics()
    if kind == "instance" then return FindFirstOf("GameInstance") end
    if kind == "mode" then return statics:GetGameMode(world) end
    if kind == "state" then return statics:GetGameState(world) end
    if kind == "controller" then return pc end
    if kind == "pawn" then return pc.Pawn end
    -- Anything else is taken as a class name, e.g. a subsystem.
    if kind then return FindFirstOf(kind) end
    return nil
end

-- List every live object of a class (and its subclasses).
local function objs(class_name)
    if not class_name then
        log("usage: coop_objs <ClassName>, e.g. coop_objs GameInstanceSubsystem")
        return
    end
    log("---- objects of class " .. class_name .. " ----")
    local count = 0
    for _, obj in ipairs(FindAllOf(class_name) or {}) do
        if valid(obj) and count < 300 then
            count = count + 1
            log("  " .. obj:GetFullName())
        end
    end
    log("---- " .. count .. " objects ----")
end

-- "Name: Type" for each parameter of a function (the return value shows up
-- as ReturnValue). Struct, object and enum types include what they refer to.
local function signature(fn)
    local parts = {}
    pcall(function()
        fn:ForEachProperty(function(prop)
            local text = prop:GetFName():ToString()
            pcall(function()
                text = text .. ": " .. prop:GetClass():GetFName():ToString()
            end)
            for _, getter in ipairs({ "GetStruct", "GetPropertyClass", "GetEnum" }) do
                pcall(function()
                    text = text .. " " .. prop[getter](prop):GetFName():ToString()
                end)
            end
            parts[#parts + 1] = text
        end)
    end)
    return table.concat(parts, ", ")
end

-- List the game's own functions on one of its core objects, to find the
-- ones that drive map loading. Engine base classes are skipped.
local function funcs(kind, needle)
    local obj = target_object(kind)
    if not valid(obj) then
        log("usage: coop_funcs <instance|mode|state|controller|pawn|ClassName> [part of name]")
        return
    end
    log("---- functions on " .. full_name(obj) .. " ----")
    local class = obj:GetClass()
    local count = 0
    while valid(class) do
        local class_name = class:GetFullName()
        if class_name:find("/Script/Engine.", 1, true) or class_name:find("/Script/CoreUObject.", 1, true) then
            break
        end
        log("class " .. class_name)
        class:ForEachFunction(function(fn)
            local name = fn:GetFName():ToString()
            if not needle or name:lower():find(needle, 1, true) then
                count = count + 1
                log("  " .. name .. "(" .. signature(fn) .. ")")
            end
        end)
        class = class:GetSuperStruct()
    end
    log("---- " .. count .. " functions ----")
end

-- List the game's own properties on an object with their current values.
local function props(kind, needle)
    local obj = target_object(kind)
    if not valid(obj) then
        log("usage: coop_props <session|user|players|ClassName> [part of name]")
        return
    end
    log("---- properties on " .. full_name(obj) .. " ----")
    local class = obj:GetClass()
    while valid(class) do
        local class_name = class:GetFullName()
        if class_name:find("/Script/Engine.", 1, true) or class_name:find("/Script/CoreUObject.", 1, true) then
            break
        end
        log("class " .. class_name)
        class:ForEachProperty(function(prop)
            local name = prop:GetFName():ToString()
            if not needle or name:lower():find(needle, 1, true) then
                local kind_text, value_text = "?", "?"
                pcall(function() kind_text = prop:GetClass():GetFName():ToString() end)
                pcall(function()
                    local value = obj[name]
                    if kind_text == "ArrayProperty" then
                        value_text = "array of " .. #value
                    else
                        value_text = show(value)
                    end
                end)
                log("  " .. name .. ": " .. tostring(kind_text) .. " = " .. tostring(value_text))
            end
        end)
        class = class:GetSuperStruct()
    end
    log("---- end properties ----")
end

-- The managers most likely to drive loading, the title flow and sessions.
local SURVEY = {
    "BP_TitleProgressManager_C",
    "BP_GameSystemManager_C",
    "BP_ScreenMaskManager_C",
    "BP_AppOnlineSessionManager_C",
    "SessionTaskManager",
    "OnlineUserSubsystem",
    "PlayerManager",
    "FastTravelSubsystem",
    "FieldSubsystem",
    "WorldPartitionController",
    "AsyncLoadingScreenSubsystem",
}

local function survey()
    for _, class_name in ipairs(SURVEY) do
        safely("survey " .. class_name, function()
            funcs(class_name)
        end)
    end
    log("---- survey done ----")
end

-- Call a function on a game object and log the result. Arguments may be
-- booleans, numbers or strings.
local function call(class_name, fn_name, ...)
    if not class_name or not fn_name then
        log("usage: coop_call <session|user|players|ClassName> <FunctionName> [arguments]")
        return
    end
    local obj = target_object(class_name)
    if not valid(obj) then
        log("no live object of class " .. class_name)
        return
    end
    local args = { ... }
    local shown = {}
    for i, a in ipairs(args) do shown[i] = tostring(a) end
    local ok, result = pcall(function() return obj[fn_name](obj, table.unpack(args)) end)
    log(class_name .. ":" .. fn_name .. "(" .. table.concat(shown, ", ") .. ") -> "
        .. (ok and show(result) or ("failed: " .. tostring(result))))
end

-- Current state of the game's session system and of the network.
local function state()
    log("---- state ----")
    for _, fn_name in ipairs({ "IsOnlineMode", "GetSessionStateStr", "HasSessions", "IsAdvertiseSession",
        "IsHostPlayer", "IsGuestPlayer", "GetCurrentMapPath" }) do
        call("session", fn_name)
    end
    call("user", "GetUserNickName")
    call("user", "IsPlayerLoggedIn", 0)
    call("user", "GetCanPlayOnline", 0)
    safely("net role", function()
        local world = UEHelpers.GetWorld()
        local ksl = UEHelpers.GetKismetSystemLibrary()
        log("map: " .. current_map() .. ", standalone: " .. tostring(ksl:IsStandalone(world))
            .. ", is server: " .. tostring(ksl:IsServer(world)))
        log("player controllers: " .. #(FindAllOf("PlayerController") or {}))
    end)
    log("---- end state ----")
end

-- The map path as the session manager itself reports it.
local function session_map()
    local mgr = target_object("session")
    return mgr:GetCurrentMapPath():ToString()
end

local function prepare_session(lan)
    call("session", "SetLANMatch", lan)
    call("session", "SetPlayerNum", 2)
    call("session", "SetOnlineMode", true)
end

-- Host a session through the game's own session manager.
--   lan / online: CreateSession, as a LAN or an online match
--   map:          CreateSessionWithMapName, naming the current map
--   net:          like map, but as an online (Steam) session, not LAN
--   go:           map, then ServerTravelOnly to open the world to a guest
local function cohost(mode)
    mode = mode or "lan"
    log("hosting through the game's session manager (" .. mode .. ")")
    state()
    prepare_session(mode ~= "online" and mode ~= "net")
    if mode == "map" or mode == "go" or mode == "net" then
        call("user", "TryToLoginForOnlinePlay", 0)
        call("session", "CreateSessionWithMapName", session_map(), {}, false)
        if mode == "go" then
            call("session", "ServerTravelOnly")
        end
    else
        call("session", "CreateSession", false)
    end
    state()
end

-- Guest side: look for a host's session on the local network.
local function cojoin(mode)
    local lan = mode ~= "net"
    log("searching for a " .. (lan and "LAN" or "Steam") .. " session through the game's session manager")
    state()
    prepare_session(lan)
    call("user", "TryToLoginForOnlinePlay", 0)
    call("session", "FindAvailableSession")
    state()
end

-- A search this mod started itself, kept so its results can be read later.
local own_search = nil

-- Every session search the game currently holds, with what each one found.
local function searches()
    local list = {}
    for _, req in ipairs(FindAllOf("CommonSession_SearchSessionRequest") or {}) do
        if valid(req) and not req:GetFullName():find("Default__", 1, true) then
            list[#list + 1] = req
        end
    end
    return list
end

local function found()
    log("---- session searches ----")
    for i, req in ipairs(searches()) do
        local count = 0
        pcall(function() count = #req.Results end)
        log("search " .. i .. ": " .. req:GetFullName() .. " -> " .. count .. " result(s)")
        for j = 1, count do
            safely("result " .. j, function()
                local result = req.Results[j]
                log("  [" .. j .. "] " .. show(result:GetDescription())
                    .. ", open slots: " .. tostring(result:GetNumOpenPublicConnections())
                    .. ", ping: " .. tostring(result:GetPingInMs()))
            end)
        end
    end
    log("---- end searches ----")
end

-- Join the first session any search found.
local function joinfound()
    for _, req in ipairs(searches()) do
        local count = 0
        pcall(function() count = #req.Results end)
        if count > 0 then
            local mgr = target_object("session")
            local pc = UEHelpers.GetPlayerController()
            log("joining the session found by " .. req:GetFullName())
            mgr:JoinSession(pc, req.Results[1])
            state()
            return
        end
    end
    log("no search has any results to join; run coop_cojoin or coop_find first")
end

-- Search with the engine's session functions directly, bypassing the
-- game's FindAvailableSession wrapper.
local function find(mode, kind)
    local lan = mode ~= "net"
    local lobbies = kind ~= "nolobby"
    log("searching for a " .. (lan and "LAN" or "Steam") .. " session directly ("
        .. (lobbies and "lobbies" or "no lobbies") .. ")")
    prepare_session(lan)
    call("user", "TryToLoginForOnlinePlay", 0)
    local mgr = target_object("session")
    own_search = mgr:CreateOnlineSearchSessionRequest()
    if lan then
        own_search.OnlineMode = 1 -- ECommonSessionOnlineMode::LAN
    end
    own_search.bUseLobbies = lobbies
    mgr:FindSessions(UEHelpers.GetPlayerController(), own_search)
    log("search started; wait about 30 seconds, then run coop_found")
end

-- Travel to the current map as a host without creating an online session,
-- using the developers' own test function.
local function travel()
    log("server travel through the game's session manager")
    state()
    prepare_session(true)
    call("session", "ServerTravelOnlyTest", session_map())
    state()
end

local function session()
    for _, class_name in ipairs({ "BP_AppOnlineSessionManager_C", "OnlineUserSubsystem", "PlayerManager" }) do
        safely("funcs " .. class_name, function() funcs(class_name) end)
    end
    state()
end

-- Host: enter the hub as a LAN listen server. Run this at the TITLE screen.
-- Reloading the hub from inside the hub hangs, and without bIsLanMatch the
-- game listens through Steam instead of opening a network port.
local function host()
    if current_map() ~= "Title" then
        log("run coop_host at the title screen; reloading the hub from inside it hangs")
        return
    end
    log("hosting: opening " .. config.host_map .. " as a LAN listen server on port " .. config.port)
    console("open " .. config.host_map .. "?listen?bIsLanMatch")
end

local function join(address)
    address = address or config.host_address
    -- IP and Steam (steam.<17-digit id>) addresses both need a port.
    if not address:find(":", 1, true) then
        address = address .. ":" .. config.port
    end
    log("joining " .. address)
    console("open " .. address)
end

local function on_game_thread(label, fn)
    ExecuteInGameThread(function()
        safely(label, fn)
    end)
end

RegisterKeyBind(Key.F6, { ModifierKey.CONTROL }, function()
    on_game_thread("dump", dump)
end)
RegisterKeyBind(Key.F7, { ModifierKey.CONTROL }, function()
    on_game_thread("host", host)
end)
RegisterKeyBind(Key.F8, { ModifierKey.CONTROL }, function()
    on_game_thread("join", join)
end)

RegisterConsoleCommandHandler("coop_dump", function()
    on_game_thread("dump", dump)
    return true
end)
RegisterConsoleCommandHandler("coop_host", function()
    on_game_thread("host", host)
    return true
end)
RegisterConsoleCommandHandler("coop_join", function(_, params)
    local address = params and params[1]
    on_game_thread("join", function()
        join(address)
    end)
    return true
end)

local function first_param(params)
    local p = params and params[1]
    return p and p:lower() or nil
end

RegisterConsoleCommandHandler("coop_widgets", function(_, params)
    local needle = first_param(params)
    on_game_thread("widgets", function()
        widgets(needle)
    end)
    return true
end)
RegisterConsoleCommandHandler("coop_hide", function(_, params)
    local needle = first_param(params)
    on_game_thread("hide", function()
        hide(needle)
    end)
    return true
end)

RegisterConsoleCommandHandler("coop_survey", function()
    on_game_thread("survey", survey)
    return true
end)
RegisterConsoleCommandHandler("coop_session", function()
    on_game_thread("session", session)
    return true
end)
-- "true"/"false" become booleans, numbers become numbers, the rest stay text.
local function parse_arg(text)
    if text == "true" then return true end
    if text == "false" then return false end
    return tonumber(text) or text
end

RegisterConsoleCommandHandler("coop_call", function(_, params)
    params = params or {}
    local class_name, fn_name = params[1], params[2]
    local args = {}
    for i = 3, #params do
        args[#args + 1] = parse_arg(params[i])
    end
    on_game_thread("call", function()
        call(class_name, fn_name, table.unpack(args))
    end)
    return true
end)
RegisterConsoleCommandHandler("coop_state", function()
    on_game_thread("state", state)
    return true
end)
RegisterConsoleCommandHandler("coop_cojoin", function(_, params)
    local mode = first_param(params)
    on_game_thread("cojoin", function()
        cojoin(mode)
    end)
    return true
end)
RegisterConsoleCommandHandler("coop_found", function()
    on_game_thread("found", found)
    return true
end)
RegisterConsoleCommandHandler("coop_joinfound", function()
    on_game_thread("joinfound", joinfound)
    return true
end)
RegisterConsoleCommandHandler("coop_find", function(_, params)
    local mode = first_param(params)
    local kind = params and params[2] and params[2]:lower() or nil
    on_game_thread("find", function()
        find(mode, kind)
    end)
    return true
end)
RegisterConsoleCommandHandler("coop_props", function(_, params)
    local kind = params and params[1]
    local needle = params and params[2] and params[2]:lower() or nil
    on_game_thread("props", function()
        props(kind, needle)
    end)
    return true
end)
RegisterConsoleCommandHandler("coop_travel", function()
    on_game_thread("travel", travel)
    return true
end)
RegisterConsoleCommandHandler("coop_cohost", function(_, params)
    local mode = first_param(params)
    on_game_thread("cohost", function()
        cohost(mode)
    end)
    return true
end)
RegisterConsoleCommandHandler("coop_objs", function(_, params)
    local class_name = params and params[1]
    on_game_thread("objs", function()
        objs(class_name)
    end)
    return true
end)
RegisterConsoleCommandHandler("coop_funcs", function(_, params)
    local kind = params and params[1]
    local needle = params and params[2] and params[2]:lower() or nil
    on_game_thread("funcs", function()
        funcs(kind, needle)
    end)
    return true
end)

log("probe loaded. Ctrl+F6 dump, Ctrl+F7 host, Ctrl+F8 join")
