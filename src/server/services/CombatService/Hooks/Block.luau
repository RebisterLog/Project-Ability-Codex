const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const types = require(ServerScriptService.server.types)
const BlockResolver = require(ReplicatedStorage.shared.combat.Block)

return {
	Name = "Block",
	Type = "Precast",
	Priority = 85,
	Function = function(Data: types.AttackData)
		const State = Data.State

		-- Все состояния сбрасываются явно: `BlockIgnored` раньше не сбрасывался
		-- вообще и мог «залипнуть» на повторном ударе.
		State.Blocked = false
		State.PerfectBlocked = false
		State.BlockBroken = false
		State.BlockCanceled = false
		State.BlockIgnored = false

		const Result = BlockResolver.Resolve(Data.Info.Block, {
			Blocking = State.Blocking,
			PerfectBlocking = State.PerfectBlocking,
		})

		State.Blocked = Result.Blocked
		State.PerfectBlocked = Result.PerfectBlocked
		State.BlockBroken = Result.BlockBroken
		State.BlockCanceled = Result.BlockCanceled
		State.BlockIgnored = Result.BlockIgnored

		-- Только обрыв: `Armor` мог уже выставить Continue = false, не стираем его.
		if Result.PerfectBlocked then State.Continue = false end

		if Result.Absorbed then
			Data.Info.Damage = nil
			Data.Info.Ragdoll = nil
			Data.Info.Restand = nil
			Data.Info.Stun = nil
			Data.Info.Bleed = nil
			Data.Info.Sever = nil
			Data.Info.HitEffects = nil
			Data.Info.HitAnimations = nil

			Data.Info.Knockback = nil
			Data.Info.Angular = nil
		end

		return true
	end,
}
