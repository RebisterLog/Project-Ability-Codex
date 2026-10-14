--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])

--- Подсчёт приоритета скиллов бота.
---
--- Модуль ничего не знает про `Spec`, `Skill` и состояние мира: на вход приходит
--- уже отфильтрованный список кандидатов (`Spec:GetAvailableSkills`), список
--- текущих условий цели и расстояние до неё. Всё остальное — чистая арифметика
--- по конфигу, поэтому её можно проверить без студии.

local DEFAULT_CONDITION_WEIGHT = 1
local DEFAULT_COMBO_WEIGHT = 1

--- Кандидат на использование. Нужен только идентификатор: всё остальное скорер
--- берёт из конфига. Структурно совместим с `types.Skill`, поэтому
--- `Spec:GetAvailableSkills()` можно передать как есть.
export type Candidate = {
	Data: {
		Id: string,
	},
}

export type ScoredSkill = {
	Id: string,
	Score: number,
}

local SkillPriority = {}

--- Вес одного мягкого условия для конкретного бота.
local function GetConditionWeight(config: BotsCharacters.BotCharacterConfig)
	return config.ConditionWeight or DEFAULT_CONDITION_WEIGHT
end

--- Сколько условий из списка сейчас выполнено.
local function CountMatched(
	list: { BotsCharacters.SkillCondition },
	conditions: { BotsCharacters.SkillCondition }
)
	local matched = 0

	for _, condition in list do
		if table.find(conditions, condition) then
			matched += 1
		end
	end

	return matched
end

--- Хотя бы одно из условий выполнено?
local function AnyMatched(
	list: { BotsCharacters.SkillCondition },
	conditions: { BotsCharacters.SkillCondition }
)
	for _, condition in list do
		if table.find(conditions, condition) then return true end
	end

	return false
end

--- Жёсткие группы: `RequiredConditions` должны быть выполнены все,
--- `ForbiddenConditions` — ни одного.
local function IsEligible(
	options: BotsCharacters.SkillPreference,
	conditions: { BotsCharacters.SkillCondition }
)
	local required = options.RequiredConditions
	if required then
		for _, condition in required do
			if not table.find(conditions, condition) then return false end
		end
	end

	local forbidden = options.ForbiddenConditions
	if forbidden then
		for _, condition in forbidden do
			if table.find(conditions, condition) then return false end
		end
	end

	return true
end

--- Бонус за попадание в мягкую полосу дистанции.
local function IsPreferredDistance(preferred: { Min: number?, Max: number? }, distance: number)
	local min = preferred.Min
	if min and distance < min then return false end

	local max = preferred.Max
	if max and distance > max then return false end

	return true
end

--- Приоритет одного скилла. `isCombo` — стоит ли он сейчас в плане.
---
--- Единственное место, где живёт арифметика: и выбор победителя, и проверка
--- удержания считают через неё, поэтому правила не могут разойтись.
function SkillPriority.Score(
	config: BotsCharacters.BotCharacterConfig,
	options: BotsCharacters.SkillPreference,
	conditions: { BotsCharacters.SkillCondition },
	distance: number,
	isCombo: boolean
): number
	local conditionWeight = GetConditionWeight(config)
	local score = options.Priority or 0

	local preferred = options.PreferredConditions
	if preferred then
		score += CountMatched(preferred, conditions) * conditionWeight
	end

	local penalty = options.PenaltyConditions
	if penalty then
		score -= CountMatched(penalty, conditions) * conditionWeight
	end

	local preferredDistance = options.PreferredDistance
	if preferredDistance and IsPreferredDistance(preferredDistance, distance) then
		score += conditionWeight
	end

	if isCombo then
		score += config.ComboWeight or DEFAULT_COMBO_WEIGHT
	end

	return score
end

--- Возвращает скилл с наибольшим приоритетом или `nil`, если ни один не подошёл.
---
--- `comboSkillId` — скилл, который сейчас стоит в плане: он получает `ComboWeight`,
--- а при равенстве очков побеждает всегда. Поэтому комбо остаётся основным
--- планом, и условия сдвигают его только когда дают строгое преимущество.
function SkillPriority.Select(
	config: BotsCharacters.BotCharacterConfig,
	candidates: { Candidate },
	conditions: { BotsCharacters.SkillCondition },
	distance: number,
	comboSkillId: string?
): ScoredSkill?
	local best: ScoredSkill? = nil
	local ties: { string } = {}

	for _, candidate in candidates do
		local id = candidate.Data.Id
		local options = config.Skills[id]
		if not options then continue end
		if not IsEligible(options, conditions) then continue end

		local maxDistance = options.Distance
		if maxDistance and distance > maxDistance then continue end

		local isCombo = comboSkillId ~= nil and id == comboSkillId
		local score = SkillPriority.Score(config, options, conditions, distance, isCombo)

		if not best or score > best.Score then
			best = { Id = id, Score = score }
			table.clear(ties)
			table.insert(ties, id)
		elseif score == best.Score then
			table.insert(ties, id)
		end
	end

	if not best then return nil end

	-- Ничья: план важнее условий, всё остальное разбирается случайно.
	for _, id in ties do
		if comboSkillId and id == comboSkillId then return { Id = id, Score = best.Score } end
	end

	return { Id = ties[math.random(1, #ties)], Score = best.Score }
end

--- Должен ли бот отпустить удерживаемый скилл прямо сейчас.
---
--- `bestId` — победитель подсчёта среди кандидатов БЕЗ удерживаемого скилла
--- (`nil`, если вариантов не осталось: тогда держаться есть смысла).
---
--- Порядок:
--- 1. сработал `HoldUntil` — аварийный релиз, ничего не считаем;
--- 2. задан `HoldWhile` — держим, пока есть хоть одно из условий;
--- 3. `HoldWhile` не задан — страховка пересчётом: отпускаем, как только скилл
---    перестал быть лучшим кандидатом. Если кандидатов не осталось (все на
---    кулдауне), держаться есть смысла, поэтому отпускать нечем.
---
--- Пустой список считается отсутствием поля: в Luau `{}` истинно, и без этой
--- проверки `HoldWhile = {}` означало бы «отпускать каждый кадр».
function SkillPriority.ShouldRelease(
	config: BotsCharacters.BotCharacterConfig,
	skillId: string,
	conditions: { BotsCharacters.SkillCondition },
	bestId: string?
): boolean
	local options = config.Skills[skillId]
	if not options then return true end

	local holdUntil = options.HoldUntil
	if holdUntil and #holdUntil > 0 and AnyMatched(holdUntil, conditions) then return true end

	local holdWhile = options.HoldWhile
	if holdWhile and #holdWhile > 0 then return not AnyMatched(holdWhile, conditions) end

	if bestId == nil then return false end

	return bestId ~= skillId
end

return SkillPriority
