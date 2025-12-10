local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Tool = script.Parent
local Player
local Character
local Humanoid
local LeftArm
local RightArm
local OriginalWalkSpeed
local Grip2
local Handle2
local Motor6DInstances = {}
local GripId = 0
local DefaultC0
local DefaultC1

local Setting = Tool:WaitForChild("Setting")
local Module = require(Setting)

local ChangeMagAndAmmo = script:WaitForChild("ChangeMagAndAmmo")

local AnimationFolder = Instance.new("Folder")
AnimationFolder.Name = "AnimationFolder"
AnimationFolder.Parent = Tool

local ValueFolder = Instance.new("Folder")
ValueFolder.Name = "ValueFolder"
ValueFolder.Parent = Tool

local Settings = {}
for i, v in pairs(Setting:GetChildren()) do
	if v.Name ~= "CanShootConditions" and v.Name ~= "ConditionableGunMods" and v.Name ~= "OnClientShootEvents" then
		table.insert(Settings, v)
	end
end
table.sort(Settings, function(a, b)
	return tonumber(a.Name) < tonumber(b.Name)
end)

if Module.UniversalAmmoEnabled then
	local AmmoValue = Instance.new("NumberValue")
	AmmoValue.Name = "Ammo"
	AmmoValue.Value = Module.Ammo
	AmmoValue.Parent = ValueFolder
end

if Module.DualWeldEnabled then
	Handle2 = Tool:WaitForChild("Handle2", 1)
	if Handle2 == nil and Module.DualWeldEnabled then error("\"Dual\" setting is enabled but \"Handle2\" is missing!") end
end

