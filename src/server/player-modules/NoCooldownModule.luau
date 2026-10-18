const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

-- No cooldown is an admin toggle, not a state the combat system owns: skills only
-- read the CooldownMultiplier parameter, and this module is what keeps that
-- parameter in sync with what the admin asked for.
--
-- The flag lives here rather than on the character because a character is a
-- fresh component on every respawn, and a toggle given in a console is expected
-- to still be on after the player respawns.
local NoCooldownModule = {
	Name = "NoCooldownModule",
} :: types.PlayerModule

-- CharacterAdder hands us each character it builds rather than listening to
-- CharacterAdded itself: the order of two connections on the same event is not
-- guaranteed, and neither module should have to poll the other for the component.
function NoCooldownModule.OnCharacter(self: typeof(NoCooldownModule), character: types.Character)
	self.Character = character
	self.Parameter = nil

	if not self.Enabled then return end

	self.Parameter = character:AddParameter("CooldownMultiplier", 0)
end

function NoCooldownModule.IsEnabled(self: typeof(NoCooldownModule)): boolean
	return self.Enabled == true
end

function NoCooldownModule.Set(self: typeof(NoCooldownModule), enabled: boolean): boolean
	self.Enabled = enabled

	if enabled then
		-- The character can be nil, or mid-creation with no component yet. Either
		-- way the flag is recorded and OnCharacter applies it once there is
		-- something to apply it to.
		const character = self.player.instance.Character
		const component = character and Crane:GetComponent("Character", character)

		if component then self:OnCharacter(component) end

		-- Cooldowns already in flight were written before the multiplier was zeroed.
		-- Rewriting them is what makes the toggle take effect on the skills the
		-- player is using right now rather than only on the next cast. Nothing
		-- needs this on a respawn: a new character starts every skill at 0.
		if component and component.Spec then
			for _, skill in component.Spec.Skills do
				skill:SetCooldown(0)
			end
		end
	else
		if self.Parameter then self.Parameter:Destroy() end

		self.Parameter = nil
	end

	return self.Enabled
end

-- onInit, not onStart: the Player component runs every module's onInit before
-- any module's onStart, so the flag is already false by the time anything can
-- ask for it, whichever order the modules were discovered in.
function NoCooldownModule.onInit(self: typeof(NoCooldownModule))
	self.Enabled = false
	self.Character = nil
	self.Parameter = nil
end

return NoCooldownModule
