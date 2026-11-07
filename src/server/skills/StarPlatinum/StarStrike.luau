const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Star Strike",
	Cooldown = 8,
	Tag = "OnlyForStand",

	SkillCharacters = { "Hit", "Ragdoll", "BlockBreak", "PerfectBlock" },

	AttackInfo = {
		Hitbox = {
			Size = Vector3.new(6, 6, 8),
			Offset = CFrame.new(0, 0, -4),
			Debug = true,
		},

		Damage = 15,

		Block = {
			BlockBreak = true,
			PerfectBlockable = true,
		},

		Ragdoll = {
			Duration = Enums.Ragdoll.Light,
		},

		Knockback = {
			RelativePart = "Attacker",
			Duration = 0.1,
			Velocity = Vector3.new(0, 10, 0),
			Speed = 40,
		},
	},
}

function Skill.onInit(self)
	const character = self.Character
	const VFXService = Crane:GetService("VFXService")

	const CombatService = Crane:GetService("CombatService")

	const Anims = self.Spec.Data.Assets.Stand.Animations
	const Sounds = self.Spec.Data.Assets.Stand.Sounds
	const AttackInfo = self.Data.AttackInfo

	self.AlreadyHit = {}

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Slowed))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))
					table.clear(self.AlreadyHit)

					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = self.Stand.instance,
						Animation = Anims.StarStrike,
						Speed = seq.Speed,
					})
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = self.Stand.RootPart,
						Sound = Sounds.StarStrike,
					})

					seq.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "Animation", {
							Character = self.Stand.instance,
							Animation = Anims.StarStrike.Animation,
						})
					end)
				end,
			},

			{
				40,
				function()
					local Targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = AttackInfo.Hitbox,
					})

					for _, Target in Targets do
						if table.find(self.AlreadyHit, Target) then continue end
						table.insert(self.AlreadyHit, Target)

						CombatService:Attack({
							Attacker = character,
							Victim = Target,
							Info = AttackInfo,
						}):andThen(function(Data: types.AttackData)
							if not Data.State.Success then return end
							if Data.State.PerfectBlocked or Data.State.BlockBroken then return end

							VFXService:StartEffect(Players:GetPlayers(), "Sound", {
								Origin = Target.RootPart,
								Sound = Sounds.StarStrikeHit,
							})
						end)
					end
				end,
				45,
			},

			{ 70 },
		},
	}))
end

function Skill.Activate(self)
	self.Stand = Crane:GetService("StandService"):GetStand(self.Character)

	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
end

function Skill.Interrupt(self)
	const VFXService = Crane:GetService("VFXService")

	if self.Sequence then self.Sequence:Stop() end

	VFXService:StopEffect(Players:GetPlayers(), "Sound", {
		Origin = self.Stand.RootPart,
		Sound = self.Spec.Data.Assets.Stand.Sounds.StarStrike.Sound,
	})
end

return Skill
