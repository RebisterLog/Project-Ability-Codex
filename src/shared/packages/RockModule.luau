--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CacheTab = require(ReplicatedStorage.shared.packages.CacheTab)

--[=[ RockModule

   Ground debris. `Ground` rings a position with two rows of paired rocks, drops
   each pair where a downward raycast finds the surface, and shrinks it back into
   the cache once its lifetime passes.

   The rocks take the material and colour of whatever they land on, so a slam on
   stone throws stone chips.
]=]

const SHRINK = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
const SHRINK_SIZE = Vector3.new(0.01, 0.01, 0.01)
const DEFAULT_SIZE = Vector3.new(2, 2, 2)
const DEFAULT_LIFETIME = 3
const RAY_DOWN = Vector3.new(0, -20, 0)
const RAY_HEIGHT = 10
const CACHE_SIZE = 100
const RINGS = 2
const POOL_NAME = "RockCache"

type RockCache = CacheTab.CacheTab<BasePart>

local rockCache: RockCache? = nil

local function storeRock(part: BasePart, position: Vector3)
	part.CFrame = CFrame.new(position)
end

local function unstoreRock(_part: BasePart) end

local function getPool(): Folder
	local existing = workspace:FindFirstChild(POOL_NAME)

	if existing and existing:IsA("Folder") then return existing end

	local folder = Instance.new("Folder")
	folder.Name = POOL_NAME
	folder.Parent = workspace

	return folder
end

local function getCache(): RockCache
	local existing = rockCache

	if existing then return existing end

	local created = CacheTab.new(
		Instance.new("Part"),
		CACHE_SIZE,
		storeRock,
		unstoreRock,
		getPool()
	) :: RockCache
	rockCache = created

	return created
end

local function createRock(
	hit: RaycastResult,
	lookAt: Vector3,
	size: Vector3,
	iceMode: boolean?,
	rocks: RockCache
): (BasePart, BasePart)
	const random = Random.new()
	local mainRock = rocks:Get()
	local topRock = rocks:Get()

	mainRock.Anchored = true
	mainRock.CanCollide = false
	mainRock.CanTouch = false
	topRock.Anchored = true
	topRock.CanCollide = false
	topRock.CanTouch = false

	const finalSize = Vector3.new(size.X * 1.3, size.Y, size.Z * 1.3) * random:NextNumber(1, 1.5)

	mainRock.Size = finalSize
	topRock.Size = Vector3.new(finalSize.X * 1.01, finalSize.Y * 0.25, finalSize.Z * 1.01)

	mainRock.CFrame = CFrame.new(hit.Position - Vector3.yAxis * (finalSize.Y * 0.4), lookAt)
		* CFrame.fromEulerAnglesXYZ(
			random:NextNumber(-0.5, 0.5),
			random:NextNumber(-0.3, 0.3),
			random:NextNumber(-0.3, 0.3)
		)

	topRock.CFrame = mainRock.CFrame * CFrame.new(0, mainRock.Size.Y / 2 - topRock.Size.Y / 2.1, 0)

	const ground = hit.Instance

	local function applyGroundAppearance(rock: BasePart)
		rock.Material = ground.Material
		rock.Reflectance = ground.Reflectance
		rock.Transparency = ground.Transparency
		rock.Color = ground.Color
		rock.MaterialVariant = ground.MaterialVariant

		-- Copy legacy texture instances (Decal, Texture object with Texture ID).
		for _, child in ipairs(ground:GetChildren()) do
			if child:IsA("Texture") or child:IsA("Decal") then
				local cloned = child:Clone()
				cloned.Parent = rock
			end
		end
	end

	if iceMode then
		mainRock.Material = Enum.Material.Ice
		topRock.Material = Enum.Material.Sand
		mainRock.Color = BrickColor.new("Pastel light blue").Color
		topRock.Color = BrickColor.new("Lily white").Color
	else
		applyGroundAppearance(mainRock)
		applyGroundAppearance(topRock)

		mainRock.Color = mainRock.Color:Lerp(Color3.fromRGB(100, 100, 100), 0.3)
	end

	local parent = rocks.Parent

	if parent then
		mainRock.Parent = parent
		topRock.Parent = parent
	end

	return mainRock, topRock
end

local function shrinkAndReturn(
	mainRock: BasePart,
	topRock: BasePart,
	rocks: RockCache,
	time: number
)
	task.delay(time, function()
		TweenService:Create(mainRock, SHRINK, { Size = SHRINK_SIZE }):Play()
		TweenService:Create(topRock, SHRINK, { Size = SHRINK_SIZE }):Play()

		task.delay(0.6, function()
			rocks:Add(mainRock)
			rocks:Add(topRock)
		end)
	end)
end

local RockModule = {}

function RockModule.Ground(
	position: Vector3,
	radius: number,
	size: Vector3?,
	rockCount: number,
	iceMode: boolean?,
	lifetime: number?
)
	if rockCount <= 0 then return end

	const rocks = getCache()
	const rockSize = size or DEFAULT_SIZE
	const lifeTime = lifetime or DEFAULT_LIFETIME

	const rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { workspace:FindFirstChild("Map") or workspace }

	local currentAngle = 0
	const angleStep = 360 / rockCount

	for ring = 1, RINGS do
		const offset = if ring == 1 then radius / 2 + radius / 10 else radius / 2 + radius / 2.7

		for _ = 1, rockCount do
			local rayOrigin = (
				CFrame.new(position)
				* CFrame.Angles(0, math.rad(currentAngle), 0)
				* CFrame.new(offset, RAY_HEIGHT, 0)
			).Position

			currentAngle += angleStep

			local hit = workspace:Raycast(rayOrigin, RAY_DOWN, rayParams)

			if hit then
				const mainRock, topRock = createRock(hit, position, rockSize, iceMode, rocks)
				shrinkAndReturn(mainRock, topRock, rocks, lifeTime)
			end
		end
	end
end

return RockModule