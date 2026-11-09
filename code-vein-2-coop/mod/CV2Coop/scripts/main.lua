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

log("probe loaded. Ctrl+F6 dump, Ctrl+F7 host, Ctrl+F8 join")
