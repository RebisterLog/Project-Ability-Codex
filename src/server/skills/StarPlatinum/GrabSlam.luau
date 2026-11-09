const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Grab Slam",
	Cooldown = 12,
	Tag = "OnlyForStand",

	SkillCharacters = { "Hit", "Grab", "IgnoreBlock", "Ragdoll", "ComboEnder" },

	AttackInfo = {
		Hitbox = {
			Size = Vector3.new(7, 7, 7),
			Offset = CFrame.new(0, 0, -3),
			SortByDistance = true,
			Debug = true,
		},

		Damage = 15,

		Block = {
			BlockIgnore = true,
			BlockCancel = true,
		},
	},

	ReleaseInfo = {
		Priority = Enums.IFrames.True,

		Ragdoll = {
			Duration = Enums.Ragdoll.Medium,
		},

		Knockback = {
			RelativePart = "Attacker",
			Duration = 0.25,
			Velocity = Vector3.new(0, 20, 0),
			Speed = 40,
		},
	},

	-- when grabbed:
	-- 20 frame - 10 damage
	-- from 20 to 30 frame - 0.5 damage per frame
	-- 72 frame - knockback + ragdoll
	-- 100 end
}

function Skill.onInit(self)
	const character = self.Character
	const VFXService = Crane:GetService("VFXService")
	const CombatService = Crane:GetService("CombatService")

	const AttackInfo = self.Data.AttackInfo
	const ReleaseInfo = self.Data.ReleaseInfo

	self.AlreadyHit = {}
	self.Target = nil

	self.GrabSequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Validator = function()
			return self.Target ~= nil
				and self.Target.instance.Parent ~= nil
				and self.Target.Humanoid.Health > 0
				and self.Stand.instance.Parent ~= nil
		end,
		Frames = {
			{
				0,
				function(seq: Sequencer.Sequencer)
					const target = self.Target
					self.Stand:WeldToPoint(self.Stand.RootPart.CFrame)

					seq.Cleaner:Add(function()
						if self.Stand.instance.Parent and character.instance.Parent then
							self.Stand:WeldToOwner()
						end
					end)

					seq.Cleaner:Set(
						"GrabObject",
						CombatService:CreateGrab(character, target, {
							Victim = {
								Bind = {
									Part0 = self.Stand.RootPart,
									Part1 = target.RootPart,
								},
							},
						})
					)

					local grabSlamAnim = self:GetAsset("Stand/Animations/GrabSlam")
					local grabSlamVictimAnim = self:GetAsset("Stand/Animations/GrabSlamVictim")
					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = self.Stand.instance,
						Animation = grabSlamAnim,
						Speed = seq.Speed,
					})
					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = target.instance,
						Animation = grabSlamVictimAnim,
						Speed = seq.Speed,
					})
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = self.Stand.RootPart,
						Sound = self:GetAsset("Stand/Sounds/GrabSlam"),
					})

					seq.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "Animation", {
							Character = self.Stand.instance,
							Animation = grabSlamAnim.Animation,
						})
						VFXService:StopEffect(Players:GetPlayers(), "Animation", {
							Character = target.instance,
							Animation = grabSlamVictimAnim.Animation,
						})
						self.Target = nil
					end)
				end,
			},
			{
				20,
				function(_, frame)
					if frame > 30 then return end

					CombatService:Attack({
						Attacker = character,
						Victim = self.Target,
						Info = {
							Priority = Enums.IFrames.True,
							Damage = if frame == 20 then 10 else 0.5,
						},
					})
				end,
				30,
			},
			{
				72,
				function(seq)
					seq.Cleaner:Remove("GrabObject")
					CombatService:Attack({
						Attacker = character,
						Victim = self.Target,
						Info = ReleaseInfo,
					})
				end,
			},
			{ 100 },
		},
	}))

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Slowed))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))
					table.clear(self.AlreadyHit)
					self.Target = nil

					local grabSlamStartAnim = self:GetAsset("Stand/Animations/GrabSlamStart")
					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = self.Stand.instance,
						Animation = grabSlamStartAnim,
						Speed = seq.Speed,
					})
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = self.Stand.RootPart,
						Sound = self:GetAsset("Stand/Sounds/GrabSlamStart"),
					})

					seq.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "Animation", {
							Character = self.Stand.instance,
							Animation = grabSlamStartAnim.Animation,
						})
					end)
				end,
			},
			{
				40,
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
								not Data.State.Success
								or not Data.State.Continue
								or self.Target
								or not seq:IsPlaying()
							then
								return
							end

							self.Target = Target
							self.GrabSequence:Play()
							seq:Stop()
						end)
					end
				end,
				45,
			},
			{ 60 },
		},
	}))
end

function Skill.Activate(self)
	self.Stand = Crane:GetService("StandService"):GetStand(self.Character)

	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end

	if self.GrabSequence:IsPlaying() then self.GrabSequence:Await() end
end

function Skill.Interrupt(self)
	const VFXService = Crane:GetService("VFXService")

	if self.Sequence then self.Sequence:Stop() end
	if self.GrabSequence then self.GrabSequence:Stop() end

	VFXService:StopEffect(Players:GetPlayers(), "Sound", {
		Origin = self.Stand.RootPart,
		Sound = self:GetAsset("Stand/Sounds/GrabSlamStart").Sound,
	})
	VFXService:StopEffect(Players:GetPlayers(), "Sound", {
		Origin = self.Stand.RootPart,
		Sound = self:GetAsset("Stand/Sounds/GrabSlam").Sound,
	})
end

return Skill
