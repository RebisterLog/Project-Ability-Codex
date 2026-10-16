const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])
const PlayerComponent = require(ServerScriptService.server.components.Player)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const PlayerSaveData = require(ReplicatedStorage.shared.schemas.PlayerSaveData)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const Signal = require(ReplicatedStorage.shared.packages.Signal)

export type PlayerModule = {
	Name: string,
	player: typeof(PlayerComponent),
	playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	onInit: (self: PlayerModule) -> (),
	onStart: (self: PlayerModule) -> (),
}

export type Bind = Enum.KeyCode | Enum.UserInputType

const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(game:GetService("ReplicatedStorage").shared.packages.Crane)
const Parameters = require(ServerScriptService.server.components.Character.Parameters)

export type CleanUp = () -> ()

export type Parameters = typeof(Parameters)
export type ParameterName = keyof<Parameters>
export type ParameterValue<K = ParameterName> = index<index<Parameters, K>, "Default">

export type ParameterObject<T> = {
	Value: ParameterValue<T>,
	Cleaner: typeof(Crane.Janitor.new()),
	Destroy: (self: ParameterValue<T>) -> (),
}

type GrabCharacter = {
	Bind: {
		Part0: BasePart,
		Part1: BasePart,
		Offset: CFrame?,
		Offset1: CFrame?,
	}?,
	Restrain: boolean?,
}

export type GrabData = {
	Attacker: GrabCharacter?,
	Victim: GrabCharacter?,
}

export type HitboxData = {
	Caster: Character,
	Skill: Skill?,
	Info: {
		Size: Vector3 | number,
		Offset: CFrame?,
		Origin: CFrame?,
		SortByDistance: boolean?,
		CanQueryCaster: boolean?,
		Parameters: OverlapParams?,
		MovementCorrection: boolean?,
		Debug: boolean?,
	},
}

export type AttackInfo = {
	Priority: number?,
	Damage: number?,
	Stun: {
		Duration: number,
		Priority: number,
	}?,

	Block: {
		BlockCancel: boolean,
		PerfectBlockable: boolean,
		Blockable: boolean,
		BlockBreak: boolean,
		BlockIgnore: boolean,
	}?,

	Knockback: {
		RelativePart: "Attacker" | "Target",
		RelativeTowards: "Attacker" | "Target",
		Origin: CFrame,
		ToFront: boolean,
		Speed: number,
		Duration: number,
		Velocity: Vector3,
		MaxForce: Vector3,

		FindCrashObject: boolean,
	}?,

	Angular: {
		Velocity: Vector3,
		Speed: number?,
		Duration: number?,
		MaxTorque: number?,
	}?,

	Ragdoll: {
		Duration: number,
	}?,
}

export type AttackData = {
	Attacker: Character,
	Victim: Character,
	Info: AttackInfo,

	State: {
		Success: boolean,
		Continue: boolean,
		Blocking: boolean,
		Blocked: boolean,
		BlockBroken: boolean,
		PerfectBlocking: boolean,
		PerfectBlocked: boolean,
		BlockIgnored: boolean,
		BlockCanceled: boolean,
		IFrames: number,
		Armored: boolean,
	},
}

-- [Success]
-- true: хит зарегистрирован (не важно: урон, блок или парирование)
-- false: промах, iframe, dead и т.д.

-- [Continue]
-- true: разрешено продолжение (следующий хит, follow-up, chain)
-- false: атака обрывается
--[[
	:andThen(function(AttackData)
		if AttackData.State.Continue then
			-- Play Next Sequence or whatever
		end
	end)
--]]

-- [Blocking]
-- true: враг активно блокирует
-- false: блок не зажат
-- Это состояние врага, а не результат удара

-- [Blocked]
-- true: удар пришёлся в блок
-- false: блок не сработал
-- !!! Отличие от Blocking:
-- Blocking — что цель делала
-- Blocked — что произошло с атакой

-- [Block Broken]
-- true: атака сломала блок врага, атака был заблокирована, но блок при этом сломался
-- false: блок не был сломан

-- [Perfect Blocking]
-- true: блок был сделан в перфект тайминг
-- false: обычный блок или его отсутствие
-- Это состояние цели, а не результат удара

-- [Perfect Blocked]
-- true: атакующий получил наказание
-- false: обычный блок / хит

