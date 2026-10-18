--!native
--!optimize 2

--[=[ KnifeStab

   One stab with a knife. The hit ignores block and leaves a single victim
   bleeding: damage over time plus a walk speed cap, both for three seconds.
   The wound can be removed early, in which case nothing of the effect is
   left behind.

   Only the closest target is stabbed - one swing should never start a whole
   crowd bleeding.


   ASSETS:

   Animations
      KnifeStab : Animation for the stab

   Sounds
      KnifeStab : Knife swing on cast
      KnifeStabHit : Knife impact on the victim

   Models
      Knife : (Model) Knife mounted on the character for the animation
      KnifeStabHit : (BasePart) Impact effect emitted at the victim
]=]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
local Enums = require(ServerScriptService.server.Enums)
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Knife Stab",
	Cooldown = 15,

	SkillCharacters = {
		"Hit",
		"IgnoreBlock",
		"Debuff",
	},

	AttackInfo = {
		Hitbox = {
			Size = Vector3.new(6, 6, 6),
			Offset = CFrame.new(0, 0, -3),
			-- The debuff lands on one victim only, so the hitbox has to hand the
			-- candidates over in distance order.
			SortByDistance = true,
			Debug = true,
		},

		Damage = 10,

		Block = {
			BlockIgnore = true,
			PerfectBlockable = false,
		},

		Bleed = {
			Damage = 1,
			Duration = 3,
			Interval = 0.5,
			Slow = 8,
		},

		Stun = {
			Duration = 0.5,
			Priority = Enums.Stun.Medium,
		},
	},
}

function Skill:onInit()
	const character = self.Character :: types.Character
	const RootPart = character.RootPart

	const VFXService = Crane:GetService("VFXService")
	const CombatService = Crane:GetService("CombatService")

	const Anims = self.Spec.Data.Assets.Animations
	const Sounds = self.Spec.Data.Assets.Sounds
	const Models = self.Spec.Data.Assets.Models
	const AttackInfo = self.Data.AttackInfo

	self.AlreadyHit = {}

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 3))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					table.clear(self.AlreadyHit)

					-- The knife is out for exactly one swing: the cleaner takes
					-- it down on interrupt as well as on the last frame.
					const Knife = CombatService:Equip(character, Models.Knife)
					seq.Cleaner:Add(Knife)

					VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
						Animation = Anims.KnifeStab,
						Speed = seq.Speed,
					})
					VFXService:StartEffect(
						Players:GetPlayers(),
						"Sound",
						RootPart,
						Sounds.KnifeStab
					)
				end,
			},

			{
				20,
				function(seq)
					const Targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = AttackInfo.Hitbox,
					}) :: { types.Character }

					-- One cast, one victim: the hitbox keeps being checked for the
					-- whole window, but once the knife has landed somewhere there
					-- is nothing left to look for.
					if #self.AlreadyHit > 0 then return end

					const Target = Targets[1]
					if not Target then return end

					-- The victim is taken before the attack resolves, so the one
					-- target rule does not depend on when the promise answers.
					table.insert(self.AlreadyHit, Target)

					CombatService:Attack({
						Attacker = character,
						Victim = Target,
						Info = AttackInfo,
					}):andThen(function(Data: types.AttackData)
						if not Data.State.Success then return end

						VFXService:StartEffect(
							Players:GetPlayers(),
							"Sound",
							Data.Victim.RootPart,
							Sounds.KnifeStabHit
						)
						VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
							Particle = Models.KnifeStabHit,
							Origin = Data.Victim.RootPart,
						})
					end)
				end,
				25,
			},

			{ 30 },
		},
	}))
end

function Skill:Activate()
	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
end

function Skill:Interrupt()
	const VFXService = Crane:GetService("VFXService")

	const Anims = self.Spec.Data.Assets.Animations

	if self.Sequence then self.Sequence:Stop() end

	VFXService:StopEffect(Players:GetPlayers(), "Animation", self.Character.instance, {
		Animation = Anims.KnifeStab.Animation,
	})
end

return Skill
