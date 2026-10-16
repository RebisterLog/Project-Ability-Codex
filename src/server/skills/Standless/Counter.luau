--!native
--!optimize 2

--[=[ Counter

   Parry window that negates an incoming hit and throws the attacker back.
   Plays a short taunt with a limited counter window, the first attack that
   lands during that window is fully ignored (damage, stun, knockback, ragdoll)
   and the attacker gets interrupted and counter-hit.

   The counter window is intentionally vulnerable - there is no hyper armor
   while the taunt is playing, missing the window means eating the hit.


   ASSETS:

   Animations
      Counter : Animation for the counter window taunt
      CounterHit : Animation for the counter throw
      EnemyCounter : Animation played on the countered attacker

   Sounds
      CounterVoice : Voice line played when the window opens
      CounterHit : Sound played when the counter throw connects

   Stats
      Counter : Tuning for the counter (CFrame, number)
         AnimationOffset : Offset the countered attacker is bound to
         StartHitFrame : Frame the grab is released and the throw damage lands
         FinalFrame : Last frame of the counter throw
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Enums = require(ServerScriptService.server.Enums)
local Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
local types = require(ServerScriptService.server.types)

local Skill: types.SkillData = {
	DisplayName = "Counter",
	Cooldown = 6,

	SkillCharacters = {
		"Counter",
		"Defense",
		"IgnoreBlock",
		"BlockBreaker",
		"ComboStarter",
	},

	-- how long (in frames) incoming hits can still be countered
	CounterWindow = 45,

	-- vulnerable frames after the window closed
	EndLag = 30,

	-- the throw that lands on the countered attacker
	CounterInfo = {
		Priority = Enums.IFrames.Ragdoll,

		Damage = 15,

		Block = {
			BlockIgnore = true,
			PerfectBlockable = false,
		},

		Knockback = {
			RelativePart = "Attacker",
			Speed = 40,
			Duration = 0.1,
			Velocity = Vector3.new(0, 50, 0),
		},

		Ragdoll = {
			Duration = 2,
		},

		Stun = {
			Priority = Enums.Stun.Heavy,
			Duration = 1.5,
		},
	},
}

function Skill:onInit()
	local character = self.Character :: types.Character
	local RootPart = character.RootPart
	local VFXService = Crane:GetService("VFXService")
	local CombatService = Crane:GetService("CombatService")

	local Anims = self.Spec.Data.Assets.Animations
	local Sounds = self.Spec.Data.Assets.Sounds
	local CounterStats = (self.Spec.Data.Assets.Stats or {}).Counter or {}

	self.CounterData = {
		Offset = CounterStats["AnimationOffset"]
			or CFrame.new(0, 0, -4) * CFrame.Angles(0, math.pi, 0),
		StartHitFrame = CounterStats["StartHitFrame"] or 30,
		FinalFrame = CounterStats["FinalFrame"] or 45,
	}

	self.Countered = false
	self.CanCounter = false
	self.Target = nil :: types.Character?

	self.CounterSequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Validate = function()
			local target = self.Target
			if not target or not target.instance.Parent then return false end

			return true
		end,

		Frames = {
			{
				0,
				function(seq: Sequencer.Sequencer)
					local target = self.Target
					if not target then return end

					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 0))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
						Animation = Anims["CounterHit"],
						Speed = seq.Speed,
					})

					VFXService:StartEffect(Players:GetPlayers(), "Animation", target.instance, {
						Animation = Anims["EnemyCounter"],
						Speed = seq.Speed,
					})

					VFXService:StartEffect(
						Players:GetPlayers(),
						"Sound",
						RootPart,
						Sounds["CounterHit"]
					)

					seq.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, {
							Animation = Anims["CounterHit"].Animation,
						})
					end)

					seq.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "Animation", target.instance, {
							Animation = Anims["EnemyCounter"].Animation,
						})
					end)