for i, v in ipairs(Settings) do
	local Module2 = require(v)
	
	local ValFolder = Instance.new("Folder")
	ValFolder.Name = i
	ValFolder.Parent = ValueFolder
	local MagValue = Instance.new("NumberValue")
	MagValue.Name = "Mag"
	MagValue.Value = Module2.AmmoPerMag
	MagValue.Parent = ValFolder
	local AmmoValue = Instance.new("NumberValue")
	AmmoValue.Name = "Ammo"
	AmmoValue.Value = (not Module.UniversalAmmoEnabled and Module2.LimitedAmmoEnabled) and Module2.Ammo or 0
	AmmoValue.Parent = ValFolder
	
	local AnimFolder = Instance.new("Folder")
	AnimFolder.Name = i
	AnimFolder.Parent = AnimationFolder
	if Module2.EquippedAnimationID ~= nil then
		local EquippedAnim = Instance.new("Animation")
		EquippedAnim.Name = "EquippedAnim"
		EquippedAnim.AnimationId = "rbxassetid://"..Module2.EquippedAnimationID
		EquippedAnim.Parent = AnimFolder
	end
	if Module2.EmptyEquippedAnimationID ~= nil then
		local EmptyEquippedAnim = Instance.new("Animation")
		EmptyEquippedAnim.Name = "EmptyEquippedAnim"
		EmptyEquippedAnim.AnimationId = "rbxassetid://"..Module2.EmptyEquippedAnimationID
		EmptyEquippedAnim.Parent = AnimFolder
	end
	if Module2.IdleAnimationID ~= nil then
		local IdleAnim = Instance.new("Animation")
		IdleAnim.Name = "IdleAnim"
		IdleAnim.AnimationId = "rbxassetid://"..Module2.IdleAnimationID
		IdleAnim.Parent = AnimFolder
	end
	if Module2.EmptyIdleAnimationID ~= nil then
		local EmptyIdleAnim = Instance.new("Animation")
		EmptyIdleAnim.Name = "EmptyIdleAnim"
		EmptyIdleAnim.AnimationId = "rbxassetid://"..Module2.EmptyIdleAnimationID
		EmptyIdleAnim.Parent = AnimFolder
	end
	if #Module2.FireAnimations > 0 then
		local FireAnimFolder = Instance.new("Folder")
		FireAnimFolder.Name = "FireAnimations"
		FireAnimFolder.Parent = AnimFolder
		for ii, vv in ipairs(Module2.FireAnimations) do
			if vv.FireAnimationID ~= nil then
				local FireAnim = Instance.new("Animation")
				FireAnim.Name = "FireAnim_"..ii
				FireAnim.AnimationId = "rbxassetid://"..vv.FireAnimationID
				FireAnim.Parent = FireAnimFolder
			end			
		end
	end
	if #Module2.LastFireAnimations > 0 then
		local LastFireAnimFolder = Instance.new("Folder")
		LastFireAnimFolder.Name = "LastFireAnimations"
		LastFireAnimFolder.Parent = AnimFolder
		for ii, vv in ipairs(Module2.LastFireAnimations) do
			if vv.LastFireAnimationID ~= nil then
				local LastFireAnim = Instance.new("Animation")
				LastFireAnim.Name = "LastFireAnim_"..ii
				LastFireAnim.AnimationId = "rbxassetid://"..vv.LastFireAnimationID
				LastFireAnim.Parent = LastFireAnimFolder
			end			
		end
	end
	if Module2.ReloadAnimationID ~= nil then
		local ReloadAnim = Instance.new("Animation")
		ReloadAnim.Name = "ReloadAnim"
		ReloadAnim.AnimationId = "rbxassetid://"..Module2.ReloadAnimationID
		ReloadAnim.Parent = AnimFolder
	end
	if Module2.ShotgunClipinAnimationID ~= nil then
		local ShotgunClipinAnim = Instance.new("Animation")
		ShotgunClipinAnim.Name = "ShotgunClipinAnim"
		ShotgunClipinAnim.AnimationId = "rbxassetid://"..Module2.ShotgunClipinAnimationID
		ShotgunClipinAnim.Parent = AnimFolder
	end
	if #Module2.ShotgunPumpinAnimations > 0 then
		local ShotgunPumpinAnimFolder = Instance.new("Folder")
		ShotgunPumpinAnimFolder.Name = "ShotgunPumpinAnimations"
		ShotgunPumpinAnimFolder.Parent = AnimFolder
		for ii, vv in ipairs(Module2.ShotgunPumpinAnimations) do
			if vv.ShotgunPumpinAnimationID ~= nil then
				local ShotgunPumpinAnim = Instance.new("Animation")
				ShotgunPumpinAnim.Name = "ShotgunPumpinAnim_"..ii
				ShotgunPumpinAnim.AnimationId = "rbxassetid://"..vv.ShotgunPumpinAnimationID
				ShotgunPumpinAnim.Parent = ShotgunPumpinAnimFolder
			end		
		end
	end
	if Module2.HoldDownAnimationID ~= nil then
		local HoldDownAnim = Instance.new("Animation")
		HoldDownAnim.Name = "HoldDownAnim"
		HoldDownAnim.AnimationId = "rbxassetid://"..Module2.HoldDownAnimationID
		HoldDownAnim.Parent = AnimFolder
	end
	if Module2.AimIdleAnimationID ~= nil then
		local AimIdleAnim = Instance.new("Animation")
		AimIdleAnim.Name = "AimIdleAnim"
		AimIdleAnim.AnimationId = "rbxassetid://"..Module2.AimIdleAnimationID
		AimIdleAnim.Parent = AnimFolder
	end
	if Module2.EmptyAimIdleAnimationID ~= nil then
		local EmptyAimIdleAnim = Instance.new("Animation")
		EmptyAimIdleAnim.Name = "EmptyAimIdleAnim"
		EmptyAimIdleAnim.AnimationId = "rbxassetid://"..Module2.EmptyAimIdleAnimationID
		EmptyAimIdleAnim.Parent = AnimFolder
	end
	if #Module2.AimFireAnimations > 0 then
		local AimFireAnimFolder = Instance.new("Folder")
		AimFireAnimFolder.Name = "AimFireAnimations"
		AimFireAnimFolder.Parent = AnimFolder
		for ii, vv in ipairs(Module2.AimFireAnimations) do
			if vv.AimFireAnimationID ~= nil then
				local AimFireAnim = Instance.new("Animation")
				AimFireAnim.Name = "AimFireAnim_"..ii
				AimFireAnim.AnimationId = "rbxassetid://"..vv.AimFireAnimationID
				AimFireAnim.Parent = AimFireAnimFolder
			end		
		end
	end
	if #Module2.AimLastFireAnimations > 0 then
		local AimLastFireAnimFolder = Instance.new("Folder")
		AimLastFireAnimFolder.Name = "AimLastFireAnimations"
		AimLastFireAnimFolder.Parent = AnimFolder
		for ii, vv in ipairs(Module2.AimLastFireAnimations) do
			if vv.AimLastFireAnimationID ~= nil then
				local AimLastFireAnim = Instance.new("Animation")
				AimLastFireAnim.Name = "AimLastFireAnim_"..ii
				AimLastFireAnim.AnimationId = "rbxassetid://"..vv.AimLastFireAnimationID
				AimLastFireAnim.Parent = AimLastFireAnimFolder
			end		
		end
	end
	if Module2.AimChargingAnimationID ~= nil then
		local AimChargingAnim = Instance.new("Animation")
		AimChargingAnim.Name = "AimChargingAnim"
		AimChargingAnim.AnimationId = "rbxassetid://"..Module2.AimChargingAnimationID
		AimChargingAnim.Parent = AnimFolder
	end
	if Module2.TacticalReloadAnimationEnabled and Module2.TacticalReloadAnimationID ~= nil then
		local TacticalReloadAnim = Instance.new("Animation")
		TacticalReloadAnim.Name = "TacticalReloadAnim"
		TacticalReloadAnim.AnimationId = "rbxassetid://"..Module2.TacticalReloadAnimationID
		TacticalReloadAnim.Parent = AnimFolder
	end
	if Module2.InspectAnimationEnabled and Module2.InspectAnimationID ~= nil then
		local InspectAnim = Instance.new("Animation")
		InspectAnim.Name = "InspectAnim"
		InspectAnim.AnimationId = "rbxassetid://"..Module2.InspectAnimationID
		InspectAnim.Parent = AnimFolder
	end
	if Module2.InspectAnimationEnabled and Module2.EmptyInspectAnimationID ~= nil then
		local EmptyInspectAnim = Instance.new("Animation")
		EmptyInspectAnim.Name = "EmptyInspectAnim"
		EmptyInspectAnim.AnimationId = "rbxassetid://"..Module2.EmptyInspectAnimationID
		EmptyInspectAnim.Parent = AnimFolder
	end
	if Module2.ShotgunReload and Module2.PreShotgunReload and Module2.PreShotgunReloadAnimationID ~= nil then
		local PreShotgunReloadAnim = Instance.new("Animation")
		PreShotgunReloadAnim.Name = "PreShotgunReloadAnim"
		PreShotgunReloadAnim.AnimationId = "rbxassetid://"..Module2.PreShotgunReloadAnimationID
		PreShotgunReloadAnim.Parent = AnimFolder
	end
	if Module2.MinigunRevUpAnimationID ~= nil then
		local MinigunRevUpAnim = Instance.new("Animation")
		MinigunRevUpAnim.Name = "MinigunRevUpAnim"
		MinigunRevUpAnim.AnimationId = "rbxassetid://"..Module2.MinigunRevUpAnimationID
		MinigunRevUpAnim.Parent = AnimFolder
	end
	if Module2.MinigunRevDownAnimationID ~= nil then
		local MinigunRevDownAnim = Instance.new("Animation")
		MinigunRevDownAnim.Name = "MinigunRevDownAnim"
		MinigunRevDownAnim.AnimationId = "rbxassetid://"..Module2.MinigunRevDownAnimationID
		MinigunRevDownAnim.Parent = AnimFolder
	end
	if Module2.ChargingAnimationEnabled and Module2.ChargingAnimationID ~= nil then
		local ChargingAnim = Instance.new("Animation")
		ChargingAnim.Name = "ChargingAnim"
		ChargingAnim.AnimationId = "rbxassetid://"..Module2.ChargingAnimationID
		ChargingAnim.Parent = AnimFolder
	end
	if Module2.SelectiveFireEnabled and Module2.SwitchAnimationID ~= nil then
		local SwitchAnim = Instance.new("Animation")
		SwitchAnim.Name = "SwitchAnim"
		SwitchAnim.AnimationId = "rbxassetid://"..Module2.SwitchAnimationID
		SwitchAnim.Parent = AnimFolder
	end
	if Module2.BatteryEnabled and Module2.OverheatAnimationID ~= nil then
		local OverheatAnim = Instance.new("Animation")
		OverheatAnim.Name = "OverheatAnim"
		OverheatAnim.AnimationId = "rbxassetid://"..Module2.OverheatAnimationID
		OverheatAnim.Parent = AnimFolder
	end
	if Module2.MeleeAttackEnabled and Module2.MeleeAttackAnimationID ~= nil then
		local MeleeAttackAnim = Instance.new("Animation")
		MeleeAttackAnim.Name = "MeleeAttackAnim"
		MeleeAttackAnim.AnimationId = "rbxassetid://"..Module2.MeleeAttackAnimationID
		MeleeAttackAnim.Parent = AnimFolder
	end
	if Module.AltFire and Module2.AltAnimationID ~= nil then
		local AltAnim = Instance.new("Animation")
		AltAnim.Name = "AltAnim"
		AltAnim.AnimationId = "rbxassetid://"..Module2.AltAnimationID
		AltAnim.Parent = AnimFolder
	end
	if Module2.LaserBeamStartupAnimationID ~= nil then
		local LaserBeamStartupAnim = Instance.new("Animation")
		LaserBeamStartupAnim.Name = "LaserBeamStartupAnim"
		LaserBeamStartupAnim.AnimationId = "rbxassetid://"..Module2.LaserBeamStartupAnimationID
		LaserBeamStartupAnim.Parent = AnimFolder
	end
	if Module2.LaserBeamLoopAnimationID ~= nil then
		local LaserBeamLoopAnim = Instance.new("Animation")
		LaserBeamLoopAnim.Name = "LaserBeamLoopAnim"
		LaserBeamLoopAnim.AnimationId = "rbxassetid://"..Module2.LaserBeamLoopAnimationID
		LaserBeamLoopAnim.Parent = AnimFolder
	end
	if Module2.LaserBeamStopAnimationID ~= nil then
		local LaserBeamStopAnim = Instance.new("Animation")
		LaserBeamStopAnim.Name = "LaserBeamStopAnim"
		LaserBeamStopAnim.AnimationId = "rbxassetid://"..Module2.LaserBeamStopAnimationID
		LaserBeamStopAnim.Parent = AnimFolder
	end
