--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])
local types = require(ServerScriptService.server.types)

local Crane = require(ReplicatedStorage.shared.packages.Crane)
local NavigationController = require(script.Parent.NavigationController)

local Attack = require(script.Parent.Attack)
local Conditions = require(script.Parent.Conditions)
local Defense = require(script.Parent.Defense)
local Posture = require(script.Parent.Posture)
local Sense = require(script.Parent.Sense)
local SkillPriority = require(script.Parent.SkillPriority)
local Threat = require(script.Parent.Threat)

local bor = bit32.bor

--- The bot: target, navigation, spec.
---
--- There are exactly two decisions here and they live in separate layers:
---   * defense is event driven (`OnIncoming`), because the perfect-block window is
---     0.25 seconds long and a single frame of delay decides whether it happens;
---   * attack runs on the tick (`Tick`), because plans and priorities are in no
---     hurry.
---
--- Owns the action slot: while the slot is held by the defense the attack leaves it
--- alone, and an incoming threat preempts the attack. A state machine used to do
--- this, but the states differed only by posture, so telling them apart was
--- pointless.

-- How often the bot thinks. The tick is not bound to a frame: the decision is made
-- on accumulated time so the behaviour does not depend on FPS.
local TICK_INTERVAL = 1 / 30

--- Bots bypass SkinModule's ownership check, so a typo in a bot config would
--- make SpecService return nil and leave the bot without a spec. Fall back to
--- the built-in skin instead.
local function resolveSkin(specId: string, skinName: string?): string
	const requested = skinName or "None"
	if requested == "None" then return "None" end

	const skins = Crane:GetService("ConfigService"):Get("Skins")
	const specSkins = skins and skins[specId]
	if specSkins and specSkins[requested] then return requested end

	return "None"
end

--- Only `Casted` is needed from the service, so it is described here instead of
--- dragging the types of the whole CombatService in, and `typeof` does not accept
--- calls.
type CombatServiceLike = {
	Casted: {
		Connect: (self: any, callback: (data: types.HitboxData) -> ()) -> RBXScriptConnection,
	},
}

type BotProperities = {
	Target: types.Character?,
	Navigator: NavigationController.NavigationController,
	Config: BotsCharacters.BotCharacterConfig,
	Cleaner: typeof(Crane.Buttler.new()),
	TargetCleaner: typeof(Crane.Buttler.new()),
	Character: types.Character,

	CombatService: CombatServiceLike,

	Posture: Posture.Posture,

	Roles: Defense.Roles,
	Sense: Sense.Sense,
	Threat: Threat.Threat,

	Combo: BotsCharacters.SkillCombo,
	ComboIndex: number,

	-- A skill held by the bot (Charge) and the time it was pressed. The timeout
	-- is the guard against "forgot to release" when no condition fires.
	HeldSkill: string?,
	HeldAt: number,

	Random: Random,
	Accumulator: number,
}

type BotMethods = {
	SetTarget: (self: Bot, character: types.Character?) -> (),
	ClearTarget: (self: Bot) -> (),

	OnIncoming: (self: Bot, data: types.HitboxData) -> (),
	Tick: (self: Bot, dt: number) -> (),
	SetPosture: (self: Bot, posture: Posture.Posture) -> (),

	IsGuardHeld: (self: Bot) -> boolean,
	IsGuardOnCooldown: (self: Bot) -> boolean,
	ReleaseGuard: (self: Bot) -> (),

	ReleaseHeld: (self: Bot) -> (),
	UpdateHeld: (self: Bot, mask: number) -> (),

	Destroy: (self: Bot) -> (),
}

export type Bot = BotProperities & BotMethods

local Bot = {}
Bot.__index = Bot

