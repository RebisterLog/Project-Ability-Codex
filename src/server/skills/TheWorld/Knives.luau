const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Projectile = require(ServerScriptService.server["combat-classes"].Projectile)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Knives",
	AimRequired = true,
	UseCooldown = 3,

	SkillCharacters = { "Projectile", "Hit", "IgnoreBlock" },

	AttackInfo = {
		Damage = 2.5,
		Block = {
			Blockable = false,
			PerfectBlockable = false,
			BlockBreak = false,
			BlockCancel = false,
			BlockIgnore = true,
		},
		HitAnimations = "Default",
		HitEffects = { { Particle = "Default", Sound = "Sounds/MarkedKnivesHit" } },
	} :: types.AttackInfo,

	ProjectileData = {
		Offsets = {
			CFrame.new(-1.5, 0, -2),
			CFrame.new(0, 0, -2),
			CFrame.new(1.5, 0, -2),
		},
		Speed = 150,
		Lifetime = 2,
		AimFallbackDistance = 60,
		MaxDistance = 200,
		HitboxSize = Vector3.new(0.3, 0.5, 2.5),
		Debug = true,
	},
}

local function shootVolley(self: types.Skill, aimPoint: Vector3)
	const CombatService = Crane:GetService("CombatService")
	const character = self.Character
	const root = character.RootPart

	for _, offset in self.Data.ProjectileData.Offsets do
		const muzzle = root.CFrame * offset
		const direction = aimPoint - muzzle.Position
		if direction.Magnitude < 0.001 then continue end

		const knife = Projectile.new({
			Caster = character,
			Skill = self,
			Model = self:GetAsset("Models/Knife"),
			Position = muzzle.Position,
			Direction = direction,
			Speed = self.Data.ProjectileData.Speed,
			HitboxSize = self.Data.ProjectileData.HitboxSize,
			Lifetime = self.Data.ProjectileData.Lifetime,
			MaxDistance = self.Data.ProjectileData.MaxDistance,
			CanPierce = false,
			OrientToVelocity = true,
			Debug = self.Data.ProjectileData.Debug,
			VisualEffect = "ProjectileFlight",
		})
		self.Cleaner:Add(knife)

		knife.Hit:Connect(function(target: types.Character)
			CombatService:Attack({
				Attacker = character,
				Victim = target,
				Skill = self,
				Info = self.Data.AttackInfo,
			})
		end)
		knife:Start()
	end
end

function Skill:onInit()
	const character = self.Character :: types.Character
	const CombatService = Crane:GetService("CombatService")
	const VFXService = Crane:GetService("VFXService")

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Slowed))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					const clip = self:GetAsset("Animations/MarkedKnives")
					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = character.instance,
						Animation = clip,
						Speed = seq.Speed,
					})
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = character.RootPart,
						Sound = self:GetAsset("Sounds/MarkedKnivesThrow"),
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
				15,
				function()
					shootVolley(self, self.AimPoint)
				end,
			},

			{ 20 },
		},
	}))
end

function Skill:Activate(aimPoint: Vector3?)
	const CombatService = Crane:GetService("CombatService")
	if math.floor(CombatService:GetCharge(self.Character, "KnivesCharge")) < 1 then return end
	CombatService:ConsumeCharge(self.Character, "KnivesCharge", 1)
	self:SetCooldown(self.Data.UseCooldown)

	self.AimPoint = aimPoint
		or self.Character.RootPart.CFrame.Position
			+ self.Character.RootPart.CFrame.LookVector * self.Data.ProjectileData.AimFallbackDistance

	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
end

function Skill:Interrupt()
	const VFXService = Crane:GetService("VFXService")
	if self.Sequence then self.Sequence:Stop() end
	VFXService:StopEffect(Players:GetPlayers(), "Animation", {
		Character = self.Character.instance,
		Animation = self:GetAsset("Animations/MarkedKnives").Animation,
	})
end

return Skill
