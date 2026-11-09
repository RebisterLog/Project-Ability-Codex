--!native
--!optimize 2

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Hook = require(ServerScriptService.server["combat-classes"].Hook)
const Promise = require(ReplicatedStorage.shared.packages.Promise)
const Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
const Signal = Crane.Signal
const Enums = require(ServerScriptService.server.Enums)
const CharacterParameters = require(ServerScriptService.server.components.Character.Parameters)
const types = require(ServerScriptService.server.types)

const CombatService = Crane:CreateService({
	Name = "CombatService",
})

--[=[
	Hamon Charge

	A time-based resource: `Amount` is the value at the end of the hold window,
	and the live value is always derived from the timestamps. That keeps the
	server tick-free — it only schedules one delayed callback for the moment the
	charge reaches zero (or leaves that to the current mode) and reschedules it
	whenever the state changes.

	While `Filling` (the held Charge skill) the value grows at `FillRate`; the
	5 second hold starts when the fill stops. Afterwards the value decays at
	`DecayRate`. Consuming never extends the hold, it only lowers the base.
]=]

const function hamonState(character: types.Character)
	const entry = character.Parameters.HamonCharge
	const object = entry and entry.Objects[1]
	return object and object.Value
end

const function hamonEnsureState(character: types.Character)
	const state = hamonState(character)
	if state then return state end

	const default = table.clone(CharacterParameters.HamonCharge.Default)
	if not character.TornDown then character:AddParameter("HamonCharge", default) end
	return default
end

const function hamonEffective(state, now: number): number
	if state.Filling then
		return math.clamp(
			state.FillStartAmount + state.FillRate * (now - state.FillStartedAt),
			0,
			state.Max
		)
	end

	-- `Amount` describes the value at the end of the hold window, so the value
	-- is flat until then and linear afterwards.
	const holdEnd = state.LastGainAt + state.HoldSeconds
	if now <= holdEnd then return math.clamp(state.Amount, 0, state.Max) end

	return math.clamp(state.Amount - state.DecayRate * (now - holdEnd), 0, state.Max)
end

const function hamonScheduleExpiry(character: types.Character)
	const entry = character.Parameters.HamonCharge
	if not entry then return end

	entry.Generation = (entry.Generation or 0) + 1
	const generation = entry.Generation

	if character.TornDown then return end

	const state = hamonState(character)
	if not state or state.Filling or state.Amount <= 0 then return end

	const now = workspace:GetServerTimeNow()
	const expiresAt = state.LastGainAt + state.HoldSeconds + state.Amount / state.DecayRate
	const delay = expiresAt - now

	const function expire()
		if character.TornDown or entry.Generation ~= generation then return end

		const current = hamonState(character)
		if not current or current.Filling then return end

		const next = table.clone(current)
		next.Amount = 0
		next.LastGainAt = workspace:GetServerTimeNow()
		character:SetParameterValue("HamonCharge", next)
	end

	-- Deferring the zero-delay case keeps the publish path out of the caller's
	-- stack, which matters when the write itself triggered this schedule.
	if delay <= 0 then
		task.defer(expire)
	else
		task.delay(delay, expire)
	end
end

const function hamonPublish(character: types.Character, state)
	if character.TornDown then return end

	character:SetParameterValue("HamonCharge", state)
	hamonScheduleExpiry(character)
end

function CombatService:onStart()
	self.VFXService = Crane:GetService("VFXService")

	self.AttackHook = Hook.new("Attack", { "Precast", "Cast", "Postcast" })
	self.HealHook = Hook.new("Heal", { "Cast" })
	self.Casted = Signal()
	self.Attacked = Signal()
	self.Interrupted = Signal()

	for i, v in pairs(script.Hooks:GetChildren()) do
		if not v:IsA("ModuleScript") then continue end
		const module = require(v)
		const hook = if module.Hook == "Heal" then self.HealHook else self.AttackHook
		hook:Hook(module.Type, module.Name, module.Priority, module.Function)
	end

	self.AttackHook:Hook("Precast", "Main", 0, function(Data)
		if Data.NoDeathDeferred then return true end
		self.Attacked:Fire("Precast", Data)
		return true
	end)

	self.AttackHook:Hook("Cast", "Main", 0, function(Data)
		self.Attacked:Fire("Cast", Data)
		return true
	end)

	self.AttackHook:Hook("Postcast", "Return", 0, function(Data)
		self.Attacked:Fire("Postcast", Data)
		return true
	end)
end

