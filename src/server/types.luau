const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])
const PlayerComponent = require(ServerScriptService.server.components.Player)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const PlayerSaveData = require(ReplicatedStorage.shared.schemas.PlayerSaveData)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const Signal = require(ReplicatedStorage.shared.packages.Signal)
const Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)

export type PlayerModule = {
	Name: string,
	player: typeof(PlayerComponent),
	playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	onInit: (self: PlayerModule) -> (),
	onStart: (self: PlayerModule) -> (),
}

export type Bind = Enum.KeyCode | Enum.UserInputType

export type SpecSlot = "Spec" | "SubSpec"

export type SpecInitOptions = {
	Movement: boolean?,
}

const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(game:GetService("ReplicatedStorage").shared.packages.Crane)
const Parameters = require(ServerScriptService.server.components.Character.Parameters)

export type CleanUp = () -> ()

-- Shape of the per-effect argument table passed to StartEffect/StopEffect.
-- Every effect module declares the protocol it expects inside its own file.
export type EffectData = { [string]: any }

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
		LookVector: Vector3,
		Speed: number,
		Duration: number,
		Velocity: Vector3,
		MaxForce: Vector3,
		P: number,

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

	Bleed: {
		Damage: number,
		Duration: number,
		Interval: number?,
		Slow: number?,
	}?,

	Burn: {
		Damage: number,
		Duration: number,
		Interval: number?,
		Slow: number?,
	}?,

	-- Hit feedback on a landed hit; nil falls back to assets.Default.Hits.
	HitEffects: Folder?,
	HitSounds: Folder?,
	HitAnimations: Folder?,
}

export type AttackData = {
	Attacker: Character,
	Victim: Character,
	Info: AttackInfo,
	-- Frozen snapshot of the attack as it was first submitted; set by
	-- CombatService:Attack and used when a held attack is replayed.
	OriginalInfo: AttackInfo?,
	-- Health actually removed by the Damage hook, after multipliers and holds.
	DamageDealt: number?,
	-- Set when the attack was queued behind DamageHold and is being replayed.
	NoDeathDeferred: boolean?,

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

	-- Template instance, cloned by the class. Never mutated. When omitted the
	-- projectile is tracked without a replicated body (server-side hidden math),
	-- and the visual effects are left to the client.
	Model: Model | BasePart?,
	Position: Vector3,
	Direction: Vector3,
	Speed: number,
	-- Fixed visual rotation used when `OrientToVelocity` is false.
	Orientation: CFrame?,
	OrientToVelocity: boolean?,
	-- Constant acceleration, default `Vector3.zero`.
	Gravity: Vector3?,

	-- Box size, or sphere radius when a number is given.
	HitboxSize: Vector3 | number,
	HitboxOffset: CFrame?,
	-- When true the projectile keeps flying after a hit and never damages the
	-- same target twice. When false it ends on the first hit.
	CanPierce: boolean,
	-- When false the projectile flies and bounces but never queries a hitbox
	-- (pure visual / virtual flight). Defaults to true.
	HitboxEnabled: boolean?,

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
	-- The cloned visual instance. Parented to `workspace.Effects`. Nil when
	-- `Model` was omitted: server-side virtual projectiles have no body.
	Instance: Model | BasePart | nil,

	Position: Vector3,
	Velocity: Vector3,
	Direction: Vector3,
	Speed: number,
	HitboxEnabled: boolean,
	OrientToVelocity: boolean,
	FixedRotation: CFrame,

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
	RayParams: RaycastParams?,
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
	VisibilityRevision: number,
	VisibilitySuppressions: { [string]: boolean },
	VisibleDelay: thread?,
}

type StandMethods = {
	Init: (self: Stand, owner: Character) -> (),

	IsActive: (self: Stand) -> boolean,
	IsVisible: (self: Stand) -> boolean,

	SetActive: (self: Stand, state: boolean) -> (),
	SetVisible: (self: Stand, state: boolean) -> (),
	RefreshVisibility: (self: Stand) -> (),
	SetVisibilitySuppressed: (self: Stand, reason: string, state: boolean) -> (),

	WeldToOwner: (self: Stand) -> (),
	WeldTo: (self: Stand, part: BasePart) -> (),
	WeldToPoint: (self: Stand, cframe: CFrame) -> (),
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
	-- Combo buffer handler: swallows another skill's input while this skill
	-- is active. Returns true when the input was consumed.
	TryComboInput: ((self: Skill, skillId: string) -> boolean)?,
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
	-- The queue of the cast that is running right now, when the skill drives
	-- itself with a Sequencer. Nil while the skill is idle, and for skills that
	-- have no sequence at all.
	Sequence: Sequencer.Sequencer?,
}

