--!strict
--- Stand-ins for the Crane services: `CombatService`, `VFXService`,
--- `StandService` and `Crane` itself.
---
--- The real services work through attack hooks, physics and replication —
--- the whole point of writing a skill. Here it is recording instead: every call
--- lands in the log along with its frame number, and the response is derived
--- from the world settings. The test checks the skill's decision, not the
--- engine's machinery.
---
--- Modules a skill requires but the stand-ins do not need (`Proxy`, `Promise`,
--- `Sequencer`) are handed back as stubs: nothing calls their functions at
--- initialization time, and requiring something that does not exist is not
--- allowed — otherwise it blows up before the test can check anything.

local Butler = require("./Butler")
local Roblox = require("./Roblox")
local Sequence = require("./Sequence")

local Services = {}

--- A signal in the spirit of `Crane.Signal`: subscriptions are kept around so
--- they can be disconnected through the `Buttler`.
function Services.signal(): any
	local connections: { { fn: any, alive: boolean } } = {}

	local self = {}

	function self:Connect(fn: any)
		local connection = { fn = fn, alive = true }

		table.insert(connections, connection)

		return {
			Disconnect = function()
				connection.alive = false
			end,
			Connected = function()
				return connection.alive
			end,
		}
	end

	function self:Once(fn: any)
		return self:Connect(function(...)
			fn(...)
		end)
	end

	function self:Fire(...)
		for _, connection in connections do
			if connection.alive then connection.fn(...) end
		end
	end

	function self:Wait()
		return true
	end

	return self
end

--- Module stub: any field yields a callable stub. Needed for the `require`d
--- modules a skill declares but never uses.
function Services.stub(): any
	return setmetatable({}, {
		__index = function()
			return function()
				return Services.stub()
			end
		end,
		__call = function()
			return Services.stub()
		end,
	})
end

--- A minimal promise in the shape of `Promise`: skills only ever call
--- `andThen`. The result is computed immediately, the chain is built over that
--- same value, and `catch`/`finally` are left for later — they are not needed
--- now, but their absence would break the code the first time anyone tried to
--- handle an error.
function Services.promise(value: any): any
	local self = {}

	function self:andThen(callback: any)
		callback(value)

		return self
	end

	function self:finally(_callback: any)
		return self
	end

	function self:await()
		return value
	end

	function self:catch(_callback: any)
		return self
	end

	return self
end

--- `CombatService` stand-in. The replies to `Hitbox` and `Attack` come from the
--- world: the list of targets and which hit went through.
function Services.combat(trace: any, targets: { any }, state: { [string]: any }): any
	const self = {}

	-- Skills react to combat going on elsewhere: `Counter` waits for
	-- `CombatService.Attacked` and throws in response, `Block` watches for an
	-- incoming hit. The events exist here so such a skill loads; nothing fires
	-- them, because in this harness the only attacks are the ones the test makes
	-- itself - a test that wants the reaction has to fire the signal by hand.
	self.Attacking = Services.signal()
	self.Attacked = Services.signal()
	self.Damaged = Services.signal()
	self.Died = Services.signal()

	--- `CreateSequence` in combat also sets the speed from the `Timescale`
	--- parameter; skipping that would hide a broken sequence speed from the
	--- test.
	function self.CreateSequence(character: any, data: { [string]: any })
		const sequence = Sequence.new(data, trace)
		sequence:AdjustSpeed(character:GetParameter("Timescale"))

		return sequence
	end

	function self:Hitbox(data: { [string]: any })
		const info = data.Info or {}
		const found = table.clone(targets)

		if info.SortByDistance then
			-- Targets are already laid out by distance: the world creates them in
			-- exactly that order, and `index` stores it for the assertions.
			table.sort(found, function(a, b)
				return (a :: any).index < (b :: any).index
			end)
		end

		trace:record("hitbox", {
			caster = data.Caster,
			size = info.Size,
			offset = info.Offset,
			canQueryCaster = info.CanQueryCaster,
			targets = #found,
		})

		return found
	end

	function self:Attack(data: { [string]: any }): any
		local victim = data.Victim
		local info = data.Info or {}
		local blocked = state.blocking == victim

		local result = {
			Victim = victim,
			Attacker = data.Attacker,
			Info = info,
			State = {
				Success = true,
				Continue = not blocked,
				Blocking = blocked,
				Blocked = blocked,
			},
		}

		trace:record("attack", {
			victim = victim,
			caster = data.Attacker,
			damage = info.Damage,
			stun = info.Stun,
			ragdoll = info.Ragdoll,
			knockback = info.Knockback,
			block = info.Block,
			blocked = blocked,
		})

		-- Fired before the reply so that a listener sees the attack while the
		-- skill that made it is still waiting for the result, which is the
		-- order the real service uses: that is what lets `Counter` answer an
		-- attack from inside the same frame it landed.
		self.Attacked:Fire("Combat", result)

		return Services.promise(result)
	end

	-- Armor is a character parameter plus a highlight. A `Buttler` comes back
	-- because the skill puts it in `seq.Cleaner:Set("Armor", ...)` and drops it
	-- on its own frame.
	function self:AddArmor(character: any, enabled: boolean)
		const cleaner = Butler.new("armor")
		cleaner:Add(character:AddParameter("Armor", enabled))
		cleaner:Add(function()
			trace:record("armor", { enabled = false, removed = true })
		end)

		trace:record("armor", { enabled = enabled, removed = false })

		return cleaner
	end

	function self:GetStates(character: any)
		local states: { [string]: any } = {}

		if character.Block and character.Block.Blocking then states.Blocking = true end

		if character:GetParameter("Armor") == true then states.Armored = true end
		if character:GetParameter("IFrames") > 0 then
			states.IFrames = character:GetParameter("IFrames")
		end

		return states
	end

	function self:CreateGrab(_attacker: any, _victim: any, _grabData: any)
		return Butler.new("grab")
	end

	return self
