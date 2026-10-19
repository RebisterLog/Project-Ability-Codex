--!strict
--- The test world: character, targets, spec, services, clock and time steps.
---
--- A world is the entire state of one skill run. It starts empty, receives the
--- skill through `world:skill(...)`, and the test moves time with
--- `world:Step(n)`. Nothing is shared between runs: two tests in one process
--- share neither variables nor logs.
---
--- Assets come from the real skin config, and every key lookup is recorded. If
--- a skill asks for `Anims.Uppercut` and the skin spells it differently, the
--- live game gets a `nil` and a crash in the middle of combat, whereas in the
--- test it shows up immediately.
---
--- The parameters are computed by the real `components/Character/Parameters`:
--- the stacking priorities (`MaxWalkSpeed` takes the minimum, `IFrames` the
--- maximum) are behavior, not an implementation detail.

local Butler = require("./Butler")
local Loader = require("./Loader")
local Roblox = require("./Roblox")
local Services = require("./Services")
local Trace = require("./Trace")
local fs = require("@lune/fs")

local World = {}
World.__index = World

--- The world type is deliberately loose: the world is assembled field by field
--- by the helpers below, so a strict shape here would only restate what those
--- helpers already say. The alias exists so test signatures have a name.
export type World = any

const SKILL_FOLDER = "src/server/skills"

--- Wrapper around the real asset table: remembers every lookup and flags the
--- misses. A miss is a typo in an asset name, the most common skill defect.
local function watched(source: any, trace: any, prefix: string, missing: { string }): any
	if type(source) ~= "table" then return source end

	return setmetatable({}, {
		__index = function(_self, key)
			local value = source[key]

			trace:record("asset", { name = `{prefix}.{key}`, found = value ~= nil })

			if value == nil then table.insert(missing, `{prefix}.{key}`) end

			return value
		end,
		__newindex = function()
			error("harness: assets are read-only", 2)
		end,
	})
end

--- Character: real instances, plus a component with the same fields as the
--- real `Character`. Parameters accumulate in layers, the value is computed by
--- the rules from the real module.
function World.character(self: any, name: string, position: any): any
	local Instance = Roblox.Datatypes.Instance
	local CFrame = Roblox.Datatypes.CFrame

	const instance = Instance.new("Model")
	instance.Name = name

	const rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.CFrame = CFrame.new(position.X, position.Y, position.Z)
	rootPart.Parent = instance

	-- The humanoid is a plain table, not a real instance: in Lune's stdlib
	-- `Humanoid` has not a single property, not even `Health`, and that is
	-- exactly what the skills and the `Skill` class need. The model and the
	-- `RootPart` stay real: `CFrame` and parenting matter there.
	local humanoid = {
		Health = 100,
		MaxHealth = 100,
		WalkSpeed = 16,
		JumpPower = 50,

		-- A skill that moves without input reads this to decide where to go
		-- (`Dash` turns it into a dash direction). It is a real Vector3 rather
		-- than nil so that the usual "no input means forward" branch runs
		-- instead of the call failing on a nil operand. The datatype table is
		-- the only source here: `Vector3` is injected into loaded skills, not
		-- into this file.
		MoveDirection = Roblox.Datatypes.Vector3.zero,

		HealthChanged = Services.signal(),
		Destroy = function() end,
	}

	humanoid.Parent = instance

	local layers: { [string]: { { value: any, alive: boolean } } } = {}

	-- The parameter table and the log are captured in a closure: inside the
	-- methods `self` is the character, not the world, so `self.parameters`
	-- would be `nil`.
	local parameters = self.parameters
	local trace = self.trace

	local character = {
		instance = instance,
		RootPart = rootPart,
		Humanoid = humanoid,
		Player = nil,
		Block = {
			Blocking = false,
			AlwaysPerfect = false,
			PerfectBlockWindow = 0.2,
			PerfectBlockTime = -100,
		},
		Cleaner = Butler.new(name),
	}

	function character:AddParameter(key: string, value: any)
		local layer = { value = value, alive = true }

		layers[key] = layers[key] or {}
		table.insert(layers[key], layer)

		trace:record("parameter", { name = key, value = value, action = "add" })

		return {
			Destroy = function()
				if not layer.alive then return end

				layer.alive = false
				trace:record("parameter", { name = key, value = value, action = "remove" })
			end,
		}
	end

	function character:GetParameter(key: string)
		const entry = parameters[key]

		if entry == nil then error(`harness: unknown parameter '{key}'`, 2) end

		local value = entry.Default
		local parser = entry.Parser or function(_a, b)
			return b
		end

		local stack = layers[key] or {}

		-- `ipairs` rather than a generalized `for`: with `for _, x in table`, iteration
		-- yields the index, not the value, so the analyzer reads the table itself
		-- as an iterator and expects a callable in its place.
		for _, layer in ipairs(stack) do
			if layer.alive then value = parser(value, layer.value) end
		end

		return value
	end

	return character
end

