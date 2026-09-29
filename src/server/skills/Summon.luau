local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local types = require(ServerScriptService.server.types)
local Enums = require(ServerScriptService.server.Enums)
local Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)

local Skill: types.SkillData = {
	DisplayName = "Summon",
	Cooldown = 1,
	
	SkillCharacters = {
		
	},
}

function Skill.Activate(self: types.Skill)
	local VFXService = Crane:GetService("VFXService")
	local StandService = Crane:GetService("StandService")
	
	local stand = StandService:GetStand(self.Character) :: types.Stand
	local isStandActive = stand and stand:IsActive() or false
	
	if not stand then return end
	
	self.Spec:SetEnableSkills("OnlyForStand", not isStandActive)
	self.Spec:SetEnableSkills("OnlyForUser", isStandActive)
	
	stand:SetActive(not isStandActive)
	stand:SetVisible(not isStandActive)
end


return Skill