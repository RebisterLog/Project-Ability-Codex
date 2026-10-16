--!native

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const types = require(ServerScriptService.server.types)

const MOVEMENT_ANIMATIONS = {
	"Idle",
	"Run",
	"Walk",
	"Jump",
	"FreeFall",
}

const Spec = {}
Spec.__index = Spec

function Spec.new(character: types.Character, data: types.SpecData): types.Spec
	const self = setmetatable({
		Data = data,
		Character = character,
		Skills = {},
		Cleaner = Crane.Buttler.new(),
		Proxy = Proxy({
			Skills = {},
		}),
		OnInterruptSkill = Crane.Signal(),
		OnActivateSkill = Crane.Signal(),
		OnDeactivateSkill = Crane.Signal(),
	}, Spec) :: types.Spec

	return self
end

function Spec.Init(self: types.Spec)
	if self.Initialized then return end
	self.Initialized = true

	const defaultMovements = Crane:GetService("ConfigService"):Get("DefaultAnimations").Movement

	for _, name in MOVEMENT_ANIMATIONS do
		const animation = self.Data.Assets.Animations[name]
		
		if not animation then
		    if not defaultMovements[name] then continue end

			self.Character.instance:SetAttribute(name, defaultMovements[name].Animation.AnimationId)
			continue
		end

		self.Character.instance:SetAttribute(name, animation.Animation.AnimationId)
	end

	if self.Data.onInit then self.Data.onInit(self) end
end

function Spec.GetAvailableSkills(self: types.Spec): { types.Skill }
	const availableSkills = {}

	for _, skill in self.Skills do
		if skill.Validate(skill) then table.insert(availableSkills, skill) end
	end

	return availableSkills
end

function Spec.CheckActiveSkills(self: types.Spec): boolean
	const activeSkills = {}

	for _, skill in self.Skills do
		if skill.Active then table.insert(activeSkills, skill) end
	end

	return #activeSkills > 0, activeSkills
end

function Spec.SetEnableSkills(self: types.Spec, tag: string, state: boolean)
	for id, skill in self.Skills do
		if skill.Data.Tag == tag then skill:SetEnabled(state) end
	end
end

function Spec.AddSkill(self: types.Spec, skill: types.Skill)
	if self.Skills[skill.Data.Id] then return end

	skill.Spec = self
	self.Skills[skill.Data.Id] = skill

	if not skill.Initialized then skill:Init() end

	skill.Proxy:Subscribe("AnyChange", { "Parameters" }, function(data)
		self.Proxy:Patch({
			{
				Name = "SetDictionary",
				Path = { "Skills" },
				Args = { skill.Data.Id, skill.Proxy() },
			},
		})
	end)

	self.Proxy:Patch({
		{ Name = "SetDictionary", Path = { "Skills" }, Args = { skill.Data.Id, skill.Proxy() } },
	})

	self.Cleaner:Add(skill)
end

function Spec.RemoveSkill(self: types.Spec, skillId: string)
	if not self.Skills[skillId] then return end

	self.Skills[skillId]:Destroy()
	self.Skills[skillId] = nil

	self.Proxy:Patch({
		{ Name = "RemoveDictionary", Path = { skillId }, Args = {} },
	})
end

function Spec.ActivateSkill(self: types.Spec, skillId: string)
	if not self.Skills[skillId] then return end
	if self:CheckActiveSkills() then return end

	const skill = self.Skills[skillId]

	const success, err = skill:Validate()
	if not success then return success, err end

	self.OnActivateSkill:Fire(skill)

	return skill:Activate()
end

function Spec.InterruptSkill(self: types.Spec, skillId: string)
	if not self.Skills[skillId] then return end

	const skill = self.Skills[skillId]
	self.OnInterruptSkill:Fire(skill)

	return skill:Interrupt()
end

function Spec.DeactivateSkill(self: types.Spec, skillId: string)
	if not self.Skills[skillId] then return end

	const skill = self.Skills[skillId]
	self.OnDeactivateSkill:Fire(skill)

	return skill:Deactivate()
end

function Spec.Destroy(self: types.Spec)
	self.Cleaner:Destroy()
end

return Spec
