--[=[
	Marked Knives

	Three knives fly to a fixed world point supplied by the client's AimPoint.
	Each landed knife deals 2.5 and adds 1/3 of a personal mark. Marks never
	expire; a full mark is consumed by Distant Slam.
	Uses the shared KnivesCharge pool (3 charges, +1 every 5 s).

	ASSETS:
	Animations
	   Animations/MarkedKnives : caster throw clip (no stand variant)
	Sounds
	   Sounds/MarkedKnivesThrow, Sounds/MarkedKnivesHit
	Models
	   Models/Knife (with its Trail), Models/MarkIndicator
]=]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Projectile = require(ServerScriptService.server["combat-classes"].Projectile)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Marked Knives",
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
		-- The aim point is clamped to 120; knives must keep flying past it.
		AimFallbackDistance = 60,
		MaxDistance = 200,
		-- A narrow box along the blade instead of a fat sphere.
		HitboxSize = Vector3.new(0.3, 0.5, 2.5),
		Debug = true,
	},
}

local function clearMark(self: types.Skill, target: types.Character)
	const VFXService = Crane:GetService("VFXService")
	self.Marks[target] = nil
	const uuid = self.MarkUUIDs[target]
	if uuid then
		VFXService:StopEffect(Players:GetPlayers(), "MarkIndicator", { UUID = uuid })
		self.MarkUUIDs[target] = nil
	end
end

local function addMark(self: types.Skill, target: types.Character)
	const VFXService = Crane:GetService("VFXService")
	-- Marks do not time out. Only a full mark consumed by Distant Slam (or
	-- the target's death) removes them.
	const entry = self.Marks[target] or { Count = 0 }
	entry.Count = math.min(3, entry.Count + 1)
	self.Marks[target] = entry

	if not self.MarkUUIDs[target] then
		self.MarkUUIDs[target] = tostring(os.clock()) .. target.instance.Name
	end
	VFXService:StartEffect(Players:GetPlayers(), "MarkIndicator", {
		UUID = self.MarkUUIDs[target],
		Character = target.instance,
		Count = entry.Count,
	})

	self.Cleaner:Add(target.Humanoid.Died:Once(function()
		clearMark(self, target)
	end))
end

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
			-- Face the travel direction so the client visual and the server
			-- hitbox/debug box share the same orientation.
			OrientToVelocity = true,
			Debug = self.Data.ProjectileData.Debug,
			-- No replicated body: the client predicts the flight from these
			-- numbers once, the server keeps only the constant hitbox path.
			VisualEffect = "ProjectileFlight",
		})
		self.Cleaner:Add(knife)

		knife.Hit:Connect(function(target: types.Character)
			CombatService:Attack({
				Attacker = character,
				Victim = target,
				Skill = self,
				Info = self.Data.AttackInfo,
			}):andThen(function(data)
				if data.State.Success then addMark(self, target) end
			end)
		end)
		knife:Start()
	end
end

function Skill:onInit()
	const character = self.Character :: types.Character
	const CombatService = Crane:GetService("CombatService")
	const VFXService = Crane:GetService("VFXService")

	self.Marks = {}
	self.MarkUUIDs = {}

	-- Shared marks table for Distant Slam: no cross-skill lookup through Spec.
	character.MarkedKnives = {
		Marks = self.Marks,
		Clear = function(target: types.Character)
			clearMark(self, target)
		end,
	}

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
