--!native
--!optimize 2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Hook = require(ServerScriptService.server["combat-classes"].Hook)
local Promise = require(ReplicatedStorage.shared.packages.Promise)
local Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
local Signal = Crane.Signal
local Enums = require(ServerScriptService.server.Enums)
local types = require(ServerScriptService.server.types)

local CombatService = Crane:CreateService({
	Name = "CombatService",
})

function CombatService:onStart()
	self.VFXService = Crane:GetService("VFXService")

	self.AttackHook = Hook.new("Attack", { "Precast", "Cast", "Postcast" })
	self.Casted = Signal.new()
	self.Attacked = Signal.new()
	self.Interrupted = Signal.new()

	for i, v in pairs(script.Hooks:GetChildren()) do
		if not v:IsA("ModuleScript") then continue end
		local module = require(v)
		self.AttackHook:Hook(module.Type, module.Name, module.Priority, module.Function)
	end

	self.AttackHook:Hook("Precast", "Main", 0, function(Data)
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
	local Caster = Data.Caster
	local Info = Data.Info
	local Skill = Data.Skill
	local RootPart = Caster.RootPart
	local Origin = Info.Origin or Caster.RootPart.CFrame
	local Size = Info.Size
	local Offset = Info.Offset or CFrame.identity
	local MovementCorrection = Info.MovementCorrection

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
		local humanoid = Caster.Humanoid
		local move = humanoid.MoveDirection
		local correction = Vector3.zAxis
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

	local Hit: { types.Character } = {}

	for _, Part: Instance in Query do
		if Part.Parent:FindFirstChildOfClass("Humanoid") then
			local TargetComponent = Crane:GetComponent("Character", Part.Parent) :: types.Character

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

	if Info.Debug then self.VFXService:StartEffect({ Caster.instance }, "Hitbox", Origin, Size) end

	return Hit
end

function CombatService:Attack(data: types.AttackData)
	data.State = CombatService:GetStates(data.Victim)
	data.State.Success = true
	data.State.Continue = true

	data.OriginalInfo = (data.Info or {})
	data.Info = table.clone(data.OriginalInfo)

	return Promise.new(function(resolve)
		local result = self.AttackHook:Apply(data)
		if result then resolve(result) end
	end)
end

function CombatService.CreateSequence(Character: types.Character, data)
	local Sequence = Sequencer.new(data)

	Sequence:AdjustSpeed(Character:GetParameter("Timescale"))

	return Sequence
end

function CombatService.GetStates(self: typeof(CombatService), Character: types.Character)
	local States = {}

	if Character.Block and Character.Block.Blocking then
		States.Blocking = true

		local PerfectBlockWindow = Character.Block.PerfectBlockWindow
		local PerfectBlockTime = Character.Block.PerfectBlockTime

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

	local IFrames = Character:GetParameter("IFrames")
	if IFrames > 0 then States.IFrames = IFrames end

	return States
end

function CombatService.AddArmor(self: typeof(CombatService), Character: types.Character)
	local Cleaner = Crane.Buttler.new()

	Cleaner:Add(Character:AddParameter("Armor", true))

	local UUID = os.clock()
	self.VFXService:StartEffect(Players:GetPlayers(), "Highlight", Character.instance, {
		UUID = UUID,
		FillColor = Color3.fromRGB(255, 136, 0),
		OutlineColor = Color3.fromRGB(255, 136, 0),
		OutlineTransparency = 0.1,
		FillTransparency = 0.8,
	})
	Cleaner:Add(function()
		self.VFXService:StopEffect(Players:GetPlayers(), "Highlight", UUID)
	end)

	return Cleaner
end

function CombatService.CreateGrab(
	self: typeof(CombatService),
	attacker: types.Character,
	victim: types.Character,
	grabData: types.GrabData?
)
	local data = grabData or {} :: types.GrabData

	local Cleaner = Crane.Buttler.new()

	Cleaner:Add(attacker:AddParameter("IFrames", Enums.IFrames.Grab))
	Cleaner:Add(victim:AddParameter("IFrames", Enums.IFrames.Grab))

	local victimPlayer = Players:GetPlayerFromCharacter(victim.instance)
	local attackerPlayer = Players:GetPlayerFromCharacter(attacker.instance)

	if attackerPlayer then
		Crane.Utils.ChangeNetworkOwner(
			victim.instance,
			Players:GetPlayerFromCharacter(attacker.instance)
		)

		Cleaner:Add(function()
			Crane.Utils.ChangeNetworkOwner(victim.instance, victimPlayer)
		end)
	end

	if data.Attacker then
		Cleaner:Add(attacker:AddParameter("NoCollision", true))

		if data.Attacker.Restrain ~= false then
			Cleaner:Add(attacker:AddParameter("Restrain", true))
		end
	end

	if data.Victim then
		Cleaner:Add(victim:AddParameter("NoCollision", true))

		if data.Victim.Restrain ~= false then Cleaner:Add(victim:AddParameter("Restrain", true)) end

		if data.Victim.Bind then
			local Part0Attachment = Cleaner:Construct(Instance, "Attachment")
			local Part1Attachment = Cleaner:Construct(Instance, "Attachment")

			local AlignPosition = Cleaner:Construct(Instance, "AlignPosition")
			local AlignOrientation = Cleaner:Construct(Instance, "AlignOrientation")

			Part0Attachment.CFrame = data.Victim.Bind.Offset
			Part1Attachment.CFrame = data.Victim.Bind.Offset1 or CFrame.identity

			Part0Attachment.Parent = data.Victim.Bind.Part0
			Part1Attachment.Parent = data.Victim.Bind.Part1

			AlignPosition.RigidityEnabled = true
			AlignPosition.Attachment0 = Part1Attachment
			AlignPosition.Attachment1 = Part0Attachment
			AlignPosition.Parent = data.Victim.Bind.Part1

			AlignOrientation.RigidityEnabled = true
			AlignOrientation.Attachment0 = Part1Attachment
			AlignOrientation.Attachment1 = Part0Attachment
			AlignOrientation.Parent = data.Victim.Bind.Part1
		end
	end

	return Cleaner
end

return CombatService
