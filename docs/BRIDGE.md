# Crane Bridge

A Studio-only control surface. Agents that talk to Roblox Studio over MCP can call
into a running playtest, reach Crane services and components, read and write game
state, and inspect the instance tree — without editing a script to ask for it.

Each side of the game publishes one Crane service with one `Request`/`Response`
BindableEvent pair:

| Side | Container | Address it from |
|---|---|---|
| Server | `ServerScriptService.Bridge` | `execute_luau` with `datamodel_type: "Server"` |
| Client | `ReplicatedStorage.Bridge` | `execute_luau` with `datamodel_type: "Client"` |

Source:

- `src/shared/packages/Bridge/` — protocol, codec, operation catalog
- `src/server/services/BridgeService.luau`
- `src/client/services/BridgeService.luau`

---

## Security

The Bridge does not exist in a published game. Both services check
`RunService:IsStudio()` before creating a single instance, and `Ops.Run` re-checks
it on every call, so firing the event directly does nothing either.

| Attack | Why it fails |
|---|---|
| Remote client fires the client pair | `IsStudio()` is false on a real server, so the pair is never created |
| Remote client subscribes to server responses | The server pair lives in `ServerScriptService`, which never replicates |
| Remote client fires the client pair upward | The server never connects to it; a BindableEvent signal only fires on the side holding the connection |
| Injected script reads a global helper | Nothing is registered in `_G` |
| Script calls `Crane.Services.BridgeService` directly | The service is always registered, but stores nothing and exposes no handler table when disabled |
| Script reads `ModuleScript.Source` | Not readable at runtime |

This stops accidental and network access. It is not a defence against a local
hook with arbitrary memory access — in that case the Bridge only exists on a
developer's own machine anyway.

---

## The round trip

`BindableEvent:Fire` never yields, so the wait has to be explicit. Server:

```lua
	local HttpService = game:GetService("HttpService")
	local Bridge = game:GetService("ServerScriptService"):WaitForChild("Bridge")

	local id = HttpService:GenerateGUID(false)
	local reply, connection = nil, nil

	connection = Bridge.Response.Event:Connect(function(payload)
		if payload.Id == id then
			reply = payload
			connection:Disconnect()
		end
	end)

	Bridge.Request:Fire({ Id = id, Op = "bridge.ping", Args = {} })

	local deadline = os.clock() + 10
	while not reply and os.clock() < deadline do
		task.wait()
	end

	if connection then
		connection:Disconnect()
	end

	return reply
```

Client is identical with `game:GetService("ReplicatedStorage"):WaitForChild("Bridge")`.

Responses are matched on `Id`, so several calls can be in flight without
interfering.

---

## Envelope

Request:

```lua
{ Id = "guid", Op = "op.name", Args = { Name = "CombatService" } }
```

Response:

```lua
{ Id = "guid", Ok = true, Value = <encoded>, Ms = 3 }
{ Id = "guid", Ok = false, Error = "Service \"Foo\" does not exist", Ms = 1 }
```

---

## Encoding

A `BindableEvent` is a hostile transport: it drops metatables, converts non-string
indices to strings, and copies tables. Nothing live ever crosses.

**Responses are tagged plain data.** Roblox datatypes become records:

```lua
{ __type = "Vector3", X = 1, Y = 2, Z = 3 }
{ __type = "CFrame", Components = { ...12 numbers }, Position = {...}, LookVector = {...} }
{ __type = "Color3", R = 1, G = 1, B = 1 }
{ __type = "Enum", EnumType = "PartType", Name = "Ball" }
{ __type = "Instance", Name = "Dummy", ClassName = "Model", Path = "Workspace.Live.Dummy" }
{ __type = "function", Name = "CombatService:Attack" }
{ __type = "Truncated", Reason = "max-depth" }
```

**`__hasMetatable = true`** marks a table that had a live metatable. It is the
honest signal that you are holding a snapshot, not an object you can keep using.

**Arrays come back with string keys** — `Items["1"]`, `Items["2"]`. The transport
does that regardless, so the codec makes it explicit. Every list result carries a
`Count` so you never have to count by hand.

**Arguments accept both forms.** Send a tagged record and it arrives as the real
datatype; send a plain number and it stays a plain number. A raw `Instance` you
grabbed yourself is passed through untouched. An encoded `Instance` record is
resolved back through its `Path`, so results chain:

```lua
-- Read a character component, then read a field off it in a second call
-- Path from the first response is sent straight back in the second request.
```

**Limits**, all there to keep one call from flooding the channel: depth 6,
500 nodes, 200 keys per table, 4096 characters per string, 150 properties per
Instance. Anything cut short arrives as `{ __type = "Truncated", Reason = ... }`.

---

## Operations

Call `bridge.help` at any time to get this catalog from the running game.

### Bridge

