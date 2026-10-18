const HttpService = game:GetService("HttpService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Codec = require(ReplicatedStorage.shared.packages.SkillConstructor.codec)
const Emitter = require(ReplicatedStorage.shared.packages.SkillConstructor.emitter)
const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const Registry = require(ReplicatedStorage.shared.packages.SkillConstructor.registry)
const Validator = require(ReplicatedStorage.shared.packages.SkillConstructor.validator)

const peek = Fusion.peek

--- Разворачивает `Children` в плоский список: все блоки blueprint'а в одном массиве,
--- где `ParentId` позволяет таймлайну построить дерево, а футеру — посчитать
--- количество без обхода вложенности.
local function flattenChildren(children: any, parentId: string?, out: { any })
	if type(children) ~= "table" then return out end

	for _, list in children do
		if type(list) == "table" then
			for _, child in list do
				if type(child) == "table" then
					table.insert(out, { Block = child, ParentId = parentId })
					flattenChildren(child.Children, child.Id, out)
				end
			end
		end
	end

	return out
end

const collectBlocks = function(blueprint: any): { any }
	const result = {}

	if type(blueprint.Blocks) == "table" then
		for _, block in blueprint.Blocks do
			table.insert(result, { Block = block, ParentId = nil })
			flattenChildren(block.Children, block.Id, result)
		end
	end

	return result
end

--- Ищет блок по `Id` и возвращает вместе с ним тот массив, в котором он лежит, и
--- блок-родителя. Вложенные дети лежат в слотах (`Children = { OnSuccess = { ... } }`),
--- поэтому «родительский список» и `bp.Blocks` — разные вещи, а без него удаление,
--- дублирование и перенос в другой слот искали бы блок не там.
const findBlock = function(blueprint: any, id: string): (any?, { any }?, number?, any?)
	if type(blueprint.Blocks) ~= "table" then return nil, nil, nil, nil end

	local function search(list: { any }, parent: any?): (any?, { any }?, number?, any?)
		if type(list) ~= "table" then return nil, nil, nil, nil end

		for index, block in list do
			if type(block) == "table" then
				if block.Id == id then return block, list, index, parent end
				if type(block.Children) == "table" then
					for _, children in block.Children do
						const found, foundList, foundIndex, foundParent = search(children, block)
						if found ~= nil then return found, foundList, foundIndex, foundParent end
					end
				end
			end
		end

		return nil, nil, nil, nil
	end

	return search(blueprint.Blocks, nil)
end

--- Локальный GUID блока или слота. `HttpService:GenerateGUID` содержит дефисы, но
--- не символы, запрещённые в имени файла Windows, поэтому префикс фиксирован, а
--- тело обрезано: в `PlacedBlock.Id` длиннее 14 символов смысла не нести.
const newLocalId = function(prefix: string): string
	return prefix .. string.gsub(HttpService:GenerateGUID(false), "-", ""):sub(1, 12)
end

const clampFrame = function(value: number): number
	return math.clamp(math.floor(value), 0, 100000)
end

return function(scope: Fusion.Scope)
	--- Стартовый blueprint берётся из `codec`: `SkillCharacters` с `Hit` и текущая
	--- версия проставлены там по умолчанию (§4), поэтому собственный «пустой» скилл
	--- в UI означал бы второй источник правды о том, что считается новым скиллом.
	const blueprintValue = scope:Value(Codec.newBlueprint("NewSkill", "New Skill"))

	--- Счётчик мутаций.
	---
	--- Fusion сравнивает новое значение со старым по сходству, а мутации правят
	--- blueprint на месте: без ревизии `Value:set` счёл бы изменение отсутствием и
	--- зависимые не пересчитывались — правка поля не отражалась бы ни в таймлайне,
	--- ни в панели свойств. Ревизия попадает в производные таблицы, и они
	--- гарантированно отличаются от предыдущих.
	const revision = scope:Value(0)

	const bump = function()
		revision:set(peek(revision) + 1)
	end

	const selectedId = scope:Value(nil :: string?)
	const zoom = scope:Value(6)
	const playhead = scope:Value(0)
	const rightTab = scope:Value("Block")
	const previewTab = scope:Value("Frames")
	const modified = scope:Value(false)
	const searchQuery = scope:Value("")
	const collapsed = scope:Value({} :: { [string]: boolean })
	const specName = scope:Value("Standless")
	const skinName = scope:Value("None")
	const importError = scope:Value(nil :: string?)

	--- Открыта ли панель обмена JSON. Живёт в состоянии, потому что от неё зависят
	--- высота тулбара и верх рабочей области: одно поле решает обе задачи и не даёт
	--- им разойтись.
	const panelVisible = scope:Value(false)

	--- Блок, для которого открыто контекстное меню, и позиция меню. Меню одно на
	--- страницу, поэтому и цель, и координаты — состояние.
	const contextBlockId = scope:Value(nil :: string?)
	const contextPosition = scope:Value(UDim2.fromOffset(0, 0))

	--- Любая мутация проходит через неё: blueprint перезаписывается целиком, и все
	--- производные ниже пересчитываются сами. `recompute()` вручную не нужен и не
	--- мог бы не забыться — забытый вызов дал бы футер, противоречащий таймлайну.
	const touch = function(blueprint: any)
		blueprintValue:set(blueprint)
		modified:set(true)
		bump()
	end

	const structural = scope:Computed(function(use)
		return Validator.validateStructural(use(blueprintValue))
	end)

	const blocks = scope:Computed(function(use)
		const current = use(revision)
		const result = collectBlocks(use(blueprintValue))

		for _, item in result do
			item.Revision = current
		end

		return result
	end)

	const json = scope:Computed(function(use)
		return Codec.encode(use(blueprintValue))
	end)

	const preview = scope:Computed(function(use)
		return Emitter.preview(use(json))
	end)

	const maxFrame = scope:Computed(function(use)
		return Emitter.maxFrame(use(json))
	end)

	const framesSource = scope:Computed(function(use)
		return Emitter.framesSource(use(json))
	end)

	const source = scope:Computed(function(use)
		return Emitter.emit(use(json)).Source
	end)

	const emitterErrors = scope:Computed(function(use)
		return Emitter.emit(use(json)).Errors
	end)

	return {
		--- Исходное состояние.
		Blueprint = blueprintValue,
		SelectedId = selectedId,
		Zoom = zoom,
		Playhead = playhead,
		RightTab = rightTab,
		PreviewTab = previewTab,
		Modified = modified,
		SearchQuery = searchQuery,
		Collapsed = collapsed,
		SpecName = specName,
		SkinName = skinName,
		ImportError = importError,
		panelVisible = panelVisible,
		contextBlockId = contextBlockId,
		contextPosition = contextPosition,

		--- Текст для `Export JSON`: ровно то, что ждёт CLI (§11), собирается из
		--- того же `codec.encode`, поэтому файл и буфер обмена не расходятся.
		ExportText = scope:Computed(function(use)
			return HttpService:JSONEncode(use(json))
		end),

		--- Производное состояние: футер, таймлайн, рамки предупреждений и PreviewTab
		--- читают только их и не знают, кто и когда менял blueprint.
		Structural = structural,
		Blocks = blocks,
		Json = json,
		revision = revision,
		Preview = preview,
		MaxFrame = maxFrame,
		FramesSource = framesSource,
		Source = source,
		EmitterErrors = emitterErrors,

		registry = Registry,
		peekBlueprint = function(): any
			return peek(blueprintValue)
		end,

		--- Текущий зум нужен перетаскиванию: пересчёт идёт от дельты мыши в пикселях,
		--- поэтому без него блок уезжал бы не туда.
		peekZoom = function(): number
			return peek(zoom)
		end,

		--- Прямой доступ к блоку для drag-обработчиков и панели свойств: blueprint
		--- передаётся явно, иначе чтение состояния внутри `Computed` сделало бы его
		--- зависимым от значений, которые он не объявил через `use`.
		findBlock = function(blueprint: any, id: string): any?
			return findBlock(blueprint, id)
		end,

		reset = function()
			blueprintValue:set(Codec.newBlueprint("NewSkill", "New Skill"))
			bump()
			selectedId:set(nil)
			collapsed:set({})
			importError:set(nil)
			modified:set(false)
		end,

		setField = function(field: string, value: any)
			const blueprint = peek(blueprintValue)
			blueprint[field] = value
			touch(blueprint)
		end,

		toggleSkillCharacter = function(tag: string)
			const blueprint = peek(blueprintValue)
			const list = blueprint.SkillCharacters or {}
			const index = table.find(list, tag)

			if index ~= nil then
				table.remove(list, index)
			else
				table.insert(list, tag)
			end

			blueprint.SkillCharacters = list
			touch(blueprint)
		end,

		--- Блок появляется там, где стоит playhead: палитра не должна уводить
		--- пользователя в начало таймлайна каждый раз.
		addBlock = function(blockType: string)
			const blueprint = peek(blueprintValue)
			const startFrame = clampFrame(peek(playhead))
			const block = {
				Id = newLocalId("b"),
				Type = blockType,
				StartFrame = startFrame,
				Properties = {},
			}

			if blockType == "Repeat" then
				block.EndFrame = startFrame + 30
				block.Children = { Body = {} }
			end

			table.insert(blueprint.Blocks, block)
			blueprintValue:set(blueprint)
			selectedId:set(block.Id)
			modified:set(true)
			bump()
		end,

		removeBlock = function(id: string)
			const blueprint = peek(blueprintValue)
			const _, list, index = findBlock(blueprint, id)
			if list == nil or index == nil then return end

			table.remove(list, index)
			touch(blueprint)
			if peek(selectedId) == id then selectedId:set(nil) end
		end,

		duplicateBlock = function(id: string)
			const blueprint = peek(blueprintValue)
			const block, list, index = findBlock(blueprint, id)
			if block == nil or list == nil or index == nil then return end

			const clone = table.clone(block)
			clone.Id = newLocalId("b")

			if type(clone.Children) == "table" then clone.Children = table.clone(clone.Children) end

			table.insert(list, index + 1, clone)
			blueprintValue:set(blueprint)
			selectedId:set(clone.Id)
			modified:set(true)
			bump()
		end,

		setStartFrame = function(id: string, frame: number)
			const blueprint = peek(blueprintValue)
			const block = findBlock(blueprint, id)
			if block == nil then return end

			block.StartFrame = clampFrame(frame)
			touch(blueprint)
		end,

		--- `EndFrame` обязан быть строго больше `StartFrame`: иначе эмиттер и
		--- валидатор жаловались бы на один и тот же блок двумя разными кодами.
		setEndFrame = function(id: string, frame: number)
			const blueprint = peek(blueprintValue)
			const block = findBlock(blueprint, id)
			if block == nil then return end

			block.EndFrame = math.max(clampFrame(frame), (block.StartFrame or 0) + 1)
			touch(blueprint)
		end,

		--- `nil` убирает поле: панель снова покажет серый дефолт вместо значения,
		--- а эмиттер перестанет печатать это поле вовсе.
		setProperty = function(id: string, name: string, value: any)
			const blueprint = peek(blueprintValue)
			const block = findBlock(blueprint, id)
			if block == nil then return end

			block.Properties = block.Properties or {}
			if value == nil then
				block.Properties[name] = nil
			else
				block.Properties[name] = value
			end

			touch(blueprint)
		end,

		--- Перенос блока в другой слот того же родителя: слоты контейнера заданы
		--- реестром, а блок, оставшийся в чужом слоте, эмиттер бы не увидел.
		moveBlockToSlot = function(id: string, slot: string)
			const blueprint = peek(blueprintValue)
			const block, list, index, parent = findBlock(blueprint, id)
			if block == nil or list == nil or index == nil or parent == nil then return end

			const allowed = Registry.getSlots(parent.Type)
			if table.find(allowed, slot) == nil then return end

			table.remove(list, index)
			parent.Children[slot] = parent.Children[slot] or {}
			table.insert(parent.Children[slot], block)
			touch(blueprint)
		end,

		addSlot = function()
			const blueprint = peek(blueprintValue)
			const slot = {
				Id = newLocalId("s"),
				Name = "NewSlot",
				AnimationId = "",
				Speed = 1,
				FadeTime = 0.2,
			}
			table.insert(blueprint.AnimationSlots, slot)
			blueprintValue:set(blueprint)
			modified:set(true)
			bump()
		end,

		removeSlot = function(slotId: string)
			const blueprint = peek(blueprintValue)
			for index, slot in blueprint.AnimationSlots do
				if slot.Id == slotId then
					table.remove(blueprint.AnimationSlots, index)
					break
				end
			end

			touch(blueprint)
		end,

		setSlot = function(slotId: string, field: string, value: any)
			const blueprint = peek(blueprintValue)
			for _, slot in blueprint.AnimationSlots do
				if slot.Id == slotId then
					slot[field] = value
					break
				end
			end

			touch(blueprint)
		end,

		selectBlock = function(id: string?)
			selectedId:set(id)
		end,

		toggleCollapsed = function(id: string)
			const map = peek(collapsed)
			const copy = {}
			for key, value in map do
				copy[key] = value
			end
			copy[id] = not copy[id]
			collapsed:set(copy)
		end,

		setZoom = function(value: number)
			zoom:set(math.clamp(value, 1, 8))
		end,

		setPlayhead = function(value: number)
			playhead:set(clampFrame(value))
		end,

		setPanelVisible = function(value: boolean)
			panelVisible:set(value)
		end,

		setContextBlockId = function(id: string?)
			contextBlockId:set(id)
		end,

		openContextMenu = function(id: string, position: UDim2)
			contextPosition:set(position)
			contextBlockId:set(id)
		end,

		importCurrent = function(text: string): boolean
			return importJson(text)
		end,

		setSearchQuery = function(value: string)
			searchQuery:set(value)
		end,

		setRightTab = function(value: string)
			rightTab:set(value)
		end,

		setPreviewTab = function(value: string)
			previewTab:set(value)
		end,

		setSpecName = function(value: string)
			specName:set(value)
		end,

		setSkinName = function(value: string)
			skinName:set(value)
		end,

		--- Импорт из буфера обмена. `codec.decode` отвергает файл из будущей версии,
		--- структурная проверка — контракт, поэтому сломанный файл в редактор не
		--- попадает, а пользователь видит первую ошибку, а не список из двадцати.
		importJson = function(text: string)
			const ok, result = pcall(function()
				return Codec.decode(HttpService:JSONDecode(text))
			end)

			if not ok or type(result) ~= "table" then
				importError:set("Не удалось разобрать JSON: " .. tostring(result))
				return false
			end

			const result2 = Validator.validateStructural(result)
			if #result2.errors > 0 then
				importError:set(
					`Структурных ошибок: {#result2.errors} — {result2.errors[1].Message}`
				)
				bump()
				return false
			end

			blueprintValue:set(result)
			selectedId:set(nil)
			collapsed:set({})
			importError:set(nil)
			modified:set(false)
			return true
		end,

		--- Экспорт отдаёт ровно ту JSON-форму, которую ждёт CLI (§11): тот же
		--- `codec.encode`, без приукрашиваний и без версии, которой нет.
		exportJson = function(): string
			return HttpService:JSONEncode(peek(json))
		end,
	}
end
