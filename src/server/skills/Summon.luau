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
	const StandService = Crane:GetService("StandService")

	const stand = StandService:GetStand(self.Character) :: types.Stand
	const isStandActive = stand and stand:IsActive() or false

	if not stand then return end

	self.Character:SetEnableSkills("OnlyForStand", not isStandActive)
	self.Character:SetEnableSkills("OnlyForUser", isStandActive)

	-- SetActive drives RefreshVisibility itself; suppression (death, ragdoll,
	-- time stop) decides whether the stand actually shows.
	stand:SetActive(not isStandActive)
end

return Skill
