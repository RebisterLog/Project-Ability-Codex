const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const OnEvent = require(ReplicatedStorage.shared.packages.Fusion.Instances.OnEvent)
const Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
const peek = require(ReplicatedStorage.shared.packages.Fusion.State.peek)

const Children = Fusion.Children
const peek = Fusion.peek
const OnEvent = Fusion.OnEvent
const OnChange = Fusion.OnChange
type UsedAs<T> = Fusion.UsedAs<T>

const GetRandomChars = function(len: number)
	local text = ""
	for i = 1, len do
		text = text .. string.char(math.random(33, 126))
	end
	return text
end

const MIX_TIME = 3
const START_DELAY = 0
const CHANGE_FREQUENCY = 0.05

const MixedText = function(
	scope: Fusion.Scope,
	isActive: UsedAs<boolean>,
	element: TextBox | TextLabel | TextButton
)
	if element.Text == "" then return element end

	const textScope = scope:innerScope()

	const targetText = element.Text
	const length = targetText:len()
	const textValue = textScope:Value("")

	local startTime = tick()
	local lastChange = 0
	local conn: RBXScriptConnection?

	textScope:Observer(isActive):onBind(function()
		const isActive = peek(isActive)

		if isActive then
			textValue:set("")
			task.wait(START_DELAY)
			startTime = tick()
			lastChange = 0

			if conn then conn:Disconnect() end

			conn = RunService.Heartbeat:Connect(function(delta)
				const diff = tick() - startTime
				local visiblePercent = diff / MIX_TIME
				visiblePercent = math.clamp(visiblePercent, 0, 1)

				if tick() - lastChange > CHANGE_FREQUENCY then
					lastChange = tick()

					const visibleCharsCount = math.round(length * visiblePercent)

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

	const object = textScope:Hydrate(element)({
		Text = textValue,
	})

	return object
end

return MixedText
