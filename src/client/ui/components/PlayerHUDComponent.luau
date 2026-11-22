const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const LocalPlayer = Players.LocalPlayer

const GameData = require(ReplicatedStorage.shared.schemas.GameData)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const Router = require(script.Parent.Parent.utils.Router)
const PlayerHUDView = require(script.Parent.Parent.views.PlayerHUDView)

type DefaultProps = {
	PlayerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	GameProxy: Proxy.ProxyTab<GameData.GameData>,
}

const GetExperienceToNextLevel = function(level: number): number
	return 100 * math.max(level, 1)
end

return function(scope: Fusion.Scope, props: DefaultProps, router: Router.Router)
	const hudScope = scope:innerScope()

	const humanoidHealth = hudScope:Value(100)
	const humanoidMaxHealth = hudScope:Value(100)
	const delayedHealth = hudScope:Value(100)
	const delayedMaxHealth = hudScope:Value(100)

	local currentHealth = 100
	local currentMaxHealth = 100
	local delayThread: thread? = nil
	local delayToken = 0

	const cancelCatchup = function()
		delayToken = delayToken + 1

		if delayThread then
			task.cancel(delayThread)
			delayThread = nil
		end
	end

	const scheduleCatchup = function()
		cancelCatchup()
		const token = delayToken

		delayThread = task.delay(1, function()
			if token == delayToken then
				delayedHealth:set(currentHealth)
				delayedMaxHealth:set(currentMaxHealth)
				delayThread = nil
			end
		end)
	end

	const healthRatio = hudScope:Computed(function(use)
		return math.clamp(use(humanoidHealth) / math.max(use(humanoidMaxHealth), 1), 0, 1)
	end)

	const delayedHealthRatio = hudScope:Computed(function(use)
		return math.clamp(use(delayedHealth) / math.max(use(delayedMaxHealth), 1), 0, 1)
	end)

	const healthText = hudScope:Computed(function(use)
		return ("HP %d / %d"):format(
			math.ceil(use(humanoidHealth)),
			math.ceil(use(humanoidMaxHealth))
		)
	end)

	const humanoidConnections = {}

	const unbindHumanoid = function()
		for _, connection in humanoidConnections do
			connection:Disconnect()
		end
		table.clear(humanoidConnections)
	end

	const bindHumanoid = function(character: Model?)
		unbindHumanoid()
		cancelCatchup()

		const humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not humanoid then
			currentHealth = 100
			currentMaxHealth = 100
			humanoidHealth:set(100)
			humanoidMaxHealth:set(100)
			delayedHealth:set(100)
			delayedMaxHealth:set(100)
			return
		end

		local lastHealth = 0

		const update = function()
			const health = humanoid.Health
			const maxHealth = humanoid.MaxHealth

			if health < lastHealth then
				scheduleCatchup()
			elseif health > lastHealth then
				cancelCatchup()
				delayedHealth:set(health)
				delayedMaxHealth:set(maxHealth)
			elseif maxHealth ~= currentMaxHealth then
				delayedMaxHealth:set(maxHealth)
			end

			lastHealth = health
			currentHealth = health
			currentMaxHealth = maxHealth
			humanoidHealth:set(health)
			humanoidMaxHealth:set(maxHealth)
		end

		update()
		table.insert(humanoidConnections, humanoid.HealthChanged:Connect(update))
		table.insert(
			humanoidConnections,
			humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update)
		)
	end

	bindHumanoid(LocalPlayer.Character)
	table.insert(hudScope, LocalPlayer.CharacterAdded:Connect(bindHumanoid))
	table.insert(
		hudScope,
		LocalPlayer.CharacterRemoving:Connect(function()
			bindHumanoid(nil)
		end)
	)
	table.insert(hudScope, unbindHumanoid)
	table.insert(hudScope, cancelCatchup)

	const level = hudScope:Value(props.PlayerProxy().Level or 0)
	const experience = hudScope:Value(props.PlayerProxy().Experience or 0)

	table.insert(
		hudScope,
		props.PlayerProxy:Subscribe("AnyChange", { "Level" }, function()
			level:set(props.PlayerProxy().Level or 0)
		end)
	)

	table.insert(
		hudScope,
		props.PlayerProxy:Subscribe("AnyChange", { "Experience" }, function()
			experience:set(props.PlayerProxy().Experience or 0)
		end)
	)

	const experienceFraction = hudScope:Computed(function(use)
		return math.clamp(use(experience) / GetExperienceToNextLevel(use(level)), 0, 1)
	end)

	return PlayerHUDView(hudScope, {
		DisplayName = LocalPlayer.DisplayName,
		Level = level,
		Experience = experienceFraction,
		HealthRatio = healthRatio,
		DelayedHealthRatio = delayedHealthRatio,
		HealthText = healthText,
	})
end