type SkillMethods = {
	Activate: (self: Skill) -> (),
	Interrupt: (self: Skill) -> (),
	Deactivate: (self: Skill) -> (),
	-- Suspends / continues the running sequence, keeping its progress.
	Pause: (self: Skill) -> (),
	Resume: (self: Skill) -> (),
	SetCooldown: (self: Skill, Time: number) -> (),
	SetDisplayName: (self: Skill, name: string) -> (),
	SetEnabled: (self: Skill, enabled: boolean) -> (),
	SetBind: (self: Skill, bind: Bind) -> (),
	IsOnCooldown: (self: Skill) -> boolean,
	Validate: (self: Skill) -> (boolean, string?),
	TryComboInput: (self: Skill, skillId: string) -> boolean,
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
	Skin: string?,
	Binds: { [string]: Bind }?,
	InstanceId: string?,
}

export type SpecData = {
	Id: string,
	Slot: SpecSlot,
	InstanceId: string?,
	DisplayName: string,
	IsPublic: boolean,

	-- Wearers see through Time Stop: they are not shown the private stasis
	-- illusion and keep acting while everyone else is frozen. A single flag in
	-- either the spec or the subspec slot is enough.
	TimeStopVision: boolean?,

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

		-- Stand presentation (Summon/Unsummon animations, sounds, particles and
		-- the owner-body aura template). Optional: a spec without a stand simply
		-- has no entry here.
		Stand: {
			Animations: {
				[string]: {
					Animation: Animation,
					Priority: Enum.AnimationPriority,
				},
			},
			Sounds: { [string]: { Sound: Sound, Volume: number?, PlaybackSpeed: number? } },
			Models: { [string]: Model | BasePart },
			Aura: Folder?,
		}?,
	},

	Skills: {
		[string]: string,
	},

	onInit: (self: Spec) -> (),
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
	Init: (self: Spec, options: SpecInitOptions?) -> (),
	AddSkill: (self: Spec, skill: Skill) -> (),
	RemoveSkill: (self: Spec, skillId: string) -> (),
	GetAvailableSkills: (self: Spec) -> { Skill },
	ActivateSkill: (self: Spec, skillId: string) -> (),
	DeactivateSkill: (self: Spec, skillId: string) -> (),
	InterruptSkill: (self: Spec, skillId: string) -> (),
	Destroy: (self: Spec) -> (),
	CheckActiveSkills: (self: Spec) -> (boolean, { Skill }),
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

-- One entry in the DamageHold queue: a whole attack to replay, or a raw
-- damage/heal amount applied in order when the hold is released.
export type HealData = {
	Healer: Character?,
	Target: Character,
	Amount: number,
	State: { Success: boolean }?,
}

export type NoDeathEntry =
	{
		Kind: "Attack",
		Attack: AttackData,
	}
	| {
		Kind: "Damage" | "Heal",
		Amount: number,
	}

type CharacterProperities = {
	Player: Player?, -- only if character owned by player
	NPCNetworkOwner: Player?,
	Navigator: {
		DisableRotation: (self: any) -> (),
		EnableRotation: (self: any) -> (),
	}?,
	Spec: Spec?,
	SubSpec: Spec?,
	OnTakeDamage: Signal.Signal<(Character, AttackData)>,
	Humanoid: Humanoid,
	RootPart: BasePart,
	TornDown: boolean,
	Parameters: {
		[ParameterName]: {
			Watchers: { (value: any) -> () },
			Objects: { ParameterObject<any> },

			-- NoDeath / DamageHold runtime state, kept on the parameter entry
			-- itself so the watchers and hooks share one source of truth.
			Queue: { NoDeathEntry }?,
			Draining: boolean?,
			Generation: number?,
			Debt: number?,
			DebtFrom: AttackData?,
		},
	},

	Block: {
		Blocking: boolean,
		PerfectBlockTime: number,
		PerfectBlockWindow: number,
		AlwaysPerfect: boolean,
		Changed: Signal.Signal<boolean>,
	},

	Motors: { Motor6D },
	RagdollConstraints: { BallSocketConstraint },
	RagdollColliders: { BasePart },

	Cleaner: typeof(Crane.Buttler.new()),
}

type CharacterMethods = {
	ClaimNPCNetworkOwner: (self: Character, player: Player?) -> (),
	SetSpec: (
		self: Character,
		name: string,
		skin: string?,
		binds: { [string]: Bind }?,
		instanceId: string?
	) -> Spec?,
	ClearSpec: (self: Character) -> (),
	ClearSubSpec: (self: Character) -> (),
	GetSpec: (self: Character) -> Spec?,
	GetSubSpec: (self: Character) -> Spec?,
	CheckActiveSkills: (self: Character) -> (boolean, { Skill }),
	SetEnableSkills: (self: Character, tag: string, state: boolean) -> (),

	AddParameter: <T>(
		self: Character,
		param: ParameterName,
		value: ParameterValue<T>
	) -> ParameterObject<ParameterName>,
	GetParameter: <T>(self: Character, param: ParameterName) -> ParameterValue<T>,
	SetParameterValue: <T>(
		self: Character,
		param: ParameterName,
		value: ParameterValue<T>
	) -> ParameterValue<T>,
	RefreshParameter: <T>(self: Character, param: ParameterName) -> ParameterValue<T>,
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
