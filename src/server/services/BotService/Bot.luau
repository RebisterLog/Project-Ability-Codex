--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Attack = require(script.Parent.Attack)
local BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])
local CombatSnapshot = require(script.Parent.CombatSnapshot)
local Conditions = require(script.Parent.Conditions)
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Defense = require(script.Parent.Defense)
local NavigationController = require(script.Parent.NavigationController)
local Posture = require(script.Parent.Posture)
local Sense = require(script.Parent.Sense)
local SkillIndex = require(script.Parent.SkillIndex)
local SkillPriority = require(script.Parent.SkillPriority)
local Threat = require(script.Parent.Threat)
local types = require(ServerScriptService.server.types)

local bor = bit32.bor

local TICK_INTERVAL = 1 / 60

type BotProperties = {
	Target: types.Character?,
	Navigator: NavigationController.NavigationController,
	Config: BotsCharacters.BotCharacterConfig,
	SkillIndex: SkillIndex.SkillIndex,
	Cleaner: typeof(Crane.Buttler.new()),
	TargetCleaner: typeof(Crane.Buttler.new()),
	Character: types.Character,
	Destroyed: boolean,

	Posture: Posture.Posture,
	Roles: Defense.Roles,
	Sense: Sense.Sense,
	Threat: Threat.Threat,

	Combo: BotsCharacters.SkillCombo,
	ComboIndex: number,

	HeldSkill: string?,
	HeldAt: number,
	Repeats: { [string]: { Count: number, At: number } },
	Blocked: { [string]: boolean },
	NavBlocked: boolean,
	DodgeIntent: boolean,

	Random: Random,
	Accumulator: number,
}

type BotMethods = {
	SetTarget: (self: Bot, character: types.Character?) -> (),
	ClearTarget: (self: Bot) -> (),
	OnIncoming: (self: Bot, data: types.HitboxData, now: number) -> (),
	Tick: (self: Bot, dt: number, tickId: number, now: number) -> (),
	SetPosture: (self: Bot, posture: Posture.Posture) -> (),

	IsGuardHeld: (self: Bot) -> boolean,
	IsGuardOnCooldown: (self: Bot) -> boolean,
	ReleaseGuard: (self: Bot) -> (),

	ReleaseHeld: (self: Bot) -> (),
	UpdateHeld: (self: Bot, mask: number, now: number) -> (),

	ActivateSkill: (self: Bot, id: string, owner: types.Spec?, spawned: boolean?) -> (),
	Destroy: (self: Bot) -> (),
}

export type Bot = BotProperties & BotMethods

local Bot = {}
Bot.__index = Bot

function Bot.ResolveSkin(specId: string, skinName: string?): string
	local requested = skinName or "None"
	if requested == "None" then return "None" end

	local skins = Crane:GetService("ConfigService"):Get("Skins")
	local specSkins = skins and skins[specId]
	if specSkins and specSkins[requested] then return requested end

	return "None"
end

function Bot.IsGuardHeld(self: Bot): boolean
	local guardId = self.Roles.Guard
	if not guardId then return false end

	local guard, _ = self.SkillIndex:Find(guardId)
	return guard ~= nil and guard.Active
end

function Bot.IsGuardOnCooldown(self: Bot): boolean
	local guardId = self.Roles.Guard
	if not guardId then return true end

	local guard, _ = self.SkillIndex:Find(guardId)
	if not guard then return true end

	return guard:IsOnCooldown()
end

function Bot.ReleaseGuard(self: Bot)
	local guardId = self.Roles.Guard
	if not guardId then return end

	local _, spec = self.SkillIndex:Find(guardId)
	if spec then spec:DeactivateSkill(guardId) end
end

function Bot.ReleaseHeld(self: Bot)
	local skillId = self.HeldSkill
	if not skillId then return end

	self.HeldSkill = nil

	local _, spec = self.SkillIndex:Find(skillId)
	if spec then spec:DeactivateSkill(skillId) end