--- The skill lifecycle is the same as in `combat-classes/Skill.luau`, but
--- without `Proxy`: UI state (the on-screen cooldown, the bind) is of no use to
--- a test, and the cooldown state is checked straight through `ReleaseTime`.
function World.handle(self: any, name: string, data: { [string]: any }): any
	local clock = self.clock

	const handle = {
		Id = name,
		Data = data,
		Character = self.caster,

		-- Both names exist in the game and skills are not consistent about which
		-- one they use: most read `self.Character`, the stand skills read
		-- `self.Caster`. Leaving either out turns into a nil-index error that
		-- looks like a bug in the skill.
		Caster = self.caster,

		Spec = self.spec,
		Cleaner = Butler.new(name),
		Deactivated = Services.signal(),
		Active = false,
		Holding = false,
		ReleaseTime = -1,
	}

	function handle:SetCooldown(time: number)
		self.ReleaseTime = clock.time + math.max(time, 0)
	end

	function handle:IsOnCooldown(): boolean
		return self.ReleaseTime > clock.time
	end

	function handle:SetDisplayName(_displayName: string) end

	function handle:SetEnabled(_enabled: boolean) end

	--- Repeats the checks from the real class: a skill must not fire while stunned,
	--- while playing a ragdoll animation, on a dead character, or on cooldown.
	function handle:Validate(): boolean
		if self.Character:GetParameter("NoSkillCast") then return false end
		if self.Character:GetParameter("Stun").Duration > 0 then return false end
		if self.Character:GetParameter("Ragdoll") then return false end
		if self.Character.Humanoid.Health <= 0 then return false end
		if self:IsOnCooldown() then return false end

		return true
	end

	function handle:Activate()
		if self.Active then return end

		self.Active = true
		self.Holding = true

		if self.Data.Activate then self.Data.Activate(self) end

		self.Active = false

		if self.Data.Cooldown then self:SetCooldown(self.Data.Cooldown) end
	end

	function handle:Interrupt()
		if not self.Active then return end

		if self.Data.Interrupt then self.Data.Interrupt(self) end
	end

	function handle:Deactivate()
		if not self.Holding then return end

		self.Holding = false
		self.Deactivated:Fire(self)
	end

	function handle:Destroy()
		if self.Data.onDestroy then self.Data.onDestroy(self) end

		self.Cleaner:Destroy()
	end

	return handle
end

--- Builds the world: the real parameter table, skin, character, targets and
--- services.
function World.new(options: { [string]: any }): any
	const clock = Roblox.newClock()
	local Vector3 = Roblox.Datatypes.Vector3

	local self = setmetatable({
		root = options.root,
		name = options.name or "Harness",
		clock = clock,
		trace = Trace.new(),
		missing = {},
		unresolved = {},
		state = {},
		stands = {},
		handles = {},
		registry = {},
	}, World)

	self.services = Roblox.services()
	self.targets = {}
	self.task = Roblox.newTask(self.clock)

	-- Real data: the skill needs `Enums` and the parameter table exactly as they
	-- are.
	self.registry["ServerScriptService.server.Enums"] =
		Loader.plain(`{self.root}/src/server/Enums.luau`)

	local env = self:environment()
	self.parameters =
		Loader.file(env, `{self.root}/src/server/components/Character/Parameters.luau`)

	self.caster = World.character(self, options.name or "Caster", Vector3.new(0, 3, 0))

	-- Targets stand in front of the fighter: a skill hits forward, so the "which
	-- way does the hitbox face" check would be a fiction without them.
	for index = 1, options.targets or 0 do
		local target = World.character(self, `Target{index}`, Vector3.new(0, 3, -5))

		target.index = index
		target.Player = { Name = `Target{index}` }
		table.insert(self.targets, target)
	end

	self.spec = {
		Data = self:loadSkin(options.spec or "Standless", options.skin or "None"),
		Character = self.caster,
		Skills = {},
		Cleaner = Butler.new("spec"),

		-- The stand skills gate themselves through the spec rather than through
		-- the stand: `Summon` enables the stand-only skills when it dismisses the
		-- stand, and the opposite way round when it summons. The state is kept
		-- per tag so a test can read it back through `Spec.enabled`.
		enabled = {},

		SetEnableSkills = function(_self, tag: string, state: boolean)
			(self.spec :: any).enabled[tag] = state
		end,
	}

	local serviceMap = {
		CombatService = Services.combat(self.trace, self.targets, self.state),
		VFXService = Services.vfx(self.trace),
		StandService = Services.stand(self.trace, self.stands),
		Character = function(_self: any, _instance: any)
			return self.caster
		end,
	}

	self.serviceMap = serviceMap
	self.crane = Services.crane(serviceMap)

	-- A skin that defines a `Stand` group can put its character inside a stand,
	-- so the world creates one. Without it a stand skill reads `GetStand` as nil
	-- and dies on the first frame that indexes its own `Caster` - the stand, not
	-- the character, which is what those skills animate.
	if self.spec.Data.Assets.Stand ~= nil then
		local standAssets = self.spec.Data.Assets.Stand

		serviceMap.StandService:AddStandFor(self.caster, standAssets.Models.Stand)
	end

	self.registry["ReplicatedStorage.shared.packages.Crane"] = self.crane

	return self
