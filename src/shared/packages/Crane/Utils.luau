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

--!native
--!strict
--!optimize 2

--[=[
	Utility functions module for the Crane framework.

	Provides logging functionality with different severity levels (info, warn, error)
	that can be used throughout the framework for debugging and error reporting.

	@class Utils
]=]

local HttpService = game:GetService("HttpService")

type LogLevel = "info" | "warn" | "error"
local function Log(owner: string, reason: string, level: LogLevel?)
	level = level or "info"

	local logMsg = `[{owner}] {reason}`

	if level ~= "info" then warn(debug.traceback(logMsg, 5)) end

	if level == "info" then
		print(logMsg)
	elseif level == "warn" then
		warn(logMsg)
	elseif level == "error" then
		error(logMsg)
	end
end

local function DeepClone<T>(t: T & {}): T
	if typeof(t) ~= "table" then return t end

	local new = table.clone(t) :: T & {}

	for k, v in pairs(t) do
		if type(v) == "table" then new[k] = DeepClone(v) end
	end

	return new
end

local function DeepFreeze<T>(t: T & {}): T
	if typeof(t) ~= "table" or table.isfrozen(t) then return t end

	for _, v in pairs(t) do
		if type(v) == "table" then DeepFreeze(v) end
	end

	return table.freeze(t)
end

local function Reconcile<S, T>(src: S, template: T): S & T
	assert(type(src) == "table", "First argument must be a table")
	assert(type(template) == "table", "Second argument must be a table")

	local tbl = table.clone(src)

	for k, v in template do
		local sv = src[k]
		if sv == nil then
			if type(v) == "table" then
				tbl[k] = Copy(v, true)
			else
				tbl[k] = v
			end
		elseif type(sv) == "table" then
			if type(v) == "table" then
				tbl[k] = Reconcile(sv, v)
			else
				tbl[k] = Copy(sv, true)
			end
		end
	end

	return (tbl :: any) :: S & T
end

local function Extend<T, E>(target: { T }, extension: { E }): { T } & { E }
	local tbl = table.clone(target) :: { any }
	for _, v in extension do
		table.insert(tbl, v)
	end
	return tbl
end

local function BezierCurve(t: number, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3): Vector3
	return Vector3.zero
end

local function SafeChangeNetworkOwner(object: BasePart | Model, owner: Player?)
	if object:IsA("Model") then
		for _, v in object:QueryDescendants("BasePart") :: { BasePart } do
			if v:CanSetNetworkOwnership() then v:SetNetworkOwner(owner) end
		end
	end

	if object:IsA("BasePart") then
		if object:CanSetNetworkOwnership() then object:SetNetworkOwner(owner) end
	end
end

local function PointPart(cframe: CFrame)
	local part = Instance.new("Part")
	part.Size = Vector3.one
	part.Anchored = true
	part.Transparency = 0.6
	part.CanCollide = false
	part.CFrame = cframe
	part.Color = Color3.new(1, 0, 0)
	part.Parent = workspace
	return part
end

local function GenerateUUID(): string
	return HttpService:GenerateGUID(false)
end

return {
	Log = Log,
	DeepClone = DeepClone,
	DeepFreeze = DeepFreeze,
	Reconcile = Reconcile,
	Extend = Extend,
	ChangeNetworkOwner = SafeChangeNetworkOwner,
	PointPart = PointPart,
	GenerateUUID = GenerateUUID,
}
