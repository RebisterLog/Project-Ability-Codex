-- Мост между Cmdr-командой `skillconstructor` и роутером UI.
--
-- Клиентскую команду нельзя объявить модулем в `CmdrClient/Commands`: папку
-- наполняет сервер (`TerminalService` переносит туда `terminal-commands` и
-- встроенные команды), а клиент сканирует её один раз — в момент `require`
-- `CmdrClient`. Если сервер не успел, в клиентском реестре не остаётся ни одной
-- команды. Поэтому команда регистрируется на клиенте явно, а роутер сюда
-- отдаётся обработчиком из фабрики `main.luau`.

const Command = {}

export type CmdrCommand = {
	Name: string,
	Aliases: { string },
	Description: string,
	Group: string,
	Args: { any },
	ClientRun: (any) -> string,
}

export type OpenHandler = () -> string

local openHandler: OpenHandler? = nil

function Command.setHandler(handler: OpenHandler)
	openHandler = handler
end

function Command.open(): string
	if not openHandler then
		return "Конструктор скиллов ещё не инициализирован"
	end

	return openHandler()
end

--- Определение команды для `Registry:RegisterCommandObject`: Cmdr не поставляет
--- типы, а реестр отвергает неизвестные ключи уже в рантайме
--- (`Unknown key/method in command`), поэтому контракт повторяем здесь.
const cmdr: CmdrCommand = {
	Name = "skillconstructor",
	Aliases = { "skc" },
	Description = "Открыть конструктор скиллов",
	Group = "Utility",

	Args = {},

	ClientRun = function()
		return Command.open()
	end,
}

Command.cmdr = cmdr

return Command
