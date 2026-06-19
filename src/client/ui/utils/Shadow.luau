local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local OnEvent = require(ReplicatedStorage.shared.packages.Fusion.Instances.OnEvent)
local peek = require(ReplicatedStorage.shared.packages.Fusion.State.peek)
local Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)

local Children = Fusion.Children
local peek = Fusion.peek
local OnEvent = Fusion.OnEvent
local OnChange = Fusion.OnChange
type UsedAs<T> = Fusion.UsedAs<T>

local AprovedClasses = {
	"Frame",
	"ScrollingFrame",
	"TextButton",
	"TextLabel",
	"ImageLabel",
	"ImageButton",
	"ViewportFrame",
}

local SHADOW_IN_STYLE = TweenInfo.new(2, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
local SHADOW_OUT_STYLE = TweenInfo.new(0.8, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)

local CONTENT_IN_STYLE = TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
local CONTENT_OUT_STYLE = TweenInfo.new(0.1, Enum.EasingStyle.Circular, Enum.EasingDirection.In)

local function GetListContent(list: GuiObject)
	local content = {}
	
	for i, v in list:GetChildren() do
		if not v:IsA("GuiObject") then continue end
		if not table.find(AprovedClasses, v.ClassName) then continue end

		table.insert(content, v)
	end
	
	table.sort(content, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	
	return content
end

local function Shadow(
	scope: Fusion.Scope,
	isShown: UsedAs<boolean>,
	element: GuiObject
)
	local targetPos = element.Position
	local targetSize = element.Size
	
	local outSize = element.Size - UDim2.fromScale(0.1, 0.1)
	local outPos = element.Position.Y.Scale < 0.5 and UDim2.fromScale(element.Position.X.Scale, -1) or UDim2.fromScale(element.Position.X.Scale, 2)
	
	-- SHADOWS
	local elementsToShadow = {} :: {GuiObject}
	local shadows = {}
	
	for i, v in element:GetChildren() do
		if not v:IsA("GuiObject") then continue end
		if not table.find(AprovedClasses, v.ClassName) then continue end
		
		if v:IsA("ImageButton") or v:IsA("ImageLabel") then
			if v.ImageTransparency == 1 and v.BackgroundTransparency == 1 then continue end
		else
			if not v:IsA("ScrollingFrame") and v.BackgroundTransparency == 1 then continue end
		end
		
		table.insert(elementsToShadow, v)
	end

	for i, v in elementsToShadow do
		local shadow = v:Clone()
		shadow:ClearAllChildren()
		shadow.BackgroundTransparency = 0
		--shadow.Rotation = v.Rotation
		shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

		if shadow:IsA("TextButton") or shadow:IsA("TextLabel") then
			shadow.Text = ""
			shadow.Interactable = false
		end
		if shadow:IsA("ImageLabel") or shadow:IsA("ImageButton") then
			shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
			shadow.ImageTransparency = 0
			shadow.BackgroundTransparency = 1
			shadow.Interactable = false
		end

		shadow.Active = false
		shadow.Selectable = false
		shadow.AnchorPoint = Vector2.new(0, 0)
		shadow.Size = UDim2.fromScale(1,1)
		shadow.Position = UDim2.fromScale(0,0)
		shadow.ZIndex = 200
		shadow.AnchorPoint = Vector2.new(0, 0)
		shadow.Name = "ShadowClone"

		local folder = scope:New "Folder" {
			Name = "Shadow",
		}

		local gradient = scope:New "UIGradient" {
			Name = "UIGradient",
			Rotation = -135,
			Offset = Vector2.new(-1, 0),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}

		gradient.Parent = shadow
		shadow.Parent = folder

		folder.Parent = v

		shadow.Rotation = 0
		--v.ClipsDescendants = true

		table.insert(shadows, gradient)
	end
	----	

	-- LIST'S CONTENT
	local lists = {} :: {GuiObject}
	
	for i, v in element:GetDescendants() do
		if v:IsA("UIListLayout") or v:IsA("UIGridLayout") then
			table.insert(lists, v)
		end
	end
	
	local content = {}

	for i, v in lists do
		content[v] = content[v] or {}

		local listData = GetListContent(v.Parent)
		for _, data in listData do
			table.insert(content[v], {
				data,
				data.Size
			})

			data.Size = UDim2.fromScale(0, 0)
		end
	end
	----

	-- IN SEQUENCE
	local slideTween = TweenService:Create(
		element,
		TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Position = targetPos
		}
	)
	local frontTween = TweenService:Create(
		element,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = targetSize
		}
	)
	
	local tweens = {} :: {Tween}
	
	local inSequence = Sequencer.new({
		Frames = {
			{1, function()
					slideTween:Play()
			end,},
			
			{30, function()
					frontTween:Play()
					
					for i, v in tweens do
						v:Destroy()
					end
					table.clear(tweens)

					for i, v in shadows do
						local tween = TweenService:Create(v, SHADOW_IN_STYLE, {Offset = Vector2.new(1, 0)})
						
						tween.Completed:Once(function()
							v.Parent.Visible = false
						end)
						
						table.insert(tweens, tween)
						
						tween:Play()
					end
				end,
			},
			{60, function()
					for list, data in content do
						task.spawn(function()
							local delayTime = #data / 30
							for i, elementData in data do
								local tween = TweenService:Create(elementData[1], CONTENT_IN_STYLE, { Size = elementData[2] })
								table.insert(tweens, tween)

								tween:Play()
								task.wait(delayTime)
							end
						end)
					end
				end,
			}
		}
	})
	----

	-- OUT SEQUENCE
	local outSlideTween = TweenService:Create(
		element,
		TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{
			Position = outPos,
		}
	)
	local outBackTween = TweenService:Create(
		element,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = outSize,
		}
	)
	
	local outSequence = Sequencer.new({
		Frames = {
			{1, function()
					outBackTween:Play()
					outSlideTween:Play()

					for i, v in tweens do
						v:Cancel()
					end
					table.clear(tweens)

					for i, v in shadows do
						v.Parent.Visible = true
						local tween = TweenService:Create(v, SHADOW_OUT_STYLE, {Offset = Vector2.new(-1.5, 0)})
						table.insert(tweens, tween)
						tween:Play()
					end
				end,
			},
			{60,function()
					for list, data in content do
						for i, elementData in data do
							local tween = TweenService:Create(elementData[1], CONTENT_OUT_STYLE, { Size = UDim2.fromScale(0, 0) })
							table.insert(tweens, tween)
							tween:Play()
						end
					end
				end,
			},
		}
	})
	

	scope:Observer(isShown):onBind(function()
		local state = peek(isShown)
		
		if state then
			outSequence:Stop()
			--table.clear(content)

			
			inSequence:Play()
		else
			inSequence:Stop()
			outSequence:Play()
		end
	end)
	
	return element
end

return Shadow