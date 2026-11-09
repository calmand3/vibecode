-- CV2Coop probe (phase 0)
--
-- Answers one question: can Unreal's built-in networking be switched on in
-- Code Vein II, and how far does a second player get?
--
--   Ctrl+F6  dump what the game is running (classes, map, net role)
--   Ctrl+F7  HOST: reload the current map as a listen server
--   Ctrl+F8  JOIN: connect to the address in config.lua
--
-- Same actions from the UE4SS console: coop_dump, coop_host, coop_join [ip]
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

local function target_object(kind)
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
                log("  " .. name)
            end
        end)
        class = class:GetSuperStruct()
    end
    log("---- " .. count .. " functions ----")
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

local function host()
    local map = current_map()
    log("hosting: reloading '" .. map .. "' as a listen server on port " .. config.port)
    console("open " .. map .. "?listen")
end

local function join(address)
    address = address or config.host_address
    log("joining " .. address .. ":" .. config.port)
    console("open " .. address .. ":" .. config.port)
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
