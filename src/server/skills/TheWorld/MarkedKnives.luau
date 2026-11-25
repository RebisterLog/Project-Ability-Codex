--[=[
	Marked Knives

	Three knives fly to a fixed world point supplied by the client's AimPoint.
	Each landed knife deals 2.5 and adds 1/3 of a personal mark that lasts 5 s.
	Uses the shared Ammo pool (3 charges, +1 every 5 s).

	ASSETS:
	Animations
	   Animations/MarkedKnives, Stand/Animations/MarkedKnives
	Sounds
	   Sounds/MarkedKnivesThrow, Sounds/MarkedKnivesHit
	Models
	   Models/Knife (with its Trail), Models/MarkIndicator
]=]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Projectile = require(ServerScriptService.server["combat-classes"].Projectile)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Marked Knives",
	Cooldown = 0, -- real cooldown starts from spending a charge, see Activate
	AimRequired = true,
	AmmoId = "MarkedKnives",
	UseCooldown = 3,
	MarkDuration = 5,

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
		HitEffects = { { Particle = "Default", Sound = "Default" } },
	} :: types.AttackInfo,

	ProjectileData = {
		Offsets = {
			CFrame.new(-1.5, 0, -2),
			CFrame.new(0, 0, -2),
			CFrame.new(1.5, 0, -2),
		},
		Speed = 150,
		Lifetime = 2,
		MaxDistance = 120,
		HitboxSize = 2,
	},
}

function Skill:onInit()
	const character = self.Character :: types.Character
	const CombatService = Crane:GetService("CombatService")
	const VFXService = Crane:GetService("VFXService")
	const stats = self.Spec.Data.Assets.Stats.MarkedKnives

	self.Marks = {}
	self.MarkUUIDs = {}
	self.MarkTimers = {}

	function self:ClearMark(target: types.Character)
		self.Marks[target] = nil
		const uuid = self.MarkUUIDs[target]
		if uuid then
			VFXService:StopEffect(Players:GetPlayers(), "MarkIndicator", { UUID = uuid })
			self.MarkUUIDs[target] = nil
		end
		const timer = self.MarkTimers[target]
		if timer then task.cancel(timer) end
		self.MarkTimers[target] = nil
	end

	function self:AddMark(target: types.Character)
		const entry = self.Marks[target] or { Count = 0, ExpiresAt = 0 }
		entry.Count = math.min(3, entry.Count + 1)
		entry.ExpiresAt = workspace:GetServerTimeNow() + self.Data.MarkDuration
		self.Marks[target] = entry

		if not self.MarkUUIDs[target] then
			self.MarkUUIDs[target] = tostring(os.clock()) .. target.instance.Name
		end
		VFXService:StartEffect(Players:GetPlayers(), "MarkIndicator", {
			UUID = self.MarkUUIDs[target],
			Character = target.instance,
			Count = entry.Count,
		})

		const timer = self.MarkTimers[target]
		if timer then task.cancel(timer) end
		self.MarkTimers[target] = task.delay(self.Data.MarkDuration, function()
			self:ClearMark(target)
		end)
		self.Cleaner:Add(target.Humanoid.Died:Once(function()
			self:ClearMark(target)
		end))
	end

	const Shoot = function(index: number, aimPoint: Vector3)
		const offset = self.Data.ProjectileData.Offsets[index]
		const muzzle = character.RootPart.CFrame * offset
		const direction = aimPoint - muzzle.Position
		if direction.Magnitude < 0.001 then return end

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
		})
		self.Cleaner:Add(knife)

		knife.Hit:Connect(function(target: types.Character)
			CombatService:Attack({
				Attacker = character,
				Victim = target,
				Info = self.Data.AttackInfo,
			}):andThen(function(data)
				if data.State.Success then self:AddMark(target) end
			end)
		end)
		knife:Start()
	end

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

					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Slowed))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = self.Caster,
						Animation = self:GetAsset(self.AssetPrefix .. "Animations/MarkedKnives"),
						Speed = seq.Speed,
					})
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = character.RootPart,
						Sound = self:GetAsset("Sounds/MarkedKnivesThrow"),
					})
					seq.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "Animation", {
							Character = self.Caster,
							Animation = self:GetAsset(
								self.AssetPrefix .. "Animations/MarkedKnives"
							).Animation,
						})
					end)
				end,
			},

			{
				stats.SpawnFrames[1],
				function()
					self:Shoot(1, self.AimPoint)
				end,
			},
			{
				stats.SpawnFrames[2],
				function()
					self:Shoot(2, self.AimPoint)
				end,
			},
			{
				stats.SpawnFrames[3],
				function()
					self:Shoot(3, self.AimPoint)
				end,
			},

			{ stats.EndFrame },
		},
	}))

	function self:Shoot(index: number, aimPoint: Vector3)
		Shoot(index, aimPoint)
	end
end

function Skill:Activate(aimPoint: Vector3?)
	const CombatService = Crane:GetService("CombatService")
	if not CombatService:ConsumeAmmo(self.Character, self.Data.AmmoId) then return end
	self:SetCooldown(self.Data.UseCooldown)

	self.AimPoint = aimPoint
		or self.Character.RootPart.CFrame.Position
			+ self.Character.RootPart.CFrame.LookVector * self.Data.ProjectileData.MaxDistance

	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
end

function Skill:Interrupt()
	const VFXService = Crane:GetService("VFXService")
	if self.Sequence then self.Sequence:Stop() end
	if self.Caster then
		VFXService:StopEffect(Players:GetPlayers(), "Animation", {
			Character = self.Caster,
			Animation = self:GetAsset(self.AssetPrefix .. "Animations/MarkedKnives").Animation,
		})
	end
end

return Skill
