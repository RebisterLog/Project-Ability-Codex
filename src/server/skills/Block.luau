--[=[ Block

   Hold-to-cast guard. Press opens the stance and its perfect-block window;
   release, interruption, a broken/canceled stance or a lost character closes it.

   Every `AttackInfo.Block` guard is read independently from `AttackData.State`
   -- one hit may carry several flags at once, so none of them is consumed by an
   `elseif` chain:

      Blockable        -> State.Blocked        : absorbed hit, guard stays up
      PerfectBlockable -> State.PerfectBlocked : attacker punished, guard stays up
      BlockBreak       -> State.BlockBroken    : stance broken, guard drops
      BlockCancel      -> State.BlockCanceled  : stance dropped without a break
      BlockIgnore      -> State.BlockIgnored   : dominant, unblockable; no reaction

   `BlockIgnore` is dominant in the shared resolver, so no other block state is
   set for that hit. `Absorbed` only means damage/VFX were stripped upstream.

   ASSETS:

   Animations
      Block : Guard pose, looped for the whole hold (resolved from the spec skin).

   Global assets (ReplicatedStorage.assets.Default.Block)
      Sounds.Hit          : Played on an ordinary blocked hit.
      Sounds.PerfectBlock : Played when the attacker is parried.
      Sounds.BlockBreak   : Played when the stance is broken.
      VFX.PerfectBlock    : Particle burst on a perfect block.
      VFX.BlockBreak      : Particle burst on a stance break.

]=]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Promise = require(ReplicatedStorage.shared.packages.Promise)
const types = require(ServerScriptService.server.types)

const PERFECT_BLOCK_WINDOW = 0.25
const GUARD_WALK_SPEED = 3
const PUNISH_STUN = Enums.StunTime.Heavy
const BLOCK_VFX_OFFSET = CFrame.new(0, 0, -2)

const function openGuard(self: types.Skill)
	const guard = self.Character.Block
	guard.Blocking = true
	guard.PerfectBlockTime = os.clock()
	guard.PerfectBlockWindow = PERFECT_BLOCK_WINDOW
	guard.Changed:Fire(true)
end

const function closeGuard(self: types.Skill)
	const guard = self.Character.Block
	if not guard.Blocking then return end
	guard.Blocking = false
	guard.Changed:Fire(false)
end

const Block: types.SkillData = {
	DisplayName = "Block",
	Cooldown = 0.25,

	SkillCharacters = {
		"Defense",
	},

	-- Route the release through the class so `Holding` and `Deactivated` stay
	-- in sync; firing `Deactivated` by hand would desync both.
	Interrupt = function(self)
		self:Deactivate()
	end,

	-- A spec change or respawn destroys the skill without a key release.
	onDestroy = function(self)
		closeGuard(self)
		self:Deactivate()
	end,
}

function Block:Activate()
	const character = self.Character
	const RootPart = character.RootPart
	const VFXService = Crane:GetService("VFXService")
	const CombatService = Crane:GetService("CombatService")

	const clip = self:GetAsset("Animations/Block")
	const blockAssets = ReplicatedStorage.assets.Default.Block

	openGuard(self)

	const Collector = Crane.Buttler.new()

	-- Butler cleans LIFO: connections, particles and the animation are stopped
	-- before the guard state is dropped.
	Collector:Add(function()
		closeGuard(self)
	end)
	Collector:Add(character:AddParameter("MaxWalkSpeed", GUARD_WALK_SPEED))
	Collector:Add(character:AddParameter("MaxJumpPower", 0))

	VFXService:StartEffect(Players:GetPlayers(), "Animation", {
		Character = character.instance,
		Animation = clip,
		Speed = 1,
	})
	Collector:Add(function()
		VFXService:StopEffect(Players:GetPlayers(), "Animation", {
			Character = character.instance,
			Animation = clip.Animation,
		})
	end)

	-- One-shot particles get a UUID so a released guard cannot leave them
	-- behind; the collector stops them on every exit path.
	const function emit(particle)
		const uuid = math.random(1, 0x7FFFFFFF)
		VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
			UUID = uuid,
			Particle = particle,
			Origin = RootPart,
			Offset = BLOCK_VFX_OFFSET,
		})
		Collector:Add(function()
			VFXService:StopEffect(Players:GetPlayers(), "EmitParticle", { UUID = uuid })
		end)
	end

	const function play(sound)
		VFXService:StartEffect(Players:GetPlayers(), "Sound", {
			Origin = RootPart,
			Sound = sound,
			Volume = 1,
		})
	end

	local released = false
	const function release()
		if released then return end
		released = true
		closeGuard(self)
	end

	-- Hold-to-cast: the promise resolves on key release (Deactivated), when the
	-- stance is broken/canceled, or when the character leaves the DataModel.
	Promise.new(function(resolve)
		Collector:Add(self.Deactivated:Once(function()
			release()
			resolve()
		end))

		Collector:Add(character.instance.AncestryChanged:Connect(function()
			if character.instance.Parent then return end
			release()
			resolve()
		end))

		Collector:Add(CombatService.Attacked:Connect(function(Type, Data)
			if Type ~= "Precast" or Data.Victim ~= character then return end

			const State = Data.State

			if State.PerfectBlocked then
				const stun = Data.Attacker:AddParameter("Stun", {
					Duration = PUNISH_STUN,
					Priority = Enums.Stun.Heavy,
				})
				task.delay(PUNISH_STUN, stun.Destroy, stun)
				CombatService.Interrupted:Fire(Data.Attacker)

				emit(blockAssets.VFX.PerfectBlock)
				VFXService:StartEffect(Players:GetPlayers(), "Highlight", {
					Character = character.instance,
					FillColor = Color3.fromRGB(255, 162, 0),
					OutlineColor = Color3.fromRGB(255, 162, 0),
					FillTransparency = 0,
					OutlineTransparency = 0,
					Lifetime = 1,
					Tween = true,
				})
				play(blockAssets.Sounds.PerfectBlock)
			end

			if State.BlockBroken then
				const stun = Data.Victim:AddParameter("Stun", {
					Duration = PUNISH_STUN,
					Priority = Enums.Stun.Heavy,
				})
				task.delay(PUNISH_STUN, stun.Destroy, stun)

				emit(blockAssets.VFX.BlockBreak)
				play(blockAssets.Sounds.BlockBreak)
			end

			if State.Blocked then play(blockAssets.Sounds.Hit) end

			-- BlockIgnored and a plain absorbed hit need no guard reaction: the
			-- resolver has already cleared their payload. Only a dropped stance
			-- ends the hold.
			if State.BlockBroken or State.BlockCanceled then
				release()
				resolve()
			end
		end))
	end)
		:finallyCall(Collector.Destroy, Collector)
		:catch(warn)
		:await()

	closeGuard(self)
end

return Block
