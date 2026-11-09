--!native
--!optimize 2

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Promise = require(ReplicatedStorage.shared.packages.Promise)
const Signal = Crane.Signal
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const types = require(ServerScriptService.server.types)

const Skill = {}
Skill.__index = Skill

function Skill.new(character: types.Character, spec: types.Spec, data: types.SkillData)
	const self = setmetatable({
		Character = character,
		Data = data,
		Spec = spec,
		Active = false,
		Holding = false,
		Cleaner = Crane.Buttler.new(),

		Deactivated = Signal(),

		Proxy = Proxy({
			Parameters = {
				DisplayName = "Unknown",
				ReleaseTime = 0,
				Enabled = false,
				Bind = Enum.KeyCode.Unknown,
			},
		}),
	}, Skill) :: types.Skill

	return self
end

local function softStopActiveSkill(self: types.Skill)
	if self.Sequence then pcall(function()
		self.Sequence:Stop()
	end) end

	if self.Active and self.Data.Interrupt then
		pcall(function()
			self.Data.Interrupt(self)
		end)
	end

	self.Active = false
	self.Holding = false
end

function Skill.Activate(self: types.Skill)
	if self.Active then return end

	self.Active = true
	self.Holding = true

	local ok, err = xpcall(function()
		if self.Data.Activate then self.Data.Activate(self) end
	end, debug.traceback)

	if not ok then
		softStopActiveSkill(self)
		if not string.find(tostring(err), "Skill:GetAsset:", 1, true) then
			warn(
				string.format(
					"[Skill] Activation error (skill=%s): %s",
					tostring(self.Data and (self.Data.Id or self.Data.DisplayName)),
					tostring(err)
				)
			)
		end
		return
	end

	self.Active = false

	if self.Data.Cooldown then self:SetCooldown(self.Data.Cooldown) end
end

function Skill.Deactivate(self: types.Skill)
	if self.Holding then
		self.Holding = false

		self.Deactivated:Fire(self)
	end
end

function Skill.Interrupt(self: types.Skill)
	if not self.Active then return end

	if self.Data.Interrupt then self.Data.Interrupt(self) end
end

function Skill.SetCooldown(self: types.Skill, Time: number)
	Time *= self.Character:GetParameter("CooldownMultiplier")
	Time = math.max(Time, 0)

	self.Proxy:Patch({
		{
			Name = "SetDictionary",
			Path = { "Parameters" },
			Args = { "ReleaseTime", os.clock() + Time },
		},
	})
end

function Skill.SetDisplayName(self: types.Skill, name: string)
	self.Proxy:Patch({
		{ Name = "SetDictionary", Path = { "Parameters" }, Args = { "DisplayName", name } },
	})
end

function Skill.SetBind(self: types.Skill, bind: types.Bind)
	self.Proxy:Patch({
		{ Name = "SetDictionary", Path = { "Parameters" }, Args = { "Bind", bind } },
	})
end

function Skill.SetEnabled(self: types.Skill, enabled: boolean)
	self.Proxy:Patch({
		{ Name = "SetDictionary", Path = { "Parameters" }, Args = { "Enabled", enabled } },
	})
end

function Skill.IsOnCooldown(self: types.Skill)
	return self.Proxy().Parameters.ReleaseTime > os.clock()
end

function Skill.Pause(self: types.Skill)
	const sequence = self.Sequence
	if sequence and sequence:IsPlaying() then sequence:Pause() end
end

function Skill.Resume(self: types.Skill)
	const sequence = self.Sequence
	if sequence and sequence:IsPaused() then sequence:Play() end
end

function Skill.Validate(self: types.Skill)
	if self.Character:GetParameter("NoSkillCast") then return false end
	if not self.Proxy().Parameters.Enabled then return false end
	if self.Character:GetParameter("Stun").Duration > 0 then return false end
	if self.Character:GetParameter("Ragdoll") then return false end
	if self.Character.Humanoid.Health <= 0 then return false end
	if self:IsOnCooldown() then return false end
	return true
end

function Skill.Init(self: types.Skill)
	if self.Initialized then return end

	self.Initialized = true
	self.PathUtil = Crane:GetService("PathUtil")

	if self.Data.onInit then self.Data.onInit(self) end

	const CombatService = Crane:GetService("CombatService")

	if self.Data.Interrupt then
		self.Cleaner:Add(CombatService.Interrupted:Connect(function(Target)
			if Target == self.Character then self:Interrupt() end
		end))
	end

	if not self.Data.Tag then self:SetEnabled(true) end

	self:SetDisplayName(self.Data.DisplayName)
end

local function resolveAsset(root: any, segments: { string }): any?
	local current = root
	for _, segment in segments do
		if type(current) ~= "table" then return nil end
		current = current[segment]
	end
	return current
end

local function parseAssetPath(path: string): { string }
	assert(type(path) == "string" and path ~= "", "Skill asset path must be a non-empty string")

	local segments = {}
	for _, segment in string.split(path, "/") do
		if segment ~= "" then table.insert(segments, segment) end
	end
	if #segments == 0 then error(string.format('Skill asset path is invalid: "%s"', path)) end

	return segments
end

local function findSkillAsset(self: types.Skill, segments: { string }): (any, string?, string?)
	local spec = self.Spec
	local root = spec and spec.Data and spec.Data.Assets
	local asset = resolveAsset(root, segments)
	if asset ~= nil then return asset, nil, nil end

	local baseSpecId = self.Data and self.Data.BaseSpec
	if baseSpecId then
		local SpecService = Crane:GetService("SpecService")
		local baseData = SpecService:GetSpecData({ Id = baseSpecId })
		if baseData and baseData.Assets then
			asset = resolveAsset(baseData.Assets, segments)
			if asset ~= nil then return asset, nil, nil end
		end
	end

	local specId = (spec and spec.Data and spec.Data.Id) or "Unknown"
	return nil, specId, baseSpecId
end

function Skill:TryGetAsset(path: string): any?
	local ok, result = pcall(function()
		return findSkillAsset(self, parseAssetPath(path))
	end)
	if not ok then return nil end

	local asset = result
	if asset ~= nil then return asset end
	return nil
end

function Skill:GetAsset(path: string): any
	local segments = parseAssetPath(path)
	local asset, specId, baseSpecId = findSkillAsset(self, segments)
	if asset ~= nil then return asset end

	local skillId = (self.Data and (self.Data.Id or self.Data.DisplayName)) or "Unknown"
	local assetName = segments[#segments] or path
	warn(
		string.format(
			'[Skill:GetAsset] Missing asset "%s" (path: "%s"). Current spec: %s. Skill: %s. BaseSpec: %s',
			tostring(assetName),
			path,
			tostring(specId),
			tostring(skillId),
			tostring(baseSpecId)
		)
	)

	softStopActiveSkill(self)
	error(
		string.format(
			'Skill:GetAsset: missing asset "%s" for spec "%s"',
			path,
			tostring(specId or "Unknown")
		)
	)
end

function Skill.Destroy(self: types.Skill)
	if self.Data.onDestroy then self.Data.onDestroy(self) end

	if self.Cleaner and #self.Cleaner > 0 then self.Cleaner:Destroy() end
end

return Skill
