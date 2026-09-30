return function(_, players)
	for _, player in pairs(players) do
		if player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid") :: Humanoid
			humanoid:TakeDamage(humanoid.MaxHealth)
		end
	end

	return ("Killed %d players."):format(#players)
end
