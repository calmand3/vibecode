# Code Vein II co-op mod

Goal: two players in the same Code Vein II world on PC.

Code Vein II ships single-player only, but the game contains a switched-off
two-player (host and guest) co-op system. This mod turns it back on. It is a
[UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) Lua mod.

## Where this stands

**Two players can share the hub.** Tested on the free Character Creator Demo
with a PC hosting and a second Windows device joining over the home network:
both players see each other and movement is smooth.

Not yet tested or working:

- Combat, enemies, bosses and progression. The demo has none, so this needs
  the full game.
- The host's own character. Hosting skips the title menu, so the host loads
  as a default character instead of their saved one.
- Play over the internet. Only a local network has been tried.
- The game's session layer on top of the connection (host/guest roles,
  invites). Sessions can be created and found, but joining through them has
  not worked yet.
- Hotkeys. Use the console commands.

## How to play (local network)

Both devices need the game, UE4SS (an experimental build), and this mod.

1. Extract UE4SS into the game's `Binaries\Win64` folder.
2. In `ue4ss\Mods\mods.txt`, set every line to `0` except
   `ConsoleEnablerMod : 1`. One of the bundled mods crashes the game.
3. Copy `mod/CV2Coop` into `ue4ss\Mods`.

**Host**

1. At the title screen, open the console (tilde or F10) and run `coop_host`.
2. Allow the game through the firewall if asked.
3. Find the PC's local address with `ipconfig`.

**Guest**

1. At the title screen, run `coop_join <host address>`, for example
   `coop_join 192.168.0.122`. Or set `host_address` in
   `mod/CV2Coop/scripts/config.lua` and run `coop_join`.

The two devices must be different machines. A second copy of the game on the
same PC crashes when UE4SS is loaded in both.

## What we learned

- **The game has co-op built in.** The player character is full of
  replication functions, and there is a session manager
  (`BP_AppOnlineSessionManager_C`) with create, find, join, kick and invite
  functions, plus `GetHostPlayer` / `GetGuestPlayer` on `PlayerManager`.
- **Hosting must start from the title screen.** Reopening the hub from inside
  the hub (by `open`, `ServerTravelOnly` or `ServerTravelOnlyTest`) hangs on
  an endless load. `open MainWorld?listen` from the title screen works.
- **The LAN flag opens the network port.** Without `?bIsLanMatch` the host
  listens through Steam and has no port to connect to. With it, the host
  listens on UDP 7777.
- **Sessions need an online login first.** `CreateSessionWithMapName`
  succeeds after `TryToLoginForOnlinePlay(0)`; plain `CreateSession` fails.

## Other commands

`coop_dump`, `coop_state`, `coop_session`, `coop_survey`,
`coop_funcs <object> [filter]`, `coop_objs <ClassName>`,
`coop_call <object> <Function> [arguments]`, `coop_widgets [filter]`,
`coop_hide <filter>`, `coop_cohost [lan|online|map|go]`, `coop_cojoin`,
`coop_travel`. These are for exploring the game's co-op code; see
`mod/CV2Coop/scripts/main.lua`.

## Plan

| Phase | What | Status |
| --- | --- | --- |
| 0 | Find out whether the engine's netcode can be switched on | Done |
| 1 | Two players see each other move | Done on the demo, local network |
| 2 | Combat: attacks, damage, enemy health and death agree on both sides | Needs the full game |
| 3 | World: enemy AI, bosses, pickups, checkpoints, map travel | Not started |
| 4 | Usability: own characters, internet play, invite flow, installer | Not started |
