--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])
local Enums = require(ServerScriptService.server.Enums)
local types = require(ServerScriptService.server.types)

local NavigationController = require(script.Parent.NavigationController)
local StateMachine = require(script.Parent.NavigationController.StateMachine)

local Crane = require(ReplicatedStorage.shared.packages.Crane)

local rand = Random.new(tick())

type BotProperities = {
	Target: types.Character?,
	Navigator: NavigationController.NavigationController,
	StateMachine: StateMachine.StateMachine,
	Config: BotsCharacters.BotCharacterConfig,
	Cleaner: typeof(Crane.Buttler.new()),
	TargetCleaner: typeof(Crane.Buttler.new()),
	Character: types.Character,
}

type BotMethods = {
	SetTarget: (self: Bot, character: types.Character?) -> (),
	ClearTarget: (self: Bot) -> (),
	Destroy: (self: Bot) -> (),
}

export type Bot = BotProperities & BotMethods

type BotState = StateMachine.State & {bot: Bot}

local States: {[string]: BotState} = {
	Attacking = {
		Enter = function(self: BotState)
			local chaoticMultiplier = self.bot.Config.Chaotic
			local isMelle = rand:NextNumber() < self.bot.Config.Aggressive + rand:NextNumber(0, chaoticMultiplier)
			local isBaiting = isMelle and (rand:NextNumber() < self.bot.Config.Agility + rand:NextNumber(0, chaoticMultiplier))
 
			self.Combo = self.bot:GetCombo()
			self.ComboIndex = 1
			
			--local conditions = self.bot:GetConditions()
			
			--self.bot.Navigator:SetHoldDistance(if isMelle then nil else 20)
			self.bot.Navigator:SetMovementStyle(if isBaiting then "zigzag" else "puma")
		end,

		Update = function(self: BotState)
			local hasActiveSkill = self.bot.Character.Spec:CheckActiveSkills()
			if hasActiveSkill then return end

			if self.ComboIndex > #self.Combo then
				self.ComboIndex = 1
				self.Combo = self.bot:GetCombo()
			end

			local chaoticMultiplier = self.bot.Config.Chaotic

			local conditions = self.bot:GetConditions()
			local skillName = self.Combo[self.ComboIndex]

			local skill: types.Skill = self.bot.Character.Spec.Skills[skillName]
			local skillOptions = self.bot.Config.Skills[skillName]
			local distance = (self.bot.Character.RootPart.Position - self.bot.Target.RootPart.Position).Magnitude

			if skillOptions.Distance and distance > skillOptions.Distance then
				self.ComboIndex += 1
				return
			end

			if skillOptions.RejectedConditions then
				for i, condition in conditions do
					if table.find(skillOptions.RejectedConditions, condition) then
						self.ComboIndex += 1
						return
					end
				end
			end

			if skillOptions.RequiredConditions then
				for i, required in skillOptions.RequiredConditions do
					if not table.find(conditions, required) then
						self.ComboIndex += 1
						return
					end
				end
			end

			if skill then
				self.ComboIndex += 1
				self.bot.Character.Spec:ActivateSkill(skill.Data.Id)
				return
			end
		end,

		Exit = function(self: BotState)
			self.ComboIndex = 1
			self.Combo = {}
			
			self.bot.Navigator:SetMovementStyle("direct")
		end,
	},

	Defending = {
		Enter = function(self: BotState)
			local spec = self.bot.Character.Spec
			self.bot.Navigator:SetMovementStyle("zigzag")
			self.bot.Navigator:SetHoldDistance(15)

			local conditions = self.bot:GetConditions() :: {BotsCharacters.SkillCondition}
			
			if table.find(conditions, "TARGET_IGNORE_BLOCK") then
				spec:ActivateSkill("Dash")
				return
			end
			
			if table.find(conditions, "TARGET_PERFECT_BLOCKABLE") then
				spec:ActivateSkill("Block")
			end

			if table.find(conditions, "TARGET_BLOCKABLE") then
				if spec.Skills["Block"]:IsOnCooldown() then
					spec:ActivateSkill("Dash")
				else
					spec:ActivateSkill("Block")
				end
			end
		end,

		Update = function(self: BotState)
			local spec = self.bot.Character.Spec
			local distance = (self.bot.Character.RootPart.Position - self.bot.Target.RootPart.Position).Magnitude
			local stun = self.bot.Target:GetParameter("Stun")
			
			if not self.bot.Target.Spec:CheckActiveSkills() then
				self.bot.StateMachine:ChangeState("Attacking")
				return
			end
			
		end,

		Exit = function(self: BotState)
			self.bot.Character.Spec:DeactivateSkill("Block")
			self.bot.Navigator:SetMovementStyle("direct")
			self.bot.Navigator:SetHoldDistance()
		end,
	},
}

