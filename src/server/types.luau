local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])
local PlayerComponent = require(ServerScriptService.server.components.Player)
local PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
local PlayerSaveData = require(ReplicatedStorage.shared.schemas.PlayerSaveData)
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)
local Signal = require(ReplicatedStorage.shared.packages.Signal)

export type PlayerModule = {
	Name: string,
	player: typeof(PlayerComponent),
	playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	onInit: (self: PlayerModule) -> (),
	onStart: (self: PlayerModule) -> (),
}

export type Bind = Enum.KeyCode | Enum.UserInputType

local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(game:GetService("ReplicatedStorage").shared.packages.Crane)
local Parameters = require(ServerScriptService.server.components.Character.Parameters)

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
