local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Camera = Workspace.CurrentCamera

local Events = ReplicatedStorage:WaitForChild("Events")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Miscs = ReplicatedStorage:WaitForChild("Miscs")

local gunEvent = Events.gunEvent
local gunFunction = Events.gunFunction

local PlayAudio = Remotes.PlayAudio
local VisualizeBullet = Remotes.VisualizeBullet
local VisualizeHitEffect = Remotes.VisualizeHitEffect
local VisualizeBeam = Remotes.VisualizeBeam
local VisibleMuzzle = Remotes.VisibleMuzzle
local VisualizeCharge = Remotes.VisualizeCharge
local VisualizeOverheat = Remotes.VisualizeOverheat
local VisualizeGore = Remotes.VisualizeGore

local AudioHandler = require(Modules.AudioHandler)
local ProjectileHandler = require(Modules.ProjectileHandler)
local Utilities = require(Modules.Utilities)
local GetSetting = require(Modules.GetSetting)
local Thread = Utilities.Thread
local CreatePacket, DecodePacket = unpack(Utilities.DataPacket)

local Gibs = Miscs.Gibs
local GibsR15 = Miscs.GibsR15
local Skeleton = Miscs.Skeleton
local SkeletonR15 = Miscs.SkeletonR15
local GunVisualEffects = Miscs.GunVisualEffects

local RenderDistance = 400

local Container = {}
local LaserTrailContainer = {}
local LightningBoltContainer = {}
local ChargeEffectModules = {}
local OverheatEffectModules = {}
local Joints = {}

local DamagedHeadParts = {"damaged.head.1", "damaged.head.2", "damaged.head.3"}

local Gore = {
	["Head"] = {"damaged.head.bone.1", "damaged.head.bone.2"},
	["Right Arm"] = {"damaged.right.arm.1", "damaged.right.arm.2", "damaged.right.arm.flesh.1", "damaged.right.arm.flesh.2"},
	["Left Arm"] = {"damaged.left.arm.1", "damaged.left.arm.2", "damaged.left.arm.flesh.1", "damaged.left.arm.flesh.2"},
	["Right Leg"] = {"damaged.right.leg.1", "damaged.right.leg.2", "damaged.right.leg.flesh.1", "damaged.right.leg.flesh.2"},
	["Left Leg"] = {"damaged.left.leg.1", "damaged.left.leg.2", "damaged.left.leg.flesh.1", "damaged.left.leg.flesh.2"},
	["Torso"] = {"damaged.torso", "damaged.torso.flesh", "damaged.torso.bone"},
}

local GoreR15 = {
	["Head"] = {"damaged.head.bone.1", "damaged.head.bone.2"},
	["RightUpperArm"] = {"damaged.right.upper.arm", "damaged.right.upper.arm.bone"},
	["RightLowerArm"] = {"damaged.right.lower.arm", "damaged.right.lower.arm.flesh"},
	["RightHand"] = {"damaged.right.hand"},
	["LeftUpperArm"] = {"damaged.left.upper.arm", "damaged.left.upper.arm.bone"},
	["LeftLowerArm"] = {"damaged.left.lower.arm", "damaged.left.lower.arm.flesh"},
	["LeftHand"] = {"damaged.left.hand"},
	["RightUpperLeg"] = {"damaged.right.upper.leg", "damaged.right.upper.leg.flesh"},
	["RightLowerLeg"] = {"damaged.right.lower.leg", "damaged.right.lower.leg.flesh"},
	["RightFoot"] = {"damaged.right.foot"},
	["LeftUpperLeg"] = {"damaged.left.upper.leg", "damaged.left.upper.leg.flesh"},
	["LeftLowerLeg"] = {"damaged.left.lower.leg", "damaged.left.lower.leg.flesh"},
	["LeftFoot"] = {"damaged.left.foot"},
	["UpperTorso"] = {"damaged.upper.torso", "damaged.upper.torso.bone"},
	["LowerTorso"] = {"damaged.lower.torso", "damaged.lower.torso.flesh"},
}

