const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Star Finger",
	BaseSpec = "StarPlatinum",
	Cooldown = 8,
	Tag = "OnlyForStand",

	SkillCharacters = { "Hit", "Stun", "Blockable" },

	AttackInfo = {
		Hitbox = {
			Size = Vector3.new(2, 2, 14),
			Offset = CFrame.new(0, 0, -7),
			Debug = true,
		},

		Damage = 10,

		Block = {
			Blockable = true,
			PerfectBlockable = false,
			BlockBreak = false,
		},

		Stun = {
			Priority = Enums.Stun.Medium,
			Duration = 1, --1.5
		},
	},
}

function Skill.onInit(self)
	const character = self.Character
	const VFXService = Crane:GetService("VFXService")

	const CombatService = Crane:GetService("CombatService")

	const AttackInfo = self.Data.AttackInfo

	self.AlreadyHit = {}

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Walk))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))
					table.clear(self.AlreadyHit)

					local starFingerAnim = self:GetAsset("Stand/Animations/StarFinger")
					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = self.Stand.instance,
						Animation = starFingerAnim,
						Speed = seq.Speed,
					})
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = self.Stand.RootPart,
						Sound = self:GetAsset("Stand/Sounds/StarFinger"),
					})

					seq.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "Animation", {
							Character = self.Stand.instance,
							Animation = starFingerAnim.Animation,
						})
					end)
				end,
			},

			{
				30,
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
						})
					end
				end,
				35,
			},

			{ 45 },
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
		Sound = self:GetAsset("Stand/Sounds/StarFinger").Sound,
	})
end

return Skill
