const Players = game:GetService("Players")
const LocalPlayer = Players.LocalPlayer

const types = require(LocalPlayer.PlayerScripts.client.types)

const SampleModule = {} :: types.ClientPlayerModule

function SampleModule:onInit() end

function SampleModule:onStart() end

function SampleModule:onCharacter(character: Model) end

function SampleModule:onDestroy() end

return SampleModule
