const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")
const Mouse = Players.LocalPlayer:GetMouse()
const Camera = workspace.CurrentCamera

const LocalPlayer = Players.LocalPlayer
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)

const TargetLockService = Crane:CreateService({
	Name = "TargetLockService",
})

function TargetLockService:Lock()
	const humanoid = LocalPlayer.Character:FindFirstChild("Humanoid") :: Humanoid
	const root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart

	const target = Mouse.Target
	if not target then return end

	if (target.Position - root.Position).Magnitude > 50 then return end

	const targetHumanoid = target.Parent:FindFirstChild("Humanoid")
	if not targetHumanoid then return end

	const targetRoot = target.Parent:FindFirstChild("HumanoidRootPart") :: BasePart
	if not targetRoot then return end

	--hum.CameraOffset = Vector3.new(1.75,0,0) -- I assume this is about the right camera offset.
	humanoid.AutoRotate = false --Disable the automatic rotation since we are the ones setting it.

	RunService:BindToRenderStep(
		"ShiftLock",
		Enum.RenderPriority.Character.Value,
		function(deltaTime)
			if humanoid:GetState() == Enum.HumanoidStateType.Ragdoll then return end

			if not root or not targetRoot or not targetRoot.Parent then
				self:Unlock()
				return
			end
			if (targetRoot.Position - root.Position).Magnitude > 50 then
				self:Unlock()
				return
			end

			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter --Set the mouse to center every frame.

			root.CFrame = root.CFrame:Lerp(
				CFrame.new(
					root.Position,
					Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z)
				),
				deltaTime * 5
			) --Set the root part to the camera's rotation
		end
	)

	RunService:BindToRenderStep(
		"ShiftLockCamera",
		Enum.RenderPriority.Camera.Value + 5,
		function(deltaTime)
			if not root or not targetRoot or not targetRoot.Parent then
				self:Unlock()
				return
			end
			if (targetRoot.Position - root.Position).Magnitude > 50 then
				self:Unlock()
				return
			end

			const targetVector = (root.Position - targetRoot.Position).Unit
			Camera.CFrame = CFrame.new(root.Position, targetRoot.Position)
				:ToWorldSpace(CFrame.new(humanoid.CameraOffset + Vector3.new(3, 4, 14)))
		end
	)

	self.Locked = true
end

function TargetLockService:Unlock()
	const humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
	const root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

	humanoid.AutoRotate = true --Let the humanoid handle the camera rotations again.

	RunService:UnbindFromRenderStep("ShiftLock") -- Allow mouse to move freely.
	RunService:UnbindFromRenderStep("ShiftLockCamera")
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default

	self.Locked = false
end

function TargetLockService:onStart()
	self.Locked = false

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.ButtonSelect then
			if self.Locked then
				self:Unlock()
			else
				self:Lock()
			end
		end
	end)
end

return TargetLockService
