-- Settings for the CV2Coop probe. Edit, then restart the game
-- (or hot-reload mods from the UE4SS console).
return {
    -- Address the joining player connects to: the host's LAN / VPN IP.
    host_address = "127.0.0.1",
    -- Unreal's default listen-server port. The host must allow it through
    -- their firewall (UDP).
    port = 7777,
    -- The map the host opens.
    host_map = "MainWorld",
}
