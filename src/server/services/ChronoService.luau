--!native
--!optimize 2

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Chrono = require(ReplicatedStorage.shared.packages.Chrono)
const LagCompensation = require(ReplicatedStorage.shared.combat.LagCompensation)

const ChronoService = Crane:CreateService({
	Name = "ChronoService",
	LoadOrder = -500,
})

ChronoService.Samples = {} :: { [Player]: LagCompensation.AimSample }
ChronoService.Entities = {} :: { [Model]: Chrono.Entity }

--- Must run before any service touches Entity.new: Chrono locks its config in
--- Start and rejects registrations afterwards.
function ChronoService:onInit()
	Chrono.Start(ReplicatedStorage.shared.configs.Chrono)
end

--- Crane stores services in a dictionary, so its `table.sort` by LoadOrder is
--- ineffective: another service's onStart can run before ours. Callers that
--- register NPCs must therefore be able to initialise the cleaner themselves.
function ChronoService:EnsureCleaner()
	if self.Cleaner then return end

	self.Cleaner = Crane.Buttler.new()
	self.Cleaner:Add(Players.PlayerRemoving:Connect(function(player: Player)
		self.Samples[player] = nil
	end))
end

function ChronoService:onStart()
	self:EnsureCleaner()
end

--- Called by SkillService with the aim timestamps carried by StartSkill, so a
--- sample can never arrive out of order with the activation it belongs to.
function ChronoService:RecordAim(player: Player, aimNormal: number, aimHalf: number)
	self.Samples[player] = {
		Normal = if aimNormal > 0 then aimNormal else nil,
		Half = if aimHalf > 0 then aimHalf else nil,
		ReceivedAt = os.clock(),
	}
end

function ChronoService:GetAimSample(player: Player?): LagCompensation.AimSample?
	if not player then return nil end

	return self.Samples[player]
end

--- Player characters are auto-registered by Chrono; NPCs are registered here.
function ChronoService:GetEntity(model: Model): Chrono.Entity?
	const registered = Chrono.Holder.GetEntityFromModel(model)
	if registered then return registered end

	return self.Entities[model]
end

--- Chrono entities are plain tables without a metatable: their methods live on
--- the Entity module, so they must be called as `Entity.GetAt(entity, time)`.
--- Keep that detail inside this service so callers deal with models only.
function ChronoService:GetCFrameAt(model: Model, time: number): CFrame?
	const entity = self:GetEntity(model)
	if not entity then return nil end

	return Chrono.Entity.GetAt(entity, time)
end

function ChronoService:IsHalfTicked(model: Model): boolean
	const entity = self:GetEntity(model)
	return if entity then entity.isHalfTicked == true else false
end

function ChronoService:RegisterNPC(model: Model, configName: string?): Chrono.Entity
	const existing = self:GetEntity(model)
	if existing then return existing end

	self:EnsureCleaner()
	const entity = Chrono.Entity.new(configName or "NPC", model)
	self.Entities[model] = entity
	self.Cleaner:Add(model.AncestryChanged:Connect(function(_, parent: Instance?)
		if parent ~= nil then return end
		self.Entities[model] = nil
		Chrono.Entity.Destroy(entity)
	end))

	return entity
end

return ChronoService