| Op | Args | Writes | Notes |
|---|---|---|---|
| `bridge.ping` | — | no | Which side answered, whether Crane started, service/component/player counts |
| `bridge.help` | — | no | This catalog, from the live build |
| `bridge.log` | `Limit?` | no | Rolling window of the last 64 requests handled |
| `bridge.craneGlobals` | `Name?, Value?` | yes | Only `CRANE_DEBUGGING` and `CRANE_TRACK_TAGS` are reachable |

### Crane

| Op | Args | Writes | Notes |
|---|---|---|---|
| `crane.info` | — | no | Every service with `LoadOrder` and methods, every component with `Tag` and methods |
| `crane.service.list` | — | no | Service names with `LoadOrder` |
| `crane.service.get` | `Name, Path?` | no | Live fields and every method, or the value at `Path` |
| `crane.service.set` | `Name, Path, Value` | yes | Writes a field |
| `crane.service.call` | `Name, Method, Args?` | yes | Any method on any service |
| `crane.component.list` | `Name?` | no | Live components, all types when `Name` is omitted |
| `crane.component.get` | `Name, Instance` | no | Live fields and every method |
| `crane.component.call` | `Name, Instance, Method, Args?` | yes | Any method on any component |
| `crane.component.getPath` | `Name, Instance, Path` | no | `Path` may cross into the wrapped Instance |
| `crane.component.setPath` | `Name, Instance, Path, Value` | yes | |
| `crane.component.add` | `Name, Instance` | yes | Attach at runtime |
| `crane.component.remove` | `Name, Instance` | yes | Detach and destroy |

### Instances

| Op | Args | Writes | Notes |
|---|---|---|---|
| `instance.get` | `Instance, Properties?` | no | Class, tags, attributes, properties. `Properties` narrows the read |
| `instance.set` | `Instance, Property, Value` | yes | |
| `instance.call` | `Instance, Method, Args?` | yes | Any method on any Instance |
| `instance.tree` | `Instance?, MaxDepth?, ClassName?, Keywords?, Limit?` | no | Defaults to `Workspace`, depth 3. Returns `Nodes` |
| `instance.find` | `Root?, Keyword?, ClassName?, Limit?` | no | Flat descendant search. Returns `Matches` |

### Game state

| Op | Args | Writes | Notes |
|---|---|---|---|
| `players.list` | — | no | Players with character and component status |
| `characters.list` | `Root?` | no | Character Models with Humanoid state |

---

## Examples

Read a service method:

```lua
Bridge.Request:Fire({
	Id = id,
	Op = "crane.service.call",
	Args = { Name = "ConfigService", Method = "Get", Args = { "Specs" } },
})
```

Call a method on a live component:

```lua
Bridge.Request:Fire({
	Id = id,
	Op = "crane.component.call",
	Args = {
		Name = "Character",
		Instance = { __type = "Instance", Path = "Workspace.Live.Dummy" },
		Method = "SetSpec",
		Args = { "StarPlatinum" },
	},
})
```

Walk the tree:

```lua
Bridge.Request:Fire({
	Id = id,
	Op = "instance.tree",
	Args = { MaxDepth = 2, ClassName = "Model", Keywords = "dummy" },
})
```

---

## Gotchas

- A request runs on a BindableEvent-created thread, so a slow operation blocks only
  that thread. The agent's wait loop still picks up the answer.
- `__hasMetatable` on a snapshot is expected, not a bug. Crane services and
  components are tables with metatables, and the transport strips those.
- A `Path` that resolves to nothing returns an error rather than a null component.
  Instance names containing a dot will not resolve.
- Mutating operations take effect immediately on the running playtest. There is no
  undo.

## Known issues in the codebase

Both surfaced while testing the Bridge. Neither is a Bridge defect; neither is
fixed here.

- **`Component:GetId()` always returns nil.** `Component.luau` reads the attribute
  `"CraneComponentId"`, but `Crane/init.luau` writes `"CraneComponentIdSERVER"` on
  the server and `"CraneComponentIdCLIENT"` on the client. `crane.component.get`
  therefore returns `ComponentId = nil`. Read the attribute directly until this is
  reconciled.
- **Duplicate `Character` components.** After several respawns,
  `crane.component.list` reports many `Character` components stacked on the same
  Model — nine on `Workspace.Live.Mahoti` during testing. Something re-adds the
  component without removing the old one.

## Engine constraints worked around

- Instances are not iterable and `Instance:GetProperties()` does not exist, so
  `instance.get` probes a fixed list of property names (plus a few per class) and
  drops the ones that do not apply. Pass `Properties` to read anything outside
  that list.
- `Enum.Name` is not readable on an `Enum` object, so `EnumType` is produced with
  `tostring` and comes back as `"KeyCode"`, `"Material"` and so on. Sending one
  back as `{ __type = "Enum", EnumType = "Material", Name = "Plastic" }` decodes
  into a real `EnumItem`.

