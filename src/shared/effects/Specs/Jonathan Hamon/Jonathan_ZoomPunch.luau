const ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
const Assets = ReplicatedStorage.assets.Default
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const ForgeVFX = require(ReplicatedStorage.shared.packages.ForgeVFX)

type StartData = {
    Reference: Folder,
	Character: Model?,
    Length: number,
}

return {
	onStart = function(self, data: StartData)
        if not ( data.Character and data.Character.Parent ) then
            return
        end
        if not ( data.Reference and data.Reference.Parent ) then
            return
        end

        local Character = data.Character
        local Arm = Character:FindFirstChild("Right Arm") :: BasePart

        if not ( Arm ) then
            return
        end

        -- Start

        local FakeArm = Arm:Clone()
        FakeArm.Material = Enum.Material.SmoothPlastic
        FakeArm.Massless = true
        FakeArm.CanCollide = false
        FakeArm.Anchored = false
        FakeArm.Parent = workspace

        local Weld = Instance.new("Weld")
        Weld.Parent = Arm
        Weld.Part0 = FakeArm
        Weld.Part1 = Arm

        Arm.Transparency = 1

        TweenService:Create(FakeArm, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = Vector3.new(Arm.Size.X, Arm.Size.Y + data.Length, Arm.Size.Z)
        }):Play()
        TweenService:Create(Weld, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            C0 = CFrame.new(0, data.Length / 2, 0)
        }):Play()

        data.Reference.AncestryChanged:Wait()

        -- End

        if Arm:IsDescendantOf(Character) then
            TweenService:Create(FakeArm, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = Vector3.new(Arm.Size.X, Arm.Size.Y, Arm.Size.Z)
            }):Play()
            TweenService:Create(Weld, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                C0 = CFrame.new(0, 0, 0)
            }):Play()
            
            task.delay(0.25, function()
                FakeArm:Destroy()
                Weld:Destroy()
                Arm.Transparency = 0
            end)
        else
            FakeArm:Destroy()
        end
	end,
}
