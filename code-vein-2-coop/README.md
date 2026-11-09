# Code Vein II co-op mod

Goal: two players in the same Code Vein II world on PC.

Code Vein II ships single-player only. It runs on Unreal Engine 5, and the
existing mods for it are built on [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS),
so this mod is too.

## Where this stands

**Phase 0 — probe (this is what is in the repo now).** Nothing here has been
run against the game yet. The probe is a small UE4SS Lua mod that finds out
whether Unreal's built-in networking can be switched on, which decides how the
rest of the mod gets built.

## The plan

| Phase | What | Done when |
| --- | --- | --- |
| 0 | Probe: turn on a listen server, try to connect a second copy | We have logs from a host and a join attempt |
| 1 | Second player exists: both players see each other move | Two characters walk around the same map |
| 2 | Combat: attacks, damage, enemy health and death agree on both sides | A shared fight ends the same way for both players |
| 3 | World: enemy AI, bosses, pickups, checkpoints, map travel | A full area is playable start to finish |
| 4 | Usability: invite flow, reconnects, installer | Someone else can install it and join |

Phase 0 has two possible outcomes, and they lead to different mods:

- **The engine's netcode works.** The join connects and a second character
  spawns. Then the work is fixing, one by one, the game systems that were
  never written to replicate. This is the faster route.
- **It does not.** The join is refused, crashes, or the netcode was compiled
  out. Then the mod has to carry its own sync: a C++ UE4SS mod that sends
  player state over its own connection and drives a puppet character on the
  other side. Slower, but it does not depend on the game cooperating.

## Run the probe

You need Code Vein II on Steam (Windows) and UE4SS installed for it. The
community setup guide linked from the Code Vein II mods on Nexus covers the
UE4SS install.

1. Copy the `mod/CV2Coop` folder into the game's `Binaries\Win64\ue4ss\Mods`
   folder. The `enabled.txt` inside it turns the mod on.
2. Start the game and load into the world.
3. Press **Ctrl+F6**. This writes a dump of what the game is running.
4. Press **Ctrl+F7**. This reloads the current map as a listen server. Once it
   has loaded, press **Ctrl+F6** again.
5. Send back `UE4SS.log` from `Binaries\Win64\ue4ss` (or just the lines
   starting with `[CV2Coop]`), and say what happened on screen.

Back up your save first. Reloading the map this way is not something the game
expects, and the save folder is cheap to copy.

To try a join, a second PC with the game and the mod sets the host's IP in
`mod/CV2Coop/scripts/config.lua` and presses **Ctrl+F8** once in the world.
The host needs UDP port 7777 open. A crash or a refused connection is still a
useful result — send the log either way.

The same actions are available from the UE4SS console as `coop_dump`,
`coop_host` and `coop_join <ip>`.
