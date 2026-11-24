# Lag compensation

A small, server-authoritative compensation for melee hitboxes. The client streams a throttled pose; the server extrapolates it to its own clock and uses it as the caster's hitbox origin only when the report is plausible. Damage and state remain fully server-side. See [[Runtime boundaries]].

## Flow

1. Client `ClientStateService` samples `RootPart.Position`, `AssemblyLinearVelocity` and yaw in `Heartbeat` at 8 Hz (client services run inside the `Main` Actor, where `RenderStepped` is not dispatched) and sends the unreliable `ClientState` packet with a `workspace:GetServerTimeNow()` timestamp. Velocity and yaw are diffed and only sent when they change, so a sample costs ~21-37 bytes (~170-300 B/s). `Time` is `float64`: in this project `GetServerTimeNow()` returns an epoch-scale value that `float32` would quantise to ~128 seconds.
2. Server `ClientStateService` keeps the last sample per `Player`, rejects future/stale/malformed samples and fills missing optional fields from the previous sample. Public API: `Get(player)` and `GetMetadata(character)`.
3. `CombatService:Hitbox` calls `GetMetadata` when `Info.MovementCorrection` is set and no explicit `Info.Origin` was supplied. The query origin becomes `metadata.Predicted`. Bots and rejected samples keep the old velocity heuristic.

## Validation

- `Latency = clamp(serverNow - sample.Time, 0, 0.3)`.
- Only **horizontal** movement is predicted, capped at Run speed (25 studs/s) and at **3 studs** of total offset. Vertical velocity is never used: a hard landing reports `-80 Y` and would put the origin under the floor; the server's Y is always kept.
- `Tolerance = min(speed * Latency + 1.5, 4)` studs, measured in X/Z. A dashing or heavily desynced client is rejected and the authoritative pose is used.
- Samples older than 0.5 s, faster than 64 studs/s, with future timestamps or non-finite values are dropped.
- The legacy fallback in `Hitbox` is clamped to **2 studs**, so Dash (100 studs/s) can no longer move the query 25 studs backwards.
- An explicit `Info.Origin` (projectiles, stand slams) is never overwritten.

## Constraints

ByteNet gives **all** client→server packets a shared budget of 512 B/s per player (`src/shared/packages/Crane/packages/ByteNet/process/server.luau`). Do not raise the send rate to the source project's 75 Hz: `StartSkill`/`StopSkill` still need room in the same budget. The client never decides hits or damage.

## Verification

Playtest in Studio with 150-250 ms ping and ~1% packet loss: a strafing target should be hit where the attacker saw it, and a target entering the melee arc only *after* the press must be rejected. Verification commands: `lune run tools/format.luau --fix --src`, `lune run tools/context.luau`, `lune run tools/impact.luau CombatService`.

Related: [[Hitbox and targeting]], [[Combat pipeline]], [[Gotchas]].
