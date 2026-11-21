local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Enums = require(ServerScriptService.server.Enums)
local types = require(ServerScriptService.server.types)

local Skill = {
	DisplayName = "Zoom Punch",
	Cooldown = 8,
	BaseSpec = "JonathanHamon",
	SkillCharacters = { "Hit", "Blockable" },

	AttackInfo = {
		Hitbox = {
			MinSize = Vector3.new(8, 8, 15),
			MaxSize = Vector3.new(8, 8, 35),
			Offset = CFrame.new(0, 0, -15),
		},

		Damage = 15,

		Block = {
			PerfectBlockable = false,
		},

		Stun = {
			Priority = Enums.Stun.Medium,
			Duration = 2,
		},
	},
}

function Skill.onInit(Skill)
	local character = Skill.Character
	local VFXService = Crane:GetService("VFXService")
	local CombatService = Crane:GetService("CombatService")

	Skill.Sequence = Skill.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{ 0, function(seq)
				seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Slowed))
				seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

				local anim = Skill:GetAsset("Animations/ZoomPunch")

				VFXService:StartEffect(Players:GetPlayers(), "Animation", {
					Character = character.instance,
					Animation = anim,
					Speed = seq.Speed,
				})

				seq.Cleaner:Add(function()
					VFXService:StopEffect(Players:GetPlayers(), "Animation", {
						Character = character.instance,
						Animation = anim.Animation,
					})
				end)
			end },

			{ 30, function(seq)
				local AttackInfo = Skill.Data.AttackInfo
				local HitboxInfo = AttackInfo.Hitbox

				local Charge = CombatService:GetCharge(character, "Hamon")
                -- idk how do i get max hamon charge, so imma hardcode
                local MaxCharge = 100
				local Alpha = math.clamp(Charge / MaxCharge, 0, 1)

				local HitboxSize = HitboxInfo.MinSize:Lerp(
					HitboxInfo.MaxSize,
					Alpha
				)

				local Targets = CombatService:Hitbox({
					Skill = seq,
					Caster = character,
					Info = {
						Size = HitboxSize,
						Offset = HitboxInfo.Offset,
					},
				})

				for _, Target in Targets do
					CombatService:Attack({
						Attacker = character,
						Victim = Target,
						Info = AttackInfo,
					})
				end
			end },

			{ 30, function(seq)
				-- CameraShake / FOV
			end },

			{ 130, function(seq)
				-- End
			end },
		},
	}))
end

function Skill.Activate(self)
	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
end

function Skill.Interrupt(self)
	if self.Sequence then
		self.Sequence:Stop()
	end
end

return Skill
