const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Configuration = ServerScriptService.server.Configuration

const PathUtil = Crane:CreateService({
	Name = "PathUtil",
})

const RootFolder = game.ServerScriptService.server
const Selectors: { [string]: (string) -> Instance? } = {
	["~"] = function(s: string)
		return RootFolder
	end,
}

const Prefixes: { [string]: (typeof(PathUtil), string) -> Instance? } = {
	["@Specs"] = function(self: typeof(PathUtil), s: string)
		const segments = string.split(s, "/")

		const info = self.SpecService:GetInfo({
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
	const segments = string.split(path, "/")
	const globalPrefix = segments[1]
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
