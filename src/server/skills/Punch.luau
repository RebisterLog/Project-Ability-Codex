const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Punch",
	ComboCooldown = 1.5,
	ComboResetTime = 1.5,
	MaxCombo = 4,

	SkillCharacters = {
		"Hit",
		"Stun",
		"ComboStarter",
		"Blockable",
	},
}

function Skill:onInit()
	const character = self.Character :: types.Character
	const RootPart = character.RootPart
	const Humanoid = character.Humanoid

	const VFXService = Crane:GetService("VFXService")
	const CombatService = Crane:GetService("CombatService")
	const StandService = Crane:GetService("StandService")

	const stand = StandService:GetStand(self.Character) :: types.Stand
	const isStandActive = if stand then stand:IsActive() else false

	-- if stand exists - it will use stand's Assets
	self.Assets = if isStandActive then self.Spec.Data.Assets.Stand else self.Spec.Data.Assets
	self.Caster = isStandActive and stand.instance or self.Character.instance

	self.PunchCount = 1
	self.AlreadyHit = {}

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					const Anims = self.Assets.Animations
					const Sounds = self.Assets.Sounds

					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 8))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					table.clear(self.AlreadyHit)

					if self.PunchCount > 1 then
						VFXService:StopEffect(Players:GetPlayers(), "Animation", self.Caster, {
							Animation = Anims["Punch" .. self.PunchCount - 1],
						})
					end

					VFXService:StartEffect(Players:GetPlayers(), "Animation", self.Caster, {
						Animation = Anims["Punch" .. self.PunchCount],
						Speed = seq.Speed,
					})

					VFXService:StartEffect(
						Players:GetPlayers(),
						"Sound",
						RootPart,
						Sounds[`Punch{self.PunchCount}`]
					)

					for i, trail: Trail in self.Caster:QueryDescendants("#PunchTrail") do
						trail.Enabled = true
					end

					seq.Cleaner:Add(function()
						task.delay(0.5, function()
							for i, trail: Trail in self.Caster:QueryDescendants("#PunchTrail") do
								trail.Enabled = false
							end
						end)
					end)
				end,
			},

			{
				14,
				function(seq, Frame)
					const Models = self.Assets.Models

					const Targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = {
							MovementCorrection = true,
							Size = Vector3.new(7, 7, 7),
							Offset = CFrame.new(0, 0, -3),
							Debug = true,
						},
					}) :: { types.Character }

					for _, Target in Targets do
						if table.find(self.AlreadyHit, Target) then continue end

						CombatService:Attack({
							Attacker = character,
							Victim = Target,
							Info = {
								Damage = 2.5,
								Block = {
									PerfectBlockable = false,
									--BlockCancel = self.PunchCount == self.Data.MaxCombo
								},
								Knockback = {
									RelativePart = self.PunchCount == self.Data.MaxCombo
										and "Attacker",
									ToFront = if self.PunchCount ~= self.Data.MaxCombo
										then 5
										else false,
									Speed = self.PunchCount == self.Data.MaxCombo and 200 or 8,
									Duration = self.PunchCount == self.Data.MaxCombo and 0.05
										or 0.05,
								},
								Stun = {
									Priority = Enums.Stun.Medium,
									Duration = 0.55,
								},
							},
						}):andThen(function(data)
							if data.State.Success then
								table.insert(self.AlreadyHit, Target)

								if not data.State.Blocked then
									VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
										Particle = Models["PunchHit"],
										Origin = Target.RootPart,
									})
								end
							end
						end)
					end
				end,
			},
		},
	}))
end

function Skill:Activate()
	const StandService = Crane:GetService("StandService")

	const stand = StandService:GetStand(self.Character) :: types.Stand
	const isStandActive = if stand then stand:IsActive() else false

	self.Assets = isStandActive and self.Spec.Data.Assets.Stand or self.Spec.Data.Assets
	self.Caster = isStandActive and stand.instance or self.Character.instance

	if self.ResetPunches then
		task.cancel(self.ResetPunches)
		self.ResetPunches = nil
	end

	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end

	self.PunchCount += 1

	if self.PunchCount > self.Data.MaxCombo then
		self.PunchCount = 1
		self:SetCooldown(self.Data.ComboCooldown)
	elseif self.Data.ComboResetTime then
		const oldCount = self.PunchCount

		self.ResetPunches = task.delay(self.Data.ComboResetTime, function()
			if oldCount == self.PunchCount then self.PunchCount = 1 end
		end)
	end
end

function Skill:Interrupt()
	const VFXService = Crane:GetService("VFXService")

	const PunchCount = self.PunchCount

	if self.Sequence then self.Sequence:Stop() end

	const Anims = self.Assets.Animations

	VFXService:StopEffect(Players:GetPlayers(), "Animation", self.Caster, {
		Animation = Anims["Punch" .. PunchCount],
	})
end

return Skill
