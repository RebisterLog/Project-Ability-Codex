--[=[ PLUCK_AND_LUCK

   Sword combo: a block-breaking opener at frame 40, chops in between, and a
   ragdolling finisher at frame 60. Spending 50 Hamon on cast adds a 5-second
   Burn (1 damage per second) to every landed hit.

   ASSETS:

   Animations
      LuckAndPluck : Combo animation (assets/JonathanHamon).

   Sounds
      LuckAndPluck : Combo sound (assets/JonathanHamon).

   Models
      Sword : Equipped through CombatService:Equip for the skill duration.

]=]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const types = require(ServerScriptService.server.types)

const BURN_COST = 50
const BurnInfo = {
	Damage = 0.2,
	Duration = 5,
	Interval = 0.5,
}

const Skill: types.SkillData = {
	DisplayName = "Pluck&Luck",
	Cooldown = 15,
	BaseSpec = "JonathanHamon",
	SkillCharacters = {
		"Hit",
		"Blockable",
		"BlockBreak",
		"Ragdoll",
		"Debuff",
	},

	FirstHitInfo = {
		Hitbox = {
			Size = Vector3.new(7, 7, 9),
			Offset = CFrame.new(0, 0, -4),
			Debug = true,
		},

		Damage = 4,

		Block = {
			Blockable = true,
			PerfectBlockable = false,
			BlockBreak = true,
		},

		Stun = {
			Duration = Enums.StunTime.Heavy,
			Priority = Enums.Stun.Heavy,
		},
	},

	ChopInfo = {
		Hitbox = {
			Size = Vector3.new(7, 7, 9),
			Offset = CFrame.new(0, 0, -4),
			Debug = true,
		},

		Damage = 4,

		Block = {
			Blockable = true,
			PerfectBlockable = false,
			BlockBreak = false,
		},

		Stun = {
			Duration = Enums.StunTime.Heavy,
			Priority = Enums.Stun.Heavy,
		},
	},

	LastHitInfo = {
		Hitbox = {
			Size = Vector3.new(7, 7, 9),
			Offset = CFrame.new(0, 0, -4),
			Debug = true,
		},

		Damage = 4,

		Ragdoll = {
			Duration = Enums.Ragdoll.Heavy,
		},

		Block = {
			Blockable = true,
			PerfectBlockable = false,
			BlockBreak = false,
		},
	},
}

function Skill.onInit(self)
	const character = self.Character
	const RootPart = character.RootPart
	const VFXService = Crane:GetService("VFXService")
	const CombatService = Crane:GetService("CombatService")

	const FirstInfo = self.Data.FirstHitInfo
	const ChopInfo = self.Data.ChopInfo
	const LastInfo = self.Data.LastHitInfo

	self.AlreadyHit = {}
	self.Burn = nil

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					table.clear(self.AlreadyHit)

					const Sword = CombatService:Equip(character, self:GetAsset("Models/Sword"))
					seq.Cleaner:Add(Sword)

					const anim = self:GetAsset("Animations/LuckAndPluck")
					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = character.instance,
						Animation = anim,
						Speed = seq.Speed,
					})

					seq.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "Animation", {
							Character = character.instance,
							Animation = anim.Animation,
						})
					end)

					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = RootPart,
						Sound = self:GetAsset("Sounds/LuckAndPluck"),
					})
				end,
			},

			{
				40,
				function(_, currentFrame)
					print(currentFrame, currentFrame % 6 == 4)
					local attackInfo = ChopInfo

					if currentFrame == 40 then
						attackInfo = FirstInfo
					elseif currentFrame == 60 then
						attackInfo = LastInfo
					else
						if currentFrame % 6 ~= 4 then return end -- filter to every 6 frame
					end

					const info = Crane.Utils.DeepClone(attackInfo)
					info.Burn = self.Burn

					const Targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = attackInfo.Hitbox,
					})

					for _, Target in Targets do
						CombatService:Attack({
							Attacker = character,
							Victim = Target,
							Info = info,
						})
					end
				end,
				60,
			},

			{ 70 },
		},
	}))
end

function Skill.Activate(self)
	const CombatService = Crane:GetService("CombatService")
	const charged, _ = CombatService:ConsumeHamonCharge(self.Character, BURN_COST)
	self.Burn = if charged then BurnInfo else nil

	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
end

function Skill.Interrupt(self)
	if self.Sequence then self.Sequence:Stop() end
end

return Skill
