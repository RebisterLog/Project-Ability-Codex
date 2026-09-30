local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Configuration = ServerScriptService.server.Configuration

local PathUtil = Crane:CreateService({
	Name = "PathUtil",
})

local RootFolder = game.ServerScriptService.server
local Selectors: { [string]: (string) -> Instance? } = {
	["~"] = function(s: string)
		return RootFolder
	end,
}

local Prefixes: { [string]: (typeof(PathUtil), string) -> Instance? } = {
	["@Specs"] = function(self: typeof(PathUtil), s: string)
		local segments = string.split(s, "/")

		local info = self.SpecService:GetInfo({
			Id = segments[2],
		})
		local skillName = ""
		for Idx = 3, #segments do
			skillName = skillName .. segments[Idx] .. (Idx < #segments and "/" or "")
		end

		return info.Skills[skillName]
	end,
}

function PathUtil:onStart()
	self.SpecService = Crane:GetService("SpecService")

	task.delay(1, function()
		--print(self:Parse("@Specs/Standless/Dash"))
	end)
end

function PathUtil:Parse(path: string): Instance? | any
	local segments = string.split(path, "/")
	local globalPrefix = segments[1]
	local current = game

	if Prefixes[globalPrefix] then return Prefixes[globalPrefix](self, path) end

	for i, segment in segments do
		local result
		if Selectors[segment:sub(1)] then
			result = Selectors[segment:sub(1)](segment)
		else
			result = current:FindFirstChild(segment)
		end

		if not result then
			warn("Not correct path:", path, "\n Can't find:", segment)
		else
			current = result
		end
	end

	return current
end

return PathUtil
