--[[
 ██████╗██████╗  █████╗ ███╗   ██╗███████╗
██╔════╝██╔══██╗██╔══██╗████╗  ██║██╔════╝
██║     ██████╔╝███████║██╔██╗ ██║█████╗
██║     ██╔══██╗██╔══██║██║╚██╗██║██╔══╝
╚██████╗██║  ██║██║  ██║██║ ╚████║███████╗
╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝

███████╗██████╗  █████╗ ███╗   ███╗███████╗██╗    ██╗ ██████╗ ██████╗ ██╗  ██╗
██╔════╝██╔══██╗██╔══██╗████╗ ████║██╔════╝██║    ██║██╔═══██╗██╔══██╗██║ ██╔╝
█████╗  ██████╔╝███████║██╔████╔██║█████╗  ██║ █╗ ██║██║   ██║██████╔╝█████╔╝
██╔══╝  ██╔══██╗██╔══██║██║╚██╔╝██║██╔══╝  ██║███╗██║██║   ██║██╔══██╗██╔═██╗
██║     ██║  ██║██║  ██║██║ ╚═╝ ██║███████╗╚███╔███╔╝╚██████╔╝██║  ██║██║  ██╗
╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝ ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
by RebisterLog
]]

--!strict
--!optimize 2

-- Requirements
const CollectionService = game:GetService("CollectionService")
const HttpService = game:GetService("HttpService")
const RunService = game:GetService("RunService")

const Component = require(script.Component)
const Packets = require(script.Packets)
const Service = require(script.Service)
const Utils = require(script.Utils)

const Buttler = require(script.packages.Buttler)
const CacheTab = require(script.packages.CacheTab)
const Janitor = require(script.packages.Janitor)
const Signal = require(script.packages.Signal)

_G["CRANE_DEBUGGING"] = false
_G["CRANE_TRACK_TAGS"] = true

const COMPONENT_ID_ATTRIBUTE = "CraneComponentId"
	.. (RunService:IsServer() and "SERVER" or "CLIENT")

-- Types
export type ServiceDef<A, T> = Service.ServiceDef<A, T>
export type ComponentDef<T> = Component.ComponentDef<T>

export type Service<A, T> = Service.Service<A, T>
export type Component<T = Instance> = Component.Component<T>

type PacketsType = typeof(Packets.packets)
type PacketName = keyof<PacketsType>

type QueriesType = typeof(Packets.queries)
type QueryName = keyof<QueriesType>

--[=[
	The main Crane framework class. Provides a service and component system for Roblox development.

	Crane allows you to:
	- Create and manage services that initialize and start in a controlled order
	- Create and manage components that can be attached to Roblox instances
	- Automatically instantiate components based on CollectionService tags
	- Access utility libraries (Promise, Signal, Janitor) through convenient shortcuts

	@class Crane
]=]

--[=[
	Flag indicating whether the framework has been started.

	@readonly
	@prop IsStarted boolean
	@within Crane
]=]

--[=[
	Dictionary of all registered services, indexed by service name.

	@readonly
	@prop Services {[string]: Service}
	@within Crane
]=]

--[=[
	Dictionary of all registered components, indexed by component name.

	@readonly
	@prop Components {[string]: Component}
	@within Crane
]=]

--[=[
	Dictionary mapping instance IDs to their instantiated components.

	@readonly
	@prop InstantiatedComponents {[string]: {[string]: Component}}
	@within Crane
]=]

--[=[
	Dictionary mapping CollectionService tags to component names for automatic component instantiation.

	@readonly
	@prop TrackedTags {[string]: string}
	@within Crane
]=]

--[=[
	Signal library shortcut for convenience.

	@readonly
	@prop Signal any
	@within Crane
]=]

const Crane = {
	-- Properties of framework
	IsStarted = false,
	Services = {},
	Components = {},
	TrackedTags = {},
	InstantiatedComponents = {},

	Utils = Utils,

	-- Shortcuts for libraries
	Signal = Signal,
	CacheTab = CacheTab,
	Janitor = Janitor,
	Buttler = Buttler,
}
Crane.__index = Crane
Crane.__tostring = "CraneFramework"

