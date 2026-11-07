--!native

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Animate = require(script.Animate)
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Parameters = require(script.Parameters)
const ParametersWatchers = require(script.Watchers)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const types = require(ServerScriptService.server.types)

type CleanUp = types.CleanUp

type Parameters = types.Parameters
type ParameterName = keyof<Parameters>
type ParameterValue<K = ParameterName> = index<index<Parameters, K>, "Default">

type ParameterObject<T> = types.ParameterObject<T>

type Bind = Enum.KeyCode | Enum.UserInputType

const attachmentCFrames = {
	["Neck"] = {
		CFrame.new(0, 1, 0, 0, -1, 0, 1, 0, -0, 0, 0, 1),
		CFrame.new(0, -0.5, 0, 0, -1, 0, 1, 0, -0, 0, 0, 1),
	},
	["Left Shoulder"] = {
		CFrame.new(-1.3, 0.75, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1),
		CFrame.new(0.2, 0.75, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1),
	},
	["Right Shoulder"] = {
		CFrame.new(1.3, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
		CFrame.new(-0.2, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	},
	["Left Hip"] = {
		CFrame.new(-0.5, -1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1),
		CFrame.new(0, 1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1),
	},
	["Right Hip"] = {
		CFrame.new(0.5, -1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1),
		CFrame.new(0, 1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1),
	},
}

-- const removeFriction = function(character: Model)
-- 	const noFriction = PhysicalProperties.new(0.7, 0, 0.5, 1, 1)
--
-- 	for i, part in character:QueryDescendants("BasePart") do
-- 		part.CustomPhysicalProperties = noFriction
--
-- 		if part.Name == "HumanoidRootPart" then
-- 			continue
-- 		end
--
-- 		if part.Name == "Left Leg" or part.Name == "Right Leg" then
-- 			continue
-- 		end
--
-- 		part.Massless = true
-- 	end
-- end

const createColliderPart = function(part: BasePart)
	if not part then return end
	const rp = Instance.new("Part")
	rp.Name = "ColliderPart"
	rp.Size = part.Size / 1.2
	rp.Massless = true
	rp.CFrame = part.CFrame
	rp.Transparency = 1
	rp.CanQuery = false
	rp.CanTouch = false
	rp.CanCollide = false
	rp.CollisionGroup = "Ragdoll"

	const wc = Instance.new("WeldConstraint")
	wc.Part0 = rp
	wc.Part1 = part

	wc.Parent = rp
	rp.Parent = part

	return rp
end

const SafeChangeNetworkOwnership = function(obj: BasePart, player: Player?)
	if obj:CanSetNetworkOwnership() then obj:SetNetworkOwner(player) end
end

const Character: types.Character = Crane:CreateComponent({
	Name = "Character",
})

function Character.onStart(self: typeof(Character))
	self.SpecService = Crane:GetService("SpecService")
	self.SkillService = Crane:GetService("SkillService")
	self.Spec = nil
	self.SubSpec = nil

	self.Cleaner = Crane.Buttler.new()
	self.OnTakeDamage = Crane.Signal()

	self.RagdollConstraints = {}
	self.RagdollColliders = {}
	self.Motors = {}

	self.Humanoid = self.instance:WaitForChild("Humanoid")
	self.RootPart = self.instance:WaitForChild("HumanoidRootPart")

	self.Player = Players:GetPlayerFromCharacter(self.instance)
	self.NPCNetworkOwner = nil :: Player?

	self.Humanoid.BreakJointsOnDeath = false
	self.Humanoid.RequiresNeck = false
	self.instance.PrimaryPart = self.RootPart

	self.Parameters = {}
	-- Set by `Destroy`: every parameter writer checks it so a late watcher or a
	-- task that outlived the cleaner cannot touch a torn down parameter table.
	self.TornDown = false

	self.Block = {
		Blocking = false,
		Changed = Crane.Signal(),
		PerfectBlockTime = 0,
		PerfectBlockWindow = 0,
		AlwaysPerfect = false,
	}

	for name, value in Parameters do
		self.Parameters[name] = {
			Watchers = {},
			Objects = {},
		}
	end

	self.Parameters.NoDeath.Debt = 0
	self.Parameters.NoDeath.DebtFrom = nil
	self.Parameters.NoDeath.Generation = 0
	self.Parameters.NoDeath.Draining = false

	self.Parameters.DamageHold.Queue = {}
	self.Parameters.DamageHold.Generation = 0
	self.Parameters.DamageHold.Draining = false

	for name, watcher in ParametersWatchers do
		self.Cleaner:Add(self:WatchParameter(name, function(value, object)
			watcher(self, value, object)
		end))
	end

	self.instance.Parent = workspace.Live

	task.defer(function()
		self.instance:AddTag("HeadInfo")
	end)

	self.Cleaner:Add(self.Humanoid.HealthChanged:Connect(function(health)
		-- TODO: add ragdoll
		if health <= 0 then
			task.wait(2)
			self.instance:Destroy()
		end
	end))

	self:prepareRagdoll()

	self.Humanoid.NameDisplayDistance = 0
	self.Humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	if not self.Player then
		Animate(self.instance)
		self.Humanoid.AutomaticScalingEnabled = false
	end

	--removeFriction(self.instance)
end

--- The spec is installed by its configured type (`SpecService:GetSpecType`):
--- `Type = "Spec"` goes to the primary slot, `Type = "SubSpec"` to the
--- secondary. There is no `SetSubSpec` — the config decides, not the caller.
function Character.SetSpec(
	self: typeof(Character),
	name: string,
	skin: string?,
	binds: { [string]: Bind }?,
	instanceId: string?
): types.Spec?
	const slot = self.SpecService:GetSpecType(name)
	if not slot then return nil end

	-- Create first so invalid specs do not destroy the currently equipped one.
	const created = self.SpecService:CreateSpec(self, {
		Id = name,
		Skin = skin or "None",
		Binds = binds or {},
		InstanceId = instanceId,
	})
	if not created then return nil end

	const previous = if slot == "Spec" then self.Spec else self.SubSpec
	if previous then self.Cleaner:Remove(slot) end
	self.Cleaner:Set(slot, created, "Destroy")

	if slot == "Spec" then
		self.Spec = created
	else
		self.SubSpec = created
	end

	-- Only the primary slot owns the body movement animations.
	created:Init({ Movement = slot == "Spec" })

	return created
end

function Character.ClearSpec(self: typeof(Character))
	if self.Spec then
		self.Cleaner:Remove("Spec")
		self.Spec = nil
	end
end

function Character.ClearSubSpec(self: typeof(Character))
	if self.SubSpec then
		self.Cleaner:Remove("SubSpec")
		self.SubSpec = nil
	end
end

function Character.GetSpec(self: typeof(Character)): types.Spec?
	return self.Spec
end

function Character.GetSubSpec(self: typeof(Character)): types.Spec?
	return self.SubSpec
end

function Character.CheckActiveSkills(self: typeof(Character)): (boolean, { types.Skill })
	const activeSkills: { types.Skill } = {}

	for _, spec in { self.Spec, self.SubSpec } do
		if not spec then continue end

		const _, specSkills = spec:CheckActiveSkills()
		for _, skill in specSkills do
			table.insert(activeSkills, skill)
		end
	end

	return #activeSkills > 0, activeSkills
end

function Character.SetEnableSkills(self: typeof(Character), tag: string, state: boolean)
	for _, spec in { self.Spec, self.SubSpec } do
		if spec then spec:SetEnableSkills(tag, state) end
	end
end

function Character.AddParameter<T>(
	self: typeof(Character),
	param: ParameterName,
	value: ParameterValue<T>
): ParameterObject<T>
	const newParamObject = {
		Value = value,
		Cleaner = self.Cleaner:Scope(),

		Destroy = function(currentParam)
			if self.TornDown then return end

			currentParam.Cleaner:Clean()
			if table.find(self.Parameters[param].Objects, currentParam) then
				table.remove(
					self.Parameters[param].Objects,
					table.find(self.Parameters[param].Objects, currentParam)
				)

				const newValue, object = self:GetParameter(param)
				for i, watcher in self.Parameters[param].Watchers do
					watcher(newValue, object)
				end
			end
		end,
	} :: ParameterValue<ParameterName>

	table.insert(self.Parameters[param].Objects, newParamObject)

	const newValue, object = self:GetParameter(param)
	for i, watcher in self.Parameters[param].Watchers do
		watcher(newValue, object)
	end

	return newParamObject
end

--- Mutates the owner object of a state parameter and notifies its watchers.
function Character.SetParameterValue<T>(
	self: typeof(Character),
	param: ParameterName,
	value: ParameterValue<T>
): ParameterValue<T>
	if self.TornDown then return value end

	const object = self.Parameters[param].Objects[1]
	if not object then error(`[Character] Parameter "{param}" has no owner object`, 2) end

	object.Value = value
	return self:RefreshParameter(param)
end

--- Re-runs a parameter's watchers without changing the aggregate value.
function Character.RefreshParameter<T>(
	self: typeof(Character),
	param: ParameterName
): ParameterValue<T>
	if self.TornDown then return Parameters[param].Default end

	const value, object = self:GetParameter(param)
	for _, watcher in self.Parameters[param].Watchers do
		watcher(value, object)
	end

	return value
end

function Character.GetParameter<T>(self: typeof(Character), param: ParameterName): ParameterValue<T>
	if self.TornDown then return Parameters[param].Default end

	local value = Parameters[param].Default
	const parser = Parameters[param].Parser
	local object

	for i, obj in self.Parameters[param].Objects do
		value = parser(value, obj.Value)

		if obj.Value == value then object = obj end
	end

	return value, object
end

function Character.WatchParameter<T>(
	self: typeof(Character),
	param: ParameterName,
	callback: (
		value: ParameterValue<T>?,
		object: ParameterObject<T>?
	) -> ()
): CleanUp
	if self.TornDown then
		return function() end
	end

	table.insert(self.Parameters[param].Watchers, callback)

	return function()
		if table.find(self.Parameters[param].Watchers, callback) then
			table.remove(
				self.Parameters[param].Watchers,
				table.find(self.Parameters[param].Watchers, callback)
			)
		end
	end
end

function Character:SetCollisionToPlayers(collide: boolean)
	Crane:GetService("CollisionService"):SetCollisionGroup(
		collide and (Players:GetPlayerFromCharacter(self.instance) and "Player" or "NPC")
			or "NoCollision",
		self.instance
	)
end

function Character.ClaimNPCNetworkOwner(self: types.Character, player: Player?)
	if self.Player or self.Humanoid.Health <= 0 then return end
	self.NPCNetworkOwner = player
	Crane.Utils.ChangeNetworkOwner(self.instance, player)
end

function Character.Ragdoll(self: types.Character, state: boolean)
	const humanoid = self.Humanoid
	if not humanoid or not self.instance then return end

	const StandService = Crane:GetService("StandService")

	const stand = StandService:GetStand(self) :: types.Stand
	if stand then stand:SetVisibilitySuppressed("Ragdoll", state) end

	if state then
		humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
	else
		--changing ownership to SERVER
		--SafeChangeNetworkOwnership(self.instance:FindFirstChild("Torso"), nil)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, not state)
	humanoid.AutoRotate = not state
	humanoid.PlatformStand = state

	for i, motor in self.Motors do
		motor.Enabled = not state
	end

	for i, ballSocket in self.RagdollConstraints do
		ballSocket.Enabled = state
	end

	for i, collider in self.RagdollColliders do
		collider.CanCollide = state
	end

	for i, part in self.instance:GetChildren() do
		if not part:IsA("BasePart") then continue end

		part.CanCollide = not state
		part.CollisionGroup = state and "Ragdoll" or "Player"
	end

	if not self.Player and self.Humanoid.Health > 0 then
		if not state then self.NPCNetworkOwner = nil end
		Crane.Utils.ChangeNetworkOwner(self.instance, self.NPCNetworkOwner)
	end

	if state then
		Crane:GetService("VFXService"):StartEffect({ self.instance }, "Ragdoll", {
			Character = self.instance,
		})
	else
		Crane:GetService("VFXService"):StopEffect({ self.instance }, "Ragdoll", {
			Character = self.instance,
		})
	end
end

function Character.prepareRagdoll(self: types.Character)
	const instance = self.instance
	const humanoid = self.Humanoid

	const isPlayer = Players:GetPlayerFromCharacter(self.instance)

	task.wait(0.5)
	self:replaceJoints()
	for i, part in self.instance:GetChildren() do
		if
			not part:IsA("BasePart")
			or part.Name == "HumanoidRootPart"
			or self.instance.Name == "Head"
		then
			continue
		end
		const collider: BasePart = createColliderPart(part)
		table.insert(self.RagdollColliders, collider)
	end

	if not isPlayer then
		for i, part in self.instance:GetDescendants() do
			if not part:IsA("BasePart") then continue end
			SafeChangeNetworkOwnership(part, self.NPCNetworkOwner)
		end
	end
end

function Character.replaceJoints(self: types.Character)
	for _, motor: Motor6D in self.instance:GetDescendants() do
		if motor:FindFirstAncestor("Stand") then continue end
		if not motor:IsA("Motor6D") then continue end
		if not attachmentCFrames[motor.Name] then continue end

		const a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.CFrame = attachmentCFrames[motor.Name][1]
		a1.CFrame = attachmentCFrames[motor.Name][2]

		a0.Name = "RagdollAttachment"
		a1.Name = "RagdollAttachment"

		const ballSocket = Instance.new("BallSocketConstraint")
		ballSocket.Attachment0 = a0
		ballSocket.Attachment1 = a1
		ballSocket.Name = "RagdollConstraint"

		ballSocket.Radius = 0.15
		ballSocket.LimitsEnabled = true
		ballSocket.TwistLimitsEnabled = false
		ballSocket.MaxFrictionTorque = 0
		ballSocket.Restitution = 0
		ballSocket.UpperAngle = 60
		ballSocket.TwistLowerAngle = -45
		ballSocket.TwistUpperAngle = 45

		if motor.Name == "Neck" then
			ballSocket.TwistLimitsEnabled = true
			ballSocket.UpperAngle = 45
			ballSocket.TwistLowerAngle = -70
			ballSocket.TwistUpperAngle = 70
		end

		a0.Parent = motor.Part0
		a1.Parent = motor.Part1
		ballSocket.Parent = motor.Parent

		table.insert(self.Motors, motor)
		table.insert(self.RagdollConstraints, ballSocket)
	end
end

function Character.Destroy(self: typeof(Character))
	-- The component is torn down top-down: the flag goes first so no watcher
	-- fired by the cleaner (or by a task that outlived it) can write to a
	-- parameter table or to the player proxy that is being released.
	self.TornDown = true

	const noDeath = self.Parameters.NoDeath
	noDeath.Generation += 1
	noDeath.Debt = 0
	noDeath.DebtFrom = nil

	const damageHold = self.Parameters.DamageHold
	damageHold.Generation += 1
	table.clear(damageHold.Queue)

	self.Cleaner:Destroy()
end

return Character