-- Обычный хит:
--[[
	{
	    Success = true,
	    Continue = true,
	    Blocking = false,
	    Blocked = false,
	    BlockBroken = false,
	    BlockCanceled = false,
	    PerfectBlocking = false,
	    PerfectBlocked = false,
	}
]]
-- Обычный Блок:
--[[
	{
	    Success = true,
	    Continue = true,
	    Blocking = true,
	    Blocked = true,
	    BlockBroken = false,
	    BlockCanceled = false,
	    PerfectBlocking = false,
	    PerfectBlocked = false,
	}
]]
-- Блок Брейк:
--[[
	{
	    Success = true,
	    Continue = true,
	    Blocking = true,
	    Blocked = true,
	    BlockBroken = true,
	    BlockCanceled = false,
	    PerfectBlocking = false,
	    PerfectBlocked = false,
	}
]]
-- Перфект Блок:
--[[
	{
	    Success = true,
	    Continue = false,
	    Blocking = true,
	    Blocked = true,
	    BlockBroken = false,
	    BlockCanceled = false,
	    PerfectBlocking = true,
	    PerfectBlocked = true,
	}
]]
-- Отмена Блока (BlockCanceled):
--[[
	{
	    Success = true,
	    Continue = true,
	    Blocking = true,
	    Blocked = false,
	    BlockBroken = false,
	    BlockCanceled = true,
	    PerfectBlocking = false,
	    PerfectBlocked = false,
	}
]]

-- PROJECTILE

--[=[
	Per-step context handed to a projectile `MoveFunction`.

	Read-only snapshot of the projectile state for the current frame. Return a new
	`Velocity` from the callback to override motion, or `nil` to keep the velocity
	the projectile already has (gravity still applies).
]=]
export type ProjectileMoveContext = {
	Velocity: Vector3,
	Direction: Vector3,
	Position: Vector3,
	DeltaTime: number,
	Elapsed: number,
	Traveled: number,
}

--[=[
	Custom motion function. Runs once per Heartbeat, before the projectile
	commits its new position.

	```lua
	-- homing
	MoveFunction = function(self, context)
		const target = findNearestCharacter(context.Position, 100)
		if not target then return nil end

		const desired = (target.RootPart.Position - context.Position).Unit
			* context.Velocity.Magnitude

		return context.Velocity:Lerp(desired, math.clamp(context.DeltaTime * 4, 0, 1))
	end
	```
]=]
export type ProjectileMoveFunction = (
	self: Projectile,
	context: ProjectileMoveContext
) -> Vector3?

--[=[
	Surface reflection (bouncing). Disabled by default — a plain projectile flies
	straight until it hits something, then ends with reason `"Wall"`.
]=]
export type ProjectileReflection = {
	Enabled: boolean,
	-- Fraction of speed kept per bounce, 0..1. `1` is a perfectly elastic bounce.
	Restitution: number?,
	-- Bounces allowed before the projectile ends. `-1` for infinite.
	MaxBounces: number?,
	-- Skip characters entirely, so only terrain/map bounces.
	IgnoreCharacters: boolean?,
	-- How far to nudge off the surface normal, prevents re-hitting the same surface.
	SurfaceOffset: number?,
}

export type ProjectileConfig = {
	-- Character the projectile is attributed to; also drives the hitbox query.
	Caster: Character,
	-- Optional skill, forwarded to `CombatService:Hitbox` for cast tracking.
	Skill: Skill?,

	-- Template instance, cloned by the class. Never mutated.
	Model: Model | BasePart,
	Position: Vector3,
	Direction: Vector3,
	Speed: number,
	-- Constant acceleration, default `Vector3.zero`.
	Gravity: Vector3?,

	-- Box size, or sphere radius when a number is given.
	HitboxSize: Vector3 | number,
	HitboxOffset: CFrame?,
	-- When true the projectile keeps flying after a hit and never damages the
	-- same target twice. When false it ends on the first hit.
	CanPierce: boolean,

	-- Seconds before the projectile ends on its own, default 5.
	Lifetime: number?,
	-- Studs travelled before the projectile ends on its own.
	MaxDistance: number?,

	Reflection: ProjectileReflection?,
	MoveFunction: ProjectileMoveFunction?,

	-- Skip the caster's own character in hit queries, default true.
	IgnoreCaster: boolean?,
	Debug: boolean?,
}

