--!native
--!optimize 2

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const SharedStand = require(ReplicatedStorage.shared.components.Stand)

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

const Stand: types.Stand = Crane:CreateComponent({
	Name = "Stand",
	BaseComponent = SharedStand,
})

const prepareStandModel = function(model: Model)
	for i, part in model:QueryDescendants("BasePart") :: { BasePart } do
		part.Anchored = false
		part.Massless = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
	end

	local animatorController = model:FindFirstChildOfClass("AnimationController")
	if not animatorController then
		animatorController = Instance.new("AnimationController")
		animatorController.Parent = model
	end

	local animator = animatorController:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = animatorController
	end
end

function Stand.onStart(self: types.Stand)
	self.Cleaner = Crane.Buttler.new()
	self.RootPart = self.instance:FindFirstChild("HumanoidRootPart") or self.instance.PrimaryPart

	prepareStandModel(self.instance)

	const parts = self.instance:QueryDescendants("BasePart") :: { BasePart }
	const decals = self.instance:QueryDescendants("Decal") :: { Decal }

	for i, part in parts do
		part:SetAttribute("Transparency", part.Transparency)
	end

	for i, decal in decals do
		decal:SetAttribute("Transparency", decal.Transparency)
	end

	task.defer(function()
		self.instance:AddTag("Stand")
	end)

	const parts = self.instance:QueryDescendants("BasePart") :: { BasePart }
	const decals = self.instance:QueryDescendants("Decal") :: { Decal }

	for i, part in parts do
		part.Transparency = 1
	end

	for i, decal in decals do
		decal.Transparency = 1
	end
end

function Stand.Init(self: types.Stand, owner: types.Character)
	self.Owner = owner

	const weld = self.Cleaner:Construct(Instance, "Weld") :: Weld
	weld.Parent = owner.RootPart

	weld.Part0 = owner.RootPart
	weld.Part1 = self.RootPart

	self.instance.Parent = workspace.Stands

	self.Owner.Humanoid.Died:Once(function()
		self:SetVisible(false)
	end)
end

function Stand.SetVisible(self: types.Stand, state: boolean)
	if self.Visible == state then return end

	if self.VisibleDelay then
		task.cancel(self.VisibleDelay)
		self.VisibleDelay = nil
	end

	self.Visible = state

	const summon = state and "Summon" or "Unsummon"

	Crane:GetService("VFXService"):StartEffect(Players:GetPlayers(), "Summon", self.instance, state)

	Crane:GetService("VFXService"):StartEffect(Players:GetPlayers(), "Animation", self.instance, {
		Animation = self.Owner.Spec.Data.Assets.Stand.Animations[summon],
	})

	if state then
		Crane:GetService("VFXService"):StartEffect(
			Players:GetPlayers(),
			"Sound",
			self.RootPart,
			self.Owner.Spec.Data.Assets.Stand.Sounds[summon]
		)

		Crane:GetService("VFXService"):StartEffect(
			Players:GetPlayers(),
			"Sound",
			self.RootPart,
			self.Owner.Spec.Data.Assets.Stand.Sounds[summon .. "VL"]
		)

		Crane:GetService("VFXService"):StartEffect(Players:GetPlayers(), "EmitParticle", {
			Particle = self.Owner.Spec.Data.Assets.Stand.Models[summon],
			Origin = self.RootPart,
		})
	end

	self.VisibleDelay = task.delay(1, function()
		const parts = self.instance:QueryDescendants("BasePart") :: { BasePart }
		const decals = self.instance:QueryDescendants("Decal") :: { Decal }

		for i, part in parts do
			part.Transparency = state and (part:GetAttribute("Transparency") or 0) or 1
		end

		for i, decal in decals do
			decal.Transparency = state and (decal:GetAttribute("Transparency") or 0) or 1
		end
	end)
end

function Stand.SetActive(self: types.Stand, state: boolean)
	if self.Active == state then return end
	self.Active = state
end

function Stand:IsActive(): boolean
	return self.Active
end

function Stand:IsVisible(): boolean
	return self.Visible
end

function Stand:Destroy()
	self.Cleaner:Destroy()
end

return Stand
