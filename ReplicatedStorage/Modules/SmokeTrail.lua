local SmokeTrail = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local Utilities = require(Modules.Utilities)
local Thread = Utilities.Thread

local Emitting = false
local ForceStop = false

function SmokeTrail:EmitSmokeTrail(Trail, MaxEmitTime)
	if not Trail then
		return
	end
	local StartTime = os.clock()
	while Trail do
		local DeltaTime = os.clock() - StartTime
		Emitting = true
		if ForceStop or DeltaTime >= MaxEmitTime then
			ForceStop = false
			break
		end
		Trail.Enabled = true
		Thread:Wait()
	end
	Emitting = false
	if Trail then
		Trail.Enabled = false
	end
end

function SmokeTrail:StopEmission()
	if Emitting then
		ForceStop = true
	end
end

return SmokeTrail
