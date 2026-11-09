const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Sendo Hamon",
	Cooldown = 2,

	AttackInfo = {
		Hitbox = {
			Size = Vector3.new(7, 7, 7),
			Offset = CFrame.new(0, 0, -3),
			Debug = true,
		},

		Damage = 15,

		Block = {
			Blockable = true,
			PerfectBlockable = false,
			BlockBreak = false,
		},

		Stun = {
			Priority = Enums.Stun.Medium,
			Duration = 0.7,
		},

		Ragdoll = {
			Duration = 2,
		},

		Knockback = {
			RelativePart = "Attacker",
			Duration = 0.1,
			Velocity = Vector3.new(0, 50, 0),
			Speed = 40,
		},
	},
}

function Skill.onInit(self)
	const character = self.Character
	const RootPart = character.RootPart
	const Humanoid = character.Humanoid
	const VFXService = Crane:GetService("VFXService")

	const CombatService = Crane:GetService("CombatService")

	const AttackInfo = self.Data.AttackInfo

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Slowed))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = character.instance,
						Animation = self:GetAsset("Animations/SendoHamon"),
						Speed = seq.Speed,
					})

					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = RootPart,
						Sound = self:GetAsset("Sounds/NAME"),
					})

					--seq.Cleaner:Add(function()
					--	VFXService:StopEffect(Players:GetPlayers(), "Animation", { Character = character.instance,
					--		Animation = self:GetAsset("Animations/NAME").Animation,
					--	})
					--end)
				end,
			},

			{
				20,
				function(seq, frame)
					if frame % 10 ~= 0 then return end

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
						}):andThen(function(Data: types.AttackData)
							if not Data.State.Success then return end
							table.insert(self.AlreadyHit, Target)
						end)
					end
				end,
				120,
			},

			{
				125,
				function(seq)
					--local Targets = CombatService:Hitbox({
					--	Skill = self,
					--	Caster = character,
					--	Info = AttackInfo.Hitbox
					--})

					--for _, Target in Targets do
					--	if table.find(self.AlreadyHit, Target) then
					--		continue
					--	end

					--	CombatService:Attack({
					--		Attacker = character,
					--		Victim = Target,
					--		Info = AttackInfo,
					--	}):andThen(function(Data: types.AttackData)
					--		if not Data.State.Success then return end
					--		table.insert(self.AlreadyHit, Target)

					--	end)
					--end
				end,
			},

			{ 130 },
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

	if self.Sequence then self.Sequence:Stop() end
end

return Skill
