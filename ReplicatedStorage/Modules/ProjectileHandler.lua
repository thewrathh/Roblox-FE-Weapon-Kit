local ProjectileHandler = {}

local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Miscs = ReplicatedStorage:WaitForChild("Miscs")
local Events = ReplicatedStorage:WaitForChild("Events")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local RayUpdateFolder = Modules.RayUpdateFolder
local FastCast = require(Modules.FastCastRedux)
local DamageModule = require(Modules.DamageModule)
local PartCache = require(Modules.PartCache)
local GetSetting = require(Modules.GetSetting)
local Utilities = require(Modules.Utilities)
local Thread = Utilities.Thread
local Math = Utilities.Math
local DirectionPredictor = Utilities.DirectionPredictor
local CloneTable = Utilities.CloneTable
local CreatePacket, DecodePacket = unpack(Utilities.DataPacket)

local GunVisualEffects = Miscs.GunVisualEffects
local Bullets = Miscs.Bullets
local Projectiles = Miscs.Projectiles
local DebrisParts = Miscs.DebrisParts

local InflictTarget = Remotes.InflictTarget
local VisualizeBullet = Remotes.VisualizeBullet
local VisualizeHitEffect = Remotes.VisualizeHitEffect
local ShatterGlass = Remotes.ShatterGlass

-- Properties
local OptimalEffects = false -- Adjust details of effects by client quality level
local RenderDistance = 400 -- Maximum camera distance to render visual effects
local ScreenCullingEnabled = true -- Show visual effects when their positions are on screen
local MaxDebrisCounts = 100 -- Maximum number of debris objects (mostly decayed projectiles) to exist
local CachedSegmentCounts = 500 -- Number of segments (lightning) to be cached. Lowering value make lightning less aesthetic but more performant and vice versa
local CachedDebrisCounts = 100 -- Number of emitted debris (not decayed projectile) to be cached
local RayExit = true -- Only for Wall Penetration
FastCast.DebugLogging = false
FastCast.VisualizeCasts = false

local Beam = Instance.new("Beam")
Beam.TextureSpeed = 0
Beam.LightEmission = 0
Beam.LightInfluence = 1
Beam.Transparency = NumberSequence.new(0)

local BlockSegContainer = Instance.new("Folder")
BlockSegContainer.Name = "BlockSegContainer"
BlockSegContainer.Parent = Camera

local CylinderSegContainer = Instance.new("Folder")
CylinderSegContainer.Name = "CylinderSegContainer"
CylinderSegContainer.Parent = Camera

local ConeSegContainer = Instance.new("Folder")
ConeSegContainer.Name = "ConeSegContainer"
ConeSegContainer.Parent = Camera

local Caster = FastCast.new()

local BlockSegCache = PartCache.new(Miscs.BlockSegment, CachedSegmentCounts, BlockSegContainer)
local CylinderSegCache = PartCache.new(Miscs.CylinderSegment, CachedSegmentCounts, CylinderSegContainer)
local ConeSegCache = PartCache.new(Miscs.ConeSegment, CachedSegmentCounts, ConeSegContainer)

local Tau = math.pi * 2

local ShootId = 0
local DebrisCounts = 0
local PartCacheStorage = {}
local DebrisPartCacheStorage = {}
local RayUpdaters = {}
local IgnoreList = {Camera}

local function ClampMagnitude(Vector, Max)
	if (Vector.Magnitude == 0) then return Vector3.new(0, 0, 0) end
	return Vector.Unit * math.min(Vector.Magnitude, Max) 
end

local function AddressTableValue(Level, ValueName, Setting)
	if Setting.ChargedShotAdvanceEnabled and Setting.ChargeAlterTable then
		local AlterTable = Setting.ChargeAlterTable[ValueName]
		return AlterTable and ((Level == 1 and AlterTable.Level1) or (Level == 2 and AlterTable.Level2) or (Level == 3 and AlterTable.Level3) or Setting[ValueName]) or Setting[ValueName]
	else
		return Setting[ValueName]
	end
end

local function CastRay(Cast, Origin, Direction, Blacklist, IgnoreWater, RealTargetHumanoid)
	debug.profilebegin("CastRay_(ProjectileHandler)")
	if RealTargetHumanoid then
		Blacklist = CloneTable(IgnoreList)
	end
	local Iterations = 0
	local NewRay = Ray.new(Origin, Direction)
	local HitPart, HitPoint, HitNormal, HitMaterial = nil, Origin + Direction, Vector3.new(0, 1, 0), Enum.Material.Air
	while Iterations < 20 do
		Iterations = Iterations + 1
		HitPart, HitPoint, HitNormal, HitMaterial = Workspace:FindPartOnRayWithIgnoreList(NewRay, Blacklist, false, IgnoreWater)
		if HitPart then
			--if Cast.UserData.Setting.IgnoreBlacklistedParts and Cast.UserData.Setting.BlacklistParts[HitPart.Name] then
			--	table.insert(Blacklist, HitPart)
			--else
				local TEAM = Cast.UserData.Character:FindFirstChild("TEAM")
				local Target = HitPart:FindFirstAncestorOfClass("Model")
				local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
				local CanBlock = Target and Target:FindFirstChild("CanBlock")
				local TargetTool = HitPart:FindFirstAncestorOfClass("Tool")
				local CanDamage = DamageModule.CanDamage(Target, Cast.UserData.Character, Cast.UserData.Setting.FriendlyFire)
				local ExplosiveEnabled = AddressTableValue(Cast.UserData.Misc.ChargeLevel, "ExplosiveEnabled", Cast.UserData.Setting)
				local SelfDamage = AddressTableValue(Cast.UserData.Misc.ChargeLevel, "SelfDamage", Cast.UserData.Setting)
				if RealTargetHumanoid and ExplosiveEnabled and SelfDamage then
					if RealTargetHumanoid.Parent.Name == Player.Name then
						CanDamage = (RealTargetHumanoid.Parent.Name == Player.Name)
					end
				end
				if (--[[not HitPart.CanCollide
					or]] HitPart.Transparency > 0.75
					or HitPart.Name == "Handle"
					or (
						TargetHumanoid and (
							TargetHumanoid.Health <= 0
								or not CanDamage
								or (Cast.UserData.BounceData and table.find(Cast.UserData.BounceData.BouncedHumanoids, TargetHumanoid))
								or (RealTargetHumanoid and RealTargetHumanoid ~= TargetHumanoid)
						)
					)
					--or (CanBlock and ((TEAM and CanBlock:FindFirstChild("TEAM")) and CanBlock.TEAM.Value == TEAM.Value))
					or TargetTool) then
					table.insert(Blacklist, HitPart)
				else
					break
				end				
			--end
		else
			break
		end
	end
	debug.profileend()
	return HitPart, HitPoint, HitNormal, HitMaterial
end

local function CanShowEffects(Position)
	if ScreenCullingEnabled then
		local _, OnScreen = Camera:WorldToScreenPoint(Position)
		return OnScreen and (Position - Camera.CFrame.p).Magnitude <= RenderDistance
	end
	return (Position - Camera.CFrame.p).Magnitude <= RenderDistance
end

local function PopulateHumanoids(Cast)
	for _, v in pairs(CollectionService:GetTagged("Humanoids")) do
		if v.Parent ~= Cast.UserData.Character and DamageModule.CanDamage(v.Parent, Cast.UserData.Character, Cast.UserData.Setting.FriendlyFire) then
			table.insert(Humanoids, v)
		end	
	end
end

local function FindNearestEntity(Cast, Position)
	Humanoids = {}
	PopulateHumanoids(Cast)
	local Dist = Cast.UserData.HomeData.HomingDistance
	local TargetModel = nil
	local TargetHumanoid = nil
	local TargetTorso = nil
	for i, v in ipairs(Humanoids) do
		local torso = v.Parent:FindFirstChild("HumanoidRootPart") or v.Parent:FindFirstChild("Torso") or v.Parent:FindFirstChild("UpperTorso")
		if v and torso and (torso.Position - Position).Magnitude < (Dist + (torso.Size.Magnitude / 2.5)) and v.Health > 0 then
			local hit = not Cast.UserData.HomeData.HomeThroughWall and CastRay(Cast, Position, (torso.CFrame.p - Position).Unit * 999, Cast.UserData.IgnoreList, true) or nil
			local CanTrack = true
			if not Cast.UserData.HomeData.HomeThroughWall then
				CanTrack = (hit and hit:IsDescendantOf(v.Parent))
			end
			if CanTrack and DamageModule.CanDamage(v.Parent, Cast.UserData.Character, Cast.UserData.Setting.FriendlyFire) then
				TargetModel = v.Parent
				TargetHumanoid = v
				TargetTorso = torso
				Dist = (Position - torso.Position).Magnitude
			end					
		end
	end
	return TargetModel, TargetHumanoid, TargetTorso
end

local function GetEmitCount(Count)
	if OptimalEffects then
		local QualityLevel = UserSettings().GameSettings.SavedQualityLevel
		if QualityLevel == Enum.SavedQualitySetting.Automatic then
			local Compressor = 1 / 2
			return Count * Compressor
		else
			local Compressor = QualityLevel.Value / 21
			return Count * Compressor
		end
	else
		return Count
	end
end

function FadeBeam(A0, A1, Beam, Hole, FadeTime, Replicate)
	local function Fade()
		local t0 = os.clock()
		while Hole ~= nil do
			local Alpha = math.min((os.clock() - t0) / FadeTime, 1)
			if Beam then Beam.Transparency = NumberSequence.new(Math.Lerp(0, 1, Alpha)) end
			if Alpha == 1 then break end
			Thread:Wait()
		end
	end
	local function Destroy()
		if A0 then A0:Destroy() end
		if A1 then A1:Destroy() end
		if Beam then Beam:Destroy() end
		if Hole then Hole:Destroy() end
	end
	if FadeTime > 0 then
		if OptimalEffects then
			if Replicate then
				Fade()
				Destroy()
			else
				Destroy()
			end
		else
			Fade()
			Destroy()
		end
	else
		Destroy()
	end
end

function EmitDebris(DebrisContent, Direction, Hit, Position, Normal, Material, NormalizeHitEffect)
	local SurfaceCF = NormalizeHitEffect and CFrame.new(Position, Position + Normal) or CFrame.new(Position, Position - Direction)
	local DebrisPart = DebrisParts:FindFirstChild(DebrisContent.DebrisName.Value)
	if DebrisPart then
		local Exist = false
		local DebrisPartProvider
		for _, v in pairs(DebrisPartCacheStorage) do
			if v.ProjectileName == DebrisPart.Name then
				Exist = true
				DebrisPartProvider = v.DebrisPartProvider
				break
			end
		end
		if not Exist then
			local DebrisContainer = Instance.new("Folder")
			DebrisContainer.Name = "DebrisContainer_("..DebrisPart.Name..")"
			DebrisContainer.Parent = Camera
			DebrisPartProvider = PartCache.new(DebrisPart, CachedDebrisCounts, DebrisContainer)
			table.insert(DebrisPartCacheStorage, {
				ProjectileName = DebrisPart.Name,
				DebrisPartProvider = DebrisPartProvider
			})
		end
		--Configs
		local MinVelocity = 25
		local MaxVelocity = 50
		if DebrisContent:FindFirstChild("Velocity") then
			MinVelocity = DebrisContent.Velocity.Min.Value
			MaxVelocity = DebrisContent.Velocity.Max.Value
		end
		--
		local MinRotVelocity = 25
		local MaxRotVelocity = 50
		if DebrisContent:FindFirstChild("RotVelocity") then
			MinRotVelocity = DebrisContent.RotVelocity.Min.Value
			MaxRotVelocity = DebrisContent.RotVelocity.Max.Value
		end
		--
		local MinSpread = 5
		local MaxSpread = 15
		if DebrisContent:FindFirstChild("Spread") then
			MinSpread = DebrisContent.Spread.Min.Value
			MaxSpread = DebrisContent.Spread.Max.Value
		end
		--
		local Lifetime = DebrisContent:FindFirstChild("Lifetime") and DebrisContent.Lifetime.Value or 5
		--
		local EmitCount = DebrisContent:FindFirstChild("EmitCount") and DebrisContent.EmitCount.Value or 5
		--
		local PartColor = false
		if DebrisContent:FindFirstChild("PartColor") then
			PartColor = DebrisContent.PartColor.Value
		end
		--
		local function SetEnabled(ClonedDebris, Enabled)
			for _, v in pairs(ClonedDebris:GetDescendants()) do
				if v:IsA("ParticleEmitter") or v:IsA("PointLight") or v:IsA("SurfaceLight") or v:IsA("SpotLight") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("BillboardGui") or v:IsA("SurfaceGui") then
					v.Enabled = Enabled
				end
			end
		end
		for i = 1, GetEmitCount(EmitCount) do
			local DirectionalCF = CFrame.new(Vector3.new(), SurfaceCF.LookVector)
			local Direction = (DirectionalCF * CFrame.fromOrientation(0, 0, Random.new():NextNumber(0, Tau)) * CFrame.fromOrientation(math.rad(Random.new():NextNumber(MinSpread, MaxSpread)), 0, 0)).LookVector
			local RotX = Random.new():NextNumber(MinRotVelocity, MaxRotVelocity)
			local RotY = Random.new():NextNumber(MinRotVelocity, MaxRotVelocity)
			local RotZ = Random.new():NextNumber(MinRotVelocity, MaxRotVelocity)
			local ClonedDebris = DebrisPartProvider:GetPart()
			PhysicsService:SetPartCollisionGroup(ClonedDebris, "Debris")
			ClonedDebris.Anchored = false
			ClonedDebris.CastShadow = false
			ClonedDebris.CanQuery = false
			ClonedDebris.CanTouch = false
			if PartColor then
				local HitPartColor = Hit and Hit.Color or Color3.fromRGB(255, 255, 255)
				if Hit and Hit:IsA("Terrain") then
					HitPartColor = Workspace.Terrain:GetMaterialColor(Material or Enum.Material.Sand)
				end
				ClonedDebris.Color = HitPartColor
			end
			SetEnabled(ClonedDebris, false)
			ClonedDebris.CFrame = CFrame.new(SurfaceCF.p, SurfaceCF.p + Direction)
			SetEnabled(ClonedDebris, true)
			ClonedDebris.Velocity = Direction * Random.new():NextNumber(MinVelocity, MaxVelocity)
			ClonedDebris.RotVelocity = Vector3.new(RotX, RotY, RotZ)
			Thread:Delay(Lifetime, function()
				if ClonedDebris ~= nil then
					SetEnabled(ClonedDebris, false)
					DebrisPartProvider:ReturnPart(ClonedDebris)
				end
			end)
		end
	end
end