--- Defense roles come from the tags of the skills of the specs and not from the
--- config: the skill itself decides what it is, the guard or the retreat.
local function CollectRoles(specs: { types.Spec? }): { Defense.RoleSkill }
	local roles: { Defense.RoleSkill } = {}

	for _, spec in specs do
		if not spec then continue end

		for id, skill in spec.Skills do
			table.insert(roles, { Id = id, Tags = skill.Data.SkillCharacters })
		end
	end

	return roles
end

--- Skills may live in either slot: Standless owns Block/Dash/Punch, Hamon owns
--- the Hamon skills. Helpers below always look in both.
local function Specs(self: Bot): { types.Spec? }
	return { self.Character.SubSpec, self.Character.Spec }
end

local function FindSkill(self: Bot, id: string): (types.Skill?, types.Spec?)
	for _, spec in Specs(self) do
		if not spec then continue end

		const skill = spec.Skills[id]
		if skill then return skill, spec end
	end

	return nil, nil
end

function Bot.IsGuardHeld(self: Bot): boolean
	local guardId = self.Roles.Guard
	if not guardId then return false end

	const guard, _ = FindSkill(self, guardId)

	return guard ~= nil and guard.Active
end

--- No guard counts as "unavailable": the defense then falls back to the escape.
function Bot.IsGuardOnCooldown(self: Bot): boolean
	local guardId = self.Roles.Guard
	if not guardId then return true end

	const guard, _ = FindSkill(self, guardId)
	if not guard then return true end

	return guard:IsOnCooldown()
end

function Bot.ReleaseGuard(self: Bot)
	local guardId = self.Roles.Guard
	if not guardId then return end

	const _, spec = FindSkill(self, guardId)
	if spec then spec:DeactivateSkill(guardId) end
end

--- Drop a held resource skill right now: used by incoming hits and by
--- `UpdateHeld` once any release rule fires.
function Bot.ReleaseHeld(self: Bot)
	const skillId = self.HeldSkill
	if not skillId then return end

	self.HeldSkill = nil

	const _, spec = FindSkill(self, skillId)
	if spec then spec:DeactivateSkill(skillId) end
end

function Bot.UpdateHeld(self: Bot, mask: number)
	const skillId = self.HeldSkill
	if not skillId then return end

	-- An interrupt (stun, ragdoll, death) can end the skill without going
	-- through our release rules: forget it instead of holding a stale id.
	const skill, _ = FindSkill(self, skillId)
	if not skill or not skill.Active then
		self.HeldSkill = nil
		return
	end

	const options = self.Config.Skills[skillId]
	const holdMax = options and options.HoldMaxTime

	if holdMax and os.clock() - self.HeldAt >= holdMax then
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
		else style.Style

	self.Navigator:SetMovementStyle(movementStyle)
	self.Navigator:SetHoldDistance(style.HoldDistance)

	-- The guard is only held while the bot backs off: in an attack the slot has to
	-- be free.
	if previous == "Defend" and posture ~= "Defend" then self:ReleaseGuard() end
end

--- Reaction to an incoming hit of the target. Called straight from the `Casted`
--- handler: `Casted` flies before `CombatService:Attack` computes the states of the
--- victim, so the guard decision belongs here and not on the next tick.
function Bot.OnIncoming(self: Bot, data: types.HitboxData)
	local target = self.Target
	if not target then return end

	if not self.Threat:Track(data, target) then return end

	-- A charge in progress must never survive the start of an enemy attack.
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

	-- `Skill:Activate` yields, so the press is spawned: the guard state
	-- (`PerfectBlockTime`) has to settle before the states of the victim are
	-- computed.
	task.spawn(function()
		const _, spec = FindSkill(self, skillId)
		if spec then spec:ActivateSkill(skillId) end
	end)
end

