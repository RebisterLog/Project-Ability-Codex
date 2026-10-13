local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Enums = require(ServerScriptService.server.Enums)
local Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
local types = require(ServerScriptService.server.types)

local Skill: types.SkillData = {
	DisplayName = "Grab",
	Cooldown = 1,

	SkillCharacters = {
		"Grab",
		"ComboEnder",
		"Hit",
		"Ragdoll",
		"IgnoreBlock",
	},

	AttackInfo = {
		Hitbox = {
			Size = Vector3.new(6, 6, 6),
			Offset = CFrame.new(0, 0, -3),
			SortByDistance = true,
			Debug = true,
		},

		Block = {
			PerfectBlockable = false,
			BlockCancel = true,
		},
	},

	Throw = {
		Priority = Enums.IFrames.Grab,
		Damage = 10,

		Block = {
			PerfectBlockable = false,
			BlockCancel = true,
		},

		Knockback = {
			Duration = 0.1,
			Velocity = Vector3.new(0, 30, 0),
			Speed = 100,
			RelativePart = "Attacker",
			MaxForce = Vector3.new(5_000, 10_000, 5_000),
			--FindCrashObject = true,
		},

		Angular = {
			Velocity = Vector3.new(-5, 0, 0),
			Duration = 0.5,
		},

		Ragdoll = {
			Duration = 0.75,
		},

		Stun = {
			Priority = Enums.Stun.Heavy,
			Duration = 1,
		},
	},
}

function Skill.onInit(self)
	local character = self.Character
	local RootPart = character.RootPart
	local Humanoid = character.Humanoid

	local AttackInfo = self.Data.AttackInfo
	local ThrowInfo = table.clone(self.Data.Throw)
	ThrowInfo.Stun = table.clone(self.Data.Throw.Stun)

	local VFXService = Crane:GetService("VFXService")
	local CombatService = Crane:GetService("CombatService")
	local StandService = Crane:GetService("StandService")

	local stand = StandService:GetStand(self.Character) :: types.Stand
	local isStandActive = if stand then stand:IsActive() else false

	-- if stand exists - it will use stand's Assets
	self.Assets = if isStandActive then self.Spec.Data.Assets.Stand else self.Spec.Data.Assets
	self.Caster = isStandActive and stand.instance or self.Character.instance

	self.GrabData = {
		Offset = self.Spec.Data.Assets.Stats.Grab["AnimationOffset"]
			or CFrame.new(0, 0, -4) * CFrame.Angles(0, 180, 0),
		FinalFrame = self.Spec.Data.Assets.Stats.Grab["FinalFrame"] or 30,
	}

	ThrowInfo.Stun.Duration = self.GrabData.FinalFrame / 60
	self.ThrowInfo = ThrowInfo

	self.AlreadyHit = {}
	self.Target = nil :: types.Character?

	self.GrabSequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Validate = function()
			if not self.Target.Parent or not self.Caster.Parent then return false end

			return true
		end,
		Frames = {
			{
				0,
				function(seq: Sequencer.Sequencer)
					local Anims = self.Assets.Animations
					local Sounds = self.Assets.Sounds

					CombatService:Attack({
						Attacker = character,
						Victim = self.Target,
						Info = {
							Block = {
								PerfectBlockable = false,
							},

							Stun = {
								Priority = Enums.Stun.Heavy,
								Duration = 2,
							},
						},
					})

					seq.Cleaner:Set(
						"GrabObject",
						CombatService:CreateGrab(
							character,
							self.Target,
							{
								Attacker = {},
								Victim = {
									Bind = {
										Part0 = RootPart,
										Part1 = self.Target.RootPart,
										Offset = self.GrabData.Offset,
									},
								},
							} :: types.GrabData
						)
					)

					VFXService:StartEffect(Players:GetPlayers(), "Animation", self.Caster, {
						Animation = Anims["GrabThrow"],
						Speed = seq.Speed,
					})

					VFXService:StartEffect(
						Players:GetPlayers(),
						"Animation",
						self.Target.instance,
						{
							Animation = Anims["GrabThrowVictim"],
							Speed = seq.Speed,
						}
					)

					VFXService:StartEffect(
						Players:GetPlayers(),
						"Sound",
						RootPart,
						Sounds["Grabbed"]
					)
				end,
			},

			{
				self.GrabData.FinalFrame - 5,
				function(seq)
					seq.Cleaner:Remove("GrabObject")
				end,
			},

			{
				self.GrabData.FinalFrame,
				function(seq: Sequencer.Sequencer)
					CombatService:Attack({
						Attacker = character,
						Victim = self.Target,
						Info = self.ThrowInfo,
					})
				end,
			},
		},
	}))

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					local Anims = self.Assets.Animations
					local Sounds = self.Assets.Sounds

					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 12))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					table.clear(self.AlreadyHit)

					VFXService:StartEffect(Players:GetPlayers(), "Animation", self.Caster, {
						Animation = Anims["Grab"],
						Speed = seq.Speed,
					})

					VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["Grab"])
					VFXService:StartEffect(
						Players:GetPlayers(),
						"Sound",
						RootPart,
						Sounds["GrabVL"]
					)

					self.Target = nil
				end,
			},

			{
				30,
				function(seq)
					local Targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = AttackInfo.Hitbox,
					})

					for _, Target in Targets do
						if self.Target then break end
						if table.find(self.AlreadyHit, Target) then continue end

						table.insert(self.AlreadyHit, Target)

						CombatService:Attack({
							Attacker = character,
							Victim = Target,
							Info = AttackInfo,
						}):andThen(function(Data: types.AttackData)
							if
								Data.State.Success
								and Data.State.Continue
								and not self.GrabSequence:IsPlaying()
							then
								self.Target = Target

								self.GrabSequence:Play()
								seq:Stop()
							end
						end)
					end
				end,
				32,
			},

			{ 40 },
		},
	}))
end

function Skill.Activate(self)
	local StandService = Crane:GetService("StandService")

	local stand = StandService:GetStand(self.Character) :: types.Stand
	local isStandActive = if stand then stand:IsActive() else false

	self.Assets = isStandActive and self.Spec.Data.Assets.Stand or self.Spec.Data.Assets
	self.Caster = isStandActive and stand.instance or self.Character.instance

	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end

	if self.GrabSequence and self.GrabSequence:IsPlaying() then self.GrabSequence:Await() end
end

function Skill.Interrupt(self)
	local character = self.Character
	local RootPart = character.RootPart

	local VFXService = Crane:GetService("VFXService")

	local Anims = self.Assets.Animations

	if self.Sequence then self.Sequence:Stop() end

	if self.GrabSequence then self.GrabSequence:Stop() end

	VFXService:StopEffect(Players:GetPlayers(), "Animation", self.Caster, {
		Animation = Anims["Grab"],
	})

	--VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds[self.GrabData.Prefix.."Grab"])
	--VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds[self.GrabData.Prefix.."GrabVL"])
end

return Skill
