const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const SkillClass = require(ServerScriptService.server["combat-classes"].Skill)
const types = require(ServerScriptService.server.types)
const Configuration = ServerScriptService.server.Configuration

const SkillsFolder = Configuration.SkillsFolder.Value

const SkillService = Crane:CreateService({
	Name = "SkillService",
})
SkillService.CachedData = {}

function SkillService:onStart()
	self.SpecService = Crane:GetService("SpecService")
	self.PathUtil = Crane:GetService("PathUtil")

	Crane:GetPacket("StartSkill").listen(function(skillId: string, player)
		const character = player.Character
		if not character then return end

		const component = Crane:GetComponent("Character", character)
		if not component then return end

		const spec = component.Spec
		if not spec then return end

		spec:ActivateSkill(skillId)
	end)

	Crane:GetPacket("StopSkill").listen(function(skillId: string, player)
		const character = player.Character
		if not character then return end

		const component = Crane:GetComponent("Character", character)
		if not component then return end

		const spec = component.Spec
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

		const data = require(module)
		data["Id"] = skillId
		self.CachedData[skillId] = data

		return data
	end
end

function SkillService:CreateSkill(
	character: types.Character,
	data: { Spec: types.SpecData, SkillId: string }
)
	const skillData: types.SkillData = self:GetSkillData(data.SkillId)

	return character.Cleaner:Add(SkillClass.new(character, data.Spec, skillData), "Destroy")
end

return SkillService