type CraneData = {
	IsStarted: boolean,
	Services: { [string]: Service.Service<string, number> },
	Components: { [string]: Component.Component },
	TrackedTags: { [string]: string },
	InstantiatedComponents: { [string]: { [string]: Component.Component } },
}

export type Crane = setmetatable<CraneData, typeof(Crane)>

--[[ Crane framework's plan:
	1) init services
	2) start services
	3) Auto-init tagged components
]]

--[=[
	Starts the framework. This method initializes all services in order, then starts them, and finally sets up automatic component tracking for tagged instances.

	**Important:** Services and components must be created before starting the framework!

	```lua
		const Crane = require(PATH_TO_FRAMEWORK)

		Crane:AddServices({FOLDER, FOLDER...})
		Crane:AddComponents({FOLDER, FOLDER...})

		Crane:Start()
	```

	@method Start
	@within Crane
	@error Throws an error if the framework has already been started
]=]
function Crane.Start(self: Crane)
	if self.IsStarted then error("Crane is already started") end
	self.IsStarted = true

	table.sort(
		self.Services :: { Service.Service<string, number> },
		function(a: Service.Service<string, number>, b: Service.Service<string, number>)
			return (a.LoadOrder or 0) < (b.LoadOrder or 0)
		end
	)

	-- Init all services
	for i, service in self.Services do
		service:Init()
	end

	-- Starting all services after initialization
	for i, service in self.Services do
		service:Start()
	end

	if _G["CRANE_TRACK_TAGS"] then
		for tag, componentName in self.TrackedTags do
			CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
				const componentName = self.TrackedTags[tag]
				if componentName and not self:GetComponent(componentName, instance) then
					self:AddComponent(instance, componentName)
				end
			end)

			const tagged = CollectionService:GetTagged(tag)

			for i, instance in tagged do
				if not self:GetComponent(componentName, instance) then
					self:AddComponent(instance, componentName)
				end
			end
		end
	end
end

