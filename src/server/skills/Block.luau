local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)
local Promise = require(ReplicatedStorage.shared.packages.Promise)
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Enums = require(ServerScriptService.server.Enums)
local types = require(ServerScriptService.server.types)

local Block: types.SkillData = {
	DisplayName = "Block",
	Cooldown = 0.25,
	SkillCharacters = {
		"Defense",
	}
}

function Block:Activate()
	local character = self.Character
	local RootPart = character.RootPart
	local Humanoid = character.Humanoid
	local VFXService = Crane:GetService("VFXService")
	local CombatService = Crane:GetService("CombatService")
	
	local BlockState = character.Block
	
	BlockState.Blocking = true
	BlockState.PerfectBlockTime = os.clock()
	BlockState.PerfectBlockWindow = 0.25

	local Anims = self.Spec.Data.Assets.Animations
	local Anim = self.Spec.Data.Assets.Animations["Block"]
	
	local Collector = Crane.Janitor.new()
	
	Promise.new(function(resolve)
		Collector:Add(character:AddParameter("MaxWalkSpeed", 3))
		Collector:Add(character:AddParameter("MaxJumpPower", 0))
		
		Collector:Add(function()
			VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, {
				Animation = Anim.Animation,
			})
		end)
		VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
			Animation = Anim,
		})
		
		Collector:Add(CombatService.Attacked:Connect(function(Type, Data)
			if not (Type == "Precast" and Data.Victim == character) then
				return
			end
			if Data.State.BlockCanceled then
				return resolve()
			end
			if Data.State.PerfectBlocked then
				local stun = Data.Attacker:AddParameter("Stun", {
					Duration = 1.5,
					Priority = Enums.Stun.Heavy
				})
				task.delay(1.5, stun.Destroy, stun)
				CombatService.Interrupted:Fire(Data.Attacker)
				
				VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
					Particle = ReplicatedStorage.assets.Default.Block.VFX.PerfectBlock,
					Origin = RootPart,
					Offset = CFrame.new(0,0,-2),
				})
				VFXService:StartEffect(Players:GetPlayers(), "Highlight", character.instance, {
					FillColor = Color3.fromRGB(255, 162, 0),
					OutlineColor = Color3.fromRGB(255, 162, 0),
					FillTransparency = 0,
					OutlineTransparency = 0,
					Lifetime = 1,
					Tween = true,
				})	
				VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, {
					Sound = ReplicatedStorage.assets.Default.Block.Sounds.PerfectBlock,
					Volume = 1,
				})
			elseif Data.State.BlockBroken then
				local stun = Data.Victim:AddParameter("Stun", {
					Duration = 2,
					Priority = Enums.Stun.Heavy
				})
				task.delay(1.5, stun.Destroy, stun)
				resolve()
				
				VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
					Particle = ReplicatedStorage.assets.Default.Block.VFX.BlockBreak,
					Origin = RootPart,
					Offset = CFrame.new(0,0,-2)
				})	
				VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, {
					Sound = ReplicatedStorage.assets.Default.Block.Sounds.BlockBreak,
					Volume = 1,
				})
			elseif Data.State.Blocked then
				VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, {
					Sound = ReplicatedStorage.assets.Default.Block.Sounds.Hit,
					Volume = 1,
				})
			end
		end))
		
		Collector:Add(character.instance.AncestryChanged:Connect(function()
			if not character.instance.Parent then
				resolve()
			end
		end))
		
		Collector:Add(self.Deactivated:Once(resolve))
		
		
	end):finallyCall(Collector.Destroy, Collector):catch(warn):await()
	
	BlockState.Blocking = false
end

return Block