local PhysicsService = game:GetService("PhysicsService")

function _G.CreateCollisionGroup(CollisionGroupName)
	local CreatedGroups = PhysicsService:GetRegisteredCollisionGroups()
	local ExistingCollisionGroups = {} do
		for _, CreatedGroup in pairs(CreatedGroups) do
			ExistingCollisionGroups[CreatedGroup.name] = true
		end
	end

	if not ExistingCollisionGroups[CollisionGroupName] then
		PhysicsService:RegisterCollisionGroup(CollisionGroupName)
	end
end

_G.CreateCollisionGroup("Debris")

PhysicsService:CollisionGroupSetCollidable("Debris", "Debris", false)