end

local function GetInstanceFromAncestor(Table)
	if Table[1] == "Tool" then
		return Tool:FindFirstChild(Table[2], true)
	end
	if Table[1] ~= "Character" then
		return
	end
	return Character:FindFirstChild(Table[2], true)
end

function SetCustomGrip(Enabled)
	if Enabled then
		GripId += 1
		local LastGripId = GripId
		for i, v in pairs(Module.CustomGrips) do
			if LastGripId ~= GripId then
				break
			end
			local Part0 = GetInstanceFromAncestor(v.CustomGripPart0)
			local Part1 = GetInstanceFromAncestor(v.CustomGripPart1)
			if not Part0 or not Part1 then
				continue
			end
			local Motor6DInstance = Instance.new("Motor6D")
			Motor6DInstance.Name = v.CustomGripName
			Motor6DInstance.Part0 = Part0
			Motor6DInstance.Part1 = Part1
			Motor6DInstance:SetAttribute("ServerInitialized", "")
			if Part1.Name == "Handle" and Part1.Parent == Tool then
				if not DefaultC0 or not DefaultC1 then
					repeat task.wait() if LastGripId ~= GripId then break end until RightArm:FindFirstChild("RightGrip")
					if LastGripId == GripId then
						local RightGrip = RightArm:FindFirstChild("RightGrip")
						if RightGrip then
							DefaultC0 = RightGrip.C0
							DefaultC1 = RightGrip.C1
							RightGrip.Enabled = false
							RightGrip:Destroy()
						end
					end
				end
				if DefaultC0 and DefaultC1 then
					if v.AlignC0AndC1FromDefaultGrip then
						Motor6DInstance.C0 = DefaultC0
						Motor6DInstance.C1 = DefaultC1
					end
					if v.CustomGripCFrame then
						Motor6DInstance.C0 *= v.CustomGripC0
						Motor6DInstance.C1 *= v.CustomGripC1
					end
					Motor6DInstance.Parent = Part0
					table.insert(Motor6DInstances, Motor6DInstance)
				end
			else
				if v.AlignC0AndC1FromDefaultGrip and DefaultC0 and DefaultC1 then
					Motor6DInstance.C0 = DefaultC0
					Motor6DInstance.C1 = DefaultC1
				end
				if v.CustomGripCFrame then
					Motor6DInstance.C0 *= v.CustomGripC0
					Motor6DInstance.C1 *= v.CustomGripC1
				end
				Motor6DInstance.Parent = Part0
				table.insert(Motor6DInstances, Motor6DInstance)
			end
		end
	else
		GripId += 1
		for _, v in pairs(Motor6DInstances) do
			if v then
				v:Destroy()
			end
		end
		table.clear(Motor6DInstances)
		DefaultC0 = nil
		DefaultC1 = nil
	end
