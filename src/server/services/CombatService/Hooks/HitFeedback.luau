const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

const VFXService = Crane:GetService("VFXService")
const CombatService = Crane:GetService("CombatService")
const PlayersService = Crane:GetService("PlayersService")

const DefaultHits = ReplicatedStorage.assets.Default.Hits
--const Hamon = ReplicatedStorage.assets.Default.Hamon
--const HamonHitVFX = Hamon.VFXs and Hamon.VFXs:FindFirstChild("Hit")
--const HamonHitSound = Hamon.Sounds and Hamon.Sounds:FindFirstChild("Hit")

const function pickRandom(folder: Folder, className: string): Instance?
	const pool = {}

	for _, child in folder:GetChildren() do
		if child.ClassName == className then table.insert(pool, child) end
	end

	if #pool == 0 then return nil end
	return pool[math.random(1, #pool)]
end

--[[
	HitAnimations = HitAnimations = {Folder} || "Default"

	HitEffects = {
		{
			BodyPart = BasePart || "Head" || "Torso",
			Particle = Particle || "Models/BarrageHit" || "Default",
			LookAt = "Attacker" || "Victim",
			Sound = Sound || "Sounds/BarrageHit" || "Default",
			SpecName: string?
		};
	}
]]

return {
	Name = "HitFeedback",
	Type = "Cast",
	Priority = 99,
	Function = function(Data: types.AttackData)
		if not Data.State.Success then return true end
		-- Blocked hits carry no damage; their feedback will get its own effects.
		if (Data.Info.Damage or 0) <= 0 then return true end
		-- Re-frozen mid-replay: the payout rides the next release, feedback with it.
		if Data.Victim:GetParameter("DamageHold") == true then return true end
		-- DamageDealt is only set when the Damage hook actually processed the hit
		-- (a corpse skips it); god mode processes the hit without removing health.
		if Data.DamageDealt == nil and not Data.Victim:GetParameter("GodMode") then return true end

		const victim = Data.Victim.instance
		const attacker = Data.Attacker.instance
		const skill = Data.Skill
		const speed = Data.Attacker:GetParameter("Timescale")

		for _, v in Data.Info.HitEffects or {} do
			local Particle = v.Particle
			local Sound = v.Sound

			if type(Particle) == "string" then
				if Particle == "Default" then
					Particle = DefaultHits.HitEffects.BaseHitVFX
				elseif skill then
					Particle = skill:TryGetAsset(v.Particle)
				end
				-- An unresolved skin key must never reach EmitParticle: it
				-- would try to call :Clone() on a plain string on the client.
				if type(Particle) == "string" then Particle = DefaultHits.HitEffects.BaseHitVFX end
			end

			if type(Sound) == "string" then
				if Sound == "Default" then
					Sound = DefaultHits.HitSounds.Hit2
				elseif skill then
					Sound = skill:TryGetAsset(Sound)
				end
				if type(Sound) == "string" then Sound = nil end
			end

			VFXService:StartEffect(Players:GetPlayers(), "HitFeedback", {
				Attacker = attacker,
				Victim = victim,
				BodyPart = v.BodyPart,
				LookAt = v.LookAt or "Attacker",
				Particle = Particle,
				Sound = Sound,
				Speed = speed,
			})
		end

		const animation = Data.Info.HitAnimations
			and pickRandom(
				(Data.Info.HitAnimations == "Default" and DefaultHits.HitAnimations)
					or Data.Info.HitAnimations,
				"Animation"
			)
		if animation then
			VFXService:StartEffect(Players:GetPlayers(), "Animation", {
				Type = "Play",
				Character = victim,
				Animation = {
					Animation = animation,
					Priority = Enum.AnimationPriority.Action,
				},
				Speed = speed,
			})
		end

		--if CombatService:GetCharge(Data.Attacker, "HamonCharge") > 0 then
		--	if HamonHitVFX and HamonHitVFX:IsA("BasePart") then
		--		VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
		--			Particle = HamonHitVFX,
		--			Origin = Data.Victim.RootPart,
		--			UseForge = true,
		--		})
		--	end

		--	if HamonHitSound and HamonHitSound:IsA("Sound") then
		--		VFXService:StartEffect(Players:GetPlayers(), "Sound", {
		--			Origin = Data.Victim.RootPart,
		--			Sound = HamonHitSound,
		--		})
		--	end
		--end

		return true
	end,
}
