--!native
--!optimize 2

local ServerScriptService = game:GetService("ServerScriptService")
local Tags = require(script.Parent.Tags)
local types = require(ServerScriptService.server.types)

local MELEE_LEAD = 8
local PROJECTILE_LEAD = 30
local MEMORY = 0.35

type Track = {
	Distance: number,
}

export type Threat = {
	Character: types.Character,
	Tracks: { [string]: Track },
	LastHit: number,
}

local Threat = {}
Threat.__index = Threat

function Threat.new(character: types.Character): Threat
	return setmetatable({
		Character = character,
		Tracks = {},
		LastHit = -math.huge,
	}, Threat)
end

function Threat:Clear()
	table.clear(self.Tracks)
	self.LastHit = -math.huge
end

function Threat:AverageSize(size: Vector3 | number): number
	if typeof(size) == "number" then return size end

	return (size.X + size.Y + size.Z) / 3
end

function Threat:Track(data: types.HitboxData, target: types.Character, now: number): boolean
	local skill = data.Skill
	if not skill then return false end

	local tags = skill.Data.SkillCharacters
	if not Tags.Has(tags, "Hit") then return false end

	local info = data.Info
	local offset = info.Offset or CFrame.identity
	local origin = info.Origin or (target.RootPart.CFrame * offset)

	local distance = (self.Character.RootPart.Position - origin.Position).Magnitude
	local lead = MELEE_LEAD
	if Tags.Has(tags, "Projectile") then lead = PROJECTILE_LEAD end
	local threshold = self:AverageSize(info.Size) + lead

	local id = skill.Data.Id
	local track = self.Tracks[id]

	local threat = distance <= threshold and (track == nil or distance < track.Distance)
	self.Tracks[id] = { Distance = distance }

	if threat then self.LastHit = now end

	return threat
end

function Threat:IsRecent(now: number): boolean
	return (now - self.LastHit) <= MEMORY
end

return Threat
