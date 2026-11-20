--!strict
--- Chrono configuration. Passed to `Chrono.Start`, which requires it *before*
--- locking the config, so all entity types must be registered here.
---
--- Replication deliberately stays NATIVE: Roblox keeps replicating Animator
--- tracks and the existing VFXService passes live model instances through
--- ByteNet. Switching to CUSTOM would require remapping every Animation/Pause
--- effect to a client-side model copy — unnecessary for lag compensation.

const Chrono = require(script.Parent.Parent.packages.Chrono)
const Config = Chrono.Config

Config.SetConfig("CHECK_NEW_VERSION", false)
Config.SetConfig("DEFAULT_MODEL_REPLICATION_MODE", "NATIVE")
Config.SetConfig("MAX_SNAPSHOT_COUNT", 40)

-- Player characters are client-owned, so the server always records their
-- snapshot history (STORE_SNAPSHOTS excludes client-owned entities).
Config.RegisterEntityType("PLAYER", {
	BUFFER = 0, -- dynamic interpolation buffer for players
	TICK_RATE = 1 / 30,
	STORE_SNAPSHOTS = true,
	MODEL_REPLICATION_MODE = "NATIVE",
	HALF_TICK_DISTANCE = math.huge,
	ASSEMBLY_ROOT_PART_CHECK = true,
})

-- Server-owned NPCs only keep history when explicitly requested; without it
-- Entity:GetAt silently returns the latest CFrame.
Config.RegisterEntityType("NPC", {
	BUFFER = 0.1,
	TICK_RATE = 1 / 30,
	STORE_SNAPSHOTS = true,
	MODEL_REPLICATION_MODE = "NATIVE",
	NORMAL_TICK_DISTANCE = 100,
	HALF_TICK_DISTANCE = 150,
	ASSEMBLY_ROOT_PART_CHECK = true,
})

-- ConfigService freezes every module in shared/configs, so this must be a
-- table even though Chrono.Start ignores the returned value.
return {}
