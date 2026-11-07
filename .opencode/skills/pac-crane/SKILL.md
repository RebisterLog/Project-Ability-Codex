---
name: pac-crane
description: Crane framework patterns (services, components, signals, packets, janitor/buttler, proxy) in PAC.
---

# PAC Crane Patterns

## Services
```luau
local Svc = Crane:CreateService({ Name = "MyService" })
function Svc:onInit() end
function Svc:onStart()
    self.VFXService = Crane:GetService("VFXService")
end
return Svc
```
- Lifecycle: `onInit` (load) before `onStart` (after all loaded).
- Access from anywhere: `Crane:GetService("Name")`.

## Components
```luau
local C = Crane:CreateComponent({ Name = "Character" })
function C.onStart(self)
    self.Humanoid = self.instance:WaitForChild("Humanoid")
    self.RootPart = self.instance:WaitForChild("HumanoidRootPart")
end
return C
-- read: Crane:GetComponent("Character", instance)
```

## Signals (Crane.Signal)
```luau
self.Attacked = Signal()
self.Attacked:Connect(function(Type, Data) end)
self.Attacked:Fire("Precast", attackData)
```

## Packets (Remote)
```luau
Crane:GetPacket("StartSkill").listen(function(skillId, player) end)
-- client: Crane:GetPacket("StartSkill").fire(skillId)
```

## Cleanup
- `Crane.Janitor`: scoped; `Add(obj, "Destroy")`, `Add(function() end)`, `Destroy()`.
- `Crane.Buttler`: keyed; `Add(obj)`, `Set(key, obj, "Destroy")`, `Remove(key)`, `Destroy()`.
- Always clean up sequences, parameters, vfx, connections. Use seq.Cleaner inside sequencer frames.

## Monitoring
`CRANE_DEBUGGING` / `CRANE_TRACK_TAGS` adjustable via Bridge op `crane.craneGlobals` only.

## Gotchas
- Duplicate Character components after respawns.
- `Component:GetId()` returns nil due to attribute name mismatch (server writes SERVER suffix, client CLIENT). Read attribute directly.