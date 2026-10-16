const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Crane = require(ReplicatedStorage.shared.packages.Crane)

const TerminalService = Crane:CreateService({
	Name = "TerminalService",
})

function TerminalService:onStart()
	const CmdrClient = ReplicatedStorage:WaitForChild("CmdrClient")
	const Cmdr = require(CmdrClient)

	-- `CmdrClient` регистрирует только то, что уже лежит в `CmdrClient/Commands`,
	-- а папку наполняет сервер — команда, объявленная там, на клиенте не появится.
	const SkillConstructorCommand =
		require(script.Parent.Parent.ui.components.SkillConstructor.Command)
	Cmdr.Registry:RegisterCommandObject(SkillConstructorCommand.cmdr)
end

return TerminalService
