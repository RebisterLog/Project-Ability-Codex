const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const SkillClass = require(ServerScriptService.server["combat-classes"].Skill)
const types = require(ServerScriptService.server.types)
const Configuration = ServerScriptService.server.Configuration

const SkillsFolder = ServerScriptService.server.skills

-- The server never trusts a client cursor point; limit how far a skill may aim.
const MAX_AIM_DISTANCE = 120

const SkillService = Crane:CreateService({
	Name = "SkillService",
})
SkillService.CachedData = {}

function SkillService:onStart()
	self.SpecService = Crane:GetService("SpecService")
	self.PathUtil = Crane:GetService("PathUtil")

	Crane:GetPacket("StartSkill")
		.listen(function(request: { Id: string, AimPoint: Vector3? }, player)
			const character = player.Character
			if not character then return end

			self:ActivateSkill(character, request.Id, request.AimPoint)
		end)

	Crane:GetPacket("StopSkill").listen(function(skillId: string, player)
		const character = player.Character
		if not character then return end

		const component = Crane:GetComponent("Character", character)
		if not component then return end

		local spec = component:GetSpec()
		if not spec or not spec.Skills[skillId] then spec = component:GetSubSpec() end
		if not spec or not spec.Skills[skillId] then return end

		spec:DeactivateSkill(skillId)
	end)
end

--- Activates a skill through the canonical spec validation path. Accepting a
--- Model keeps the packet handler and Studio Bridge on the same code path.
function SkillService:ActivateSkill(
	character: types.Character | Model,
	skillId: string,
	aimPoint: Vector3?
): boolean
	local component: types.Character?
	if typeof(character) == "Instance" then
		component = Crane:GetComponent("Character", character) :: types.Character?
	else
		component = character :: types.Character
	end
	if not component then return false end

	local spec = component:GetSpec()
	if not spec or not spec.Skills[skillId] then spec = component:GetSubSpec() end
	if not spec or not spec.Skills[skillId] then return false end

	-- Clients (and bots) can submit any cursor point; clamp it to a sane radius
	-- around the caster before a skill consumes it. A nil point is left alone
	-- so skills can still apply their own fallback.
	if aimPoint and component.RootPart then
		const delta = aimPoint - component.RootPart.Position
		if delta.Magnitude > MAX_AIM_DISTANCE then
			aimPoint = component.RootPart.Position + delta.Unit * MAX_AIM_DISTANCE
		end
	end

	spec:ActivateSkill(skillId, aimPoint)
	return true
end

function SkillService:GetSkillData(skillId: string): types.SkillData?
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

	return nil
end

function SkillService:CreateSkill(
	character: types.Character,
	data: { Spec: types.SpecData, SkillId: string }
)
	const skillData = self:GetSkillData(data.SkillId)
	if skillData == nil then error(`SkillService: unknown skill "{data.SkillId}"`) end

	return character.Cleaner:Add(SkillClass.new(character, data.Spec, skillData), "Destroy")
end

return SkillService
