---
name: pac-performance
description: PAC performance principles and optimization conventions.
---

# PAC Performance Principles

1. Combat logic is server-authoritative: all damage, hit detection, state changes on server.
2. Client-side prediction for responsive feel, server reconciliation.
3. Reactive replication via Proxy — only changed data synced.
4. Object pooling for particles and temporary instances.
5. Janitor cleanup to prevent leaks — every spawned resource tracked.
6. `--!native` and `--!optimize 2` on performance-critical server files.
7. Spatial queries use Roblox physics (`GetPartBoundsInBox`/`GetPartBoundsInRadius`) — not custom overlap.
8. Frame-based sequences for precise animation timing at 60fps.

## Proxy (reactive data)
```luau
self.Proxy = Proxy({ Skills = {} })
self.Proxy:Patch({ { Name="SetDictionary", Path={"Skills"}, Args={skillId, skill.Proxy()} } })
local cleanup = skill.Proxy:Subscribe("AnyChange", {"Parameters"}, function(newValue,oldValue,instr) end)
playerProxy:Subscribe("AnyChange", {"Skills","*","Parameters"}, function() end)
local state = self.Proxy()
```
Rules: AnyChange fires when subscribed path is prefix of changed path (replacing parent does not notify deeper); exact subs O(1); AnyChange one lookup/segment; patterns scan pattern list; throwing listener reported via warn and doesn't stop batch/OnPatch; no-op patch produces no callback and is not forwarded.

## Also
- Keep combat constants/formulas in shared configs.
- Modularize skills; centralize via Spec/Crane.
- Janitor for all resources (parameters via seq.Cleaner).