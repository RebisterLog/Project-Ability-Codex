--[=[ CHARGE

   Hold-to-cast Hamon charge. Shared skill: any spec can import it from
   ~/skills/Charge. Assets are resolved from the Hamon SubSpec skin through
   `BaseSpec`, so the skill itself owns no spec-specific paths. The hold ends
   on release/interrupt or automatically once Hamon is fully charged; a cast
   on an already-full bar is skipped entirely.

   ASSETS:

   Animations
      Charge : Looped clip played for the whole hold (assets/Default/Hamon).

   Sounds
      Charge : Sound played on press (assets/Default/Hamon).

   Models
      Charge : Particle VFX attached to the root while charging.

]=]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Enums = require(ServerScriptService.server.Enums)
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Promise = require(ReplicatedStorage.shared.packages.Promise)
const types = require(ServerScriptService.server.types)

-- Poll the replicated charge state rather than trusting a one-shot timer:
-- other skills can spend Hamon mid-hold, so the time to Max is not fixed.
const FULL_CHARGE_POLL = 0.1

const function isFullyCharged(character, CombatService): boolean
	const state = character:GetParameter("HamonCharge")
	const max = state and state.Max or 0
	return max > 0 and CombatService:GetCharge(character, "HamonCharge") >= max
end

const Skill: types.SkillData = {
	DisplayName = "Hamon Charge",
	Cooldown = 1,
	BaseSpec = "Hamon",
	SkillCharacters = { "Buff" },

	-- A spec change or respawn destroys the skill without a key release, so the
	-- fill has to be closed here: otherwise the character would stay "filling"
	-- forever, blocking the hold/decay model.
	onDestroy = function(self)
		const CombatService = Crane:GetService("CombatService")

		CombatService:StopChargeFill(self.Character, "HamonCharge")
		-- Route through the class so it owns `Holding` and the signal: firing
		-- `Deactivated` by hand would desync both.
		self:Deactivate()
	end,
}

--- Hold-to-cast: the fill starts on press and stops on release. The actual
--- resource lives on the character (CombatService owns the math), so this skill
--- only opens and closes the tap.
function Skill.Activate(self)
	const character = self.Character
	const RootPart = character.RootPart
	const VFXService = Crane:GetService("VFXService")
	const CombatService = Crane:GetService("CombatService")

	-- A full bar has nothing to fill: do not start the cast at all, so the
	-- looped animation, the sound and the VFX are not played for nothing.
	if isFullyCharged(character, CombatService) then return end

	const Collector = Crane.Buttler.new()

	Collector:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Walk))
	Collector:Add(character:AddParameter("MaxJumpPower", 0))

	CombatService:StartChargeFill(character, "HamonCharge")

	Collector:Add(function()
		CombatService:StopChargeFill(character, "HamonCharge")
	end)

	-- `Looped` lives on the clip in the skin config; the animation effect and
	-- the client handler both read it from there.
	const animation = self:TryGetAsset("Animations/Charge")
	if animation then
		VFXService:StartEffect(Players:GetPlayers(), "Animation", {
			Character = character.instance,
			Animation = animation,
			Speed = 1,
		})

		Collector:Add(function()
			VFXService:StopEffect(Players:GetPlayers(), "Animation", {
				Character = character.instance,
				Animation = animation.Animation,
			})
		end)
	end

	const chargeSound = self:TryGetAsset("Sounds/Charge")
	if chargeSound then
		VFXService:StartEffect(Players:GetPlayers(), "Sound", {
			Origin = RootPart,
			Sound = chargeSound,
		})
	end

	const chargeVFX = self:TryGetAsset("VFXs/Charge")
	if chargeVFX then
		const vfxUUID = math.random(1, 0x7FFFFFFF)
		VFXService:StartEffect(Players:GetPlayers(), "ForgeVFXHold", {
			UUID = vfxUUID,
			Template = chargeVFX,
			Origin = RootPart,
		})

		Collector:Add(function()
			VFXService:StopEffect(Players:GetPlayers(), "ForgeVFXHold", { UUID = vfxUUID })
		end)
	end

	-- Block-style hold: `Activate` yields until the bind is released, the
	-- character goes away, or the Hamon bar hits Max. The poll lives in the
	-- same Collector as StopChargeFill/VFX, so it is cancelled on any exit.
	Promise.new(function(resolve)
		Collector:Add(self.Deactivated:Once(resolve))

		Collector:Add(character.instance.AncestryChanged:Connect(function()
			if not character.instance.Parent then resolve() end
		end))

		Collector:Every(FULL_CHARGE_POLL, function()
			if not self.Holding then return end
			if isFullyCharged(character, CombatService) then self:Deactivate() end
		end)
	end)
		:finallyCall(Collector.Destroy, Collector)
		:catch(warn)
		:await()
end

function Skill.Interrupt(self)
	const CombatService = Crane:GetService("CombatService")
	CombatService:StopChargeFill(self.Character, "HamonCharge")
	self:Deactivate()
end

return Skill
