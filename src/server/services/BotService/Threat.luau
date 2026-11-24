--!native
--!optimize 2

local types = require(game:GetService("ServerScriptService").server.types)

--- Reaction to incoming hitboxes of the current target.
---
--- This is the event-driven half of the bot: the decision is taken right inside
--- the `CombatService.Casted` handler instead of on the next tick. `Casted` flies
--- before `CombatService:Attack` computes `GetStates`, which is where perfect
--- block versus normal block is decided, so a single frame of delay here costs
--- the whole 0.25s perfect-block window.
---
--- A threat is judged by how the hitbox moves: being inside the radius is not
--- enough on its own (a windup may be aimed elsewhere), while approaching means
--- the hit is actually coming at the bot.

-- Margin added to the hitbox size, for melee and for projectiles: a projectile
-- travels, so it has to be reacted to from further away.
local MELEE_LEAD = 8
local PROJECTILE_LEAD = 30

-- How long a detected threat stays "recent". Keeps the defend posture from
-- flickering between two neighbouring frames.
local MEMORY = 0.35

local function AverageSize(size: Vector3 | number): number
	if typeof(size) == "number" then return size end

	return (size.X + size.Y + size.Z) / 3
end

type Track = {
	Distance: number,
}

export type ThreatProperties = {
	Character: types.Character,
	Tracks: { [string]: Track },
	LastHit: number,
}

export type Threat = ThreatProperties

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

--- Does this hitbox hit the bot? `true` means react now.
function Threat.Track(self: Threat, data: types.HitboxData, target: types.Character): boolean
	local skill = data.Skill
	if not skill then return false end

	local tags = skill.Data.SkillCharacters
	if not table.find(tags, "Hit") then return false end

	local info = data.Info
	local offset = info.Offset or CFrame.identity
	local origin = info.Origin or (target.RootPart.CFrame * offset)

	local distance = (self.Character.RootPart.Position - origin.Position).Magnitude

	local threshold = AverageSize(info.Size)
		+ (if table.find(tags, "Projectile") then PROJECTILE_LEAD else MELEE_LEAD)

	local id = skill.Data.Id
	local track = self.Tracks[id]

	-- The first sighting only counts when the hitbox is already close; every
	-- later one only counts while it keeps approaching.
	local threat = distance <= threshold and (track == nil or distance < track.Distance)

	self.Tracks[id] = { Distance = distance }

	if threat then self.LastHit = os.clock() end

	return threat
end

--- A hit landed recently, so the bot is still backing off.
function Threat.IsRecent(self: Threat): boolean
	return (os.clock() - self.LastHit) <= MEMORY
end

return Threat
