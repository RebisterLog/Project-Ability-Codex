const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Grab",
	Cooldown = 1,

	SkillCharacters = {
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
	const character = self.Character
	const RootPart = character.RootPart
	const Humanoid = character.Humanoid

	const AttackInfo = self.Data.AttackInfo
	const ThrowInfo = table.clone(self.Data.Throw)
	ThrowInfo.Stun = table.clone(self.Data.Throw.Stun)

	const VFXService = Crane:GetService("VFXService")
	const CombatService = Crane:GetService("CombatService")
	const StandService = Crane:GetService("StandService")

	const stand = StandService:GetStand(self.Character) :: types.Stand
	const isStandActive = if stand then stand:IsActive() else false

	-- if stand exists - it will use stand's Assets
	self.AssetPrefix = if isStandActive then "Stand/" else ""
	self.Caster = isStandActive and stand.instance or self.Character.instance

	self.GrabData = {
		Offset = self:TryGetAsset("Stats/Grab/AnimationOffset")
			or CFrame.new(0, 0, -4) * CFrame.Angles(0, 180, 0),
		FinalFrame = self:TryGetAsset("Stats/Grab/FinalFrame") or 30,
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
					local assetPrefix = self.AssetPrefix or ""

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

					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = self.Caster,
						Animation = self:GetAsset(assetPrefix .. "Animations/GrabThrow"),
						Speed = seq.Speed,
					})

					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = self.Target.instance,
						Animation = self:GetAsset(assetPrefix .. "Animations/GrabThrowVictim"),
						Speed = seq.Speed,
					})

					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = RootPart,
						Sound = self:GetAsset(assetPrefix .. "Sounds/Grabbed"),
					})
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
					local assetPrefix = self.AssetPrefix or ""

					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 12))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					table.clear(self.AlreadyHit)

					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = self.Caster,
						Animation = self:GetAsset(assetPrefix .. "Animations/Grab"),
						Speed = seq.Speed,
					})

					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = RootPart,
						Sound = self:GetAsset(assetPrefix .. "Sounds/Grab"),
					})
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = RootPart,
						Sound = self:GetAsset(assetPrefix .. "Sounds/GrabVL"),
					})

					self.Target = nil
				end,
			},

			{
				30,
				function(seq)
					const Targets = CombatService:Hitbox({
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
	const StandService = Crane:GetService("StandService")

	const stand = StandService:GetStand(self.Character) :: types.Stand
	const isStandActive = if stand then stand:IsActive() else false

	self.AssetPrefix = isStandActive and "Stand/" or ""
	self.Caster = isStandActive and stand.instance or self.Character.instance

	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end

	if self.GrabSequence and self.GrabSequence:IsPlaying() then self.GrabSequence:Await() end
end

function Skill.Interrupt(self)
	const character = self.Character
	const RootPart = character.RootPart

	const VFXService = Crane:GetService("VFXService")

	local assetPrefix = self.AssetPrefix or ""

	if self.Sequence then self.Sequence:Stop() end

	if self.GrabSequence then self.GrabSequence:Stop() end

	VFXService:StopEffect(Players:GetPlayers(), "Animation", {
		Character = self.Caster,
		Animation = self:GetAsset(assetPrefix .. "Animations/Grab"),
	})

	--VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds[self.GrabData.Prefix.."Grab"])
	--VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds[self.GrabData.Prefix.."GrabVL"])
end

return Skill
