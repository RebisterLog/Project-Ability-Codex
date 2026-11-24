# Create a service or component

## Service

```luau
local Service = Crane:CreateService({ Name = "MyService" })

function Service:onInit() end
function Service:onStart() end

return Service
```

- Place server services in `src/server/services/<Name>.luau` or `src/server/services/<Name>/init.luau`; client services in `src/client/services/`.
- Obtain dependencies with `Crane:GetService("Name")`; do not assume constructor injection.
- Register packets with `Crane:GetPacket("Name")` and signals with `Signal()`.
- Track timers, connections and instances with `Crane.Janitor` / `Crane.Buttler`.
- Ordering: `onInit` of all services runs before `onStart`; a service needed by another's `onStart` must be ready in time.

## Component

```luau
local Component = Crane:CreateComponent({ Name = "MyComponent" })
-- self.instance is the bound Instance
```

- Place components in `src/server/components/` or `src/client/components/`.
- Components are instance-bound; obtain one with `Crane:GetComponent`.
- After respawns, do not assume exactly one component per model. See [[Gotchas]].

## Templates

Starter templates exist under `tools/templates/` (`Service`, `Component`, `Spec`, `Hook`). Replace every `{{...}}` placeholder and then follow the relevant how-to. See [[Templates and generators]].

## Verification

- Lifecycle callbacks fire in the expected order.
- All resources are cleaned up when the component/service is removed.
- `lune run tools/format.luau --fix --src`.

Related: [[Services and dependencies]], [[Player modules]], [[Player and character lifecycle]].
