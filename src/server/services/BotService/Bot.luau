--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])
local Enums = require(ServerScriptService.server.Enums)
local types = require(ServerScriptService.server.types)

local NavigationController = require(script.Parent.NavigationController)
local SkillPriority = require(script.Parent.SkillPriority)
local StateMachine = require(script.Parent.NavigationController.StateMachine)

local Crane = require(ReplicatedStorage.shared.packages.Crane)

local rand = Random.new(tick())

--- Границы `TARGET_SHORT_RANGE` / `TARGET_MIDDLE_RANGE` / `TARGET_LARGE_RANGE`.
local RANGE_SHORT = 10
local RANGE_MIDDLE = 20

--- Замахивается ли цель: среди её активных скиллов есть хоть один с тегом `Hit`.
---
--- Одного факта «у цели что-то активно» мало: удерживаемый блок или отход не
--- атака, а проверка на них держала бота в отступлении навсегда.
local function IsTargetAttacking(target: types.Character): boolean
	local _, activeSkills = target.Spec:CheckActiveSkills()

	for _, skill in activeSkills do
		local data = skill.Data.SkillCharacters
		if data and table.find(data, "Hit") then return true end
	end

	return false
end

type BotProperities = {
	Target: types.Character?,
	Navigator: NavigationController.NavigationController,
	StateMachine: StateMachine.StateMachine,
	Config: BotsCharacters.BotCharacterConfig,
	Cleaner: typeof(Crane.Buttler.new()),
	TargetCleaner: typeof(Crane.Buttler.new()),
	Character: types.Character,

	Combo: BotsCharacters.SkillCombo,
	ComboIndex: number,

	--- Скилл, который бот сейчас держит (`Block`). Пока он активен, выбор скилла
	--- не идёт: либо его отпускает `HoldUntil`/`HoldWhile` (см.
	--- `SkillPriority.ShouldRelease`), либо он перестаёт быть активным сам.
	HeldSkill: string?,
}

type BotMethods = {
	SetTarget: (self: Bot, character: types.Character?) -> (),
	ClearTarget: (self: Bot) -> (),
	Think: (self: Bot) -> (),
	ReleaseSkill: (self: Bot) -> (),
	GetCombo: (self: Bot) -> BotsCharacters.SkillCombo,
	GetConditions: (self: Bot) -> { BotsCharacters.SkillCondition },
	Destroy: (self: Bot) -> (),
}

export type Bot = BotProperities & BotMethods

type BotState = StateMachine.State & { bot: Bot }

local States: { [string]: BotState } = {
	Attacking = {
		Enter = function(self: BotState)
			local chaoticMultiplier = self.bot.Config.Chaotic
			local isMelle = rand:NextNumber()
				< self.bot.Config.Aggressive + rand:NextNumber(0, chaoticMultiplier)
			local isBaiting = isMelle
				and (
					rand:NextNumber()
					< self.bot.Config.Agility + rand:NextNumber(0, chaoticMultiplier)
				)

			self.bot.Combo = self.bot:GetCombo()
			self.bot.ComboIndex = 1

			self.bot.Navigator:SetMovementStyle(if isBaiting then "zigzag" else "puma")
		end,

		Update = function(self: BotState)
			self.bot:Think()
		end,

		Exit = function(self: BotState)
			self.bot:ReleaseSkill()
			self.bot.Navigator:SetMovementStyle("direct")
		end,
	},

	Defending = {
		Enter = function(self: BotState)
			self.bot.Navigator:SetMovementStyle("zigzag")
			self.bot.Navigator:SetHoldDistance(15)
		end,

		Update = function(self: BotState)
			-- Отступать имеет смысл только пока цель реально замахивается.
			-- Проверка «есть ли активный скилл» застревала намертво: цель,
			-- удерживающая свой блок, активна сколько угодно.
			if not IsTargetAttacking(self.bot.Target) then
				self.bot.StateMachine:ChangeState("Attacking")
				return
			end

			self.bot:Think()
		end,

		Exit = function(self: BotState)
			self.bot:ReleaseSkill()
			self.bot.Navigator:SetMovementStyle("direct")
			self.bot.Navigator:SetHoldDistance()
		end,
	},
}

local function GetAverageValue(nums: { number })
	local summ = 0
	local count = 0

	for i, x in nums do
		summ += x
		count += 1
	end

	return summ / count
end

local Bot = {}
Bot.__index = Bot

