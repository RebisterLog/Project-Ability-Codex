--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Promise = require(ReplicatedStorage.shared.packages.Promise)
local Signal = Crane.Signal
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)
local types = require(ServerScriptService.server.types)

local Skill = {}
Skill.__index = Skill

function Skill.new(character: types.Character, spec: types.Spec, data: types.SkillData)
	local self = setmetatable({
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

function Skill.Activate(self: types.Skill)
	if self.Active then return end

	self.Active = true
	self.Holding = true

	if self.Data.Activate then self.Data.Activate(self) end

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

	if self.Data.onInit then self.Data.onInit(self) end

	local CombatService = Crane:GetService("CombatService")

	if self.Data.Interrupt then
		self.Cleaner:Add(CombatService.Interrupted:Connect(function(Target)
			if Target == self.Character then self:Interrupt() end
		end))
	end

	if not self.Data.Tag then self:SetEnabled(true) end

	self:SetDisplayName(self.Data.DisplayName)
end

function Skill.Destroy(self: types.Skill)
	if self.Data.onDestroy then self.Data.onDestroy(self) end

	if self.Cleaner and #self.Cleaner > 0 then self.Cleaner:Destroy() end
end

return Skill
