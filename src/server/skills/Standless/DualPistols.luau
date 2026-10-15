--!native
--!optimize 2

--[=[ DualPistols

   Reloads a pair of pistols and fires two rounds down the user's facing.

   Ported from the old rbxts implementation. The old skill fired on an
   animation "Hit" marker; the new engine drives everything from sequencer
   frames instead, so the shot frames are exposed through the skin Stats and
   tuned per skin.

   Each round is a `Projectile` (combat-classes/Projectile), which owns the
   travel, the swept surface test and the hitbox query. This skill only reports
   hits through `bullet.Hit` and applies damage via `CombatService:Attack`.


   ASSETS:

   Animations
      DualPistols : Animation for the reload and two shots

   Sounds
      DualPistolsVoice : Voice line played when the skill starts
      DualPistolsReload : Sound of reloading the pistols
      DualPistolsShot : Sound played on every shot

   Models
      LeftPistol : (Model) Weapon welded to the left arm
      RightPistol : (Model) Weapon welded to the right arm
      Bullet : (Model) Travelling round, carries its own trail and particles
      PistolShotEffectPart : (BasePart) Muzzle flash emitted at the barrel
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Enums = require(ServerScriptService.server.Enums)
local Projectile = require(ServerScriptService.server["combat-classes"].Projectile)
local types = require(ServerScriptService.server.types)

local Skill: types.SkillData = {
	DisplayName = "Dual Pistols",
	Cooldown = 4,

	SkillCharacters = {
		"Projectile",
		"Hit",
		"IgnoreBlock"
	},

	AttackInfo = {
		Damage = 15,

		Block = {
			Blockable = false,
			PerfectBlockable = false,
			BlockBreak = false,
			BlockCancel = false,
			BlockIgnore = true,
		},

		Stun = {
			Priority = Enums.Stun.Light,
			Duration = 0.5,
		},

		-- Knockback = {
		-- 	RelativePart = "Attacker",
		-- 	Duration = 0.1,
		-- 	Velocity = Vector3.new(0, 30, 0),
		-- 	Speed = 40,
		-- },
	},

	-- Handed straight to `Projectile.new`. See combat-classes/Projectile.
	ProjectileData = {
		-- Offset from the RootPart the round spawns and travels along.
		Offset = CFrame.new(0, 0, -3),
		Speed = 120,
		LifeTime = 2,
		Distance = 120,
		HitboxSize = 5,
		-- One round, one target, matching the old `soloTarget` flag.
		CanPierce = false,
	},

	-- Caps applied while the pistols are out.
	OwnerSlowdown = {
		WalkSpeed = 8,
		JumpPower = 0,
	},

	-- Seconds the dropped pistols stay in the world.
	DebrisLifeTime = 5,

	-- The old skill fired on an animation "Hit" marker, which the new engine
	-- cannot read, so the shots are placed on explicit frames instead.
	-- One round per frame.
	ShotFrames = { 60, 90, 110, 111 },

	-- Last frame of the animation.
	TotalFrames = 120,
}

function Skill:onInit()
	local character = self.Character :: types.Character
	local RootPart = character.RootPart

	local VFXService = Crane:GetService("VFXService")
	local CombatService = Crane:GetService("CombatService")

	local Anims = self.Spec.Data.Assets.Animations
	local Sounds = self.Spec.Data.Assets.Sounds
	local Models = self.Spec.Data.Assets.Models
	local AttackInfo = self.Data.AttackInfo

	local ProjectileData = self.Data.ProjectileData
	local Slowdown = self.Data.OwnerSlowdown

	local DebrisLifeTime = self.Data.DebrisLifeTime
	local ShotFrames = self.Data.ShotFrames
	local TotalFrames = self.Data.TotalFrames

	-- Weapons currently mounted on the arms, so cleanup can drop them as debris.
	self.Equipped = {} :: { { Weapon: Model, Handle: BasePart } }

	-- Mounts a handle on the arm through a Motor6D so the weapon follows the
	-- animation, then welds the weapon onto that handle. Ported from the old
	-- `makeHandlePart` / `weldPistolToHandle` pair.
	local function EquipPistol(armName: string, weapon: Model?)
		local arm = character.instance:FindFirstChild(armName)
		if not arm or not arm:IsA("BasePart") or not weapon then
			return
		end

		local motor = Instance.new("Motor6D")
		motor.Part0 = arm
		motor.C0 = CFrame.new(0, -1.2, 0) * CFrame.fromOrientation(math.rad(-90), 0, 0)

		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Anchored = false
		handle.CanCollide = false
		handle.CanTouch = false
		handle.CanQuery = false
		handle.Transparency = 1
		handle.Size = Vector3.new(0.5, 0.5, 0.5)
		handle.Parent = arm

		motor.Part1 = handle
		motor.Parent = handle

		local weld = Instance.new("Weld")
		weld.Part0 = weapon.PrimaryPart
		weld.Part1 = handle
		weld.Parent = handle

		-- Parent last. An unparented Model is not in the DataModel, so it neither
		-- replicates nor renders. Parenting after the weld means clients never
		-- receive a half-assembled weapon.
		weapon.Parent = character.instance

		table.insert(self.Equipped, { Weapon = weapon, Handle = handle })
	end

	-- The old skill dropped the pistols into the world as physical props when
	-- the skill ended. The parts are captured up front because re-parenting
	-- empties the model.
	local function DropDebris(weapon: Model)
		local parts = {}

		for _, child in weapon:GetChildren() do
			if not child:IsA("BasePart") then
				continue
			end

			table.insert(parts, child)
			child.CanCollide = true
			child.Parent = Workspace
		end

		if #parts == 0 then
			return
		end

		local Debris = Crane.Buttler.new()

		Debris:Delay(DebrisLifeTime, function()
			for _, part in parts do
				if part.Parent then
					part:Destroy()
				end
			end

			Debris:Clean()
		end)
	end

	local function Shoot()
		local muzzle = RootPart.CFrame * ProjectileData.Offset

		local bullet = Projectile.new({
			Caster = character,
			Skill = self,
			Model = Models["Bullet"],
			Position = muzzle.Position,
			Direction = muzzle.LookVector,
			Speed = ProjectileData.Speed,
			HitboxSize = ProjectileData.HitboxSize,
			Lifetime = ProjectileData.LifeTime,
			MaxDistance = ProjectileData.Distance,
			CanPierce = ProjectileData.CanPierce,
		})

		-- Tracked by the skill, so interrupt / spec removal cleans it up for free.
		self.Cleaner:Add(bullet)

		bullet.Hit:Connect(function(target: types.Character)
			CombatService:Attack({
				Attacker = character,
				Victim = target,
				Info = AttackInfo,
			})
		end)

		bullet:Start()

		VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
			Particle = Models["PistolShotEffectPart"],
			Origin = muzzle,
			UseForge = true,
		})

		VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["DualPistolsShot"])
	end

	-- The last entry has to be the highest frame: the sequencer treats it as the
	-- terminator, so the shot frames are inserted in ascending order before it.
	local Frames: { any } = {
		{
			0,
			function(seq)
				table.clear(self.Equipped)

				local left = Models["LeftPistol"]
				local right = Models["RightPistol"]

				EquipPistol("Left Arm", left and left:Clone())
				EquipPistol("Right Arm", right and right:Clone())

				seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Slowdown.WalkSpeed))
				seq.Cleaner:Add(character:AddParameter("MaxJumpPower", Slowdown.JumpPower))

				VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
					Animation = Anims["DualPistols"],
					Speed = seq.Speed,
				})

				VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["DualPistolsVoice"])

				VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["DualPistolsReload"])

				-- Runs on both a clean finish and an interrupt, so the pistols end
				-- up on the floor exactly like the old `onEnd`.
				seq.Cleaner:Add(function()
					for _, equipped in self.Equipped do
						DropDebris(equipped.Weapon)
						equipped.Handle:Destroy()
					end

					table.clear(self.Equipped)

					local anim = Anims["DualPistols"]
					if not anim then
						return
					end

					VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, {
						Animation = anim.Animation,
					})
				end)
			end,
		},
	}

	for _, frame in ShotFrames do
		table.insert(Frames, {
			frame,
			function()
				Shoot()
			end,
		})
	end

	table.insert(Frames, { TotalFrames })

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = Frames,
	}))
end

function Skill:Activate()
	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
end

function Skill:Interrupt()
	local VFXService = Crane:GetService("VFXService")

	if self.Sequence then
		self.Sequence:Stop()
	end

	local anim = self.Spec.Data.Assets.Animations["DualPistols"]
	if not anim then
		return
	end

	VFXService:StopEffect(Players:GetPlayers(), "Animation", self.Character.instance, {
		Animation = anim.Animation,
	})
end

return Skill
