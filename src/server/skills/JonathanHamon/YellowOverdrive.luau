--[=[ YELLOW_OVERDRIVE

   Portable Hamon barrage. Needs at least 5 Hamon to start, then drains 5 per
   second (in small per-frame chunks) until the resource runs out or the
   animation reaches its last frame.

   ASSETS:

   Animations
      YellowOverdrive : Barrage clip (assets/JonathanHamon).

   Sounds
      YellowOverdrive : Barrage sound (assets/JonathanHamon).

   Models
      YellowOverdrive : Particle VFX attached to the root for the duration.

]=]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const types = require(ServerScriptService.server.types)

const MIN_HAMON = 5
const DRAIN_PER_SECOND = 5

const Skill: types.SkillData = {
	DisplayName = "Yellow Overdrive",
	UseCooldown = 10,
	BaseSpec = "JonathanHamon",
	SkillCharacters = {
		"Hit",
		"Blockable",
		"Stun",
		"ComboExtender",
	},

	AttackInfo = {
		Hitbox = {
			Size = Vector3.new(7, 7, 7),
			Offset = CFrame.new(0, 0, -3),
			Debug = true,
		},

		Damage = 0.6,

		Block = {
			Blockable = true,
			PerfectBlockable = false,
			BlockBreak = false,
			BlockCancel = false,
			BlockIgnore = false,
		},

		Stun = {
			Priority = Enums.Stun.Light,
			Duration = Enums.StunTime.Light,
		},

		Knockback = {
			Direction = { Mode = "AwayFromAttacker" },
			Push = 5,
			Hold = 0.1,
		},

		HitEffects = { {
			Particle = "Default",
			Sound = "Default",
		} },
	},
}

function Skill.onInit(self)
	const character = self.Character
	const RootPart = character.RootPart
	const VFXService = Crane:GetService("VFXService")
	const CombatService = Crane:GetService("CombatService")

	const AttackInfo = self.Data.AttackInfo

	self.LastDrain = 0
	self.VFXUUID = os.clock()
	self.VFXStarted = false

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		-- Sequencer reads `Validator` — `Validate` would be silently ignored.
		Validator = function()
			-- Stopping the sequence runs its Cleaner, which removes the clip,
			-- the sound and the particle VFX in one place.
			return CombatService:GetCharge(character, "HamonCharge") > 0
		end,

		Frames = {
			{
				0,
				function(seq)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Medium))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					const anim = self:GetAsset("Animations/YellowOverdrive")
					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = character.instance,
						Animation = anim,
						Speed = seq.Speed,
					})

					seq.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "Animation", {
							Character = character.instance,
							Animation = anim.Animation,
						})
					end)

					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = RootPart,
						Sound = self:GetAsset("Sounds/YellowOverdrive"),
					})

					-- The VFX itself starts right before the first hitbox (frame 25).
					seq.Cleaner:Add(function()
						VFXService:StopEffect(
							Players:GetPlayers(),
							"ForgeVFXHold",
							{ UUID = self.VFXUUID }
						)
					end)
				end,
			},

			{
				25,
				function()
					if not self.VFXStarted then
						self.VFXStarted = true
						VFXService:StartEffect(Players:GetPlayers(), "ForgeVFXHold", {
							UUID = self.VFXUUID,
							Template = self:GetAsset("Models/YellowOverdrive"),
							Origin = RootPart,
						})
					end

					-- Drain by elapsed wall time, not by frame count: Timescale
					-- changes frame pacing but must not change the Hamon cost.
					const now = workspace:GetServerTimeNow()
					const elapsed = now - self.LastDrain
					self.LastDrain = now

					if elapsed > 0 then
						const spent = CombatService:ConsumeCharge(
							character,
							"HamonCharge",
							DRAIN_PER_SECOND * elapsed
						)
						if not spent then self.Sequence:Stop() end
					end
				end,
				150,
			},

			{
				25,
				function()
					const Targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = AttackInfo.Hitbox,
					})

					for _, Target in Targets do
						CombatService:Attack({
							Attacker = character,
							Victim = Target,
							Info = AttackInfo,
						})
					end
				end,
				150,
				Interval = 5,
			},

			{ 155 },
		},
	}))
end

function Skill.Activate(self)
	const CombatService = Crane:GetService("CombatService")
	if CombatService:GetCharge(self.Character, "HamonCharge") < MIN_HAMON then return end

	-- The clock starts at the cast, so the wind-up frames count toward the drain.
	self.LastDrain = workspace:GetServerTimeNow()
	-- The skill instance lives as long as the character; the frame-25 VFX latch
	-- has to be rearmed for every cast, otherwise bots (which recast from combos)
	-- stop showing the effect after the very first use.
	self.VFXStarted = false

	if self.Sequence then
		-- Hold-to-cast, like StandBarrage: releasing the bind fires Deactivated
		-- and ends the barrage before its animation/hamon budget runs out.
		self.Sequence.Cleaner:Add(self.Deactivated:Once(function()
			self.Sequence:Stop()
		end))

		self.Sequence:Play()
		self.Sequence:Await()
	end

	self:SetCooldown(self.Data.UseCooldown)
end

function Skill.Interrupt(self)
	if self.Sequence then self.Sequence:Stop() end
end

return Skill
