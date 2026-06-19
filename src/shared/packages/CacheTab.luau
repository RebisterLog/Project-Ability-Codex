--!native
--!strict
--!optimize 2

local FAR_AWAY_POINT = Vector3.new(10e8, 10e8, 10e8)

local CacheTab = {}
CacheTab.__index = CacheTab

type CacheTabData<T> = {
	Origin: T&Instance,
	CachedItems: { T&Instance },
	
	-- Колбеки при кешировании и инстанцинировании
	StoreCallback: (T&Instance, Vector3) -> (),
	UnstoreCallback: (T&Instance) -> (),
	Parent: Instance?
}

export type CacheTab<T> = setmetatable<CacheTabData<T>, typeof(CacheTab)>

function CacheTab.new<T>(origin: T, precreate: number, storeCallback: (T, Vector3) -> (), unstoreCallback: (T) -> (), parent: Instance?): CacheTab<T>
	local newTab = setmetatable({
		Origin = origin,
		CachedItems = {},

		UnstoreCallback = unstoreCallback,
		StoreCallback = storeCallback,
		Parent = parent
	}, CacheTab) :: CacheTab<T>
	
	newTab:Expand(precreate or 0)

	return newTab
end

function CacheTab.Expand<T>(self: CacheTab<T>, count: number)
	for i = 1, count do
		self:Add(self.Origin:Clone())
	end
end

function CacheTab.Add<T>(self: CacheTab<T>, item: T&Instance)
	table.insert(self.CachedItems, item)
	self.StoreCallback(item, FAR_AWAY_POINT)
	
	if self.Parent then
		item.Parent = self.Parent
	end
end

function CacheTab.Get<T>(self: CacheTab<T>): T
	if self:IsEmpty() then
		self:Expand(2)
	end 
	
	local item = table.remove(self.CachedItems)
	if not item then return nil end
	
	self.UnstoreCallback(item)

	return item
end

function CacheTab.IsEmpty<T>(self: CacheTab<T>)
	if #self.CachedItems == 0 then return true end
	
	return false
end

function CacheTab.Dispose<T>(self: CacheTab<T>)
	table.clear(self.CachedItems)
	
	for item in self.CachedItems do
		self.CachedItems[item]:Destroy()
	end
end

function CacheTab.Destroy<T>(self: CacheTab<T>)
	self:Dispose()
end

--[[ EXAMPLE
	local someModel = Instance.new("Model")
	someModel.Name = "SomeModel"
	someModel.Parent = workspace

	local x = CacheTab.new(
		someModel,
		30,

		function(model: Model, pos)
			model:PivotTo(CFrame.new(pos))
		end,
		
		function(model)
			model:PivotTo(CFrame.new(0,0,0))
		end
	)

	local clone = x:Get()
	x:Add(clone)
]]

return CacheTab