end

function OnUnequipping(Remove)
	if Module.WalkSpeedModifierEnabled then
		Humanoid.WalkSpeed = OriginalWalkSpeed
	end
	if Module.CustomGripEnabled and not Tool.RequiresHandle then
		task.spawn(function()
			SetCustomGrip(false)
		end)
	end
	if Module.DualWeldEnabled and not Module.CustomGripEnabled and Tool.RequiresHandle then
		Handle2.CanCollide = true
		if Grip2 then
			Grip2:Destroy()
		end
	end
end

ChangeMagAndAmmo.OnServerEvent:Connect(function(Player, Id, Mag, Ammo)
	ValueFolder[Id].Mag.Value = Mag
	if Module.UniversalAmmoEnabled then
		ValueFolder.Ammo.Value = Ammo
	else
		ValueFolder[Id].Ammo.Value = Ammo
	end
end)

Tool.Equipped:Connect(function()
	Player = Players:GetPlayerFromCharacter(Tool.Parent)
	Character = Tool.Parent
	Humanoid = Character:FindFirstChildOfClass("Humanoid")
	LeftArm = Character:FindFirstChild("Left Arm") or Character:FindFirstChild("LeftHand")
	RightArm = Character:FindFirstChild("Right Arm") or Character:FindFirstChild("RightHand")
	OriginalWalkSpeed = Humanoid.WalkSpeed
	if Module.WalkSpeedModifierEnabled then
		Humanoid.WalkSpeed = Module.WalkSpeed
	end
	if Module.CustomGripEnabled and not Tool.RequiresHandle then
		task.spawn(function()
			SetCustomGrip(true)
		end)
	end
	if Module.DualWeldEnabled and not Module.CustomGripEnabled and Tool.RequiresHandle then
		Handle2.CanCollide = false
		if RightArm then
			local Grip = RightArm:WaitForChild("RightGrip", 0.01)
			if Grip then
				Grip2 = Grip:Clone()
				Grip2.Name = "LeftGrip"
				Grip2.Part0 = LeftArm
				Grip2.Part1 = Handle2
				--Grip2.C1 = Grip2.C1:inverse()
				Grip2:SetAttribute("ServerInitialized", "")
				Grip2.Parent = LeftArm
			end
		end
	end
end)

Tool.Unequipped:Connect(function()
	OnUnequipping()
end)

Tool.AncestryChanged:Connect(function()
	if not Tool:IsDescendantOf(game) then
		OnUnequipping(true)
	end
end)