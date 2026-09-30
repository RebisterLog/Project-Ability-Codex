local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Enums = require(ServerScriptService.server.Enums)
local Types = require(ServerScriptService.server.types)

local Skill: Types.SkillData = {
	DisplayName = "Uppercut",
	Cooldown = 1,

	SkillCharacters = {
		"Ragdoll",
		"PerfectBlockable",
		"Hit",
		"ComboEnder",
		"Armored",
		"BlockBreaker",
	},

	AttackInfo = {
		Hitbox = {
			Size = Vector3.new(7, 7, 7),
			Offset = CFrame.new(0, 0, -3),
			Debug = true,
		},
		--
		Damage = 15,

		Block = {
			PerfectBlockable = true,
			BlockBreak = true,
		},

		Knockback = {
			Duration = 0.1,
			Velocity = Vector3.new(0, 50, 0),
			Speed = 30,
			RelativePart = "Attacker",
		},

		Angular = {
			Velocity = Vector3.new(-15, 0, 0),
			Duration = 0.2,
		},

		Stun = {
			Priority = Enums.Stun.Medium,
			Duration = 0.7,
		},

		Ragdoll = {
			Duration = 2,
		},
	},
}

function Skill.onInit(self)
	local character = self.Character
	local RootPart = character.RootPart
	local Humanoid = character.Humanoid
	local VFXService = Crane:GetService("VFXService")

	local CombatService = Crane:GetService("CombatService")

	local Anims = self.Spec.Data.Assets.Animations
	local Sounds = self.Spec.Data.Assets.Sounds
	local Models = self.Spec.Data.Assets.Models
	local AttackInfo = self.Data.AttackInfo

	self.AlreadyHit = {}

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				1,
				function(seq)
					seq.Cleaner:Set("Armor", CombatService:AddArmor(character, true))
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 3))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					table.clear(self.AlreadyHit)

					VFXService:StartEffect(
						Players:GetPlayers(),
						"EmitFolder",
						self.Character.instance,
						Models.Uppercut
					)
					VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
						Animation = Anims.Uppercut,
						Speed = seq.Speed,
					})
					VFXService:StartEffect(
						Players:GetPlayers(),
						"Sound",
						RootPart,
						Sounds["UppercutVL"]
					)
				end,
			},

			{
				20,
				function(seq, Frame)
					local Targets = CombatService:Hitbox({
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

							if Data.State.PerfectBlocked or Data.State.BlockBroken then return end

							if #self.AlreadyHit <= 1 then
								VFXService:StartEffect(
									Players:GetPlayers(),
									"EmitFolder",
									self.Character.instance,
									Models.UppercutHit
								)
							end

							VFXService:StartEffect(
								Players:GetPlayers(),
								"Sound",
								Data.Victim.RootPart.CFrame,
								Sounds.UppercutHit
							)
						end)
					end
				end,
				24,
			},

			{
				30,
				function(seq)
					seq.Cleaner:Remove("Armor")
				end,
			},

			{ 35 },
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
	local character = self.Character
	local RootPart = character.RootPart
	local VFXService = Crane:GetService("VFXService")

	local Anims = self.Spec.Data.Assets.Animations
	local Sounds = self.Spec.Data.Assets.Sounds

	if self.Sequence then self.Sequence:Stop() end

	VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, {
		Animation = Anims.Uppercut.Animation,
	})
	VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds.UppercutVL.Sound)
end

return Skill
