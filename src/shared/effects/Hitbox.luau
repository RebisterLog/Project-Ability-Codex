local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationActor = game.Players.LocalPlayer.PlayerScripts.client.Animations
local Skins = require(ReplicatedStorage.shared.configs.Skins)

local Hitbox = {}

function Hitbox:onStart(Origin: CFrame, Size: Vector3 | number)
	local Part = Instance.new("Part")
	Part.CFrame = Origin
	Part.Anchored = true
	Part.CanCollide = false
	Part.CanTouch = false
	Part.CanQuery = false
	Part.Color = Color3.new(1,0,0)
	Part.Material = Enum.Material.ForceField
	Part.CastShadow = false
	
	if typeof(Size) == "number" then
		Part.Shape = Enum.PartType.Ball
		Part.Size = Vector3.new(Size, Size, Size) * 2
	elseif typeof(Size) == "Vector3" then
		Part.Size = Size
	end
	
	task.delay(0.2, Part.Destroy, Part)
	Part.Parent = workspace.Effects
end

return Hitbox