local Bones = {
	["Head"] = {"head"},
	["Right Arm"] = {"right.arm"},
	["Left Arm"] = {"left.arm"},
	["Right Leg"] = {"right.leg"},
	["Left Leg"] = {"left.leg"},
	["Torso"] = {"torso"},
}

local BonesR15 = {
	["Head"] = {"head"},
	["RightUpperArm"] = {"right.upper.arm"},
	["RightLowerArm"] = {"right.lower.arm"},
	["RightHand"] = {"right.hand"},
	["LeftUpperArm"] = {"left.upper.arm"},
	["LeftLowerArm"] = {"left.lower.arm"},
	["LeftHand"] = {"left.hand"},
	["RightUpperLeg"] = {"right.upper.leg"},
	["RightLowerLeg"] = {"right.lower.leg"},
	["RightFoot"] = {"right.foot"},
	["LeftUpperLeg"] = {"left.upper.leg"},
	["LeftLowerLeg"] = {"left.lower.leg"},
	["LeftFoot"] = {"left.foot"},
	["UpperTorso"] = {"upper.torso"},
	["LowerTorso"] = {"lower.torso"},
}

local function GetChargeEffectModule(Effect)
	if not ChargeEffectModules[Effect] then
		if Modules.ChargeFolder:FindFirstChild(Effect) then
			ChargeEffectModules[Effect]	= require(Modules.ChargeFolder[Effect])
		end
	end

	if ChargeEffectModules[Effect] then
		return ChargeEffectModules[Effect]
	end

	return nil
end

local function GetOverheatEffectModule(Effect)
	if not OverheatEffectModules[Effect] then
		if Modules.OverheatFolder:FindFirstChild(Effect) then
			OverheatEffectModules[Effect]= require(Modules.OverheatFolder[Effect])
		end
	end

	if OverheatEffectModules[Effect] then
		return OverheatEffectModules[Effect]
	end

	return nil
end

local function FindExistingId(Dictionary)
	for _, v in pairs(Container) do
		if v.Main.Id == Dictionary.Id then
			return true
		end
	end
	return false
end

function RemoveExistingBeam(Id, Tool, ModuleName, BeamTable, LaserTrail, BoltSegments, CrosshairPointAttachment)
	VisualizeBeam:FireServer(false, {
		Id = Id,
		Tool = Tool,
		ModuleName = ModuleName,
	})
	if BeamTable then
		for i, v in pairs(BeamTable) do
			if v then
				v:Destroy()
			end
		end
		table.clear(BeamTable)
	end
	local Module = GetSetting(Tool, {ModuleName = ModuleName})
	if LaserTrail then
		Thread:Spawn(function()
			if Module.LaserTrailFadeTime > 0 then
				local DesiredSize = LaserTrail.Size * (Module.ScaleLaserTrail and Vector3.new(1, Module.LaserTrailScaleMultiplier, Module.LaserTrailScaleMultiplier) or Vector3.new(1, 1, 1))
				local Tween = TweenService:Create(LaserTrail, TweenInfo.new(Module.LaserTrailFadeTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Transparency = 1, Size = DesiredSize})
				Tween:Play()
				Tween.Completed:Wait()
				LaserTrail:Destroy()
			else
				LaserTrail:Destroy()
			end	
		end)
	end
	if BoltSegments then
		for i, v in pairs(BoltSegments) do
			local segment = v
			Thread:Delay(Module.BoltVisibleTime, function()
				if Module.BoltFadeTime > 0 then
					local DesiredSize = segment.Size * (Module.ScaleBolt and Vector3.new(1, Module.BoltScaleMultiplier, Module.BoltScaleMultiplier) or Vector3.new(1, 1, 1))
					local Tween = TweenService:Create(segment, TweenInfo.new(Module.BoltFadeTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Transparency = 1, Size = DesiredSize})
					Tween:Play()
					Tween.Completed:Wait()
					segment:Destroy()
				else
					segment:Destroy()							
				end
			end)			
		end
		table.clear(BoltSegments)
	end
	if CrosshairPointAttachment then
		CrosshairPointAttachment:Destroy()
	end
