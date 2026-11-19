--!strict

--- Чистый резолвер секции `AttackInfo.Knockback`.
---
--- Модуль намеренно не трогает Roblox-глобалы в исполняемом коде: `Vector3` и
--- `CFrame` встречаются только в аннотациях (они стираются в рантайме), а все
--- вычисления идут по плоским `{ x, y, z }`. Благодаря этому резолвер грузится
--- и в `lune`, где этих типов нет, и его можно покрыть юнит-тестами.
---
--- Public-конфиг описывает намерение автора ("кого толкаем, как сильно, как
--- долго"), а `Build` превращает его в готовые Velocity/MaxForce/Hold/Stiffness.
--- Единственный источник дефолтов и пресетов — этот файл: его читают хук
--- и документация.

export type Vec3 = { x: number, y: number, z: number }

export type KnockbackAdd =
	| { Mode: "ToFront", Distance: number }
	| { Mode: "Custom", Vector: Vector3 }

export type KnockbackDirection =
	| { Mode: "AwayFromAttacker" | "TowardsAttacker", Add: { KnockbackAdd }? }
	| { Mode: "FromPoint", Point: CFrame, Add: { KnockbackAdd }? }
	| { Mode: "Custom", Vector: Vector3, Add: { KnockbackAdd }? }

export type KnockbackConfig = {
	Preset: ("Tap" | "Shove" | "Launch" | "Slam")?,
	Direction: KnockbackDirection?,
	-- Горизонтальная скорость вдоль `Direction`, studs/s.
	Push: number?,
	-- Вертикальная скорость, studs/s. Раньше это было `Velocity.Y`.
	Lift: number?,
	-- Время жизни mover'а. Это НЕ затухание: скорость константна до удаления.
	Hold: number?,
	-- Жёсткость BodyVelocity. Раньше это было `P`.
	Stiffness: number?,
	MaxForce: (Vector3 | "Auto")?,
}

export type Context = {
	Attacker: Vec3?,
	Target: Vec3?,
	AttackerLook: Vec3?,
}

export type Resolved = {
	Velocity: Vec3,
	MaxForce: Vec3,
	Hold: number,
	Stiffness: number,
}

type Config = {
	Preset: ("Tap" | "Shove" | "Launch" | "Slam")?,
	Direction: KnockbackDirection,
	Push: number,
	Lift: number,
	Hold: number,
	Stiffness: number,
	MaxForce: Vector3 | "Auto",
}

--- Пресеты задают только numbers. Направление ортогонально пресету: один и тот
--- же `Launch` может бить от атакующего, от точки взрыва или по явному вектору.
const Presets: { [string]: { Push: number, Lift: number, Hold: number } } = {
	Tap = { Push = 8, Lift = 0, Hold = 0.05 },
	Shove = { Push = 40, Lift = 0, Hold = 0.1 },
	Launch = { Push = 40, Lift = 50, Hold = 0.1 },
	Slam = { Push = 100, Lift = 20, Hold = 0.25 },
}

const ZERO: Vec3 = { x = 0, y = 0, z = 0 }
const AUTO_FORCE_XZ = 100_000

--- Принимает и Roblox `Vector3` (поля `X/Y/Z`), и плоский `{ x, y, z }` из тестов.
local function vec(value: any): Vec3?
	if type(value) ~= "table" then return nil end
	if type(value.x) == "number" then return { x = value.x, y = value.y or 0, z = value.z or 0 } end
	if type(value.X) == "number" then return { x = value.X, y = value.Y or 0, z = value.Z or 0 } end
	return nil
end

--- `CFrame` в конфиге нужен только для точки отсчёта, поэтому берём `Position`.
local function position(value: any): Vec3?
	if type(value) ~= "table" then return nil end
	if value.Position ~= nil then return vec(value.Position) end
	return vec(value)
end

local function add(a: Vec3, b: Vec3): Vec3
	return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }
end

local function sub(a: Vec3, b: Vec3): Vec3
	return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

local function scale(a: Vec3, factor: number): Vec3
	return { x = a.x * factor, y = a.y * factor, z = a.z * factor }
