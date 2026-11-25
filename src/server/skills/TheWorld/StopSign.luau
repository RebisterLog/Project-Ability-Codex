--[=[
	Stop Sign

	Slow combo starter. Slams a sign into the ground, ignores block, breaks the
	victim's guard, applies hyper armor to the caster, severs the right arm and
	leaves a short bleed. The stand is presentation only; damage comes from the
	character.

	ASSETS:
	Animations
	   Animations/StopSign, Stand/Animations/StopSign : cast clips
	   Animations/StopSignVictim : victim reaction
	Sounds
	   Sounds/StopSign, Stand/Sounds/StopSign
	   Sounds/StopSignHit : impact
	Models
	   Models/StopSign : sign left stuck in the ground
	   Models/StopSignImpact : ground/debris VFX
	   Models/SeveredRightArm : severed limb template
]=]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Stop Sign",
	Cooldown = 15,

	SkillCharacters = { "Hit", "Stun", "ComboStarter", "IgnoreBlock", "Armored", "Debuff" },

	AttackInfo = {
		Damage = 20,
		Block = {
			Blockable = false,
			PerfectBlockable = false,
			BlockBreak = false,
			BlockCancel = true,
			BlockIgnore = true,
		},
		Stun = { Priority = Enums.Stun.Medium, Duration = Enums.StunTime.Medium },
		Knockback = { Preset = "Slam", Direction = { Mode = "AwayFromAttacker" } },
		Bleed = { Damage = 0.5, Duration = 3 },
		Sever = { Limb = Enums.Limb.RightArm, Duration = 8 },
		HitAnimations = "Default",
		HitEffects = { { Particle = "Default", Sound = "Default" } },
	} :: types.AttackInfo,

	Hitbox = {
		Size = Vector3.new(7, 7, 7),
		Offset = CFrame.new(0, 0, -3),
		MovementCorrection = true,
		Debug = false,
	},
}

function Skill:onInit()
	const character = self.Character :: types.Character
	const CombatService = Crane:GetService("CombatService")
	const VFXService = Crane:GetService("VFXService")
	const stats = self.Spec and self.Spec.Data.Assets.Stats.StopSign or self.Data.Hitbox

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					const stand =
						Crane:GetService("StandService"):GetStand(character) :: types.Stand
					const isStandActive = if stand then stand:IsActive() else false
					self.AssetPrefix = if isStandActive then "Stand/" else ""
					self.Caster = if isStandActive then stand.instance else character.instance

					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Medium))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))
					seq.Cleaner:Add(CombatService:AddArmor(character))

					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = self.Caster,
						Animation = self:GetAsset(self.AssetPrefix .. "Animations/StopSign"),
						Speed = seq.Speed,
					})
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = character.RootPart,
						Sound = self:GetAsset(self.AssetPrefix .. "Sounds/StopSign"),
					})
					seq.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "Animation", {
							Character = self.Caster,
							Animation = self:GetAsset(self.AssetPrefix .. "Animations/StopSign").Animation,
						})
					end)
				end,
			},

			{
				stats.HitFrame,
				function()
					const targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = self.Data.Hitbox,
					}) :: { types.Character }

					for _, target in targets do
						if target == character then continue end
						if target:GetParameter("Ragdoll") then continue end

						CombatService:Attack({
							Attacker = character,
							Victim = target,
							Info = self.Data.AttackInfo,
						})
					end

					-- Ground impact and the sign that stays behind.
					const impact = character.RootPart.CFrame * CFrame.new(0, 0, -3)
					self.ImpactUUID = os.clock()
					VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
						UUID = self.ImpactUUID,
						Particle = self:GetAsset("Models/StopSignImpact"),
						Origin = impact,
					})
					const sign = self.Cleaner:Clone(self:GetAsset("Models/StopSign"))
					sign:PivotTo(impact * CFrame.Angles(0, 0, math.pi / 2))
					self.Cleaner:Add(sign)
					task.delay(stats.SignLifetime or 15, function()
						if sign.Parent then sign:Destroy() end
					end)
				end,
			},

			{ stats.EndFrame },
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
		self.ImpactUUID = nil
	end
	if self.Caster then
		VFXService:StopEffect(Players:GetPlayers(), "Animation", {
			Character = self.Caster,
			Animation = self:GetAsset(self.AssetPrefix .. "Animations/StopSign").Animation,
		})
	end
end

return Skill