end

--- The skin config in full: inside it pulls instances out of
--- `ReplicatedStorage.assets`, which `Roblox.services` stands in for.
function World.loadSkin(self: any, spec: string, skin: string)
	local path = `{self.root}/src/shared/configs/Skins/{spec}/{skin}.luau`

	if not fs.isFile(path) then error(`harness: no skin at {spec}/{skin}`, 2) end

	local data = Loader.file(self:environment(), path)
	local assets = data.Assets or data

	-- The shape mirrors combat: a skill reads `Spec.Data.Assets.Animations`, and
	-- if the stand-in disagreed with that path, the test would not be testing
	-- the right code.
	--
	-- Every top-level group of the skin is exposed, not a hand-written list of
	-- the three or four that happened to be used so far: `StarPlatinum` carries
	-- a whole `Stand` group, and a fixed list would leave a skill reading it with
	-- no trace and no record of a missing name.
	const groups: { [string]: any } = {}

	for key, value in assets do
		if type(value) == "table" and key:sub(1, 1) ~= "_" then
			groups[key] = watched(value, self.trace, key, self.missing)
		end
	end

	return {
		DisplayName = spec,
		Assets = groups,
	}
end

--- What the prelude makes visible to the skill's chunk.
function World.environment(self: any): { [string]: any }
	local services = self.services

	local env: { [string]: any } = {
		game = {
			GetService = function(_self, name: string)
				local service = services[name]

				if service == nil then error(`harness: service '{name}' is not available`, 3) end

				return service
			end,
			IsStudio = function()
				return true
			end,
		},
		workspace = services.workspace,
		script = { Name = self.name },
		task = self.task,
		os = self.clock.os,
		-- `tick()` is CPU time in Roblox. Skills use it to tag effects with an id
		-- (`Footrest` spawns one per swing), so it has to advance with the virtual
		-- clock: the same id twice in a row would make a test see a stuck effect.
		tick = function()
			return self.clock.time
		end,
		registry = self.registry,
	}

	for name, datatype in pairs(Roblox.Datatypes) do
		env[name] = datatype
	end

	env.require = Loader.shim(self.registry, function(path)
		table.insert(self.unresolved, path)
		return Services.stub()
	end)

	return env
end

--- Loads the skill, runs `onInit` and returns the wrapper.
function World.skill(self: any, name: string): any
	const path = `{self.root}/{SKILL_FOLDER}/{name}.luau`

	if not fs.isFile(path) then error(`harness: no skill '{name}' in {SKILL_FOLDER}`, 2) end

	-- A skill may require anything at all: missing modules are handed back as
	-- stubs and remembered, so the test can look at them.
	self.registry["ServerScriptService.server.types"] = Services.stub()
	self.registry["ServerScriptService.server.Types"] = Services.stub()
	self.registry["ReplicatedStorage.shared.packages.Proxy"] = Services.stub()
	self.registry["ReplicatedStorage.shared.packages.Sequencer"] = Services.stub()
	self.registry["ReplicatedStorage.shared.packages.Promise"] = Services.stub()

	local data = Loader.file(self:environment(), path)

	if type(data) ~= "table" then error(`{name}: module did not return a table`, 2) end

	if type(data.DisplayName) ~= "string" or data.DisplayName == "" then
		error(`{name}: DisplayName is required`, 2)
	end

	local handle = self:handle(name, data)

	if data.onInit then data.onInit(handle) end

	table.insert(self.handles, handle)

	return handle
end

--- Moves time forward by `frames` frames: sequences first, then the deferred
--- calls — just like in the game, where `task.delay` fires off the clock while
--- frames run on their own count.
function World.Step(self: any, frames: number)
	local perFrame = 1 / 60

	for _ = 1, frames do
		self.clock.time += perFrame

		for _, handle in self.handles do
			local sequence = handle.Sequence

			if sequence and sequence.playing then sequence:Step(1) end
		end

		self.clock.flush()
	end

	self.trace:setFrame(0)
end

--- Asset keys the skill did not find: an empty list means every name matched
--- the skin.
function World.missingAssets(self: any): { string }
	local unique: { [string]: boolean } = {}
	local list: { string } = {}

	for _, key in self.missing do
		if not unique[key] then
			unique[key] = true
			table.insert(list, key)
		end
	end

	table.sort(list)

	return list
end

--- Modules the harness does not know and replaced with a stub. A skill may
--- require anything, but this list is worth a look: a stub means the behavior
--- of that module was not covered by this test.
function World.missingModules(self: any): { string }
	local unique: { [string]: boolean } = {}
	local list: { string } = {}

	for _, path in self.unresolved do
		if not unique[path] then
			unique[path] = true
			table.insert(list, path)
		end
	end

	table.sort(list)

	return list
end

return World
