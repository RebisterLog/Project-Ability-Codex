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

--- A stationary, invincible target for hit-validation playtests. Everything
--- that moves on its own starts attacking as soon as the bots wake up, so this
--- one is kept deliberately inert: no AI, no HealthChanged reset, WalkSpeed 0.
--- It must stay unanchored — Chrono only records snapshots for unanchored
--- entities, and without history there is nothing to rewind to.
const EnsureDummy = function()
	const live = workspace.Live
	const existing = live:FindFirstChild("Dummy")
	local dummy: Model?
	if existing and existing:IsA("Model") then
		dummy = existing
	else
		const source = live:FindFirstChild("Dummy1")
		if not source or not source:IsA("Model") then
			warn("TestService: no source rig available for the test Dummy")
			return
		end

		const clone = source:Clone()
		clone.Name = "Dummy"
		clone.Parent = live
		dummy = clone :: Model
	end
	if not dummy then return end
	const model = dummy :: Model

	const humanoid = model:FindFirstChildOfClass("Humanoid")
	const root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		warn("TestService: test Dummy is missing a Humanoid or HumanoidRootPart")
		return
	end

	model.PrimaryPart = root
	model:PivotTo(CFrame.new(20, 3, 20))
	root.Anchored = false
	humanoid.MaxHealth = 1e9
	humanoid.Health = 1e9
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false

	if not Crane:GetComponent("Character", model) then Crane:AddComponent(model, "Character") end
	Crane:GetService("ChronoService"):RegisterNPC(model)
end

function TestService:onStart()
	EnsureDummy()

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

			-- Give the dummy a Chrono entity so server-side hits can rewind it.
			Crane:GetService("ChronoService"):RegisterNPC(char.instance)
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