-- 					CombatService:Attack({
-- 						Attacker = character,
-- 						Victim = self.Target,
-- 						Info = {
-- 							Block = {
-- 								PerfectBlockable = false,
-- 							},
-- 
-- 							Stun = {
-- 								Priority = Enums.Stun.Heavy,
-- 								Duration = 2,
-- 							},
-- 						},
-- 					})

					seq.Cleaner:Set(
						"GrabObject",
						CombatService:CreateGrab(character, target, {
							Attacker = {},
							Victim = {
								Bind = {
									Part0 = RootPart,
									Part1 = target.RootPart,
									Offset = self.CounterData.Offset,
								},
							},
						} :: types.GrabData)
					)
				end,
			},

			{
				self.CounterData.StartHitFrame,
				function(seq)
					local target = self.Target
					if not target then return end

					seq.Cleaner:Remove("GrabObject")

					CombatService:Attack({
						Attacker = character,
						Victim = target,
						Info = self.Data.CounterInfo,
					})
				end,
			},

			{ self.CounterData.FinalFrame },
		},
	}))

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 0))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					self.Countered = false
					self.CanCounter = true
					self.Target = nil

					VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
						Animation = Anims["Counter"],
						Speed = seq.Speed,
					})

					VFXService:StartEffect(
						Players:GetPlayers(),
						"Sound",
						RootPart,
						Sounds["CounterVoice"]
					)

					seq.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, {
							Animation = Anims["Counter"].Animation,
						})
					end)

					seq.Cleaner:Add(
						CombatService.Attacked:Connect(function(Type: string, Data: types.AttackData)
							if Type ~= "Precast" or Data.Victim ~= character then return end
							if not self.CanCounter or self.Countered then return end
							if Data.Attacker == character then return end

							self.Countered = true
							self.CanCounter = false

							-- ignores the incoming hit entirely:
							-- Info is shared between Precast and Cast, so clearing it here
							-- prevents damage, stun, knockback, ragdoll and angular from applying
							Data.Info.Damage = nil
							Data.Info.Stun = nil
							Data.Info.Ragdoll = nil
							Data.Info.Knockback = nil
							Data.Info.Angular = nil

							Data.State.Success = false
							Data.State.Continue = false

							-- stops the attacker's current skill and drops their hyper armor
							CombatService.Interrupted:Fire(Data.Attacker)

							for _, armor in table.clone(Data.Attacker.Parameters.Armor.Objects) do
								armor:Destroy()
							end

							self.Target = Data.Attacker

							self.CounterSequence:Play()
							seq:Stop()
						end)
					)
				end,
			},

			{
				150,
				function()
					self.CanCounter = false
					if self.Countered then return end

					VFXService:StartEffect(Players:GetPlayers(), "Highlight", character.instance, {
						FillColor = Color3.fromRGB(255, 60, 60),
						OutlineColor = Color3.fromRGB(255, 60, 60),
						FillTransparency = 0.5,
						OutlineTransparency = 0,
						Lifetime = 1,
						Tween = true,
					})
				end,
			},

			{ 150 + 60 },
		},
	}))
end

function Skill:Activate()
	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end

	if self.CounterSequence and self.CounterSequence:IsPlaying() then
		self.CounterSequence:Await()
	end
end

-- function Skill:Interrupt()
-- 	local VFXService = Crane:GetService("VFXService")
-- 
-- 	local Anims = self.Spec.Data.Assets.Animations
-- 
-- 	if self.Sequence then self.Sequence:Stop() end
-- 	if self.CounterSequence then self.CounterSequence:Stop() end
-- 
-- 	self.CanCounter = false
-- 	self.Countered = true
-- 
-- 	VFXService:StopEffect(Players:GetPlayers(), "Animation", self.Character.instance, {
-- 		Animation = Anims["Counter"].Animation,
-- 	})
-- 
-- 	VFXService:StopEffect(Players:GetPlayers(), "Animation", self.Character.instance, {
-- 		Animation = Anims["CounterHit"].Animation,
-- 	})
-- 
-- 	local target = self.Target
-- 	if target then
-- 		VFXService:StopEffect(Players:GetPlayers(), "Animation", target.instance, {
-- 			Animation = Anims["EnemyCounter"].Animation,
-- 		})
-- 	end
-- end

return Skill