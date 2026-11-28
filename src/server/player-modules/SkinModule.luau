const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

const SkinModule = {
	Name = "SkinModule",
} :: types.PlayerModule

function SkinModule.onInit() end

function SkinModule.onStart(self: typeof(SkinModule))
	self.player.Janitor:Add(Crane:GetPacket("SetSkin").listen(function(request, player)
		if player ~= self.player.instance then return end
		self:EquipSkin(request.SpecName, request.SkinName or "None")
	end))

	self.player.Janitor:Add(Crane:GetPacket("DeleteItem").listen(function(request, player)
		if player ~= self.player.instance then return end
		if request.Kind == "Skin" then self:DeleteSkin(request.Id) end
	end))
end

--- Ownership is per spec name: `None` is the built-in default and needs no grant.
function SkinModule.HasSkin(self: typeof(SkinModule), specName: string, skinName: string): boolean
	if skinName == "None" then return true end

	for _, skin in self.playerProxy().Skins do
		if skin.Spec == specName and skin.Id == skinName then return true end
	end

	return false
end

function SkinModule.AddSkin(self: typeof(SkinModule), data: types.SkinSaveData)
	if self:HasSkin(data.Spec, data.Id) then return end

	self.playerProxy:Patch({
		{ Name = "SetDictionary", Path = { "Skins" }, Args = { Crane.Utils.GenerateUUID(), data } },
	})
end

function SkinModule.GetEquippedSkin(self: typeof(SkinModule), specId: string): string
	return self.playerProxy().EquippedSkins[specId] or "None"
end

function SkinModule.DeleteSkin(self: typeof(SkinModule), id: string)
	const skin = self.playerProxy().Skins[id]
	if not skin then return end

	const specModule = self.player.Modules["SpecModule"]
	const specId = specModule:GetSpecIdByName(skin.Spec)
	if specId and self:GetEquippedSkin(specId) == skin.Id then self:EquipSkin(skin.Spec, "None") end

	self.playerProxy:Patch({
		{ Name = "RemoveDictionary", Path = { "Skins" }, Args = { id } },
	})
end

--- Persists the choice and re-equips only when that spec is currently worn.
function SkinModule.EquipSkin(
	self: typeof(SkinModule),
	specName: string,
	skinName: string
): (boolean, string?)
	const skinConfigs = Crane:GetService("ConfigService"):Get("Skins")[specName]
	if not skinConfigs or not skinConfigs[skinName] then
		return false, `Skin "{skinName}" doesn't exist for "{specName}"`
	end

	const specModule = self.player.Modules["SpecModule"]
	const specId = specModule:GetSpecIdByName(specName)
	if not specId then return false, `Player doesn't own spec "{specName}"` end

	if not self:HasSkin(specName, skinName) then
		return false, `Player doesn't own skin "{skinName}" for "{specName}"`
	end

	self.playerProxy:Patch({
		{ Name = "SetDictionary", Path = { "EquippedSkins" }, Args = { specId, skinName } },
	})

	if specModule:GetSpec() == specId then
		if not specModule:SetSpec(specId) then
			return false, `Failed to re-equip "{specName}" with skin "{skinName}"`
		end
	elseif specModule:GetSubSpec() == specId then
		if not specModule:SetSubSpec(specId) then
			return false, `Failed to re-equip "{specName}" with skin "{skinName}"`
		end
	end

	return true, nil
end

return SkinModule
