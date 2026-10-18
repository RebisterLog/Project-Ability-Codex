--!native

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Players = game:GetService("Players")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const types = require(ServerScriptService.server.types)

const WalkSpeedWatcher = function(self: types.Character)
	const MaxWalkSpeed = self:GetParameter("MaxWalkSpeed")
	local MinWalkSpeed = self:GetParameter("MinWalkSpeed")

	if MaxWalkSpeed < MinWalkSpeed then MinWalkSpeed = MaxWalkSpeed end

	const WalkSpeed = math.clamp(16, MinWalkSpeed, MaxWalkSpeed)
	self.Humanoid.WalkSpeed = WalkSpeed
end

return {
	["MaxWalkSpeed"] = WalkSpeedWatcher,
	["MinWalkSpeed"] = WalkSpeedWatcher,

	["MaxJumpPower"] = function(self: types.Character, value)
		const JumpPower = math.min(50, value)

		self.Humanoid.JumpPower = JumpPower
	end,

	["Stun"] = function(
		self: types.Character,
		value: { Priority: number, Duration: number }?,
		object
	)
		if not value or not object then return end

		const Priority = value.Priority

		object.Cleaner:Add(self:AddParameter("MaxJumpPower", 0))

		if Priority == Enums.Stun.Heavy then
			object.Cleaner:Add(self:AddParameter("MaxWalkSpeed", 0))
		elseif Priority == Enums.Stun.Medium then
			object.Cleaner:Add(self:AddParameter("MaxWalkSpeed", 3))
		end
	end,

	["Bleeding"] = function(self: types.Character, value, object)
		const Bleeding = value ~= nil and (value.Damage or 0) > 0
		const VFXService = Crane:GetService("VFXService")

		-- Blood and the slowdown are a state, not a one-shot effect: the watcher
		-- fires on every change of the parameter and syncs both with it, so an
		-- effect removed from the outside (a future cleanse, for example) stops
		-- them without a separate branch anywhere.
		if Bleeding then
			VFXService:StartEffect(Players:GetPlayers(), "Bleeding", self.instance)
		else
			VFXService:StopEffect(Players:GetPlayers(), "Bleeding", self.instance)
		end

		if not Bleeding or not object then return end

		if not object.Cleaner:Has("Slow") then
			object.Cleaner:Set("Slow", self:AddParameter("MaxWalkSpeed", value.Slow or 8))
		end
	end,

	["Ragdoll"] = function(self: types.Character, value: boolean?, object)
		value = value or false
		self:Ragdoll(value)

		if value then
			const iframe = self:AddParameter("IFrames", Enums.IFrames.Ragdoll)

			object.Cleaner:OnClean(function()
				task.delay(0.4, function()
					iframe:Destroy()
				end)
			end)
		end
	end,

	["NoCollision"] = function(
		self: types.Character,
		value: boolean,
		object: types.ParameterObject<boolean>
	)
		self:SetCollisionToPlayers(value ~= nil and value or true)
	end,

	["Restrain"] = function(self: types.Character, value: boolean, object)
		if not value then return end

		self.Humanoid.AutoRotate = not value
		--self.RootPart.Anchored = value

		object.Cleaner:Add(self:AddParameter("MaxWalkSpeed", 0))
		object.Cleaner:Add(self:AddParameter("MaxJumpPower", 0))

		object.Cleaner:Add(function()
			self.Humanoid.AutoRotate = true
			--self.RootPart.Anchored = false
		end)
	end,
}
