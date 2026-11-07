--!native
--!optimize 2

const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const MovementRules = require(ReplicatedStorage.shared.MovementRules)
const ClientSkillService = require(script.Parent.Parent.services.ClientSkillService)

type Context = ClientSkillService.ClientSkillContext

--[=[ Run (client prediction)

   Press-to-flip sprint. The server owns the real `MinWalkSpeed` parameter;
   this skill only predicts it locally so the speed change is felt on the same
   frame as the press, then resyncs itself the moment the authoritative value
   disagrees (server toggled it off, an interrupt landed, the character died).

   No tool state is involved: the gate reads the replicated CharacterState
   directly through MovementRules.CanRun.
]=]

const Run: ClientSkillService.ClientSkill = {
	Id = "Run",
	Toggle = true,
}

function Run.CanActivate(self: ClientSkillService.ClientSkill, ctx: Context): boolean
	const characterState = ctx.CharacterState
	if not characterState or not characterState.Parameters then return false end

	const parameters = characterState.Parameters
	const humanoidState = ctx.Humanoid:GetState()

	return MovementRules.CanRun({
		Alive = ctx.Character.Parent ~= nil and humanoidState ~= Enum.HumanoidStateType.Dead,
		Stunned = parameters.Stun.ExpiresAt > workspace:GetServerTimeNow(),
		Ragdolled = parameters.Ragdoll,
		Restrained = parameters.Restrain,
		Blocking = characterState.Blocking,
		Physics = humanoidState == Enum.HumanoidStateType.Physics,
	})
end

function Run.Activate(self: ClientSkillService.ClientSkill, ctx: Context)
	const movement = Crane:GetService("MovementService")
	movement:SetLocalMinWalkSpeed("Run", MovementRules.RunSpeed)
	ctx.Cleaner:Add(function()
		movement:SetLocalMinWalkSpeed("Run", nil)
	end)

	-- Resync: when the server's authoritative minimum drops below the sprint
	-- speed, the prediction is stale — hand it back without waiting for a press.
	const playerService = Crane:GetService("PlayerService")
	ctx.Cleaner:Add(
		playerService.Proxy:Subscribe(
			"AnyChange",
			{ "CharacterState", "Parameters", "MinWalkSpeed" },
			function()
				const state = playerService.Proxy().CharacterState
				const min = state and state.Parameters and state.Parameters.MinWalkSpeed or 0
				if min < MovementRules.RunSpeed then ctx.Deactivate() end
			end
		)
	)
end

return Run
