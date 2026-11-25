const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Crane = require(ReplicatedStorage.shared.packages.Crane)

const TerminalService = Crane:CreateService({
	Name = "TerminalService",
})

function TerminalService:onStart()
	-- Команды Cmdr приходят из ReplicatedStorage.CmdrClient, который создаёт
	-- серверная часть (Initialize.luau). Ждём папку перед require — это и
	-- включает обработчик F2 и клонирование GUI в PlayerGui.
	const CmdrClient = ReplicatedStorage:WaitForChild("CmdrClient")
	require(CmdrClient)
end

return TerminalService
