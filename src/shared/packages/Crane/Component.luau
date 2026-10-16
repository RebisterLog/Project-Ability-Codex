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

const COMPONENT_ID_ATTRIBUTE = "CraneComponentId"

const Signal = require(script.Parent.packages.Signal)
const Log = require(script.Parent.Utils).Log

--[=[
	The Component module provides the base class for all components in the Crane framework.

	Components are reusable pieces of functionality that can be attached to Roblox instances.
	They support lifecycle callbacks, automatic cleanup, and can be automatically instantiated
	via CollectionService tags.

	@class Component
]=]
const Component = {}
Component.__index = Component
Component.__tostring = "CraneComponent"

-- Types
--[=[
	Configuration table for creating a new component.

	@type ComponentDef <T = {any}?>{Name: string, Tag: string?, BaseComponent: T?}
	@within Component
]=]
export type ComponentDef<T = { any }?> = {
	--[=[
		The unique name of the component.

		@prop Name string
		@within ComponentDef
	]=]
	Name: string,
	--[=[
		Optional CollectionService tag for automatic component instantiation.

		@prop Tag string?
		@within ComponentDef
	]=]
	Tag: string?,
	--[=[
		Optional base table to extend with component functionality.

		@prop BaseComponent T
		@within ComponentDef
	]=]
	BaseComponent: T,
}

--[=[
	Internal data structure for component instances.

	@type ComponentData <T>ComponentDef & {instance: T, Destroying: Signal.Signal<nil>, onStart: ((self: Component<T>) -> ())?}
	@within Component
]=]
export type ComponentData<T> = ComponentDef & {
	--[=[
		The Roblox instance this component is attached to.

		@prop instance T
		@readonly
		@within ComponentData
	]=]
	instance: T,
	--[=[
		Signal that fires when the component is being destroyed.

		@prop Destroying Signal.Signal<nil>
		@readonly
		@within ComponentData
	]=]
	Destroying: Signal.Signal<nil>,
	--[=[
		Optional callback function that is called when the component starts.

		@prop onStart ((self: Component<T>) -> ())?
		@within ComponentData
	]=]
	onStart: ((self: Component<T>) -> ())?,
}

--[=[
	Represents a component instance in the Crane framework.

	@type Component <T = Instance>setmetatable<ComponentData<T>, typeof(Component)>
	@within Component
]=]
export type Component<T = Instance> = setmetatable<ComponentData<T>, typeof(Component)>

--[=[
	Creates a new component definition. This is typically called by `Crane:CreateComponent`.

	```lua
	const component = Component.new({
		Name = "MyComponent",
		Tag = "MyComponentTag",
		BaseComponent = {},
	})
	```

	@method new
	@param options ComponentDef<T>
	@return Component<T>
	@within Component
]=]
function Component.new<T>(options: ComponentDef<T>)
	const self = (options.BaseComponent or {}) :: ComponentDef<T>
	self.Name = options.Name
	self.Tag = options.Tag

	return setmetatable(self, Component) :: Component & T
end

--[=[
	Creates a new instance of this component attached to a specific Roblox instance.

	This method is typically called by `Crane:AddComponent` and should not be called directly in most cases.

	```lua
	const componentInstance = component:Instantiate(workspace.Part)
	```

	@method Instantiate
	@param instance T & Instance
	@return Component<T>
	@within Component
]=]
function Component.Instantiate<T>(self: Component<T>, instance: T & Instance)
	const prototype = setmetatable({
		instance = instance,
		Destroying = Signal(),
	}, {
		__index = self,
	}) :: Component<T>

	local destroyed = false
	instance.Destroying:Connect(function()
		if destroyed then return end

		destroyed = true
		prototype.Destroying:Fire()
		prototype:Destroy()
	end)

	return prototype :: Component<T>
end

function Component.GetId<T>(self: Component<T>)
	return (self.instance :: Instance):GetAttribute(COMPONENT_ID_ATTRIBUTE)
end

--[=[
	Destroys the component instance, firing the Destroying signal and cleaning up resources.

	```lua
	component:Destroy()
	```

	@method Destroy
	@within Component
]=]
function Component.Destroy<T>(self: Component<T>) end

--[=[
	Starts the component by calling the `onStart` callback if it exists.

	This method is automatically called by `Crane:AddComponent` and should not be called manually in most cases.

	If `CRANE_DEBUGGING` is enabled, errors are caught and logged instead of being thrown.

	@method Start
	@within Component
]=]
function Component.Start<T>(self: Component<T>)
	if not self.onStart then return end

	if _G["CRANE_DEBUGGING"] then
		const success, err = pcall(self.onStart, self)

		if not success then
			Log(self.Name, err, "warn")
		else
			Log(self.Name, "Successfully started")
		end
	else
		self:onStart()
	end
end

return Component
