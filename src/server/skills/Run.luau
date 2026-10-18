const ServerScriptService = game:GetService("ServerScriptService")
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Run",
}

function Skill:onInit() end

function Skill.Activate(self)
	const Character = self.Character

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