end

function Bot.UpdateHeld(self: Bot, mask: number, now: number)
	local skillId = self.HeldSkill
	if not skillId then return end

	local skill, _ = self.SkillIndex:Find(skillId)
	if not skill or not skill.Active then
		self.HeldSkill = nil
		return
	end

	local options = self.Config.Skills[skillId]
	local holdMax = options and options.HoldMaxTime

	if holdMax and now - self.HeldAt >= holdMax then
		self:ReleaseHeld()
		return
	end

	if SkillPriority.ShouldRelease(self.Config, skillId, mask, nil) then self:ReleaseHeld() end
end

function Bot.SetPosture(self: Bot, posture: Posture.Posture)
	if self.Posture == posture then return end

	local previous = self.Posture
	self.Posture = posture

	local style = Posture.Get(posture)
	local movementStyle = if posture == "Attack"
		then Posture.RollAttackStyle(self.Config, self.Random)
		elseif posture == "Defend" then Posture.RollDefendStyle(self.Config, self.Random)
		else style.Style

	self.Navigator:SetMovementStyle(movementStyle)
	self.Navigator:SetHoldDistance(style.HoldDistance)

	if previous == "Defend" and posture ~= "Defend" then self:ReleaseGuard() end
end

function Bot.ActivateSkill(_self: Bot, id: string, owner: types.Spec?, spawned: boolean?)
	if not owner then return end

	if spawned then
		task.spawn(function()
			owner:ActivateSkill(id)
		end)
	else
		owner:ActivateSkill(id)
	end
end

function Bot.OnIncoming(self: Bot, data: types.HitboxData, now: number)
	local target = self.Target
	if not target then return end
	if not self.Threat:Track(data, target, now) then return end

	self:ReleaseHeld()
	self:SetPosture("Defend")

	local decision = Defense.React(data, {
		GuardId = self.Roles.Guard,
		EscapeId = self.Roles.Escape,
		GuardHeld = self:IsGuardHeld(),
		GuardOnCooldown = self:IsGuardOnCooldown(),
	})

	local skillId = if decision == "Press"
		then self.Roles.Guard
		else if decision == "Escape" then self.Roles.Escape else nil
	if not skillId then return end

	local _, spec = self.SkillIndex:Find(skillId)
	self:ActivateSkill(skillId, spec, true)
end

function Bot.Tick(self: Bot, dt: number, tickId: number, now: number)
	self.Accumulator += dt
	if self.Accumulator < TICK_INTERVAL then return end

	self.Accumulator -= TICK_INTERVAL
	if self.Accumulator > TICK_INTERVAL then self.Accumulator = 0 end

	if not self.Target then
		self:SetPosture("Idle")
		return
	end

	self.Sense:Refresh(tickId)

	local mask = self.Sense.Mask
	local recent = self.Threat:IsRecent(now)
	if recent then mask = bor(mask, Conditions.Bit("OWN_THREATENED")) end

	self:UpdateHeld(mask, now)

	local guardId = self.Roles.Guard
	local released = false
	if
		guardId
		and self:IsGuardHeld()
		and Defense.ShouldReleaseGuard(self.Config, guardId, mask)
	then
		self:ReleaseGuard()
		released = true
	end

	if released then CombatSnapshot:Get(self.Character):Refresh(self.Character, -1) end

	if self.HeldSkill == "Charge" then
		self:SetPosture("Charge")
		return
	end

	if Defense.ShouldDefend(mask, recent) then
		self:SetPosture("Defend")
		return
	end

	self:SetPosture("Attack")

	local navState = self.Navigator:GetState()
	self.NavBlocked = navState == "Pathfinding"
		or navState == "FollowingPath"
		or navState == "HoldingDistance"
	self.DodgeIntent = Conditions.Has(mask, "TARGET_ATTACKING")
		or Conditions.Has(mask, "OWN_THREATENED")

	local id, mode = Attack.Step(self, mask, self.Sense.Distance, now)
	if not id then return end

	if mode == "summon" then
		self:ActivateSkill("Summon", self.SkillIndex:SummonOwner())
		return
	end

	local _, owner = self.SkillIndex:Find(id)
	if mode == "hold" then
		self.HeldSkill = id
		self.HeldAt = now
	end

	self:ActivateSkill(id, owner, mode == "hold")
