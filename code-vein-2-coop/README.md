# Code Vein II co-op mod

Goal: two players in the same Code Vein II world on PC.

Code Vein II ships single-player only, but the game contains a switched-off
two-player co-op system. This mod turns it back on. It is a
[UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) Lua mod.

## Where this stands

**Two players can share the hub, over a local network or through Steam.**
Tested on the free Character Creator Demo with a PC and a second Windows
device on a separate Steam account. Both players see each other.

Not yet tested or working:

- Combat, enemies, bosses and progression. The demo has none, so this needs
  the full game.
- The world owner's own character. Opening a world skips the title menu, so
  the owner loads as a default character. The helper keeps their own.
- Ending a session cleanly. When the other player leaves, the game runs its
  own disband routine, which has crashed the remaining player.
- Invites and friends lists. Players find each other by session search.
- Hotkeys. Use the console commands.

## How the game's co-op is designed

It is a call-for-help system with two roles:

- The **helper** offers to be called. They create a session and wait.
- The **world owner** finds that offer and accepts it. The helper is then
  pulled into the owner's world ("You have been called on for assistance").

So the player who creates the session is the one who travels, and the player
who joins it is the one hosting the world.

## Setup (both players)

1. Extract UE4SS (an experimental build) into the game's `Binaries\Win64`.
2. In `ue4ss\Mods\mods.txt`, set every line to `0` except
   `ConsoleEnablerMod : 1`. One of the bundled mods crashes the game.
3. Copy `mod/CV2Coop` into `ue4ss\Mods`.

Commands are typed in the in-game console (tilde or F10). They print to
`ue4ss\UE4SS.log`, not to the screen.

## Play through Steam

Each player needs their own Steam account, online. No addresses or port
forwarding.

**Helper** (keeps their own character)

1. Load into the hub normally.
2. Run `coop_offer` and wait ten seconds.

**World owner**

1. At the title screen, run `coop_host steam`.
2. In the hub, run `coop_summon` and wait 30 seconds.
3. Run `coop_joinfound`.

The helper sees "You have been called on for assistance" and loads into the
owner's world.

## Play on a local network

Works with one Steam account (second device in offline mode).

**World owner**

1. At the title screen, run `coop_host`.
2. Allow the game through the firewall if asked.
3. Find the PC's local address with `ipconfig`.

**Other player**

1. At the title screen, run `coop_join <owner's address>`.

The same steps should work over a virtual LAN tool for play across the
internet; that is untested.

## Testing: the owner's own character

Untested. Three tries, cheapest first. Do each on the world owner's device
and note which character appears in the hub.

1. **Through the title menu.** At the title screen run `coop_arm` (or
   `coop_arm steam`), then start the game from the title menu as usual. The
   mod adds "listen" to the map the menu opens. In the hub, run
   `coop_state`: "is server: true, standalone: false" means the world is
   open to another player.
2. **Back to the title.** Load into the hub normally, return to the title
   screen from the game's menu, then run `coop_host`. This checks whether
   the character stays loaded after leaving the hub.
3. **Same options.** Load into the hub normally and look in `UE4SS.log` for
   the line `[travel] map loaded: ... options '...'`. If the options are not
   empty, restart, and at the title screen type
   `open MainWorld?<those options>?listen?bIsLanMatch` in the console.

Every map load is logged with the tag `[travel]`, including which function
opened it. Send the log after try 1 whatever happens: if it says "still
armed", the title menu opens maps some other way and the log shows how.

## Test setup used so far

- Game: CODE VEIN II Character Creator Demo (Steam app 3733960), Unreal
  Engine 5.4.
- UE4SS: experimental build `UE4SS_v3.0.1-1218-g560411f1`. The stable
  v3.0.1 release is too old for this game.
- Two Windows devices on one home network: a desktop PC and a handheld.
  The local-network test used one Steam account with the handheld offline;
  the Steam test used two accounts, both online.
- The shipped game writes no log of its own. Everything known comes from
  the mod's output in `UE4SS.log`, so new experiments should log what they
  do. Upload logs as files; the startup section is several hundred lines.

## Next steps

1. Full game: check UE4SS and the mod load, and that the same steps open a
   world and connect a second player. Map and class names may differ from
   the demo.
2. Combat: does damage, enemy health and death agree on both sides?
3. Let the world owner use their own character, which probably means
   opening the world through the title menu's normal load.
4. Stop the game's disband routine from crashing the remaining player when
   the other leaves.
5. Replace typed commands with an on-screen flow, and try Steam invites.

## What we learned

- **The game has co-op built in.** The player character is full of
  replication functions, and there is a session manager
  (`BP_AppOnlineSessionManager_C`) with create, find, join, kick and invite
  functions.
- **The session creator travels, the joiner hosts.** A few seconds after a
  player joins a session, the session's creator connects to the joiner's
  world. If the joiner is not hosting, the creator times out after 60
  seconds with "You have been disconnected".
- **A world must be opened from the title screen.** Reopening the hub from
  inside the hub hangs on an endless load. `open MainWorld?listen` from the
  title screen works.
- **`?bIsLanMatch` chooses the network.** With it, the world owner listens
  on UDP 7777. Without it, they listen through Steam (`SteamNetDriver`) and
  open no port.
- **Sessions need an online login first**, and must be created from the
  hub. `CreateSessionWithMapName` succeeds after
  `TryToLoginForOnlinePlay(0)`; creating a session at the title screen
  crashes the game.
- **The game's own search needs preparing.** `FindAvailableSession` finds
  nothing until online mode is on, LAN mode is off and the user is logged
  in. The developers' debug menu has no join button; `JoinSession` with the
  manager's own `SearchResults` does the join.
- **The developers' network debug menu ships in the game.** `coop_debugmenu`
  builds it; it shows the session state live.
- **Two copies on one PC do not work.** The second crashes with UE4SS
  loaded.

## Other commands

`coop_dump`, `coop_state`, `coop_debugmenu`, `coop_found`,
`coop_find [net] [nolobby]`, `coop_session`, `coop_survey`,
`coop_funcs <object> [filter]`, `coop_props <object> [filter]`,
`coop_objs <ClassName>`, `coop_class <path>`,
`coop_call <object> <Function> [arguments]`, `coop_widgets [filter]`,
`coop_hide <filter>`, `coop_cohost [lan|online|map|net|go]`,
`coop_cojoin [net]`, `coop_travel`, `coop_arm [steam|off]`. These are for exploring the game's
co-op code; see `mod/CV2Coop/scripts/main.lua`. The mod also logs the
session and connection state whenever it changes, tagged `[watch]`.

## Plan

| Phase | What | Status |
| --- | --- | --- |
| 0 | Find out whether the engine's netcode can be switched on | Done |
| 1 | Two players see each other move | Done on the demo, local network and Steam |
| 2 | Combat: attacks, damage, enemy health and death agree on both sides | Needs the full game |
| 3 | World: enemy AI, bosses, pickups, checkpoints, map travel | Not started |
| 4 | Usability: owner's character, clean session end, invites, installer | Not started |
