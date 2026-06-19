local Skill = {
	DisplayName = "Run",
}

function Skill.Activate(self)
	local Character = self.Character
	
	if self.WalkSpeedModifier then
		self.WalkSpeedModifier:Destroy()
		self.WalkSpeedModifier = nil
	else
		self.WalkSpeedModifier = self.Character:AddParameter("MinWalkSpeed", 25)
	end
end

return Skill