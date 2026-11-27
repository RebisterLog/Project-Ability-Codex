const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Fraid Kick",
	Tag = "OnlyForStand",
	SearchRadius = 50,

	SkillCharacters = { "Hit", "Blockable", "PerfectBlock", "Ragdoll" },

	AttackInfo = {
		Damage = 25,
		Block = {
			Blockable = false,
			PerfectBlockable = true,
			BlockBreak = false,
			BlockCancel = false,
			BlockIgnore = false,
		},
		Ragdoll = { Duration = Enums.Ragdoll.Light },
		Knockback = { Push = 8, Hold = 0.1, Direction = { Mode = "Custom", Vector = Vector3.zero } },
		HitAnimations = "Default",
		HitEffects = { { Particle = "Default", Sound = "Default" } },
	} :: types.AttackInfo,
}

function Skill:onInit()
	const character = self.Character :: types.Character
	const CombatService = Crane:GetService("CombatService")
	const VFXService = Crane:GetService("VFXService")

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					const target = self.Target
					const stand =
						Crane:GetService("StandService"):GetStand(character) :: types.Stand
					if not target or not stand then return end

					stand:WeldTo(target.RootPart)
					seq.Cleaner:Add(function()
						stand:WeldToOwner()
						if not character.Player then stand:HandleMovement() end
					end)

					self.WarningUUID = os.clock()
					VFXService:StartEffect(Players:GetPlayers(), "DistantSlamWarning", {
						UUID = self.WarningUUID,
						Caster = character.instance,
						Target = target.instance,
						Stand = stand.instance,
						Duration = 1.5,
					})
					seq.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "DistantSlamWarning", {
							UUID = self.WarningUUID,
						})
						VFXService:StopEffect(Players:GetPlayers(), "Animation", {
							Character = stand.instance,
							Animation = self:GetAsset("Stand/Animations/DistantSlam").Animation,
						})
					end)

					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = stand.instance,
						Animation = self:GetAsset("Stand/Animations/DistantSlam"),
						Speed = seq.Speed,
					})

					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = character.RootPart,
						Sound = self:GetAsset("Sounds/DistantSlamCast"),
					})
				end,
			},
			{
				45,
				function()
					const target = self.Target
					if not target or target.Humanoid.Health <= 0 then return end

					const info = table.clone(self.Data.AttackInfo)
					info.Knockback = table.clone(self.Data.AttackInfo.Knockback)
					info.Knockback.Direction = {
						Mode = "Custom",
						Vector = target.RootPart.CFrame.LookVector,
					}

					const hit = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = {
							Debug = true,
							Size = Vector3.new(5, 5, 5),
							Origin = CFrame.new(target.RootPart.Position),
						},
					})

					for _, candidate in hit do
						if candidate ~= target then continue end
						CombatService:Attack({
							Attacker = character,
							Victim = target,
							Info = info,
						})
					end
				end,
			},
			{ 50 },
		},
	}))
end

function Skill:Activate()
	self.Target = nil

	const CombatService = Crane:GetService("CombatService")

	self.CastSlow = self.Character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Medium)
	self.CastNoJump = self.Character:AddParameter("MaxJumpPower", 0)
	self.Sequence.Cleaner:Add(self.CastSlow)
	self.Sequence.Cleaner:Add(self.CastNoJump)

	self:SetCooldown(20)

	const targets = CombatService:Hitbox({
		Caster = self.Character,
		Info = {
			Size = self.Data.SearchRadius,
			SortByDistance = true,
		},
	}) :: { types.Character }
	self.Target = targets[1]
	if not self.Target then
		self.CastSlow:Destroy()
		self.CastNoJump:Destroy()
		return
	end

	self.Sequence:Play()
	self.Sequence:Await()
end

function Skill:Interrupt()
	if self.Sequence then self.Sequence:Stop() end
end

return Skill