end

function PlayReplicatedAudio(Audio, LowAmmoAudio, Replicate)
	AudioHandler:PlayAudio(Audio, LowAmmoAudio, Replicate)
end

function SimulateReplicatedProjectile(Tool, Handle, Directions, FirePointObject, MuzzlePointObject, Misc, Replicate)
	ProjectileHandler:SimulateProjectile(Tool, Handle, Directions, FirePointObject, MuzzlePointObject, Misc, Replicate)
end

function VisualizeReplicatedHitEffect(Type, Hit, Position, Normal, Material, Misc, Replicate)
	ProjectileHandler:VisualizeHitEffect(Type, Hit, Position, Normal, Material, Misc, Replicate)
end

function VisualizeReplicatedBeam(Enabled, Dictionary)
	if Enabled then
		if not FindExistingId(Dictionary) then
			table.insert(Container, {Main = Dictionary})
		else
			local Main
			for _, v in pairs(Container) do
				if v.Main.Id == Dictionary.Id then
					Main = v.Main
					break
				end
			end
			local Module = GetSetting(Main.Tool, {ModuleName = Main.ModuleName})
			local LaserBeamEffect = GunVisualEffects:FindFirstChild(Module.LaserBeamEffect)
			if not Main.CrosshairPointAttachment then
				Main.CrosshairPointAttachment = Instance.new("Attachment")
				Main.CrosshairPointAttachment.Name = "CrosshairPointAttachment"
				if LaserBeamEffect then
					for i, v in pairs(LaserBeamEffect.HitEffect:GetChildren()) do
						if v.ClassName == "ParticleEmitter" then
							local particle = v:Clone()
							particle.Enabled = true
							particle.Parent = Main.CrosshairPointAttachment
						end
					end
				end
			end
			if not Main.LaserBeamContainer then
				Main.LaserBeamContainer = {}
				if LaserBeamEffect then
					for i, v in pairs(LaserBeamEffect.LaserBeams:GetChildren()) do
						if v.ClassName == "Beam" then
							local beam = v:Clone()
							table.insert(Main.LaserBeamContainer, beam)
						end
					end
				end
				for i, v in pairs(Main.LaserBeamContainer) do
					if v then
						v.Parent = Main.Handle
						v.Attachment0 = Main.FirePoint
						v.Attachment1 = Main.CrosshairPointAttachment
					end
				end
			end
			if Module.LaserTrailEnabled and not Main.LaserTrailData then
				Main.LaserTrailData = {}
				Main.LaserTrailData.Id = Main.Id
				Main.LaserTrailData.Setting = Module
				Main.LaserTrailData.FirePoint = Main.FirePoint
				Main.LaserTrailData.CrosshairPointAttachment = Main.CrosshairPointAttachment
				
				Main.LaserTrailData.LaserTrail = Miscs[Module.LaserTrailShape.."Segment"]:Clone()
				Main.LaserTrailData.LaserTrail.CastShadow = false
				Main.LaserTrailData.LaserTrail.CanQuery = false
				Main.LaserTrailData.LaserTrail.CanTouch = false
				if Module.RandomizeLaserColorIn == "None" then
					Main.LaserTrailData.LaserTrail.Color = Module.LaserTrailColor
				end
				Main.LaserTrailData.LaserTrail.Material = Module.LaserTrailMaterial
				Main.LaserTrailData.LaserTrail.Reflectance = Module.LaserTrailReflectance
				Main.LaserTrailData.LaserTrail.Transparency = Module.LaserTrailTransparency
				Main.LaserTrailData.LaserTrail.Size = Module.LaserTrailShape == "Cone" and Vector3.new(Module.LaserTrailWidth, (Main.FirePoint.WorldPosition - Main.CrosshairPointAttachment.WorldPosition).Magnitude, Module.LaserTrailHeight) or Vector3.new((Main.FirePoint.WorldPosition - Main.CrosshairPointAttachment.WorldPosition).Magnitude, Module.LaserTrailHeight, Module.LaserTrailWidth)
				Main.LaserTrailData.LaserTrail.CFrame = CFrame.new((Main.FirePoint.WorldPosition + Main.CrosshairPointAttachment.WorldPosition) * 0.5, Main.CrosshairPointAttachment.WorldPosition) * (Module.LaserTrailShape == "Cone" and CFrame.Angles(math.pi / 2, 0, 0) or CFrame.Angles(0, math.pi / 2, 0))
				Main.LaserTrailData.LaserTrail.Parent = Camera

				table.insert(LaserTrailContainer, Main.LaserTrailData)
			end
			if Module.LightningBoltEnabled and not Main.LightningBoltData then
				Main.LightningBoltData = {}
				Main.LightningBoltData.Id = Main.Id
				Main.LightningBoltData.Setting = Module
				Main.LightningBoltData.FirePoint = Main.FirePoint
				Main.LightningBoltData.CrosshairPointAttachment = Main.CrosshairPointAttachment
				table.insert(LightningBoltContainer, Main.LightningBoltData)
			end
			Main.CrosshairPointAttachment.Parent = Workspace.Terrain
			Main.CrosshairPointAttachment.WorldCFrame = CFrame.new(Dictionary.CrosshairPosition) --CFrame.new(Main.CrosshairPosition)
			if Module.LookAtInput then
				local FireDirection = (Main.CrosshairPointAttachment.WorldPosition - Main.FirePoint.WorldPosition).Unit
				Main.MuzzlePoint.CFrame = Main.MuzzlePoint.Parent.CFrame:toObjectSpace(CFrame.lookAt(Main.MuzzlePoint.WorldPosition, Dictionary.CrosshairPosition)) --CFrame.lookAt(Main.MuzzlePoint.WorldPosition, Main.CrosshairPosition)
				Main.CrosshairPointAttachment.WorldCFrame = CFrame.new(Dictionary.CrosshairPosition, FireDirection) --CFrame.new(Main.CrosshairPosition, FireDirection)
			end
		end
	else
		for i, v in pairs(Container) do
			if v.Main.Id == Dictionary.Id then
				if v.Main.CrosshairPointAttachment then
					v.Main.CrosshairPointAttachment:Destroy()
				end
				if v.Main.LaserBeamContainer then
					for ii, vv in pairs(v.Main.LaserBeamContainer) do
						if vv then
							vv:Destroy()
						end
					end
					table.clear(v.Main.LaserBeamContainer)
				end
				if v.Main.LaserTrailData then					
					for ii, vv in pairs(LaserTrailContainer) do
						if vv.Id == v.Main.LaserTrailData.Id then
							vv.Terminate = true
							break
						end
					end
					--table.clear(v.Main.LaserTrailData)
				end
				if v.Main.LightningBoltData then					
					for ii, vv in pairs(LightningBoltContainer) do
						if vv.Id == v.Main.LightningBoltData.Id then
							vv.Terminate = true
							break
						end
					end
					--table.clear(v.Main.LightningBoltData)
				end
				table.remove(Container, i)
				break
			end
		end
	end
