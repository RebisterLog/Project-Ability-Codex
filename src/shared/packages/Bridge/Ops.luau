--!strict

--[[
	Operation catalog for the Crane Bridge.

	Every operation returns an already-encoded payload, or `nil, message` for a
	failure. Dispatch never re-encodes: encoding happens exactly once per
	response, here, so a value can never end up tagged twice.

	The surface is deliberately reflective rather than curated. Anything callable
	on a Crane service, a Crane component or an Instance is reachable by name, so
	this file does not need to grow every time the game does.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Codec = require(script.Parent.Codec)
local Crane = require(script.Parent.Parent.Crane)

local Ops = {}

-- Limits that keep one request from flooding the channel.
local MAX_PROPERTIES = 150
local MAX_TREE_NODES = 300
local MAX_FIND_NODES = 200
local HISTORY_LIMIT = 64

export type Args = { [string]: any }

export type Definition = {
	Summary: string,
	Args: string,
	Write: boolean,
	Handler: (args: Args) -> any,
}

-- Rollback guard: a Bridge operation must never be able to drive the Bridge.
local ActiveDepth = 0

local Definitions: { [string]: Definition } = {}

local function Define(name: string, definition: Definition)
	Definitions[name] = definition
end

--[[ ARGUMENT HELPERS ]]
--

local function DecodeArray(value: any): { any }
	return Codec.ToArray(Codec.Decode(value))
end

local function InstanceArg(args: Args, key: string): (Instance?, string?)
	local value = args[key]

	if typeof(value) == "Instance" then return value, nil end

	if typeof(value) == "table" and value.__type == "Instance" then
		local decoded = Codec.Decode(value)
		if typeof(decoded) == "Instance" then return decoded, nil end
		return nil, `Arg "{key}" points at "{tostring(value.Path)}", which no longer exists`
	end

	return nil, `Arg "{key}" must be an Instance or an encoded Instance record`
end

local function StringArg(args: Args, key: string): (string?, string?)
	local value = args[key]
	if type(value) ~= "string" or #value == 0 then
		return nil, `Arg "{key}" must be a non-empty string`
	end
	return value, nil
end

local function NumberArg(args: Args, key: string, fallback: number): number
	local value = tonumber(args[key])
	if not value then return fallback end
	return value
end

local function ServiceArg(args: Args): (any, string?)
	local name, err = StringArg(args, "Name")
	if not name then return nil, err end
	if not Crane.IsStarted then return nil, "Crane has not started yet" end
	if not Crane.Services[name] then return nil, `Service "{name}" does not exist` end
	return Crane.Services[name], nil
end

--[[ REFLECTION HELPERS ]]
--

--- Reads a key out of a table or an Instance. A path may cross from a component
--- into the instance it wraps and on into that instance's children.
local function Index(value: any, key: any): any
	local name = tostring(key)

	if typeof(value) == "table" then
		local child = value[key]
		if child == nil then child = value[name] end
		return child
	end

	if typeof(value) == "Instance" then
		local ok, property = pcall(function()
			return (value :: any)[name]
		end)
		if ok and property ~= nil then return property end
		return (value :: Instance):FindFirstChild(name)
	end

	return nil
end

local function ResolvePath(root: any, path: { any }): (any, string?)
	local current = root

	for step, key in path do
		local child = Index(current, key)
		if child == nil then
			return nil, `Path segment {step} ("{tostring(key)}") resolved to nil`
		end
		current = child
	end

	return current, nil
end

local function AssignPath(root: any, path: { any }, value: any): (boolean, string?)
	if #path == 0 then return false, "Path must not be empty" end

	local parent = root
	for step = 1, #path - 1 do
		parent = Index(parent, path[step])
		if parent == nil then
			return false, `Path segment {step} ("{tostring(path[step])}") resolved to nil`
		end
	end

	local leaf = path[#path]
	local ok, err = pcall(function()
		parent[leaf] = value
	end)
	if not ok then return false, tostring(err) end

	return true, nil
end

local function ComponentNameArg(args: Args): (string?, string?)
	return StringArg(args, "Name")
end

--- Walks the metatable `__index` chain so an agent sees the methods and fields a
--- live object actually exposes, not just the two keys sitting on the instance.
--- A component's prototype only owns `instance` and `Destroying`; everything
--- else lives up the chain.
---
--- Returns raw values and an assembled method list. The caller encodes the two
--- halves separately: Fields is deep and would otherwise starve Methods.
local function DescribeTarget(target: any, instance: Instance?): { [string]: any }
	local methods: { [string]: { Name: string, Origin: string } } = {}
	local fields: { [string]: any } = {}

	local current: any = target
	local visited: { [any]: boolean } = {}
	local level = 0

	while typeof(current) == "table" and level <= 3 do
		if visited[current] then break end
		visited[current] = true

		local origin = if level == 0 then "own" else "class"

		for key, value in pairs(current) do
			local name = tostring(key)

			-- Component.__index and __tostring sit on the table as raw keys and
			-- would otherwise show up as if they were part of the object.
			if string.sub(name, 1, 2) == "__" then continue end

			if type(value) == "function" then
				if methods[name] == nil then methods[name] = { Name = name, Origin = origin } end
			elseif fields[name] == nil then
				fields[name] = value
			end
		end

		local meta = getmetatable(current)
		current = if typeof(meta) == "table" then (meta :: any).__index else nil
		level += 1
	end

	local methodList = {}
	for _, entry in methods do
		table.insert(methodList, entry)
	end
	table.sort(methodList, function(a, b)
		return a.Name < b.Name
	end)

	local out: { [string]: any } = { Methods = methodList, Fields = fields }
	if instance then out.Instance = instance end

	return out
end

-- Instances are not iterable and GetProperties does not exist, so properties are
-- probed by name. This is the set an agent actually reaches for; anything else
-- comes through the Properties argument, which takes priority.
local COMMON_PROPERTIES = {
	"Parent",
	"Archivable",
	"Locked",
	"Position",
	"Orientation",
	"CFrame",
	"Size",
	"Color",
	"Transparency",
	"Material",
	"Anchored",
	"CanCollide",
	"CanQuery",
	"CanTouch",
	"Velocity",
	"AssemblyLinearVelocity",
	"Mass",
	"RootPriority",
	"PrimaryPart",
	"PivotOffset",
	"Health",
	"MaxHealth",
	"WalkSpeed",
	"JumpPower",
	"JumpHeight",
	"DisplayName",
	"UserId",
	"AccountAge",
	"Team",
	"CameraMaxZoomDistance",
	"Text",
	"TextSize",
	"Visible",
	"Image",
	"BackgroundColor3",
	"BorderSizePixel",
	"Value",
	"Enabled",
	"Duration",
	"Speed",
	"Volume",
	"PlaybackSpeed",
	"CurrentCamera",
	"CameraType",
}

local CLASS_PROPERTIES: { [string]: { string } } = {
	Folder = {},
	StringValue = { "Value" },
	NumberValue = { "Value" },
	IntValue = { "Value" },
	BoolValue = { "Value" },
	ObjectValue = { "Value" },
	CFrameValue = { "Value" },
	Vector3Value = { "Value" },
	Color3Value = { "Value" },
	RemoteEvent = { "MaxClients" },
	Script = { "Disabled", "RunContext" },
	ModuleScript = {},
	BindableEvent = {},
	ClickDetector = { "MaxActivationDistance", "CursorIcon" },
}

local function PropertyNames(instance: Instance, filter: { any }?): { string }
	if filter and #filter > 0 then
		local requested = {}
		for _, name in filter do
			table.insert(requested, tostring(name))
		end
		return requested
	end

	local names = {}
	local seen: { [string]: boolean } = {}

	for _, name in COMMON_PROPERTIES do
		if not seen[name] then
			seen[name] = true
			table.insert(names, name)
		end
	end

	for _, name in CLASS_PROPERTIES[instance.ClassName] or {} do
		if not seen[name] then
			seen[name] = true
			table.insert(names, name)
		end
	end

	return names
end

local function ReadProperties(instance: Instance, filter: { any }?): { [string]: any }
	local out: { [string]: any } = {}
	local names = PropertyNames(instance, filter)

	for index, name in names do
		local ok, value = pcall(function()
			return (instance :: any)[name]
		end)
		if ok then out[name] = value end

		if index > MAX_PROPERTIES then
			out.__truncated = "property-budget"
			break
		end
	end

	return out
end

local function MatchKeywords(name: string, keywords: { string }?): boolean
	if not keywords then return true end
	local lowered = string.lower(name)
	for _, keyword in keywords do
		if string.find(lowered, keyword, 1, true) then return true end
	end
	return false
end

local function SplitKeywords(value: any): { string }?
	if type(value) ~= "string" or #value == 0 then return nil end

	local out = {}
	for word in string.lower(value):gmatch("%S+") do
		table.insert(out, word)
	end
	if #out == 0 then return nil end

	return out
end

--[[ REQUEST HISTORY ]]
--

local History: { any } = {}

function Ops.Record(entry: { [string]: any })
	table.insert(History, entry)
	while #History > HISTORY_LIMIT do
		table.remove(History, 1)
	end
end

--[[ BRIDGE ]]
--

Define("bridge.ping", {
	Summary = "Liveness check. Returns which side answered, whether Crane started, and basic counts.",
	Args = "none",
	Write = false,
	Handler = function(_: Args)
		local serviceCount = 0
		for _ in Crane.Services do
			serviceCount += 1
		end

		local componentCount = 0
		for _ in Crane.Components do
			componentCount += 1
		end

		return Codec.Encode({
			Side = if RunService:IsServer() then "Server" else "Client",
			IsStudio = RunService:IsStudio(),
			CraneStarted = Crane.IsStarted,
			ServiceCount = serviceCount,
			ComponentCount = componentCount,
			PlayerCount = #Players:GetPlayers(),
		})
	end,
})

Define("bridge.help", {
	Summary = "Self-describing catalog of every operation, with its argument schema and whether it mutates.",
	Args = "none",
	Write = false,
	Handler = function(_: Args)
		local catalog: { [string]: any } = {}
		local names = Ops.Names()

		for _, name in names do
			local definition = Definitions[name]
			catalog[name] = {
				Summary = definition.Summary,
				Args = definition.Args,
				Write = definition.Write,
			}
		end

		return Codec.Encode({ Count = #names, Ops = catalog })
	end,
})

Define("bridge.log", {
	Summary = "Rolling window of the most recent requests this side handled.",
	Args = "Limit?",
	Write = false,
	Handler = function(args: Args)
		local limit = math.min(
			math.max(math.floor(NumberArg(args, "Limit", HISTORY_LIMIT)), 1),
			HISTORY_LIMIT
		)

		local snapshot = {}
		local start = math.max(1, #History - limit + 1)
		for index = start, #History do
			table.insert(snapshot, History[index])
		end

		return Codec.Encode(Codec.List(snapshot))
	end,
})

Define("bridge.craneGlobals", {
	Summary = "Reads or writes the two Crane debug globals. Only CRANE_DEBUGGING and CRANE_TRACK_TAGS are reachable.",
	Args = "Name?, Value?",
	Write = true,
	Handler = function(args: Args)
		local allowed = {
			CRANE_DEBUGGING = true,
			CRANE_TRACK_TAGS = true,
		}

		local name = args.Name
		if name == nil then
			return Codec.Encode({
				CRANE_DEBUGGING = _G["CRANE_DEBUGGING"],
				CRANE_TRACK_TAGS = _G["CRANE_TRACK_TAGS"],
			})
		end

		if type(name) ~= "string" or not allowed[name] then
			return nil, "Name must be CRANE_DEBUGGING or CRANE_TRACK_TAGS"
		end
		if typeof(args.Value) ~= "boolean" then return nil, "Value must be a boolean" end

		local previous = _G[name]
		_G[name] = args.Value

		return Codec.Encode({ Name = name, Previous = previous, Value = args.Value })
	end,
})

--[[ CRANE ]]
--

Define("crane.info", {
	Summary = "Full Crane snapshot: every service with its LoadOrder and methods, every component with its Tag and methods.",
	Args = "none",
	Write = false,
	Handler = function(_: Args)
		local services: { [string]: any } = {}
		for name, service in Crane.Services do
			local description = DescribeTarget(service)
			services[name] = {
				LoadOrder = service.LoadOrder,
				Methods = Codec.List(description.Methods),
			}
		end

		local components: { [string]: any } = {}
		for name, component in Crane.Components do
			local description = DescribeTarget(component)
			components[name] = {
				Tag = component.Tag,
				Methods = Codec.List(description.Methods),
			}
		end

		return {
			IsStarted = Crane.IsStarted,
			Services = services,
			Components = components,
		}
	end,
})

Define("crane.service.list", {
	Summary = "Names of every registered Crane service on this side, with their LoadOrder.",
	Args = "none",
	Write = false,
	Handler = function(_: Args)
		local entries = {}
		for name, service in Crane.Services do
			table.insert(entries, { Name = name, LoadOrder = service.LoadOrder })
		end
		table.sort(entries, function(a, b)
			return a.Name < b.Name
		end)

		return Codec.Encode(Codec.List(entries))
	end,
})

Define("crane.service.get", {
	Summary = "Snapshot of a service: its live fields and every method reachable through its metatable chain.",
	Args = "Name, Path?",
	Write = false,
	Handler = function(args: Args)
		local service, err = ServiceArg(args)
		if not service then return nil, err end

		local path = DecodeArray(args.Path)
		if #path > 0 then
			local value, pathErr = ResolvePath(service, path)
			if not pathErr then return Codec.Encode(value, Codec.Budgets.Wide) end
			return nil, pathErr
		end

		local target = DescribeTarget(service)

		return {
			Name = tostring(service.Name),
			Methods = Codec.List(target.Methods),
			Fields = Codec.Encode(target.Fields, Codec.Budgets.Default),
		}
	end,
})

Define("crane.service.set", {
	Summary = "Writes a value into a service at a field path.",
	Args = "Name, Path, Value",
	Write = true,
	Handler = function(args: Args)
		local service, err = ServiceArg(args)
		if not service then return nil, err end

		local path = DecodeArray(args.Path)
		if #path == 0 then return nil, "Path must not be empty" end

		local ok, assignErr = AssignPath(service, path, Codec.Decode(args.Value))
		if not ok then return nil, assignErr end

		return Codec.Encode({ Name = service.Name, Path = path, Value = Codec.Decode(args.Value) })
	end,
})

Define("crane.service.call", {
	Summary = "Calls any method on any Crane service and returns its results.",
	Args = "Name, Method, Args?",
	Write = true,
	Handler = function(args: Args)
		local service, err = ServiceArg(args)
		if not service then return nil, err end

		local method, methodErr = StringArg(args, "Method")
		if not method then return nil, methodErr end

		local target = Index(service, method)
		if type(target) ~= "function" then
			return nil, `"{method}" is not a function on service "{tostring(service.Name)}"`
		end

		local callArgs = DecodeArray(args.Args)
		local packed = table.pack(pcall(target, service, table.unpack(callArgs, 1, #callArgs)))

		if not packed[1] then return nil, tostring(packed[2]) end

		local results = {}
		for index = 2, packed.n do
			table.insert(results, packed[index])
		end

		return Codec.Encode({
			Service = service.Name,
			Method = method,
			Results = Codec.List(results),
		})
	end,
})

Define("crane.component.list", {
	Summary = "Every instantiated component of a type, or of every type when Name is omitted.",
	Args = "Name?",
	Write = false,
	Handler = function(args: Args)
		local requested = args.Name

		local wanted: { [string]: boolean } = {}
		if requested ~= nil then
			if type(requested) ~= "string" or not Crane.Components[requested] then
				return nil, `Component "{tostring(requested)}" does not exist`
			end
			wanted[requested] = true
		else
			for name in Crane.Components do
				wanted[name] = true
			end
		end

		local found = {}
		for id, bucket in Crane.InstantiatedComponents do
			for name, component in bucket do
				if wanted[name] then
					local instance = component.instance
					table.insert(found, {
						Id = id,
						Name = name,
						Instance = if typeof(instance) == "Instance" then instance else nil,
					})
				end
			end
		end

		return Codec.Encode(Codec.List(found))
	end,
})

--- Resolves a live component without tripping the assert inside
--- Crane:GetComponent, which throws for instances that carry no component id.
local function ResolveComponent(name: any, instance: Instance): (any, string?)
	if type(name) ~= "string" or #name == 0 then
		return nil, 'Arg "Name" must be a non-empty string'
	end
	if not Crane.Components[name] then return nil, `Component "{name}" does not exist` end

	local ok, component = pcall(function()
		return Crane:GetComponent(name, instance)
	end)
	if not ok then return nil, `Instance "{instance:GetFullName()}" has no "{name}" component` end

	return component, nil
end

Define("crane.component.get", {
	Summary = "Snapshot of a component attached to an Instance: live fields plus every method.",
	Args = "Name, Instance",
	Write = false,
	Handler = function(args: Args)
		local name, nameErr = ComponentNameArg(args)
		if not name then return nil, nameErr end

		local instance, instanceErr = InstanceArg(args, "Instance")
		if not instance then return nil, instanceErr end

		local component, err = ResolveComponent(name, instance)
		if not component then return nil, err end

		local target = DescribeTarget(component, instance)

		return {
			Name = name,
			ComponentId = component:GetId(),
			Instance = Codec.Encode(instance, Codec.Budgets.Flat),
			Methods = Codec.List(target.Methods),
			Fields = Codec.Encode(target.Fields, Codec.Budgets.Default),
		}
	end,
})

Define("crane.component.call", {
	Summary = "Calls any method on a live component and returns its results.",
	Args = "Name, Instance, Method, Args?",
	Write = true,
	Handler = function(args: Args)
		local name, nameErr = ComponentNameArg(args)
		if not name then return nil, nameErr end

		local instance, instanceErr = InstanceArg(args, "Instance")
		if not instance then return nil, instanceErr end

		local method, methodErr = StringArg(args, "Method")
		if not method then return nil, methodErr end

		local component, err = ResolveComponent(name, instance)
		if not component then return nil, err end

		local target = Index(component, method)
		if type(target) ~= "function" then
			return nil, `"{method}" is not a function on component "{name}"`
		end

		local callArgs = DecodeArray(args.Args)
		local packed = table.pack(pcall(target, component, table.unpack(callArgs, 1, #callArgs)))

		if not packed[1] then return nil, tostring(packed[2]) end

		local results = {}
		for index = 2, packed.n do
			table.insert(results, packed[index])
		end

		return Codec.Encode({
			Component = name,
			Method = method,
			Results = Codec.List(results),
		})
	end,
})

Define("crane.component.getPath", {
	Summary = "Reads a field path off a live component. The path may cross into the wrapped Instance.",
	Args = "Name, Instance, Path",
	Write = false,
	Handler = function(args: Args)
		local name, nameErr = ComponentNameArg(args)
		if not name then return nil, nameErr end

		local instance, instanceErr = InstanceArg(args, "Instance")
		if not instance then return nil, instanceErr end

		local component, err = ResolveComponent(name, instance)
		if not component then return nil, err end

		local path = DecodeArray(args.Path)
		if #path == 0 then return nil, "Path must not be empty" end

		local value, pathErr = ResolvePath(component, path)
		if pathErr then return nil, pathErr end

		return Codec.Encode(value, Codec.Budgets.Wide)
	end,
})

Define("crane.component.setPath", {
	Summary = "Writes a field path on a live component.",
	Args = "Name, Instance, Path, Value",
	Write = true,
	Handler = function(args: Args)
		local name, nameErr = ComponentNameArg(args)
		if not name then return nil, nameErr end

		local instance, instanceErr = InstanceArg(args, "Instance")
		if not instance then return nil, instanceErr end

		local component, err = ResolveComponent(name, instance)
		if not component then return nil, err end

		local path = DecodeArray(args.Path)
		if #path == 0 then return nil, "Path must not be empty" end

		local decoded = Codec.Decode(args.Value)
		local ok, assignErr = AssignPath(component, path, decoded)
		if not ok then return nil, assignErr end

		return Codec.Encode({ Name = name, Path = path, Value = decoded })
	end,
})

Define("crane.component.add", {
	Summary = "Attaches a component to an Instance at runtime.",
	Args = "Name, Instance",
	Write = true,
	Handler = function(args: Args)
		local name, nameErr = ComponentNameArg(args)
		if not name then return nil, nameErr end

		local instance, instanceErr = InstanceArg(args, "Instance")
		if not instance then return nil, instanceErr end

		if not Crane.IsStarted then return nil, "Crane has not started yet" end
		if not Crane.Components[name] then return nil, `Component "{name}" does not exist` end

		local ok, component = pcall(function()
			return Crane:AddComponent(instance, name)
		end)
		if not ok then return nil, tostring(component) end

		return Codec.Encode({
			Name = name,
			Instance = instance,
			ComponentId = component:GetId(),
		})
	end,
})

Define("crane.component.remove", {
	Summary = "Detaches and destroys a component from an Instance.",
	Args = "Name, Instance",
	Write = true,
	Handler = function(args: Args)
		local name, nameErr = ComponentNameArg(args)
		if not name then return nil, nameErr end

		local instance, instanceErr = InstanceArg(args, "Instance")
		if not instance then return nil, instanceErr end

		local component, err = ResolveComponent(name, instance)
		if not component then return nil, err end

		local ok, removeErr = pcall(function()
			Crane:RemoveComponent(instance, name)
		end)
		if not ok then return nil, tostring(removeErr) end

		return Codec.Encode({ Name = name, Instance = instance, Removed = true })
	end,
})

--[[ INSTANCES ]]
--

Define("instance.get", {
	Summary = "Class, tags, attributes and properties of an Instance. Pass Properties to narrow the read.",
	Args = "Instance, Properties?",
	Write = false,
	Handler = function(args: Args)
		local instance, err = InstanceArg(args, "Instance")
		if not instance then return nil, err end

		local filter = DecodeArray(args.Properties)
		local gotAttributes, attributes = pcall(function()
			return instance:GetAttributes()
		end)

		return {
			Name = instance.Name,
			ClassName = instance.ClassName,
			Path = instance:GetFullName(),
			IsDestroyed = not instance.Parent,
			Tags = Codec.List(instance:GetTags()),
			Attributes = if gotAttributes then Codec.Encode(attributes, Codec.Budgets.Flat) else {},
			Properties = Codec.Encode(
				ReadProperties(instance, if #filter > 0 then filter else nil),
				Codec.Budgets.Shallow
			),
		}
	end,
})

Define("instance.set", {
	Summary = "Writes a property on an Instance.",
	Args = "Instance, Property, Value",
	Write = true,
	Handler = function(args: Args)
		local instance, err = InstanceArg(args, "Instance")
		if not instance then return nil, err end

		local property, propertyErr = StringArg(args, "Property")
		if not property then return nil, propertyErr end

		local decoded = Codec.Decode(args.Value)
		local ok, setErr = pcall(function()
			(instance :: any)[property] = decoded
		end)
		if not ok then return nil, tostring(setErr) end

		return Codec.Encode({
			Path = instance:GetFullName(),
			Property = property,
			Value = decoded,
		})
	end,
})

Define("instance.call", {
	Summary = "Calls any method on an Instance and returns its results.",
	Args = "Instance, Method, Args?",
	Write = true,
	Handler = function(args: Args)
		local instance, err = InstanceArg(args, "Instance")
		if not instance then return nil, err end

		local method, methodErr = StringArg(args, "Method")
		if not method then return nil, methodErr end

		local target = Index(instance, method)
		if type(target) ~= "function" then
			return nil, `"{method}" is not a function on "{instance.ClassName}"`
		end

		local callArgs = DecodeArray(args.Args)
		local packed = table.pack(pcall(target, instance, table.unpack(callArgs, 1, #callArgs)))

		if not packed[1] then return nil, tostring(packed[2]) end

		local results = {}
		for index = 2, packed.n do
			table.insert(results, packed[index])
		end

		return Codec.Encode({
			ClassName = instance.ClassName,
			Path = instance:GetFullName(),
			Method = method,
			Results = Codec.List(results),
		})
	end,
})

Define("instance.tree", {
	Summary = "Walks the tree from a root, optionally filtered by class and name keywords.",
	Args = "Instance?, MaxDepth?, ClassName?, Keywords?, Limit?",
	Write = false,
	Handler = function(args: Args)
		local root = args.Instance
		if typeof(root) ~= "Instance" then root = Workspace end

		local maxDepth = math.max(math.floor(NumberArg(args, "MaxDepth", 3)), 1)
		local limit = math.max(math.floor(NumberArg(args, "Limit", MAX_TREE_NODES)), 1)
		local className = if type(args.ClassName) == "string" then args.ClassName else nil
		local keywords = SplitKeywords(args.Keywords)

		local nodes = {}
		local queue = { { instance = root, depth = 0 } }
		local head = 1
		local truncated = false

		while head <= #queue do
			local entry = queue[head]
			head += 1

			if entry.depth > maxDepth then continue end

			for _, child in entry.instance:GetChildren() do
				if className and not child:IsA(className) then continue end
				if not MatchKeywords(child.Name, keywords) then continue end

				table.insert(nodes, {
					Name = child.Name,
					ClassName = child.ClassName,
					Path = child:GetFullName(),
					Depth = entry.depth + 1,
				})

				table.insert(queue, { instance = child, depth = entry.depth + 1 })

				if #nodes >= limit then
					truncated = true
					break
				end
			end

			if truncated then break end
		end

		return Codec.Encode({
			Root = root:GetFullName(),
			MaxDepth = maxDepth,
			Truncated = truncated,
			Nodes = Codec.List(nodes),
		})
	end,
})

Define("instance.find", {
	Summary = "Flat search across every descendant of a root, by class and/or name keyword.",
	Args = "Root?, Keyword?, ClassName?, Limit?",
	Write = false,
	Handler = function(args: Args)
		local root = args.Root
		if typeof(root) ~= "Instance" then root = Workspace end

		local limit = math.max(math.floor(NumberArg(args, "Limit", MAX_FIND_NODES)), 1)
		local className = if type(args.ClassName) == "string" then args.ClassName else nil
		local keyword = if type(args.Keyword) == "string" and #args.Keyword > 0
			then string.lower(args.Keyword)
			else nil

		local matches = {}
		local truncated = false

		for _, descendant in root:GetDescendants() do
			if className and not descendant:IsA(className) then continue end
			if keyword and not string.find(string.lower(descendant.Name), keyword, 1, true) then
				continue
			end

			table.insert(matches, {
				Name = descendant.Name,
				ClassName = descendant.ClassName,
				Path = descendant:GetFullName(),
			})

			if #matches >= limit then
				truncated = true
				break
			end
		end

		return Codec.Encode({
			Root = root:GetFullName(),
			Truncated = truncated,
			Matches = Codec.List(matches),
		})
	end,
})

--[[ GAME STATE ]]
--

Define("players.list", {
	Summary = "Every player this side knows about, with their character and resolved Crane components.",
	Args = "none",
	Write = false,
	Handler = function(_: Args)
		local entries = {}

		for _, player in Players:GetPlayers() do
			local character = player.Character
			local playerComponent, _ = ResolveComponent("Player", player)
			local characterComponent = nil
			if character then characterComponent = ResolveComponent("Character", character) end

			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil

			table.insert(entries, {
				Name = player.Name,
				DisplayName = player.DisplayName,
				UserId = player.UserId,
				AccountAge = player.AccountAge,
				Team = player.Team and player.Team.Name or nil,
				HasPlayerComponent = playerComponent ~= nil,
				HasCharacter = character ~= nil,
				HasCharacterComponent = characterComponent ~= nil,
				CharacterPath = if character then character:GetFullName() else nil,
				Health = if humanoid then humanoid.Health else nil,
				MaxHealth = if humanoid then humanoid.MaxHealth else nil,
			})
		end

		return Codec.Encode(Codec.List(entries))
	end,
})

Define("characters.list", {
	Summary = "Every character Model in Workspace with its Humanoid state and Crane component status.",
	Args = "Root?",
	Write = false,
	Handler = function(args: Args)
		local root = args.Root
		if typeof(root) ~= "Instance" then root = Workspace end

		local entries = {}
		for _, model in root:GetDescendants() do
			if not model:IsA("Model") then continue end
			if not model:FindFirstChildOfClass("Humanoid") then continue end

			local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
			local rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			local component = ResolveComponent("Character", model)

			table.insert(entries, {
				Name = model.Name,
				Path = model:GetFullName(),
				Health = humanoid.Health,
				MaxHealth = humanoid.MaxHealth,
				Position = if rootPart then rootPart.Position else nil,
				HasCharacterComponent = component ~= nil,
			})
		end

		return Codec.Encode(Codec.List(entries))
	end,
})

--[[ PUBLIC SURFACE ]]
--

function Ops.Names(): { string }
	local names = {}
	for name in Definitions do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function Ops.Has(name: any): boolean
	return type(name) == "string" and Definitions[name] ~= nil
end

--- Runs one operation. Returns the encoded payload, or nil plus a message.
--- Every failure path lands here rather than propagating into the event handler.
function Ops.Run(name: any, args: Args): (any, string?)
	if not Ops.Has(name) then
		return nil, `Unknown op "{tostring(name)}". Call "bridge.help" for the catalog.`
	end
	if not RunService:IsStudio() then
		return nil, "The Bridge is only available in a Studio playtest"
	end
	if ActiveDepth > 0 then
		return nil, "The Bridge is already handling a request on this thread"
	end

	ActiveDepth += 1
	local ok, value, err = pcall(Definitions[name :: string].Handler, args)
	ActiveDepth -= 1

	if not ok then return nil, tostring(value) end
	if err ~= nil then return nil, tostring(err) end

	return value, nil
end

return Ops
