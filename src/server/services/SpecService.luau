const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const SpecClass = require(ServerScriptService.server["combat-classes"].Spec)
const types = require(ServerScriptService.server.types)
const Configuration = ServerScriptService.server.Configuration

const SpecsFolder = Configuration.SpecsFolder.Value

const SpecService = Crane:CreateService({
	Name = "SpecService",
})
SpecService.CachedInfo = {}

function SpecService:onStart()
	self.ConfigService = Crane:GetService("ConfigService")
	self.SkillService = Crane:GetService("SkillService")
end

function SpecService:GetSpecData(spec: types.SpecDef): types.SpecData
	if self.CachedInfo[spec.Id] then -- if already was imported
		return self.CachedInfo[spec.Id]
	end

	const specInfo = self.ConfigService:Get("Specs")[spec.Id]
	if not specInfo then
		Crane.Utils.Log("SpecService", `Config doesn't exists: {spec.Id}`, "error")
		return
	end

	const skin = self.ConfigService:Get("Skins")[spec.Id][spec.Skin or "None"]
	if not skin then
		Crane.Utils.Log("SpecService", `Skin doesn't exists: {spec.Skin}`, "error")
		return
	end

	const module = SpecsFolder:FindFirstChild(spec.Id)
	if not module then
		Crane.Utils.Log("SpecService", `Can't find spec module with Name: {spec.Id}`, "error")
		return
	end

	const data = require(module)
	for i, v in specInfo do
		data[i] = v
	end

	data.Id = spec.Id
	data["Assets"] = skin

	self.CachedInfo[spec.Id] = data

	return data
end

function SpecService:CreateSpec(character: types.Character, data: types.SpecDef)
	const specData: types.SpecData = self:GetSpecData(data)

	const spec = SpecClass.new(character, specData)

	for skillId, skillData in spec.Data.Skills do
		const skill = self.SkillService:CreateSkill(character, {
			Spec = spec,
			SkillId = skillId,
		})

		spec:AddSkill(skill)

		if data.Binds[skillId] then
			skill:SetBind(data.Binds[skillId])
		else
			skill:SetBind(specData.Binds[skillId])
		end
	end

	if _G["CRANE_DEBUGGING"] then
		Crane.Utils.Log(
			script.Name,
			`Generated Spec {spec.Data.DisplayName} for {character.instance.Name}`
		)
	end

	return spec
end

return SpecService