end

--- Нормализация делает `Push` честной скоростью: 40 — это 40 studs/s независимо
--- от дистанции между атакующим и целью. Раньше длина зависела от суммы
--- lookvector-ов, и два "направления" в конфиге молча удваивали толчок.
local function normalize(a: Vec3): Vec3
	const length = math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
	if length < 1e-6 then return { x = 0, y = 0, z = 0 } end
	return { x = a.x / length, y = a.y / length, z = a.z / length }
end

local function resolve(config: KnockbackConfig?): Config
	const preset = if config and config.Preset then Presets[config.Preset] else nil
	const presetPush = if preset then preset.Push else 0
	const presetLift = if preset then preset.Lift else 0
	const presetHold = if preset then preset.Hold else 0.1

	return {
		Preset = if config then config.Preset else nil,
		Direction = if config and config.Direction
			then config.Direction
			else { Mode = "AwayFromAttacker" },
		Push = if config and config.Push then config.Push else presetPush,
		Lift = if config and config.Lift then config.Lift else presetLift,
		Hold = if config and config.Hold then config.Hold else presetHold,
		-- Раньше клиентский эффект ставил math.huge, а server-fallback оставлял
		-- дефолт Roblox (200). Теперь обе ветви получают одно и то же значение.
		Stiffness = if config and config.Stiffness then config.Stiffness else math.huge,
		MaxForce = if config and config.MaxForce then config.MaxForce else "Auto",
	}
end

local function basis(direction: KnockbackDirection, ctx: Context): Vec3
	const mode = direction.Mode

	if mode == "AwayFromAttacker" or mode == "TowardsAttacker" then
		if not (ctx.Attacker and ctx.Target) then return ZERO end
		return normalize(
			if mode == "AwayFromAttacker"
				then sub(ctx.Target, ctx.Attacker)
				else sub(ctx.Attacker, ctx.Target)
		)
	elseif mode == "FromPoint" then
		const point = position((direction :: any).Point)
		if not (point and ctx.Target) then return ZERO end
		return normalize(sub(ctx.Target, point))
	end

	return normalize(vec((direction :: any).Vector) or ZERO)
end

--- `Add` — единственный разрешённый способ сложить направления. Каждый член
--- даёт raw-вектор поверх уже посчитанного `basis * Push`, поэтому его вклад
--- не зависит от скорости толчка и виден в конфиге как есть.
local function additions(direction: KnockbackDirection, ctx: Context): Vec3
	local result = ZERO

	for _, entry in (direction.Add or {}) :: { KnockbackAdd } do
		if entry.Mode == "ToFront" then
			if ctx.Attacker and ctx.Target and ctx.AttackerLook then
				const desired = add(ctx.Attacker, scale(ctx.AttackerLook, entry.Distance))
				result = add(result, sub(desired, ctx.Target))
			end
		else
			result = add(result, vec(entry.Vector) or ZERO)
		end
	end

	return result
end

local function autoMaxForce(lift: number): Vec3
	return {
		x = AUTO_FORCE_XZ,
		y = if math.abs(lift) > 1e-3 then AUTO_FORCE_XZ else 0,
		z = AUTO_FORCE_XZ,
	}
end

local Knockback = {
	Presets = Presets,
	Resolve = resolve,
}

--- Собирает всё, что нужно хуку, из конфига и позиций персонажей.
function Knockback.Build(config: KnockbackConfig?, ctx: Context): Resolved
	const cfg = resolve(config)
	const pushed = scale(basis(cfg.Direction, ctx), cfg.Push)
	const velocity = add(add(pushed, additions(cfg.Direction, ctx)), { x = 0, y = cfg.Lift, z = 0 })
	const maxForce = if cfg.MaxForce == "Auto"
		then autoMaxForce(cfg.Lift)
		else vec(cfg.MaxForce) or autoMaxForce(cfg.Lift)

	return {
		Velocity = velocity,
		MaxForce = maxForce,
		Hold = cfg.Hold,
		Stiffness = cfg.Stiffness,
	}
end

return Knockback
