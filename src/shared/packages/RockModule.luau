local RockModule = {}
local TweenSerivce = game:GetService("TweenService")
local Players= game:GetService("Players")
local DebrisFolder


local function CheckDebrisFolder()
	if not workspace:FindFirstChild("Debris") then
		DebrisFolder = Instance.new("Folder")
		DebrisFolder.Name = "Debris"
		DebrisFolder.Parent = workspace
	else
		DebrisFolder = workspace:FindFirstChild("Debris")
	end
end



function RockModule.Crater(Center : CFrame, Radius : number, MinRocks : number, MaxRocks : number, PlayerCollision : boolean)
	Radius = Radius or 7
	MinRocks = MinRocks or 7
	MaxRocks = MaxRocks or 10
	if PlayerCollision == nil then
		PlayerCollision = true
	end
	
	
	CheckDebrisFolder()
	
	local raycastParams = RaycastParams.new()
	
	local players = {DebrisFolder}
	for i, v in pairs(Players:GetPlayers()) do
		local Character = v.Character
		if Character then
			table.insert(players, Character)
		end
	end
	for i, v in pairs(game.Workspace:GetDescendants()) do
		if game:GetService("CollectionService"):HasTag(v, "RockModuleIgnore") then
			table.insert(players, v)
		end
	end
	raycastParams.FilterDescendantsInstances = players
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true
	local ray = workspace:Raycast(Center.Position, Center.UpVector * -1000, raycastParams)
	
	if ray then
	local numRocks = math.round(math.random(MinRocks, MaxRocks))
		local distance = Radius
		local newCframe = CFrame.new(ray.Position)
		local angle = 0
		
		for i = 1, numRocks do
			local Rock = Instance.new("Part")
			Rock.Parent = DebrisFolder
			Rock.Name = "GroundSlam"
			Rock.Size = Vector3.new(math.random(3,5), math.random(2, 3), math.random(2,4))
			Rock.CFrame = newCframe * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0,0, -distance) + Vector3.new(0, -5, 0)
			Rock.CFrame = CFrame.lookAt(Rock.Position, ray.Position)
			local ray2 = workspace:Raycast(Rock.CFrame.Position + Vector3.new(0,7,0), Vector3.new(0,1,0) * -1000, raycastParams)
			if ray2 then
				Rock.Color = ray2.Instance.Color
				Rock.Material = ray2.Instance.Material
				Rock.Transparency = ray2.Instance.Transparency
				
			else
				Rock.Color = ray.Instance.Color
				Rock.Material = ray.Instance.Material
				Rock.Transparency = ray.Instance.Transparency
			end
			if PlayerCollision == false then
				Rock.CollisionGroup = "RockDebris"
			end
			
			Rock.Anchored = true
			
			Rock.CanCollide = true
			game:GetService("Debris"):AddItem(Rock, 30)
			local Tween = TweenSerivce:Create(Rock, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Position = Rock.Position + Vector3.new(0, 4.5, 0)})
			Tween:Play()
			task.spawn(function()
				task.wait(math.random(650, 950) / 100)
				local Tween = TweenSerivce:Create(Rock, TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Position = Rock.Position + Vector3.new(0, -5, 0), Size = Vector3.new(1,1,1)})
				Tween:Play()
			end)
			angle += 360/numRocks
		end
	end
	
end

function RockModule.Explosion(Center : CFrame, TotalRocks : number, MinSize : number, MaxSize : number, PlayerCollision : boolean)
	TotalRocks = TotalRocks or 7
	MinSize = MinSize or 0.5
	MaxSize = MaxSize or 2.5
	PlayerCollision = PlayerCollision or false
	
	local numOfRocks = TotalRocks
	CheckDebrisFolder()
	
	local raycastParams = RaycastParams.new()
	local players = {DebrisFolder}
	for i, v in pairs(Players:GetPlayers()) do
		local Character = v.Character
		if Character then
			table.insert(players, Character)
		end
	end
	for i, v in pairs(game.Workspace:GetDescendants()) do
		if game:GetService("CollectionService"):HasTag(v, "RockModuleIgnore") then
			table.insert(players, v)
		end
	end
	raycastParams.FilterDescendantsInstances = players
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true

	local ray = workspace:Raycast(Center.Position, Center.UpVector * -100, raycastParams)
	
	if ray then
		for i = 1, numOfRocks do
			local Rock = Instance.new("Part")
			Rock.Name = "ExplosionPart"
			Rock.Parent = DebrisFolder
			
			local RandomSize = (math.random(MinSize * 100, MaxSize * 100)) / 100.0
			if math.random(1, 5) == 3 then
				Rock.Size = Vector3.new(RandomSize * 2, 0.15, RandomSize * 2)
			else
				Rock.Size = Vector3.new(RandomSize, RandomSize, RandomSize)
			end
			
			Rock.CFrame = Center
			Rock.Color = ray.Instance.Color
			Rock.Material = ray.Instance.Material
			Rock.Anchored = false
			Rock.Orientation = Vector3.new(math.random(-359, 359),math.random(-359, 359),math.random(-359, 359))
			Rock.Transparency = ray.Instance.Transparency
			Rock.CanCollide = true
			if PlayerCollision == false then
				Rock.CollisionGroup = "RockDebris"
			end
			
			
			game:GetService("Debris"):AddItem(Rock, 4.5)
			
			local velocitySpread = 32 
			local upwardForce = 22
			local velocity = Vector3.new(math.random(-velocitySpread, velocitySpread),upwardForce,math.random(-velocitySpread, velocitySpread))
			local bodyVelocity = Instance.new("BodyVelocity")
		
			bodyVelocity.Velocity = velocity
			bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			bodyVelocity.P = 5000
			bodyVelocity.Parent = Rock
			
			game:GetService("Debris"):AddItem(bodyVelocity, 0.25)
			task.spawn(function()
				task.wait(4)
				local Tween = TweenSerivce:Create(Rock, TweenInfo.new(0.75, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {Size = Vector3.new(0.1,0.1,0.1), Transparency = 1}):Play()	
			end)
		end
	end
end

function RockModule.CraterRows(Center : CFrame, Radius : number, Rows: number, NextRowRadius : number, MinRocks : number, MaxRocks : number, PlayerCollision : boolean)
	if PlayerCollision == nil then
		PlayerCollision = true
	end
	Radius = Radius or 7
	MinRocks = MinRocks or 7
	MaxRocks = MaxRocks or 10
	Rows = Rows or 3
	NextRowRadius = NextRowRadius or 4
	local currentRadius = Radius
	for i = 1, Rows do
		RockModule.Crater(Center, currentRadius, MinRocks * i, MaxRocks * i, PlayerCollision)
		currentRadius += NextRowRadius
	end
end

function RockModule.ClearDebris(Fade : boolean)
	CheckDebrisFolder()
	
	if Fade then
		for i, v in pairs(DebrisFolder:GetChildren()) do
			if v:IsA("BasePart") then
				local Tween = TweenSerivce:Create(v, TweenInfo.new(0.75, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {Size = Vector3.new(0.1,0.1,0.1), Transparency = 1}):Play()	
				game:GetService("Debris"):AddItem(v, 1)
				
			end
		end
	else
		for i, v in pairs(DebrisFolder:GetChildren()) do
			v:Destroy()
		end
	end
end



return RockModule