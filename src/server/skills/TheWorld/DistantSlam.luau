--[=[
	Distant Slam

	Telegraphs and then lands a remote kick on the nearest fully marked enemy.
	The stand is welded to the victim's root; the caster stays put and is slowed
	until both sequences finish. No time stop is involved.

	ASSETS:
	Animations
	   Animations/DistantSlamCast, Stand/Animations/DistantSlam
	Sounds
	   Sounds/DistantSlamCast, Stand/Sounds/DistantSlam
	Models
	   Models/DistantSlamWarning : warning ParticleEmitter on the stand
]=]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const types = require(ServerScriptService.server.types)

const PERFECT_BLOCK = {
	Blockable = true,
	PerfectBlockable = true,
	BlockBreak = false,
	BlockCancel = false,
	BlockIgnore = false,
} :: any

const IGNORE_BLOCK = {
	Blockable = false,
	PerfectBlockable = false,
	BlockBreak = false,
	BlockCancel = false,
	BlockIgnore = true,
} :: any

const Skill: types.SkillData = {
	DisplayName = "Distant Slam",
	Cooldown = 0, -- set manually only after a marked target is found
	Tag = "OnlyForStand",
	SearchRadius = 25,

	SkillCharacters = { "Hit", "Blockable", "PerfectBlock", "Ragdoll" },

	AttackInfo = {
		Damage = 25,
		Block = IGNORE_BLOCK,
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
	const stats = self.Spec.Data.Assets.Stats.DistantSlam

	self.Sequence2 = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				stats.HitFrame,
				function()
					const target = self.Target
					if not target or target.Humanoid.Health <= 0 then return end

					const info = table.clone(self.Data.AttackInfo)
					const block = target.Block
					const isPerfect = block and block.Blocking == true
						and (os.clock() - (block.PerfectBlockTime or 0)) <= (block.PerfectBlockWindow or 0)
					info.Block = if isPerfect then PERFECT_BLOCK else IGNORE_BLOCK
					info.Knockback = table.clone(self.Data.AttackInfo.Knockback)
					info.Knockback.Direction = {
						Mode = "Custom",
						Vector = target.RootPart.CFrame.LookVector,
					}

					const hit = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = {
							Size = Vector3.new(5, 5, 5),
							Origin = CFrame.new(target.RootPart.Position),
						},
					})

					var landed = false
					for _, candidate in hit do
						if candidate ~= target then continue end
						CombatService:Attack({
							Attacker = character,
							Victim = target,
							Info = info,
						})
						landed = true
					end
					if not landed then return end
					self:ClearAllMarks()
				end,
			},
			{ 35 },
		},
	}))
	self.Sequence2.Cleaner:Add(function()
		if self.CastCleaner then
			self.CastCleaner:Destroy()
			self.CastCleaner = nil
		end
	end)

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					const target = self.Target
					const stand = Crane:GetService("StandService"):GetStand(character) :: types.Stand
					if not target or not stand then return end

					self.CastCleaner = self.Cleaner:Add(Crane.Buttler.new())
					self.CastCleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Medium))
					self.CastCleaner:Add(character:AddParameter("MaxJumpPower", 0))

					stand:WeldTo(target.RootPart)
					self.CastCleaner:Add(function()
						stand:WeldToOwner()
						if not character.Player then
							pcall(function()
								stand:HandleMovement()
							end)
						end
					end)

					self.WarningUUID = os.clock()
					VFXService:StartEffect(Players:GetPlayers(), "DistantSlamWarning", {
						UUID = self.WarningUUID,
						Caster = character.instance,
						Target = target.instance,
						Stand = stand.instance,
						Duration = stats.WarningDuration,
					})
					self.CastCleaner:Add(function()
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
				stats.StandAnimationFrames,
				function()
					if self.Sequence2 then
						self.Sequence2:Play()
						self.Sequence2:Await()
					end
				end,
			},

			{ stats.StandAnimationFrames + 5 },
		},
	}))

	function self:ClearAllMarks()
		const skill = character.Spec and character.Spec.Skills.MarkedKnives
		if skill and skill.Marks then
			for target, _ in skill.Marks do
				skill:ClearMark(target)
			end
		end
	end
end

function Skill:FindTarget(): types.Character?
	const marks = self.Character.Spec and self.Character.Spec.Skills.MarkedKnives
	if not marks or not marks.Marks then return nil end

	const now = workspace:GetServerTimeNow()
	let nearest: types.Character? = nil
	let best = self.Data.SearchRadius :: number

	for target, entry in marks.Marks do
		if entry.Count < 3 or entry.ExpiresAt <= now then continue end
		const dist = (target.RootPart.Position - self.Character.RootPart.Position).Magnitude
		if dist < best then
			best = dist
			nearest = target
		end
	end
	return nearest
end

function Skill:Activate()
	const marks = self.Character.Spec and self.Character.Spec.Skills.MarkedKnives
	if not marks or not marks.Marks or next(marks.Marks) == nil then return end

	const target = self:FindTarget()
	if not target then
		self:SetCooldown(20)
		self:ClearAllMarks()
		return
	end

	self:SetCooldown(20)
	self.Target = target

	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
	if self.Sequence2 then self.Sequence2:Await() end
end

function Skill:Interrupt()
	if self.Sequence then self.Sequence:Stop() end
	if self.Sequence2 then self.Sequence2:Stop() end
	if self.CastCleaner then
		self.CastCleaner:Destroy()
		self.CastCleaner = nil
	end
end

return Skill
