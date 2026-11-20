--[=[ DASH

   Fast horizontal escape/dodge. The authoritative cast grants a short
   Dodge-level i-frame window and plays the VFX for everyone; movement is
   handled by the shared DashMovement tuning:

     * players run Apply() + Update() client-side (the client owns its own
       character physics),
     * NPCs run the very same Apply() + Update() loop here on the server,
       because they have no client to predict for them.

   An air dash holds the character at a constant height for the whole dash
   (no falling) and releases gravity on the last frame, producing the falling
   arc. Ground dashes keep their old slide feel.

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
const RunService = game:GetService("RunService")
const ServerScriptService = game:GetService("ServerScriptService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const DashMovement = require(ReplicatedStorage.shared.DashMovement)

const Config = DashMovement.Config

--- The mover and its driver outlive the short i-frame sequence, so they live
--- in the skill's own cleaner instead of the sequence cleaner.
local function stopDash(self)
	self.Cleaner:Remove("DashHeartbeat")
	self.Cleaner:Remove("DashMover")
end

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
					-- drives their mover with the same Update() loop the local
					-- player uses. The mover lives in the skill cleaner (not the
					-- sequence cleaner) so the longer air dash is not cut short
					-- by the 8-frame i-frame sequence.
					if not isPlayer then
						stopDash(self)
						const mover = DashMovement.Apply(RootPart, moveDirection, Humanoid)
						self.Cleaner:Set("DashMover", mover, "Destroy")
						self.Cleaner:Set(
							"DashHeartbeat",
							RunService.Heartbeat:Connect(function(deltaTime)
								-- A newer dash may have replaced this mover on the
								-- same frame; its stale callback must not tear down
								-- the new one.
								if mover.Destroyed then return end
								if not DashMovement.Update(mover, deltaTime) then stopDash(self) end
							end)
						)
					end
				end,
			},

			{ Config.IFrameFrames }, -- end frame: Cleaner:Clean() drops IFrames
		},
	}))

	-- Activate() returns immediately, so `Skill.Active` is already false by the
	-- time a stun/ragdoll arrives and the base class' Interrupt guard would
	-- skip us. Stop the sequence and the mover directly to guarantee cleanup.
	self.Cleaner:Add(CombatService.Interrupted:Connect(function(Target)
		if Target == character and self.Sequence then
			self.Sequence:Stop()
			stopDash(self)
		end
	end))
end

function Skill:Activate()
	const Sequence = self.Sequence
	if Sequence then Sequence:Play() end
end

function Skill:Interrupt()
	const Sequence = self.Sequence
	if Sequence then Sequence:Stop() end
	stopDash(self)
end

return Skill