end

function VisibleReplicatedMuzzle(MuzzlePointObject, Enabled)
	if MuzzlePointObject then
		for i, v in pairs(MuzzlePointObject:GetChildren()) do
			if v.ClassName == "ParticleEmitter" then
				if v:FindFirstChild("EmitCount") then
					if Enabled then
						Thread:Delay(0.01, function()
							v:Emit(v.EmitCount.Value)
						end)					
					end
				else
					v.Enabled = Enabled
				end	
			end
		end		
	end
end

function Charge(EffectName, State, Character, Tool, Handle, ChargeLevel, Replicate)
	if EffectName == "None" then
		return
	end
	local Effect = GetChargeEffectModule(EffectName)
	if Effect == nil then
		return
	end
	if State == "Begin" then
		Effect:BeginCharge(Character, Tool, Handle, ChargeLevel)
	elseif State == "End" then
		Effect:EndCharge(Character, Tool, Handle)
	end
	if Replicate then
		VisualizeCharge:FireServer(EffectName, State, Character, Tool, Handle, ChargeLevel)
	end
end

function Overheat(EffectName, State, Character, Tool, Handle, Replicate)
	if EffectName == "None" then
		return
	end
	local Effect = GetOverheatEffectModule(EffectName)
	if Effect == nil then
		return
	end
	if State == "Begin" then
		Effect:BeginOverheat(Character, Tool, Handle)
	elseif State == "End" then
		Effect:EndOverheat(Character, Tool, Handle)
	end
	if Replicate then
		VisualizeOverheat:FireServer(EffectName, State, Character, Tool, Handle)
	end
