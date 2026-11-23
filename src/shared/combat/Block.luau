--!strict

--- Чистый резолвер секции `AttackInfo.Block`.
---
--- Все пять флагов — независимые переключатели: каждый порождает своё состояние
--- атаки, и ни один не «проглатывает» соседний конфиг молча. Исключение —
--- `BlockIgnore`: это доминирующее правило, явно описанное ниже.
---
--- Модуль не трогает Roblox-глобалы, поэтому грузится и в `lune`, где его
--- покрывают табличные тесты из `tests/block.spec.luau`.

--- Полный конфиг блока атаки. Все поля обязательны: автор удара всегда
--- описывает все пять свойств, а не полагается на скрытые дефолты.
export type Config = {
	Blockable: boolean,
	PerfectBlockable: boolean,
	BlockBreak: boolean,
	BlockCancel: boolean,
	BlockIgnore: boolean,
}

--- Состояние цели в момент удара.
export type VictimState = {
	Blocking: boolean?,
	PerfectBlocking: boolean?,
}

export type Result = {
	Blocked: boolean,
	PerfectBlocked: boolean,
	BlockBroken: boolean,
	BlockCanceled: boolean,
	BlockIgnored: boolean,
	--- true: удар поглощён блоком — Damage/Restand/Stun/Knockback и т.п.
	--- должны быть сняты с `AttackInfo` до остальных хуков.
	Absorbed: boolean,
}

--- Дефолт для динамических конфигов, собранных без явного `Block`.
--- Намеренно ВСЕ false: чтобы получить блокируемый удар, его надо описать.
const DefaultBlock: Config = {
	Blockable = false,
	PerfectBlockable = false,
	BlockBreak = false,
	BlockCancel = false,
	BlockIgnore = false,
}

const function normalize(config: Config?): Config
	if not config then return DefaultBlock end

	return {
		Blockable = config.Blockable == true,
		PerfectBlockable = config.PerfectBlockable == true,
		BlockBreak = config.BlockBreak == true,
		BlockCancel = config.BlockCancel == true,
		BlockIgnore = config.BlockIgnore == true,
	}
end

--- Приоритеты результата (переходы заданы конфигом, а не порядком полей):
--- 1. Блок не зажат — никаких состояний блока.
--- 2. `BlockIgnore` — удар полностью игнорирует блок, остальные флаги не
---    порождают состояний (доминирующее правило).
--- 3. Перфектный блок против `PerfectBlockable` — парирование; `BlockBreak`
---    в этой ветке не срабатывает.
--- 4. Иначе `Blockable` даёт «удар в блок», а `BlockBreak` — слом стойки
---    независимо от `Blockable`.
--- 5. `BlockCancel` снимает стойку независимо от остальных флагов.
const function Resolve(config: Config?, victim: VictimState): Result
	const block = normalize(config)

	const result: Result = {
		Blocked = false,
		PerfectBlocked = false,
		BlockBroken = false,
		BlockCanceled = false,
		BlockIgnored = false,
		Absorbed = false,
	}

	if victim.Blocking ~= true then return result end

	if block.BlockIgnore then
		result.BlockIgnored = true
		return result
	end

	if victim.PerfectBlocking == true and block.PerfectBlockable then
		result.PerfectBlocked = true
		result.Absorbed = true
	else
		result.Blocked = block.Blockable
		result.BlockBroken = block.BlockBreak
		result.Absorbed = result.Blocked
	end

	result.BlockCanceled = block.BlockCancel

	return result
end

return {
	DefaultBlock = DefaultBlock,
	Resolve = Resolve,
}
