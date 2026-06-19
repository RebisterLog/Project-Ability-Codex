local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local types = require(ServerScriptService.server.types)
local Configuration = ServerScriptService.server.Configuration

local TestService = Crane:CreateService({
	Name = "TestService",
	LoadOrder = 999,
})

local function HandleHealth(humanoid: Humanoid)
	humanoid.HealthChanged:Connect(function(health)
		humanoid.Health = humanoid.MaxHealth
	end)
end

local function HandleWatchHome(homePoint: Vector3, character: Model)
	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
	
	RunService.Heartbeat:Connect(function()
		if not humanoid or not rootPart then return end
		
		if (rootPart.Position - homePoint).Magnitude > 50 then
			humanoid:MoveTo(homePoint)
		end
	end)
end

function TestService:onStart()
	self.ChronoService = Crane:GetService("ChronoService")
	
	task.delay(3, function()
		local ATTACKING_DUMMY do
			local bot = workspace.Live["Attacking Dummy"]

			local char: types.Character = Crane:AddComponent(bot, "Character")
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
		
		local PB_DUMMY do
			local bot = workspace.Live["PB Dummy"]
			local char: types.Character = Crane:AddComponent(bot, "Character")
			char:SetSpec("Standless")

			char.Block["AlwaysPerfect"] = true
			
			RunService.Heartbeat:Connect(function()
				char.Spec:ActivateSkill("Block")
				task.wait()
			end)
			
			HandleHealth(char.Humanoid)
			HandleWatchHome(char.RootPart.Position, char.instance)
		end
		
		local BLOCKIMG_DUMMY do
			local bot = workspace.Live["Blocking Dummy"]
			local char: types.Character = Crane:AddComponent(bot, "Character")
			char:SetSpec("Standless")
			
			RunService.Heartbeat:Connect(function()
				char.Spec:ActivateSkill("Block")
				task.wait()
			end)
			
			HandleHealth(char.Humanoid)
			HandleWatchHome(char.RootPart.Position, char.instance)
		end
		
		local DEFAULT_DUMMY1 do
			local bot = workspace.Live["Dummy1"]
			local char: types.Character = Crane:AddComponent(bot, "Character")
			--char:SetSpec("Standless")
			--HandleHealth(char.Humanoid)
			--char.Spec:ActivateSkill("Run")
			--HandleWatchHome(char.RootPart.Position, char.instance)
			
			Crane:GetService("BotsService"):Instance("BasicWarrior", char)
		end
		
		local DEFAULT_DUMMY2 do
			local bot = workspace.Live["Dummy2"]
			local char: types.Character = Crane:AddComponent(bot, "Character")
			--char:SetSpec("Standless")
			HandleHealth(char.Humanoid)
			--char.Spec:ActivateSkill("Run")
			--HandleWatchHome(char.RootPart.Position, char.instance)

			Crane:GetService("BotsService"):Instance("BasicWarrior", char)
		end
		
		local GERSON do
			local bot = workspace.Live["Gerson"]
			local char: types.Character = Crane:AddComponent(bot, "Character")
			--char:SetSpec("Standless")
			--HandleHealth(char.Humanoid)
			--char.Spec:ActivateSkill("Run")
			--HandleWatchHome(char.RootPart.Position, char.instance)

			Crane:GetService("BotsService"):Instance("Gerson", char)
		end
		
		local Undyne do
			local bot = workspace.Live["Undyne"]
			local char: types.Character = Crane:AddComponent(bot, "Character")
			--char:SetSpec("Standless")
			--HandleHealth(char.Humanoid)
			--char.Spec:ActivateSkill("Run")
			--HandleWatchHome(char.RootPart.Position, char.instance)

			Crane:GetService("BotsService"):Instance("Undyne", char)
		end
	end)
end

return TestService