end

function GibJoint(Joint, Ragdoll, Tool, ModuleName, FullyGib)
	local Humanoid = Ragdoll:FindFirstChildOfClass("Humanoid")
	if Humanoid then
		local Module
		if typeof(ModuleName) == "table" then
			Module = GetSetting(nil, nil, nil, DecodePacket(ModuleName))
		else
			Module = GetSetting(Tool, {ModuleName = ModuleName})
		end
		local Torso = Ragdoll:FindFirstChild("UpperTorso") or Ragdoll:FindFirstChild("Torso")
		if Torso and Joint.Transparency ~= 1 and not Ragdoll:FindFirstChild("gibbed") and (Joint.Position - Camera.CFrame.p).Magnitude <= RenderDistance then	
			Joint.Transparency = 1

			local Tag = Instance.new("StringValue")
			Tag.Name = "gibbed"
			Tag.Parent = Ragdoll

			local Decal = Joint:FindFirstChildOfClass("Decal") 
			if Decal then
				Decal:Destroy()
			end

			if Joint.Name == "Head" then
				local parts = Ragdoll:GetChildren()
				for i = 1, #parts do
					if parts[i]:IsA("Hat") or parts[i]:IsA("Accessory") then
						local handle = parts[i].Handle:Clone()
						local children = handle:GetChildren()
						for i = 1, #children do
							if children[i]:IsA("Weld") then
								children[i]:Destroy()
							end
						end
						handle.CFrame = parts[i].Handle.CFrame
						handle.CanCollide = true
						handle.RotVelocity = Vector3.new((math.random() - 0.5) * 25, (math.random() - 0.5) * 25, (math.random() - 0.5) * 25)
						handle.Velocity = Vector3.new(
							(math.random() - 0.5) * 25,
							math.random(25, 50),
							(math.random() - 0.5) * 25
						)
						handle.Parent = Camera
						parts[i].Handle.Transparency = 1
					end
				end
				if not FullyGib then
					for _, headPart in pairs(DamagedHeadParts) do
						local part = Gibs[headPart]:Clone()
						part.Color = Joint.Color
						part.CFrame = Joint.CFrame
						part.RotVelocity = Vector3.new((math.random() - 0.5) * 25, (math.random() - 0.5) * 25, (math.random() - 0.5) * 25)
						part.Velocity = Vector3.new(
							(math.random() - 0.5) * 25,
							math.random(50, 100),
							(math.random() - 0.5) * 25
						)
						part.Parent = Camera
					end
				end
			end

			if FullyGib then
				local Limbs = (Humanoid.RigType == Enum.HumanoidRigType.R6) and Bones or BonesR15
				local Model = (Humanoid.RigType == Enum.HumanoidRigType.R6) and Skeleton or SkeletonR15
				for _, Limb in pairs(Limbs) do
					local limb = Model[Limb]:Clone()
					limb.Anchored = true
					limb.CanCollide = false
					limb.Parent = Camera
					local offset = Model.rig[Joint.Name].CFrame:ToObjectSpace(limb.CFrame)
					Joints[limb] = {Joint, function()
						return Joint.CFrame * offset
					end}
				end
			else
				local Limbs = (Humanoid.RigType == Enum.HumanoidRigType.R6) and Gore or GoreR15
				local Model = (Humanoid.RigType == Enum.HumanoidRigType.R6) and Gibs or GibsR15
				for _, Limb in pairs(Limbs[Joint.Name]) do
					local limb = Model[Limb]:Clone()
					limb.Anchored = true
					limb.CanCollide = false
					if not (limb.Name:match("flesh") or limb.Name:match("bone")) then
						limb.Color = Joint.Color
						if not limb.Name:match("head") then
							if limb.Name:match("leg") or limb.Name:match("foot") then
								if Ragdoll:FindFirstChildOfClass("Pants") then
									limb.TextureID = Ragdoll:FindFirstChildOfClass("Pants").PantsTemplate
								end
							else
								if limb.Name:match("torso") then
									if Ragdoll:FindFirstChildOfClass("Shirt") then
										limb.TextureID = Ragdoll:FindFirstChildOfClass("Shirt").ShirtTemplate
									else
										if Ragdoll:FindFirstChildOfClass("Pants") then
											limb.TextureID = Ragdoll:FindFirstChildOfClass("Pants").PantsTemplate
										end
									end
								else
									if Ragdoll:FindFirstChildOfClass("Shirt") then
										limb.TextureID = Ragdoll:FindFirstChildOfClass("Shirt").ShirtTemplate
									end
								end
							end
						end
					end
					limb.Parent = Camera
					local offset = Model.rig[Joint.Name].CFrame:ToObjectSpace(limb.CFrame)
					Joints[limb] = {Joint, function()
						return Joint.CFrame * offset
					end}
				end
			end

			local Attachment = Instance.new("Attachment")
			Attachment.CFrame = Joint.CFrame
			Attachment.Parent = workspace.Terrain

			local Sound = Instance.new("Sound")
			Sound.SoundId = "rbxassetid://"..Module.GoreSoundIDs[math.random(1, #Module.GoreSoundIDs)]
			Sound.PlaybackSpeed = Random.new():NextNumber(Module.GoreSoundPitchMin, Module.GoreSoundPitchMax)
			Sound.Volume = Module.GoreSoundVolume
			Sound.Parent = Attachment

			local function spawner()
				local GoreEffect = GunVisualEffects:FindFirstChild(Module.GoreEffect)
				if GoreEffect then
					local C = GoreEffect:GetChildren()
					for i = 1, #C do
						if C[i].className == "ParticleEmitter" then
							local count = 1
							local Particle = C[i]:Clone()
							Particle.Parent = Attachment
							if Particle:FindFirstChild("EmitCount") then
								count = Particle.EmitCount.Value
							end
							Thread:Delay(0.01, function()
								Particle:Emit(count)
								Debris:AddItem(Particle, Particle.Lifetime.Max)
							end)
						end
					end
				end
				Sound:Play()
			end

			Thread:Spawn(spawner)
			Debris:AddItem(Attachment, 10)	
		end
	end
end

gunEvent.Event:Connect(function(EventName, ...)
	if EventName == "VisualizeBullet" then
		SimulateReplicatedProjectile(...)
	elseif EventName == "VisualizeHitEffect" then
		VisualizeReplicatedHitEffect(...)
	elseif EventName == "RemoveBeam" then
		RemoveExistingBeam(...)
	elseif EventName == "PlayAudio" then
		PlayReplicatedAudio(...)
	elseif EventName == "VisualizeCharge" then
		Charge(...)
	elseif EventName == "VisualizeOverheat" then
		Overheat(...)
	end
end)

gunFunction.OnInvoke = function(EventName, ...)
	return nil --Nothing
end 

PlayAudio.OnClientEvent:Connect(PlayReplicatedAudio)
VisualizeBullet.OnClientEvent:Connect(SimulateReplicatedProjectile)
VisualizeHitEffect.OnClientEvent:Connect(VisualizeReplicatedHitEffect)
VisualizeBeam.OnClientEvent:Connect(VisualizeReplicatedBeam)
VisibleMuzzle.OnClientEvent:Connect(VisibleReplicatedMuzzle)
VisualizeCharge.OnClientEvent:Connect(Charge)
VisualizeOverheat.OnClientEvent:Connect(Overheat)
VisualizeGore.OnClientEvent:Connect(GibJoint)

RunService.RenderStepped:Connect(function(dt)
	for part, data in next, Joints do
		if data[1] == nil then
			part:Destroy()
		else
			part.CFrame = data[2]()
		end
	end
	for i, v in next, LaserTrailContainer, nil do
		if v.Terminate then
			v.Terminate = false
			local LaserTrail = v.LaserTrail
			local Module = v.Setting
			if LaserTrail then
				Thread:Spawn(function()
					if Module.LaserTrailFadeTime > 0 then
						local DesiredSize = LaserTrail.Size * (Module.ScaleLaserTrail and Vector3.new(1, Module.LaserTrailScaleMultiplier, Module.LaserTrailScaleMultiplier) or Vector3.new(1, 1, 1))
						local Tween = TweenService:Create(LaserTrail, TweenInfo.new(Module.LaserTrailFadeTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Transparency = 1, Size = DesiredSize})
						Tween:Play()
						Tween.Completed:Wait()
						LaserTrail:Destroy()
					else
						LaserTrail:Destroy()
					end	
				end)
			end
			table.remove(LaserTrailContainer, i)
		else
			if v.Setting.RandomizeLaserColorIn ~= "None" then
				local Hue = os.clock() % v.Setting.LaserColorCycleTime / v.Setting.LaserColorCycleTime
				local Color = Color3.fromHSV(Hue, 1, 1)
				v.LaserTrail.Color = Color
			end			
			v.LaserTrail.Size = v.Setting.LaserTrailShape == "Cone" and Vector3.new(v.Setting.LaserTrailWidth, (v.FirePoint.WorldPosition - v.CrosshairPointAttachment.WorldPosition).Magnitude, v.Setting.LaserTrailHeight) or Vector3.new((v.FirePoint.WorldPosition - v.CrosshairPointAttachment.WorldPosition).Magnitude, v.Setting.LaserTrailHeight, v.Setting.LaserTrailWidth)
			v.LaserTrail.CFrame = CFrame.new((v.FirePoint.WorldPosition + v.CrosshairPointAttachment.WorldPosition) * 0.5, v.CrosshairPointAttachment.WorldPosition) * (v.Setting.LaserTrailShape == "Cone" and CFrame.Angles(math.pi / 2, 0, 0) or CFrame.Angles(0, math.pi / 2, 0))	
		end
	end
	for i, v in next, LightningBoltContainer, nil do
		if v.Terminate then
			v.Terminate = false
			table.remove(LightningBoltContainer, i)
		else
			local BoltCFrameTable = {}
			local BoltRadius = v.Setting.BoltRadius
			for ii = 1, v.Setting.BoltCount do
				if ii == 1 then
					table.insert(BoltCFrameTable, CFrame.new(0, 0, 0))
				else
					table.insert(BoltCFrameTable, CFrame.new(math.random(-BoltRadius, BoltRadius), math.random(-BoltRadius, BoltRadius), 0))
				end
			end
			for _, vv in ipairs(BoltCFrameTable) do
				local FireDirection = (v.CrosshairPointAttachment.WorldPosition - v.FirePoint.WorldPosition).Unit
				local Start = (CFrame.new(v.FirePoint.WorldPosition, v.FirePoint.WorldPosition + FireDirection) * vv).p
				local End = (CFrame.new(v.CrosshairPointAttachment.WorldPosition, v.CrosshairPointAttachment.WorldPosition + FireDirection) * vv).p
				local Distance = (End - Start).Magnitude
				local LastPos = Start
				local RandomBoltColor = Color3.new(math.random(), math.random(), math.random())
				for ii = 0, Distance, 10 do
					local FakeDistance = CFrame.new(Start, End) * CFrame.new(0, 0, -ii - 10) * CFrame.new(-2 + (math.random() * v.Setting.BoltWideness), -2 + (math.random() * v.Setting.BoltWideness), -2 + (math.random() * v.Setting.BoltWideness))
					local BoltSegment = Miscs[v.Setting.BoltShape.."Segment"]:Clone()
					BoltSegment.CastShadow = false
					BoltSegment.CanQuery = false
					BoltSegment.CanTouch = false
					if v.Setting.RandomizeBoltColorIn ~= "None" then
						if v.Setting.RandomizeBoltColorIn == "Whole" then
							BoltSegment.Color = RandomBoltColor
						elseif v.Setting.RandomizeBoltColorIn == "Segment" then
							BoltSegment.Color = Color3.new(math.random(), math.random(), math.random())
						end
					else
						BoltSegment.Color = v.Setting.BoltColor
					end
					BoltSegment.Material = v.Setting.BoltMaterial
					BoltSegment.Reflectance = v.Setting.BoltReflectance
					BoltSegment.Transparency = v.Setting.BoltTransparency
					if ii + 10 > Distance then
						BoltSegment.CFrame = CFrame.new(LastPos, End) * CFrame.new(0, 0, -(LastPos - End).Magnitude / 2) * (v.Setting.BoltShape == "Cone" and CFrame.Angles(math.pi / 2, 0, 0) or CFrame.Angles(0, math.pi / 2, 0))
					else
						BoltSegment.CFrame = CFrame.new(LastPos, FakeDistance.p) * CFrame.new(0, 0, -(LastPos - FakeDistance.p).Magnitude / 2) * (v.Setting.BoltShape == "Cone" and CFrame.Angles(math.pi / 2, 0, 0) or CFrame.Angles(0, math.pi / 2, 0))
					end					
					if ii + 10 > Distance then
						BoltSegment.Size = v.Setting.BoltShape == "Cone" and Vector3.new(v.Setting.BoltWidth, (LastPos - End).Magnitude, v.Setting.BoltHeight) or Vector3.new((LastPos - End).Magnitude, v.Setting.BoltHeight, v.Setting.BoltWidth)
					else
						BoltSegment.Size = v.Setting.BoltShape == "Cone" and Vector3.new(v.Setting.BoltWidth, (LastPos - FakeDistance.p).Magnitude, v.Setting.BoltHeight) or Vector3.new((LastPos - FakeDistance.p).Magnitude, v.Setting.BoltHeight, v.Setting.BoltWidth)
					end
					BoltSegment.Parent = Camera
					Thread:Delay(v.Setting.BoltVisibleTime, function()
						if v.Setting.BoltFadeTime > 0 then
							local DesiredSize = BoltSegment.Size * (v.Setting.ScaleBolt and Vector3.new(1, v.Setting.BoltScaleMultiplier, v.Setting.BoltScaleMultiplier) or Vector3.new(1, 1, 1))
							local Tween = TweenService:Create(BoltSegment, TweenInfo.new(v.Setting.BoltFadeTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Transparency = 1, Size = DesiredSize})
							Tween:Play()
							Tween.Completed:Wait()
							BoltSegment:Destroy()
						else
							BoltSegment:Destroy()							
						end
					end)
					LastPos = FakeDistance.p
				end
			end
		end
	end
end)
