--[=[ DASH

   Fast horizontal escape/dodge. The authoritative cast grants a short
   Dodge-level i-frame window and plays the VFX for everyone; movement is
   handled by the shared DashMovement tuning:

     * players run the movers client-side (client owns its own physics),
     * NPCs get the identical movers here on the server.

   `Activate` deliberately does not await the sequence, so the global
   single-skill lock (Spec.ActivateSkill / Character.CheckActiveSkills) is
   released on the same tick and other skills are not queued behind the dash.

   ASSETS:

   Animations
      DashForward / DashBack / DashLeft / DashRight : dash direction animation

   Sounds
      Dash : optional dash whoosh

   Models
      DashEffect : dust burst effect part, emitted once at the cast position
]=]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const DashMovement = require(ReplicatedStorage.shared.DashMovement)

const Config = DashMovement.Config

local Skill = {
	DisplayName = "Dash",
	Cooldown = Config.Cooldown,
	SkillCharacters = {
		"Escape",
		"Defense",
		"ComboStarter",
	},
	DashProperties = {
		Speed = Config.Speed,
	},
}

function Skill:onInit()
	const character = self.Character
	const RootPart = character.RootPart
	const Humanoid = character.Humanoid :: Humanoid

	const VFXService = Crane:GetService("VFXService")
	const CombatService = Crane:GetService("CombatService")

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					-- 8 frames of dodge-level invulnerability. All parameters live
					-- in the sequence cleaner, so Stop() always removes them.
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 0))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))
					seq.Cleaner:Add(character:AddParameter("IFrames", Enums.IFrames.Dodge))

					local Normal = RootPart.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
					if Normal == Vector3.zero then Normal = Vector3.new(0, 0, -1) end

					const direction = DashMovement.GetDashDirection(Normal)
					const moveDirection =
						DashMovement.GetDirection(Humanoid.MoveDirection, RootPart.CFrame)
					self.LastDashMoveDirection = moveDirection

					const isPlayer = Players:GetPlayerFromCharacter(character.instance) ~= nil
					if not isPlayer then
						-- Players play their own Dash animation client-side; no
						-- StopEffect either way, the clip is not looped.
						const dashAnim = self:GetAsset("Animations/Dash" .. direction)
						VFXService:StartEffect(Players:GetPlayers(), "Animation", {
							Character = character.instance,
							Animation = dashAnim,
							SpecId = self.Spec.Data.Id,
						})
					end

					const dashSound = self:TryGetAsset("Sounds/Dash")
					if dashSound then
						VFXService:StartEffect(Players:GetPlayers(), "Sound", {
							Origin = RootPart,
							Sound = dashSound,
						})
					end

					-- Dust burst stays in the world at the cast position: a CFrame
					-- origin makes EmitParticle anchor the clone instead of welding
					-- it to the character. CFrame.identity is required to trigger
					-- PivotTo and adds no actual offset.
					VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
						Particle = self:GetAsset("Models/DashEffect"),
						Origin = RootPart.CFrame,
						Offset = CFrame.identity,
					})

					-- Players predict locally; NPCs have no client, so the server
					-- owns their movers. Registering the handle with "Destroy" in
					-- the sequence cleaner covers interrupt and respawn too.
					if not isPlayer then
						seq.Cleaner:Set(
							"DashMover",
							DashMovement.Apply(RootPart, moveDirection, Humanoid),
							"Destroy"
						)
					end
				end,
			},

			{
				Config.MoveFrames,
				function(seq)
					-- NPC dash ends cleanly at MoveFrames; no tween tail pushing
					-- into walls after the character has already stopped.
					seq.Cleaner:Remove("DashMover")
					seq.MoveDirection = nil
				end,
			},

			{ Config.IFrameFrames }, -- end frame: Cleaner:Clean() drops IFrames
		},
	}))

	-- Activate() returns immediately, so `Skill.Active` is already false by the
	-- time a stun/ragdoll arrives and the base class' Interrupt guard would
	-- skip us. Stop the sequence directly to guarantee mover/parameter cleanup.
	self.Cleaner:Add(CombatService.Interrupted:Connect(function(Target)
		if Target == character and self.Sequence then self.Sequence:Stop() end
	end))
end

function Skill:Activate()
	const Sequence = self.Sequence
	if Sequence then Sequence:Play() end
end

function Skill:Interrupt()
	const Sequence = self.Sequence
	if Sequence then Sequence:Stop() end
end

return Skill
