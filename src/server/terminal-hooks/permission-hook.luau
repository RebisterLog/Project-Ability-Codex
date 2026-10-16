const GroupService = game:GetService("GroupService")

type Role = {
	Id: number,
	Name: string,
	Rank: number,
}

const GetRank = function(UserId: number): number
	--? The GetRankInGroup method is deprecated and unstable now.
	--? https://devforum.roblox.com/t/excessive-rate-limits-when-checking-gamepasses-group-ranks/3549665
	const groups = GroupService:GetGroupsAsync(UserId)

	for _, GroupInfo in groups do
		if not UserId then break end

		if GroupInfo.Id == 34865080 then return GroupInfo.Rank end
	end

	return 0
end

return function(registry)
	registry:RegisterHook("BeforeRun", function(context)
		const player = context.Executor :: Player

		if context.Group == "Admin" and GetRank(player.UserId) < 200 then
			return "You don't have permission to run this command"
		end
	end)
end
