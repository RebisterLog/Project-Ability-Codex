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

	self.Cleaner = Crane.Buttler.new()
	self.OnTakeDamage = Crane.Signal()

	self.RagdollConstraints = {}
	self.RagdollColliders = {}
	self.Motors = {}

	self.Humanoid = self.instance:WaitForChild("Humanoid")
	self.RootPart = self.instance:WaitForChild("HumanoidRootPart")

	self.Player = Players:GetPlayerFromCharacter(self.instance)

	self.Humanoid.BreakJointsOnDeath = false
	self.Humanoid.RequiresNeck = false
	self.instance.PrimaryPart = self.RootPart

	self.Parameters = {}

	self.Block = {
		Blocking = false,
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
		if health <= 0 then
			task.wait(2)
			self.instance:Destroy()
		end
	end))

	self:prepareRagdoll()

	if not self.Player then
		Animate(self.instance)
		self.Humanoid.AutomaticScalingEnabled = false
	end
end

function Character.SetSpec(
	self: typeof(Character),
	id: string,
	skin: string?,
	binds: { [string]: Bind }?
)
	if self.Spec then self.Cleaner:Remove("Spec") end

	const spec = self.Cleaner:Set(
		"Spec",
		self.SpecService:CreateSpec(self, {
			Id = id,
			Skin = skin or "None",
			Binds = binds or {},
		}),
		"Destroy"
	)

	self.Spec = spec
	self.Spec:Init()

	return spec
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

function Character.GetParameter<T>(self: typeof(Character), param: ParameterName): ParameterValue<T>
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

function Character.Ragdoll(self: types.Character, state: boolean)
	const humanoid = self.Humanoid
	if not humanoid or not self.instance then return end

	const StandService = Crane:GetService("StandService")

	const stand = StandService:GetStand(self) :: types.Stand
	const isStandVisible = stand and stand:IsVisible() or false

	if stand and state == isStandVisible then
		if state then
			self.StandWasActive = true
			stand:SetVisible(not state)
		else
			if self.StandWasActive then
				self.StandWasActive = false
				stand:SetVisible(not state)
			end
		end
	end

	if not Players:GetPlayerFromCharacter(self.instance) and not state then
		SafeChangeNetworkOwnership(self.RootPart, nil)
	end

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

	if state then
		Crane:GetService("VFXService"):StartEffect({ self.instance }, "Ragdoll", self.instance)
	else
		Crane:GetService("VFXService"):StopEffect({ self.instance }, "Ragdoll", self.instance)
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
			SafeChangeNetworkOwnership(part)
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
	self.Cleaner:Destroy()
end

return Character
