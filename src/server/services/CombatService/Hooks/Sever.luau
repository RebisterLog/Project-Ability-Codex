const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Config = require(ReplicatedStorage.shared.configs.SeveredLimbs)
const types = require(ServerScriptService.server.types)

const VFXService = Crane:GetService("VFXService")
const SeverAssets = ReplicatedStorage.assets:WaitForChild(Config.AssetsRoot)

-- Wounds are a global mechanic, not a spec asset: every character resolves
-- the same placeholder clips and limb models regardless of their skin.
const function globalClip(name: string): string?
	const clip = SeverAssets.Animations:FindFirstChild(name)
	return clip and (clip :: Animation).AnimationId or nil
end

return {
	Name = "Sever",
	Type = "Cast",
	Priority = 95,

	Function = function(Data: types.AttackData)
		const Info = Data.Info
		if not Data.State.Success then return true end
		if not Info.Sever then return true end

		const victim = Data.Victim
		if victim.Humanoid.Health <= 0 then return true end

		const limb = Info.Sever.Limb
		const now = workspace:GetServerTimeNow()
		const uuid = tostring(os.clock()) .. limb
		const isLeg = limb == Enums.Limb.LeftLeg or limb == Enums.Limb.RightLeg
		const isArm = limb == Enums.Limb.LeftArm or limb == Enums.Limb.RightArm

		const wound = victim:AddParameter(
			"SeveredLimbs" :: any,
			{
				[limb] = {
					UUID = uuid,
					ExpiresAt = now + Info.Sever.Duration,
					WalkSpeed = if isLeg then Enums.CastSpeed.Medium else nil,
					DamageMultiplier = if isArm then 0.5 else nil,
					Walk = if isLeg then globalClip(Config.Animations.Crawl) else nil,
					Run = if isLeg then globalClip(Config.Animations.Run) else nil,
					Idle = if isLeg then globalClip(Config.Animations.Idle) else nil,
				},
			} :: any
		)
		victim.Cleaner:Add(wound)
		task.delay(Info.Sever.Duration, function()
			if not victim.TornDown then wound:Destroy() end
		end)

		const model = SeverAssets.Models:FindFirstChild((Config.Models :: any)[limb] or limb)

		VFXService:StartEffect(Players:GetPlayers(), "SeveredLimb", {
			UUID = uuid,
			Character = victim.instance,
			Limb = limb,
			Model = model,
			Position = victim.RootPart.Position,
		})
		VFXService:StartEffect(Players:GetPlayers(), "BloodFXBurst", {
			UUID = uuid,
			Character = victim.instance,
			Limb = limb,
			Preset = "Fountain",
		})

		return true
	end,
}
