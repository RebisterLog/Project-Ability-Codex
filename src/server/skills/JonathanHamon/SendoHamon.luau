--[=[ SENDO_HAMON

   Ground-wave Hamon: repeated small hits while the wave expands, then a
   ragdolling release. Costs 25 Hamon on cast.

   ASSETS:

   Animations
      SendoHamon : Wave animation (assets/JonathanHamon).

   Sounds
      SendoHamon : Wave sound (assets/JonathanHamon).

   Models
      SendoHamon : Particle VFX part attached to the root.

]=]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const types = require(ServerScriptService.server.types)

const HAMON_COST = 25

const Skill: types.SkillData = {
	DisplayName = "Sendo Hamon",
	Cooldown = 2,
	BaseSpec = "JonathanHamon",
	SkillCharacters = { "Hit", "Blockable", "Ragdoll", "IgnoreBlock" },

	AttackInfo = {
		Hitbox = {
			Size = Vector3.new(30, 2, 30),
			Offset = CFrame.new(0, -3, 0),
			Debug = true,
		},

		Damage = 0.25,

		Block = {
			Blockable = true,
			PerfectBlockable = false,
			BlockBreak = false,
		},

		Stun = {
			Priority = Enums.Stun.Medium,
			Duration = 0.5,
		},
	},

	ReleaseInfo = {
		Damage = 2,

		Block = {
			BlockBreak = true,
		},

		Restand = {
			Duration = Enums.Ragdoll.Heavy,
		},

		-- Ragdoll = {
		-- 	Duration = Enums.Ragdoll.Heavy,
		-- },
	},
}

function Skill.onInit(self)
	const character = self.Character
	const RootPart = character.RootPart
	const VFXService = Crane:GetService("VFXService")
	const CombatService = Crane:GetService("CombatService")

	const AttackInfo = self.Data.AttackInfo
	const ReleaseInfo = self.Data.ReleaseInfo

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Slowed))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					const anim = self:GetAsset("Animations/SendoHamon")
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
						Sound = self:GetAsset("Sounds/SendoHamon"),
					})

					const vfxUUID = math.random(1, 0x7FFFFFFF)
					VFXService:StartEffect(Players:GetPlayers(), "ForgeVFXHold", {
						UUID = vfxUUID,
						Template = self:GetAsset("Models/SendoHamon"),
						Origin = RootPart,
					})

					seq.Cleaner:Add(function()
						VFXService:StopEffect(
							Players:GetPlayers(),
							"ForgeVFXHold",
							{ UUID = vfxUUID }
						)
					end)
				end,
			},

			{
				20,
				function()
					const Targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = AttackInfo.Hitbox,
					})

					for _, Target in Targets do
						CombatService:Attack({
							Attacker = character,
							Victim = Target,
							Info = AttackInfo,
						})
					end
				end,
				120,
				Interval = 10,
			},

			{
				125,
				function()
					const Targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = AttackInfo.Hitbox,
					})

					for _, Target in Targets do
						CombatService:Attack({
							Attacker = character,
							Victim = Target,
							Info = ReleaseInfo,
						})
					end
				end,
			},

			{ 130 },
		},
	}))
end

function Skill.Activate(self)
	const CombatService = Crane:GetService("CombatService")
	const paid = CombatService:ConsumeCharge(self.Character, "HamonCharge", HAMON_COST)
	if not paid then return end

	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
end

function Skill.Interrupt(self)
	if self.Sequence then self.Sequence:Stop() end
end

return Skill
