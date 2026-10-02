local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crane = require(ReplicatedStorage.shared.packages.Crane)

local TerminalService = Crane:CreateService({
	Name = "TerminalService",
})

function TerminalService:onStart()
	local CmdrClient = ReplicatedStorage:WaitForChild("CmdrClient")
	local Cmdr = require(CmdrClient)

	-- `CmdrClient` регистрирует только то, что уже лежит в `CmdrClient/Commands`,
	-- а папку наполняет сервер — команда, объявленная там, на клиенте не появится.
	local SkillConstructorCommand =
		require(script.Parent.Parent.ui.components.SkillConstructor.Command)
	Cmdr.Registry:RegisterCommandObject(SkillConstructorCommand.cmdr)
end

return TerminalService
