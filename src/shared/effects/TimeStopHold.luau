const Players = game:GetService("Players")
const RunService = game:GetService("RunService")

--[=[ Time Stop / Hold.

   The "the world stopped for everyone, you just cannot tell who the user
   is" hold, shown only to players caught in a Time Stop who do not carry
   the `TimeStopVision` flag in their equipped spec or subspec.

   On their screen the caster — and the caster's stand — freeze in the pose
   they were struck in: the root's CFrame is written every frame before the
   render, which is the only way to beat the replication of another player's
   assembly. The anchor is kept on the root purely as a local stabiliser and
   restored exactly as found.

   The clip hold itself travels through the Animation VFX ("PauseAll" /
   "ResumeAll"), targeted at the same audience — this module only owns the pin.
]=]

type HoldEntry = {
	model: Model,
	root: BasePart,
	frozenCFrame: CFrame,
	wasAnchored: boolean,
}

type ActiveHold = {
	entries: { HoldEntry },
	connection: RBXScriptConnection,
	expireThread: thread?,
}

type HoldData = {
	Caster: Model?,
	Stand: Model?,
	Duration: number?,
}

const Active: { [Model]: ActiveHold } = {}

const function entriesReady(models: { Model }): { HoldEntry }
	const entries: { HoldEntry } = {}

	for _, model in models do
		const root = model:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then continue end

		table.insert(entries, {
			model = model,
			root = root,
			frozenCFrame = root.CFrame,
			wasAnchored = root.Anchored,
		})

		root.Anchored = true
	end

	return entries
end

const function release(hold: ActiveHold)
	if hold.connection.Connected then hold.connection:Disconnect() end
	if hold.expireThread then pcall(task.cancel, hold.expireThread) end

	for _, entry in hold.entries do
		const root = entry.root
		if root.Parent then root.Anchored = entry.wasAnchored end
	end

	table.clear(hold.entries)
end

const function unpin(caster: Model?, _stand: Model?)
	const hold = caster and Active[caster]
	if hold == nil then return end
	Active[caster] = nil
	release(hold)
end

const function prune(hold: ActiveHold): boolean
	local kept = #hold.entries

	for index = #hold.entries, 1, -1 do
		if hold.entries[index].root.Parent then continue end

		table.remove(hold.entries, index)
		kept -= 1
	end

	return kept > 0
end

const function pin(caster: Model?, data: HoldData)
	if caster == nil then return end
	const stand = data.Stand

	-- Defensive: the caster must never see themselves stopped.
	if caster == Players.LocalPlayer.Character then return end

	unpin(caster, stand)

	const models: { Model } = { caster }
	if stand ~= nil then table.insert(models, stand) end

	const entries = entriesReady(models)
	if #entries == 0 then return end

	const hold: ActiveHold = {
		entries = entries,
		connection = nil :: any,
		expireThread = nil,
	}

	hold.connection = RunService.PreSimulation:Connect(function()
		for _, entry in entries do
			const root = entry.root
			if root.Parent then root.CFrame = entry.frozenCFrame end
		end

		if not prune(hold) then unpin(caster, stand) end
	end)

	const duration = data.Duration or 4
	hold.expireThread = task.delay(duration, function()
		unpin(caster, stand)
	end)

	Active[caster] = hold
end

return {
	onStart = function(self, data: HoldData)
		if typeof(data) ~= "table" then return end
		pin(data.Caster, data)
	end,

	onStop = function(self, data: HoldData)
		unpin(data.Caster, data and data.Stand)
	end,
}