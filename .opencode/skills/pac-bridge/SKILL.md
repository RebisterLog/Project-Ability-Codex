---
name: pac-bridge
description: Crane Bridge (Studio-only MCP control surface) protocol, encoding, operations, gotchas.
---

# PAC Crane Bridge

Studio-only. Surfaces:
- Server: `ServerScriptService.Bridge` (BindableEvent Request/Response).
- Client: `ReplicatedStorage.Bridge`.
- Requires `RunService:IsStudio()`; Ops.Run re-checks. Not present in published game.

## Round trip
Fire `{ Id = guid, Op = op, Args = {...} }` on Request; wait for `{ Id, Ok, Value|Error, Ms }` on Response matched by Id. Never yields from Fire, so poll `task.wait()`.

## Encoding
- Responses are tagged plain data. Roblox types become records (`__type="Vector3"`, etc.). `__hasMetatable=true` means snapshot.
- Arrays come back with string keys; every list carries `Count`.
- Args accept tagged records (decode to real type) or plain; encoded Instance resolves via Path.
- Limits: depth 6, 500 nodes, 200 keys/table, 4096 chars/string, 150 props/Instance; overflow → `{ __type="Truncated", Reason=... }`.

## Operation catalog
- Bridge: `bridge.ping`, `bridge.help`, `bridge.log(Limit?)`, `bridge.craneGlobals(Name?, Value?)` (only CRANE_DEBUGGING, CRANE_TRACK_TAGS).
- Crane: `crane.info`, `crane.service.list/get/set/call`, `crane.component.list/get/call/getPath/setPath/add/remove`.
- Instances: `instance.get/set/call/tree/find`.
- Game state: `players.list`, `characters.list(root?)`.

## Known issues
- `Component:GetId()` returns nil (attribute mismatch).
- Duplicate Character components after respawns.
- Instance names with dot won't resolve Path.

## Constraints
- Operations take effect immediately (no undo).
- BindableEvent-created thread; slow op blocks only that thread. Agents' wait loop still receives answer.