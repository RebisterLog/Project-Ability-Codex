const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

const VFXService = Crane:GetService("VFXService")
const DefaultHits = ReplicatedStorage.assets.Default.Hits

const function pickRandom(folder: Folder, className: string): Instance?
	const pool = {}

	for _, child in folder:GetChildren() do
		if child.ClassName == className then table.insert(pool, child) end
	end

	if #pool == 0 then return nil end
	return pool[math.random(1, #pool)]
end

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

		VFXService:StartEffect(Players:GetPlayers(), "HitFeedback", {
			Character = victim,
			Effects = Data.Info.HitEffects or DefaultHits.HitEffects,
			Sound = pickRandom(Data.Info.HitSounds or DefaultHits.HitSounds, "Sound"),
		})

		const animation =
			pickRandom(Data.Info.HitAnimations or DefaultHits.HitAnimations, "Animation")
		if animation then
			VFXService:StartEffect(Players:GetPlayers(), "Animation", {
				Type = "Play",
				Character = victim,
				Animation = {
					Animation = animation,
					Priority = Enum.AnimationPriority.Action,
				},
			})
		end

		return true
	end,
}