end

function Bot.SetTarget(self: Bot, character: types.Character?)
	if not character then
		self:ClearTarget()
		return
	end

	if self.Target == character then return end
	if not (character.Spec or character.SubSpec) then return end

	self.TargetCleaner:Clean()
	if self.Target then CombatSnapshot:Forget(self.Target) end

	self.Target = character
	self.Navigator:SetTarget(character.RootPart)
	self.Sense:SetTarget(character)
	self.Threat:Clear()

	table.clear(self.Repeats)

	self.TargetCleaner:Add(character.Destroying:Once(function()
		self:ClearTarget()
	end))

	self:SetPosture("Defend")
end

function Bot.ClearTarget(self: Bot)
	self.TargetCleaner:Clean()

	self:ReleaseGuard()
	self:ReleaseHeld()

	if self.Target then CombatSnapshot:Forget(self.Target) end
	self.Target = nil
	self.Sense:ClearTarget()
	self.Threat:Clear()

	table.clear(self.Repeats)

	self:SetPosture("Idle")
	self.Navigator:ClearTarget()
end

function Bot.Destroy(self: Bot)
	self.Destroyed = true
	self.TargetCleaner:Clean()
	self.Cleaner:Destroy()
	CombatSnapshot:Forget(self.Character)

	self.Character.Navigator = nil
end

return {
	new = function(character: types.Character, config: BotsCharacters.BotCharacterConfig): Bot
		character:SetSpec(config.Spec, Bot.ResolveSkin(config.Spec, config.SpecSkin))
		if config.SubSpec then
			character:SetSpec(config.SubSpec, Bot.ResolveSkin(config.SubSpec, config.SubSpecSkin))
		end

		local primarySpec = character.Spec
		local random = Random.new()

		local navigator = NavigationController.new(character.instance, {
			ReachDistance = 5,
			HoldDistance = config.Aggressive < 0.5 and 20 or nil,
			ObstacleCheckDistance = 5,
			ObstacleCheckRadius = 4,
			PathRecalculateInterval = 5,
			PathRecalculateDistance = 15,
			AutoJump = true,
			RotateToTarget = true,
			Style = NavigationController.MovementStyles.direct,
			Debug = config.Debug or false,
		})

		character.Navigator = navigator

		local cleaner = character.Cleaner:Scope()
		cleaner:Set("Navigator", navigator)

		local skillIndex = SkillIndex.new(character, config)

		local bot = setmetatable({
			Navigator = navigator,
			Config = config,
			SkillIndex = skillIndex,
			Cleaner = cleaner,
			TargetCleaner = cleaner:Scope(),
			Target = nil,
			Character = character,
			Destroyed = false,

			Posture = "Idle",
			Roles = skillIndex:ResolveRoles(config.Skills),
			Sense = Sense.new(character),
			Threat = Threat.new(character),

			Combo = Attack.RollCombo(config, random),
			ComboIndex = 1,

			HeldSkill = nil,
			HeldAt = 0,

			Repeats = {},
			Blocked = {},
			NavBlocked = false,
			DodgeIntent = false,

			Random = random,
			Accumulator = 0,
		}, Bot)

		if primarySpec then primarySpec:ActivateSkill("Run") end

		cleaner:Add(character.OnTakeDamage:Connect(function(attacker)
			if not attacker then return end

			bot:SetTarget(attacker)
		end))

		Crane:GetService("CollisionService"):SetCollisionGroup("NPC", character.instance)

		return bot
	end,
}
