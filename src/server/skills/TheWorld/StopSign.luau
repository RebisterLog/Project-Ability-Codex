const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Stop Sign",
	Cooldown = 15,

	SkillCharacters = { "Hit", "Ragdoll", "ComboStarter", "IgnoreBlock", "Armored", "Debuff" },

	AttackInfo = {
		Damage = 20,
		Block = {
			Blockable = false,
			PerfectBlockable = false,
			BlockBreak = false,
			BlockCancel = true,
			BlockIgnore = true,
		},
		Ragdoll = { Duration = Enums.Ragdoll.Light },
		Bleed = { Damage = 0.5, Duration = 3, Slow = 0 },
		Sever = { Limb = Enums.Limb.RightArm, Duration = 5 },
		HitAnimations = "Default",
		HitEffects = { { Particle = "Default", Sound = "Default" } },
	} :: types.AttackInfo,

	Hitbox = {
		Size = Vector3.new(7, 7, 7),
		Offset = CFrame.new(0, 0, -3),
		MovementCorrection = true,
		Debug = true,
	},
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
					const weapon = CombatService:Equip(character, self:GetAsset("Models/StopSign"))
					seq.Cleaner:Add(weapon)

					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Medium))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))
					seq.Cleaner:Add(CombatService:AddArmor(character))

					const clip = self:GetAsset("Animations/StopSign")
					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = character.instance,
						Animation = clip,
						Speed = seq.Speed,
					})
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = character.RootPart,
						Sound = self:GetAsset("Sounds/StopSign"),
					})
					seq.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "Animation", {
							Character = character.instance,
							Animation = clip.Animation,
						})
					end)
				end,
			},

			{
				50,
				function()
					const targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = self.Data.Hitbox,
					}) :: { types.Character }

					for _, target in targets do
						CombatService:Attack({
							Attacker = character,
							Victim = target,
							Info = self.Data.AttackInfo,
						})
					end

					self.ImpactUUID = os.clock()
					VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
						UUID = self.ImpactUUID,
						Particle = self:GetAsset("Models/StopSignImpact"),
						Origin = character.RootPart.CFrame,
					})
				end,
			},

			{ 65 },
		},
	}))
end

function Skill:Activate()
	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
end

function Skill:Interrupt()
	const VFXService = Crane:GetService("VFXService")
	if self.Sequence then self.Sequence:Stop() end

	if self.ImpactUUID then
		VFXService:StopEffect(Players:GetPlayers(), "EmitParticle", { UUID = self.ImpactUUID })
		VFXService:StopEffect(Players:GetPlayers(), "StopSignSign", { UUID = self.ImpactUUID })
		self.ImpactUUID = nil
	end
	VFXService:StopEffect(Players:GetPlayers(), "Animation", {
		Character = self.Character.instance,
		Animation = self:GetAsset("Animations/StopSign").Animation,
	})
end

return Skill