function CombatService:Hitbox(Data: types.HitboxData)
	const Caster = Data.Caster
	const Info = Data.Info
	const Skill = Data.Skill
	const RootPart = Caster.RootPart
	local Origin = Info.Origin or Caster.RootPart.CFrame
	const Size = Info.Size
	local Offset = Info.Offset or CFrame.identity
	const MovementCorrection = Info.MovementCorrection

	if Skill then task.spawn(function()
		self.Casted:Fire(Data)
	end) end

	local Params
	if Info.Parameters then
		Params = Info.Parameters
	else
		Params = OverlapParams.new()
		Params.MaxParts = 0
		Params.FilterType = Enum.RaycastFilterType.Include
		Params:AddToFilter(workspace.Live)
	end

	--if not Caster.Player then
	--	Params.CollisionGroup = "Player"
	--end

	if MovementCorrection then
		const humanoid = Caster.Humanoid
		const move = humanoid.MoveDirection
		const correction = Vector3.zAxis
			* math.min(
				0,
				(-Origin.LookVector:Dot(move) * RootPart.AssemblyLinearVelocity.Magnitude / 4)
			)

		Offset += correction
	end

	if Offset and Offset ~= CFrame.identity then
		Origin *= Offset
	end

	local Query: { Instance } = {}

	if typeof(Size) == "number" then
		Query = workspace:GetPartBoundsInRadius(Origin.Position, Size, Params)
	elseif typeof(Size) == "Vector3" then
		Query = workspace:GetPartBoundsInBox(Origin, Size, Params)
	end

	const Hit: { types.Character } = {}

	for _, Part: Instance in Query do
		if Part.Parent:FindFirstChildOfClass("Humanoid") then
			const TargetComponent = Crane:GetComponent("Character", Part.Parent) :: types.Character

			if TargetComponent and not TargetComponent.Player and not Caster.Player then
				continue
			end
			if not (TargetComponent and not table.find(Hit, TargetComponent)) then continue end
			if TargetComponent == Caster and not Info.CanQueryCaster then continue end
			table.insert(Hit, TargetComponent)
		end
	end

	if Info.SortByDistance then
		table.sort(Hit, function(a: types.Character, b: types.Character)
			return (a.RootPart.Position - Caster.RootPart.Position).Magnitude
				< (b.RootPart.Position - Caster.RootPart.Position).Magnitude
		end)
	end

	if Info.Debug then
		self.VFXService:StartEffect({ Caster.instance }, "Hitbox", {
			Origin = Origin,
			Size = Size,
		})
	end

	return Hit
end

function CombatService:Attack(data: types.AttackData)
	if not data.NoDeathDeferred then
		data.State = self:GetStates(data.Victim)
		data.State.Success = true
		data.State.Continue = true

		const OriginalInfo = data.Info or {}

		if not table.isfrozen(OriginalInfo) then Crane.Utils.DeepFreeze(OriginalInfo) end

		data.OriginalInfo = OriginalInfo
		data.Info = table.clone(OriginalInfo)
	end

	return Promise.new(function(resolve)
		const result = self.AttackHook:Apply(data)
		if result then resolve(result) end
	end)
end

function CombatService:Heal(data: types.HealData)
	data.State = { Success = true }
	return self.HealHook:Apply(data)
end

--- The current Hamon Charge, including the in-progress fill and decay.
function CombatService:GetHamonCharge(character: types.Character): number
	const state = hamonEnsureState(character)
	return hamonEffective(state, workspace:GetServerTimeNow())
end

--- Adds a flat amount (a manual source, not the held skill). The 5 second hold
--- restarts at this moment, unless the held Charge skill is running — the hold
--- then starts when that fill stops.
function CombatService:AddHamonCharge(character: types.Character, amount: number): number
	if amount <= 0 then return self:GetHamonCharge(character) end

	const now = workspace:GetServerTimeNow()
	const state = hamonEnsureState(character)
	const next = table.clone(state)

	next.Amount = math.clamp(hamonEffective(state, now) + amount, 0, next.Max)

	if next.Filling then
		-- Materialize the jump and keep growing from it toward the cap.
		next.FillStartAmount = next.Amount
		next.FillStartedAt = now
	else
		next.LastGainAt = now
	end

	hamonPublish(character, next)
	return next.Amount
end

--- Spends charge. Returns `false, current` when there is not enough. The hold is
--- not extended: consuming is not an increase. A running fill keeps running
--- from the reduced value.
function CombatService:ConsumeHamonCharge(
	character: types.Character,
	cost: number
): (boolean, number)
	const now = workspace:GetServerTimeNow()
	const state = hamonEnsureState(character)
	const current = hamonEffective(state, now)

	if cost <= 0 then return true, current end
	if cost > current then return false, current end

	const remaining = math.max(0, current - cost)
	const next = table.clone(state)
	next.Amount = remaining

	if next.Filling then
		next.FillStartAmount = remaining
		next.FillStartedAt = now
	elseif now > next.LastGainAt + next.HoldSeconds then
		-- The hold is already over and the value is mid-decay. `Amount` is the
		-- value at the end of the hold, so the old window would decay the
		-- remaining value a second time; rebasing it onto `now` keeps the
		-- spend continuous without starting a fresh hold.
		next.LastGainAt = now - next.HoldSeconds
	end

	hamonPublish(character, next)
	return true, remaining
