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

local Debris = game:GetService("Debris")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Workspace = game:GetService("Workspace")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Projectile = require(ServerScriptService.server["combat-classes"].Projectile)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Dual Pistols",
	Cooldown = 15,

	SkillCharacters = {
		"Projectile",
		"Hit",
		"IgnoreBlock"
	},

	AttackInfo = {
		Damage = 2.5,

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
		Offset = CFrame.new(0, 0, -2),
		Speed = 300,
		LifeTime = 2,
		Distance = 120,
		HitboxSize = 2,
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
	ShotFrames = { 30, 60, 90, 91 },

	-- Last frame of the animation.
	TotalFrames = 120,
}

const function DropPistol(model: Model, throwVector: Vector3)
    for _, child in model:QueryDescendants("BasePart") do
        child.CollisionGroup = "NoCollision"
		child.CanCollide = true
	end

	model.Parent = Workspace.Effects

	if model.PrimaryPart then
	    model.PrimaryPart:ApplyImpulse(throwVector)
	end
end

function Skill:onInit()
	const character = self.Character :: types.Character
	const RootPart = character.RootPart

	const VFXService = Crane:GetService("VFXService")
	const CombatService = Crane:GetService("CombatService")

	const Anims = self.Spec.Data.Assets.Animations
	const Sounds = self.Spec.Data.Assets.Sounds
	const Models = self.Spec.Data.Assets.Models
	const AttackInfo = self.Data.AttackInfo

	const ProjectileData = self.Data.ProjectileData
	const Slowdown = self.Data.OwnerSlowdown

	const ShotFrames = self.Data.ShotFrames
	const TotalFrames = self.Data.TotalFrames

	const Shoot = function()
		const muzzle = RootPart.CFrame * ProjectileData.Offset

		const bullet = Projectile.new({
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
	const Frames: { any } = {
		{
			0,
			function(seq)
				const left, motorL = CombatService:Equip(character, Models["LeftPistol"])
				const right, motorR = CombatService:Equip(character, Models["RightPistol"])

				if character.Player then
				    Crane.Utils.ChangeNetworkOwner(left, character.Player)
					Crane.Utils.ChangeNetworkOwner(right, character.Player)
				end

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
    				Debris:AddItem(left, 3)
                    Debris:AddItem(right, 3)
        
				    motorL:Destroy()
					motorR:Destroy()

					DropPistol(left, -character.RootPart.CFrame.LookVector)
					DropPistol(right, -character.RootPart.CFrame.LookVector)
					
					const anim = Anims["DualPistols"]
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
	const VFXService = Crane:GetService("VFXService")

	if self.Sequence then
		self.Sequence:Stop()
	end

	const anim = self.Spec.Data.Assets.Animations["DualPistols"]
	if not anim then
		return
	end

	VFXService:StopEffect(Players:GetPlayers(), "Animation", self.Character.instance, {
		Animation = anim.Animation,
	})
end

return Skill