function MakeImpactFX(Direction, Hit, Position, Normal, Material, ParentToPart, Setting, Misc, Replicate, Blocked, IsMelee)
	local SurfaceCF = CFrame.new(Position, Position + Normal)

	local HitEffectEnabled = Setting.HitEffectEnabled
	local HitSoundIDs = IsMelee and Setting.MeleeHitSoundIDs or AddressTableValue(Misc.ChargeLevel, "HitSoundIDs", Setting)
	local HitSoundPitchMin = IsMelee and Setting.MeleeHitSoundPitchMin or AddressTableValue(Misc.ChargeLevel, "HitSoundPitchMin", Setting)
	local HitSoundPitchMax = IsMelee and Setting.MeleeHitSoundPitchMax or AddressTableValue(Misc.ChargeLevel, "HitSoundPitchMax", Setting)
	local HitSoundVolume = IsMelee and Setting.MeleeHitSoundVolume or AddressTableValue(Misc.ChargeLevel, "HitSoundVolume", Setting)
	local CustomHitEffect = AddressTableValue(Misc.ChargeLevel, "CustomHitEffect", Setting)
	local NormalizeHitEffect = AddressTableValue(Misc.ChargeLevel, "NormalizeHitEffect", Setting)

	local BulletHoleEnabled = Setting.BulletHoleEnabled
	local BulletHoleSize = IsMelee and Setting.MarkerEffectSize or AddressTableValue(Misc.ChargeLevel, "BulletHoleSize", Setting)
	local BulletHoleTexture = IsMelee and Setting.MarkerEffectTexture or AddressTableValue(Misc.ChargeLevel, "BulletHoleTexture", Setting)
	local PartColor = AddressTableValue(Misc.ChargeLevel, "PartColor", Setting)
	local BulletHoleVisibleTime = IsMelee and Setting.MarkerEffectVisibleTime or Setting.BulletHoleVisibleTime
	local BulletHoleFadeTime = IsMelee and Setting.MarkerEffectFadeTime or Setting.BulletHoleFadeTime

	local EffectFolder = GunVisualEffects:FindFirstChild(IsMelee and Setting.MeleeHitEffect or AddressTableValue(Misc.ChargeLevel, "HitEffect", Setting))

	if IsMelee then
		HitEffectEnabled = Setting.MeleeHitEffectEnabled
		CustomHitEffect = Setting.CustomMeleeHitEffect
		NormalizeHitEffect = Setting.NormalizeMeleeHitEffect

		BulletHoleEnabled = Setting.MarkerEffectEnabled
		PartColor = Setting.MarkerPartColor
	end

	if Blocked then
		HitEffectEnabled = Setting.BlockEffectEnabled
		HitSoundIDs = IsMelee and Setting.MeleeBlockSoundIDs or AddressTableValue(Misc.ChargeLevel, "BlockSoundIDs", Setting)
		HitSoundPitchMin = IsMelee and Setting.MeleeBlockSoundPitchMin or AddressTableValue(Misc.ChargeLevel, "BlockSoundPitchMin", Setting)
		HitSoundPitchMax = IsMelee and Setting.MeleeBlockSoundPitchMax or AddressTableValue(Misc.ChargeLevel, "BlockSoundPitchMax", Setting)
		HitSoundVolume = IsMelee and Setting.MeleeBlockSoundVolume or AddressTableValue(Misc.ChargeLevel, "BlockSoundVolume", Setting)
		NormalizeHitEffect = AddressTableValue(Misc.ChargeLevel, "NormalizeBlockEffect", Setting)

		EffectFolder = GunVisualEffects:FindFirstChild(IsMelee and Setting.MeleeBlockEffect or AddressTableValue(Misc.ChargeLevel, "BlockEffect", Setting))

		if IsMelee then
			HitEffectEnabled = Setting.MeleeBlockEffectEnabled
			NormalizeHitEffect = Setting.NormalizeMeleeBlockEffect
		end
	end

	if HitEffectEnabled then
		local Attachment = Instance.new("Attachment")
		Attachment.CFrame = NormalizeHitEffect and SurfaceCF or CFrame.new(Position, Position + Direction)
		Attachment.Parent = Workspace.Terrain
		local Sound

		local function PlaySound()
			Sound = Instance.new("Sound")
			Sound.SoundId = "rbxassetid://"..HitSoundIDs[math.random(1, #HitSoundIDs)]
			Sound.PlaybackSpeed = Random.new():NextNumber(HitSoundPitchMin, HitSoundPitchMax)
			Sound.Volume = HitSoundVolume
			Sound.Parent = Attachment
		end

		local function Spawner(material)
			local RealEffectFolder = material == "Block" and EffectFolder or (EffectFolder and EffectFolder:FindFirstChild(material) or nil)
			if material ~= "Block" then
				if RealEffectFolder and RealEffectFolder:FindFirstChild("MaterialSounds") then
					local tracks = RealEffectFolder.MaterialSounds:GetChildren()
					local rn = math.random(1, #tracks)
					local track = tracks[rn]
					if track ~= nil then
						Sound = track:Clone()
						if track:FindFirstChild("Pitch") then
							Sound.PlaybackSpeed = Random.new():NextNumber(track.Pitch.Min.Value, track.Pitch.Max.Value)
						else
							Sound.PlaybackSpeed = Random.new():NextNumber(HitSoundPitchMin, HitSoundPitchMax)
						end
						if track:FindFirstChild("Volume") then
							Sound.Volume = Random.new():NextNumber(track.Volume.Min.Value, track.Volume.Max.Value)
						else
							Sound.Volume = HitSoundVolume
						end
						Sound.Parent = Attachment
					end
				else
					PlaySound()
				end
			else
				PlaySound()
			end
			if RealEffectFolder then
				for i, v in pairs(RealEffectFolder:GetChildren()) do
					if v.ClassName == "ParticleEmitter" then
						local Count = 1
						local Particle = v:Clone()
						Particle.Parent = Attachment
						if Particle:FindFirstChild("EmitCount") then
							Count = Particle.EmitCount.Value
						end
						if Particle:FindFirstChild("PartColor") then
							if Particle.PartColor.Value then
								local HitPartColor = Hit and Hit.Color or Color3.fromRGB(255, 255, 255)
								if Hit and Hit:IsA("Terrain") then
									HitPartColor = Workspace.Terrain:GetMaterialColor(Material or Enum.Material.Sand)
								end
								Particle.Color = ColorSequence.new(HitPartColor, HitPartColor)
							end
						end
						Thread:Delay(0.01, function()
							Particle:Emit(GetEmitCount(Count))
							Debris:AddItem(Particle, Particle.Lifetime.Max)
						end)					
					end
				end
			end
			if material ~= "Block" and RealEffectFolder and RealEffectFolder:FindFirstChildOfClass("StringValue") then
				local DebrisValue = RealEffectFolder:FindFirstChildOfClass("StringValue")
				if DebrisValue.Name == "Debris" then
					EmitDebris(DebrisValue, Direction, Hit, Position, Normal, Material, NormalizeHitEffect)
				end
			end
			Sound:Play()
			if BulletHoleEnabled and not Blocked then
				local Hole = Instance.new("Attachment")
				Hole.Parent = ParentToPart and Hit or Workspace.Terrain
				Hole.WorldCFrame = SurfaceCF * CFrame.Angles(math.rad(90), math.rad(180), 0)
				if ParentToPart then
					local Scale = BulletHoleSize
					if RealEffectFolder and RealEffectFolder:FindFirstChild("MaterialHoleSize") then
						Scale = RealEffectFolder.MaterialHoleSize.Value
					end
					local A0 = Instance.new("Attachment")
					local A1 = Instance.new("Attachment")
					local BeamClone = Beam:Clone()
					BeamClone.Width0 = Scale
					BeamClone.Width1 = Scale
					if RealEffectFolder and RealEffectFolder:FindFirstChild("MaterialDecals") then
						local Decals = RealEffectFolder.MaterialDecals:GetChildren()
						local Chosen = math.random(1, #Decals)
						local Decal = Decals[Chosen]
						if Decal ~= nil then
							BeamClone.Texture = "rbxassetid://"..Decal.Value
							if Decal:FindFirstChild("PartColor") then
								if Decal.PartColor.Value then
									local HitPartColor = Hit and Hit.Color or Color3.fromRGB(255, 255, 255)
									if Hit and Hit:IsA("Terrain") then
										HitPartColor = Workspace.Terrain:GetMaterialColor(Material or Enum.Material.Sand)
									end
									BeamClone.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, HitPartColor), ColorSequenceKeypoint.new(1, HitPartColor)})
								end
							end
						end
					else
						BeamClone.Texture = "rbxassetid://"..BulletHoleTexture[math.random(1, #BulletHoleTexture)]
						if PartColor then
							local HitPartColor = Hit and Hit.Color or Color3.fromRGB(255, 255, 255)
							if Hit and Hit:IsA("Terrain") then
								HitPartColor = Workspace.Terrain:GetMaterialColor(Material or Enum.Material.Sand)
							end
							BeamClone.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, HitPartColor), ColorSequenceKeypoint.new(1, HitPartColor)})
						end
					end
					BeamClone.Attachment0 = A0
					BeamClone.Attachment1 = A1
					A0.Parent = Hit
					A1.Parent = Hit
					A0.WorldCFrame = Hole.WorldCFrame * CFrame.new(Scale / 2, -0.01, 0) * CFrame.Angles(math.rad(90), 0, 0)
					A1.WorldCFrame = Hole.WorldCFrame * CFrame.new(-Scale / 2, -0.01, 0) * CFrame.Angles(math.rad(90), math.rad(180), 0)
					BeamClone.Parent = Workspace.Terrain
					Thread:Delay(BulletHoleVisibleTime, function()
						FadeBeam(A0, A1, BeamClone, Hole, BulletHoleFadeTime, Replicate)
					end)
				else
					Debris:AddItem(Hole, 5)
				end
			end
		end

		if Blocked then
			Spawner("Block")
		else
			if not CustomHitEffect then
				if EffectFolder and EffectFolder:FindFirstChild(Material) then
					Spawner(Material.Name)
				else
					Spawner("Custom")
				end
			else
				Spawner("Custom")
			end
		end

		Debris:AddItem(Attachment, 10)				
	end
end

function MakeBloodFX(Direction, Hit, Position, Normal, Material, ParentToPart, Setting, Misc, Replicate, IsAMetal, IsMelee)
	local SurfaceCF = CFrame.new(Position, Position + Normal)

	local BloodEnabled = Setting.BloodEnabled
	local HitCharSndIDs = IsMelee and Setting.MeleeHitCharSndIDs or AddressTableValue(Misc.ChargeLevel, "HitCharSndIDs", Setting)
	local HitCharSndPitchMin = IsMelee and Setting.MeleeHitCharSndPitchMin or AddressTableValue(Misc.ChargeLevel, "HitCharSndPitchMin", Setting)
	local HitCharSndPitchMax = IsMelee and Setting.MeleeHitCharSndPitchMax or AddressTableValue(Misc.ChargeLevel, "HitCharSndPitchMax", Setting)
	local HitCharSndVolume = IsMelee and Setting.MeleeHitCharSndVolume or AddressTableValue(Misc.ChargeLevel, "HitCharSndVolume", Setting)
	local NormalizeBlood = AddressTableValue(Misc.ChargeLevel, "NormalizeBlood", Setting)

	local BloodWoundEnabled = Setting.BloodWoundEnabled
	local BloodWoundTexture = IsMelee and Setting.MeleeBloodWoundTexture or AddressTableValue(Misc.ChargeLevel, "BloodWoundTexture", Setting)
	local BloodWoundSize = IsMelee and Setting.MeleeBloodWoundSize or AddressTableValue(Misc.ChargeLevel, "BloodWoundSize", Setting)
	local BloodWoundTextureColor = IsMelee and Setting.MeleeBloodWoundTextureColor or AddressTableValue(Misc.ChargeLevel, "BloodWoundTextureColor", Setting)
	local BloodWoundPartColor = AddressTableValue(Misc.ChargeLevel, "BloodWoundPartColor", Setting)
	local BloodWoundVisibleTime = IsMelee and Setting.MeleeBloodWoundVisibleTime or Setting.BloodWoundVisibleTime
	local BloodWoundFadeTime = IsMelee and Setting.MeleeBloodWoundFadeTime or Setting.BloodWoundFadeTime

	local MetalEnabled = Setting.MetalEnabled

	local BloodEffectFolder = GunVisualEffects:FindFirstChild(IsMelee and Setting.MeleeBloodEffect or AddressTableValue(Misc.ChargeLevel, "BloodEffect", Setting))

	if IsMelee then
		BloodEnabled = Setting.MeleeBloodEnabled
		NormalizeBlood = Setting.NormalizeMeleeBlood

		BloodWoundEnabled = Setting.MeleeBloodWoundEnabled
		BloodWoundPartColor = Setting.MeleeBloodWoundPartColor

		MetalEnabled = Setting.MeleeMetalEnabled
	end

	if IsAMetal and MetalEnabled then
		HitCharSndIDs = IsAMetal and Setting.MeleeHitMetalSndIDs or AddressTableValue(Misc.ChargeLevel, "HitMetalSndIDs", Setting)
		HitCharSndPitchMin = IsAMetal and Setting.MeleeHitMetalSndPitchMin or AddressTableValue(Misc.ChargeLevel, "HitMetalSndPitchMin", Setting)
		HitCharSndPitchMax = IsAMetal and Setting.MeleeHitMetalSndPitchMax or AddressTableValue(Misc.ChargeLevel, "HitMetalSndPitchMax", Setting)
		HitCharSndVolume = IsAMetal and Setting.MeleeHitMetalSndVolume or AddressTableValue(Misc.ChargeLevel, "HitMetalSndVolume", Setting)

		BloodWoundEnabled = Setting.MetalHoleEnabled
		BloodWoundTexture = IsAMetal and Setting.MeleeMetalHoleTexture or AddressTableValue(Misc.ChargeLevel, "MetalHoleTexture", Setting)
		BloodWoundSize = IsAMetal and Setting.MeleeMetalHoleSize or AddressTableValue(Misc.ChargeLevel, "MetalHoleSize", Setting)
		BloodWoundTextureColor = IsAMetal and Setting.MeleeMetalHoleTextureColor or AddressTableValue(Misc.ChargeLevel, "MetalHoleTextureColor", Setting)
		BloodWoundPartColor = IsAMetal and Setting.MeleeMetalHolePartColor or AddressTableValue(Misc.ChargeLevel, "MetalHolePartColor", Setting)
		BloodWoundVisibleTime = IsAMetal and Setting.MeleeMetalHoleVisibleTime or Setting.MetalHoleVisibleTime
		BloodWoundFadeTime = IsAMetal and Setting.MeleeMetalHoleFadeTime or Setting.MetalHoleFadeTime

		BloodEffectFolder = GunVisualEffects:FindFirstChild(IsAMetal and Setting.MeleeMetalEffect or AddressTableValue(Misc.ChargeLevel, "MetalEffect", Setting))

		if IsMelee then
			BloodWoundEnabled = Setting.MeleeMetalHoleEnabled
			BloodWoundPartColor = Setting.MeleeMetalHolePartColor
		end
	end

	if BloodEnabled then
		local Attachment = Instance.new("Attachment")
		Attachment.CFrame = NormalizeBlood and SurfaceCF or CFrame.new(Position, Position + Direction)
		Attachment.Parent = Workspace.Terrain
		local Sound = Instance.new("Sound")
		Sound.SoundId = "rbxassetid://"..HitCharSndIDs[math.random(1, #HitCharSndIDs)]
		Sound.PlaybackSpeed = Random.new():NextNumber(HitCharSndPitchMin, HitCharSndPitchMax)
		Sound.Volume = HitCharSndVolume
		Sound.Parent = Attachment
		if BloodEffectFolder then
			for i, v in pairs(BloodEffectFolder:GetChildren()) do
				if v.ClassName == "ParticleEmitter" then
					local Count = 1
					local Particle = v:Clone()
					Particle.Parent = Attachment
					if Particle:FindFirstChild("EmitCount") then
						Count = Particle.EmitCount.Value
					end
					Thread:Delay(0.01, function()
						Particle:Emit(GetEmitCount(Count))
						Debris:AddItem(Particle, Particle.Lifetime.Max)
					end)
				end
			end
		end
		Sound:Play()
		Debris:AddItem(Attachment, 10)

		if BloodWoundEnabled then
			local Hole = Instance.new("Attachment")
			Hole.Parent = ParentToPart and Hit or Workspace.Terrain
			Hole.WorldCFrame = SurfaceCF * CFrame.Angles(math.rad(90), math.rad(180), 0)
			if ParentToPart then
				local A0 = Instance.new("Attachment")
				local A1 = Instance.new("Attachment")
				local BeamClone = Beam:Clone()
				BeamClone.Width0 = BloodWoundSize
				BeamClone.Width1 = BloodWoundSize
				BeamClone.Texture = "rbxassetid://"..BloodWoundTexture[math.random(1, #BloodWoundTexture)]
				BeamClone.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, BloodWoundTextureColor), ColorSequenceKeypoint.new(1, BloodWoundTextureColor)})
				if BloodWoundPartColor then
					local HitPartColor = Hit and Hit.Color or Color3.fromRGB(255, 255, 255)
					if Hit and Hit:IsA("Terrain") then
						HitPartColor = Workspace.Terrain:GetMaterialColor(Material or Enum.Material.Sand)
					end
					BeamClone.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, HitPartColor), ColorSequenceKeypoint.new(1, HitPartColor)})
				end				
				BeamClone.Attachment0 = A0
				BeamClone.Attachment1 = A1
				A0.Parent = Hit
				A1.Parent = Hit
				A0.WorldCFrame = Hole.WorldCFrame * CFrame.new(BloodWoundSize / 2, -0.01, 0) * CFrame.Angles(math.rad(90), 0, 0)
				A1.WorldCFrame = Hole.WorldCFrame * CFrame.new(-BloodWoundSize / 2, -0.01, 0) * CFrame.Angles(math.rad(90), math.rad(180), 0)
				BeamClone.Parent = Workspace.Terrain
				Thread:Delay(BloodWoundVisibleTime, function()
					FadeBeam(A0, A1, BeamClone, Hole, BloodWoundFadeTime, Replicate)
				end)
			else
				Debris:AddItem(Hole, 5)
			end
		end
	end
