# Lag compensation (Chrono)

Server-authoritative hit detection is rewound to the instant the attacker was
actually rendering. Chrono supplies the snapshot history and the render clock;
the game code only captures a timestamp and re-tests geometry.

## Files

| File | Role |
|---|---|
| `src/shared/configs/Chrono.luau` | Entity types (`PLAYER`, `NPC`), NATIVE replication, `STORE_SNAPSHOTS` |
| `src/server/services/ChronoService.luau` | Calls `Chrono.Start`, registers NPCs, stores per-player aim samples |
| `src/client/services/ChronoService.luau` | Calls `Chrono.Start`, exposes `GetAim()` (render timestamps) |
| `src/shared/combat/LagCompensation.luau` | Pure math: validation, clock selection, overlap tests |
| `src/shared/packages/Crane/Packets.luau` | `StartSkill` carries `AimNormal` / `AimHalf` |
| `src/server/services/CombatService/init.luau` | `Hitbox` resolves rewound attacker/target poses |

## Flow

1. `ChronoService:onInit` (LoadOrder `-500`) calls `Chrono.Start(config)` before
   any other service can call `Entity.new`. Player characters are registered
   automatically by Chrono; NPCs through `RegisterNPC`.
2. On every skill press (including hold retries) `BindService` reads
   `ChronoService:GetAim()` and puts both render clocks into the `StartSkill`
   packet. Bundling them with the activation avoids out-of-order delivery.
3. `SkillService` records the sample on the server (`RecordAim`).
4. `CombatService:Hitbox` chooses a bounded instant via
   `LagCompensation.ChooseTime`, rewinds the attacker with `Entity:GetAt`, and
   uses that CFrame as the query origin.
5. The workspace overlap query is **only a broadphase** — it sees live parts,
   so it is inflated by `maxRewind * 32` studs. Each candidate is then tested
   with its limb poses carried back by the target's root delta
   (`rootThen * rootNow:inverse()`). Chrono stores root history only; this
   approximation is sufficient for melee-sized hitboxes.
6. `Info.Rewind = false` disables the whole path for self-simulated attacks.

`Entity:GetTargetRenderTime()` already returns a value on the server's
`os.clock()` timeline (server send time minus interpolation buffer), so no
clock conversion is needed. Do not mix it with `workspace:GetServerTimeNow()`,
which is a different clock.

**Chrono gotcha:** entity instances are plain tables with no metatable. Their
methods live on the module, so call `Chrono.Entity.GetAt(entity, t)`, never
`entity:GetAt(t)`. `ChronoService:GetCFrameAt(model, t)` wraps that detail;
client clocks are different (their methods are stored on the instance table, so
`clock:GetTargetRenderTime()` is correct there).

Do not keep test targets `Anchored = true`: anchored entities do not produce
snapshot history, so `GetAt` has nothing to rewind to. A stationary dummy should
simply have `Humanoid.WalkSpeed = 0` and no AI, with `Anchored = false`.

Crane's `LoadOrder` is not reliable: services live in a dictionary, so its
`table.sort` does not reorder them. `onInit` still runs for every service before
any `onStart`, but the `onStart` order is arbitrary. `ChronoService` therefore
initialises its cleaner lazily — never assume another service's `onStart` has
already run.

## Stand and animations

Entity types stay `NATIVE`. Roblox keeps replicating `Animator` tracks and the
existing VFX pipeline keeps passing live model instances to the client.
`CUSTOM` replication would require remapping every Animation / PauseAll effect
to client-side model copies and is deliberately not used. Stands live in
`workspace.Stands` and are welded to their owner, so they need no separate
entity for hit rewinding — the owner's root delta covers them.

Every combatant that should benefit must have a Chrono entity: players get one
automatically, NPCs need `ChronoService:RegisterNPC(model)` (the test dummies in
`TestService` already do this). An unregistered target has no history, so it is
tested at its live pose while the attacker is rewound.

## Measuring the gain

```luau
local combat = Crane:GetService("CombatService")
combat.TrackRewind = true
-- run the fight / playtest with network emulation, then read:
print(combat.RewindStats) -- Checks, RewindHits, LiveHits
```

`LiveHits` is what the same geometry would have hit with live poses;
`RewindHits` is the compensated result. Their difference over `Checks` is the
accuracy delta at the current ping. Keep `TrackRewind` off in normal play: it
adds a second overlap test per candidate.

Sanity checks for a playtest: 150–250 ms ping, ~1% packet loss, a moving target
strafing across the melee arc, and a target that enters the arc only *after*
the press (must be rejected by the historical test).
