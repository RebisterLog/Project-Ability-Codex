--!native
--!optimize 2

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const ServerScriptService = game:GetService("ServerScriptService")
const BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])
const types = require(ServerScriptService.server.types)

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const NavigationController = require(script.Parent.NavigationController)

const Attack = require(script.Parent.Attack)
const Defense = require(script.Parent.Defense)
const Posture = require(script.Parent.Posture)
const Sense = require(script.Parent.Sense)
const Threat = require(script.Parent.Threat)

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
const TICK_INTERVAL = 1 / 30

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

	Destroy: (self: Bot) -> (),
}

export type Bot = BotProperities & BotMethods

const Bot = {}
Bot.__index = Bot

--- Defense roles come from the tags of the skills of the spec and not from the
--- config: the skill itself decides what it is, the guard or the retreat.
const CollectRoles = function(spec: types.Spec): { Defense.RoleSkill }
	const roles: { Defense.RoleSkill } = {}

	for id, skill in spec.Skills do
		table.insert(roles, { Id = id, Tags = skill.Data.SkillCharacters })
	end

	return roles
end

function Bot.IsGuardHeld(self: Bot): boolean
	const guardId = self.Roles.Guard
	if not guardId then return false end

	const guard = self.Character.Spec.Skills[guardId]

	return guard ~= nil and guard.Active
end

--- No guard counts as "unavailable": the defense then falls back to the escape.
function Bot.IsGuardOnCooldown(self: Bot): boolean
	const guardId = self.Roles.Guard
	if not guardId then return true end

	const guard = self.Character.Spec.Skills[guardId]
	if not guard then return true end

	return guard:IsOnCooldown()
end

function Bot.ReleaseGuard(self: Bot)
	const guardId = self.Roles.Guard
	if not guardId then return end

	self.Character.Spec:DeactivateSkill(guardId)
end

function Bot.SetPosture(self: Bot, posture: Posture.Posture)
	if self.Posture == posture then return end

	const previous = self.Posture
	self.Posture = posture

	const style = Posture.Get(posture)
	const movementStyle = if posture == "Attack"
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
	const target = self.Target
	if not target then return end

	if not self.Threat:Track(data, target) then return end

	self:SetPosture("Defend")

	const decision = Defense.React(data, {
		GuardId = self.Roles.Guard,
		EscapeId = self.Roles.Escape,
		GuardHeld = self:IsGuardHeld(),
		GuardOnCooldown = self:IsGuardOnCooldown(),
	})

	const skillId = if decision == "Press"
		then self.Roles.Guard
		else if decision == "Escape" then self.Roles.Escape else nil

	if not skillId then return end

	-- `Skill:Activate` yields, so the press is spawned: the guard state
	-- (`PerfectBlockTime`) has to settle before the states of the victim are
	-- computed.
	task.spawn(function()
		self.Character.Spec:ActivateSkill(skillId)
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

	const mask = self.Sense.Mask
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
	Attack.Step(self, mask, self.Sense.Distance, guardId)
end

function Bot.SetTarget(self: Bot, character: types.Character?)
	if not character then
		self:ClearTarget()
		return
	end

	if self.Target == character then return end
	if not character.Spec then return end

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

	self.Target = nil
	self.Sense:ClearTarget()
	self.Threat:Clear()

	self:SetPosture("Idle")
	self.Navigator:ClearTarget()
end

function Bot.Destroy(self: Bot)
	self.TargetCleaner:Clean()
	self.Cleaner:Clean()
end

return {
	new = function(character: types.Character, config: BotsCharacters.BotCharacterConfig)
		character:SetSpec(config.Spec)

		const spec = character.Spec
		const random = Random.new()

		const navigator = NavigationController.new(character.instance, {
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

		const cleaner = character.Cleaner:Scope()
		cleaner:Set("Navigator", navigator)

		const bot = setmetatable({
			Navigator = navigator,
			Config = config,
			Cleaner = cleaner,
			TargetCleaner = cleaner:Scope(),
			Target = nil,
			Character = character,

			CombatService = Crane:GetService("CombatService"),

			Posture = "Idle",
			Roles = Defense.ResolveRoles(CollectRoles(spec)),
			Sense = Sense.new(character),
			Threat = Threat.new(character),

			Combo = Attack.RollCombo(config, random),
			ComboIndex = 1,

			Random = random,
			Accumulator = 0,
		}, Bot)

		spec:ActivateSkill("Run")

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