type ProjectileProperities = {
	Config: ProjectileConfig,
	-- The cloned visual instance. Parented to `workspace.Effects`.
	Instance: Model | BasePart,

	Position: Vector3,
	Velocity: Vector3,
	Direction: Vector3,
	Speed: number,

	Elapsed: number,
	Traveled: number,
	HitCount: number,
	-- Targets already hit, so a piercing projectile never hits one twice.
	AlreadyHit: { [Character]: true },

	-- Normalised reflection config, resolved once in `new`.
	Reflection: ProjectileReflection,
	Bounces: number,

	Running: boolean,
	Finished: boolean,
	Connection: RBXScriptConnection?,
	RayParams: RaycastParams,
	-- Resolved lazily on the first step, since services may not be started yet.
	CombatService: any?,

	Cleaner: typeof(Crane.Buttler.new()),

	Hit: Signal.Signal<Character, Vector3>,
	-- Second argument is the post-bounce direction. The result is `nil` when the
	-- bounce came from a manual `Reflect` rather than the swept surface test.
	Reflect: Signal.Signal<RaycastResult?, Vector3>,
	-- Reasons: "Lifetime", "Distance", "Hit", "Bounce", "Wall", "Stopped",
	-- "Destroyed"
	End: Signal.Signal<string>,
	Stepped: Signal.Signal<number>,
}

type ProjectileMethods = {
	Start: (self: Projectile) -> (),
	Stop: (self: Projectile, reason: string?) -> (),
	Destroy: (self: Projectile) -> (),
	Step: (self: Projectile, deltaTime: number) -> (),

	SetVelocity: (self: Projectile, velocity: Vector3) -> (),
	SetDirection: (self: Projectile, direction: Vector3, speed: number?) -> (),
	-- Manually bounce off a surface normal, bypassing the sweep.
	Reflect: (self: Projectile, normal: Vector3) -> (),
	-- Force a hit on a target, respecting the unique-target set. Returns `false`
	-- when the target had already been hit.
	HitTarget: (self: Projectile, target: Character, position: Vector3) -> boolean,
}

export type Projectile = ProjectileProperities & ProjectileMethods

-- QUEST

type QuestProperities = {
	Name: string,
	Data: { any },
	Player: PlayerComponent,
	Cleaner: typeof(Crane.Buttler.new()),
}

type QuestMethods = {
	Init: (self: Quest, player: PlayerComponent) -> (),
	Start: (self: Quest) -> (),
	Complete: (self: Quest) -> (),

	AddProgress: (self: Quest, amount: any) -> (),
	RemoveProgress: (self: Quest, amount: any) -> ()?,

	CheckComplete: (self: Quest) -> boolean,
}

export type Quest = QuestProperities & QuestMethods

-- STAND

type StandProperities = {
	Active: boolean,
	Visible: boolean,
	Owner: Character,
	RootPart: BasePart,
	Cleaner: typeof(Crane.Buttler.new()),
}

type StandMethods = {
	Init: (self: Stand, owner: Character) -> (),

	IsActive: (self: Stand) -> boolean,
	IsVisible: (self: Stand) -> boolean,

	SetActive: (self: Stand, state: boolean) -> (),
	SetVisible: (self: Stand, state: boolean) -> (),

	WeldToOwner: (self: Stand) -> (),
	WeldTo: (self: Stand, part: BasePart) -> (),
}

export type Stand = Crane.Component<Model> & StandProperities & StandMethods

--SKILL

export type SkillData = {
	Id: string,
	Tag: string?,

	Cooldown: number,
	DisplayName: string,
	AttackInfo: AttackInfo,
	SkillCharacters: { BotsCharacters.SkillCharacter },
	onInit: (self: Skill) -> (),
	onDestroy: (self: Skill) -> (),
	Activate: (self: Skill) -> (),
	Interrupt: (self: Skill) -> (),
}

type SkillProperties = {
	Initialized: boolean,
	Active: boolean,
	Enabled: boolean,
	Holding: boolean,
	Data: SkillData,
	Spec: Spec,
	Character: Character,
	Cleaner: typeof(Crane.Buttler.new()),
	Proxy: Proxy.ProxyTab<SkillReplicationData>,
	Deactivated: Signal.Signal<Skill>,
}

type SkillMethods = {
	Activate: (self: Skill) -> (),
	Interrupt: (self: Skill) -> (),
	Deactivate: (self: Skill) -> (),
	SetCooldown: (self: Skill, Time: number) -> (),
	SetDisplayName: (self: Skill, name: string) -> (),
	SetEnabled: (self: Skill, enabled: boolean) -> (),
	SetBind: (self: Skill, bind: Bind) -> (),
	IsOnCooldown: (self: Skill) -> boolean,
	Validate: (self: Skill) -> (boolean, string?),
	Init: (self: Skill) -> (),
	Destroy: (self: Skill) -> (),
}

