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

const function prepareStandModel(model: Model)
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
	self.Active = false
	self.Visible = false
	self.VisibilityRevision = 0
	self.VisibilitySuppressions = {}

	prepareStandModel(self.instance)

	const parts = self.instance:QueryDescendants("BasePart") :: { BasePart }
	const decals = self.instance:QueryDescendants("Decal") :: { Decal }
	const emitters = self.instance:QueryDescendants("ParticleEmitter") :: { ParticleEmitter }

	-- The authored look is snapshotted before everything is hidden: the delayed
	-- restore reads these attributes, so a stand always returns to exactly the
	-- transparency and emission it was built with.
	for i, part in parts do
		part:SetAttribute("Transparency", part.Transparency)
	end

	for i, decal in decals do
		decal:SetAttribute("Transparency", decal.Transparency)
	end

	for i, emitter in emitters do
		emitter:SetAttribute("EmitEnabled", emitter.Enabled)
	end

	task.defer(function()
		self.instance:AddTag("Stand")
	end)

	for i, part in parts do
		part.Transparency = 1
	end

	for i, decal in decals do
		decal.Transparency = 1
	end

	for i, emitter in emitters do
		emitter.Enabled = false
	end
end

function Stand.Init(self: types.Stand, owner: types.Character)
	self.Owner = owner
	-- Force the initial transition so the replicated attribute and owner idle are initialized.
	self.Active = true
	self:SetActive(false)

	self.instance.Parent = workspace.Stands
	self:WeldToOwner()

	self.Owner.Humanoid.Died:Once(function()
		self:SetVisibilitySuppressed("Dead", true)
	end)

	self.Cleaner:Add(function()
		Crane:GetService("VFXService"):StopEffect(Players:GetPlayers(), "StandAura", {
			Character = self.Owner.instance,
		})
	end)
end

function Stand.WeldTo(self: types.Stand, part: BasePart)
	self.Cleaner:Remove("StandWeld")

	const weld = Instance.new("Weld")
	weld.Name = "StandWeld"
	weld.Part0 = part
	weld.Part1 = self.RootPart
	weld.Parent = part

	self.Cleaner:Set("StandWeld", weld)
end

function Stand.WeldToOwner(self: types.Stand)
	self.Cleaner:Remove("StandWeld")
	self.Cleaner:Remove("StandAnchor")
	self.RootPart.CFrame = self.Owner.RootPart.CFrame
	self.RootPart.AssemblyLinearVelocity = Vector3.zero
	self.RootPart.AssemblyAngularVelocity = Vector3.zero
	self:WeldTo(self.Owner.RootPart)
end

function Stand.WeldToPoint(self: types.Stand, cframe: CFrame)
	self.Cleaner:Remove("StandWeld")
	self.Cleaner:Remove("StandAnchor")

	const anchor = Instance.new("Part")
	anchor.Name = "StandAnchor"
	anchor.Size = Vector3.one
	anchor.CFrame = cframe
	anchor.Anchored = true
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Parent = workspace.Stands

	self.Cleaner:Set("StandAnchor", anchor)
	self.RootPart.CFrame = cframe
	self:WeldTo(anchor)
end

function Stand.RefreshVisibility(self: types.Stand)
	self:SetVisible(self.Active and next(self.VisibilitySuppressions) == nil)
end

function Stand.SetVisibilitySuppressed(self: types.Stand, reason: string, state: boolean)
	if state then
		self.VisibilitySuppressions[reason] = true
	else
		self.VisibilitySuppressions[reason] = nil
	end

	self:RefreshVisibility()
end

function Stand.SetVisible(self: types.Stand, state: boolean)
	if self.Visible == state then return end
	self.VisibilityRevision += 1
	const revision = self.VisibilityRevision

	if self.VisibleDelay then
		task.cancel(self.VisibleDelay)
		self.VisibleDelay = nil
	end

	self.Visible = state

	const summon = state and "Summon" or "Unsummon"
	const VFXService = Crane:GetService("VFXService")

	VFXService:StartEffect(Players:GetPlayers(), "Summon", {
		Stand = self.instance,
		Visible = state,
	})

	-- Stand assets live on the primary spec; every read is nil-safe so a spec
	-- without a stand asset set simply skips the presentation.
	const spec = self.Owner.Spec
	const assets = spec and spec.Data.Assets.Stand
	-- const animation = assets and assets.Animations[summon]
	-- if animation then
	-- 	VFXService:StartEffect(Players:GetPlayers(), "Animation", self.instance, {
	-- 		Animation = animation,
	-- 	})
	-- end

	const sound = assets and assets.Sounds[summon]
	if sound then
		VFXService:StartEffect(Players:GetPlayers(), "Sound", {
			Origin = self.RootPart,
			Sound = sound,
		})
	end

	const voiceLine = assets and assets.Sounds[summon .. "VL"]
	if voiceLine then
		VFXService:StartEffect(Players:GetPlayers(), "Sound", {
			Origin = self.RootPart,
			Sound = voiceLine,
		})
	end

	-- The aura glows on the owner's body, not on the rig, so it follows the
	-- visibility transition of the stand instead of living in the stand model.
	const aura = assets and assets.Aura
	if aura then
		if state then
			VFXService:StartEffect(Players:GetPlayers(), "StandAura", {
				Character = self.Owner.instance,
				Aura = aura,
			})
		else
			VFXService:StopEffect(Players:GetPlayers(), "StandAura", {
				Character = self.Owner.instance,
			})
		end
	end

	if state then
		const particle = assets and assets.Models[summon]
		if particle then
			VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
				Particle = particle,
				Origin = self.RootPart,
			})
		end
	end

	self.VisibleDelay = task.delay(1, function()
		if revision ~= self.VisibilityRevision then return end

		const parts = self.instance:QueryDescendants("BasePart") :: { BasePart }
		const decals = self.instance:QueryDescendants("Decal") :: { Decal }
		const emitters = self.instance:QueryDescendants("ParticleEmitter") :: { ParticleEmitter }

		for i, part in parts do
			part.Transparency = state and (part:GetAttribute("Transparency") or 0) or 1
		end

		for i, decal in decals do
			decal.Transparency = state and (decal:GetAttribute("Transparency") or 0) or 1
		end

		for i, emitter in emitters do
			emitter.Enabled = state and (emitter:GetAttribute("EmitEnabled") or false) or false
		end

		if revision == self.VisibilityRevision then self.VisibleDelay = nil end
	end)
end

function Stand.SetActive(self: types.Stand, state: boolean)
	if self.Active == state then return end
	self.Active = state
	self.instance:SetAttribute("Active", state)

	const owner = self.Owner
	if not owner then return end

	self:RefreshVisibility()
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
