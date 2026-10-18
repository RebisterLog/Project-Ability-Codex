const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Types = require(ServerScriptService.server.types)

const Skill = {
	DisplayName = "Footrest",
	Cooldown = 1,

	SkillCharacters = {
		"Ragdoll",
		"PerfectBlockable",
		"Hit",
		"ComboEnder",
		"Armored",
		"BlockBreaker",
		"Blockable",
	},

	AttackInfo = {
		Hitbox = {
			Size = Vector3.new(8, 2, 7),
			Offset = CFrame.new(0, -2, -3),
			Debug = true,
		},

		Damage = 15,

		Block = {
			BlockBreak = false,
			PerfectBlockable = false,
		},

		Stun = {
			Priority = Enums.Stun.Heavy,
			Duration = 1.5,
		},
	},
}

function Skill.onInit(self)
	const character = self.Character
	const RootPart = character.RootPart
	const Humanoid = character.Humanoid
	const VFXService = Crane:GetService("VFXService")

	const CombatService = Crane:GetService("CombatService")

	const Anims = self.Spec.Data.Assets.Animations
	const Sounds = self.Spec.Data.Assets.Sounds
	const Models = self.Spec.Data.Assets.Models
	const AttackInfo = self.Data.AttackInfo

	self.AlreadyHit = {}
	self.UUID = 0

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				1,
				function(seq)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 3))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					table.clear(self.AlreadyHit)

					VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
						Animation = Anims.Footrest,
						Speed = seq.Speed,
					})
					VFXService:StartEffect(
						Players:GetPlayers(),
						"Sound",
						RootPart,
						Sounds.FootrestVL
					)
				end,
			},

			{
				24,
				function()
					self.UUID = tick()
					VFXService:StartEffect(
						Players:GetPlayers(),
						"EmitFolder",
						character.instance,
						Models.Footrest,
						self.UUID
					)
				end,
			},

			{
				25,
				function(seq, Frame)
					const Targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = AttackInfo.Hitbox,
					})

					for _, Target in Targets do
						if table.find(self.AlreadyHit, Target) then continue end

						CombatService:Attack({
							Attacker = character,
							Victim = Target,
							Info = AttackInfo,
						}):andThen(function(Data: Types.AttackData)
							if not Data.State.Success then return end
							table.insert(self.AlreadyHit, Target)
							if not Data.State.Continue then return end

							VFXService:StartEffect(
								Players:GetPlayers(),
								"EmitFolder",
								Data.Victim.instance,
								Models.FootrestVictim
							)

							VFXService:StartEffect(
								Players:GetPlayers(),
								"Animation",
								Data.Victim.instance,
								{
									Animation = Anims.FootrestVictim,
									Speed = seq.Speed,
								}
							)
						end)
					end
				end,
				30,
			},

			{ 45 },
		},
	}))
end

function Skill.Activate(self)
	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
end

function Skill.Interrupt(self)
	const character = self.Character
	const RootPart = character.RootPart
	const VFXService = Crane:GetService("VFXService")

	const Anims = self.Spec.Data.Assets.Animations
	const Sounds = self.Spec.Data.Assets.Sounds

	if self.Sequence then self.Sequence:Stop() end

	VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, {
		Animation = Anims.Footrest.Animation,
	})
	VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds.FootrestVL.Sound)
	VFXService:StopEffect(Players:GetPlayers(), "EmitFolder", character.instance, self.UUID)
end

return Skill
