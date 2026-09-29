local ServerScriptService = game:GetService("ServerScriptService")
local types = require(ServerScriptService.server.types)

local Skill: types.SkillData = {
	DisplayName = "Run",
}

function Skill:onInit()
	
end

function Skill.Activate(self)
	local Character = self.Character

	if self.Cleaner:Has("SpeedUp") then
		self.Cleaner:Remove("SpeedUp")
	else
		self.Cleaner:Set("SpeedUp", self.Character:AddParameter("MinWalkSpeed", 25))
	end
end

function Skill:onDestroy()
	self.Cleaner:Remove("SpeedUp")
end

return Skill