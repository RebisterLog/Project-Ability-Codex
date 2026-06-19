local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local types = require(ServerScriptService.server.types)

local Spec = {
	Name = "SpecModule",
} :: types.PlayerModule

--TEST
function Spec:onStart()

end

function Spec.SetSpec(self: typeof(Spec), spec: string)
	--кстати тут лучше прописать проверку, есть ли у пользователя вообще такой спек
	--TODO: if not table.find(currentData.Specs, spec) then return end

	self.playerProxy:Patch({
		{Name = "ChangeValue", Path = {"Spec"}, Args = {spec}}
	})
	
	local character = self.player.instance.Character
	local characterComponent = character and Crane:GetComponent("Character", character)
	
	if characterComponent then
		--TODO: choose skin by choosed spec
		--TODO: add binds from player data
		local spec = characterComponent:SetSpec(spec, "None", {}) :: types.Spec
		
		if not spec then
			Crane.Utils.Log(script.Name, `Couldn't set spec {spec.Id} for {characterComponent.instance}`, "error")
			return
		end

		spec.Proxy:Subscribe("AnyChange", {"Skills"}, function()
			self.playerProxy:Patch({
				{Name = "ChangeValue", Path = {"Skills"}, Args = {spec.Proxy().Skills}}
			})
		end)
		
		self.playerProxy:Patch({
			{Name = "ChangeValue", Path = {"Skills"}, Args = {spec.Proxy().Skills}}
		})
	end
end

function Spec:GetSpec()
	return self.playerProxy().Spec
end

return Spec
