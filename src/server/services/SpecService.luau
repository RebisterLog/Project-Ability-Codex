const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const SpecClass = require(ServerScriptService.server["combat-classes"].Spec)
const types = require(ServerScriptService.server.types)
const Configuration = ServerScriptService.server.Configuration

const SpecsFolder = ServerScriptService.server.specs

const SpecService = Crane:CreateService({
	Name = "SpecService",
})
SpecService.CachedInfo = {}

function SpecService:onStart()
	self.ConfigService = Crane:GetService("ConfigService")
	self.SkillService = Crane:GetService("SkillService")
end

function SpecService:GetSpecData(spec: types.SpecDef): types.SpecData?
	const skinName = spec.Skin or "None"
	const cacheKey = `{spec.Id}/{skinName}`
	if self.CachedInfo[cacheKey] then return self.CachedInfo[cacheKey] end

	const specInfo = self.ConfigService:Get("Specs")[spec.Id]
	if not specInfo then
		Crane.Utils.Log("SpecService", `Config doesn't exist: {spec.Id}`, "warn")
		return nil
	end

	const skins = self.ConfigService:Get("Skins")[spec.Id]
	const skin = skins and skins[skinName]
	if not skin then
		Crane.Utils.Log("SpecService", `Skin doesn't exist: {skinName} (spec {spec.Id})`, "warn")
		return nil
	end

	const module = SpecsFolder:FindFirstChild(spec.Id)
	if not module or not module:IsA("ModuleScript") then
		Crane.Utils.Log("SpecService", `Can't find spec module with Name: {spec.Id}`, "warn")
		return nil
	end

	const data = Crane.Utils.DeepClone(require(module))
	for key, value in specInfo do
		data[key] = value
	end

	data.Id = spec.Id
	data.Slot = specInfo.Type or "Spec"
	data.Assets = skin

	self.CachedInfo[cacheKey] = data
	return data
end

--- The slot a spec belongs to, taken from the spec config (`Type`, `"Spec"` by
--- default). This is the single source of truth for the slot routing.
function SpecService:GetSpecType(specId: string): types.SpecSlot?
	const spec = self.ConfigService:Get("Specs")[specId]
	if not spec then
		Crane.Utils.Log("SpecService", `Spec doesn't exist: {specId}`, "warn")
		return nil
	end

	return spec.Type or "Spec"
end

function SpecService:CreateSpec(character: types.Character, data: types.SpecDef): types.Spec?
	const baseData = self:GetSpecData(data)
	if not baseData then return nil end

	-- CachedInfo is shared by all owners of a definition. Per-owned-spec state
	-- must only ever be stamped onto this shallow per-runtime copy.
	const specData = table.clone(baseData) :: types.SpecData
	specData.InstanceId = data.InstanceId

	const spec = SpecClass.new(character, specData)

	for skillId in spec.Data.Skills do
		const skill = self.SkillService:CreateSkill(character, {
			Spec = spec,
			SkillId = skillId,
		})

		spec:AddSkill(skill)

		-- Config binds are either a bare enum (legacy) or a declaration that
		-- also carries `Hold`. A per-owner override is always a bare enum: it
		-- replaces the key only, never the options attached in the config.
		const declared = specData.Binds and specData.Binds[skillId]
		const declaration = if type(declared) == "table"
			then declared :: { Key: types.Bind, Hold: boolean? }
			else nil
		const defaultKey = if declaration then declaration.Key else declared :: types.Bind?

		local bind: types.Bind? = data.Binds and data.Binds[skillId]
		if not bind then bind = defaultKey end

		if not bind then
			-- A skill without a bind keeps `Enum.KeyCode.Unknown`, which is also
			-- what a mouse click reports. The client would then fire it on every
			-- click, so the mismatch between the skill id and the bind key has to
			-- be loud.
			Crane.Utils.Log(
				script.Name,
				`No bind for skill "{skillId}" of spec "{spec.Data.DisplayName}"`,
				"warn"
			)
			continue
		end

		skill:SetBind(bind)
		skill:SetHold(declaration ~= nil and declaration.Hold == true)
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
