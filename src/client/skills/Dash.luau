--!native
--!optimize 2

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const DashMovement = require(ReplicatedStorage.shared.DashMovement)
const ClientSkillService = require(script.Parent.Parent.services.ClientSkillService)

type Context = ClientSkillService.ClientSkillContext

--[=[ Dash (client prediction)

   The server stays authoritative for cooldown and i-frames, but the local
   player owns its own character physics. Applying the mover here makes the
   dash feel instant; the server skill deliberately skips it for player-owned
   characters and still creates one for NPCs.

   Animation is also owned by this client through the shared "Dash" effect, so
   the server never starts or stops an animation for the local player.
]=]

-- ReleaseTime is now server time and is directly comparable on the client.
-- The local timer still drives prediction on the same frame as the press;
-- the server remains the final validator.
local LastActivateAt = -math.huge

local function canActivate(_self: ClientSkillService.ClientSkill, ctx: Context): boolean
	const state = ctx.CharacterState
	if not state or not state.Parameters then return false end

	const parameters = state.Parameters
	const now = workspace:GetServerTimeNow()

	if ctx.Humanoid.Health <= 0 then return false end
	if parameters.Stun and parameters.Stun.ExpiresAt > now then return false end
	if parameters.Ragdoll then return false end
	if parameters.Restand then return false end
	if parameters.Restrain then return false end
	if
		ctx.Humanoid.PlatformStand
		or ctx.Humanoid:GetState() == Enum.HumanoidStateType.PlatformStanding
	then
		return false
	end
	if now - LastActivateAt < DashMovement.Config.Cooldown then return false end

	return true
end

local function activate(_self: ClientSkillService.ClientSkill, ctx: Context)
	LastActivateAt = workspace:GetServerTimeNow()

	const rootPart = ctx.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		ctx.Deactivate()
		return
	end

	const playerService = Crane:GetService("PlayerService")
	const vfxService = Crane:GetService("VFXService")

	const moveDirection = DashMovement.GetDirection(ctx.Humanoid.MoveDirection, rootPart.CFrame)
	const mover = DashMovement.Apply(rootPart, moveDirection, ctx.Humanoid)
	ctx.Cleaner:Set("DashMover", mover, "Destroy")

	-- The shared Dash effect derives the animation direction from the vector
	-- itself. No server-side start/stop for the local player.
	-- Proxy().Spec / .SubSpec hold spec UUIDs, not config names. Skins are keyed
	-- by the name inside Specs[uuid], so resolve it first (and prefer the slot
	-- that actually owns Dash).
	const playerData = playerService.Proxy()
	const skills = playerData.Skills
	const dashSlot = if skills and skills.SubSpec and skills.SubSpec.Dash then "SubSpec" else "Spec"
	const specId = if dashSlot == "SubSpec" then playerData.SubSpec else playerData.Spec
	const specConfig = playerData.Specs and playerData.Specs[specId]
	const specName = specConfig and specConfig.Name
	if specName and specName ~= "None" then
		vfxService:StartEffect("Dash", {
			Character = ctx.Character,
			SpecData = { SpecId = specName, SkinId = "None" },
			-- The effect picks the animation from the object-space normal; a
			-- world vector would select the wrong Dash side.
			Normal = mover.LocalDirection,
		})
	end

	ctx.Cleaner:Add(RunService.Heartbeat:Connect(function(deltaTime)
		-- Finish only when the shared tick says the slide / air cap is done.
		-- A fixed timer would drop the mover before the cap is reached and the
		-- leftover inertia would still carry the player too far in the air.
		if not DashMovement.Update(mover, deltaTime) then ctx.Deactivate() end
	end))

	-- Resync: if the authoritative state says the character can no longer dash,
	-- drop the local prediction immediately instead of waiting for key release.
	ctx.Cleaner:Add(
		playerService.Proxy:Subscribe("AnyChange", { "CharacterState", "Parameters" }, function()
			const state = playerService.Proxy().CharacterState
			if not state or not state.Parameters then return end

			const parameters = state.Parameters
			if
				parameters.Ragdoll
				or parameters.Restand
				or parameters.Restrain
				or ctx.Humanoid.PlatformStand
				or ctx.Humanoid:GetState() == Enum.HumanoidStateType.PlatformStanding
				or ctx.Humanoid.Health <= 0
				or (parameters.Stun and parameters.Stun.ExpiresAt > workspace:GetServerTimeNow())
			then
				ctx.Deactivate()
			end
		end)
	)
end

local function stop(_self: ClientSkillService.ClientSkill, ctx: Context)
	ctx.Cleaner:Remove("DashMover")
end

const Dash: ClientSkillService.ClientSkill = {
	Id = "Dash",
	IgnoreRelease = true,
	CanActivate = canActivate,
	Activate = activate,
	Stop = stop,
}

return Dash
