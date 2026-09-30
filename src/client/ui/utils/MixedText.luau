local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local OnEvent = require(ReplicatedStorage.shared.packages.Fusion.Instances.OnEvent)
local Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
local peek = require(ReplicatedStorage.shared.packages.Fusion.State.peek)

local Children = Fusion.Children
local peek = Fusion.peek
local OnEvent = Fusion.OnEvent
local OnChange = Fusion.OnChange
type UsedAs<T> = Fusion.UsedAs<T>

local function GetRandomChars(len: number)
	local text = ""
	for i = 1, len do
		text = text .. string.char(math.random(33, 126))
	end
	return text
end

local MIX_TIME = 3
local START_DELAY = 0
local CHANGE_FREQUENCY = 0.05

local function MixedText(
	scope: Fusion.Scope,
	isActive: UsedAs<boolean>,
	element: TextBox | TextLabel | TextButton
)
	if element.Text == "" then return element end

	local textScope = scope:innerScope()

	local targetText = element.Text
	local length = targetText:len()
	local textValue = textScope:Value("")

	local startTime = tick()
	local lastChange = 0
	local conn: RBXScriptConnection?

	textScope:Observer(isActive):onBind(function()
		local isActive = peek(isActive)

		if isActive then
			textValue:set("")
			task.wait(START_DELAY)
			startTime = tick()
			lastChange = 0

			if conn then conn:Disconnect() end

			conn = RunService.Heartbeat:Connect(function(delta)
				local diff = tick() - startTime
				local visiblePercent = diff / MIX_TIME
				visiblePercent = math.clamp(visiblePercent, 0, 1)

				if tick() - lastChange > CHANGE_FREQUENCY then
					lastChange = tick()

					local visibleCharsCount = math.round(length * visiblePercent)

					textValue:set(
						targetText:sub(1, visibleCharsCount)
							.. GetRandomChars(length - visibleCharsCount)
					)
				end

				if visiblePercent == 1 then
					textValue:set(targetText)
					if conn then conn:Disconnect() end
				end
			end)
		else
			startTime = 0
			if conn then conn:Disconnect() end
		end
	end)

	--table.insert(textScope,
	--end))

	local object = textScope:Hydrate(element)({
		Text = textValue,
	})

	return object
end

return MixedText
