--[[ Zoom Punch
	Punch that zooms in, hits your targets and pulls them back
]]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)

const HAMON_COST = 15

const Skill = {
	DisplayName = "Zoom Punch",
	Cooldown = 8,
	BaseSpec = "JonathanHamon",
	SkillCharacters = { "Hit", "Blockable", "ComboStarter", "ComboExtender" },

	AttackInfo = {
		Hitbox = {
			MinSize = Vector3.new(8, 8, 15),
			MaxSize = Vector3.new(8, 8, 35),
		},

		Damage = 15,

		Block = {
			PerfectBlockable = false,
		},

		Stun = {
			Priority = Enums.Stun.Heavy,
			Duration = 1.5,
		},
	},

	PullInfo = {
		Damage = 5;

		Block = {
			Blockable = true,
			PerfectBlockable = true,
		},

		Stun = {
			Priority = Enums.Stun.Heavy,
			Duration = 1.5;
		};
	},
}

function Skill.onInit(self)
	const character = self.Character
	const VFXService = Crane:GetService("VFXService")
	const CombatService = Crane:GetService("CombatService")

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{0, function(seq)
				seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Walk))
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
			end};

			{28, function(seq)
				local Ref = seq.Cleaner:Add("_Ref", Instance.new("Folder"))
				Ref.Name = "_Ref"
				Ref.Parent = character
				
				VFXService:StartEffect(Players:GetPlayers(), "Jonathan_ZoomPunch", {
					Character = character.instance,
					Reference = Ref,
					Length = seq.HitboxSize.Z
				})
			end};

			{30, function(seq)
				seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 0))
				seq.Cleaner:Add(character:AddParameter("NoRotate", true))
			end};

			{30, function(seq)
				const AttackInfo = self.Data.AttackInfo

				const Targets = CombatService:Hitbox({
					Skill = seq,
					Caster = character,
					Info = seq.HitboxInfo
				})

				for _, Target in Targets do
					CombatService:Attack({
						Attacker = character,
						Victim = Target,
						Info = AttackInfo,
					})
				end
			end};

			-- Pull out

			{63, function(seq)
				self.VFXService:StartEffect(Players:GetPlayers(), "Highlight", {
					Character = character.instance,
					FillColor = Color3.fromRGB(255, 255, 255),
					OutlineColor = Color3.fromRGB(255, 255, 255),
					OutlineTransparency = 0,
					FillTransparency = 0,
					Lifetime = 0.75,
					Tween = true,
				})
			end};

			{63, function(seq)
				seq.Cleaner:Remove("_Ref")
			end};

			{65, function(seq)
				local Origin = (character.RootPart.CFrame * CFrame.new(0,0,-5)).Position

				const Targets = CombatService:Hitbox({
					Skill = seq,
					Caster = character,
					Info = seq.HitboxInfo
				})

				for _, Target in Targets do
					CombatService:Attack({
						Attacker = character,
						Victim = Target,
						Info = Skill.PullInfo,
					}):andThen(function(AttackData)
						if not AttackData.State.Success then return end
						if not AttackData.State.Continue then return end
						if AttackData.State.Blocked then return end
						if AttackData.State.PerfectBlocked then return end

						-- not sure..
						-- VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						-- 	Character = character.instance,
						-- 	Animation = self:GetAsset("Animations/ZoomPunch_TargetPull"),
						-- 	Speed = seq.Speed,
						-- })

						local TargetRootPart = AttackData.Target.RootPart

						local BP = Instance.new("BodyPosition")
						BP.D = 1500
						BP.P = 50_000
						BP.Position = Origin
						BP.Parent = TargetRootPart

						task.delay(.3, BP.Destroy, BP)
					end)
				end
			end};

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
	if not self.Sequence then return end

	const AttackInfo = self.Data.AttackInfo
	const HitboxInfo = AttackInfo.Hitbox

	-- Max lives on the replicated charge state, so scaling follows
	-- the configured Hamon maximum instead of a hardcoded value.
	const state = self.Character:GetParameter("HamonCharge")
	const max = if state then state.Max else 0
	const Charge = CombatService:GetCharge(self.Character, "HamonCharge")
	const Alpha = if max > 0 then math.clamp(Charge / max, 0, 1) else 0

	local HitboxSize = HitboxInfo.MinSize:Lerp(HitboxInfo.MaxSize, Alpha)
	self.Sequence.HitboxInfo = {
		Size = HitboxSize,
		Offset = CFrame.new(0,0,HitboxSize.Size.Z / 2),
	}

	self.Sequence:Play()
	self.Sequence:Await()
end

function Skill.Interrupt(self)
	if self.Sequence then self.Sequence:Stop() end
end

return Skill
