const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Summon",
	Cooldown = 1,

	SkillCharacters = {},
}

function Skill.Activate(self: types.Skill)
	const VFXService = Crane:GetService("VFXService")
	const StandService = Crane:GetService("StandService")

	const stand = StandService:GetStand(self.Character) :: types.Stand
	const isStandActive = stand and stand:IsActive() or false

	if not stand then return end

	self.Spec:SetEnableSkills("OnlyForStand", not isStandActive)
	self.Spec:SetEnableSkills("OnlyForUser", isStandActive)

	stand:SetActive(not isStandActive)
	stand:SetVisible(not isStandActive)
end

return Skill
