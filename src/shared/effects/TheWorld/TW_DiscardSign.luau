type SignData = {
	Model: Model?,
}

const LIFE_TIME = 3

return {
	onStart = function(_, data: SignData)
		local FakeSign = data.Model:Clone()
		for i, v in FakeSign:QueryDescendants("BasePart") do
			v.Anchored = true
			v.CanCollide = false
			v.CanQuery = false
		end
		for i, v in FakeSign:QueryDescendants("Motor6D") do
			v:Destroy()
		end
		FakeSign.Parent = workspace.Effects
		FakeSign.Handle.CFrame = data.Model.Handle.CFrame

		for i, v in data.Model:QueryDescendants("BasePart,Decal") do
			v.Transparency = 1
		end

		task.delay(LIFE_TIME, function()
			const Info = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

			for i, v in FakeSign:QueryDescendants("BasePart,Decal") do
				game:GetService("TweenService"):Create(v, Info, { Transparency = 1 }):Play()
			end

			task.wait(1.5)

			FakeSign:Destroy()
		end)
	end,
}
