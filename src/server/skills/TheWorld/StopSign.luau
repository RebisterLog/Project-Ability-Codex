const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Sudden Slam",
	Cooldown = 15,

	SkillCharacters = { "Hit", "Ragdoll", "ComboStarter", "IgnoreBlock", "Armored", "Debuff" },

	AttackInfo = {
		Damage = 10,
		Ragdoll = { Duration = Enums.Ragdoll.Light },
		Bleed = { Damage = 0.5, Duration = 3, Slow = 0 },
		Sever = { Limb = Enums.Limb.RightArm, Duration = 5 },

		Hitbox = {
			MovementCorrection = true,
			Size = Vector3.new(5, 7, 10),
			Offset = CFrame.new(0, 0, -8),
			Debug = true,
		},
	} :: types.AttackInfo,

	SlamInfo = {
		Priority = Enums.IFrames.Ragdoll,

		Damage = 5,
		Block = {
			Blockable = false,
			PerfectBlockable = false,
			BlockBreak = false,
			BlockCancel = true,
			BlockIgnore = true,
		},

		Ragdoll = { Duration = Enums.Ragdoll.Light },

		HitAnimations = "Default",
		HitEffects = { { Particle = "Default", Sound = "Default" } },

		Hitbox = {
			Size = 8,
			Offset = CFrame.new(0, -2, -8.5),
			MovementCorrection = true,
			Debug = true,
		},
	},
}

function Skill:onInit()
	const character = self.Character :: types.Character
	const CombatService = Crane:GetService("CombatService")
	const VFXService = Crane:GetService("VFXService")
	const ClientStateService = Crane:GetService("ClientStateService")

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					const weapon = CombatService:Equip(character, self:GetAsset("Models/StopSign"))
					seq.StopSign = weapon
					seq.Cleaner:Add(weapon)

					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Medium))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))
					seq.Cleaner:Set("Armor", CombatService:AddArmor(character))

					const clip = self:GetAsset("Animations/StopSign")
					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = character.instance,
						Animation = clip,
						Speed = seq.Speed,
						FadeInTime = 0.25,
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
				43,
				function(seq)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 0))
					seq.Cleaner:Add(character:AddParameter("NoRotate", true))
				end,
			},

			{
				46,
				function(seq)
					VFXService:StartEffect({ character.instance }, "Step", {
						Normal = Vector3.new(0, 0, -1),
						Speed = 40,
						EndSpeed = 8,
						Turn = true,
						Character = character.instance,
						Time = 0.25 * seq.Speed,
					})
				end,
			},

			{
				46,
				function(seq)
					const AttackInfo = self.Data.AttackInfo

					const targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = AttackInfo.Hitbox,
					}) :: { types.Character }

					for _, target in targets do
						CombatService:Attack({
							Skill = self,
							Victim = target,
							Info = AttackInfo,
						})
					end
				end,
			},

			{
				50,
				function(seq)
					const SlamInfo = self.Data.SlamInfo

					const targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = SlamInfo.Hitbox,
					}) :: { types.Character }

					for _, target in targets do
						CombatService:Attack({
							Skill = self,
							Victim = target,
							Info = SlamInfo,
						})
					end

					VFXService:StartEffect(Players:GetPlayers(), "GroundEmit", {
						Particle = self:GetAsset("Models/StopSignImpact"),
						Origin = character.RootPart,
						Offset = SlamInfo.Hitbox.Offset,
						GroundOffset = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)),
					})

					const Valid = {}
					const Radius = SlamInfo.Hitbox.Size * 1.25
					for _, Player in Players:GetPlayers() do
						if
							not (
								Player.Character
								and Player.Character:FindFirstChild("HumanoidRootPart")
							)
						then
							continue
						end
						if
							(
								Player.Character.HumanoidRootPart.Position
								- character.RootPart.Position
							).Magnitude >= Radius
						then
							continue
						end

						table.insert(Valid, Player)
					end

					VFXService:StartEffect(Valid, "CameraShake", { Type = "Slam" })
				end,
			},

			{
				55,
				function(seq)
					VFXService:StartEffect(Players:GetPlayers(), "TW_DiscardSign", {
						Model = seq.StopSign,
					})
				end,
			},

			{
				50,
				function(seq)
					seq.Cleaner:Remove("Armor")
				end,
			},

			{ 85 },
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

	VFXService:StopEffect(Players:GetPlayers(), "Animation", {
		Character = self.Character.instance,
		Animation = self:GetAsset("Animations/StopSign").Animation,
	})
end

return Skill
