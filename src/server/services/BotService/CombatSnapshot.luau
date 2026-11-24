--!native
--!optimize 2

local ServerScriptService = game:GetService("ServerScriptService")
local Tags = require(script.Parent.Tags)
local types = require(ServerScriptService.server.types)

export type Snapshot = {
	Tick: number,
	Character: types.Character,

	NoSkillCast: boolean,
	Stun: number,
	Ragdoll: boolean,
	Restand: boolean,
	Health: number,
	Armor: boolean,
	IFrames: number,

	HasActiveSkills: boolean,
	ActiveTagMask: number,
	HasStand: boolean,
	StandActive: boolean,

	Cooldowns: { [string]: number },
	Enabled: { [string]: boolean },
	Active: { [string]: boolean },

	Refresh: (self: Snapshot, character: types.Character, tickId: number) -> Snapshot,
}

type StandServiceLike = {
	GetStand: (self: StandServiceLike, character: types.Character) -> types.Stand?,
}

local SNAPSHOTS: { [types.Character]: Snapshot } = {}

local CombatSnapshot = {}
CombatSnapshot.__index = CombatSnapshot

local standService: StandServiceLike? = nil

function CombatSnapshot:Configure(services: { StandService: StandServiceLike })
	standService = services.StandService
end

local function collect(
	self: Snapshot,
	spec: types.Spec?,
	hasActive: boolean,
	activeMask: number
): (boolean, number)
	if not spec then return hasActive, activeMask end

	for id, skill in spec.Skills do
		local parameters = skill.Proxy().Parameters

		self.Cooldowns[id] = parameters.ReleaseTime
		self.Enabled[id] = parameters.Enabled
		self.Active[id] = skill.Active

		if skill.Active then
			hasActive = true
			activeMask = bit32.bor(activeMask, Tags.Mask(skill.Data.SkillCharacters))
		end
	end

	return hasActive, activeMask
end

function CombatSnapshot.new(character: types.Character): Snapshot
	return setmetatable({
		Tick = -1,
		Character = character,

		NoSkillCast = false,
		Stun = 0,
		Ragdoll = false,
		Restand = false,
		Health = 0,
		Armor = false,
		IFrames = 0,

		HasActiveSkills = false,
		ActiveTagMask = 0,
		HasStand = false,
		StandActive = false,

		Cooldowns = {},
		Enabled = {},
		Active = {},
	}, CombatSnapshot) :: Snapshot
end

function CombatSnapshot:Get(character: types.Character): Snapshot
	local snapshot = SNAPSHOTS[character]
	if snapshot then return snapshot end

	snapshot = CombatSnapshot.new(character)
	SNAPSHOTS[character] = snapshot

	return snapshot
end

function CombatSnapshot:Forget(character: types.Character)
	SNAPSHOTS[character] = nil
end

function CombatSnapshot:Refresh(character: types.Character, tickId: number): Snapshot
	if self.Tick == tickId and self.Character == character then return self end

	self.Tick = tickId
	self.Character = character

	self.NoSkillCast = character:GetParameter("NoSkillCast") == true
	self.Stun = character:GetParameter("Stun").Duration
	self.Ragdoll = character:GetParameter("Ragdoll") == true
	self.Restand = character:GetParameter("Restand") == true
	self.Health = character.Humanoid.Health
	self.Armor = character:GetParameter("Armor") == true
	self.IFrames = character:GetParameter("IFrames")

	table.clear(self.Cooldowns)
	table.clear(self.Enabled)
	table.clear(self.Active)

	local hasActive, activeMask = collect(self, character.SubSpec, false, 0)
	hasActive, activeMask = collect(self, character.Spec, hasActive, activeMask)

	self.HasActiveSkills = hasActive
	self.ActiveTagMask = activeMask

	local stand = standService and standService:GetStand(character)
	self.HasStand = stand ~= nil
	self.StandActive = stand ~= nil and stand:IsActive()

	return self
end

function CombatSnapshot.IsBasicValid(snapshot: Snapshot, skill: types.Skill, now: number): boolean
	if snapshot.NoSkillCast then return false end
	if snapshot.Stun > 0 then return false end
	if snapshot.Ragdoll then return false end
	if snapshot.Health <= 0 then return false end
	if (snapshot.Cooldowns[skill.Data.Id] or 0) > now then return false end

	return true
end

function CombatSnapshot.IsSkillValid(snapshot: Snapshot, skill: types.Skill, now: number): boolean
	if not CombatSnapshot.IsBasicValid(snapshot, skill, now) then return false end
	if snapshot.Restand then return false end
	if snapshot.Enabled[skill.Data.Id] == false then return false end

	return true
end

return CombatSnapshot