local Bot = {}
Bot.__index = Bot

function Bot.SetTarget(self: Bot, character: types.Character)
	if self.Target == character then return end
	if not character.Spec then return end

	self.TargetCleaner:Clean()
	self.Target = character
	self.Navigator:SetTarget(character.RootPart)

	self.TargetCleaner:Add(character.Destroying:Once(function()
		self:ClearTarget()
	end))
	
	self.TargetCleaner:Add(Crane:GetService("CombatService").Casted:Connect(function(data: types.HitboxData)
		if data.Caster == self.Target then
			if table.find(data.Skill.Data.SkillCharacters, "Hit") then
				self.StateMachine:ChangeState("Defending")
			end
		end
	end))

	self.StateMachine:ChangeState("Attacking")
end

function Bot.GetCombo(self: Bot)
	return self.Config.Combos[rand:NextInteger(1, #self.Config.Combos)]
end

function Bot.GetConditions(self: Bot)
	local conditions: {BotsCharacters.SkillCondition} = {}
	local distance = (self.Target.RootPart.Position - self.Character.RootPart.Position).Magnitude
	local hasActiveSkill, activeSkills = self.Target.Spec:CheckActiveSkills()

	if self.Target:GetParameter("Armor") then
		table.insert(conditions, "TARGET_ARMORED")
	end

	local stun = self.Target:GetParameter("Stun")
	if stun and stun.Priority > Enums.Stun.None then
		table.insert(conditions, "TARGET_STUNNED")
	end

	if self.Target:GetParameter("Ragdoll") then
		table.insert(conditions, "TARGET_RAGDOLLED")
	end

	local block = self.Target.Block

	if block.Blocking then
		table.insert(conditions, "TARGET_BLOCKING")
	end

	if (os.clock() - block.PerfectBlockTime) <= block.PerfectBlockWindow then
		table.insert(conditions, "TARGET_PERFECT_BLOCKING")
	end

	for i, skill: types.Skill in activeSkills do
		if not skill.Data.SkillCharacters then continue end

		local data = skill.Data.SkillCharacters

		if table.find(data, "Hit") and not table.find(conditions, "TARGET_ATTACKING") then
			table.insert(conditions, "TARGET_ATTACKING")
		end

		if table.find(data, "PerfectBlockable") and not table.find(conditions, "TARGET_PERFECT_BLOCKABLE") then
			table.insert(conditions, "TARGET_PERFECT_BLOCKABLE")
		end

		if table.find(data, "Blockable") and not table.find(conditions, "TARGET_BLOCKABLE") then
			table.insert(conditions, "TARGET_BLOCKABLE")
		end

		if table.find(data, "IgnoreBlock") and not table.find(conditions, "TARGET_IGNORE_BLOCK") then
			table.insert(conditions, "TARGET_IGNORE_BLOCK")
		end
	end

	return conditions
end

function Bot.ClearTarget(self: Bot)
	self.TargetCleaner:Clean()
	self.StateMachine:ChangeState()
end

function Bot:Destroy()

end

return {
	new = function(character: types.Character, config: BotsCharacters.BotCharacterConfig)
		character:SetSpec(config.Spec)

		local navigator = NavigationController.new(character.instance, {
			ReachDistance = 5,
			HoldDistance = config.Aggressive < 0.5 and 20 or nil,
			ObstacleCheckDistance = 5,
			ObstacleCheckRadius = 4,
			PathRecalculateInterval = 5,
			PathRecalculateDistance = 15,
			AutoJump = true,
			RotateToTarget = true,
			Style = NavigationController.MovementStyles.direct,
			Debug = false,
		})

		local cleaner = character.Cleaner:Scope()
		cleaner:Set("Navigator", navigator)

		local stateMachine = StateMachine.new({
			CreateNoneState = false,	
		})

		cleaner:Add(stateMachine)

		local bot = setmetatable({
			Navigator = navigator,
			StateMachine = stateMachine,
			Config = config,
			Cleaner = cleaner,
			TargetCleaner = cleaner:Scope(),
			Target = nil,
			Character = character,
		}, Bot)

		bot.Character.Spec:ActivateSkill("Run")

		for name, state in States do
			local copy = table.clone(state)
			copy["bot"] = bot
			bot.StateMachine:AddState(name, copy)
		end

		cleaner:Add(character.OnTakeDamage:Connect(function(attacker, data)
			bot:SetTarget(attacker)
		end))

		return bot
	end	
}