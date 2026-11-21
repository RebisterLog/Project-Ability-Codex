const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Zoom Punch",
	Cooldown = 8,
	BaseSpec = "JonathanHamon",
	SkillCharacters = { "Hit", "Blockable" },

	AttackInfo = {
		Hitbox = {
      -- Size depends on Hamon Charge
			MinSize = Vector3.new(8, 8, 15),
      MaxSize = Vector3.new(8, 8, 35)
			Offset = CFrame.new(0, 0, -15),
		},

		Damage = 15,

		Block = {
			PerfectBlockable = false,
		},

    -- Combo Extender / Starter, so 2 seconds should be enough to continue
		Stun = {
			Priority = Enums.Stun.Medium,
			Duration = 2,
		},
	},
}

function Skill.onInit(Skill)
	const character = Skill.Character
	const RootPart = character.RootPart
	const VFXService = Crane:GetService("VFXService")
	const CombatService = Crane:GetService("CombatService")

	Skill.Sequence = Skill.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
      -- i hate seq, sorry
      {0, function(self)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Slowed))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					const anim = Skill:GetAsset("Animations/ZoomPunch")
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
      end};

      {30, function(self)
          const AttackInfo = Skill.Data.AttackInfo

          const Targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = AttackInfo.Hitbox,
					})

					for _, Target in Targets do
						CombatService:Attack({
							Attacker = character,
							Victim = Target,
							Info = AttackInfo,
						})
					end
      end};

      {30, function(self)
          -- TODO: CameraShake or FOV Modification would be nice
      end};

			{130, function(self)
          -- end
      end},
		},
	}))
end

function Skill.Activate(self)
	const CombatService = Crane:GetService("CombatService")

	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
end

function Skill.Interrupt(self)
	if self.Sequence then self.Sequence:Stop() end
end

return Skill