end

--- Starts the held Charge: the value grows at `FillRate` until released or capped.
function CombatService:StartHamonFill(character: types.Character): number
	const now = workspace:GetServerTimeNow()
	const state = hamonEnsureState(character)
	const current = hamonEffective(state, now)
	const next = table.clone(state)

	next.Filling = true
	next.FillStartedAt = now
	next.FillStartAmount = current
	next.Amount = current
	next.LastGainAt = now

	hamonPublish(character, next)
	return current
end

--- Stops the held Charge. The 5 second hold starts now, then the value decays.
--- Stopping twice is a no-op: a second call must not restart the hold.
function CombatService:StopHamonFill(character: types.Character): number
	const now = workspace:GetServerTimeNow()
	const state = hamonEnsureState(character)
	const current = hamonEffective(state, now)

	if not state.Filling then return current end

	const next = table.clone(state)

	next.Filling = false
	next.FillStartedAt = 0
	next.FillStartAmount = current
	next.Amount = current
	next.LastGainAt = now

	hamonPublish(character, next)
	return current
end

function CombatService.CreateSequence(Character: types.Character, data)
	const Sequence = Sequencer.new(data)

	Sequence:AdjustSpeed(Character:GetParameter("Timescale"))

	return Sequence
end

function CombatService.GetStates(self: typeof(CombatService), Character: types.Character)
	const States = {}

	if Character.Block and Character.Block.Blocking then
		States.Blocking = true

		const PerfectBlockWindow = Character.Block.PerfectBlockWindow
		const PerfectBlockTime = Character.Block.PerfectBlockTime

		if (os.clock() - PerfectBlockTime) <= PerfectBlockWindow then
			States.PerfectBlocking = true
		end
	end

	if Character.Block.AlwaysPerfect then
		States.Blocking = true
		States.PerfectBlocking = true -- just for testing dummies
	end

	if Character:GetParameter("Armor") == true then States.Armored = true end

	if Character:GetParameter("Ragdoll") == true then States.Ragdolled = true end

	const IFrames = Character:GetParameter("IFrames")
	if IFrames > 0 then States.IFrames = IFrames end

	return States
end

function CombatService.AddArmor(self: typeof(CombatService), Character: types.Character)
	local Cleaner = Crane.Buttler.new()

	Cleaner:Add(Character:AddParameter("Armor", true))

	local UUID = os.clock()
	self.VFXService:StartEffect(Players:GetPlayers(), "Highlight", {
		Character = Character.instance,
		UUID = UUID,
		FillColor = Color3.fromRGB(255, 136, 0),
		OutlineColor = Color3.fromRGB(255, 136, 0),
		OutlineTransparency = 0.1,
		FillTransparency = 0.8,
	})

	Cleaner:Add(function()
		self.VFXService:StopEffect(Players:GetPlayers(), "Highlight", { UUID = UUID })
	end)

	return Cleaner
end

-- Equips a model (a weapon, a tool, any prop) onto a character through a
-- Motor6D. The caller gets back the clone, already inside the character, so it
-- can own the lifetime (`seq.Cleaner:Add(...)`); the motor is returned
-- separately for callers that need to drive it.
--
-- Attributes for model:
--   HandleName - name of handle part, if it's not "Handle"
--
-- The mount part is always a part named `Handle`: a model without one is a
-- mistake in the asset, not a runtime state, so it raises instead of quietly
-- equipping nothing and leaving a combat bug to be found in game. Attributes of
-- that `Handle`:
--
--   MotorName — name of the created Motor6D (animations address motors by name)
--   Bone      — character part to mount on (defaults to "HumanoidRootPart")
--   Offset    — C0 of the motor, i.e. where the grip sits (defaults to identity)
function CombatService:Equip(character: types.Character, model: Model): (Model, Motor6D)
	const Handle = model:FindFirstChild("Handle")
		or model:FindFirstChild(model:GetAttribute("HandleName"))

	if not Handle or not Handle:IsA("BasePart") then
		error(`CombatService:Equip — {model.Name} has no Handle part`, 2)
	end

	const BoneName = Handle:GetAttribute("Bone") or "HumanoidRootPart"
	const Bone = character.instance:FindFirstChild(BoneName)

	if not Bone or not Bone:IsA("BasePart") then
		error(`CombatService:Equip — {character.instance.Name} has no {BoneName} part`, 2)
	end

	const Weapon = model:Clone()
	const WeaponHandle = Weapon:FindFirstChild(Handle.Name) :: BasePart

	for _, part in Weapon:GetDescendants() do
		if not part:IsA("BasePart") then continue end

		part.Anchored = false
		part.CanCollide = false
		part.Massless = true
	end

	const Motor = Instance.new("Motor6D")
	Motor.Name = Handle:GetAttribute("MotorName") or "Handle"
	Motor.Part0 = Bone
	Motor.C0 = Handle:GetAttribute("Offset") or CFrame.identity
	Motor.Part1 = WeaponHandle

	-- The motor lives inside the model, so destroying the model takes it away
	-- with the prop. Parenting comes last: clients never see a half-assembled
	-- weapon, and an unparented model neither replicates nor renders.
	Motor.Parent = WeaponHandle
	Weapon.Parent = character.instance

	return Weapon, Motor
