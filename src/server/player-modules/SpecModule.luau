const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const types = require(ServerScriptService.server.types)

const Spec = {
	Name = "SpecModule",
} :: types.PlayerModule

--TEST
function Spec:onStart()
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

function Spec.AddSpec(self: typeof(Spec), data: types.SpecSaveData)
	self.playerProxy:Patch({
		{ Name = "SetDictionary", Path = { "Specs" }, Args = { data.Id, data } },
	})
end

function Spec.GetSpecIdByName(self: typeof(Spec), name: string): string
	for i, spec in self.playerProxy().Specs do
		if spec.Name == name then return spec.Id end
	end
end

function Spec.SetSpec(self: typeof(Spec), specId: string)
	if not self.playerProxy().Specs[specId] then return end
	--if self.playerProxy().Spec == specId then return end

	self.playerProxy:Patch({
		{ Name = "ChangeValue", Path = { "Spec" }, Args = { specId } },
	})

	const character = self.player.instance.Character
	const characterComponent = character and Crane:GetComponent("Character", character)

	if characterComponent then
		--TODO: choose skin by choosed spec
		--TODO: add binds from player data
		const specName = self.playerProxy().Specs[specId].Name

		const spec = characterComponent:SetSpec(specName, "None", {}) :: types.Spec

		if not spec then
			Crane.Utils.Log(
				script.Name,
				`Couldn't set spec {spec.Id} for {characterComponent.instance}`,
				"error"
			)
			return
		end

		spec.Proxy:Subscribe("AnyChange", { "Skills" }, function()
			self.playerProxy:Patch({
				{ Name = "ChangeValue", Path = { "Skills" }, Args = { spec.Proxy().Skills } },
			})
		end)

		self.playerProxy:Patch({
			{ Name = "ChangeValue", Path = { "Skills" }, Args = { spec.Proxy().Skills } },
		})
	end
end

function Spec:GetSpec()
	return self.playerProxy().Spec
end

return Spec
