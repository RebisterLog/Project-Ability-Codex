const PhysicsService = game:GetService("PhysicsService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Configuration = ServerScriptService.server.Configuration

const CollisionService = Crane:CreateService({
	Name = "CollisionService",
})

const Groups = {
	"Player",
	"Ragdoll",
	"NPC",
	"NoCollision",
}

function CollisionService:onInit()
	for i, group in Groups do
		PhysicsService:RegisterCollisionGroup(group)
	end

	PhysicsService:CollisionGroupSetCollidable("Player", "Player", true)
	PhysicsService:CollisionGroupSetCollidable("Player", "Ragdoll", false)
	PhysicsService:CollisionGroupSetCollidable("Player", "NPC", false)

	PhysicsService:CollisionGroupSetCollidable("NoCollision", "Player", false)
	PhysicsService:CollisionGroupSetCollidable("NoCollision", "NPC", false)
	PhysicsService:CollisionGroupSetCollidable("NoCollision", "Ragdoll", false)
	PhysicsService:CollisionGroupSetCollidable("NoCollision", "NoCollision", false)

	PhysicsService:CollisionGroupSetCollidable("NPC", "NPC", false)

	PhysicsService:CollisionGroupSetCollidable("Ragdoll", "Ragdoll", false)
end

function CollisionService:SetCollisionGroup(group: string, instance: Instance)
	if group ~= "Default" and not table.find(Groups, group) then
		Crane.Utils.Log(script.Name, `Collision group {group} does not exist`, "error")
		return
	end

	if instance:IsA("BasePart") then instance.CollisionGroup = group end

	for i, part: BasePart in instance:QueryDescendants("BasePart") do
		part.CollisionGroup = group
	end
end

return CollisionService