end

function OnRayFinalHit(Cast, Origin, Direction, RaycastResult, SegmentVelocity, CosmeticBulletObject, Blocked)
	local EndPos = RaycastResult and RaycastResult.Position or Cast.UserData.SegmentOrigin
	local ShowEffects = CanShowEffects(EndPos)
	if Blocked then
		if ShowEffects then
			MakeImpactFX(Cast.UserData.SegmentDirection, RaycastResult.Instance, RaycastResult.Position, RaycastResult.Normal, RaycastResult.Material, true, Cast.UserData.Setting, Cast.UserData.Misc, Cast.UserData.Replicate, Blocked)
		end
		return
	end
	if not AddressTableValue(Cast.UserData.Misc.ChargeLevel, "ExplosiveEnabled", Cast.UserData.Setting) then
		if not RaycastResult then
			return
		end
		if RaycastResult.Instance and RaycastResult.Instance.Parent then
			if RaycastResult.Instance.Name == "_glass" and AddressTableValue(Cast.UserData.Misc.ChargeLevel, "CanBreakGlass", Cast.UserData.Setting) then
				if Cast.UserData.Replicate then
					ShatterGlass:FireServer(RaycastResult.Instance, RaycastResult.Position, Direction)
				end
			else
				if Cast.UserData.Setting.BlacklistParts[RaycastResult.Instance.Name] then
					if ShowEffects then
						MakeImpactFX(Cast.UserData.SegmentDirection, RaycastResult.Instance, RaycastResult.Position, RaycastResult.Normal, RaycastResult.Material, true, Cast.UserData.Setting, Cast.UserData.Misc, Cast.UserData.Replicate)
					end
				else
					local Distance = (RaycastResult.Position - Origin).Magnitude
					local Target = RaycastResult.Instance:FindFirstAncestorOfClass("Model")
					local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
					local TargetTorso = Target and (Target:FindFirstChild("HumanoidRootPart") or Target:FindFirstChild("Head"))
					if TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso then
						if ShowEffects then
							MakeBloodFX(Cast.UserData.SegmentDirection, RaycastResult.Instance, RaycastResult.Position, RaycastResult.Normal, RaycastResult.Material, true, Cast.UserData.Setting, Cast.UserData.Misc, Cast.UserData.Replicate, Target:FindFirstChild("IAmMetal"))
						end
						if Cast.UserData.Replicate then
							Thread:Spawn(function()
								local TempMisc = CloneTable(Cast.UserData.Misc)
								TempMisc["BulletId"] = Cast.UserData.BulletId
								TempMisc["ClientHitSize"] = RaycastResult.Instance.Size
								TempMisc["Distance"] = Distance
								TempMisc["MousePosition"] = nil
								InflictTarget:FireServer("Gun", Cast.UserData.Tool, RaycastResult.Instance, CreatePacket(TempMisc))
							end)
							if Cast.UserData.Tool and Cast.UserData.Tool.GunClient:FindFirstChild("MarkerEvent") then
								local ShouldHeadshot = AddressTableValue(Cast.UserData.Misc.ChargeLevel, "HeadshotHitmarker", Cast.UserData.Setting)
								Cast.UserData.Tool.GunClient.MarkerEvent:Fire(Cast.UserData.Setting, RaycastResult.Instance.Name == "Head" and ShouldHeadshot)
							end	
						end	
					else
						if ShowEffects then
							MakeImpactFX(Cast.UserData.SegmentDirection, RaycastResult.Instance, RaycastResult.Position, RaycastResult.Normal, RaycastResult.Material, true, Cast.UserData.Setting, Cast.UserData.Misc, Cast.UserData.Replicate)
						end
					end					
				end
			end
		end
	else
		if Cast.UserData.Setting.ExplosionSoundEnabled then
			local SoundTable = AddressTableValue(Cast.UserData.Misc.ChargeLevel, "ExplosionSoundIDs", Cast.UserData.Setting)
			local Attachment = Instance.new("Attachment")
			Attachment.CFrame = CFrame.new(EndPos)
			Attachment.Parent = Workspace.Terrain
			local Sound = Instance.new("Sound")
			Sound.SoundId = "rbxassetid://"..SoundTable[math.random(1, #SoundTable)]
			Sound.PlaybackSpeed = Random.new():NextNumber(AddressTableValue(Cast.UserData.Misc.ChargeLevel, "ExplosionSoundPitchMin", Cast.UserData.Setting), AddressTableValue(Cast.UserData.Misc.ChargeLevel, "ExplosionSoundPitchMax", Cast.UserData.Setting))
			Sound.Volume = AddressTableValue(Cast.UserData.Misc.ChargeLevel, "ExplosionSoundVolume", Cast.UserData.Setting)
			Sound.Parent = Attachment
			Sound:Play()
			Debris:AddItem(Attachment, 10)		
		end

		local Explosion = Instance.new("Explosion")
		Explosion.BlastRadius = AddressTableValue(Cast.UserData.Misc.ChargeLevel, "ExplosionRadius", Cast.UserData.Setting)
		Explosion.BlastPressure = 0
		Explosion.ExplosionType = Enum.ExplosionType.NoCraters
		Explosion.Position = EndPos
		Explosion.Parent = Camera

		local SurfaceCF = RaycastResult and CFrame.new(RaycastResult.Position, RaycastResult.Position + RaycastResult.Normal) or CFrame.new(Cast.UserData.SegmentOrigin, Cast.UserData.SegmentOrigin + Cast.UserData.SegmentDirection)

		if ShowEffects and RaycastResult then 
			if AddressTableValue(Cast.UserData.Misc.ChargeLevel, "ExplosionCraterEnabled", Cast.UserData.Setting) then
				if RaycastResult.Instance and RaycastResult.Instance.Parent then
					local Target = RaycastResult.Instance:FindFirstAncestorOfClass("Model")
					local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
					if not TargetHumanoid then
						local ParentToPart = true
						local Hole = Instance.new("Attachment")
						Hole.Parent = ParentToPart and RaycastResult.Instance or Workspace.Terrain
						Hole.WorldCFrame = SurfaceCF * CFrame.Angles(math.rad(90), math.rad(180), 0)
						if ParentToPart then
							local Scale = AddressTableValue(Cast.UserData.Misc.ChargeLevel, "ExplosionCraterSize", Cast.UserData.Setting)
							local Texture = AddressTableValue(Cast.UserData.Misc.ChargeLevel, "ExplosionCraterTexture", Cast.UserData.Setting)
							local A0 = Instance.new("Attachment")
							local A1 = Instance.new("Attachment")
							local BeamClone = Beam:Clone()
							BeamClone.Width0 = Scale
							BeamClone.Width1 = Scale
							BeamClone.Texture = "rbxassetid://"..Texture[math.random(1,#Texture)]
							if AddressTableValue(Cast.UserData.Misc.ChargeLevel, "ExplosionCraterPartColor", Cast.UserData.Setting) then
								local HitPartColor = RaycastResult.Instance and RaycastResult.Instance.Color or Color3.fromRGB(255, 255, 255)
								if RaycastResult.Instance and RaycastResult.Instance:IsA("Terrain") then
									HitPartColor = Workspace.Terrain:GetMaterialColor(RaycastResult.Material or Enum.Material.Sand)
								end
								BeamClone.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, HitPartColor), ColorSequenceKeypoint.new(1, HitPartColor)})
							end			
							BeamClone.Attachment0 = A0
							BeamClone.Attachment1 = A1
							A0.Parent = RaycastResult.Instance
							A1.Parent = RaycastResult.Instance
							A0.WorldCFrame = Hole.WorldCFrame * CFrame.new(Scale / 2, -0.01, 0) * CFrame.Angles(math.rad(90), 0, 0)
							A1.WorldCFrame = Hole.WorldCFrame * CFrame.new(-Scale / 2, -0.01, 0) * CFrame.Angles(math.rad(90), math.rad(180), 0)
							BeamClone.Parent = Workspace.Terrain
							local VisibleTime = AddressTableValue(Cast.UserData.Misc.ChargeLevel, "ExplosionCraterVisibleTime", Cast.UserData.Setting)
							local FadeTime = AddressTableValue(Cast.UserData.Misc.ChargeLevel, "ExplosionCraterFadeTime", Cast.UserData.Setting)
							Thread:Delay(VisibleTime, function()
								FadeBeam(A0, A1, BeamClone, Hole, FadeTime, Cast.UserData.Replicate)
							end)
						else
							Debris:AddItem(Hole, 5)
						end						
					end
				end
			end
		end

		local ExplosionEffectFolder = GunVisualEffects:FindFirstChild(AddressTableValue(Cast.UserData.Misc.ChargeLevel, "ExplosionEffect", Cast.UserData.Setting))
		if Cast.UserData.Setting.CustomExplosion and ExplosionEffectFolder then
			Explosion.Visible = false

			if ShowEffects then
				local Attachment = Instance.new("Attachment")
				Attachment.CFrame = SurfaceCF
				Attachment.Parent = Workspace.Terrain

				for i, v in pairs(ExplosionEffectFolder:GetChildren()) do
					if v.ClassName == "ParticleEmitter" then
						local Count = 1
						local Particle = v:Clone()
						Particle.Parent = Attachment
						if Particle:FindFirstChild("EmitCount") then
							Count = Particle.EmitCount.Value
						end
						Thread:Delay(0.01, function()
							Particle:Emit(GetEmitCount(Count))
							Debris:AddItem(Particle, Particle.Lifetime.Max)
						end)
					end
				end

				Debris:AddItem(Attachment, 10)
			end
		end	

		local HitHumanoids = {}

		Explosion.Hit:Connect(function(HitPart, HitDist)
			if HitPart and Cast.UserData.Replicate then
				if HitPart.Name == "_glass" and AddressTableValue(Cast.UserData.Misc.ChargeLevel, "CanBreakGlass", Cast.UserData.Setting) then
					ShatterGlass:FireServer(HitPart, HitPart.Position, Direction)
				else
					local Target = HitPart:FindFirstAncestorOfClass("Model")
					local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
					local TargetTorso = Target and (Target:FindFirstChild("HumanoidRootPart") or Target:FindFirstChild("Head"))
					if TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso then
						if not HitHumanoids[TargetHumanoid] then
							HitHumanoids[TargetHumanoid] = true
							local DamageThroughWall = AddressTableValue(Cast.UserData.Misc.ChargeLevel, "DamageThroughWall", Cast.UserData.Setting)
							local Hit = not DamageThroughWall and CastRay(Cast, Explosion.Position, (TargetTorso.CFrame.p - Explosion.Position).Unit * 999, Cast.UserData.IgnoreList, true, TargetHumanoid) or nil
							local CanHit = true
							if not DamageThroughWall then
								CanHit = (Hit and Hit:IsDescendantOf(Target))
							end
							if not CanHit then
								return
							end
							if AddressTableValue(Cast.UserData.Misc.ChargeLevel, "ExplosionKnockback", Cast.UserData.Setting) then
								if TargetHumanoid.Parent.Name == Player.Name then
									local Multipler = AddressTableValue(Cast.UserData.Misc.ChargeLevel, "ExplosionKnockbackMultiplierOnPlayer", Cast.UserData.Setting)
									local VelocityMod = (TargetTorso.Position - Explosion.Position).Unit * AddressTableValue(Cast.UserData.Misc.ChargeLevel, "ExplosionKnockbackPower", Cast.UserData.Setting)
									local AirVelocity = TargetTorso.Velocity - Vector3.new(0, TargetTorso.Velocity.Y, 0) + Vector3.new(VelocityMod.X, 0, VelocityMod.Z)
									local TorsoFly = Instance.new("BodyVelocity")
									TorsoFly.MaxForce = Vector3.new(math.huge, 0, math.huge)
									TorsoFly.Velocity = AirVelocity
									TorsoFly.Parent = TargetTorso
									TargetTorso.Velocity = TargetTorso.Velocity + Vector3.new(0, VelocityMod.Y * Multipler, 0)
									Debris:AddItem(TorsoFly, 0.25)		
								end
							end
							Thread:Spawn(function()
								local TempMisc = CloneTable(Cast.UserData.Misc)
								TempMisc["BulletId"] = Cast.UserData.BulletId	
								TempMisc["ExplosionPos"] = Explosion.Position
								TempMisc["ClientHitSize"] = HitPart.Size
								TempMisc["Distance"] = HitDist
								TempMisc["MousePosition"] = nil
								InflictTarget:FireServer("Gun", Cast.UserData.Tool, HitPart, CreatePacket(TempMisc))
							end)
							if Cast.UserData.Tool and Cast.UserData.Tool.GunClient:FindFirstChild("MarkerEvent") then
								local ShouldHeadshot = AddressTableValue(Cast.UserData.Misc.ChargeLevel, "HeadshotHitmarker", Cast.UserData.Setting)
								Cast.UserData.Tool.GunClient.MarkerEvent:Fire(Cast.UserData.Setting, HitPart.Name == "Head" and ShouldHeadshot)
							end	
						end
					end
				end
			end
		end)
	end
end

function OnRayHit(Cast, Origin, Direction, RaycastResult, SegmentVelocity, CosmeticBulletObject, Reflected)
	local CanBounce = Cast.UserData.CastBehavior.Hitscan and true or false
	local CurrentPosition = Cast:GetPosition()
	local CurrentVelocity = Cast:GetVelocity()
	local Acceleration = Cast.UserData.CastBehavior.Acceleration
	local Position = Cast.RayInfo.RaycastHitbox and Cast.UserData.BounceData.CurrentAnchorPoint or RaycastResult.Position
	if Cast.RayInfo.ShapeCast then
		local FinalPos = Cast.UserData.BounceData.CurrentAnchorPoint + SegmentVelocity.Unit * RaycastResult.Distance
		Position = FinalPos
	end
	if Reflected then
		if not Cast.UserData.CastBehavior.Hitscan then
			if CurrentVelocity.Magnitude > 0 then
				local CurrentDirection = SegmentVelocity.Unit
				local NewDirection = CurrentDirection - (2 * CurrentDirection:Dot(RaycastResult.Normal) * RaycastResult.Normal)
				Cast:SetVelocity(NewDirection * SegmentVelocity.Magnitude)
				Cast:SetPosition(Position)
				CanBounce = true
			end
		else
			local CurrentDirection = Cast.RayInfo.ModifiedDirection
			local NewDirection = CurrentDirection - (2 * CurrentDirection:Dot(RaycastResult.Normal) * RaycastResult.Normal)
			Cast.RayInfo.ModifiedDirection = NewDirection
		end
		if CanBounce then
			local ShowEffects = CanShowEffects(RaycastResult.Position)
			if ShowEffects then
				MakeImpactFX(Cast.UserData.SegmentDirection, RaycastResult.Instance, RaycastResult.Position, RaycastResult.Normal, RaycastResult.Material, true, Cast.UserData.Setting, Cast.UserData.Misc, Cast.UserData.Replicate, true)
			end
		end
	else
		if not Cast.UserData.CastBehavior.Hitscan then
			Cast.UserData.SpinData.InitalTick = os.clock()
			Cast.UserData.SpinData.InitalAngularVelocity = RaycastResult.Normal:Cross(CurrentVelocity) / 0.2
			Cast.UserData.SpinData.InitalRotation = (Cast.RayInfo.CurrentCFrame - Cast.RayInfo.CurrentCFrame.p)
			Cast.UserData.SpinData.ProjectileOffset = 0.2 * RaycastResult.Normal		
			if CurrentVelocity.Magnitude > 0 then
				local NormalizeBounce = false
				local Target = RaycastResult.Instance:FindFirstAncestorOfClass("Model")
				local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
				local TargetTorso = Target and (Target:FindFirstChild("HumanoidRootPart") or Target:FindFirstChild("Head"))
				if Cast.UserData.BounceData.BounceBetweenHumanoids then
					if TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso then
						if not table.find(Cast.UserData.BounceData.BouncedHumanoids, TargetHumanoid) then
							table.insert(Cast.UserData.BounceData.BouncedHumanoids, TargetHumanoid)
						end
					end
					local TrackedEntity, TrackedHumanoid, TrackedTorso = FindNearestEntity(Cast, Position)
					if TrackedEntity and TrackedHumanoid and TrackedTorso and TrackedHumanoid.Health > 0 then
						local DesiredVector = (TrackedTorso.Position - Position).Unit
						if Cast.UserData.BounceData.PredictDirection then
							local Pos, Vel = DirectionPredictor(Position, TrackedTorso.Position, Vector3.new(), TrackedTorso.Velocity, Acceleration, (2 * TrackedTorso.Velocity) / 3, SegmentVelocity.Magnitude)
							if Pos and Vel then
								DesiredVector = Vel.Unit
							end
						end
						Cast:SetVelocity(DesiredVector * SegmentVelocity.Magnitude)
						Cast:SetPosition(Position)
						if Cast.RayInfo.RaycastHitbox or Cast.RayInfo.ShapeCast then
							Cast.UserData.BounceData.LastBouncedObject = TargetHumanoid and TargetHumanoid.Parent or RaycastResult.Instance
							Cast.UserData.BounceData.BounceDeltaTime = 0						
						end
					else
						NormalizeBounce = true
					end
				else
					NormalizeBounce = true
				end
				if NormalizeBounce then
					local Delta = Position - CurrentPosition
					local Fix = 1 - 0.001 / Delta.Magnitude
					Fix = Fix < 0 and 0 or Fix
					Cast:AddPosition(Fix * Delta + 0.05 * RaycastResult.Normal)
					local NewNormal = RaycastResult.Normal
					local NewVelocity = CurrentVelocity
					if Cast.UserData.BounceData.IgnoreSlope and (Acceleration ~= Vector3.new(0, 0, 0) and Acceleration.Y < 0) then
						local NewPosition = Cast:GetPosition()
						NewVelocity = Vector3.new(CurrentVelocity.X, -Cast.UserData.BounceData.BounceHeight, CurrentVelocity.Z)
						local Instance2, Position2, Normal2, Material2 = CastRay(Cast, NewPosition, Vector3.new(0, 1, 0), Cast.UserData.IgnoreList, true)
						if Instance2 then
							NewVelocity = Vector3.new(CurrentVelocity.X, Cast.UserData.BounceData.BounceHeight, CurrentVelocity.Z)
						end
						local SlopeAngle = Math.GetSlopeAngle(RaycastResult.Normal)
						NewNormal = SlopeAngle >= Cast.UserData.BounceData.SlopeAngle and RaycastResult.Normal or Vector3.new(0, RaycastResult.Normal.Y, 0)
					end
					local NormalVelocity = Vector3.new().Dot(NewNormal, NewVelocity) * NewNormal
					local TanVelocity = NewVelocity - NormalVelocity
					local GeometricDeceleration
					local D1 = -Vector3.new().Dot(NewNormal, Acceleration)
					local D2 = -(1 + Cast.UserData.BounceData.BounceElasticity) * Vector3.new().Dot(NewNormal, NewVelocity)
					GeometricDeceleration = 1 - Cast.UserData.BounceData.FrictionConstant * (10 * (D1 < 0 and 0 or D1) * Cast.StateInfo.Delta + (D2 < 0 and 0 or D2)) / TanVelocity.Magnitude
					Cast:SetVelocity((GeometricDeceleration < 0 and 0 or GeometricDeceleration) * TanVelocity - Cast.UserData.BounceData.BounceElasticity * NormalVelocity)				
					if Cast.RayInfo.RaycastHitbox or Cast.RayInfo.ShapeCast then
						Cast.UserData.BounceData.LastBouncedObject = TargetHumanoid and TargetHumanoid.Parent or RaycastResult.Instance
						Cast.UserData.BounceData.BounceDeltaTime = 0					
					end	
				end
				CanBounce = true	
			end
		else
			local NormalizeBounce = false
			if Cast.UserData.BounceData.BounceBetweenHumanoids then
				local Target = RaycastResult.Instance:FindFirstAncestorOfClass("Model")
				local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
				local TargetTorso = Target and (Target:FindFirstChild("HumanoidRootPart") or Target:FindFirstChild("Head"))
				if TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso then
					if not table.find(Cast.UserData.BounceData.BouncedHumanoids, TargetHumanoid) then
						table.insert(Cast.UserData.BounceData.BouncedHumanoids, TargetHumanoid)
					end
				end
				local TrackedEntity, TrackedHumanoid, TrackedTorso = FindNearestEntity(Cast, RaycastResult.Position)
				if TrackedEntity and TrackedHumanoid and TrackedTorso and TrackedHumanoid.Health > 0 then
					local DesiredVector = (TrackedTorso.Position - RaycastResult.Position).Unit
					Cast.RayInfo.ModifiedDirection = DesiredVector
				else
					NormalizeBounce = true
				end
			else
				NormalizeBounce = true
			end
			if NormalizeBounce then			
				local CurrentDirection = Cast.RayInfo.ModifiedDirection
				local NewDirection = CurrentDirection - (2 * CurrentDirection:Dot(RaycastResult.Normal) * RaycastResult.Normal)
				Cast.RayInfo.ModifiedDirection = NewDirection
			end
		end
		if CanBounce then
			if Cast.UserData.BounceData.CurrentBounces > 0 then
				Cast.UserData.BounceData.CurrentBounces -= 1
				local ShowEffects = CanShowEffects(RaycastResult.Position)
				if Cast.UserData.BounceData.NoExplosionWhileBouncing then
					if RaycastResult.Instance.Name == "_glass" and AddressTableValue(Cast.UserData.Misc.ChargeLevel, "CanBreakGlass", Cast.UserData.Setting) then
						if Cast.UserData.Replicate then
							ShatterGlass:FireServer(RaycastResult.Instance, RaycastResult.Position, SegmentVelocity.Unit)
						end
					else
						if Cast.UserData.Setting.BlacklistParts[RaycastResult.Instance.Name] then
							if ShowEffects then
								MakeImpactFX(Cast.UserData.SegmentDirection, RaycastResult.Instance, RaycastResult.Position, RaycastResult.Normal, RaycastResult.Material, true, Cast.UserData.Setting, Cast.UserData.Misc, Cast.UserData.Replicate)
							end
						else
							local Target = RaycastResult.Instance:FindFirstAncestorOfClass("Model")
							local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
							local Distance = (RaycastResult.Position - Origin).Magnitude
							local TargetTorso = Target and (Target:FindFirstChild("HumanoidRootPart") or Target:FindFirstChild("Head"))
							if TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso then
								if ShowEffects then
									MakeBloodFX(Cast.UserData.SegmentDirection, RaycastResult.Instance, RaycastResult.Position, RaycastResult.Normal, RaycastResult.Material, true, Cast.UserData.Setting, Cast.UserData.Misc, Cast.UserData.Replicate, Target:FindFirstChild("IAmMetal"))
								end
								if Cast.UserData.Replicate then
									Thread:Spawn(function()
										local TempMisc = CloneTable(Cast.UserData.Misc)
										TempMisc["BulletId"] = Cast.UserData.BulletId
										TempMisc["ClientHitSize"] = RaycastResult.Instance.Size
										TempMisc["Distance"] = Distance
										TempMisc["MousePosition"] = nil
										InflictTarget:FireServer("Gun", Cast.UserData.Tool, RaycastResult.Instance, CreatePacket(TempMisc))
									end)
									if Cast.UserData.Tool and Cast.UserData.Tool.GunClient:FindFirstChild("MarkerEvent") then
										local ShouldHeadshot = AddressTableValue(Cast.UserData.Misc.ChargeLevel, "HeadshotHitmarker", Cast.UserData.Setting)
										Cast.UserData.Tool.GunClient.MarkerEvent:Fire(Cast.UserData.Setting, RaycastResult.Instance.Name == "Head" and ShouldHeadshot)
									end	
								end
							else
								if ShowEffects then
									MakeImpactFX(Cast.UserData.SegmentDirection, RaycastResult.Instance, RaycastResult.Position, RaycastResult.Normal, RaycastResult.Material, true, Cast.UserData.Setting, Cast.UserData.Misc, Cast.UserData.Replicate)
								end
							end						
						end
					end
				else
					OnRayFinalHit(Cast, Origin, Direction, RaycastResult, SegmentVelocity, CosmeticBulletObject)
				end
			end		
		end
	end
end

local function CanRayHit(Cast, Origin, Direction, RaycastResult, SegmentVelocity, CosmeticBulletObject)
	local Target = RaycastResult.Instance:FindFirstAncestorOfClass("Model")
	if Cast.UserData.Setting.BlacklistParts[RaycastResult.Instance.Name] then
		if Cast.UserData.BounceData.StopBouncingOn == "Object" then
			return false
		end
	else
		local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
		local TargetTorso = Target and (Target:FindFirstChild("HumanoidRootPart") or Target:FindFirstChild("Head"))
		if TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso then
			if Cast.UserData.BounceData.StopBouncingOn == "Humanoid" then
				return false
			end
		else
			if Cast.UserData.BounceData.StopBouncingOn == "Object" then
				return false
			end
		end		
	end
	local CanBlock = Target and Target:FindFirstChild("CanBlock")
	if AddressTableValue(Cast.UserData.Misc.ChargeLevel, "BlockBullet", Cast.UserData.Setting) and CanBlock then
		if AddressTableValue(Cast.UserData.Misc.ChargeLevel, "ReflectBullet", Cast.UserData.Setting) and CanBlock:FindFirstChild("CanReflect") then
			Cast.UserData.LastReflectingModel = Target
			return "Reflected"
		else
			return "Blocked"
		end
	else
		local Density = RaycastResult.Instance:GetMass() / (RaycastResult.Instance.Size.X * RaycastResult.Instance.Size.Y * RaycastResult.Instance.Size.Z)
		local Dot = RaycastResult.Normal:Dot(SegmentVelocity.Unit)
		Dot = Dot * (Cast.UserData.BounceData.UsePartDensity and (10 / Density) or 1) * (Cast.UserData.BounceData.UseBulletSpeed and (SegmentVelocity.Magnitude / 2400) or 1)
		if not Cast.UserData.CastBehavior.Hitscan and Cast.UserData.BounceData.SuperBounce then
			return true
		else
			if (math.abs(Dot) <= math.cos(math.rad(math.clamp(Cast.UserData.BounceData.MaxBounceAngle, 0, 90)))) and Cast.UserData.BounceData.CurrentBounces > 0 then
				return true
			end		
		end
	end
	return false
end

function OnRayExited(Cast, Origin, Direction, RaycastResult, SegmentVelocity, CosmeticBulletObject)
	if not RayExit then
		return
	end
	if Cast.UserData.PenetrationData then
		if Cast.UserData.Setting.PenetrationType == "WallPenetration" then
			local ShowEffects = CanShowEffects(RaycastResult.Position)
			if RaycastResult.Instance and RaycastResult.Instance.Parent then
				if Cast.UserData.Setting.BlacklistParts[RaycastResult.Instance.Name] then
					if ShowEffects then
						MakeImpactFX(Cast.UserData.SegmentDirection, RaycastResult.Instance, RaycastResult.Position, RaycastResult.Normal, RaycastResult.Material, true, Cast.UserData.Setting, Cast.UserData.Misc, Cast.UserData.Replicate)
					end
				else
					local Target = RaycastResult.Instance:FindFirstAncestorOfClass("Model")
					local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
					local TargetTorso = Target and (Target:FindFirstChild("HumanoidRootPart") or Target:FindFirstChild("Head"))
					if TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso then
						if ShowEffects then
							MakeBloodFX(Cast.UserData.SegmentDirection, RaycastResult.Instance, RaycastResult.Position, RaycastResult.Normal, RaycastResult.Material, true, Cast.UserData.Setting, Cast.UserData.Misc, Cast.UserData.Replicate, Target:FindFirstChild("IAmMetal"))
						end	
					else
						if ShowEffects then
							MakeImpactFX(Cast.UserData.SegmentDirection, RaycastResult.Instance, RaycastResult.Position, RaycastResult.Normal, RaycastResult.Material, true, Cast.UserData.Setting, Cast.UserData.Misc, Cast.UserData.Replicate)
						end
					end						
				end
			end		
		end		
	end
	if RaycastResult.Instance and RaycastResult.Instance.Parent then
		local vis = Cast:DbgVisualizeHit(CFrame.new(RaycastResult.Position), true)
		if (vis ~= nil) then vis.Color3 = Color3.fromRGB(13, 105, 172) end		
	end
end

local function CanRayPenetrate(Cast, Origin, Direction, RaycastResult, SegmentVelocity, CosmeticBulletObject)
	local ShowEffects = CanShowEffects(RaycastResult.Position)
	if RaycastResult.Instance and RaycastResult.Instance.Parent then
		if Cast.UserData.Setting.IgnoreBlacklistedParts and Cast.UserData.Setting.BlacklistParts[RaycastResult.Instance.Name] then
			return true
		else
			local TEAM = Cast.UserData.Character:FindFirstChild("TEAM")
			local Target = RaycastResult.Instance:FindFirstAncestorOfClass("Model")
			local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
			local CanBlock = Target and Target:FindFirstChild("CanBlock")
			local TargetTool = RaycastResult.Instance:FindFirstAncestorOfClass("Tool")
			if (--[[not RaycastResult.Instance.CanCollide
				or]] RaycastResult.Instance.Transparency > 0.75
				or RaycastResult.Instance.Name == "Handle"
				or (TargetHumanoid and (TargetHumanoid.Health <= 0 or not DamageModule.CanDamage(Target, Cast.UserData.Character, Cast.UserData.Setting.FriendlyFire) or (Cast.UserData.PenetrationData and table.find(Cast.UserData.PenetrationData.HitHumanoids, TargetHumanoid)) or (Cast.UserData.BounceData and table.find(Cast.UserData.BounceData.BouncedHumanoids, TargetHumanoid))))
				or (CanBlock and ((TEAM and CanBlock:FindFirstChild("TEAM")) and CanBlock.TEAM.Value == TEAM.Value))
				or TargetTool) then
				return true
			else
				if Cast.UserData.LastReflectingModel and Cast.UserData.LastReflectingModel == Target then
					return true
				end	
				if Cast.UserData.PenetrationData then
					local Density = RaycastResult.Instance:GetMass() / (RaycastResult.Instance.Size.X * RaycastResult.Instance.Size.Y * RaycastResult.Instance.Size.Z)
					local Dot = RaycastResult.Normal:Dot(SegmentVelocity.Unit)
					Dot = Dot * (Cast.UserData.BounceData.UsePartDensity and (10 / Density) or 1) * (Cast.UserData.BounceData.UseBulletSpeed and (SegmentVelocity.Magnitude / 2400) or 1)
					if (math.abs(Dot) <= math.cos(math.rad(math.clamp(Cast.UserData.BounceData.MaxBounceAngle, 0, 90)))) and Cast.UserData.BounceData.CurrentBounces > 0 then
						return false
					end	
					local MaxExtent = RaycastResult.Instance.Size.Magnitude * Direction
					local ExitHit, ExitPoint, ExitNormal, ExitMaterial = Workspace:FindPartOnRayWithWhitelist(Ray.new(RaycastResult.Position + MaxExtent, -MaxExtent), {RaycastResult.Instance}, Cast.RayInfo.Parameters.IgnoreWater)
					local Diff = ExitPoint - RaycastResult.Position
					local Dist = Direction:Dot(Diff)
					if Cast.UserData.Setting.PenetrationType == "WallPenetration" then
						if Dist >= Cast.UserData.PenetrationData.PenetrationDepth then
							return false
						end
					elseif Cast.UserData.Setting.PenetrationType == "HumanoidPenetration" then
						if Cast.UserData.PenetrationData.PenetrationAmount <= 0 then
							return false
						end
					end
					local Modifier = Cast.UserData.PenetrationData.PenetrationModifiers[RaycastResult.Material.Name] ~= nil and math.max(0, Cast.UserData.PenetrationData.PenetrationModifiers[RaycastResult.Material.Name]) or 1
					if RaycastResult.Instance.Name == "_glass" and AddressTableValue(Cast.UserData.Misc.ChargeLevel, "CanBreakGlass", Cast.UserData.Setting) then
						if Cast.UserData.Replicate then
							ShatterGlass:FireServer(RaycastResult.Instance, RaycastResult.Position, SegmentVelocity.Unit)
						end
						if Cast.UserData.Setting.PenetrationType == "WallPenetration" then
							Cast.UserData.PenetrationData.PenetrationDepth -= (Dist * Modifier)
							return true
						end
					else
						if Cast.UserData.Setting.BlacklistParts[RaycastResult.Instance.Name] then
							if Cast.UserData.Setting.PenetrationType == "WallPenetration" then
								if ShowEffects then
									MakeImpactFX(Cast.UserData.SegmentDirection, RaycastResult.Instance, RaycastResult.Position, RaycastResult.Normal, RaycastResult.Material, true, Cast.UserData.Setting, Cast.UserData.Misc, Cast.UserData.Replicate)
								end
								Cast.UserData.PenetrationData.PenetrationDepth -= (Dist * Modifier)
								if ExitHit then
									OnRayExited(Cast, RaycastResult.Position + MaxExtent, -MaxExtent, {Instance = ExitHit, Position = ExitPoint, Normal = ExitNormal, Material = ExitMaterial}, SegmentVelocity, CosmeticBulletObject)
								end
								return true							
							end
						else
							local Distance = (RaycastResult.Position - Origin).Magnitude
							local TargetTorso = Target and (Target:FindFirstChild("HumanoidRootPart") or Target:FindFirstChild("Head"))
							if TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso then
								if not table.find( Cast.UserData.PenetrationData.HitHumanoids, TargetHumanoid) then
									table.insert(Cast.UserData.PenetrationData.HitHumanoids, TargetHumanoid)
									if ShowEffects then
										MakeBloodFX(Cast.UserData.SegmentDirection, RaycastResult.Instance, RaycastResult.Position, RaycastResult.Normal, RaycastResult.Material, true, Cast.UserData.Setting, Cast.UserData.Misc, Cast.UserData.Replicate, Target:FindFirstChild("IAmMetal"))
									end
									if Cast.UserData.Replicate then
										Thread:Spawn(function()
											local TempMisc = CloneTable(Cast.UserData.Misc)
											TempMisc["BulletId"] = Cast.UserData.BulletId
											TempMisc["ClientHitSize"] = RaycastResult.Instance.Size
											TempMisc["Distance"] = Distance
											TempMisc["MousePosition"] = nil
											InflictTarget:FireServer("Gun", Cast.UserData.Tool, RaycastResult.Instance, CreatePacket(TempMisc))
										end)
										if Cast.UserData.Tool and Cast.UserData.Tool.GunClient:FindFirstChild("MarkerEvent") then
											local ShouldHeadshot = AddressTableValue(Cast.UserData.Misc.ChargeLevel, "HeadshotHitmarker", Cast.UserData.Setting)
											Cast.UserData.Tool.GunClient.MarkerEvent:Fire(Cast.UserData.Setting, RaycastResult.Instance.Name == "Head" and ShouldHeadshot)
										end
									end
									if Cast.UserData.Setting.PenetrationType == "WallPenetration" then
										Cast.UserData.PenetrationData.PenetrationDepth -= (Dist * Modifier)
										if ExitHit then
											OnRayExited(Cast, RaycastResult.Position + MaxExtent, -MaxExtent, {Instance = ExitHit, Position = ExitPoint, Normal = ExitNormal, Material = ExitMaterial}, SegmentVelocity, CosmeticBulletObject)
										end
									elseif Cast.UserData.Setting.PenetrationType == "HumanoidPenetration" then
										Cast.UserData.PenetrationData.PenetrationAmount -= 1
									end
									if Cast.UserData.PenetrationData.PenetrationIgnoreDelay ~= math.huge then
										Thread:Delay(Cast.UserData.PenetrationData.PenetrationIgnoreDelay, function()
											local Index = table.find( Cast.UserData.PenetrationData.HitHumanoids, TargetHumanoid)
											if Index then
												table.remove(Cast.UserData.PenetrationData.HitHumanoids, Index)
											end	
										end)
									end
									return true
								end
							else
								if Cast.UserData.Setting.PenetrationType == "WallPenetration" then
									if ShowEffects then
										MakeImpactFX(Cast.UserData.SegmentDirection, RaycastResult.Instance, RaycastResult.Position, RaycastResult.Normal, RaycastResult.Material, true, Cast.UserData.Setting, Cast.UserData.Misc, Cast.UserData.Replicate)
									end
									Cast.UserData.PenetrationData.PenetrationDepth -= (Dist * Modifier)
									if ExitHit then
										OnRayExited(Cast, RaycastResult.Position + MaxExtent, -MaxExtent, {Instance = ExitHit, Position = ExitPoint, Normal = ExitNormal, Material = ExitMaterial}, SegmentVelocity, CosmeticBulletObject)
									end
									return true							
								end
							end								
						end	
					end		
				end
				if Cast.UserData.BounceData.LastBouncedObject and (Cast.UserData.BounceData.LastBouncedObject == (TargetHumanoid and TargetHumanoid.Parent or RaycastResult.Instance)) then
					return true
				end	
			end			
		end
	end
	return false
end

function UpdateParticle(Cast, Position, LastPosition, W2)
	if Cast.UserData.BulletParticleData.MotionBlur then
		local T2 = os.clock()
		local P2 = CFrame.new().pointToObjectSpace(Camera.CFrame, W2)
		local V2
		if Cast.UserData.BulletParticleData.T0 then
			V2 = 2 / (T2 - Cast.UserData.BulletParticleData.T1) * (P2 - Cast.UserData.BulletParticleData.P1) - (P2 - Cast.UserData.BulletParticleData.P0) / (T2 - Cast.UserData.BulletParticleData.T0)
		else
			V2 = (P2 - Cast.UserData.BulletParticleData.P1) / (T2 - Cast.UserData.BulletParticleData.T1)
			Cast.UserData.BulletParticleData.V1 = V2
		end
		Cast.UserData.BulletParticleData.T0, Cast.UserData.BulletParticleData.V0, Cast.UserData.BulletParticleData.P0 = Cast.UserData.BulletParticleData.T1, Cast.UserData.BulletParticleData.V1, Cast.UserData.BulletParticleData.P1
		Cast.UserData.BulletParticleData.T1, Cast.UserData.BulletParticleData.V1, Cast.UserData.BulletParticleData.P1 = T2, V2, P2
		local Dt = Cast.UserData.BulletParticleData.T1 - Cast.UserData.BulletParticleData.T0
		local M0 = Cast.UserData.BulletParticleData.V0.Magnitude
		local M1 = Cast.UserData.BulletParticleData.V1.Magnitude
		Cast.UserData.BulletParticleData.Attachment0.Position = Camera.CFrame * Cast.UserData.BulletParticleData.P0
		Cast.UserData.BulletParticleData.Attachment1.Position = Camera.CFrame * Cast.UserData.BulletParticleData.P1
		if M0 > 1.0E-8 then
			Cast.UserData.BulletParticleData.Attachment0.Axis = CFrame.new().vectorToWorldSpace(Camera.CFrame, Cast.UserData.BulletParticleData.V0 / M0)
		end
		if M1 > 1.0E-8 then
			Cast.UserData.BulletParticleData.Attachment1.Axis = CFrame.new().vectorToWorldSpace(Camera.CFrame, Cast.UserData.BulletParticleData.V1 / M1)
		end
		local Dist0 = -Cast.UserData.BulletParticleData.P0.Z
		local Dist1 = -Cast.UserData.BulletParticleData.P1.Z
		if Dist0 < 0 then
			Dist0 = 0
		end
		if Dist1 < 0 then
			Dist1 = 0
		end
		local W0 = Cast.UserData.BulletParticleData.BulletSize + Cast.UserData.BulletParticleData.BulletBloom * Dist0
		local W1 = Cast.UserData.BulletParticleData.BulletSize + Cast.UserData.BulletParticleData.BulletBloom * Dist1
		local L = ((Cast.UserData.BulletParticleData.P1 - Cast.UserData.BulletParticleData.P0) * Vector3.new(1, 1, 0)).Magnitude
		local Tr = 1 - 4 * Cast.UserData.BulletParticleData.BulletSize * Cast.UserData.BulletParticleData.BulletSize / ((W0 + W1) * (2 * L + W0 + W1)) * Cast.UserData.BulletParticleData.BulletBrightness
		for _, effect in next, Cast.UserData.BulletParticleData.Effects do
			effect.CurveSize0 = Dt / 3 * M0
			effect.CurveSize1 = Dt / 3 * M1
			effect.Width0 = W0
			effect.Width1 = W1
			effect.Transparency = NumberSequence.new(Tr)
		end
	else
		if (Position - LastPosition).Magnitude > 0 then
			local Rotation = CFrame.new(LastPosition, Position) - LastPosition
			local Offset = CFrame.Angles(0, math.pi / 2, 0)
			Cast.UserData.BulletParticleData.Attachment0.CFrame = CFrame.new(Position) * Rotation * Offset
			Cast.UserData.BulletParticleData.Attachment1.CFrame = CFrame.new(LastPosition, Position) * Offset
		end					
	end
end

function OnRayUpdated(Cast, LastSegmentOrigin, SegmentOrigin, SegmentDirection, Length, SegmentVelocity, CosmeticBulletObject)
	Cast.UserData.LastSegmentOrigin = LastSegmentOrigin
	Cast.UserData.SegmentOrigin = SegmentOrigin
	Cast.UserData.SegmentDirection = SegmentDirection
	Cast.UserData.SegmentVelocity = SegmentVelocity
	local Tick = os.clock() - Cast.UserData.SpinData.InitalTick
	if Cast.UserData.UpdateData.UpdateRayInExtra then
		local RayUpdater = Cast.UserData.UpdateData.ExtraRayUpdater
		if not RayUpdaters[RayUpdater] then
			if RayUpdateFolder:FindFirstChild(RayUpdater) then
				RayUpdaters[RayUpdater]	= require(RayUpdateFolder[RayUpdater])
			end
		end
		if RayUpdaters[RayUpdater] then
			RayUpdaters[RayUpdater](Cast, Cast.StateInfo.Delta)
		end
	end
	if not Cast.UserData.CastBehavior.Hitscan and Cast.UserData.HomeData.Homing then
		local CurrentPosition = Cast:GetPosition()
		local CurrentVelocity = Cast:GetVelocity()
		if Cast.UserData.HomeData.LockOnOnHovering then
			if Cast.UserData.HomeData.LockedEntity then
				local TargetHumanoid = Cast.UserData.HomeData.LockedEntity:FindFirstChildOfClass("Humanoid")
				if TargetHumanoid and TargetHumanoid.Health > 0 then
					local TargetTorso = Cast.UserData.HomeData.LockedEntity:FindFirstChild("HumanoidRootPart") or Cast.UserData.HomeData.LockedEntity:FindFirstChild("Torso") or Cast.UserData.HomeData.LockedEntity:FindFirstChild("UpperTorso")
					local DesiredVector = (TargetTorso.Position - CurrentPosition).Unit
					local CurrentVector = CurrentVelocity.Unit
					local AngularDifference = math.acos(DesiredVector:Dot(CurrentVector))
					if AngularDifference > 0 then
						local OrthoVector = CurrentVector:Cross(DesiredVector).Unit
						local AngularCorrection = math.min(AngularDifference, Cast.StateInfo.Delta * Cast.UserData.HomeData.TurnRatePerSecond)
						Cast:SetVelocity(CFrame.fromAxisAngle(OrthoVector, AngularCorrection):vectorToWorldSpace(CurrentVelocity))
					end
				end
			end
		else
			local TargetEntity, TargetHumanoid, TargetTorso = FindNearestEntity(Cast, CurrentPosition)
			if TargetEntity and TargetHumanoid and TargetTorso and TargetHumanoid.Health > 0 then
				local DesiredVector = (TargetTorso.Position - CurrentPosition).Unit
				local CurrentVector = CurrentVelocity.Unit
				local AngularDifference = math.acos(DesiredVector:Dot(CurrentVector))
				if AngularDifference > 0 then
					local OrthoVector = CurrentVector:Cross(DesiredVector).Unit
					local AngularCorrection = math.min(AngularDifference, Cast.StateInfo.Delta * Cast.UserData.HomeData.TurnRatePerSecond)
					Cast:SetVelocity(CFrame.fromAxisAngle(OrthoVector, AngularCorrection):vectorToWorldSpace(CurrentVelocity))
				end
			end
		end
	end
	if Cast.UserData.RealAccelerationData then
		local Accel = Cast.UserData.RealAccelerationData.Acceleration
		local RealAccel = Cast.UserData.RealAccelerationData.RealAcceleration
		local DeltaAccel = Vector3.new(Accel.X * RealAccel, Accel.Y * RealAccel, Accel.Z * RealAccel) * Cast.StateInfo.Delta
		Cast:AddVelocity(DeltaAccel)
		local CurrentSpeed = (Cast:GetVelocity() - DeltaAccel).Magnitude
		local FixVelocity = function(Max)
			if not Cast.UserData.RealAccelerationData.Clamped then
				Cast.UserData.RealAccelerationData.Clamped = true
				Cast:SetVelocity(ClampMagnitude(Cast:GetVelocity(), Max))
			end
		end
		if Cast.UserData.RealAccelerationData.InvertRealAcceleration then
			if CurrentSpeed > 0.00001 then
				Cast:SetVelocity(Cast:GetVelocity() * (1 - RealAccel * Cast.StateInfo.Delta))
			else
				FixVelocity(0.00001)
			end
		else
			if Cast.UserData.RealAccelerationData.StartSpeed < Cast.UserData.RealAccelerationData.TargetSpeed then
				if CurrentSpeed < Cast.UserData.RealAccelerationData.TargetSpeed then
					Cast:SetVelocity(Cast:GetVelocity() * (1 + RealAccel * Cast.StateInfo.Delta))
				else
					FixVelocity(Cast.UserData.RealAccelerationData.TargetSpeed)
				end
			elseif Cast.UserData.RealAccelerationData.StartSpeed > Cast.UserData.RealAccelerationData.TargetSpeed then
				if CurrentSpeed > Cast.UserData.RealAccelerationData.TargetSpeed then
					Cast:SetVelocity(Cast:GetVelocity() * (1 - RealAccel * Cast.StateInfo.Delta))
				else
					FixVelocity(Cast.UserData.RealAccelerationData.TargetSpeed)
				end
			end
		end
	end
	local TravelCFrame
	if Cast.UserData.SpinData.CanSpinPart then
		if not Cast.UserData.CastBehavior.Hitscan then
			local Position = (SegmentOrigin + Cast.UserData.SpinData.ProjectileOffset)
			if Cast.UserData.BounceData.SuperBounce then
				TravelCFrame = CFrame.new(Position, Position + SegmentVelocity) * Math.FromAxisAngle(Tick * Cast.UserData.SpinData.InitalAngularVelocity) * Cast.UserData.SpinData.InitalRotation
			else
				if Cast.UserData.BounceData.CurrentBounces > 0 then
					TravelCFrame = CFrame.new(Position, Position + SegmentVelocity) * Math.FromAxisAngle(Tick * Cast.UserData.SpinData.InitalAngularVelocity) * Cast.UserData.SpinData.InitalRotation
				else
					TravelCFrame = CFrame.new(SegmentOrigin, SegmentOrigin + SegmentVelocity) * CFrame.Angles(math.rad(-360 * ((os.clock() - Cast.UserData.ShootId / 4) * Cast.UserData.SpinData.SpinX - math.floor((os.clock() - Cast.UserData.ShootId / 4) * Cast.UserData.SpinData.SpinX))), math.rad(-360 * ((os.clock() - Cast.UserData.ShootId / 4) * Cast.UserData.SpinData.SpinY - math.floor((os.clock() - Cast.UserData.ShootId / 4) * Cast.UserData.SpinData.SpinY))), math.rad(-360 * ((os.clock() - Cast.UserData.ShootId / 4) * Cast.UserData.SpinData.SpinZ - math.floor((os.clock() - Cast.UserData.ShootId / 4) * Cast.UserData.SpinData.SpinZ))))
				end
			end
		else
			TravelCFrame = CFrame.new(SegmentOrigin, SegmentOrigin + SegmentVelocity) * CFrame.Angles(math.rad(-360 * ((os.clock() - Cast.UserData.ShootId / 4) * Cast.UserData.SpinData.SpinX - math.floor((os.clock() - Cast.UserData.ShootId / 4) * Cast.UserData.SpinData.SpinX))), math.rad(-360 * ((os.clock() - Cast.UserData.ShootId / 4) * Cast.UserData.SpinData.SpinY - math.floor((os.clock() - Cast.UserData.ShootId / 4) * Cast.UserData.SpinData.SpinY))), math.rad(-360 * ((os.clock() - Cast.UserData.ShootId / 4) * Cast.UserData.SpinData.SpinZ - math.floor((os.clock() - Cast.UserData.ShootId / 4) * Cast.UserData.SpinData.SpinZ))))
		end
	else
		TravelCFrame = CFrame.new(SegmentOrigin, SegmentOrigin + SegmentVelocity)
	end
	Cast.RayInfo.CurrentCFrame = TravelCFrame
	Cast.UserData.BounceData.CurrentAnchorPoint = (TravelCFrame * Cast.UserData.BounceData.AnchorPoint).p
	Cast.UserData.BounceData.BounceDeltaTime += Cast.StateInfo.Delta
	if Cast.UserData.BounceData.BounceDeltaTime > Cast.UserData.BounceData.BounceDelay then
		Cast.UserData.BounceData.LastBouncedObject = nil
	end
	if Cast.UserData.BulletParticleData then
		UpdateParticle(Cast, SegmentOrigin, Cast.UserData.LastPosition, SegmentOrigin)
	end
	if Cast.UserData.LaserData.LaserTrailEnabled then
		if Cast.StateInfo.Delta > 0 then
			local Width = Cast.UserData.LaserData.LaserTrailWidth
			local Height = Cast.UserData.LaserData.LaserTrailHeight
			local TrailSegment = Miscs[Cast.UserData.LaserData.LaserTrailShape.."Segment"]:Clone()
			if Cast.UserData.LaserData.RandomizeLaserColorIn ~= "None" then
				if Cast.UserData.LaserData.RandomizeLaserColorIn == "Whole" then
					TrailSegment.Color = Cast.UserData.LaserData.RandomLaserColor
				elseif Cast.UserData.LaserData.RandomizeLaserColorIn == "Segment" then
					TrailSegment.Color = Color3.new(math.random(), math.random(), math.random())
				end
			else
				TrailSegment.Color = Cast.UserData.LaserData.LaserTrailColor
			end
			TrailSegment.Material = Cast.UserData.LaserData.LaserTrailMaterial
			TrailSegment.Reflectance = Cast.UserData.LaserData.LaserTrailReflectance
			TrailSegment.Transparency = Cast.UserData.LaserData.LaserTrailTransparency
			TrailSegment.Size = Cast.UserData.LaserData.LaserTrailShape == "Cone" and Vector3.new(Width, (SegmentOrigin - LastSegmentOrigin).Magnitude, Height) or Vector3.new((SegmentOrigin - LastSegmentOrigin).Magnitude, Height, Width)
			TrailSegment.CFrame = CFrame.new((LastSegmentOrigin + SegmentOrigin) * 0.5, SegmentOrigin) * (Cast.UserData.LaserData.LaserTrailShape == "Cone" and CFrame.Angles(math.pi / 2, 0, 0) or CFrame.Angles(0, math.pi / 2, 0))
			TrailSegment.Parent = Camera
			table.insert(Cast.UserData.LaserData.LaserTrailContainer, TrailSegment)
			if Cast.UserData.LaserData.UpdateLaserTrail then
				Cast.UserData.LaserData.UpdateLaserTrail:Fire(Cast.UserData.LaserData.LaserTrailId, Cast.UserData.LaserData.LaserTrailContainer)
			end
			Thread:Delay(Cast.UserData.LaserData.LaserTrailVisibleTime, function()
				if Cast.UserData.LaserData.LaserTrailFadeTime > 0 then
					local DesiredSize = TrailSegment.Size * (Cast.UserData.LaserData.ScaleLaserTrail and Vector3.new(1, Cast.UserData.LaserData.LaserTrailScaleMultiplier, Cast.UserData.LaserData.LaserTrailScaleMultiplier) or Vector3.new(1, 1, 1))
					local Tween = TweenService:Create(TrailSegment, TweenInfo.new(Cast.UserData.LaserData.LaserTrailFadeTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Transparency = 1, Size = DesiredSize})
					Tween:Play()
					Tween.Completed:Wait()
					if TrailSegment then
						local Index = table.find(Cast.UserData.LaserData.LaserTrailContainer, TrailSegment)
						if Index then
							table.remove(Cast.UserData.LaserData.LaserTrailContainer, Index)
							if Cast.UserData.LaserData.UpdateLaserTrail then
								Cast.UserData.LaserData.UpdateLaserTrail:Fire(Cast.UserData.LaserData.LaserTrailId, Cast.UserData.LaserData.LaserTrailContainer)
							end
						end
						TrailSegment:Destroy()
					end
				else
					if TrailSegment then
						local Index = table.find(Cast.UserData.LaserData.LaserTrailContainer, TrailSegment)
						if Index then
							table.remove(Cast.UserData.LaserData.LaserTrailContainer, Index)
							if Cast.UserData.LaserData.UpdateLaserTrail then
								Cast.UserData.LaserData.UpdateLaserTrail:Fire(Cast.UserData.LaserData.LaserTrailId, Cast.UserData.LaserData.LaserTrailContainer)
							end
						end
						TrailSegment:Destroy()
					end
				end
			end)			
		end
	end
	if Cast.UserData.LightningData.LightningBoltEnabled then
		if Cast.StateInfo.Delta > 0 then
			local Wideness = Cast.UserData.LightningData.BoltWideness
			local Width = Cast.UserData.LightningData.BoltWidth
			local Height = Cast.UserData.LightningData.BoltHeight
			for _, v in ipairs(Cast.UserData.LightningData.BoltCFrameTable) do
				local Cache
				if Cast.UserData.LightningData.BoltShape == "Block" then
					Cache = BlockSegCache
				elseif Cast.UserData.LightningData.BoltShape == "Cylinder" then
					Cache = CylinderSegCache
				elseif Cast.UserData.LightningData.BoltShape == "Cone" then
					Cache = ConeSegCache
				end
				if Cache then
					local Start = (CFrame.new(SegmentOrigin, SegmentOrigin + SegmentDirection) * v).p
					local End = (CFrame.new(LastSegmentOrigin, LastSegmentOrigin + SegmentDirection) * v).p
					local Distance = (End - Start).Magnitude
					local Pos = Start
					for i = 0, Distance, 10 do
						local FakeDistance = CFrame.new(Start, End) * CFrame.new(0, 0, -i - 10) * CFrame.new(-2 + (math.random() * Wideness), -2 + (math.random() * Wideness), -2 + (math.random() * Wideness))
						local BoltSegment = Cache:GetPart()
						BoltSegment.CastShadow = false
						BoltSegment.CanQuery = false
						BoltSegment.CanTouch = false
						if Cast.UserData.LightningData.RandomizeBoltColorIn ~= "None" then
							if Cast.UserData.LightningData.RandomizeBoltColorIn == "Whole" then
								BoltSegment.Color = Cast.UserData.LightningData.RandomBoltColor
							elseif Cast.UserData.LightningData.RandomizeBoltColorIn == "Segment" then
								BoltSegment.Color = Color3.new(math.random(), math.random(), math.random())
							end
						else
							BoltSegment.Color = Cast.UserData.LightningData.BoltColor
						end
						BoltSegment.Material = Cast.UserData.LightningData.BoltMaterial
						BoltSegment.Reflectance = Cast.UserData.LightningData.BoltReflectance
						BoltSegment.Transparency = Cast.UserData.LightningData.BoltTransparency						
						if i + 10 > Distance then
							BoltSegment.CFrame = CFrame.new(Pos, End) * CFrame.new(0, 0, -(Pos - End).Magnitude / 2) * (Cast.UserData.LightningData.BoltShape == "Cone" and CFrame.Angles(math.pi / 2, 0, 0) or CFrame.Angles(0, math.pi / 2, 0))
						else
							BoltSegment.CFrame = CFrame.new(Pos, FakeDistance.p) * CFrame.new(0, 0, -(Pos - FakeDistance.p).Magnitude / 2) * (Cast.UserData.LightningData.BoltShape == "Cone" and CFrame.Angles(math.pi / 2, 0, 0) or CFrame.Angles(0, math.pi / 2, 0))
						end
						if i + 10 > Distance then
							BoltSegment.Size = Cast.UserData.LightningData.BoltShape == "Cone" and Vector3.new(Width, (Pos - End).Magnitude, Height) or Vector3.new((Pos - End).Magnitude, Height, Width)
						else
							BoltSegment.Size = Cast.UserData.LightningData.BoltShape == "Cone" and Vector3.new(Width, (Pos - FakeDistance.p).Magnitude, Height) or Vector3.new((Pos - FakeDistance.p).Magnitude, Height, Width)
						end
						Thread:Delay(Cast.UserData.LightningData.BoltVisibleTime, function()
							if Cast.UserData.LightningData.BoltFadeTime > 0 then
								local DesiredSize = BoltSegment.Size * (Cast.UserData.LightningData.ScaleBolt and Vector3.new(1, Cast.UserData.LightningData.BoltScaleMultiplier, Cast.UserData.LightningData.BoltScaleMultiplier) or Vector3.new(1, 1, 1))
								local Tween = TweenService:Create(BoltSegment, TweenInfo.new(Cast.UserData.LightningData.BoltFadeTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Transparency = 1, Size = DesiredSize})
								Tween:Play()
								Tween.Completed:Wait()
								if BoltSegment ~= nil then
									Cache:ReturnPart(BoltSegment)
								end
							else
								if BoltSegment ~= nil then
									Cache:ReturnPart(BoltSegment)
								end								
							end
						end)
						Pos = FakeDistance.p
					end					
				end
			end
		end
	end
	if not Cast.UserData.Replicate and Cast.UserData.WhizData.WhizSoundEnabled then
		local Mag = (Camera.CFrame.p - SegmentOrigin).Magnitude --(Camera.CFrame.p - CosmeticBulletObject.Position).Magnitude		
		if Mag < Cast.UserData.WhizData.WhizDistance and not Cast.UserData.WhizData.Whizzed then
			local WhizSound = Instance.new("Sound")
			WhizSound.SoundId = "rbxassetid://"..Cast.UserData.WhizData.WhizSoundIDs[math.random(1, #Cast.UserData.WhizData.WhizSoundIDs)]
			WhizSound.Volume = Cast.UserData.WhizData.WhizSoundVolume
			WhizSound.PlaybackSpeed = Random.new():NextNumber(Cast.UserData.WhizData.WhizSoundPitchMin, Cast.UserData.WhizData.WhizSoundPitchMax)
			WhizSound.Name = "WhizSound"
			WhizSound.Parent = SoundService
			WhizSound:Play()
			Debris:AddItem(WhizSound, WhizSound.TimeLength / WhizSound.PlaybackSpeed)
			Cast.UserData.WhizData.Whizzed = true
		end
	end
	Cast.UserData.LastPosition = SegmentOrigin
	if CosmeticBulletObject == nil then
		return
	end
	CosmeticBulletObject.CFrame = TravelCFrame
end

function OnRayTerminated(Cast, RaycastResult, IsDecayed)
	if Cast.UserData.LaserData.UpdateLaserTrail then
		Cast.UserData.LaserData.UpdateLaserTrail:Fire(Cast.UserData.LaserData.LaserTrailId, Cast.UserData.LaserData.LaserTrailContainer, true)
	end
	if Cast.UserData.BulletParticleData then
		Cast.UserData.BulletParticleData.Attachment0:Destroy()
		Cast.UserData.BulletParticleData.Attachment1:Destroy()
		for _, effect in next, Cast.UserData.BulletParticleData.Effects do
			effect:Destroy()
		end
	end
	local CosmeticBulletObject = Cast.RayInfo.CosmeticBulletObject
	if CosmeticBulletObject ~= nil then	
		local CurrentPosition = Cast:GetPosition()
		local CurrentVelocity = Cast:GetVelocity()
		local EndPos = RaycastResult and RaycastResult.Position or CurrentPosition
		local ShowEffects = CanShowEffects(EndPos)
		if IsDecayed then
			if Cast.UserData.DebrisData.DecayProjectile and DebrisCounts <= MaxDebrisCounts and ShowEffects then
				DebrisCounts += 1
				local DecayProjectile = CosmeticBulletObject:Clone()
				DecayProjectile.Name = "DecayProjectile"
				DecayProjectile.CFrame = CosmeticBulletObject.CFrame
				DecayProjectile.Anchored = Cast.UserData.DebrisData.AnchorDecay
				DecayProjectile.CanCollide = Cast.UserData.DebrisData.CollideDecay
				if not DecayProjectile.Anchored then
					if Cast.UserData.DebrisData.VelocityInfluence then
						DecayProjectile.Velocity = DecayProjectile.CFrame.LookVector * CurrentVelocity.Magnitude
					else
						DecayProjectile.Velocity = DecayProjectile.CFrame.LookVector * Cast.UserData.DebrisData.DecayVelocity
					end
				end
				for _, v in pairs(DecayProjectile:GetDescendants()) do
					if ((v:IsA("PointLight") or v:IsA("SurfaceLight") or v:IsA("SpotLight")) and Cast.UserData.DebrisData.DisableDebrisContents.DisableTrail) then
						v.Enabled = false
					elseif (v:IsA("ParticleEmitter") and Cast.UserData.DebrisData.DisableDebrisContents.Particle) then
						v.Enabled = false
					elseif (v:IsA("Trail") and Cast.UserData.DebrisData.DisableDebrisContents.Trail) then
						v.Enabled = false
					elseif (v:IsA("Beam") and Cast.UserData.DebrisData.DisableDebrisContents.Beam) then
						v.Enabled = false
					elseif (v:IsA("Sound") and Cast.UserData.DebrisData.DisableDebrisContents.Sound) then
						v:Stop()
					end
				end
				DecayProjectile.Parent = Camera
				Thread:Delay(5, function() --10
					if DecayProjectile then
						DecayProjectile:Destroy()
					end
					DebrisCounts -= 1
				end)
			end
		else
			if RaycastResult then
				local HitPointObjectSpace = RaycastResult.Instance.CFrame:pointToObjectSpace(RaycastResult.Position)
				if Cast.UserData.DebrisData.DebrisProjectile and DebrisCounts <= MaxDebrisCounts and ShowEffects then
					DebrisCounts += 1
					local DebrisProjectile = CosmeticBulletObject:Clone()
					DebrisProjectile.Name = "DebrisProjectile"
					DebrisProjectile.CFrame = Cast.UserData.DebrisData.NormalizeDebris and CFrame.new(RaycastResult.Position, RaycastResult.Position + RaycastResult.Normal) or (RaycastResult.Instance.CFrame * CFrame.new(HitPointObjectSpace, HitPointObjectSpace + RaycastResult.Instance.CFrame:vectorToObjectSpace(Cast.UserData.SegmentVelocity.Unit))) --CosmeticBulletObject.CFrame
					DebrisProjectile.Anchored = Cast.UserData.DebrisData.AnchorDebris
					DebrisProjectile.CanCollide = Cast.UserData.DebrisData.CollideDebris
					if not DebrisProjectile.Anchored and Cast.UserData.DebrisData.BounceDebris then
						local Direction = DebrisProjectile.CFrame.LookVector
						local Reflect = Direction - (2 * Direction:Dot(RaycastResult.Normal) * RaycastResult.Normal)
						DebrisProjectile.Velocity = Reflect * (Cast.UserData.DebrisData.BounceVelocity * (CurrentVelocity.Magnitude / AddressTableValue(Cast.UserData.Misc.ChargeLevel, "BulletSpeed", Cast.UserData.Setting)))
						DebrisProjectile.CFrame = CFrame.new(DebrisProjectile.Position, DebrisProjectile.Position + DebrisProjectile.Velocity)	
					end
					for _, v in pairs(DebrisProjectile:GetDescendants()) do
						if ((v:IsA("PointLight") or v:IsA("SurfaceLight") or v:IsA("SpotLight")) and Cast.UserData.DebrisData.DisableDebrisContents.DisableTrail) then
							v.Enabled = false
						elseif (v:IsA("ParticleEmitter") and Cast.UserData.DebrisData.DisableDebrisContents.Particle) then
							v.Enabled = false
						elseif (v:IsA("Trail") and Cast.UserData.DebrisData.DisableDebrisContents.Trail) then
							v.Enabled = false
						elseif (v:IsA("Beam") and Cast.UserData.DebrisData.DisableDebrisContents.Beam) then
							v.Enabled = false
						elseif (v:IsA("Sound") and Cast.UserData.DebrisData.DisableDebrisContents.Sound) then
							v:Stop()
						end
					end
					DebrisProjectile.Parent = Camera
					if Cast.UserData.DebrisData.WeldDebris then
						local weld = Instance.new("WeldConstraint")
						weld.Parent = DebrisProjectile
						weld.Part0 = DebrisProjectile
						weld.Part1 = RaycastResult.Instance
					end
					Thread:Delay(5, function() --10
						if DebrisProjectile then
							DebrisProjectile:Destroy()
						end
						DebrisCounts -= 1
					end)
				end
			end
		end
		CosmeticBulletObject.Transparency = 1
		for _, v in pairs(CosmeticBulletObject:GetDescendants()) do
			if v:IsA("ParticleEmitter") or v:IsA("PointLight") or v:IsA("SurfaceLight") or v:IsA("SpotLight") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("BillboardGui") or v:IsA("SurfaceGui") then
				v.Enabled = false
			elseif v:IsA("Sound") then
				v:Stop()
			elseif v:IsA("Decal") or v:IsA("Texture") or v:IsA("BasePart") then
				v.Transparency = 1
			end
		end
		if Cast.UserData.CastBehavior.CosmeticBulletProvider ~= nil then
			--Thread:Delay(5, function() -- 10
			if CosmeticBulletObject ~= nil then
				Cast.UserData.CastBehavior.CosmeticBulletProvider:ReturnPart(CosmeticBulletObject)
			end
			--end)
		else
			Debris:AddItem(CosmeticBulletObject, 5) -- 10
		end
	end
end

function ProjectileHandler:VisualizeHitEffect(Type, Hit, Position, Normal, Material, Misc, Replicate)
	local Module
	if Replicate then 
		VisualizeHitEffect:FireServer(Type, Hit, Position, Normal, Material, CreatePacket(CloneTable(Misc)))
		if Misc.Tool == nil then
			return
		end
		Module = GetSetting(Misc.Tool, {ModuleName = Misc.ModuleName}, nil, nil)
	else
		Misc = DecodePacket(Misc)
		if Misc.NPCData then
			Module = GetSetting(nil, nil, nil, Misc.NPCData)
		else
			if Misc.Tool == nil then
				return
			end
			Module = GetSetting(Misc.Tool, {ModuleName = Misc.ModuleName}, nil, nil)
		end
	end
	local ShowEffects = CanShowEffects(Position)
	if ShowEffects then
		if Type == "Normal" then
			MakeImpactFX(Misc.Direction, Hit, Position, Normal, Material, true, Module, Misc, Replicate, Misc.Blocked, true)
		elseif Type == "Blood" then
			local Target = Hit:FindFirstAncestorOfClass("Model")
			MakeBloodFX(Misc.Direction, Hit, Position, Normal, Material, true, Module, Misc, Replicate, Target:FindFirstChild("IAmMetal"), true)
		end
	end
end

function ProjectileHandler:SimulateProjectile(Tool, Handle, Directions, FirePointObject, MuzzlePointObject, Misc, Replicate)
	if Tool and Handle then
		if FirePointObject then
			if not FirePointObject:IsDescendantOf(Workspace) and not FirePointObject:IsDescendantOf(Tool) then
				return
			end
		else
			return
		end

		local Module

		if Replicate then
			VisualizeBullet:FireServer(Tool, Handle, CreatePacket(CloneTable(Directions)), FirePointObject, MuzzlePointObject, CreatePacket(CloneTable(Misc)))
			Module = GetSetting(Tool, {ModuleName = Misc.ModuleName, ModNames = Misc.ModNames}, nil, nil)
		else
			Directions = DecodePacket(Directions)
			Misc = DecodePacket(Misc)
			if Misc.NPCData then
				Module = GetSetting(nil, nil, nil, Misc.NPCData)
			else
				Module = GetSetting(Tool, {ModuleName = Misc.ModuleName, ModNames = Misc.ModNames}, nil, nil)
			end
		end

		local CanEmit = true
		if Module.LockOnScan and Module.InstaBurst then
			CanEmit = Misc.FirstShot
		end
		if MuzzlePointObject and CanEmit then
			local MuzzleFolder = GunVisualEffects:FindFirstChild(AddressTableValue(Misc.ChargeLevel, "MuzzleEffect", Module))
			if Module.MuzzleFlashEnabled and MuzzleFolder then		
				for i, v in pairs(MuzzleFolder:GetChildren()) do
					if v.ClassName == "ParticleEmitter" then
						local Count = 1
						local Particle = v:Clone()
						Particle.Parent = MuzzlePointObject
						if Particle:FindFirstChild("EmitCount") then
							Count = Particle.EmitCount.Value
						end
						Thread:Delay(0.01, function()
							Particle:Emit(Count)
							Debris:AddItem(Particle, Particle.Lifetime.Max)
						end)
					end
				end	
			end

			if Module.MuzzleLightEnabled then
				local Light = Instance.new("PointLight")
				Light.Brightness = AddressTableValue(Misc.ChargeLevel, "LightBrightness", Module)
				Light.Color = AddressTableValue(Misc.ChargeLevel, "LightColor", Module)
				Light.Range = AddressTableValue(Misc.ChargeLevel, "LightRange", Module)
				Light.Shadows = Module.LightShadows
				Light.Enabled = true
				Light.Parent = MuzzlePointObject
				Debris:AddItem(Light, Module.VisibleTime)
			end			
		end

		if AddressTableValue(Misc.ChargeLevel, "ShootType", Module) == "Custom" then
			return
		end

		local Character = Tool.Parent
		local IgnoreList = CloneTable(IgnoreList)
		table.insert(IgnoreList, Tool)
		table.insert(IgnoreList, Character)
		local CastParams = RaycastParams.new()
		CastParams.IgnoreWater = true
		CastParams.FilterType = Enum.RaycastFilterType.Blacklist
		CastParams.FilterDescendantsInstances = IgnoreList
		local RegionParams = OverlapParams.new()
		RegionParams.FilterType = Enum.RaycastFilterType.Blacklist
		RegionParams.FilterDescendantsInstances = IgnoreList
		RegionParams.MaxParts = 0
		RegionParams.CollisionGroup = "Default"

		ShootId += 1

		local LaserTrails = {}
		local UpdateLaserTrail
		local LaserTrailEnabled = AddressTableValue(Misc.ChargeLevel, "LaserTrailEnabled", Module)		
		local DamageableLaserTrail = AddressTableValue(Misc.ChargeLevel, "DamageableLaserTrail", Module)
		if Replicate then
			if LaserTrailEnabled and DamageableLaserTrail then
				UpdateLaserTrail = Instance.new("BindableEvent")
				UpdateLaserTrail.Name = "UpdateLaserTrail_"..HttpService:GenerateGUID()
			end
		end

		for _, Direction in pairs(Directions) do
			if FirePointObject then
				if not FirePointObject:IsDescendantOf(Workspace) and not FirePointObject:IsDescendantOf(Tool) then
					return
				end
			else
				return
			end 

			local Origin, Dir = FirePointObject.WorldPosition, Direction[1]

			local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart", 1)
			local TipCFrame = FirePointObject.WorldCFrame
			local TipPos = TipCFrame.Position
			local TipDir = TipCFrame.LookVector
			local AmountToCheatBack = math.abs((HumanoidRootPart.Position - TipPos):Dot(TipDir)) + 1
			local GunRay = Ray.new(TipPos - TipDir.Unit * AmountToCheatBack, TipDir.Unit * AmountToCheatBack)
			local HitPart, HitPoint = Workspace:FindPartOnRayWithIgnoreList(GunRay, IgnoreList, false, true)
			if HitPart and math.abs((TipPos - HitPoint).Magnitude) > 0 then
				Origin = HitPoint - TipDir.Unit * 0.1
				--Dir = TipDir.Unit
			end

			local Module2

			if Misc.NPCData then
				local TempMisc = CloneTable(Misc)
				if TempMisc.NPCData.ModData then
					TempMisc.NPCData.ModData["BulletId"] = Direction[2]
				end
				Module2 = GetSetting(nil, nil, nil, TempMisc.NPCData)
			else
				Module2 = GetSetting(Tool, {ModuleName = Misc.ModuleName, ModNames = Misc.ModNames, BulletId = Direction[2]}, nil, nil)
			end

			local BulletSpeed = math.max(0.00001, AddressTableValue(Misc.ChargeLevel, "BulletSpeed", Module2))
			local Acceleration = AddressTableValue(Misc.ChargeLevel, "Acceleration", Module2)
			local RealAcceleration = AddressTableValue(Misc.ChargeLevel, "RealAcceleration", Module2)
			local InvertRealAcceleration = AddressTableValue(Misc.ChargeLevel, "InvertRealAcceleration", Module2)
			local RealAccelerationData
			if RealAcceleration > 0 then
				if not InvertRealAcceleration then
					BulletSpeed = math.max(0.00001, AddressTableValue(Misc.ChargeLevel, "InitialBulletSpeed", Module2))
				end
				RealAccelerationData = {
					Acceleration = Acceleration,
					RealAcceleration = RealAcceleration,
					InvertRealAcceleration = InvertRealAcceleration,
					StartSpeed = BulletSpeed,
					TargetSpeed = math.max(0.00001, AddressTableValue(Misc.ChargeLevel, "BulletSpeed", Module2)),
					Clamped = false
				}
			end
			local Velocity = Dir * BulletSpeed

			local CosmeticPartProvider
			local ProjectileContainer
			local ProjectileType = AddressTableValue(Misc.ChargeLevel, "ProjectileType", Module2)
			if ProjectileType ~= "None" then
				local Projectile = Projectiles:FindFirstChild(ProjectileType)
				if Projectile then
					local Exist2 = false
					for _, v in pairs(PartCacheStorage) do
						if v.ProjectileName == Projectile.Name then
							Exist2 = true
							ProjectileContainer = Camera:FindFirstChild("ProjectileContainer_("..Projectile.Name..")")
							CosmeticPartProvider = v.CosmeticPartProvider
							break
						end
					end
					if not Exist2 then
						ProjectileContainer = Instance.new("Folder")
						ProjectileContainer.Name = "ProjectileContainer_("..Projectile.Name..")"
						ProjectileContainer.Parent = Camera
						CosmeticPartProvider = PartCache.new(Projectile, 100, ProjectileContainer)
						table.insert(PartCacheStorage, {
							ProjectileName = Projectile.Name,
							CosmeticPartProvider = CosmeticPartProvider
						})
					end					
				end				
			end

			local PenetrationDepth = AddressTableValue(Misc.ChargeLevel, "PenetrationDepth", Module2)
			local PenetrationAmount = AddressTableValue(Misc.ChargeLevel, "PenetrationAmount", Module2)
			local PenetrationData
			if (PenetrationDepth > 0 or PenetrationAmount > 0) then
				PenetrationData = {
					PenetrationDepth = PenetrationDepth,
					PenetrationAmount = PenetrationAmount,
					PenetrationIgnoreDelay = AddressTableValue(Misc.ChargeLevel, "PenetrationIgnoreDelay", Module2),
					PenetrationModifiers = AddressTableValue(Misc.ChargeLevel, "PenetrationModifiers", Module2),
					HitHumanoids = {},
				}
			end

			local SpinX = AddressTableValue(Misc.ChargeLevel, "SpinX", Module2)
			local SpinY = AddressTableValue(Misc.ChargeLevel, "SpinY", Module2)
			local SpinZ = AddressTableValue(Misc.ChargeLevel, "SpinZ", Module2)

			local BulletParticleData
			if AddressTableValue(Misc.ChargeLevel, "BulletParticle", Module2) then
				local BulletType = AddressTableValue(Misc.ChargeLevel, "BulletType", Module2)
				if BulletType ~= "None" then
					local Attachment0 = Bullets[BulletType].Attachment0:Clone()
					local Attachment1 = Bullets[BulletType].Attachment1:Clone()
					local Effects = {}
					Attachment0.Parent = Workspace.Terrain
					Attachment1.Parent = Workspace.Terrain
					for _, effect in next, Bullets[BulletType]:GetChildren() do
						if effect:IsA("Beam") or effect:IsA("Trail") then
							local eff = effect:Clone()
							eff.Attachment0 = Attachment0 --Attachment1
							eff.Attachment1 = Attachment1 --Attachment0
							eff.Parent = Workspace.Terrain
							table.insert(Effects, eff)
						end
					end
					BulletParticleData = {
						T0 = nil,
						P0 = nil,
						V0 = nil,
						T1 = os.clock(),
						P1 = CFrame.new().pointToObjectSpace(Camera.CFrame, Origin),
						V1 = nil,
						Attachment0 = Attachment0,
						Attachment1 = Attachment1,
						Effects = Effects,
						MotionBlur = AddressTableValue(Misc.ChargeLevel, "MotionBlur", Module2),
						BulletSize = AddressTableValue(Misc.ChargeLevel, "BulletSize", Module2),
						BulletBloom = AddressTableValue(Misc.ChargeLevel, "BulletBloom", Module2),
						BulletBrightness = AddressTableValue(Misc.ChargeLevel, "BulletBrightness", Module2),
					}
				end	
			end

			local CastBehavior = FastCast.newBehavior()
			CastBehavior.RaycastParams = CastParams
			CastBehavior.TravelType = AddressTableValue(Misc.ChargeLevel, "TravelType", Module2)
			CastBehavior.MaxDistance = AddressTableValue(Misc.ChargeLevel, "Range", Module2)
			CastBehavior.Lifetime = AddressTableValue(Misc.ChargeLevel, "Lifetime", Module2)
			CastBehavior.HighFidelityBehavior = FastCast.HighFidelityBehavior.Default

			--CastBehavior.CosmeticBulletTemplate = CosmeticBullet -- Uncomment if you just want a simple template part and aren't using PartCache
			CastBehavior.CosmeticBulletProvider = CosmeticPartProvider -- Comment out if you aren't using PartCache

			CastBehavior.CosmeticBulletContainer = ProjectileContainer
			CastBehavior.Acceleration = RealAcceleration > 0 and Vector3.new(0, 0, 0) or Acceleration
			CastBehavior.AutoIgnoreContainer = false
			CastBehavior.HitEventOnTermination = AddressTableValue(Misc.ChargeLevel, "HitEventOnTermination", Module2)
			CastBehavior.CanPenetrateFunction = CanRayPenetrate
			CastBehavior.CanHitFunction = CanRayHit

			local RaycastHitbox = AddressTableValue(Misc.ChargeLevel, "RaycastHitbox", Module2)
			local RaycastHitboxData = AddressTableValue(Misc.ChargeLevel, "RaycastHitboxData", Module2)
			local ShapeCast = AddressTableValue(Misc.ChargeLevel, "ShapeCast", Module2)
			CastBehavior.RaycastHitbox = (not ShapeCast and RaycastHitbox and #RaycastHitboxData > 0) and RaycastHitboxData or nil
			CastBehavior.ShapeCast = nil
			if ShapeCast then
				CastBehavior.ShapeCast = {
					CastShape = AddressTableValue(Misc.ChargeLevel, "CastShape", Module2),
					CastSize = AddressTableValue(Misc.ChargeLevel, "CastSize", Module2),
					CastRadius = AddressTableValue(Misc.ChargeLevel, "CastRadius", Module2),
				}
			end
			CastBehavior.CurrentCFrame = CFrame.new(Origin, Origin + Dir)
			CastBehavior.ModifiedDirection = CFrame.new(Origin, Origin + Dir).LookVector

			CastBehavior.Hitscan = AddressTableValue(Misc.ChargeLevel, "ShootType", Module2) == "Hitscan"

			local LaserTrailId = HttpService:GenerateGUID()
			if Replicate then
				if LaserTrailEnabled and DamageableLaserTrail then
					table.insert(LaserTrails, {
						Id = LaserTrailId,
						LaserContainer = {},
						HitHumanoids = {},
						Terminate = false,
						Setting = Module2,
						BulletId = Direction[2],
					})
				end
			end

			local BoltCFrameTable = {}
			local LightningBoltEnabled = AddressTableValue(Misc.ChargeLevel, "LightningBoltEnabled", Module2)
			if LightningBoltEnabled then
				local BoltRadius = AddressTableValue(Misc.ChargeLevel, "BoltRadius", Module2)
				for i = 1, AddressTableValue(Misc.ChargeLevel, "BoltCount", Module2) do
					if i == 1 then
						table.insert(BoltCFrameTable, CFrame.new(0, 0, 0))
					else
						table.insert(BoltCFrameTable, CFrame.new(math.random(-BoltRadius, BoltRadius), math.random(-BoltRadius, BoltRadius), 0))
					end
				end
			end

			CastBehavior.UserData = {
				ShootId = ShootId,
				Tool = Tool,
				Character = Character,
				Setting = Module2,
				BulletId = Direction[2],
				Misc = Misc,
				Replicate = Replicate,
				RealAccelerationData = RealAccelerationData,
				PenetrationData = PenetrationData,
				BulletParticleData = BulletParticleData,
				LaserData = {
					LaserTrailEnabled = LaserTrailEnabled,					
					LaserTrailWidth = AddressTableValue(Misc.ChargeLevel, "LaserTrailWidth", Module2),
					LaserTrailHeight = AddressTableValue(Misc.ChargeLevel, "LaserTrailHeight", Module2),					
					LaserTrailColor = AddressTableValue(Misc.ChargeLevel, "LaserTrailColor", Module2),
					RandomizeLaserColorIn = AddressTableValue(Misc.ChargeLevel, "RandomizeLaserColorIn", Module2),
					LaserTrailMaterial = AddressTableValue(Misc.ChargeLevel, "LaserTrailMaterial", Module2),
					LaserTrailShape = AddressTableValue(Misc.ChargeLevel, "LaserTrailShape", Module2),
					LaserTrailReflectance = AddressTableValue(Misc.ChargeLevel, "LaserTrailReflectance", Module2),
					LaserTrailTransparency = AddressTableValue(Misc.ChargeLevel, "LaserTrailTransparency", Module2),
					LaserTrailVisibleTime = AddressTableValue(Misc.ChargeLevel, "LaserTrailVisibleTime", Module2),
					LaserTrailFadeTime = AddressTableValue(Misc.ChargeLevel, "LaserTrailFadeTime", Module2),
					ScaleLaserTrail = AddressTableValue(Misc.ChargeLevel, "ScaleLaserTrail", Module2),
					LaserTrailScaleMultiplier = AddressTableValue(Misc.ChargeLevel, "LaserTrailScaleMultiplier", Module2),
					RandomLaserColor = Color3.new(math.random(), math.random(), math.random()),
					LaserTrailId = LaserTrailId,
					UpdateLaserTrail = UpdateLaserTrail,
					LaserTrailContainer = {},
				},
				LightningData = {
					LightningBoltEnabled = AddressTableValue(Misc.ChargeLevel, "LightningBoltEnabled", Module2),
					BoltWideness = AddressTableValue(Misc.ChargeLevel, "BoltWideness", Module2),
					BoltWidth = AddressTableValue(Misc.ChargeLevel, "BoltWidth", Module2),
					BoltHeight = AddressTableValue(Misc.ChargeLevel, "BoltHeight", Module2),
					BoltColor = AddressTableValue(Misc.ChargeLevel, "BoltColor", Module2),
					RandomizeBoltColorIn = AddressTableValue(Misc.ChargeLevel, "RandomizeBoltColorIn", Module2),
					BoltMaterial = AddressTableValue(Misc.ChargeLevel, "BoltMaterial", Module2),
					BoltShape = AddressTableValue(Misc.ChargeLevel, "BoltShape", Module2),
					BoltReflectance = AddressTableValue(Misc.ChargeLevel, "BoltReflectance", Module2),
					BoltTransparency = AddressTableValue(Misc.ChargeLevel, "BoltTransparency", Module2),
					BoltVisibleTime = AddressTableValue(Misc.ChargeLevel, "BoltVisibleTime", Module2),
					BoltFadeTime = AddressTableValue(Misc.ChargeLevel, "BoltFadeTime", Module2),
					ScaleBolt = AddressTableValue(Misc.ChargeLevel, "ScaleBolt", Module2),
					BoltScaleMultiplier = AddressTableValue(Misc.ChargeLevel, "BoltScaleMultiplier", Module2),
					RandomBoltColor = Color3.new(math.random(), math.random(), math.random()),
					BoltCFrameTable = BoltCFrameTable,
				},
				SpinData = {
					CanSpinPart = AddressTableValue(Misc.ChargeLevel, "CanSpinPart", Module2),
					SpinX = SpinX,
					SpinY = SpinY,
					SpinZ = SpinZ,
					InitalTick = os.clock(),
					InitalAngularVelocity = Vector3.new(SpinX, SpinY, SpinZ),
					InitalRotation = (CastBehavior.CurrentCFrame - CastBehavior.CurrentCFrame.p),
					ProjectileOffset = Vector3.new(),
				},
				DebrisData = {
					DebrisProjectile = AddressTableValue(Misc.ChargeLevel, "DebrisProjectile", Module2),
					AnchorDebris = AddressTableValue(Misc.ChargeLevel, "AnchorDebris", Module2),
					CollideDebris = AddressTableValue(Misc.ChargeLevel, "CollideDebris", Module2),
					NormalizeDebris = AddressTableValue(Misc.ChargeLevel, "NormalizeDebris", Module2),
					BounceDebris = AddressTableValue(Misc.ChargeLevel, "BounceDebris", Module2),
					BounceVelocity = AddressTableValue(Misc.ChargeLevel, "BounceVelocity", Module2),
					WeldDebris = AddressTableValue(Misc.ChargeLevel, "WeldDebris", Module2),

					DecayProjectile = AddressTableValue(Misc.ChargeLevel, "DecayProjectile", Module2),
					AnchorDecay = AddressTableValue(Misc.ChargeLevel, "AnchorDecay", Module2),
					CollideDecay = AddressTableValue(Misc.ChargeLevel, "CollideDecay", Module2),
					DecayVelocity = AddressTableValue(Misc.ChargeLevel, "DecayVelocity", Module2),
					VelocityInfluence = AddressTableValue(Misc.ChargeLevel, "VelocityInfluence", Module2),

					DisableDebrisContents = AddressTableValue(Misc.ChargeLevel, "DisableDebrisContents", Module2),	
				},
				BounceData = {
					CurrentBounces = AddressTableValue(Misc.ChargeLevel, "BounceAmount", Module2),
					BounceElasticity = AddressTableValue(Misc.ChargeLevel, "BounceElasticity", Module2),
					FrictionConstant = AddressTableValue(Misc.ChargeLevel, "FrictionConstant", Module2),
					IgnoreSlope = AddressTableValue(Misc.ChargeLevel, "IgnoreSlope", Module2),
					SlopeAngle = AddressTableValue(Misc.ChargeLevel, "SlopeAngle", Module2),
					BounceHeight = AddressTableValue(Misc.ChargeLevel, "BounceHeight", Module2),
					NoExplosionWhileBouncing = AddressTableValue(Misc.ChargeLevel, "NoExplosionWhileBouncing", Module2),
					StopBouncingOn = AddressTableValue(Misc.ChargeLevel, "StopBouncingOn", Module2),
					SuperBounce = AddressTableValue(Misc.ChargeLevel, "SuperBounce", Module2),
					BounceBetweenHumanoids = AddressTableValue(Misc.ChargeLevel, "BounceBetweenHumanoids", Module2),
					PredictDirection = AddressTableValue(Misc.ChargeLevel, "PredictDirection", Module2),
					MaxBounceAngle = AddressTableValue(Misc.ChargeLevel, "MaxBounceAngle", Module2),
					UsePartDensity = AddressTableValue(Misc.ChargeLevel, "UsePartDensity", Module2),
					UseBulletSpeed = AddressTableValue(Misc.ChargeLevel, "UseBulletSpeed", Module2),
					AnchorPoint = AddressTableValue(Misc.ChargeLevel, "AnchorPoint", Module2),
					BounceDelay = AddressTableValue(Misc.ChargeLevel, "BounceDelay", Module2),
					BouncedHumanoids = {},
					CurrentAnchorPoint = Vector3.new(),
					BounceDeltaTime = 0,
					LastBouncedObject = nil,
				},
				HomeData = {
					Homing = AddressTableValue(Misc.ChargeLevel, "Homing", Module2),
					HomingDistance = AddressTableValue(Misc.ChargeLevel, "HomingDistance", Module2),
					TurnRatePerSecond = AddressTableValue(Misc.ChargeLevel, "TurnRatePerSecond", Module2),
					HomeThroughWall = AddressTableValue(Misc.ChargeLevel, "HomeThroughWall", Module2),
					LockOnOnHovering = Module2.LockOnOnHovering,
					LockedEntity = Misc.LockedEntity,
				},
				UpdateData = {
					UpdateRayInExtra = AddressTableValue(Misc.ChargeLevel, "UpdateRayInExtra", Module2),
					ExtraRayUpdater = AddressTableValue(Misc.ChargeLevel, "ExtraRayUpdater", Module2),
				},
				WhizData = {
					WhizSoundEnabled = AddressTableValue(Misc.ChargeLevel, "WhizSoundEnabled", Module2),
					WhizDistance = AddressTableValue(Misc.ChargeLevel, "WhizDistance", Module2),
					WhizSoundIDs = AddressTableValue(Misc.ChargeLevel, "WhizSoundIDs", Module2),
					WhizSoundVolume = AddressTableValue(Misc.ChargeLevel, "WhizSoundVolume", Module2),
					WhizSoundPitchMin = AddressTableValue(Misc.ChargeLevel, "WhizSoundPitchMin", Module2),
					WhizSoundPitchMax = AddressTableValue(Misc.ChargeLevel, "WhizSoundPitchMax", Module2),
					Whizzed = false,	
				},
				LastReflectingModel = nil,
				IgnoreList = IgnoreList,
				LastSegmentOrigin = Vector3.new(),
				SegmentOrigin = Vector3.new(),
				SegmentDirection = Vector3.new(),
				SegmentVelocity = Vector3.new(),
				LastPosition = Origin,
				CastBehavior = CastBehavior,
			}

			local Simulate = Caster:Fire(Origin, Dir, Velocity, CastBehavior)
		end

		if Replicate then
			if LaserTrailEnabled and DamageableLaserTrail then
				if UpdateLaserTrail then
					UpdateLaserTrail.Event:Connect(function(Id, LaserContainer, Terminate)
						for _, v in pairs(LaserTrails) do
							if v.Id == Id then
								v.LaserContainer = LaserContainer
								if Terminate then
									v.Terminate = true
								end
								break
							end
						end
					end)
				end
				local Connection
				Connection = RunService.Heartbeat:Connect(function(dt)
					if #LaserTrails <= 0 then
						if UpdateLaserTrail then
							UpdateLaserTrail:Destroy()
						end
						if Connection then
							Connection:Disconnect()
							Connection = nil
						end
					else
						for i, v in next, LaserTrails, nil do
							local Terminated = false
							if v.Terminate then
								if #v.LaserContainer <= 0 then
									Terminated = true
									table.remove(LaserTrails, i)
								end
							end
							if Terminated then
								continue						
							end
							for _, vv in pairs(v.LaserContainer) do
								if vv == nil then
									continue
								end
								local TouchingParts = Workspace:GetPartsInPart(vv, RegionParams)
								for _, part in pairs(TouchingParts) do
									if part and part.Parent then
										local Target = part:FindFirstAncestorOfClass("Model")
										local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
										local TargetTorso = Target and (Target:FindFirstChild("HumanoidRootPart") or part.Parent:FindFirstChild("Head"))
										if TargetHumanoid and TargetHumanoid.Health > 0 and TargetHumanoid.Parent ~= Character and TargetTorso then
											if not table.find(v.HitHumanoids, TargetHumanoid) then
												table.insert(v.HitHumanoids, TargetHumanoid)
												Thread:Spawn(function()
													local TempMisc = CloneTable(Misc)
													TempMisc["BulletId"] = v.BulletId
													TempMisc["ClientHitSize"] = part.Size
													TempMisc["MousePosition"] = nil
													InflictTarget:FireServer("GunLaser", Tool, part, CreatePacket(TempMisc))
												end)
												if Tool and Tool.GunClient:FindFirstChild("MarkerEvent") then
													Tool.GunClient.MarkerEvent:Fire(v.Setting)
												end	
												if AddressTableValue(Misc.ChargeLevel, "LaserTrailConstantDamage", v.Setting) then
													Thread:Delay(AddressTableValue(Misc.ChargeLevel, "LaserTrailDamageRate", v.Setting), function()
														local Index = table.find(v.HitHumanoids, TargetHumanoid)
														if Index then
															table.remove(v.HitHumanoids, Index)
														end
													end)
												end
											end	
										end	
									end
								end
							end		
						end
					end
				end)				
			end			
		end
	end
end

Caster.RayFinalHit:Connect(OnRayFinalHit)
Caster.RayHit:Connect(OnRayHit)
Caster.LengthChanged:Connect(OnRayUpdated)
Caster.CastTerminating:Connect(OnRayTerminated)

return ProjectileHandler
