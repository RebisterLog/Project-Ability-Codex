--!native
--!optimize 2

--[=[ CircularKick

   Unblockable low kick that sweeps the ground in front of the caster, ragdolling enemies.
   Hits ragdolled enemies via Ragdoll IFrame priority.
   Sphere hitbox placed at ground level for a foot-sweep feel.


   ASSETS:

   Animations
      CircularKick : Animation for the kick

   Sounds
      CircularKick : Sound for the kick swoosh
      CircularKickVL : Voice line on cast
      CircularKickHit : Sound on hit connect
]=]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "CircularKick",
	BaseSpec = "Standless",
	Cooldown = 15,

	SkillCharacters = {
		"Hit",
		"ComboEnder",
		"IgnoreBlock",
		"Ragdoll",
	},

	AttackInfo = {
		Priority = Enums.IFrames.Ragdoll,

		Hitbox = {
			Size = 6,
			Offset = CFrame.new(0, -3, -4),
			Debug = true,
		},

		Damage = 8,

		Block = {
			BlockIgnore = true,
		},

		Ragdoll = {
			Duration = 0.5,
		},

		Knockback = {
			RelativePart = "Attacker",
			Speed = 30,
			Duration = 0.1,
			Velocity = Vector3.new(0, 20, 0),
		},
	},
}

function Skill:onInit()
	const character = self.Character :: types.Character
	const RootPart = character.RootPart
	const VFXService = Crane:GetService("VFXService")

	const CombatService = Crane:GetService("CombatService")

	const AttackInfo = self.Data.AttackInfo

	self.AlreadyHit = {}

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 3))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					table.clear(self.AlreadyHit)

					local circularKickAnim = self:GetAsset("Animations/CircularKick")
					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = character.instance,
						Animation = circularKickAnim,
						Speed = seq.Speed,
					})
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = RootPart,
						Sound = self:GetAsset("Sounds/CircularKick"),
					})
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = RootPart,
						Sound = self:GetAsset("Sounds/CircularKickVL"),
					})

					seq.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "Animation", {
							Character = character.instance,
							Animation = circularKickAnim.Animation,
						})
					end)
				end,
			},

			{
				11,
				function()
					VFXService:StartEffect(Players:GetPlayers(), "EmitFolder", {
						Character = character.instance,
						EffectsFolder = self:GetAsset("Models/CircularKick"),
					})
				end,
			},

			{
				19,
				function()
					local circularKickFolder = self:GetAsset("Models/CircularKick")
					local groundHit = self:GetAsset("Models/CircularKickGroundHit")
					VFXService:StartEffect(Players:GetPlayers(), "EmitFolder", {
						Character = character.instance,
						EffectsFolder = circularKickFolder,
					})
					VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
						Particle = groundHit,
						Origin = character.RootPart.CFrame,
						Offset = groundHit:GetAttribute("Offset"),
						UseForge = true,
					})
				end,
			},

			{
				20,
				function(seq)
					const Targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = AttackInfo.Hitbox,
					}) :: { types.Character }

					for _, Target in Targets do
						if table.find(self.AlreadyHit, Target) then continue end

						CombatService:Attack({
							Attacker = character,
							Victim = Target,
							Info = AttackInfo,
						}):andThen(function(Data: types.AttackData)
							if not Data.State.Success then return end
							table.insert(self.AlreadyHit, Target)

							if #self.AlreadyHit <= 1 then
								VFXService:StartEffect(Players:GetPlayers(), "Sound", {
									Origin = Target.RootPart,
									Sound = self:GetAsset("Sounds/CircularKickHit"),
								})
							end
						end)
					end
				end,
				25,
			},

			{ 40 },
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
		Animation = self:GetAsset("Animations/CircularKick").Animation,
	})
end

return Skill
