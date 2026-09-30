--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Signal = Crane.Signal
local types = require(ServerScriptService.server.types)

local Projectile = {}
Projectile.__index = Projectile

function Projectile.new()
	local self = setmetatable({}, Projectile)

	return self
end

return Projectile
