--!native

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

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