--- Пустое комбо допустимо: тогда план не даёт бонуса никому и выбор целиком
--- определяется условиями.
local function GetRandomCombo(config: BotsCharacters.BotCharacterConfig): BotsCharacters.SkillCombo
	local combos = config.Combos
	if not combos or #combos == 0 then return {} end

	return combos[rand:NextInteger(1, #combos)]
end

function Bot.SetTarget(self: Bot, character: types.Character)
	if self.Target == character then return end
	if not character.Spec then return end

	self.TargetCleaner:Clean()
	self.Target = character
	self.Navigator:SetTarget(character.RootPart)

	self.TargetCleaner:Add(character.Destroying:Once(function()
		self:ClearTarget()
	end))

	local hitboxTracker: { [string]: { lastPos: Vector3, lastTime: number, lastDist: number } } = {}

	self.TargetCleaner:Add(
		Crane:GetService("CombatService").Casted:Connect(function(data: types.HitboxData)
			if data.Caster ~= self.Target then return end
			if not table.find(data.Skill.Data.SkillCharacters, "Hit") then return end

			local botPos = self.Character.RootPart.Position
			local hitboxPos = data.Info.Origin and data.Info.Origin.Position
				or (self.Target.RootPart.CFrame * data.Info.Offset).Position
			local hitboxSize = typeof(data.Info.Size) == "Vector3"
					and GetAverageValue({ data.Info.Size.X, data.Info.Size.Y, data.Info.Size.Z })
				or data.Info.Size
			local dist = (botPos - hitboxPos).Magnitude
			local skillId = data.Skill.Data.Id
			local now = os.clock()
			local isProjectile = table.find(data.Skill.Data.SkillCharacters, "Projectile")
			local track = hitboxTracker[skillId]

			local threshold = hitboxSize + (isProjectile and 30 or 8)

			local isThreat
			if track then
				isThreat = dist < track.lastDist and dist <= threshold
			else
				isThreat = dist <= threshold
			end

			hitboxTracker[skillId] = { lastPos = hitboxPos, lastTime = now, lastDist = dist }

			if not isThreat then return end

			self.StateMachine:ChangeState("Defending")

			-- `Casted` летит раньше, чем `CombatService:Attack` считает `GetStates`,
			-- где и решается, перфект-блок это или обычный. Поэтому выбор скилла
			-- делается прямо здесь: на следующем Heartbeat Block уже опоздает и
			-- попадёт мимо окна.
			--
			-- `task.spawn` нужен, потому что `Activate` уходит в yield: `Block`
			-- выставляет `PerfectBlockTime` до него, так что состояние успевает
			-- лечь до `GetStates`.
			task.spawn(function()
				self:Think()
			end)
		end)
	)

	self.StateMachine:ChangeState("Defending")
end

function Bot.GetCombo(self: Bot): BotsCharacters.SkillCombo
	return GetRandomCombo(self.Config)
end

--- Отпускает удерживаемый скилл. Вызывается при выходе из состояния и при
--- потере цели, чтобы бот не остался с зажатым блоком.
function Bot.ReleaseSkill(self: Bot)
	local held = self.HeldSkill
	self.HeldSkill = nil

	if not held then return end

	self.Character.Spec:DeactivateSkill(held)
end

--- Кандидаты на использование, без указанного скилла.
---
--- `Spec:GetAvailableSkills` не смотрит на `Active`, поэтому удерживаемый скилл
--- надо исключать вручную: иначе в проверке удержания он сравнивал бы сам с
--- собой и не отпускался никогда.
local function GetCandidates(spec: types.Spec, except: string?): { types.Skill }
	local available = spec:GetAvailableSkills()
	if not except then return available end

	local filtered: { types.Skill } = {}

	for _, skill in available do
		if skill.Data.Id ~= except then table.insert(filtered, skill) end
	end

	return filtered
end

--- Единая точка выбора скилла для обоих состояний: удержание, подсчёт
--- приоритетов, активация победителя и ведение комбо.
function Bot.Think(self: Bot)
	if not self.Target then return end

	local spec = self.Character.Spec
	local conditions = self:GetConditions()
	local distance = (self.Character.RootPart.Position - self.Target.RootPart.Position).Magnitude
	local combo = self.Combo
	local comboSkillId = combo[self.ComboIndex]

	-- Удерживаемый скилл проверяется каждый кадр: он держит, пока есть смысл
	-- держать. Если смысла нет — освобождает слот сразу же, в этом же кадре.
	if self.HeldSkill then
		local held = spec.Skills[self.HeldSkill]

		if not held or not held.Active then
			self.HeldSkill = nil
		else
			local rival = SkillPriority.Select(
				self.Config,
				GetCandidates(spec, self.HeldSkill),
				conditions,
				distance,
				comboSkillId
			)

			local shouldRelease = SkillPriority.ShouldRelease(
				self.Config,
				self.HeldSkill,
				conditions,
				rival and rival.Id
			)

			if not shouldRelease then return end

			self:ReleaseSkill()
		end
	end

	if spec:CheckActiveSkills() then return end

	local available = GetCandidates(spec)
	if #available == 0 then return end

	local best = SkillPriority.Select(self.Config, available, conditions, distance, comboSkillId)
	if not best then return end

	-- Отклонение от плана (выбран скилл вне комбо) индекс не сдвигает:
	-- комбо остаётся тем же, просто условия перебили его сейчас.
	if comboSkillId == best.Id then
		self.ComboIndex += 1

		if self.ComboIndex > #combo then
			self.ComboIndex = 1
			self.Combo = self:GetCombo()
		end
	end

	self.HeldSkill = best.Id
	spec:ActivateSkill(best.Id)
end

function Bot.GetConditions(self: Bot)
	local conditions: { BotsCharacters.SkillCondition } = {}
	local distance = (self.Target.RootPart.Position - self.Character.RootPart.Position).Magnitude
	local _, activeSkills = self.Target.Spec:CheckActiveSkills()

	if distance <= RANGE_SHORT then
		table.insert(conditions, "TARGET_SHORT_RANGE")
	elseif distance <= RANGE_MIDDLE then
		table.insert(conditions, "TARGET_MIDDLE_RANGE")
	else
		table.insert(conditions, "TARGET_LARGE_RANGE")
	end

	if self.Target:GetParameter("Armor") then table.insert(conditions, "TARGET_ARMORED") end

	local stun = self.Target:GetParameter("Stun")
	if stun and stun.Priority > Enums.Stun.None then table.insert(conditions, "TARGET_STUNNED") end

	if self.Target:GetParameter("Ragdoll") then table.insert(conditions, "TARGET_RAGDOLLED") end

	if self.Target:GetParameter("IFrames") >= Enums.IFrames.Dodge then
		table.insert(conditions, "TARGET_DODGING")
	end

	local block = self.Target.Block

	if block.Blocking then table.insert(conditions, "TARGET_BLOCKING") end

	if (os.clock() - block.PerfectBlockTime) <= block.PerfectBlockWindow then
		table.insert(conditions, "TARGET_PERFECT_BLOCKING")
	end

	for i, skill: types.Skill in activeSkills do
		if not skill.Data.SkillCharacters then continue end

		local data = skill.Data.SkillCharacters

		if table.find(data, "Hit") and not table.find(conditions, "TARGET_ATTACKING") then
			table.insert(conditions, "TARGET_ATTACKING")
		end

		-- Принимаются оба написания: `PerfectBlockable` из словаря и `PerfectBlock`
		-- из его значений. Второе сейчас не объявлено, но подстраховывает скиллы,
		-- написанные по значению, а не по ключу.
		local isPerfectBlockable = table.find(data, "PerfectBlockable")
			or table.find(data, "PerfectBlock")

		if isPerfectBlockable and not table.find(conditions, "TARGET_PERFECT_BLOCKABLE") then
			table.insert(conditions, "TARGET_PERFECT_BLOCKABLE")
		end

		if table.find(data, "Blockable") and not table.find(conditions, "TARGET_BLOCKABLE") then
			table.insert(conditions, "TARGET_BLOCKABLE")
		end

		if
			table.find(data, "IgnoreBlock") and not table.find(conditions, "TARGET_IGNORE_BLOCK")
		then
			table.insert(conditions, "TARGET_IGNORE_BLOCK")
		end
	end

	return conditions
end

function Bot.ClearTarget(self: Bot)
	self.TargetCleaner:Clean()
	self:ReleaseSkill()
	self.StateMachine:ChangeState("None")
	self.Navigator:ClearTarget()
end

function Bot:Destroy() end

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
			Debug = config.Debug or false,
		})

		local cleaner = character.Cleaner:Scope()
		cleaner:Set("Navigator", navigator)

		local stateMachine = StateMachine.new({
			CreateNoneState = true,
			ProhibitNullState = true,
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
			Combo = GetRandomCombo(config),
			ComboIndex = 1,
			HeldSkill = nil,
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
	end,
}
