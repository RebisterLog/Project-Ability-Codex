--- Точка входа в пакет конструктора: типизированный фасад для игрового кода.
---
--- `types`, `registry`, `codec`, `validator` и `emitter` лежат в пакете рядом, но
--- `registry` намеренно ничего не `require`-ит — иначе он перестал бы грузиться в
--- `lune`, а на нём работает `tools/generate-skill.luau` (§3, §11). Поэтому типы
--- подключаются здесь, а в `lune` доступ к модулям идёт напрямую:
---
--- ```lua
--- local registry = require("../src/shared/packages/SkillConstructor/registry")
--- local codec = require("../src/shared/packages/SkillConstructor/codec")
--- local validator = require("../src/shared/packages/SkillConstructor/validator")
--- local emitter = require("../src/shared/packages/SkillConstructor/emitter")
--- ```
---
--- `codec` сам по себе environment-agnostic: строковое JSON-кодирование делает
--- вызывающий код (`HttpService` в игре, `serde` в CLI), а `toTagged`/`fromTagged`
--- в `lune` не трогают Roblox-типы, которых там нет.
---
--- `validator` тоже грузится в `lune`: `validateStructural` не обращается к
--- `game`, а `validateAgainstSpec` требует `bot-characters` лениво, уже
--- внутри функции — иначе импорт падал бы ещё до вызова (§9).
---
--- `emitter` не требует `registry`: список блоков и их свойства он читает из
--- самого blueprint, а Roblox-конструкторы (`Vector3.new`, `Color3.fromRGB`)
--- просит вызывающий код уже в виде строк. Поэтому `emitter` одинаково грузится
--- в UI, в CLI и в тестах (§10).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Package = ReplicatedStorage.shared.packages.SkillConstructor

return {
	types = require(Package.types),
	registry = require(Package.registry),
	codec = require(Package.codec),
	validator = require(Package.validator),
	emitter = require(Package.emitter),
}
