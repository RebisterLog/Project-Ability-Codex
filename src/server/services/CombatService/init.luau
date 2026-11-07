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
const types = require(ServerScriptService.server.types)

const CombatService = Crane:CreateService({
	Name = "CombatService",
})

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
