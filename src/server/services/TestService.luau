const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)
const Configuration = ServerScriptService.server.Configuration

const TestService = Crane:CreateService({
	Name = "TestService",
	LoadOrder = 999,
})

const HandleHealth = function(humanoid: Humanoid)
	humanoid.HealthChanged:Connect(function(health)
		humanoid.Health = humanoid.MaxHealth
	end)
end

const HandleWatchHome = function(homePoint: Vector3, character: Model)
	const humanoid = character:FindFirstChild("Humanoid") :: Humanoid
	const rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart

	RunService.Heartbeat:Connect(function()
		if not humanoid or not rootPart then return end

		if (rootPart.Position - homePoint).Magnitude > 50 then humanoid:MoveTo(homePoint) end
	end)
end

function TestService:onStart()
	task.delay(3, function()
		local ATTACKING_DUMMY
		do
			const bot = workspace.Live["Attacking Dummy"]

			const char: types.Character = Crane:AddComponent(bot, "Character")
			char:SetSpec("Standless")

			char.Spec.Data.Assets.Sounds["UppercutVL"].Volume = 0.05

			RunService.Heartbeat:Connect(function()
				char.Spec:ActivateSkill("Uppercut")
				task.wait()
			end)

			HandleHealth(char.Humanoid)
			HandleWatchHome(char.RootPart.Position, char.instance)

			--self.ChronoService:RegisterNPC("NPC", char)
		end

		local PB_DUMMY
		do
			const bot = workspace.Live["PB Dummy"]
			const char: types.Character = Crane:AddComponent(bot, "Character")
			char:SetSpec("Standless")

			char.Block["AlwaysPerfect"] = true

			RunService.Heartbeat:Connect(function()
				char.Spec:ActivateSkill("Block")
				task.wait()
			end)

			HandleHealth(char.Humanoid)
			HandleWatchHome(char.RootPart.Position, char.instance)
		end

		local BLOCKIMG_DUMMY
		do
			const bot = workspace.Live["Blocking Dummy"]
			const char: types.Character = Crane:AddComponent(bot, "Character")
			char:SetSpec("Standless")

			RunService.Heartbeat:Connect(function()
				char.Spec:ActivateSkill("Block")
				task.wait()
			end)

			HandleHealth(char.Humanoid)
			HandleWatchHome(char.RootPart.Position, char.instance)
		end

		local DEFAULT_DUMMY1
		do
			const bot = workspace.Live["Dummy1"]
			const char: types.Character = Crane:AddComponent(bot, "Character")
			--char:SetSpec("Standless")
			--HandleHealth(char.Humanoid)
			--char.Spec:ActivateSkill("Run")
			--HandleWatchHome(char.RootPart.Position, char.instance)

			Crane:GetService("BotsService"):Instance("BasicWarrior", char)
		end

		local DEFAULT_DUMMY2
		do
			const bot = workspace.Live["Dummy2"]
			const char: types.Character = Crane:AddComponent(bot, "Character")
			--char:SetSpec("Standless")
			HandleHealth(char.Humanoid)
			--char.Spec:ActivateSkill("Run")
			--HandleWatchHome(char.RootPart.Position, char.instance)

			Crane:GetService("BotsService"):Instance("BasicWarrior", char)
		end
	end)
end

return TestService
