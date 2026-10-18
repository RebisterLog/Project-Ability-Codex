const Crane = require(game:GetService("ReplicatedStorage").shared.packages.Crane)
const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")

const STYLE_OUT = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

const BusyObjects = {}

return {
	onStart = function(self, object: Model, projectile: Model)
		if not projectile.Parent or not projectile.PrimaryPart then return end
		if table.find(BusyObjects, object) then return end
		table.insert(BusyObjects, object)
		object.Parent = nil

		const cleaner = Crane.Buttler.new()

		const copy = cleaner:Clone(object)

		const parts = copy:QueryDescendants("BasePart") :: { BasePart }

		for i, part in parts do
			part.Anchored = false
			part.CollisionGroup = "NoCollision"
		end

		copy.Parent = workspace.Effects

		for i, part in parts do
			part:ApplyImpulse(
				(part.Position - projectile.PrimaryPart.Position) * 30 + Vector3.yAxis * 10
			)
		end

		task.delay(3, function()
			for i, part in parts do
				TweenService:Create(part, STYLE_OUT, { Transparency = 1, Size = Vector3.zero })
					:Play()
			end
		end)

		task.delay(6, function()
			cleaner:Clean()
		end)

		table.remove(BusyObjects, table.find(BusyObjects, object))

		cleaner:OnClean(function()
			object.Parent = workspace
		end)

		-- timeout
		cleaner:Add(task.delay(7, function()
			cleaner:Clean()
			table.remove(BusyObjects, table.find(BusyObjects, object))
		end))
	end,
}
