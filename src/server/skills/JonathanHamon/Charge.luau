const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Enums = require(ServerScriptService.server.Enums)
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Promise = require(ReplicatedStorage.shared.packages.Promise)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Hamon Charge",
	Cooldown = 2,
	BaseSpec = "JonathanHamon",

	-- A spec change or respawn destroys the skill without a key release, so the
	-- fill has to be closed here: otherwise the character would stay "filling"
	-- forever, blocking the hold/decay model.
	onDestroy = function(self)
		const CombatService = Crane:GetService("CombatService")

		CombatService:StopHamonFill(self.Character)
		-- Route through the class so it owns `Holding` and the signal: firing
		-- `Deactivated` by hand would desync both.
		self:Deactivate()
	end,
}

--- Hold-to-cast: the fill starts on press and stops on release. The actual
--- resource lives on the character (CombatService owns the math), so this skill
--- only opens and closes the tap.
function Skill.Activate(self)
	const character = self.Character
	const VFXService = Crane:GetService("VFXService")
	const CombatService = Crane:GetService("CombatService")

	const Collector = Crane.Buttler.new()

	Collector:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Walk))
	Collector:Add(character:AddParameter("MaxJumpPower", 0))

	CombatService:StartHamonFill(character)

	Collector:Add(function()
		CombatService:StopHamonFill(character)
	end)

	const animation = self:TryGetAsset("Animations/Charge")
	if animation then
		VFXService:StartEffect(Players:GetPlayers(), "Animation", {
			Character = character.instance,
			Animation = animation,
			Looped = true,
		})

		Collector:Add(function()
			VFXService:StopEffect(Players:GetPlayers(), "Animation", {
				Character = character.instance,
				Animation = animation.Animation,
			})
		end)
	end

	-- Block-style hold: `Activate` yields until the bind is released or the
	-- character goes away, so the skill stays active for the whole hold.
	Promise.new(function(resolve)
		Collector:Add(self.Deactivated:Once(resolve))

		Collector:Add(character.instance.AncestryChanged:Connect(function()
			if not character.instance.Parent then resolve() end
		end))
	end)
		:finallyCall(Collector.Destroy, Collector)
		:catch(warn)
		:await()
end

function Skill.Interrupt(self)
	const CombatService = Crane:GetService("CombatService")
	CombatService:StopHamonFill(self.Character)
	self:Deactivate()
end

return Skill
