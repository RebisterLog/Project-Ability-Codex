const GuiService = game:GetService("GuiService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Workspace = game:GetService("Workspace")

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

const GetTopInset = function(): number
	const inset = GuiService.TopbarInset
	const strip = inset.Min.Y + inset.Height

	if strip > 0 and strip <= 200 then return strip end

	return 36
end

const GetTopInsetScale = function(): number
	const camera = Workspace.CurrentCamera
	const viewportHeight = if camera then camera.ViewportSize.Y else 0

	if viewportHeight <= 0 then return 36 / 1080 end

	return GetTopInset() / viewportHeight
end

return function(scope: Fusion.Scope, props: DefaultProps, router: Router.Router)
	const hudScope = scope:innerScope()

	const humanoidHealth = hudScope:Value(100)
	const humanoidMaxHealth = hudScope:Value(100)

	const healthRatio = hudScope:Computed(function(use)
		return math.clamp(use(humanoidHealth) / math.max(use(humanoidMaxHealth), 1), 0, 1)
	end)

	const healthText = hudScope:Computed(function(use)
		return ("%d/%d"):format(math.ceil(use(humanoidHealth)), math.ceil(use(humanoidMaxHealth)))
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

		const humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not humanoid then
			humanoidHealth:set(100)
			humanoidMaxHealth:set(100)
			return
		end

		const update = function()
			humanoidHealth:set(humanoid.Health)
			humanoidMaxHealth:set(humanoid.MaxHealth)
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

	const levelText = hudScope:Computed(function(use)
		return ("%d lvl."):format(math.floor(use(level)))
	end)

	const experienceFraction = hudScope:Computed(function(use)
		return math.clamp(use(experience) / GetExperienceToNextLevel(use(level)), 0, 1)
	end)

	const topInsetScale = hudScope:Value(GetTopInsetScale())

	const updateTopInsetScale = function()
		topInsetScale:set(GetTopInsetScale())
	end

	table.insert(
		hudScope,
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(updateTopInsetScale)
	)

	local cameraConnection: RBXScriptConnection? = nil

	const bindCamera = function()
		if cameraConnection then
			cameraConnection:Disconnect()
			cameraConnection = nil
		end

		const camera = Workspace.CurrentCamera
		if not camera then return end

		cameraConnection =
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateTopInsetScale)
		updateTopInsetScale()
	end

	bindCamera()
	table.insert(hudScope, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))
	table.insert(hudScope, function()
		if cameraConnection then cameraConnection:Disconnect() end
	end)

	return PlayerHUDView(hudScope, {
		HealthRatio = healthRatio,
		HealthText = healthText,
		LevelText = levelText,
		Experience = experienceFraction,
		DisplayName = LocalPlayer.DisplayName,
		AvatarImage = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(
			LocalPlayer.UserId
		),
		TopInsetScale = topInsetScale,
	})
end