end

const function makeMassless(character: types.Character): () -> ()
	const originalMassless: { [BasePart]: boolean } = {}
	for _, descendant in character.instance:GetDescendants() do
		if not descendant:IsA("BasePart") then continue end
		originalMassless[descendant] = descendant.Massless
		descendant.Massless = true
	end

	return function()
		for part, wasMassless in originalMassless do
			if part.Parent then part.Massless = wasMassless end
		end
	end
end

function CombatService.CreateGrab(
	self: typeof(CombatService),
	attacker: types.Character,
	victim: types.Character,
	grabData: types.GrabData?
)
	const data = grabData or {} :: types.GrabData

	const Cleaner = Crane.Buttler.new()

	Cleaner:Add(attacker:AddParameter("IFrames", Enums.IFrames.Grab))
	Cleaner:Add(victim:AddParameter("IFrames", Enums.IFrames.Grab))
	Cleaner:Add(victim:AddParameter("NoSkillCast", true))
	Cleaner:Add(makeMassless(victim))

	const victimPlayer = Players:GetPlayerFromCharacter(victim.instance)
	const attackerPlayer = Players:GetPlayerFromCharacter(attacker.instance)
	const previousNPCNetworkOwner = victim.NPCNetworkOwner

	if attackerPlayer then
		if victimPlayer then
			Crane.Utils.ChangeNetworkOwner(victim.instance, attackerPlayer)
			Cleaner:Add(function()
				Crane.Utils.ChangeNetworkOwner(victim.instance, victimPlayer)
			end)
		else
			victim:ClaimNPCNetworkOwner(attackerPlayer)
			Cleaner:Add(function()
				victim:ClaimNPCNetworkOwner(previousNPCNetworkOwner)
			end)
		end
	elseif victimPlayer then
		Crane.Utils.ChangeNetworkOwner(victim.instance, nil)
		Cleaner:Add(function()
			Crane.Utils.ChangeNetworkOwner(victim.instance, victimPlayer)
		end)
	end

	if data.Attacker then
		Cleaner:Add(attacker:AddParameter("NoCollision", true))

		if data.Attacker.Restrain ~= false then
			Cleaner:Add(attacker:AddParameter("Restrain", true))
		end

		const navigator = attacker.Navigator
		if navigator then
			navigator:DisableRotation()
			Cleaner:Add(function()
				navigator:EnableRotation()
			end)
		end
	end

	if data.Victim then
		Cleaner:Add(victim:AddParameter("NoCollision", true))

		if data.Victim.Restrain ~= false then Cleaner:Add(victim:AddParameter("Restrain", true)) end

		const humanoid = victim.Humanoid
		const wasPlatformStand = humanoid.PlatformStand
		humanoid.PlatformStand = true
		Cleaner:Add(function()
			if not humanoid.Parent then return end
			humanoid.PlatformStand = wasPlatformStand or victim:GetParameter("Ragdoll") == true

			victim.RootPart.CFrame = victim.instance:FindFirstChild("Torso").CFrame
		end)

		if data.Victim.Bind then
			const Bind = data.Victim.Bind
			const C0 = Bind.Offset or CFrame.identity
			const C1 = Bind.Offset1 or CFrame.identity

			Bind.Part1.CFrame = Bind.Part0.CFrame * C0 * C1:Inverse()
			Bind.Part1.AssemblyLinearVelocity = Vector3.zero
			Bind.Part1.AssemblyAngularVelocity = Vector3.zero

			const Weld = Cleaner:Construct(Instance, "Weld") :: Weld

			Weld.C0 = C0
			Weld.C1 = C1
			Weld.Part0 = Bind.Part0
			Weld.Part1 = Bind.Part1
			Weld.Parent = Bind.Part1
		end
	end

	return Cleaner
end

return CombatService