end

--- `VFXService` stand-in: on the server it only broadcasts packets, so logging
--- is a faithful copy of what it does.
function Services.vfx(trace: any): any
	const self = {}

	--- A record of an effect: the kind (`Animation`, `Sound`, `EmitFolder`), the
	--- action, and the first argument. The asset name is not in the record — it
	--- lives in the object, and comparing such objects in a test is pointless.
	local function record(action: string, kind: string, ...)
		trace:record("effect", {
			action = action,
			name = kind,
			first = (select(1, ...)),
			argCount = select("#", ...),
		})
	end

	function self:StartEffect(_players: any, kind: string, ...)
		record("start", kind, ...)
	end

	function self:StopEffect(_players: any, kind: string, ...)
		record("stop", kind, ...)
	end

	function self:StartEffectExcept(_players: any, kind: string, ...)
		return self:StartEffect(_players, kind, ...)
	end

	function self:StopEffectExcept(_players: any, kind: string, ...)
		return self:StopEffect(_players, kind, ...)
	end

	return self
end

--- `StandService` stand-in: without a stand the skill works with the spec's
--- assets.
function Services.stand(trace: any, stands: { [any]: any }): any
	const self = {}

	function self:GetStand(character: any)
		return stands[character]
	end

	function self:AddStand(character: any, stand: any)
		stands[character] = stand
	end

	function self:RemoveStand(character: any)
		stands[character] = nil
	end

	-- A stand is a model with a lifecycle, and a skill that fires while standing
	-- inside one animates the stand, not the character. It has to exist as an
	-- object with `instance`, `IsActive` and `Active`: a skill reads `self.Caster`
	-- -- which the stand skills set to exactly this -- and indexes it on the very
	-- first frame.
	function self:AddStandFor(character: any, model: any)
		local active = true
		local visible = true

		-- Declared before it is built: a local is not in scope inside its own
		-- initialiser, so the methods below would otherwise capture a global
		-- named `stand` - which is nil, and fails on the first call.
		local stand: any

		-- `instance` is a real Model, not the asset stand-in. A skill hands it
		-- straight to `QueryDescendants` and to `VFXService:StartEffect`, and an
		-- asset node answers those calls with a child table instead of a
		-- collection. Its name is the asset path, which is enough to tell two
		-- stands apart in a trace.
		local shape = Roblox.Datatypes.Instance.new("Model")

		shape.Name = tostring(model)

		stand = {
			instance = shape,
			Active = true,
			Visible = true,

			IsActive = function()
				return active
			end,

			-- `Summon` toggles the stand on and off, and the visibility follows
			-- the active state. Reading `IsActive` afterwards has to give the new
			-- answer, or a test cannot tell a stand that was dismissed from one
			-- that was never there.
			SetActive = function(_self, state: boolean)
				active = state
				stand.Active = state

				trace:record("stand", { action = if state then "activated" else "removed" })
			end,

			SetVisible = function(_self, state: boolean)
				visible = state
				stand.Visible = state
			end,

			IsVisible = function()
				return visible
			end,

			Remove = function()
				active = false
			end,
			Animate = function() end,
			UnAnimate = function() end,

			-- A skill reads the stand the way it reads the character, including
			-- walking its descendants (`Punch` lights up the trail parts). The
			-- stand model in a test has none of them, and saying so with an empty
			-- list is the honest answer - a fake that invented descendants would
			-- make the loop run over something the game does not have.
			QueryDescendants = function()
				return {}
			end,
			GetDescendants = function()
				return {}
			end,
			GetChildren = function()
				return {}
			end,
		}

		stands[character] = stand

		trace:record("stand", { action = "added" })

		return stand
	end

	return self
end

--- Assembles `Crane` as a whole: the services, `Buttler`, `Signal` and whatever
--- the component lifecycle needs.
function Services.crane(services: { [string]: any }): any
	const self = {}

	function self:GetService(name: string)
		local service = services[name]

		if service == nil then error(`harness: unknown service '{name}'`, 2) end

		return service
	end

	function self:CreateService(data: { [string]: any })
		return services[data.Name]
	end

	function self:AddComponent(_instance: any, name: string)
		return self:GetComponent(name)
	end

	function self:GetComponent(name: string)
		if name == "Character" then return services.Character end

		return Services.stub()
	end

	function self:GetPacket(_name: string)
		return { sendTo = function() end, listen = function() end }
	end

	self.Buttler = Butler
	self.Signal = Services.signal
	self.Utils = {
		DeepFreeze = function(value: any)
			return value
		end,
		ChangeNetworkOwner = function() end,
	}

	return self
end

return Services
