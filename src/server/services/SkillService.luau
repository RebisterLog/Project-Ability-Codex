local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local SkillClass = require(ServerScriptService.server["combat-classes"].Skill)
local types = require(ServerScriptService.server.types)
local Configuration = ServerScriptService.server.Configuration

local SkillsFolder = Configuration.SkillsFolder.Value

local SkillService = Crane:CreateService({
	Name = "SkillService",
})
SkillService.CachedData = {}

function SkillService:onStart()
	self.SpecService = Crane:GetService("SpecService")
	self.PathUtil = Crane:GetService("PathUtil")

	Crane:GetPacket("StartSkill").listen(function(skillId: string, player)
		local character = player.Character
		if not character then return end

		local component = Crane:GetComponent("Character", character)
		if not component then return end

		local spec = component.Spec
		if not spec then return end

		spec:ActivateSkill(skillId)
	end)

	Crane:GetPacket("StopSkill").listen(function(skillId: string, player)
		local character = player.Character
		if not character then return end

		local component = Crane:GetComponent("Character", character)
		if not component then return end

		local spec = component.Spec
		if not spec then return end

		spec:DeactivateSkill(skillId)
	end)
end

function SkillService:GetSkillData(skillId: string): types.SkillData
	if self.CachedData[skillId] then -- if already imported
		return self.CachedData[skillId]
	end

	for i, module in SkillsFolder:GetDescendants() do
		if not module:IsA("ModuleScript") then continue end
		if module.Name ~= skillId then continue end

		local data = require(module)
		data["Id"] = skillId
		self.CachedData[skillId] = data

		return data
	end
end

function SkillService:CreateSkill(
	character: types.Character,
	data: { Spec: types.SpecData, SkillId: string }
)
	local skillData: types.SkillData = self:GetSkillData(data.SkillId)

	return character.Cleaner:Add(SkillClass.new(character, data.Spec, skillData), "Destroy")
end

return SkillService
