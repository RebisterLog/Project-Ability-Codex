const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

-- God mode is an admin toggle, not a state the combat system owns: the damage
-- hooks only read the GodMode parameter, and this module is what keeps that
-- parameter in sync with what the admin asked for.
--
-- The flag lives here rather than on the character because a character is a
-- fresh component on every respawn, and a toggle given in a console is expected
-- to still be on after the player respawns.
local GodModeModule = {
	Name = "GodModeModule",
} :: types.PlayerModule

-- CharacterAdder hands us each character it builds rather than listening to
-- CharacterAdded itself: the order of two connections on the same event is not
-- guaranteed, and neither module should have to poll the other for the component.
function GodModeModule.OnCharacter(self: typeof(GodModeModule), character: types.Character)
	self.Character = character
	self.Parameter = nil

	if not self.Enabled then return end

	self.Parameter = character:AddParameter("GodMode", true)
end

function GodModeModule.IsEnabled(self: typeof(GodModeModule)): boolean
	return self.Enabled == true
end

function GodModeModule.Set(self: typeof(GodModeModule), enabled: boolean): boolean
	self.Enabled = enabled

	if enabled then
		-- The character can be nil, or mid-creation with no component yet. Either
		-- way the flag is recorded and OnCharacter applies it once there is
		-- something to apply it to.
		const character = self.player.instance.Character
		const component = character and Crane:GetComponent("Character", character)

		if component then self:OnCharacter(component) end
	else
		if self.Parameter then self.Parameter:Destroy() end

		self.Parameter = nil
	end

	return self.Enabled
end

-- onInit, not onStart: the Player component runs every module's onInit before
-- any module's onStart, so the flag is already false by the time anything can
-- ask for it, whichever order the modules were discovered in.
function GodModeModule.onInit(self: typeof(GodModeModule))
	self.Enabled = false
	self.Character = nil
	self.Parameter = nil
end

return GodModeModule