export type Skill = SkillProperties & SkillMethods

export type SkillReplicationData = {
	Parameters: {
		Bind: Bind,
		Enabled: boolean,
		ReleaseTime: number,
	},
}

--SPEC

export type SpecSaveData = PlayerSaveData.SpecData

export type SpecDef = {
	Id: string,
	Name: string,
	Skin: string,
	Binds: { [string]: Bind },
}

export type SpecData = {
	DisplayName: string,
	IsPublic: boolean,

	Binds: { [string]: Enum.KeyCode & Enum.UserInputType },

	Assets: {
		Animations: {
			[string]: {
				Animation: Animation,
				Priority: Enum.AnimationPriority,
			},
		},

		Sounds: {
			[string]: {
				Sound: Sound,
				Volume: number?,
				PlaybackSpeed: number?,
			},
		},

		Models: {
			[string]: Model | BasePart,
		},
	},

	Skills: {
		[string]: Skill,
	},

	onInit: (self: Skill) -> (),
}

type SpecProperities = {
	Data: SpecData,
	Initialized: boolean,
	Skills: { [string]: Skill },
	Cleaner: typeof(Crane.Buttler.new()),
	Character: Character,
	Proxy: Proxy.ProxyTab<{
		Skills: {
			[string]: SkillReplicationData,
		},
	}>,

	OnActivateSkill: Signal.Signal<Skill>,
	OnInterruptSkill: Signal.Signal<Skill>,
	OnDeactivateSkill: Signal.Signal<Skill>,
}

type SpecMethods = {
	Init: (self: Spec) -> (),
	AddSkill: (self: Spec, skill: Skill) -> (),
	GetAvailableSkills: (self: Spec) -> { Skill },
	ActivateSkill: (self: Spec, skillId: string) -> (),
	DeactivateSkill: (self: Spec, skillId: string) -> (),
	InterruptSkill: (self: Spec, skillId: string) -> (),
	Destroy: (self: Spec) -> (),
	CheckActiveSkills: (self: Spec) -> boolean,
	SetEnableSkills: (self: Spec, tag: string, state: boolean) -> (),
}

export type Spec = SpecProperities & SpecMethods

-- PLAYER

type PlayerProperties = {
	Character: Character?,

	Proxy: Proxy.ProxyTab<PlayerData>,
	Modules: { [string]: PlayerModule },

	Janitor: typeof(Crane.Janitor.new()),
}

type PlayerMethods = {
	GetModule: (self: Player, name: string) -> PlayerModule,
	LoadDocumentData: (self: Player, data: PlayerSaveData.PlayerSaveData) -> (),
}

export type PlayerComponent = Crane.Component<Player> & PlayerProperties & PlayerMethods

--CHARACTER

type CharacterProperities = {
	Player: Player?, -- only if character owned by player
	Spec: Spec?,
	OnTakeDamage: Signal.Signal<(Character, AttackData)>,
	Humanoid: Humanoid,
	RootPart: BasePart,
	Parameters: {
		[ParameterName]: {
			Watchers: { (value: any) -> () },
			Objects: { ParameterObject<any> },
		},
	},

	Block: {
		Blocking: boolean,
		PerfectBlockTime: number,
		PerfectBlockWindow: number,
		AlwaysPerfect: boolean,
	},

	Motors: { Motor6D },
	RagdollConstraints: { BallSocketConstraint },
	RagdollColliders: { BasePart },

	Cleaner: typeof(Crane.Buttler.new()),
}

type CharacterMethods = {
	SetSpec: <T>(self: Character, name: string, skin: string?) -> (),

	AddParameter: <T>(
		self: Character,
		param: ParameterName,
		value: ParameterValue<T>
	) -> ParameterObject<ParameterName>,
	GetParameter: <T>(self: Character, param: ParameterName) -> ParameterValue<T>,
	WatchParameter: <T>(
		self: Character,
		param: ParameterName,
		callback: (value: ParameterValue<T>) -> ()
	) -> CleanUp,

	Ragdoll: <T>(self: Character, state: boolean) -> (),

	SetCollisionToPlayers: <T>(self: Character, collide: boolean) -> (),

	Destroy: (self: Character) -> (),
}

export type Character = Crane.Component<Model> & CharacterMethods & CharacterProperities

return nil
