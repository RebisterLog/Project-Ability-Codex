const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

const SpecModule = {
	Name = "SpecModule",
} :: types.PlayerModule

const function EquipSpec(self: typeof(SpecModule), slot: types.SpecSlot, specId: string): boolean
	const proxy = self.playerProxy
	const ownedSpec = proxy().Specs[specId]

	if not ownedSpec then return false end

	const specService = Crane:GetService("SpecService")
	if specService:GetSpecType(ownedSpec.Name) ~= slot then return false end

	const character = self.player.instance.Character
	const characterComponent: types.Character? = character
		and Crane:GetComponent("Character", character) :: types.Character?

	if not characterComponent then
		-- No character yet: the id is saved here, the equip happens on respawn.
		proxy:Patch({
			{ Name = "ChangeValue", Path = { slot }, Args = { specId } },
		})
		return true
	end

	const spec = characterComponent:SetSpec(ownedSpec.Name, "None", {}, specId)
	if not spec then return false end

	self:ReplicateSkills(slot, spec)

	proxy:Patch({
		{ Name = "ChangeValue", Path = { slot }, Args = { specId } },
	})

	return true
end

function SpecModule:onStart()
	if self.playerProxy().Spec == "None" then
		const starterSpec: types.SpecSaveData = {
			Id = Crane.Utils.GenerateUUID(),
			Name = "Standless",
			ReceivedTime = os.date(),
			FirstOwnerId = self.player.instance.UserId,
		}

		self:AddSpec(starterSpec)
		self:SetSpec(starterSpec.Id)
	end
end

function SpecModule.AddSpec(self: typeof(SpecModule), data: types.SpecSaveData)
	self.playerProxy:Patch({
		{ Name = "SetDictionary", Path = { "Specs" }, Args = { data.Id, data } },
	})
end

function SpecModule.SetSpec(self: typeof(SpecModule), specId: string): boolean
	return EquipSpec(self, "Spec", specId)
end

function SpecModule.SetSubSpec(self: typeof(SpecModule), specId: string): boolean
	return EquipSpec(self, "SubSpec", specId)
end

--- Mirrors the skill set of a live spec into `playerProxy.Skills[slot]`.
function SpecModule.ReplicateSkills(
	self: typeof(SpecModule),
	slot: types.SpecSlot,
	spec: types.Spec
)
	const function mirror()
		self.playerProxy:Patch({
			{ Name = "SetDictionary", Path = { "Skills" }, Args = { slot, spec.Proxy().Skills } },
		})
	end

	spec.Cleaner:Add(spec.Proxy:Subscribe("AnyChange", { "Skills" }, mirror))

	mirror()
end

--- Empties a slot on both the player data and the live character.
function SpecModule.ClearSlot(self: typeof(SpecModule), slot: types.SpecSlot): boolean
	const character = self.player.instance.Character
	const characterComponent = character and Crane:GetComponent("Character", character)

	if characterComponent then
		if slot == "SubSpec" then
			characterComponent:ClearSubSpec()
		else
			characterComponent:ClearSpec()
		end
	end

	self.playerProxy:Patch({
		{ Name = "SetDictionary", Path = { "Skills" }, Args = { slot, {} } },
		{ Name = "ChangeValue", Path = { slot }, Args = { "None" } },
	})

	return true
end

--- The id of the owned spec by its config name, if the player owns it.
function SpecModule.GetSpecIdByName(self: typeof(SpecModule), specName: string): string?
	for specId, ownedSpec in self.playerProxy().Specs do
		if ownedSpec.Name == specName then return specId end
	end

	return nil
end

function SpecModule.GetSpec(self: typeof(SpecModule)): string
	return self.playerProxy().Spec or "None"
end

function SpecModule.GetSubSpec(self: typeof(SpecModule)): string
	return self.playerProxy().SubSpec or "None"
end

return SpecModule