function Bot.Tick(self: Bot, dt: number)
	self.Accumulator += dt
	if self.Accumulator < TICK_INTERVAL then return end

	self.Accumulator = 0

	if not self.Target then
		self:SetPosture("Idle")
		return
	end

	self.Sense:Refresh()

	local mask = self.Sense.Mask
	if self.Threat:IsRecent() then mask = bor(mask, Conditions.Bit("OWN_THREATENED")) end

	self:UpdateHeld(mask)

	const guardId = self.Roles.Guard

	if
		guardId
		and self:IsGuardHeld()
		and Defense.ShouldReleaseGuard(self.Config, guardId, mask)
	then
		self:ReleaseGuard()
	end

	-- The slot goes to the defense for what a block can take, and for a hit that has
	-- already landed. "Does it have an active skill" must not be used for this: a
	-- target holding a block stays active indefinitely, and the bot would back off
	-- from it for the whole fight; a windup of an unblockable hit is a window for a
	-- counter attack, and retreating there only gets in the way (see
	-- `Defense.ShouldDefend`).
	if Defense.ShouldDefend(mask, self.Threat:IsRecent()) then
		self:SetPosture("Defend")
		return
	end

	self:SetPosture("Attack")
	Attack.Step(self, mask, self.Sense.Distance)
end

function Bot.SetTarget(self: Bot, character: types.Character?)
	if not character then
		self:ClearTarget()
		return
	end

	if self.Target == character then return end
	if not (character.Spec or character.SubSpec) then return end

	self.TargetCleaner:Clean()

	self.Target = character
	self.Navigator:SetTarget(character.RootPart)
	self.Sense:SetTarget(character)
	self.Threat:Clear()

	self.TargetCleaner:Add(character.Destroying:Once(function()
		self:ClearTarget()
	end))

	self.TargetCleaner:Add(self.CombatService.Casted:Connect(function(data: types.HitboxData)
		if data.Caster ~= self.Target then return end

		self:OnIncoming(data)
	end))

	-- A freshly acquired target is approached defensively: the same posture the old
	-- state machine entered with `ChangeState("Defending")`.
	self:SetPosture("Defend")
end

function Bot.ClearTarget(self: Bot)
	self.TargetCleaner:Clean()

	self:ReleaseGuard()
	self:ReleaseHeld()

	self.Target = nil
	self.Sense:ClearTarget()
	self.Threat:Clear()

	self:SetPosture("Idle")
	self.Navigator:ClearTarget()
end

function Bot.Destroy(self: Bot)
	self.TargetCleaner:Clean()
	self.Cleaner:Clean()

	self.Character.Navigator = nil
end

return {
	new = function(character: types.Character, config: BotsCharacters.BotCharacterConfig)
		-- The primary spec owns movement/animations; the optional SubSpec owns
		-- the combat skills (SetSpec routes by the spec's configured type).
		character:SetSpec(config.Spec, resolveSkin(config.Spec, config.SpecSkin))
		if config.SubSpec then
			character:SetSpec(config.SubSpec, resolveSkin(config.SubSpec, config.SubSpecSkin))
		end

		const primarySpec = character.Spec
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

		local bot = setmetatable({
			Navigator = navigator,
			Config = config,
			Cleaner = cleaner,
			TargetCleaner = cleaner:Scope(),
			Target = nil,
			Character = character,

			CombatService = Crane:GetService("CombatService"),

			Posture = "Idle",
			Roles = Defense.ResolveRoles(
				CollectRoles({ character.SubSpec, character.Spec }),
				config.Skills
			),
			Sense = Sense.new(character),
			Threat = Threat.new(character),

			Combo = Attack.RollCombo(config, random),
			ComboIndex = 1,

			HeldSkill = nil,
			HeldAt = 0,

			Random = random,
			Accumulator = 0,
		}, Bot)

		if primarySpec then primarySpec:ActivateSkill("Run") end

		cleaner:Add(character.OnTakeDamage:Connect(function(attacker)
			if not attacker then return end

			bot:SetTarget(attacker)
		end))

		cleaner:Add(RunService.Heartbeat:Connect(function(dt)
			bot:Tick(dt)
		end))

		return bot
	end,
}
