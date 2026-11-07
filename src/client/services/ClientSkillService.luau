--!native
--!optimize 2

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Crane = require(ReplicatedStorage.shared.packages.Crane)

const LocalPlayer = Players.LocalPlayer
const SkillsFolder = script.Parent.Parent.skills

--[=[ ClientSkillService

   A local-only skill layer that runs alongside the authoritative server
   skills. BindService still forwards every press/release to the server; this
   service adds immediate client-side prediction (movement, camera, UI) so the
   game feels responsive before replication lands.

   Improvements over the legacy tool-coupled system:
   * Skills are auto-discovered from `client/skills` — no manual registry.
   * Every activation owns a fresh Buttler cleaner, so a skill's state and
     connections can never leak across activations or respawns.
   * A single-activation guard plus an optional `Toggle` mode cover both
     hold-to-cast and press-to-flip skills with one contract.
   * `CanActivate` gates prediction on the replicated CharacterState, and the
     context hands the skill a `Deactivate` callback so it can resync itself
     when the server disagrees (interrupt, restraint, respawn).

   Contract (each module returns):
     Id: string                      -- matches the server skill id / bind
     Toggle: boolean?                -- press flips state; release is ignored
     CanActivate: (self, ctx) -> boolean?
     Activate: (self, ctx) -> ()     -- ctx.Cleaner owns this activation
     Stop: (self, ctx) -> ()?
]=]

export type ClientSkillContext = {
	Cleaner: typeof(Crane.Buttler.new()),
	Character: Model,
	Humanoid: Humanoid,
	CharacterState: any,
	Deactivate: () -> (),
}

export type ClientSkill = {
	Id: string,
	Toggle: boolean?,
	CanActivate: ((self: ClientSkill, ctx: ClientSkillContext) -> boolean)?,
	Activate: (self: ClientSkill, ctx: ClientSkillContext) -> (),
	Stop: ((self: ClientSkill, ctx: ClientSkillContext) -> ())?,
}

type SkillEntry = {
	Module: ClientSkill,
	Active: boolean,
	Cleaner: typeof(Crane.Buttler.new())?,
}

const ClientSkillService = Crane:CreateService({
	Name = "ClientSkillService",
	LoadOrder = 1,
})

function ClientSkillService.onStart(self: typeof(ClientSkillService))
	self.Skills = {} :: { [string]: SkillEntry }
	self.Cleaner = Crane.Buttler.new()

	for _, module in SkillsFolder:GetDescendants() do
		if not module:IsA("ModuleScript") then continue end

		const skill = require(module) :: ClientSkill
		const id = skill.Id or module.Name
		self.Skills[id] = { Module = skill, Active = false, Cleaner = nil }
	end

	self.Cleaner:Add(LocalPlayer.CharacterAdded:Connect(function()
		self:ResetAll()
	end))
end

-- Build the per-activation context. Returns nil when there is no living
-- character to act on, which is what keeps prediction off dead/absent rigs.
function ClientSkillService.MakeContext(
	self: typeof(ClientSkillService),
	skillId: string,
	cleaner: typeof(Crane.Buttler.new())
): ClientSkillContext?
	const character = LocalPlayer.Character
	if not character then return nil end

	const humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end

	const source = Crane:GetService("PlayerService").Proxy()
	const characterState = source and source.CharacterState

	return {
		Cleaner = cleaner,
		Character = character,
		Humanoid = humanoid,
		CharacterState = characterState,
		Deactivate = function()
			self:Deactivate(skillId)
		end,
	}
end

function ClientSkillService.Activate(self: typeof(ClientSkillService), skillId: string): boolean
	const entry = self.Skills[skillId]
	if not entry then return false end

	const module = entry.Module

	-- Press-to-flip: a second press while active turns the skill back off.
	if module.Toggle and entry.Active then
		self:Deactivate(skillId)
		return true
	end

	-- Hold-to-cast: ignore repeats while already active.
	if entry.Active then return true end

	const cleaner = Crane.Buttler.new()
	const ctx = self:MakeContext(skillId, cleaner)
	if not ctx then
		cleaner:Destroy()
		return false
	end

	if module.CanActivate and not module.CanActivate(module, ctx) then
		cleaner:Destroy()
		return false
	end

	entry.Active = true
	entry.Cleaner = cleaner
	module.Activate(module, ctx)
	return true
end

function ClientSkillService.Stop(self: typeof(ClientSkillService), skillId: string): boolean
	const entry = self.Skills[skillId]
	if not entry then return false end

	-- A toggle skill ignores key release; only the next press flips it.
	if entry.Module.Toggle then return true end

	self:Deactivate(skillId)
	return true
end

function ClientSkillService.Deactivate(self: typeof(ClientSkillService), skillId: string)
	const entry = self.Skills[skillId]
	if not entry or not entry.Active then return end

	-- Clear the flag first so a resync callback fired during cleanup cannot
	-- re-enter this path.
	entry.Active = false

	const cleaner = entry.Cleaner
	const ctx = cleaner and self:MakeContext(skillId, cleaner)
	if entry.Module.Stop and ctx then entry.Module.Stop(entry.Module, ctx) end

	entry.Cleaner = nil
	if cleaner then cleaner:Destroy() end
end

function ClientSkillService.ResetAll(self: typeof(ClientSkillService))
	for skillId in self.Skills do
		self:Deactivate(skillId)
	end
end

function ClientSkillService.IsActive(self: typeof(ClientSkillService), skillId: string): boolean
	const entry = self.Skills[skillId]
	return entry ~= nil and entry.Active
end

function ClientSkillService.Destroy(self: typeof(ClientSkillService))
	self:ResetAll()
	self.Cleaner:Destroy()
end

return ClientSkillService
