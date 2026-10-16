--!native
--!strict

const Stack = {}
Stack.__index = Stack

type StackData<T> = {
	Stack: { [number]: { [string]: T } },
	Cache: { { Name: string, Value: T, Priority: number } },
}

export type Stack<T> = setmetatable<StackData<T>, typeof(Stack)>

function Stack.new<T>(): Stack<T>
	const self = setmetatable({
		Stack = {},
		Cache = {},
	}, Stack)

	return self :: Stack<T>
end

function Stack.Update<T>(self: Stack<T>)
	table.clear(self.Cache)

	for priority, entries in pairs(self.Stack) do
		for name, value in pairs(entries) do
			table.insert(self.Cache, {
				Name = name,
				Value = value,
				Priority = priority,
			})
		end
	end

	table.sort(self.Cache, function(a: { Priority: number }, b: { Priority: number })
		return a.Priority > b.Priority
	end)
end

function Stack.Add<T>(self: Stack<T>, name: any, value: any, priority: number)
	local bucket = self.Stack[priority]
	if not bucket then
		bucket = {}
		self.Stack[priority] = bucket
	end

	bucket[name] = value
	self:Update()
end

function Stack.Remove<T>(self: Stack<T>, name: string)
	for _, bucket in self.Stack do
		bucket[name] = nil
	end

	self:Update()
end

function Stack.Get<T>(self: Stack<T>, name: string): T?
	for _, bucket in self.Stack do
		if bucket[name] then return bucket[name] end
	end

	return nil
end

function Stack.GetAll<T>(self: Stack<T>)
	return self.Cache
end

function Stack.Destroy<T>(self: Stack<T>)
	table.clear(self.Cache)
	table.clear(self.Stack)
end

return Stack
