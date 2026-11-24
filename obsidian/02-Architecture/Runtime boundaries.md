# Runtime boundaries

PAC is **server-authoritative**. The client requests actions and renders results; the server owns damage, hit detection and state changes.

| Side | Runs where | Responsibilities | Must not do |
|---|---|---|---|
| Server | `ServerScriptService.server` | Validate skill requests, run sequences, hitboxes, attacks, hooks, bot AI, persistence | Trust client-supplied damage or state |
| Client | `StarterPlayer.StarterPlayerScripts.client` | Input, binds, prediction/feel, UI, VFX presentation, target lock | Decide final combat results |
| Shared | `ReplicatedStorage.shared` | Configs, schemas, effects, packages, combat helpers | Assume only one side is executing |

## Request path

1. Client input is translated into a packet request (`StartSkill`, `StopSkill`). See [[Input and BindService]].
2. Server `SkillService` validates cooldown, stun, ragdoll, alive state and spec ownership.
3. The skill runs on the server; hits are resolved by `CombatService`. See [[Combat pipeline]].
4. Results are replicated through Proxy state and VFX packets. See [[Data schemas and Proxy]], [[VFX replication]].

## Special case: Bridge

The runtime control surface exists only during Studio playtest: both Bridge services check `RunService:IsStudio()` before creating instances. It is never reachable in a published game. See [[Bridge (Studio only)]].

## Practical rule

If a change only modifies what the player sees, it can be client-side. If it changes what happens to a character, it belongs on the server, with the client kept responsive through prediction and fast feedback.
