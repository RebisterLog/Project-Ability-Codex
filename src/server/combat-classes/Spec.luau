--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)
local types = require(ServerScriptService.server.types)

const MOVEMENT_ANIMATIONS = {
	"Idle",
	"Run",
	"Walk",
}

local Spec = {}
Spec.__index = Spec

function Spec.new(character: types.Character, data: types.SpecData): types.Spec
	local self = setmetatable({
		Data = data,
		Character = character,
		Skills = {},
		ActiveSkill = nil,
		Janitor = Crane.Janitor.new(),
		Proxy = Proxy({
			Skills = {}
		}),
		OnInterruptSkill = Crane.Signal.new(),
		OnActivateSkill = Crane.Signal.new(),
		OnDeactivateSkill = Crane.Signal.new(),
	}, Spec) :: types.Spec

	return self
end

function Spec.Init(self: types.Spec)
	if self.Initialized then return end
	self.Initialized = true
	
	for _, name in MOVEMENT_ANIMATIONS do
		local animation = self.Data.Assets.Animations[name]
		if not animation then continue end
		
		self.Character.instance:SetAttribute(name, animation.Animation.AnimationId)
	end
	
	if self.Data.onInit then
		self.Data.onInit(self)
	end
end

function Spec.GetAvailableSkills(self: types.Spec): {types.Skill}
	local availableSkills = {}
	
	for _, skill in self.Skills do
		if skill.Validate(skill) then
			table.insert(availableSkills, skill)
		end
	end
	
	return availableSkills
end

function Spec.CheckActiveSkills(self: types.Spec): boolean
	local activeSkills = {}
	
	for _, skill in self.Skills do
		if skill.Active then
			table.insert(activeSkills, skill)
		end
	end
	
	return #activeSkills > 0, activeSkills
end

function Spec.AddSkill(self: types.Spec, skill: types.Skill)
	if self.Skills[skill.Data.Id] then return end
	
	skill.Spec = self
	self.Skills[skill.Data.Id] = skill
	
	if not skill.Initialized then
		skill:Init()
	end
	
	skill.Proxy:Subscribe("AnyChange", {"Parameters"}, function(data)
		self.Proxy:Patch({
			{Name = "SetDictionary", Path = {"Skills"}, Args = {skill.Data.Id, skill.Proxy()} }
		})
	end)
	
	self.Proxy:Patch({
		{Name = "SetDictionary", Path = {"Skills"}, Args = {skill.Data.Id, skill.Proxy()} }
	})
end

function Spec.RemoveSkill(self: types.Spec, skillId: string)
	if not self.Skills[skillId] then return end
	
	self.Skills[skillId]:Destroy()
	self.Skills[skillId] = nil
	
	self.Proxy:Patch({
		{Name = "RemoveDictionary", Path = {skillId}, Args = {}}
	})
end

function Spec.ActivateSkill(self: types.Spec, skillId: string)
	if not self.Skills[skillId] then return end
	if self:CheckActiveSkills() then return end
																																
	local skill = self.Skills[skillId]
	
	local success, err = skill:Validate()
	if not success then return success, err end
	
	self.ActiveSkill = skill
	
	self.OnActivateSkill:Fire(skill)
	
	return skill:Activate()
end

function Spec.InterruptSkill(self: types.Spec, skillId: string)
	if not self.Skills[skillId] then return end
	
	local skill = self.Skills[skillId]
	self.OnInterruptSkill:Fire(skill)
	
	if self.ActiveSkill == skill then
		self.ActiveSkill = nil
	end

	return skill:Interrupt()
end

function Spec.DeactivateSkill(self: types.Spec, skillId: string)
	if not self.Skills[skillId] then return end
	
	local skill = self.Skills[skillId]
	self.OnDeactivateSkill:Fire(skill)
	
	if self.ActiveSkill == skill then
		self.ActiveSkill = nil
	end
	
	return skill:Deactivate()
end

function Spec.Destroy(self: types.Spec)
	self.Janitor:Destroy()
end


return Spec