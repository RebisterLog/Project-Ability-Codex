local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Crane = require(ReplicatedStorage.shared.packages.Crane)
local types = require(ServerScriptService.server.types)

local StandService = Crane:CreateService({
	Name = "StandService",
	LoadOrder = 150,
})

function StandService:onStart()
	self.ConfigService = Crane:GetService("ConfigService")

	self.Stands = {}
end

function StandService:AddStandFor(character: types.Character, model: Model)
    task.wait() -- for getting time to clean stand

    if self.Stands[character] then
        error("User already have stand")
    end
    
	local stand = Crane:AddComponent(model, "Stand") :: types.Stand
	stand:Init(character)

	self.Stands[character] = stand

	stand.Destroying:Once(function()
		self:RemoveStandFor(character)
	end)

	character.Destroying:Once(function()
		stand:Destroy()
	end)

	return stand
end

function StandService:RemoveStandFor(character: types.Character)
    local stand = self.Stands[character]
    
    if stand then
        self.Stands[character] = nil
        stand.instance:Destroy()
    end
end

-- Add standName only if you must to get any model of stand
-- if you just want to know: does this character have stand? - do NOT add standName
function StandService:GetStand(character: types.Character, standName: string?)
	return self.Stands[character]
end

return StandService