--[=[
	Scans the provided folders/instances for ModuleScripts containing services and automatically registers them in Crane.

	The parameter `descendants` is optional and determines whether to search for services in descendants of the parent instances.

	```lua
	Crane:AddServices({
		game:GetService("ReplicatedStorage"):WaitForChild("Services"),
		game:GetService("ReplicatedStorage"):WaitForChild("Services"):WaitForChild("SubServices"),
	})

	-- Search in descendants as well
	Crane:AddServices({
		game:GetService("ReplicatedStorage"):WaitForChild("Services"),
	}, true)
	```

	@method AddServices
	@param parents {Instance}
	@param descendants boolean?
	@return {Service}
	@within Crane
	@error Throws an error if parents is not a table or is empty
]=]
function Crane.AddServices(
	self: Crane,
	parents: { Instance },
	descendants: boolean?
): { Service.Service<string, number> }
	assert(typeof(parents) == "table", `Parents must be a table, got {type(parents)}`)
	assert(#parents > 0, `Parents must be a non-empty table`)

	const addedServices = {}

	for i, parent in parents do
		for i, module in
			(descendants and parent:GetDescendants() or parent:GetChildren()) :: { Instance }
		do
			if module:IsA("ModuleScript") then
				const service = require(module) :: Service.Service<string, number>
				table.insert(addedServices, service)
			end
		end
	end

	return addedServices
end

--[=[
	Scans the provided folders/instances for ModuleScripts containing components and automatically registers them in Crane.

	The parameter `descendants` is optional and determines whether to search for components in descendants of the parent instances.

	```lua
	Crane:AddComponents({
		game:GetService("ReplicatedStorage"):WaitForChild("Components"),
		game:GetService("ReplicatedStorage"):WaitForChild("Components"):WaitForChild("SubComponents"),
	})

	-- Search in descendants as well
	Crane:AddComponents({
		game:GetService("ReplicatedStorage"):WaitForChild("Components"),
	}, true)
	```

	@method AddComponents
	@param parents {Instance}
	@param descendants boolean?
	@return {Component}
	@within Crane
	@error Throws an error if parents is not a table or is empty
]=]
function Crane.AddComponents(
	self: Crane,
	parents: { Instance },
	descendants: boolean?
): { Component.Component }
	assert(typeof(parents) == "table", `Parents must be a table, got {type(parents)}`)
	assert(#parents > 0, `Parents must be a non-empty table`)

	const addedComponents = {}

	for i, parent in parents do
		for i, instance in
			(descendants and parent:GetDescendants() or parent:GetChildren()) :: { Instance }
		do
			if instance:IsA("ModuleScript") then
				const component = require(instance) :: Component.Component
				table.insert(addedComponents, component)
			end
		end
	end

	return addedComponents
end

--[=[
	Creates and registers a new service in the framework.

	```lua
	const MyService = Crane:CreateService({
		Name = "MyService",
		LoadOrder = 1,
	})

	function MyService:onInit()
		-- Initialization logic
	end

	function MyService:onStart()
		-- Startup logic
	end
	```

	@method CreateService
	@param options ServiceDef
	@return Service
	@within Crane
	@error Throws an error if:
	- options is not a table
	- options.Name is not a string or is empty
	- A service with the same name already exists
	- The framework has already been started
]=]
function Crane.CreateService<A, T>(self: Crane, options: ServiceDef<A, T>)
	assert(type(options) == "table", `Service must be a table, got {type(options)}`)
	assert(
		type(options.Name) == "string",
		`Service.Name must be a string; got {type(options.Name)}`
	)
	assert(#options.Name > 0, "Service.Name must be a non-empty string")
	assert(not self.Services[options.Name], `Service "{options.Name}" already exists`)
	assert(not self.IsStarted, `Services cannot be created after calling "Crane:Start()"`)

	const service = Service.new(options)
	self.Services[options.Name] = service
	return service :: Service.Service<A, T>
end

--[=[
	Retrieves a registered service by name.

	```lua
	const MyService = Crane:GetService("MyService")
	```

	@method GetService
	@param name string
	@return Service
	@within Crane
	@error Throws an error if:
	- The framework has not been started
	- name is not a string or is empty
	- The service does not exist
]=]
function Crane.GetService(self: Crane, name: string)
	assert(self.IsStarted, `Crane must be started before getting a service`)
	assert(type(name) == "string", `Service name must be a string, got {type(name)}`)
	assert(#name > 0, "Service name must be a non-empty string")
	assert(self.Services[name], `Could not find service "{name}"`)

	return self.Services[name]
end

--[=[
	Retrieves a registered packet by name.

	```lua
	const MyPacket = Crane:GetPacket("MyPacket")
	```

	@method GetPacket
	@param name PacketName
	@return any
	@within Crane
	@error Throws an error if the packet does not exist
]=]
function Crane.GetPacket(self: Crane, name: PacketName)
	assert((Packets.packets :: any)[name], `Packet "{name}" doesn't exists`)
	return (Packets.packets :: any)[name] :: index<typeof(Packets.packets), PacketName>
end

function Crane.GetQuery(self: Crane, name: QueryName)
	assert((Packets.queries :: any)[name], `Query "{name}" doesn't exists`)
	return (Packets.queries :: any)[name] :: index<typeof(Packets.queries), QueryName>
end

--[=[

]=]
function Crane.GetComponent<T>(
	self: Crane,
	name: string,
	instance: Instance
): Component.Component | nil
	assert(self.Components[name], `Component {name} doesn't exists`)
	assert(instance, `Instance is required`)

	const componentId = instance:GetAttribute(COMPONENT_ID_ATTRIBUTE) :: string?
	if not componentId then return nil end

	return self.InstantiatedComponents[componentId][name]
end

--[=[

]=]
function Crane.GetAllComponents<T>(self: Crane, name: string): { Component.Component }
	assert(self.Components[name], `Component {name} doesn't exists`)

	const components = {}

	for id, instanceComponents in self.InstantiatedComponents do
		for componentName, component in instanceComponents do
			if componentName == name then table.insert(components, component) end
		end
	end

	return components
end

--[=[
	Creates and registers a new component in the framework.

	```lua
	const MyComponent = Crane:CreateComponent({
		Name = "MyComponent",
		Tag = "MyComponentTag", -- Optional: enables automatic instantiation via CollectionService
		BaseComponent = {}, -- Optional: base table to extend
	})

	function MyComponent:onStart()
		-- Component startup logic
		print("Component started on", self.instance)
	end
	```

	@method CreateComponent
	@param options ComponentDef<T>
	@return Component<T>
	@within Crane
	@error Throws an error if:
	- options is not a table
	- options.Name is not a string or is empty
	- A component with the same name already exists
	- The framework has already been started
	- options.Tag is provided but is not a string or already exists
]=]
function Crane.CreateComponent<T>(self: Crane, options: ComponentDef<T>)
	assert(type(options) == "table", `Component must be a table, got {type(options)}`)
	assert(
		type(options.Name) == "string",
		`Component.Name must be a string; got {type(options.Name)}`
	)
	assert(#options.Name > 0, "Component.Name must be a non-empty string")
	assert(not self.Components[options.Name], `Component "{options.Name}" already exists`)
	assert(not self.IsStarted, `Components cannot be created after calling "Crane:Start()"`)

	const component = Component.new(options) :: Component.Component & T
	self.Components[options.Name] = component

	if _G["CRANE_TRACK_TAGS"] and options.Tag then
		assert(
			typeof(options.Tag) == "string",
			`Component.Tag must be a string; got {type(options.Tag)}`
		)
		assert(
			not table.find(self.TrackedTags, options.Tag),
			`Component.Tag "{options.Tag}" already exists`
		)

		self.TrackedTags[options.Tag] = options.Name
	end

	return component
end

--[=[
	Adds a component instance to a specific Roblox instance.

	This method creates a new instance of the component and attaches it to the provided instance. If the instance already has components, they will share the same component ID.

	```lua
	const part = workspace:FindFirstChild("MyPart")
	const component = Crane:AddComponent(part, "MyComponent")
	```

	@method AddComponent
	@param instance T & Instance
	@param name string
	@return Component<T>
	@within Crane
	@error Throws an error if:
	- The framework has not been started
	- name is not a string or is empty
	- The component does not exist
	- The component already exists on the instance
]=]
function Crane.AddComponent<T>(self: Crane, instance: T & Instance, name: string)
	assert(self.IsStarted, `Cannot add components before calling "Crane:Start()"`)
	assert(type(name) == "string", `Component name must be a string, got {type(name)}`)
	assert(#name > 0, "Component name must be a non-empty string")
	assert(self.Components[name], `Component "{name}" does not exist`)

	const componentId = instance:GetAttribute(COMPONENT_ID_ATTRIBUTE) :: string?
		or HttpService:GenerateGUID(false)

	self.InstantiatedComponents[componentId] = self.InstantiatedComponents[componentId] or {}
	assert(
		not self.InstantiatedComponents[componentId][name],
		`Component "{name}" already exists on instance "{instance:GetFullName()}"`
	)

	instance:SetAttribute(COMPONENT_ID_ATTRIBUTE, componentId)

	const component: Component.Component<T> = self.Components[name]:Instantiate(instance)
	self.InstantiatedComponents[componentId][name] = component

	component.Destroying:Connect(function()
		self.InstantiatedComponents[componentId][name] = nil
	end)

	component:Start()

	return component :: Component.Component<T>
end

--[=[
	Removes a component instance from a specific Roblox instance.

	This method destroys the component and cleans up all associated data.

	```lua
	const part = workspace:FindFirstChild("MyPart")
	Crane:RemoveComponent(part, "MyComponent")
	```

	@method RemoveComponent
	@param instance Instance
	@param name string
	@within Crane
	@error Throws an error if:
	- The framework has not been started
	- name is not a string or is empty
	- The component does not exist
	- The component does not exist on the instance
]=]
function Crane.RemoveComponent(self: Crane, instance: Instance, name: string)
	assert(self.IsStarted, `Cannot remove components before calling "Crane:Start()"`)
	assert(type(name) == "string", `Component name must be a string, got {type(name)}`)
	assert(#name > 0, "Component name must be a non-empty string")
	assert(self.Components[name], `Component "{name}" does not exist`)

	const component =
		self.InstantiatedComponents[instance:GetAttribute(COMPONENT_ID_ATTRIBUTE) :: string][name]
	assert(component, `Component "{name}" does not exist on instance "{instance:GetFullName()}"`)

	self.InstantiatedComponents[instance:GetAttribute(COMPONENT_ID_ATTRIBUTE) :: string][name] = nil
	component:Destroy()
end

return Crane :: Crane
