const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)

const HAMON_COST = 25

const Skill = {
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

function Skill.onInit(self)
	const character = self.Character
	const VFXService = Crane:GetService("VFXService")
	const CombatService = Crane:GetService("CombatService")

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Slowed))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					const anim = self:GetAsset("Animations/ZoomPunch")

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
				end,
			},

			{
				30,
				function(seq)
					const AttackInfo = self.Data.AttackInfo
					const HitboxInfo = AttackInfo.Hitbox

					-- Max lives on the replicated charge state, so scaling follows
					-- the configured Hamon maximum instead of a hardcoded value.
					const state = character:GetParameter("HamonCharge")
					const max = if state then state.Max else 0
					const Charge = CombatService:GetCharge(character, "HamonCharge")
					const Alpha = if max > 0 then math.clamp(Charge / max, 0, 1) else 0

					const HitboxSize = HitboxInfo.MinSize:Lerp(HitboxInfo.MaxSize, Alpha)

					const Targets = CombatService:Hitbox({
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
				end,
			},

			{
				30,
				function()
					-- CameraShake / FOV
				end,
			},

			{
				130,
				function()
					-- End
				end,
			},
		},
	}))
end

function Skill.Activate(self)
	const CombatService = Crane:GetService("CombatService")
	const paid, _ = CombatService:ConsumeCharge(self.Character, "HamonCharge", HAMON_COST)
	if not paid then return end

	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
end

function Skill.Interrupt(self)
	if self.Sequence then self.Sequence:Stop() end
end

return Skill
