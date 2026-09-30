--!native
--!strict

local Stack = require(script.Stack)

type CheckCallback<T> = (T) -> boolean

type HookData = {
	Name: string,
	Stacks: { [string]: Stack.Stack<CheckCallback<any>> },
	StackOrder: { string },
}

local Hook = {}
Hook.__index = Hook

export type Hook = setmetatable<HookData, typeof(Hook)>

function Hook.Hook(
	self: Hook,
	stack: string,
	identifier: string,
	priority: number,
	callback: () -> boolean
)
	if not self.Stacks[stack] then return end

	local stack = self.Stacks[stack]
	stack:Add(identifier, callback, priority)
end

function Hook.Unhook(self: Hook, stack: string, identifier: string)
	if not self.Stacks[stack] then return end
	if not self.Stacks[stack]:Get(identifier) then return end

	local stack = self.Stacks[stack]
	stack:Remove(identifier)
end

function Hook.Apply<T>(self: Hook, state: T): T
	for _, stackName in self.StackOrder do
		local stack = self.Stacks[stackName]
		for i, entry in stack:GetAll() do
			local result = entry.Value(state)

			if not result then return state end
		end
	end

	return state
end

function Hook.CreateStack(self: Hook, name: string)
	if self.Stacks[name] then return end
	self.Stacks[name] = Stack.new() :: Stack.Stack<CheckCallback<any>>
	table.insert(self.StackOrder, name)
end

function Hook.Destroy(self: Hook)
	for i, stack in self.Stacks do
		stack:Destroy()
	end

	table.clear(self.Stacks)
end

return {
	new = function(name: string?, stacks: { string }?): Hook
		local self = setmetatable({
			Name = name,
			Stacks = {},
			StackOrder = {},
		}, Hook) :: Hook

		if stacks then
			for i, name in stacks do
				self:CreateStack(name)
			end
		end

		return self
	end,
}
