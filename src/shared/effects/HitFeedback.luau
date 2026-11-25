const Debris = game:GetService("Debris")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ForgeVFX = require(ReplicatedStorage.shared.packages.ForgeVFX)

const Crane = require(ReplicatedStorage.shared.packages.Crane)
local VFXService = nil
task.spawn(function()
	while not Crane.IsStarted do
		task.wait(.1)
	end
	VFXService = Crane:GetService("VFXService")
end)

const LIFETIME = 3

type LookAt = "Attacker" | "Victim"
type BodyPart =
	"Head"
| "Torso"
| "Left Arm"
| "Right Arm"
| "Left Leg"
| "Right Leg"

type HitFeedbackData = {
	Victim: Model,
	Attacker: Model,
	Particle: BasePart | string,
	Sound: Sound?,
	LookAt: LookAt,
	BodyPart: BodyPart?,
}

return {
	onStart = function(_self, data: HitFeedbackData)

		const victim = data.Victim
		if not (victim and victim:IsDescendantOf(workspace)) then return end
		
		const attacker = data.Attacker
		if not (attacker and attacker:IsDescendantOf(workspace)) then return end
		
		const PartName = data.BodyPart or "Torso"

		local VictimPart = victim:FindFirstChild(PartName)
		local AttackerPart = attacker:FindFirstChild(PartName)
		
		if not (VictimPart and AttackerPart) then
			return
		end
		
		local VictimCF = VictimPart.CFrame
		local AttackerCF = AttackerPart.CFrame
		local CF = VictimCF
		
		if data.LookAt == "Attacker" then
			CF = CFrame.new(VictimCF.Position, AttackerCF.Position)
		elseif data.LookAt == "Victim" then
			CF = CFrame.new(AttackerCF.Position, VictimCF.Position)
		end
		
		if data.Particle then
			VFXService:StartEffect("EmitParticle", {
				Origin = CF,
				Offset = CFrame.identity,
				Particle = data.Particle,
			})	
		end

		if data.Sound then
			VFXService:StartEffect("Sound", {
				Origin = CF,
				Sound = data.Sound,
			})
		end			

		--const torso = character:FindFirstChild("Torso")
		--if not torso then return end
		
		

		--if data.Effects then
		--	for _, child in data.Effects:GetChildren() do
		--		const clone = child:Clone()
		--		clone.Parent = torso
		--		ForgeVFX.emit(clone)
		--		Debris:AddItem(clone, LIFETIME)
		--	end
		--end

		--if data.Sound then
		--	const sound = data.Sound:Clone()
		--	sound.Parent = torso
		--	-- The one-shot trick: play on removal, then remove.
		--	sound.PlayOnRemove = true
		--	sound:Destroy()
		--end
	end,
}
