local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Miscs = ReplicatedStorage:WaitForChild("Miscs")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Events = ReplicatedStorage:WaitForChild("Events")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Tool = script.Parent
local AnimationFolder = Tool:WaitForChild("AnimationFolder")
local ValueFolder = Tool:WaitForChild("ValueFolder")

local Camera = Workspace.CurrentCamera

local Player = Players.LocalPlayer
local Character = Player.Character
if not Character or not Character.Parent then
	Character = Player.CharacterAdded:Wait()
end
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Head = Character:WaitForChild("Head")
local Torso = Character:FindFirstChild("Torso") or Character:FindFirstChild("UpperTorso")
local LeftArm = Character:FindFirstChild("Left Arm") or Character:FindFirstChild("LeftHand")
local RightArm = Character:FindFirstChild("Right Arm") or Character:FindFirstChild("RightHand")

local PlayerGui = Player:WaitForChild("PlayerGui")
local Mouse = Player:GetMouse()
local GunServer = Tool:WaitForChild("GunServer")
local ChangeMagAndAmmo = GunServer:WaitForChild("ChangeMagAndAmmo")
local MarkerEvent = script:WaitForChild("MarkerEvent")

local GUI = script:WaitForChild("GunGUI")
local MobileButtons = {
	AimButton = GUI.MobileButtons.AimButton,
	FireButton = GUI.MobileButtons.FireButton,
	SubFireButton = GUI.SubFireButton,
	HoldDownButton = GUI.MobileButtons.HoldDownButton,
	InspectButton = GUI.MobileButtons.InspectButton,
	ReloadButton = GUI.MobileButtons.ReloadButton,
	SwitchButton = GUI.MobileButtons.SwitchButton,
	MeleeButton = GUI.MobileButtons.MeleeButton,
	AltButton = GUI.MobileButtons.AltButton
}

local TouchGui
local TouchControlFrame
local JumpButton
if UserInputService.TouchEnabled then
	TouchGui = PlayerGui:WaitForChild("TouchGui")
	TouchControlFrame = TouchGui:WaitForChild("TouchControlFrame")
	JumpButton = TouchControlFrame:WaitForChild("JumpButton")
end

local GunVisualEffects = Miscs.GunVisualEffects
local Scanners = Miscs.Scanners

local SmokeTrail = require(Modules.SmokeTrail)
local SettingModifier = require(Modules.SettingModifier)
local DamageModule = require(Modules.DamageModule)
local Utilities = require(Modules.Utilities)
local Thread = Utilities.Thread
local ProjectileMotion = Utilities.ProjectileMotion
local Math = Utilities.Math
local Spring = Utilities.Spring
local CloneTable = Utilities.CloneTable
local RotatedRegion3 = Utilities.RotatedRegion3
local RaycastHitbox = Utilities.RaycastHitboxV4
local CreatePacket, DecodePacket = unpack(Utilities.DataPacket)

local gunEvent = Events.gunEvent
local gunFunction = Events.gunFunction

local InflictTarget = Remotes.InflictTarget
local ShatterGlass = Remotes.ShatterGlass
local VisualizeBeam = Remotes.VisualizeBeam
local VisibleMuzzle = Remotes.VisibleMuzzle

local GUID = HttpService:GenerateGUID()
local BindToStepName = "UpdateGun_"..GUID

local TopbarOffset = (GUI.IgnoreGuiInset and GuiService:GetGuiInset()) or Vector2.new(0, 0)
local Killzone = GUI.AbsoluteSize.Y + TopbarOffset.Y + 100

local TargetMarker = script:WaitForChild("TargetMarker")
local LockedEntity

local CommonVariables = {
	Equipped = false;
	ActuallyEquipped = false;
	Enabled = true;
	Down = false;
	HoldDown = false;
	Reloading = false;
	CanCancelReload = false;
	AimDown = false;
	Scoping = false;
	Inspecting = false;
	Charging = false;
	Charged = false;
	Overheated = false;
	CanBeCooledDown = true;
	Switching = false;
	Alting = false;
	AlreadyHit = false;
	CurrentFireRate = 0;
	ShootCounts = 0;
	CurrentRate = 0;
	LastRate = 0;
	ElapsedTime = 0;
	CasingCount = 0;
	LastUpdate = nil;
	LastUpdate2 = nil;
	Radar = nil;
	Beam = nil;
	Attach0 = nil;
	Attach1 = nil;
	Misc = nil;
	LaserTrail = nil;
	Hitbox = nil;
	Hitbox2 = nil;
	BoltSegments = {};
	Animations = {};
	SettingModules = {};
	Keyframes = {};
	KeyframeConnections = {};
	Casings = {};
	HitHumanoids = {};
	MeleeHitHumanoids = {};
	BlockedModels = {};
	InitialSensitivity = UserInputService.MouseDeltaSensitivity;
	Motor6DInstances = {};
	GripId = 0;
	DefaultC0 = nil;
	DefaultC1 = nil;
	Handle2 = nil;
	Grip2 = nil;
}
local Variables = {}

local IgnoreList = {Camera, Tool, Character}

local RegionParams = OverlapParams.new()
RegionParams.FilterType = Enum.RaycastFilterType.Blacklist
RegionParams.FilterDescendantsInstances = IgnoreList
RegionParams.MaxParts = 0
RegionParams.CollisionGroup = "Default"

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Blacklist
RayParams.FilterDescendantsInstances = IgnoreList
RayParams.IgnoreWater = true

local Setting = Tool:WaitForChild("Setting")
local Module = require(Setting)
local ConditionableGunMods = require(Setting:WaitForChild("ConditionableGunMods"))
local CanShootConditions = require(Setting:WaitForChild("CanShootConditions"))
local OnClientShootEvents = require(Setting:WaitForChild("OnClientShootEvents"))

if Module.DualWeldEnabled then
	CommonVariables.Handle2 = Tool:WaitForChild("Handle2", 2)
	if CommonVariables.Handle2 == nil and Module.DualWeldEnabled then error("\"Dual\" setting is enabled but \"Handle2\" is missing!") end
end

local Settings = {}
for i, v in pairs(Setting:GetChildren()) do
	if v.Name ~= "CanShootConditions" and v.Name ~= "ConditionableGunMods" and v.Name ~= "OnClientShootEvents" then
		table.insert(Settings, v)
	end
end
table.sort(Settings, function(a, b)
	return tonumber(a.Name) < tonumber(b.Name)
end)

for i, v in ipairs(Settings) do
	table.insert(CommonVariables.SettingModules, require(v))
	table.insert(Variables, {
		Mag = ValueFolder[i].Mag.Value;
		Ammo = ValueFolder[i].Ammo.Value;
		Heat = 0;
		MaxAmmo = CommonVariables.SettingModules[i].MaxAmmo;
		ElapsedCooldownTime = 0;
		ChargeLevel = 0;
		FireModes = CommonVariables.SettingModules[i].FireModes;
		FireMode = 1;
		ShotsForDepletion = 0;
		ShotID = 0;
		HandleIndex = 1;
		FireAnimIndex = 1;
		LastFireAnimIndex = 1;
		AimFireAnimIndex = 1;
		AimLastFireAnimIndex = 1;
		ShotgunPumpinAnimIndex = 1;
		ChargeLevelCap = math.clamp(CommonVariables.SettingModules[i].ChargeLevelCap, 1, 3);
	})
end

for i, v in ipairs(AnimationFolder:GetChildren()) do
	local AnimTable = {}
	if CommonVariables.SettingModules[i].EquippedAnimationID ~= nil then
		AnimTable.EquippedAnim = v:WaitForChild("EquippedAnim")
		AnimTable.EquippedAnim = Humanoid:LoadAnimation(AnimTable.EquippedAnim)
	end
	if CommonVariables.SettingModules[i].EmptyEquippedAnimationID ~= nil then
		AnimTable.EmptyEquippedAnim = v:WaitForChild("EmptyEquippedAnim")
		AnimTable.EmptyEquippedAnim = Humanoid:LoadAnimation(AnimTable.EmptyEquippedAnim)
	end
	if CommonVariables.SettingModules[i].IdleAnimationID ~= nil then
		AnimTable.IdleAnim = v:WaitForChild("IdleAnim")
		AnimTable.IdleAnim = Humanoid:LoadAnimation(AnimTable.IdleAnim)
	end
	if CommonVariables.SettingModules[i].EmptyIdleAnimationID ~= nil then
		AnimTable.EmptyIdleAnim = v:WaitForChild("EmptyIdleAnim")
		AnimTable.EmptyIdleAnim = Humanoid:LoadAnimation(AnimTable.EmptyIdleAnim)
	end
	if #CommonVariables.SettingModules[i].FireAnimations > 0 then		
		local FireAnimFolder = v:WaitForChild("FireAnimations")	
		AnimTable.FireAnims = {}
		for ii, vv in ipairs(CommonVariables.SettingModules[i].FireAnimations) do
			if vv.FireAnimationID ~= nil then
				local Anim = FireAnimFolder:WaitForChild("FireAnim_"..ii)
				table.insert(AnimTable.FireAnims, {Humanoid:LoadAnimation(Anim), vv.FireAnimationSpeed})
			end			
		end
	end
	if #CommonVariables.SettingModules[i].LastFireAnimations > 0 then		
		local LastFireAnimFolder = v:WaitForChild("LastFireAnimations")	
		AnimTable.LastFireAnims = {}
		for ii, vv in ipairs(CommonVariables.SettingModules[i].LastFireAnimations) do
			if vv.LastFireAnimationID ~= nil then
				local Anim = LastFireAnimFolder:WaitForChild("LastFireAnim_"..ii)
				table.insert(AnimTable.LastFireAnims, {Humanoid:LoadAnimation(Anim), vv.LastFireAnimationSpeed})
			end			
		end
	end
	if #CommonVariables.SettingModules[i].ShotgunPumpinAnimations > 0 then		
		local ShotgunPumpinAnimFolder = v:WaitForChild("ShotgunPumpinAnimations")	
		AnimTable.ShotgunPumpinAnims = {}
		for ii, vv in ipairs(CommonVariables.SettingModules[i].ShotgunPumpinAnimations) do
			if vv.ShotgunPumpinAnimationID ~= nil then
				local Anim = ShotgunPumpinAnimFolder:WaitForChild("ShotgunPumpinAnim_"..ii)
				table.insert(AnimTable.ShotgunPumpinAnims, {Humanoid:LoadAnimation(Anim), vv.ShotgunPumpinAnimationSpeed})
			end			
		end
	end
	if CommonVariables.SettingModules[i].ShotgunClipinAnimationID ~= nil then		
		AnimTable.ShotgunClipinAnim = v:WaitForChild("ShotgunClipinAnim")
		AnimTable.ShotgunClipinAnim = Humanoid:LoadAnimation(AnimTable.ShotgunClipinAnim)
	end
	if CommonVariables.SettingModules[i].ReloadAnimationID ~= nil then	
		AnimTable.ReloadAnim = v:WaitForChild("ReloadAnim")
		AnimTable.ReloadAnim = Humanoid:LoadAnimation(AnimTable.ReloadAnim)
	end
	if CommonVariables.SettingModules[i].HoldDownAnimationID ~= nil then		
		AnimTable.HoldDownAnim = v:WaitForChild("HoldDownAnim")
		AnimTable.HoldDownAnim = Humanoid:LoadAnimation(AnimTable.HoldDownAnim)
	end
	if CommonVariables.SettingModules[i].AimIdleAnimationID ~= nil then		
		AnimTable.AimIdleAnim = v:WaitForChild("AimIdleAnim")
		AnimTable.AimIdleAnim = Humanoid:LoadAnimation(AnimTable.AimIdleAnim)
	end
	if CommonVariables.SettingModules[i].EmptyAimIdleAnimationID ~= nil then		
		AnimTable.EmptyAimIdleAnim = v:WaitForChild("EmptyAimIdleAnim")
		AnimTable.EmptyAimIdleAnim = Humanoid:LoadAnimation(AnimTable.EmptyAimIdleAnim)
	end
	if #CommonVariables.SettingModules[i].AimFireAnimations > 0 then		
		local AimFireAnimFolder = v:WaitForChild("AimFireAnimations")	
		AnimTable.AimFireAnims = {}
		for ii, vv in ipairs(CommonVariables.SettingModules[i].AimFireAnimations) do
			if vv.AimFireAnimationID ~= nil then
				local Anim = AimFireAnimFolder:WaitForChild("AimFireAnim_"..ii)
				table.insert(AnimTable.AimFireAnims, {Humanoid:LoadAnimation(Anim), vv.AimFireAnimationSpeed})
			end			
		end
	end
	if #CommonVariables.SettingModules[i].AimLastFireAnimations > 0 then		
		local AimLastFireAnimFolder = v:WaitForChild("AimLastFireAnimations")	
		AnimTable.AimLastFireAnims = {}
		for ii, vv in ipairs(CommonVariables.SettingModules[i].AimLastFireAnimations) do
			if vv.AimFireAnimationID ~= nil then
				local Anim = AimLastFireAnimFolder:WaitForChild("AimLastFireAnim_"..ii)
				table.insert(AnimTable.AimLastFireAnims, {Humanoid:LoadAnimation(Anim), vv.AimLastFireAnimationSpeed})
			end			
		end
	end		
	if CommonVariables.SettingModules[i].AimChargingAnimationID ~= nil then		
		AnimTable.AimChargingAnim = v:WaitForChild("AimChargingAnim")
		AnimTable.AimChargingAnim = Humanoid:LoadAnimation(AnimTable.AimChargingAnim)
	end
	if CommonVariables.SettingModules[i].TacticalReloadAnimationEnabled and CommonVariables.SettingModules[i].TacticalReloadAnimationID ~= nil then
		AnimTable.TacticalReloadAnim = v:WaitForChild("TacticalReloadAnim")
		AnimTable.TacticalReloadAnim = Humanoid:LoadAnimation(AnimTable.TacticalReloadAnim)
	end
	if CommonVariables.SettingModules[i].InspectAnimationEnabled and CommonVariables.SettingModules[i].InspectAnimationID ~= nil then		
		AnimTable.InspectAnim = v:WaitForChild("InspectAnim")
		AnimTable.InspectAnim = Humanoid:LoadAnimation(AnimTable.InspectAnim)
	end
	if CommonVariables.SettingModules[i].InspectAnimationEnabled and CommonVariables.SettingModules[i].EmptyInspectAnimationID ~= nil then		
		AnimTable.EmptyInspectAnim = v:WaitForChild("EmptyInspectAnim")
		AnimTable.EmptyInspectAnim = Humanoid:LoadAnimation(AnimTable.EmptyInspectAnim)
	end
	if CommonVariables.SettingModules[i].ShotgunReload and CommonVariables.SettingModules[i].PreShotgunReload and CommonVariables.SettingModules[i].PreShotgunReloadAnimationID ~= nil then
		AnimTable.PreShotgunReloadAnim = v:WaitForChild("PreShotgunReloadAnim")
		AnimTable.PreShotgunReloadAnim = Humanoid:LoadAnimation(AnimTable.PreShotgunReloadAnim)
	end
	if CommonVariables.SettingModules[i].MinigunRevUpAnimationID ~= nil then
		AnimTable.MinigunRevUpAnim = v:WaitForChild("MinigunRevUpAnim")
		AnimTable.MinigunRevUpAnim = Humanoid:LoadAnimation(AnimTable.MinigunRevUpAnim)
	end
	if CommonVariables.SettingModules[i].MinigunRevDownAnimationID ~= nil then
		AnimTable.MinigunRevDownAnim = v:WaitForChild("MinigunRevDownAnim")
		AnimTable.MinigunRevDownAnim = Humanoid:LoadAnimation(AnimTable.MinigunRevDownAnim)
	end
	if CommonVariables.SettingModules[i].ChargingAnimationEnabled and CommonVariables.SettingModules[i].ChargingAnimationID ~= nil then
		AnimTable.ChargingAnim = v:WaitForChild("ChargingAnim")
		AnimTable.ChargingAnim = Humanoid:LoadAnimation(AnimTable.ChargingAnim)
	end
	if CommonVariables.SettingModules[i].SelectiveFireEnabled and CommonVariables.SettingModules[i].SwitchAnimationID ~= nil then		
		AnimTable.SwitchAnim = v:WaitForChild("SwitchAnim")
		AnimTable.SwitchAnim = Humanoid:LoadAnimation(AnimTable.SwitchAnim)
	end
	if CommonVariables.SettingModules[i].BatteryEnabled and CommonVariables.SettingModules[i].OverheatAnimationID ~= nil then
		AnimTable.OverheatAnim = v:WaitForChild("OverheatAnim")
		AnimTable.OverheatAnim = Humanoid:LoadAnimation(AnimTable.OverheatAnim)
	end
	if CommonVariables.SettingModules[i].MeleeAttackEnabled and CommonVariables.SettingModules[i].MeleeAttackAnimationID ~= nil then
		AnimTable.MeleeAttackAnim = v:WaitForChild("MeleeAttackAnim")
		AnimTable.MeleeAttackAnim = Humanoid:LoadAnimation(AnimTable.MeleeAttackAnim)
	end
	if Module.AltFire and CommonVariables.SettingModules[i].AltAnimationID ~= nil then
		AnimTable.AltAnim = v:WaitForChild("AltAnim")
		AnimTable.AltAnim = Humanoid:LoadAnimation(AnimTable.AltAnim)
	end
	if CommonVariables.SettingModules[i].LaserBeamStartupAnimationID ~= nil then		
		AnimTable.LaserBeamStartupAnim = v:WaitForChild("LaserBeamStartupAnim")
		AnimTable.LaserBeamStartupAnim = Humanoid:LoadAnimation(AnimTable.LaserBeamStartupAnim)
	end
	if CommonVariables.SettingModules[i].LaserBeamLoopAnimationID ~= nil then		
		AnimTable.LaserBeamLoopAnim = v:WaitForChild("LaserBeamLoopAnim")
		AnimTable.LaserBeamLoopAnim = Humanoid:LoadAnimation(AnimTable.LaserBeamLoopAnim)
	end
	if CommonVariables.SettingModules[i].LaserBeamStopAnimationID ~= nil then		
		AnimTable.LaserBeamStopAnim = v:WaitForChild("LaserBeamStopAnim")
		AnimTable.LaserBeamStopAnim = Humanoid:LoadAnimation(AnimTable.LaserBeamStopAnim)
	end
	table.insert(CommonVariables.Animations, AnimTable)
end

local CurrentFireMode = 1
local CurrentModule = CommonVariables.SettingModules[CurrentFireMode]
local CurrentVariables = Variables[CurrentFireMode]
local CurrentAnimTable = CommonVariables.Animations[CurrentFireMode]
local CurrentCrosshair = GUI.Crosshair[CurrentFireMode]

for i, v in pairs(GUI.Crosshair:GetChildren()) do
	if v:IsA("CanvasGroup") then
		v.Visible = (tonumber(v.Name) == CurrentFireMode)
	end
end

CommonVariables.ShootCounts = CurrentModule.ShootCounts 

local UniversalTable
if Module.UniversalAmmoEnabled then
	UniversalTable = {
		Ammo = ValueFolder.Ammo.Value;
		MaxAmmo = Module.Ammo;
	}
else
	UniversalTable = CurrentVariables
end

local HandleToFire = Tool:FindFirstChild(CurrentModule.Handles[1], true)

local CurrentAimFireAnim = #CurrentAnimTable.AimFireAnims > 0 and CurrentAnimTable.AimFireAnims[1][1] or nil
local CurrentAimFireAnimationSpeed = #CurrentAnimTable.AimFireAnims > 0 and CurrentAnimTable.AimFireAnims[1][2] or nil
local CurrentFireAnim = #CurrentAnimTable.FireAnims > 0 and CurrentAnimTable.FireAnims[1][1] or nil
local CurrentFireAnimationSpeed = #CurrentAnimTable.FireAnims > 0 and CurrentAnimTable.FireAnims[1][2] or nil

local CurrentAimLastFireAnim = #CurrentAnimTable.AimLastFireAnims > 0 and CurrentAnimTable.AimLastFireAnims[1][1] or nil
local CurrentAimLastFireAnimationSpeed = #CurrentAnimTable.AimLastFireAnims > 0 and CurrentAnimTable.AimLastFireAnims[1][2] or nil
local CurrentLastFireAnim = #CurrentAnimTable.LastFireAnims > 0 and CurrentAnimTable.LastFireAnims[1][1] or nil
local CurrentLastFireAnimationSpeed = #CurrentAnimTable.LastFireAnims > 0 and CurrentAnimTable.LastFireAnims[1][2] or nil

local CurrentShotgunPumpinAnim = #CurrentAnimTable.ShotgunPumpinAnims > 0 and CurrentAnimTable.ShotgunPumpinAnims[1][1] or nil
local CurrentShotgunPumpinAnimationSpeed = #CurrentAnimTable.ShotgunPumpinAnims > 0 and CurrentAnimTable.ShotgunPumpinAnims[1][2] or nil

local BeamTable = {}
local CrosshairPointAttachment = Instance.new("Attachment")
CrosshairPointAttachment.Name = "CrosshairPointAttachment"
local LaserBeamEffect = GunVisualEffects:FindFirstChild(CurrentModule.LaserBeamEffect)
if LaserBeamEffect then
	for i, v in pairs(LaserBeamEffect.HitEffect:GetChildren()) do
		if v.ClassName == "ParticleEmitter" then
			local particle = v:Clone()
			particle.Enabled = true
			particle.Parent = CrosshairPointAttachment
		end
	end
	for i, v in pairs(LaserBeamEffect.LaserBeams:GetChildren()) do
		if v.ClassName == "Beam" then
			local beam = v:Clone()
			table.insert(BeamTable, beam)
		end
	end
end

local function FindAnimationNameForKeyframe(AnimObject)
	if CurrentModule.AnimationKeyframes[AnimObject.Name] then
		table.insert(CommonVariables.Keyframes, {AnimObject, CurrentModule.AnimationKeyframes[AnimObject.Name]})
	end
end

for _, a in pairs(CurrentAnimTable) do
	if typeof(a) == "table" then
		for _, a2 in pairs(a) do
			FindAnimationNameForKeyframe(a2[1])
		end
	else
		FindAnimationNameForKeyframe(a)
	end 
end

if Module.MagCartridge and not CurrentModule.BatteryEnabled and CurrentModule.AmmoPerMag ~= math.huge then
	for i = 1, CurrentModule.AmmoPerMag do
		local Bullet = GUI.MagCartridge.UIGridLayout.Template:Clone()
		Bullet.Name = i
		Bullet.LayoutOrder = i
		Bullet.Parent = GUI.MagCartridge
	end
end

local Springs = {
	Scope = Spring.spring.new(Vector3.new(0, 200, 0));
	Knockback = Spring.spring.new(Vector3.new());
	CameraSpring = Spring.spring.new(Vector3.new());
	CrossScale = Spring.spring.new(0);
	CrossSpring = Spring.spring.new(0);
}

Springs.Scope.s = CurrentModule.ScopeSwaySpeed
Springs.Scope.d = CurrentModule.ScopeSwayDamper

Springs.Knockback.s = CurrentModule.ScopeKnockbackSpeed
Springs.Knockback.d = CurrentModule.ScopeKnockbackDamper

Springs.CameraSpring.s	= CurrentModule.RecoilSpeed
Springs.CameraSpring.d	= CurrentModule.RecoilDamper

Springs.CrossScale.s = 10	
Springs.CrossScale.d = 0.8
Springs.CrossScale.t = 1

Springs.CrossSpring.s = 12
Springs.CrossSpring.d = 0.65

local function SetCrossScale(Scale)
	Springs.CrossScale.t = Scale
end	

local function SetCrossSize(Size)
	Springs.CrossSpring.t = Size
end

local function SetCrossSettings(Size, Speed, Damper)
	Springs.CrossSpring.t = Size
	Springs.CrossSpring.s = Speed
	Springs.CrossSpring.d = Damper
end

local function Random2DDirection(Velocity, X, Y)
	return Vector2.new(X, Y) * (Velocity or 1)
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

local function AddressTableValue(ValueName, Setting)
	if CurrentModule.ChargedShotAdvanceEnabled and Setting.ChargeAlterTable then
		local AlterTable = Setting.ChargeAlterTable[ValueName]
		return AlterTable and ((CurrentVariables.ChargeLevel == 1 and AlterTable.Level1) or (CurrentVariables.ChargeLevel == 2 and AlterTable.Level2) or (CurrentVariables.ChargeLevel == 3 and AlterTable.Level3) or Setting[ValueName]) or Setting[ValueName]
	else
		return Setting[ValueName]
	end
end

local function CanShoot()
	if CanShootConditions[CurrentFireMode] ~= nil then
		return CanShootConditions[CurrentFireMode](Tool, Humanoid, CurrentVariables.Heat, CurrentModule.MaxHeat, CurrentVariables.Mag, CurrentModule.AmmoPerMag, UniversalTable.Ammo, UniversalTable.MaxAmmo, CommonVariables.ShootCounts, CommonVariables.CurrentFireRate)	
	end
	return true
end

local function PopulateHumanoids()	
	for _, v in pairs(CollectionService:GetTagged("Humanoids")) do
		if v.Parent ~= Character and DamageModule.CanDamage(v.Parent, Character, CurrentModule.FriendlyFire) then
			table.insert(Humanoids, v)
		end	
	end
end

local function CastRay(Type, StartPos, Direction, Length, Blacklist, IgnoreWater, RealTargetHumanoid)
	debug.profilebegin("CastRay_(GunClient_"..Tool.Name..")")
	local Blacklist = CloneTable(Blacklist)
	local ShouldIgnoreHumanoid = CurrentModule.IgnoreHumanoids
	if Type ~= "Beam" then
		ShouldIgnoreHumanoid = false
	end
	local Iterations = 0
	local NewRay = Ray.new(StartPos, Direction * Length)
	local HitPart, HitPoint, HitNormal, HitMaterial = nil, StartPos + (Direction * Length), Vector3.new(0, 1, 0), Enum.Material.Air
	while Iterations < 20 do
		Iterations = Iterations + 1
		HitPart, HitPoint, HitNormal, HitMaterial = Workspace:FindPartOnRayWithIgnoreList(NewRay, Blacklist, false, IgnoreWater)
		if HitPart then
			local Target = HitPart:FindFirstAncestorOfClass("Model")
			local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
			local TargetTool = HitPart:FindFirstAncestorOfClass("Tool")
			if RealTargetHumanoid and TargetHumanoid then
				ShouldIgnoreHumanoid = (RealTargetHumanoid ~= TargetHumanoid)
			end
			if (--[[not HitPart.CanCollide
				or]] HitPart.Transparency > 0.75
				or HitPart.Name == "Handle"
				or (
					TargetHumanoid and (
						TargetHumanoid.Health <= 0
							or not DamageModule.CanDamage(Target, Character, CurrentModule.FriendlyFire)
							or ShouldIgnoreHumanoid
					)
				)
				or TargetTool) then
				table.insert(Blacklist, HitPart)
			else
				break
			end				
		else
			break
		end
	end
	debug.profileend()
	return HitPart, HitPoint, HitNormal, HitMaterial
end

local function Get3DPosition(Type, CurrentPosOnScreen)
	local InputRay = Camera:ScreenPointToRay(CurrentPosOnScreen.X, CurrentPosOnScreen.Y, 1000)
	local EndPos = InputRay.Origin + InputRay.Direction
	local HitPart, HitPoint, HitNormal, HitMaterial = CastRay(Type, Camera.CFrame.p, (EndPos - Camera.CFrame.p).Unit, 1000, IgnoreList, true)
	return HitPoint
end

local function Get3DPosition2()
	local Type = CurrentModule.LaserBeam and "Beam" or "Tip"
	if Module.DirectShootingAt == "None" then
		return Get3DPosition(Type, GUI.Crosshair.Center.AbsolutePosition)
	else
		local FirePointObject = HandleToFire:FindFirstChild("GunFirePoint"..CurrentFireMode)
		if FirePointObject ~= nil then
			local Direction = ((FirePointObject.WorldCFrame * CFrame.new(0, 0, -5000)).p - FirePointObject.WorldPosition).Unit		
			local HitPart, HitPoint, HitNormal, HitMaterial = CastRay("Direct", FirePointObject.WorldPosition, Direction, 5000, IgnoreList, true)
			if Module.DirectShootingAt == "Both" then
				return HitPoint
			else
				if Module.DirectShootingAt == "FirstPerson" then
					if (Camera.Focus.p - Camera.CoordinateFrame.p).Magnitude <= 2 then
						return HitPoint
					else
						return Get3DPosition(Type, GUI.Crosshair.Center.AbsolutePosition)
					end
				elseif Module.DirectShootingAt == "ThirdPerson" then
					if (Camera.Focus.p - Camera.CoordinateFrame.p).Magnitude > 2 then
						return HitPoint
					else
						return Get3DPosition(Type, GUI.Crosshair.Center.AbsolutePosition)
					end
				end
			end			
		else
			return Get3DPosition(Type, GUI.Crosshair.Center.AbsolutePosition)
		end
	end
end

local function CheckPartInScanner(part)
	if part and CommonVariables.Radar then
		local PartPos, OnScreen = Camera:WorldToScreenPoint(part.Position)
		if OnScreen then
			local FrameSize = CommonVariables.Radar.AbsoluteSize
			local FramePos = CommonVariables.Radar.AbsolutePosition	
			return PartPos.X > FramePos.X and PartPos.Y > FramePos.Y and PartPos.X < FramePos.X + FrameSize.X and PartPos.Y < FramePos.Y + FrameSize.Y
		end			
	end
	return false
end

local function CheckForLockedTarget(Target, LockedOnTargets)
	local Found = false
	for _, v in pairs(LockedOnTargets) do
		if v and v.TargetEntity == Target then
			Found = true
			break
		end
	end
	return Found
end

local function FindNearestEntity(LockedOnTargets)
	Humanoids = {}
	PopulateHumanoids()
	local RealDist = CurrentModule.LockOnDistance
	local MinOffset = nil
	local TargetModel = nil
	local TargetHumanoid = nil
	local TargetTorso = nil
	local AlreadyLocked = false
	local TargetCount = 0
	local LocketTargetCount = 0
	local SubHumanoids = {}
	if LockedOnTargets then
		for i, v in ipairs(Humanoids) do
			local torso = v.Parent:FindFirstChild("HumanoidRootPart") or v.Parent:FindFirstChild("Torso") or v.Parent:FindFirstChild("UpperTorso")
			local Dist = (Head.Position - torso.Position).Magnitude
			if v and torso and v.Health > 0 and CheckPartInScanner(torso) and Dist < (RealDist + (torso.Size.Magnitude / 2.5)) then
				if CheckForLockedTarget(v.Parent, LockedOnTargets) then
					LocketTargetCount += 1
				else
					TargetCount += 1
				end
				table.insert(SubHumanoids, v)
			end	
		end
	end
	for i, v in ipairs(LockedOnTargets ~= nil and SubHumanoids or Humanoids) do
		local torso = v.Parent:FindFirstChild("HumanoidRootPart") or v.Parent:FindFirstChild("Torso") or v.Parent:FindFirstChild("UpperTorso")
		if v and torso then
			local Dist = (Head.Position - torso.Position).Magnitude
			local MousePos = Get3DPosition2()
			local MouseDirection = (MousePos - Head.Position).Unit
			local Offset = (((MouseDirection * Dist) + Head.Position) - torso.Position).Magnitude
			local CanFind = Dist < (RealDist + (torso.Size.Magnitude / 2.5)) and Offset < CurrentModule.LockOnRadius and (not MinOffset or Offset < MinOffset) and v.Health > 0
			if LockedOnTargets then
				CanFind = false
				local ShouldIgnore = false
				if CurrentModule.IgnoreLockedTargets and LocketTargetCount < #SubHumanoids then
					ShouldIgnore = CheckForLockedTarget(v.Parent, LockedOnTargets)
				end
				if CurrentModule.ContinueTrackingTargets and LocketTargetCount >= #SubHumanoids and #SubHumanoids < CurrentModule.MaximumTargets then
					ShouldIgnore = false
				end
				if v.Health > 0 and not ShouldIgnore and CheckPartInScanner(torso) then
					CanFind = Dist < (RealDist + (torso.Size.Magnitude / 2.5))
				end 
			end
			local hit = not CurrentModule.LockOnThroughWall and CastRay("LockOn", Head.Position, (torso.CFrame.p - Head.Position).Unit, 999, IgnoreList, true, v) or nil
			local CanLock = true
			if not CurrentModule.LockOnThroughWall then
				CanLock = (hit and hit:IsDescendantOf(v.Parent))
			end
			if CanFind and CanLock and DamageModule.CanDamage(v.Parent, Character, CurrentModule.FriendlyFire) then
				TargetModel = v.Parent
				TargetHumanoid = v
				TargetTorso = torso
				AlreadyLocked = CheckForLockedTarget(v.Parent, LockedOnTargets)
				RealDist = Dist
			end
		end	
	end
	table.clear(SubHumanoids)
	return TargetModel, TargetHumanoid, TargetTorso, AlreadyLocked
end

function SetCustomGrip(Enabled)
	if Enabled then
		CommonVariables.GripId += 1
		local LastGripId = CommonVariables.GripId
		for i, v in pairs(Module.CustomGrips) do
			if LastGripId ~= CommonVariables.GripId then
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
			Motor6DInstance:SetAttribute("Id", i)
			if Part1.Name == "Handle" and Part1.Parent == Tool then
				if not CommonVariables.DefaultC0 or not CommonVariables.DefaultC1 then
					repeat task.wait() if LastGripId ~= CommonVariables.GripId then break end until RightArm:FindFirstChild("RightGrip")
					if LastGripId == CommonVariables.GripId then
						local RightGrip = RightArm:FindFirstChild("RightGrip")
						if RightGrip then
							CommonVariables.DefaultC0 = RightGrip.C0
							CommonVariables.DefaultC1 = RightGrip.C1
							RightGrip.Enabled = false
							RightGrip:Destroy()
						end
					end
				end
				if CommonVariables.DefaultC0 and CommonVariables.DefaultC1 then
					if v.AlignC0AndC1FromDefaultGrip then
						Motor6DInstance.C0 = CommonVariables.DefaultC0
						Motor6DInstance.C1 = CommonVariables.DefaultC1
					end
					if v.CustomGripCFrame then
						Motor6DInstance.C0 *= v.CustomGripC0
						Motor6DInstance.C1 *= v.CustomGripC1
					end
					Motor6DInstance.Parent = Part0
					table.insert(CommonVariables.Motor6DInstances, Motor6DInstance)
				end
			else
				if v.AlignC0AndC1FromDefaultGrip and CommonVariables.DefaultC0 and CommonVariables.DefaultC1 then
					Motor6DInstance.C0 = CommonVariables.DefaultC0
					Motor6DInstance.C1 = CommonVariables.DefaultC1
				end
				if v.CustomGripCFrame then
					Motor6DInstance.C0 *= v.CustomGripC0
					Motor6DInstance.C1 *= v.CustomGripC1
				end
				Motor6DInstance.Parent = Part0
				table.insert(CommonVariables.Motor6DInstances, Motor6DInstance)
			end
		end
	else
		CommonVariables.GripId += 1
		for _, v in pairs(CommonVariables.Motor6DInstances) do
			if v then
				v:Destroy()
			end
		end
		table.clear(CommonVariables.Motor6DInstances)
		CommonVariables.DefaultC0 = nil
		CommonVariables.DefaultC1 = nil
	end
end

function UpdateGUI()
	if CurrentModule.AmmoPerMag ~= math.huge and CurrentModule.MaxHeat ~= math.huge then
		GUI.Frame.Counter.Visible = true
	end

	GUI.Frame.Counter.Mag.Fill:TweenSize(UDim2.new(CurrentVariables.Mag / CurrentModule.AmmoPerMag, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.25, true)
	GUI.Frame.Counter.Ammo.Fill:TweenSize(UDim2.new(UniversalTable.Ammo / UniversalTable.MaxAmmo, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.25, true)
	GUI.Frame.Counter.Heat.Fill:TweenSize(UDim2.new(CurrentVariables.Heat / CurrentModule.MaxHeat, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.25, true)
	GUI.Frame.Counter.Mag.Current.Text = CurrentVariables.Mag
	GUI.Frame.Counter.Mag.Max.Text = CurrentModule.AmmoPerMag
	GUI.Frame.Counter.Ammo.Current.Text = UniversalTable.Ammo
	GUI.Frame.Counter.Ammo.Max.Text = UniversalTable.MaxAmmo
	GUI.Frame.Counter.Heat.Current.Text = CurrentVariables.Heat
	GUI.Frame.Counter.Heat.Max.Text = CurrentModule.MaxHeat

	GUI.Frame.FireMode.Alternative.Visible = (Module.AltFire and CurrentModule.AltName ~= "")
	GUI.Frame.FireMode.Alternative.Text = CurrentModule.AltName
	GUI.Frame.FireMode.Selective.Visible = (CurrentModule.SelectiveFireEnabled and CurrentModule.FireModeTexts[CurrentVariables.FireMode] ~= "")
	GUI.Frame.FireMode.Selective.Text = CurrentModule.FireModeTexts[CurrentVariables.FireMode]

	GUI.Frame.Counter.Mag.Current.Visible = not CommonVariables.Reloading
	GUI.Frame.Counter.Mag.Max.Visible = not CommonVariables.Reloading
	GUI.Frame.Counter.Mag.Frame.Visible = not CommonVariables.Reloading
	GUI.Frame.Counter.Mag.Reloading.Visible = CommonVariables.Reloading

	GUI.Frame.Counter.Ammo.Current.Visible = not (UniversalTable.Ammo <= 0)
	GUI.Frame.Counter.Ammo.Max.Visible = not (UniversalTable.Ammo <= 0)
	GUI.Frame.Counter.Ammo.Frame.Visible = not (UniversalTable.Ammo <= 0)
	GUI.Frame.Counter.Ammo.NoMoreAmmo.Visible = (UniversalTable.Ammo <= 0)

	GUI.Frame.Counter.Heat.Visible = CurrentModule.BatteryEnabled
	GUI.Frame.Counter.Heat.Current.Visible = not CommonVariables.Overheated
	GUI.Frame.Counter.Heat.Max.Visible = not CommonVariables.Overheated
	GUI.Frame.Counter.Heat.Frame.Visible = not CommonVariables.Overheated
	GUI.Frame.Counter.Heat.Overheated.Visible = CommonVariables.Overheated

	GUI.ChargeBar.Visible = (CurrentModule.ChargedShotAdvanceEnabled or (CurrentModule.HoldAndReleaseEnabled and not CurrentModule.LockOnScan))
	GUI.ChargeBar.Level1.Visible = not CurrentModule.HoldAndReleaseEnabled and CurrentVariables.ChargeLevelCap > 1
	GUI.ChargeBar.Level2.Visible = not CurrentModule.HoldAndReleaseEnabled and CurrentVariables.ChargeLevelCap > 2
	local ChargeTime = CurrentModule.AdvancedChargingTime
	if CurrentVariables.ChargeLevelCap == 1 then
		ChargeTime = CurrentModule.Level1ChargingTime
	elseif CurrentVariables.ChargeLevelCap == 2 then
		ChargeTime = CurrentModule.Level2ChargingTime
	end
	GUI.ChargeBar.Level1.Position = UDim2.new(CurrentModule.Level1ChargingTime / ChargeTime, 0, 0.5, 0)
	GUI.ChargeBar.Level2.Position = UDim2.new(CurrentModule.Level2ChargingTime / ChargeTime, 0, 0.5, 0)
	GUI.ChargeBar.Position = Module.MagCartridge and UDim2.new(1, -260, 1, -70) or UDim2.new(1, -260, 1, -35)

	GUI.MagCartridge.Visible = Module.MagCartridge

	GUI.Frame.Counter.Mag.Visible = not CurrentModule.BatteryEnabled
	GUI.Frame.Counter.Ammo.Visible = (Module.UniversalAmmoEnabled or CurrentModule.LimitedAmmoEnabled)
	GUI.Frame.Counter.Heat.Visible = CurrentModule.BatteryEnabled
	GUI.Frame.Counter.Size = (Module.UniversalAmmoEnabled or CurrentModule.LimitedAmmoEnabled) and UDim2.new(1, 0, 0, 100) or UDim2.new(1, 0, 0, 55)
	GUI.Frame.Position = (CurrentModule.ChargedShotAdvanceEnabled or (CurrentModule.HoldAndReleaseEnabled and not CurrentModule.LockOnScan)) and (Module.MagCartridge and UDim2.new(1, -260, 1, -190) or UDim2.new(1, -260, 1, -150)) or (Module.MagCartridge and UDim2.new(1, -260, 1, -150) or UDim2.new(1, -260, 1, -110))

	--For mobile version
	GUI.MobileButtons.Visible = UserInputService.TouchEnabled
	MobileButtons.SubFireButton.Visible = UserInputService.TouchEnabled
	MobileButtons.AimButton.Visible = CurrentModule.ADSEnabled
	MobileButtons.HoldDownButton.Visible = CurrentModule.HoldDownEnabled
	MobileButtons.InspectButton.Visible = CurrentModule.InspectAnimationEnabled
	MobileButtons.SwitchButton.Visible = CurrentModule.SelectiveFireEnabled
	MobileButtons.ReloadButton.Visible = not CurrentModule.BatteryEnabled
	MobileButtons.MeleeButton.Visible = CurrentModule.MeleeAttackEnabled
	MobileButtons.AltButton.Visible = Module.AltFire
end

function Render(dt)
	--Scope (OLD)

	--[[if CommonVariables.Scoping and UserInputService.MouseEnabled and UserInputService.KeyboardEnabled then --For pc version
		GUI.Scope.Size = UDim2.new(Math.Lerp(GUI.Scope.Size.X.Scale, 1.2, math.min(dt * 5, 1)), 36, Math.Lerp(GUI.Scope.Size.Y.Scale, 1.2, math.min(dt * 5, 1)), 36)
		GUI.Scope.Position = UDim2.new(0, Mouse.X - GUI.Scope.AbsoluteSize.X / 2, 0, Mouse.Y - GUI.Scope.AbsoluteSize.Y / 2)
	elseif CommonVariables.Scoping and UserInputService.TouchEnabled and not UserInputService.MouseEnabled and not UserInputService.KeyboardEnabled then --For mobile version, but in first-person view
		GUI.Scope.Size = UDim2.new(Math.Lerp(GUI.Scope.Size.X.Scale, 1.2, math.min(dt * 5, 1)), 36, Math.Lerp(GUI.Scope.Size.Y.Scale, 1.2, math.min(dt * 5, 1)), 36)
		GUI.Scope.Position = UDim2.new(0, GUI.Crosshair.AbsolutePosition.X - GUI.Scope.AbsoluteSize.X / 2, 0, GUI.Crosshair.AbsolutePosition.Y - GUI.Scope.AbsoluteSize.Y / 2)
	else
		GUI.Scope.Size = UDim2.new(0.6, 36, 0.6, 36)
		GUI.Scope.Position = UDim2.new(0, 0, 0, 0)
	end]]

	--Crosshair and scope

	Springs.Knockback.t = Springs.Knockback.t:Lerp(Vector3.new(), 0.2)

	local function UpdateCrosshair()
		if UserInputService.MouseEnabled and UserInputService.KeyboardEnabled then --For pc version
			GUI.Crosshair.Position = UDim2.new(0, Mouse.X, 0, Mouse.Y)    
		elseif UserInputService.TouchEnabled and not UserInputService.MouseEnabled and not UserInputService.KeyboardEnabled and (Camera.Focus.p - Camera.CoordinateFrame.p).Magnitude > 2 then --For mobile version, but in third-person view
			GUI.Crosshair.Position = UDim2.new(0.5, 0, 0.4, -50)
		elseif UserInputService.TouchEnabled and not UserInputService.MouseEnabled and not UserInputService.KeyboardEnabled and (Camera.Focus.p - Camera.CoordinateFrame.p).Magnitude <= 2 then --For mobile version, but in first-person view
			GUI.Crosshair.Position = UDim2.new(0.5, -1, 0.5, -19)
		end
	end

	local Delta = UserInputService:GetMouseDelta() / CurrentModule.ScopeSensitivity
	local Offset = GUI.Scope.AbsoluteSize.X * 0.5

	if CommonVariables.Scoping and UserInputService.MouseEnabled and UserInputService.KeyboardEnabled then --For pc version
		GUI.Scope.Position = UDim2.new(0, Springs.Scope.p.X + (Springs.Knockback.p.Y * 1000), 0, Springs.Scope.p.Y + (Springs.Knockback.p.X * 200))
		Springs.Scope.t = Vector3.new(Mouse.X - Offset - Delta.X, Mouse.Y - Offset - Delta.Y, 0)
	elseif CommonVariables.Scoping and UserInputService.TouchEnabled and not UserInputService.MouseEnabled and not UserInputService.KeyboardEnabled then --For mobile version, but in first-person view
		GUI.Scope.Position = UDim2.new(0, Springs.Scope.p.X + (Springs.Knockback.p.Y * 1000), 0, Springs.Scope.p.Y + (Springs.Knockback.p.X * 200))
		Springs.Scope.t = Vector3.new(GUI.Crosshair.Center.AbsolutePosition.X - Offset - Delta.X, GUI.Crosshair.Center.AbsolutePosition.Y - Offset - Delta.Y, 0)
	end

	GUI.Scope.Visible = CommonVariables.Scoping
	if not CommonVariables.Scoping then
		--CurrentCrosshair.Visible = true
		Springs.Scope.t = Vector3.new(600, 200, 0)
	else
		--CurrentCrosshair.Visible = false
	end

	if Module.DirectShootingAt == "None" then
		UpdateCrosshair()
	else
		local FirePointObject = HandleToFire:FindFirstChild("GunFirePoint"..CurrentFireMode)
		if FirePointObject ~= nil then
			local Position, _ = Camera:WorldToScreenPoint((FirePointObject.WorldCFrame * CFrame.new(0, 0, -5000)).p)
			if Module.DirectShootingAt == "Both" then
				GUI.Crosshair.Position = UDim2.fromOffset(Position.X, Position.Y)
			else
				if Module.DirectShootingAt == "FirstPerson" then
					if (Camera.Focus.p - Camera.CoordinateFrame.p).Magnitude <= 2 then
						GUI.Crosshair.Position = UDim2.fromOffset(Position.X, Position.Y)
					else
						UpdateCrosshair()
					end
				elseif Module.DirectShootingAt == "ThirdPerson" then
					if (Camera.Focus.p - Camera.CoordinateFrame.p).Magnitude > 2 then
						GUI.Crosshair.Position = UDim2.fromOffset(Position.X, Position.Y)
					else
						UpdateCrosshair()
					end
				end
			end			
		else
			UpdateCrosshair()
		end
	end

	local Size = Springs.CrossSpring.p * 4 * Springs.CrossScale.p
	GUI.Crosshair.Size = UDim2.new(0, Size, 0, Size)

	--Radar and target marker

	if CommonVariables.Radar then
		CommonVariables.Radar.Position = CurrentModule.StayInCenter and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(0, GUI.Crosshair.Center.AbsolutePosition.X, 0, GUI.Crosshair.Center.AbsolutePosition.Y)
	end

	if AddressTableValue("Homing", CurrentModule) and CurrentModule.LockOnOnHovering then
		local TargetEntity, TargetHumanoid, TargetTorso = FindNearestEntity()
		if TargetEntity and TargetHumanoid and TargetTorso then
			LockedEntity = TargetEntity
			TargetMarker.Parent = GUI
			TargetMarker.Adornee = TargetTorso
			TargetMarker.Enabled = true
		else
			LockedEntity = nil
			TargetMarker.Enabled = false
			TargetMarker.Parent = nil
			TargetMarker.Adornee = nil
		end
	end

	--Motion beam

	if CurrentModule.ProjectileMotion then
		if CommonVariables.Beam and CommonVariables.Attach0 and CommonVariables.Attach1 then
			local Position = Get3DPosition2()
			local cframe = CFrame.new(HandleToFire:FindFirstChild("GunFirePoint"..CurrentFireMode).WorldPosition, Position)
			local direction	= cframe.LookVector

			if direction then
				ProjectileMotion.UpdateProjectilePath(CommonVariables.Beam, CommonVariables.Attach0, CommonVariables.Attach1, HandleToFire:FindFirstChild("GunFirePoint"..CurrentFireMode).WorldPosition, direction * AddressTableValue("BulletSpeed", CurrentModule), 3, AddressTableValue("Acceleration", CurrentModule))
			end		
		end
	end

	--Cooldown

	if CurrentModule.BatteryEnabled then
		CurrentVariables.ElapsedCooldownTime = CurrentVariables.ElapsedCooldownTime + dt
		if CurrentVariables.ElapsedCooldownTime >= CurrentModule.CooldownTime then
			CurrentVariables.ElapsedCooldownTime = 0
			if not CommonVariables.Down and not CommonVariables.Overheated and CommonVariables.CanBeCooledDown and CurrentVariables.Heat > 0 then
				CurrentVariables.Heat = math.clamp(CurrentVariables.Heat - CurrentModule.CooldownRate, 0, CurrentModule.MaxHeat)
				UpdateGUI()
			end
		end
	end

	--Camera

	Camera.CoordinateFrame = Camera.CoordinateFrame * CFrame.Angles(Springs.CameraSpring.p.X * (dt * 60), Springs.CameraSpring.p.Y * (dt * 60), Springs.CameraSpring.p.Z * (dt * 60))

	if Module.ThirdPersonADS then
		if CommonVariables.AimDown and ((Camera.Focus.p - Camera.CoordinateFrame.p).Magnitude <= 1) then
			Player.CameraMode = Enum.CameraMode.LockFirstPerson
		end
	end

	--Smoke trail

	CommonVariables.ElapsedTime = CommonVariables.ElapsedTime + dt
	if CommonVariables.ElapsedTime >= 1 then
		CommonVariables.ElapsedTime = 0
		CommonVariables.CurrentRate = CommonVariables.CurrentRate - CommonVariables.LastRate
		CommonVariables.LastRate = CommonVariables.CurrentRate
	end

	--2D Ammo counter

	local Drag = Module.Drag ^ dt
	for casing, data in pairs(CommonVariables.Casings) do
		if casing.Parent then
			data.Vel = (data.Vel * Drag) + Module.Gravity * dt
			data.Pos = data.Pos + data.Vel * dt
			data.RotVel = data.RotVel * Drag
			data.Rot = data.Rot + data.RotVel * dt
			casing.Position = UDim2.new(0, data.Pos.X, 0, data.Pos.Y)
			casing.Rotation = data.Rot
			if casing.AbsolutePosition.Y > Killzone then
				casing:Destroy()
				CommonVariables.CasingCount = CommonVariables.CasingCount - 1
				CommonVariables.Casings[casing] = nil
			end
		else
			CommonVariables.CasingCount = CommonVariables.CasingCount - 1
			CommonVariables.Casings[casing] = nil
		end
	end

	--Lock-on scanner

	if CurrentModule.HoldAndReleaseEnabled and CurrentModule.LockOnScan then
		CurrentModule.OnScannerRender(CommonVariables.Radar, dt)
	end

	--Animations

	if CurrentAnimTable.ChargingAnim and CurrentAnimTable.AimChargingAnim then
		CurrentAnimTable.ChargingAnim:AdjustWeight(CommonVariables.AimDown and 0 or 1)
		CurrentAnimTable.AimChargingAnim:AdjustWeight(CommonVariables.AimDown and 1 or 0)
	end
end

function SetAnimationTrack(AnimationName, Action, Speed, FadeTime, WhenToSet)
	local AnimationTrack = CurrentAnimTable[AnimationName]
	if AnimationName == "AimFireAnim" then
		AnimationTrack = CurrentAimFireAnim
	elseif AnimationName == "FireAnim" then
		AnimationTrack = CurrentFireAnim
	elseif AnimationName == "AimLastFireAnim" then
		AnimationTrack = CurrentAimLastFireAnim
	elseif AnimationName == "LastFireAnim" then
		AnimationTrack = CurrentLastFireAnim
	elseif AnimationName == "ShotgunPumpinAnim" then
		AnimationTrack = CurrentShotgunPumpinAnim
	elseif AnimationName == "InspectAnim" then
		AnimationTrack = (CurrentVariables.Mag <= 0) and CurrentAnimTable.EmptyInspectAnim or CurrentAnimTable.InspectAnim
	end
	if AnimationTrack then
		local CanSet = true
		if WhenToSet then
			if WhenToSet == "IsPlaying" then
				CanSet = AnimationTrack.IsPlaying
			else
				CanSet = not AnimationTrack.IsPlaying
			end
		end
		if CanSet then
			if Action == "Play" then
				AnimationTrack:Play(FadeTime, nil, Speed)
			else
				AnimationTrack:Stop(FadeTime)
			end
		end
	end
end

function SetFireSoundLoopEnabled(Id, Enabled)
	if CurrentModule.ShouldLoop then
		local FireSound = HandleToFire[CurrentFireMode]:FindFirstChild(AddressTableValue("FireSound", CurrentModule))
		if FireSound and FireSound:IsA("Sound") then
			gunEvent:Fire("PlayAudio",
				{
					Instance = FireSound,
					Origin = HandleToFire:FindFirstChild("GunMuzzlePoint"..CurrentFireMode),
					Echo = CurrentModule.EchoEffect,
					Silenced = CurrentModule.SilenceEffect,
					LoopData = {
						Enabled = Enabled,
						Id = Id
					}
				}, nil, true)
		end	
	end
end

function VisibleMuzz(MuzzlePointObject, Enabled)
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

function MarkHit(ClientModule, IsHeadshot)
	if ClientModule.HitmarkerEnabled then
		if IsHeadshot then
			GUI.Crosshair.Hitmarker.ImageColor3 = ClientModule.HitmarkerColorHS
			GUI.Crosshair.Hitmarker.ImageTransparency = 0
			TweenService:Create(GUI.Crosshair.Hitmarker, TweenInfo.new(ClientModule.HitmarkerFadeTimeHS, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {ImageTransparency = 1}):Play()
		else
			GUI.Crosshair.Hitmarker.ImageColor3 = ClientModule.HitmarkerColor
			GUI.Crosshair.Hitmarker.ImageTransparency = 0
			TweenService:Create(GUI.Crosshair.Hitmarker, TweenInfo.new(ClientModule.HitmarkerFadeTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {ImageTransparency = 1}):Play()
		end
		local MarkerSound = GUI.Crosshair.MarkerSound:Clone()
		MarkerSound.Name = "MarkerSoundClone"
		MarkerSound.SoundId = "rbxassetid://"..ClientModule.HitmarkerSoundIDs[math.random(1, #ClientModule.HitmarkerSoundIDs)]
		MarkerSound.PlaybackSpeed = IsHeadshot and ClientModule.HitmarkerSoundPitchHS or ClientModule.HitmarkerSoundPitch
		MarkerSound.Parent = GUI.Crosshair
		MarkerSound:Play()
		Debris:AddItem(MarkerSound, 1)
	end
end

function EjectShell(ShootingHandle, TempModule)
	if AddressTableValue("BulletShellEnabled", TempModule) then
		if AddressTableValue("BulletShellParticles", TempModule) then
			local ShellEjectParticlePoint = ShootingHandle:FindFirstChild("ShellEjectParticlePoint"..CurrentFireMode)
			local ShellEjectEffect = GunVisualEffects:FindFirstChild(AddressTableValue("ShellEjectEffect", TempModule))
			if ShellEjectParticlePoint and ShellEjectEffect then
				for i, v in pairs(ShellEjectEffect:GetChildren()) do
					if v.ClassName == "ParticleEmitter" then
						local Count = 1
						local Particle = v:Clone()
						Particle.Parent = ShellEjectParticlePoint
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
		end
		local RadomizeRotVelocity = AddressTableValue("RadomizeRotVelocity", TempModule)
		local EjectPoint = ShootingHandle:FindFirstChild("ShellEjectPoint"..CurrentFireMode)
		if not EjectPoint then
			return
		end
		local Shell = Miscs.BulletShells[AddressTableValue("BulletShellType", TempModule)]:Clone()
		Shell.CFrame = EjectPoint.WorldCFrame
		Shell.CanCollide = AddressTableValue("AllowCollide", TempModule)
		Shell.Velocity = EjectPoint.WorldCFrame.LookVector * AddressTableValue("BulletShellVelocity", TempModule)
		Shell.RotVelocity = (RadomizeRotVelocity and EjectPoint.WorldCFrame.XVector or EjectPoint.WorldCFrame.LookVector) * AddressTableValue("BulletShellRotVelocity", TempModule)
		Shell.Parent = Camera
		if AddressTableValue("BulletShellHitSoundEnabled", TempModule) then
			local BulletShellHitSoundIDs = AddressTableValue("BulletShellHitSoundIDs", TempModule)
			local BulletShellHitSoundVolume = AddressTableValue("BulletShellHitSoundVolume", TempModule)
			local BulletShellHitSoundPitchMin = AddressTableValue("BulletShellHitSoundPitchMin", TempModule)
			local BulletShellHitSoundPitchMax = AddressTableValue("BulletShellHitSoundPitchMax", TempModule)
			local TouchedConnection = nil
			TouchedConnection = Shell.Touched:Connect(function(Hit)
				if not Hit:IsDescendantOf(Character) then
					local Sound = Instance.new("Sound")
					Sound.SoundId = "rbxassetid://"..BulletShellHitSoundIDs[math.random(1, #BulletShellHitSoundIDs)]
					Sound.PlaybackSpeed = Random.new():NextNumber(BulletShellHitSoundPitchMin, BulletShellHitSoundPitchMax)
					Sound.Volume = BulletShellHitSoundVolume
					Sound.Parent = Shell
					Sound:Play()					
					TouchedConnection:Disconnect()
					TouchedConnection = nil
				end
			end)
		end
		Debris:AddItem(Shell, AddressTableValue("DisappearTime", TempModule))
	end
end

function CreateCasing(ObjRot, Pos, Size, Vel, Type, Shockwave)
	local MaxedOut = CommonVariables.CasingCount >= Module.MaxCount
	if MaxedOut and Module.RemoveOldAtMax and math.random() then
		--This is the best method I can figure for removing a random item from a dictionary of known length
		local RemoveCoutndown = math.random(1, Module.MaxCount)
		for casing, _ in pairs(CommonVariables.Casings) do
			RemoveCoutndown = RemoveCoutndown - 1
			if RemoveCoutndown <= 0 then
				casing:Destroy()
				CommonVariables.CasingCount = CommonVariables.CasingCount - 1
				CommonVariables.Casings[casing] = nil
				MaxedOut = CommonVariables.CasingCount >= Module.MaxCount
				break
			end
		end
	end
	if not MaxedOut then
		CommonVariables.CasingCount = CommonVariables.CasingCount + 1
		local Rot = ObjRot --math.random() * 360
		local XCenter = Pos.X + (Size.X / 2)
		local YCenter = Pos.Y + (Size.Y / 2)
		local Data = {
			RotVel = (math.random() * 2 - 1) * Module.MaxRotationSpeed,
			Rot = Rot,
			Pos = (Pos and Vector2.new(XCenter, YCenter) or Vector2.new(0, 0)) + TopbarOffset,
			Vel = Vel or Vector2.new(0, 0),
		}
		local Casing = GUI.MagCartridge.UIGridLayout.Shell
		if Type == "Bullet" then
			Casing = GUI.MagCartridge.UIGridLayout.Template
		end
		local Clone = Casing:Clone()
		Clone.Rotation = Rot
		CommonVariables.Casings[Clone] = Data
		Clone.Parent = GUI
		if Shockwave then
			Thread:Spawn(function()
				local ShockwaveClone = GUI.MagCartridge.UIGridLayout.Shockwave:Clone()
				local Degree = math.rad(math.random(360))
				ShockwaveClone.Position = UDim2.new(0, XCenter, 0, YCenter)
				ShockwaveClone.Rotation = math.deg(Degree)
				ShockwaveClone.Parent = GUI
				local Tween = TweenService:Create(ShockwaveClone, TweenInfo.new(0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Size = UDim2.new(0, 50, 0, 50), ImageTransparency = 1})
				Tween:Play()
				Tween.Completed:Wait()
				ShockwaveClone:Destroy()				
			end)
		end
	end
end

function Fire(ShootingHandle, MousePosition, FireDirections, TempModule, ModNames, Target, FirstShot)
	--This code block manages one-time, looped or last-shot fire animations
	if (CurrentVariables.Mag - AddressTableValue("AmmoCost", TempModule)) <= 0 then
		if CommonVariables.AimDown then
			if CurrentAimLastFireAnim then
				if CurrentAimFireAnim and CurrentAimFireAnim.Looped then
					SetAnimationTrack("AimFireAnim", "Stop", nil, 0)
				end
				SetAnimationTrack("AimLastFireAnim", "Play", CurrentAimLastFireAnimationSpeed, 0.05)
			else
				if CurrentAimFireAnim then
					if CurrentFireAnim and CurrentFireAnim.Looped then
						SetAnimationTrack("FireAnim", "Stop", nil, 0)
					end
					SetAnimationTrack("AimFireAnim", "Play", CurrentAimFireAnimationSpeed, 0.05, CurrentAimFireAnim.Looped and "IsNotPlaying" or nil)
				else
					if CurrentLastFireAnim then
						if CurrentFireAnim and CurrentFireAnim.Looped then
							SetAnimationTrack("FireAnim", "Stop", nil, 0)
						end
						SetAnimationTrack("LastFireAnim", "Play", CurrentLastFireAnimationSpeed, 0.05)
					else
						SetAnimationTrack("FireAnim", "Play", CurrentFireAnimationSpeed, 0.05, (CurrentFireAnim and CurrentFireAnim.Looped) and "IsNotPlaying" or nil)
					end	
				end
			end
		else
			if CurrentAimFireAnim and CurrentAimFireAnim.Looped then
				SetAnimationTrack("AimFireAnim", "Stop", nil, 0)
			end
			if CurrentLastFireAnim then
				if CurrentFireAnim and CurrentFireAnim.Looped then
					SetAnimationTrack("FireAnim", "Stop", nil, 0)
				end
				SetAnimationTrack("LastFireAnim", "Play", CurrentLastFireAnimationSpeed, 0.05)
			else
				SetAnimationTrack("FireAnim", "Play", CurrentFireAnimationSpeed, 0.05, (CurrentFireAnim and CurrentFireAnim.Looped) and "IsNotPlaying" or nil)
			end
		end
	else
		if CurrentAimFireAnim and CommonVariables.AimDown then
			if CurrentFireAnim and CurrentFireAnim.Looped then
				SetAnimationTrack("FireAnim", "Stop", nil, 0)
			end
			SetAnimationTrack("AimFireAnim", "Play", CurrentAimFireAnimationSpeed, 0.05, CurrentAimFireAnim.Looped and "IsNotPlaying" or nil)
		else
			if CurrentAimFireAnim and CurrentAimFireAnim.Looped then
				SetAnimationTrack("AimFireAnim", "Stop", nil, 0)
			end
			SetAnimationTrack("FireAnim", "Play", CurrentFireAnimationSpeed, 0.05, (CurrentFireAnim and CurrentFireAnim.Looped) and "IsNotPlaying" or nil)
		end
	end
	--
	SetAnimationTrack("MinigunRevUpAnim", "Stop")
	local CanPlay = true
	if TempModule.LockOnScan and TempModule.InstaBurst then
		CanPlay = FirstShot
	end
	local FireSound = ShootingHandle[CurrentFireMode]:FindFirstChild(AddressTableValue("FireSound", TempModule))
	if CanPlay and FireSound and not TempModule.ShouldLoop then
		local Track = FireSound
		if FireSound:IsA("Folder") then
			local Tracks = FireSound:GetChildren()
			local Chosen = math.random(1, #Tracks)
			Track = Tracks[Chosen]
		end
		if Track ~= nil then
			gunEvent:Fire("PlayAudio",
				{
					Instance = Track,
					Origin = ShootingHandle:FindFirstChild("GunMuzzlePoint"..CurrentFireMode),
					Echo = TempModule.EchoEffect,
					Silenced = TempModule.SilenceEffect
				},
				(TempModule.LowAmmo and CurrentVariables.Mag <= TempModule.AmmoPerMag / 5) and {
					CurrentAmmo = CurrentVariables.Mag,
					AmmoPerMag = TempModule.AmmoPerMag,
					Instance = ShootingHandle[CurrentFireMode]:FindFirstChild(AddressTableValue("LowAmmoSound", TempModule)),
					RaisePitch = TempModule.RaisePitch
				} or nil, true)
		end
	end	
	local Misc = {
		ChargeLevel = CurrentVariables.ChargeLevel,
		LockedEntity = Target or LockedEntity,
		MousePosition = MousePosition,
		ModuleName = TempModule.ModuleName,
		ModNames = ModNames,
		FirstShot = FirstShot
	}
	gunEvent:Fire("VisualizeBullet",
		Tool,
		ShootingHandle,
		FireDirections,
		ShootingHandle:FindFirstChild("GunFirePoint"..CurrentFireMode),
		ShootingHandle:FindFirstChild("GunMuzzlePoint"..CurrentFireMode),
		Misc,
		true)
	local OnClientShootEventName = AddressTableValue("OnClientShootEventName", TempModule)
	if OnClientShootEventName ~= "None" then
		OnClientShootEvents[OnClientShootEventName](
			AddressTableValue("OnClientShootEventData", TempModule),
			Character,
			Tool,
			ShootingHandle,
			FireDirections,
			ShootingHandle:FindFirstChild("GunFirePoint"..CurrentFireMode),
			ShootingHandle:FindFirstChild("GunMuzzlePoint"..CurrentFireMode),
			Misc
		)
	end	
	local CanTrigger = true
	if TempModule.LockOnScan and TempModule.InstaBurst then
		CanTrigger = FirstShot
	end
	if CanTrigger then
		Thread:Spawn(function()
			if TempModule.CameraRecoilingEnabled then
				local Recoil = AddressTableValue("Recoil", TempModule)
				local CurrentRecoil = Recoil * (CommonVariables.AimDown and 1 - TempModule.ADSRecoilRedution or 1)
				local RecoilX = math.rad(CurrentRecoil * Math.Randomize2(TempModule.AngleXMin, TempModule.AngleXMax, TempModule.Accuracy))
				local RecoilY = math.rad(CurrentRecoil * Math.Randomize2(TempModule.AngleYMin, TempModule.AngleYMax, TempModule.Accuracy))
				local RecoilZ = math.rad(CurrentRecoil * Math.Randomize2(TempModule.AngleZMin, TempModule.AngleZMax, TempModule.Accuracy))
				Springs.Knockback:Accelerate(Vector3.new(-RecoilX * TempModule.ScopeKnockbackMultiplier, -RecoilY * TempModule.ScopeKnockbackMultiplier, 0))
				Springs.CameraSpring:Accelerate(Vector3.new(RecoilX, RecoilY, RecoilZ))
				Thread:Wait(0.03)
				Springs.CameraSpring:Accelerate(Vector3.new(-RecoilX, -RecoilY, 0))
			end
		end)
		Springs.CrossSpring:Accelerate(AddressTableValue("CrossExpansion", TempModule))
		if AddressTableValue("SelfKnockback", TempModule) then
			local SelfKnockbackPower = AddressTableValue("SelfKnockbackPower", TempModule)
			local SelfKnockbackMultiplier = AddressTableValue("SelfKnockbackMultiplier", TempModule)
			local SelfKnockbackRedution = AddressTableValue("SelfKnockbackRedution", TempModule)
			local Power = Humanoid:GetState() ~= Enum.HumanoidStateType.Freefall and SelfKnockbackPower * SelfKnockbackMultiplier * (1 - SelfKnockbackRedution) or SelfKnockbackPower * SelfKnockbackMultiplier
			local VelocityMod = (MousePosition - Torso.Position).Unit
			local AirVelocity = Torso.Velocity - Vector3.new(0, Torso.Velocity.Y, 0) + Vector3.new(VelocityMod.X, 0, VelocityMod.Z) * -Power
			local TorsoFly = Instance.new("BodyVelocity")
			TorsoFly.MaxForce = Vector3.new(math.huge, 0, math.huge)
			TorsoFly.Velocity = AirVelocity
			TorsoFly.Parent = Torso
			Torso.Velocity = Torso.Velocity + Vector3.new(0, VelocityMod.Y * 2, 0) * -Power
			Debris:AddItem(TorsoFly, 0.25)		
		end
	end
	local CanTrigger2 = true
	if TempModule.LockOnScan and TempModule.InstaBurst and TempModule.TriggerOnce then
		CanTrigger2 = FirstShot
	end
	if not CanTrigger2 then
		return
	end
	if TempModule.BatteryEnabled then
		CurrentVariables.ShotsForDepletion = CurrentVariables.ShotsForDepletion + 1
		if CurrentVariables.ShotsForDepletion >= TempModule.ShotsForDepletion then
			CurrentVariables.ShotsForDepletion = 0
			UniversalTable.Ammo = math.clamp(UniversalTable.Ammo - Random.new():NextInteger(AddressTableValue("MinDepletion", TempModule), AddressTableValue("MaxDepletion", TempModule)), 0, UniversalTable.MaxAmmo)
		end	
		CurrentVariables.Heat = math.clamp(CurrentVariables.Heat + Random.new():NextInteger(AddressTableValue("HeatPerFireMin", TempModule), AddressTableValue("HeatPerFireMax", TempModule)), 0, TempModule.MaxHeat)
	else							
		local LastMag = CurrentVariables.Mag
		CurrentVariables.Mag = math.clamp(CurrentVariables.Mag - AddressTableValue("AmmoCost", TempModule), 0, TempModule.AmmoPerMag)
		if Module.MagCartridge and not TempModule.BatteryEnabled and TempModule.AmmoPerMag ~= math.huge then
			for i = 0, (LastMag - CurrentVariables.Mag) - 1 do
				local Bullet = GUI.MagCartridge:FindFirstChild(LastMag - i)
				if Module.Ejection then
					local Vel = Random2DDirection(Module.Velocity, math.random(Module.XMin, Module.XMax), math.random(Module.YMin, Module.YMax)) * (math.random() ^ 0.5)
					CreateCasing(Bullet.Rotation, Bullet.AbsolutePosition, Bullet.AbsoluteSize, Vel, "shell", Module.Shockwave)								
				end
				Bullet.Visible = false	
			end
		end
	end
	ChangeMagAndAmmo:FireServer(CurrentFireMode, CurrentVariables.Mag, UniversalTable.Ammo)
	CommonVariables.ShootCounts = CommonVariables.ShootCounts - 1
	if CommonVariables.ShootCounts <= 0 then
		CommonVariables.ShootCounts = TempModule.ShootCounts
	end
	CurrentVariables.ShotID = CurrentVariables.ShotID + 1
	local LastShotID = CurrentVariables.ShotID
	Thread:Spawn(function()
		CommonVariables.CanBeCooledDown = false	
		local Interrupted = false
		local StartTime = os.clock() repeat Thread:Wait() if LastShotID ~= CurrentVariables.ShotID then break end until (os.clock() - StartTime) >= AddressTableValue("TimeBeforeCooldown", TempModule)
		if LastShotID ~= CurrentVariables.ShotID then Interrupted = true end				
		if not Interrupted then
			CommonVariables.CanBeCooledDown = true
		end
	end)
	UpdateGUI()
	if CurrentAnimTable.EmptyIdleAnim and CurrentVariables.Mag <= 0 then
		if CurrentAnimTable.EmptyAimIdleAnim and CommonVariables.AimDown then
			SetAnimationTrack("AimIdleAnim", "Stop")
			SetAnimationTrack("EmptyAimIdleAnim", "Play", TempModule.EmptyAimIdleAnimationSpeed)
		else
			SetAnimationTrack("IdleAnim", "Stop")
			SetAnimationTrack("EmptyIdleAnim", "Play", TempModule.EmptyIdleAnimationSpeed)
		end
	end
end

function CycleHandles()
	CurrentVariables.HandleIndex = CurrentVariables.HandleIndex % #CurrentModule.Handles + 1
	HandleToFire = Tool:FindFirstChild(CurrentModule.Handles[CurrentVariables.HandleIndex], true)

	if #CurrentAnimTable.AimFireAnims > 0 then
		CurrentVariables.AimFireAnimIndex = CurrentVariables.AimFireAnimIndex % #CurrentAnimTable.AimFireAnims + 1
		CurrentAimFireAnim = CurrentAnimTable.AimFireAnims[CurrentVariables.AimFireAnimIndex][1]
		CurrentAimFireAnimationSpeed = CurrentAnimTable.AimFireAnims[CurrentVariables.AimFireAnimIndex][2]							
	end
	if #CurrentAnimTable.FireAnims > 0 then
		CurrentVariables.FireAnimIndex = CurrentVariables.FireAnimIndex % #CurrentAnimTable.FireAnims + 1
		CurrentFireAnim = CurrentAnimTable.FireAnims[CurrentVariables.FireAnimIndex][1]
		CurrentFireAnimationSpeed = CurrentAnimTable.FireAnims[CurrentVariables.FireAnimIndex][2]							
	end
	if #CurrentAnimTable.AimLastFireAnims > 0 then
		CurrentVariables.AimLastFireAnimIndex = CurrentVariables.AimLastFireAnimIndex % #CurrentAnimTable.AimLastFireAnims + 1
		CurrentAimLastFireAnim = CurrentAnimTable.AimLastFireAnims[CurrentVariables.AimLastFireAnimIndex][1]
		CurrentAimLastFireAnimationSpeed = CurrentAnimTable.AimLastFireAnims[CurrentVariables.AimLastFireAnimIndex][2]							
	end
	if #CurrentAnimTable.LastFireAnims > 0 then
		CurrentVariables.LastFireAnimIndex = CurrentVariables.LastFireAnimIndex % #CurrentAnimTable.LastFireAnims + 1
		CurrentLastFireAnim = CurrentAnimTable.LastFireAnims[CurrentVariables.LastFireAnimIndex][1]
		CurrentLastFireAnimationSpeed = CurrentAnimTable.LastFireAnims[CurrentVariables.LastFireAnimIndex][2]							
	end
	if #CurrentAnimTable.ShotgunPumpinAnims > 0 then
		CurrentVariables.ShotgunPumpinAnimIndex = CurrentVariables.ShotgunPumpinAnimIndex % #CurrentAnimTable.ShotgunPumpinAnims + 1
		CurrentShotgunPumpinAnim = CurrentAnimTable.ShotgunPumpinAnims[CurrentVariables.ShotgunPumpinAnimIndex][1]
		CurrentShotgunPumpinAnimationSpeed = CurrentAnimTable.ShotgunPumpinAnims[CurrentVariables.ShotgunPumpinAnimIndex][2]							
	end
end

function SetADS(ForceDisable)
	if not CurrentModule.ADSEnabled then
		return
	end
	local Info
	local function Disable()
		Info = TweenInfo.new(CurrentModule.TweenLengthNAD, CurrentModule.EasingStyleNAD, CurrentModule.EasingDirectionNAD)
		TweenService:Create(Camera, Info, {FieldOfView = 70}):Play()
		SetCrossScale(1)
		if CommonVariables.ActuallyEquipped then
			SetAnimationTrack("AimIdleAnim", "Stop")
			SetAnimationTrack("EmptyAimIdleAnim", "Stop")
			if CurrentAnimTable.EmptyIdleAnim and CurrentVariables.Mag <= 0 then
				SetAnimationTrack("EmptyIdleAnim", "Play", CurrentModule.EmptyIdleAnimationSpeed)
			else
				SetAnimationTrack("IdleAnim", "Play", CurrentModule.IdleAnimationSpeed)
			end
		end
		UserInputService.MouseDeltaSensitivity = CommonVariables.InitialSensitivity
		CommonVariables.AimDown = false
		CommonVariables.Scoping = false
		if CurrentModule.HideCrosshair then
			TweenService:Create(CurrentCrosshair, Info, {GroupTransparency = 0}):Play()
		end
		Player.CameraMode = Enum.CameraMode.Classic
	end
	if ForceDisable then
		Disable()
		return
	end
	if not CommonVariables.Equipped then
		return
	end
	if not CommonVariables.Reloading and not CommonVariables.Overheated and not CommonVariables.HoldDown and not CommonVariables.Switching and not CommonVariables.Alting and not CommonVariables.AimDown and CommonVariables.ActuallyEquipped then
		Info = TweenInfo.new(CurrentModule.TweenLength, CurrentModule.EasingStyle, CurrentModule.EasingDirection)
		TweenService:Create(Camera, Info, {FieldOfView = CurrentModule.ADSFieldOfView}):Play()
		SetCrossScale(CurrentModule.ADSCrossScale)
		SetAnimationTrack("InspectAnim", "Stop", nil, 0)
		if CurrentAnimTable.AimIdleAnim then
			SetAnimationTrack("IdleAnim", "Stop")
			SetAnimationTrack("EmptyIdleAnim", "Stop")
			if CurrentAnimTable.EmptyAimIdleAnim and CurrentVariables.Mag <= 0 then
				SetAnimationTrack("EmptyAimIdleAnim", "Play", CurrentModule.EmptyAimIdleAnimationSpeed)
			else
				SetAnimationTrack("AimIdleAnim", "Play", CurrentModule.AimIdleAnimationSpeed)
			end
		end
		UserInputService.MouseDeltaSensitivity = CommonVariables.InitialSensitivity * CurrentModule.ADSMouseSensitivity
		CommonVariables.AimDown = true
		if CurrentModule.HideCrosshair then
			TweenService:Create(CurrentCrosshair, Info, {GroupTransparency = 1}):Play()
		end
		if not Module.ThirdPersonADS then
			Player.CameraMode = Enum.CameraMode.LockFirstPerson
		else
			if Module.ForceFirstPerson then
				Player.CameraMode = Enum.CameraMode.LockFirstPerson
			end
		end
		if CurrentModule.ADSType == "Sniper" then
			local StartTime = os.clock() repeat Thread:Wait() if not (CommonVariables.ActuallyEquipped or CommonVariables.AimDown) then break end until (os.clock() - StartTime) >= CurrentModule.ScopeDelay
			if CommonVariables.ActuallyEquipped and CommonVariables.AimDown then
				GUI.Scope.ZoomSound:Play()
				CommonVariables.Scoping = true
			end
		end
	else
		Disable()
	end
end

function SetChargeEffect(ChargeLevel, ChargeEffect)
	gunEvent:Fire("VisualizeCharge", ChargeEffect, "Begin", Character, Tool, HandleToFire, ChargeLevel, true)
end

function RemoveStuff(StopSounds)
	for i, v in pairs(CommonVariables.KeyframeConnections) do
		v:Disconnect()
		table.remove(CommonVariables.KeyframeConnections, i)
	end
	LockedEntity = nil
	TargetMarker.Enabled = false
	TargetMarker.Parent = script
	TargetMarker.Adornee = nil
	if CommonVariables.Radar then
		CommonVariables.Radar:Destroy()
		CommonVariables.Radar = nil
	end
	if CommonVariables.Beam then
		CommonVariables.Beam:Destroy()
		CommonVariables.Beam = nil
	end
	if CommonVariables.Attach0 then
		CommonVariables.Attach0:Destroy()
		CommonVariables.Attach0 = nil
	end
	if CommonVariables.Attach1 then
		CommonVariables.Attach1:Destroy()
		CommonVariables.Attach1 = nil
	end
	for _, a in pairs(CurrentAnimTable) do
		if typeof(a) == "table" then
			for _, a2 in pairs(a) do
				--SetAnimationTrack(a2[1].Animation.Name, "Stop", nil, nil, "IsPlaying")
				if a2[1].IsPlaying then
					a2[1]:Stop()
				end
			end
		else
			--SetAnimationTrack(a.Animation.Name, "Stop", nil, nil, "IsPlaying")
			if a.IsPlaying then
				a:Stop()
			end
		end 
	end
	if StopSounds then
		for _, h in pairs(CurrentModule.Handles) do
			local handle = Tool:FindFirstChild(h, true)
			if handle then
				for _, s in pairs(handle[CurrentFireMode]:GetChildren()) do
					if s:IsA("Sound") and s.IsPlaying then
						s:Stop()
					end 
				end
			end
		end
	end
end

function Overheat()
	if CommonVariables.ActuallyEquipped and CommonVariables.Enabled and not CommonVariables.Overheated and CurrentVariables.Heat >= CurrentModule.MaxHeat then
		CommonVariables.Overheated = true
		SetAnimationTrack("InspectAnim", "Stop", nil, 0)
		SetADS(true)
		UpdateGUI()
		if CommonVariables.ActuallyEquipped then
			SetAnimationTrack("OverheatAnim", "Play", CurrentModule.OverheatAnimationSpeed)
			HandleToFire[CurrentFireMode].OverheatSound:Play()
			gunEvent:Fire("VisualizeOverheat", CurrentModule.OverheatEffect, "Begin", Character, Tool, HandleToFire, true)
		end
		--Thread:Wait(CurrentModule.OverheatTime)
		for i = 1, CurrentModule.MaxHeat do
			Thread:Wait(CurrentModule.OverheatTime / CurrentModule.MaxHeat)
			CurrentVariables.Heat = CurrentVariables.Heat - 1
			UpdateGUI()
			if CurrentVariables.Heat == 0 then
				CommonVariables.Overheated = false
				break
			end
		end
		CommonVariables.Overheated = false
		UpdateGUI()
		if CommonVariables.ActuallyEquipped then
			gunEvent:Fire("VisualizeOverheat", CurrentModule.OverheatEffect, "End", Character, Tool, HandleToFire, true)
		end
	end
end

function Reload()
	if CommonVariables.ActuallyEquipped and CommonVariables.Enabled and not CommonVariables.Reloading and (UniversalTable.Ammo > 0 or not (Module.UniversalAmmoEnabled or CurrentModule.LimitedAmmoEnabled)) and CurrentVariables.Mag < CurrentModule.AmmoPerMag then
		CommonVariables.Reloading = true
		SetAnimationTrack("InspectAnim", "Stop", nil, 0)
		SetADS(true)
		UpdateGUI()
		local function PlayIdleAnim()
			SetAnimationTrack("IdleAnim", "Stop")
			SetAnimationTrack("EmptyIdleAnim", "Stop")
			SetAnimationTrack("AimIdleAnim", "Stop")
			SetAnimationTrack("EmptyAimIdleAnim", "Stop")
			if CurrentAnimTable.EmptyIdleAnim and CurrentVariables.Mag <= 0 then
				if CurrentAnimTable.EmptyAimIdleAnim and CommonVariables.AimDown then
					SetAnimationTrack("EmptyAimIdleAnim", "Play", CurrentModule.EmptyAimIdleAnimationSpeed)
				else
					SetAnimationTrack("EmptyIdleAnim", "Play", CurrentModule.EmptyIdleAnimationSpeed)
				end
			else
				if CurrentAnimTable.AimIdleAnim and CommonVariables.AimDown then
					SetAnimationTrack("AimIdleAnim", "Play", CurrentModule.AimIdleAnimationSpeed)
				else
					SetAnimationTrack("IdleAnim", "Play", CurrentModule.IdleAnimationSpeed)
				end
			end
		end
		if CurrentModule.ShotgunReload then
			if CurrentModule.PreShotgunReload then
				if CommonVariables.ActuallyEquipped then
					SetAnimationTrack("PreShotgunReloadAnim", "Play", CurrentModule.PreShotgunReloadAnimationSpeed)
					HandleToFire[CurrentFireMode].PreReloadSound:Play()					
				end
				local StartTime = os.clock() repeat Thread:Wait() if not CommonVariables.ActuallyEquipped or CommonVariables.CanCancelReload then
						if CommonVariables.ActuallyEquipped and CommonVariables.CanCancelReload then
							PlayIdleAnim()
							SetAnimationTrack("PreShotgunReloadAnim", "Stop")
							if HandleToFire[CurrentFireMode].PreReloadSound.Playing then
								HandleToFire[CurrentFireMode].PreReloadSound:Stop()
							end
						end
						break
					end
				until (os.clock() - StartTime) >= CurrentModule.PreShotgunReloadSpeed
				--Thread:Wait(CurrentModule.PreShotgunReloadSpeed)
			end
			for i = 1, (CurrentModule.AmmoPerMag - CurrentVariables.Mag) do
				if CommonVariables.ActuallyEquipped then
					SetAnimationTrack("ShotgunClipinAnim", "Play", CurrentModule.ShotgunClipinAnimationSpeed)
					HandleToFire[CurrentFireMode].ShotgunClipin:Play()					
				end
				local StartTime = os.clock() repeat Thread:Wait() if not CommonVariables.ActuallyEquipped or CommonVariables.CanCancelReload then
						if CommonVariables.ActuallyEquipped and CommonVariables.CanCancelReload then
							PlayIdleAnim()
							SetAnimationTrack("ShotgunClipinAnim", "Stop")
							if HandleToFire[CurrentFireMode].ShotgunClipin.Playing then
								HandleToFire[CurrentFireMode].ShotgunClipin:Stop()
							end
						end
						break
					end
				until (os.clock() - StartTime) >= CurrentModule.ShellClipinSpeed
				--Thread:Wait(CurrentModule.ShellClipinSpeed)
				if CommonVariables.CanCancelReload then
					break
				end
				if CurrentVariables.Mag < CurrentModule.AmmoPerMag then
					if CommonVariables.ActuallyEquipped then
						if (Module.UniversalAmmoEnabled or CurrentModule.LimitedAmmoEnabled) and UniversalTable.MaxAmmo ~= math.huge then
							if UniversalTable.Ammo > 0 then
								CurrentVariables.Mag = CurrentVariables.Mag + 1
								UniversalTable.Ammo = UniversalTable.Ammo - 1
								if Module.MagCartridge and not CurrentModule.BatteryEnabled then
									for i = 1, CurrentVariables.Mag do
										GUI.MagCartridge[i].Visible = true
									end		
								end							
								UpdateGUI()                        
							end
						else
							CurrentVariables.Mag = CurrentVariables.Mag + 1
							UpdateGUI()    
						end
						ChangeMagAndAmmo:FireServer(CurrentFireMode, CurrentVariables.Mag, UniversalTable.Ammo)
					end
				else
					break
				end
				if (Module.UniversalAmmoEnabled or CurrentModule.LimitedAmmoEnabled) and UniversalTable.MaxAmmo ~= math.huge then
					if not CommonVariables.ActuallyEquipped or UniversalTable.Ammo <= 0 then
						break
					end
				else
					if not CommonVariables.ActuallyEquipped then
						break
					end
				end
			end
		end
		if CommonVariables.ActuallyEquipped and not CommonVariables.CanCancelReload then
			if CurrentModule.TacticalReloadAnimationEnabled then
				if CurrentVariables.Mag > 0 then
					SetAnimationTrack("TacticalReloadAnim", "Play", CurrentModule.TacticalReloadAnimationSpeed)
					HandleToFire[CurrentFireMode].TacticalReloadSound:Play()
				else
					SetAnimationTrack("ReloadAnim", "Play", CurrentModule.ReloadAnimationSpeed)
					HandleToFire[CurrentFireMode].ReloadSound:Play()
				end
			else
				SetAnimationTrack("ReloadAnim", "Play", CurrentModule.ReloadAnimationSpeed)
				HandleToFire[CurrentFireMode].ReloadSound:Play()
			end
		end
		local ReloadTime = (CurrentVariables.Mag > 0 and CurrentModule.TacticalReloadAnimationEnabled) and CurrentModule.TacticalReloadTime or CurrentModule.ReloadTime
		local StartTime = os.clock() repeat Thread:Wait() if not CommonVariables.ActuallyEquipped or CommonVariables.CanCancelReload then
				if CommonVariables.ActuallyEquipped and CommonVariables.CanCancelReload then
					PlayIdleAnim()
					SetAnimationTrack("TacticalReloadAnim", "Stop")
					if HandleToFire[CurrentFireMode].TacticalReloadSound.Playing then
						HandleToFire[CurrentFireMode].TacticalReloadSound:Stop()
					end
					SetAnimationTrack("ReloadAnim", "Stop")
					if HandleToFire[CurrentFireMode].ReloadSound.Playing then
						HandleToFire[CurrentFireMode].ReloadSound:Stop()
					end					
				end
				break
			end
		until (os.clock() - StartTime) >= ReloadTime
		--Thread:Wait((CurrentVariables.Mag > 0 and CurrentModule.TacticalReloadAnimationEnabled) and CurrentModule.TacticalReloadTime or CurrentModule.ReloadTime)
		if CommonVariables.ActuallyEquipped and not CommonVariables.CanCancelReload then
			if not CurrentModule.ShotgunReload then	
				if Module.MagCartridge and Module.DropAllRemainingBullets and not CurrentModule.BatteryEnabled then
					for i = 1, CurrentVariables.Mag do
						local Bullet = GUI.MagCartridge:FindFirstChild(i)
						local Vel = Random2DDirection(Module.DropVelocity, math.random(Module.DropXMin, Module.DropXMax), math.random(Module.DropYMin, Module.DropYMax)) * (math.random() ^ 0.5)
						CreateCasing(Bullet.Rotation, Bullet.AbsolutePosition, Bullet.AbsoluteSize, Vel, "Bullet")	
					end	
				end
				if (Module.UniversalAmmoEnabled or CurrentModule.LimitedAmmoEnabled) and UniversalTable.MaxAmmo ~= math.huge then
					local AmmoToUse = math.min(CurrentModule.AmmoPerMag - CurrentVariables.Mag, UniversalTable.Ammo)
					CurrentVariables.Mag = CurrentVariables.Mag + AmmoToUse
					UniversalTable.Ammo = UniversalTable.Ammo - AmmoToUse
				else
					CurrentVariables.Mag = CurrentModule.AmmoPerMag
				end
				ChangeMagAndAmmo:FireServer(CurrentFireMode, CurrentVariables.Mag, UniversalTable.Ammo)
			end
			PlayIdleAnim()
		end
		CommonVariables.Reloading = false
		CommonVariables.CanCancelReload = false
		if Module.MagCartridge and not CurrentModule.BatteryEnabled then
			for i = 1, CurrentVariables.Mag do
				GUI.MagCartridge[i].Visible = true
			end		
		end
		UpdateGUI()
	end
end

function OnHoldingDown()
	if CurrentModule.HoldDownEnabled then
		if not CommonVariables.Reloading and not CommonVariables.Overheated and CommonVariables.ActuallyEquipped and CommonVariables.Enabled then
			if not CommonVariables.HoldDown then
				CommonVariables.HoldDown = true
				SetAnimationTrack("AimIdleAnim", "Stop")
				SetAnimationTrack("IdleAnim", "Stop")
				SetAnimationTrack("HoldDownAnim", "Play", CurrentModule.HoldDownAnimationSpeed)
				SetADS(true)
			else
				CommonVariables.HoldDown = false
				SetAnimationTrack("IdleAnim", "Play", CurrentModule.IdleAnimationSpeed)
				SetAnimationTrack("HoldDownAnim", "Stop")
			end
		end
	end
end

function OnInspecting()
	if not CommonVariables.Reloading and not CommonVariables.Overheated and CommonVariables.ActuallyEquipped and CommonVariables.Enabled and not CommonVariables.AimDown and not CommonVariables.Inspecting and not CommonVariables.Switching and not CommonVariables.Alting and CurrentModule.InspectAnimationEnabled then
		CommonVariables.Inspecting = true
		local AnimationSpeed = CurrentAnimTable.InspectAnim and CurrentModule.InspectAnimationSpeed or 0
		local AnimationLength = CurrentAnimTable.InspectAnim and CurrentAnimTable.InspectAnim.Length or 0
		if CurrentVariables.Mag <= 0 then
			AnimationSpeed = CurrentAnimTable.EmptyInspectAnim and CurrentModule.EmptyInspectAnimationSpeed or (CurrentAnimTable.InspectAnim and CurrentModule.InspectAnimationSpeed or 0)
			AnimationLength = CurrentAnimTable.EmptyInspectAnim and CurrentAnimTable.EmptyInspectAnim.Length or (CurrentAnimTable.InspectAnim and CurrentAnimTable.InspectAnim.Length or 0)
		end
		SetAnimationTrack("InspectAnim", "Play", AnimationSpeed)
		local StartTime = os.clock() repeat Thread:Wait() if not CommonVariables.ActuallyEquipped or CommonVariables.Reloading or CommonVariables.Overheated or not CommonVariables.Enabled or CommonVariables.AimDown or CommonVariables.Switching or CommonVariables.Alting then break end until (os.clock() - StartTime) >= AnimationLength / AnimationSpeed
		CommonVariables.Inspecting = false	
	end
end

function OnSwitching()
	if not CommonVariables.Reloading and not CommonVariables.Overheated and CommonVariables.ActuallyEquipped and CommonVariables.Enabled and not CommonVariables.Switching and not CommonVariables.Alting and CurrentModule.SelectiveFireEnabled then
		CommonVariables.Switching = true
		SetAnimationTrack("InspectAnim", "Stop", nil, 0)
		SetAnimationTrack("SwitchAnim", "Play", CurrentModule.SwitchAnimationSpeed)
		local StartTime = os.clock() repeat Thread:Wait() if not CommonVariables.ActuallyEquipped or CommonVariables.Reloading or CommonVariables.Overheated or not CommonVariables.Enabled then break end until (os.clock() - StartTime) >= CurrentModule.SwitchTime
		CommonVariables.Switching = false
		if CommonVariables.ActuallyEquipped and not CommonVariables.Reloading and not CommonVariables.Overheated and CommonVariables.Enabled then
			HandleToFire[CurrentFireMode].SwitchSound:Play()	
			CurrentVariables.FireMode = CurrentVariables.FireMode % #CurrentVariables.FireModes + 1
			UpdateGUI()
		end	
	end
end

function OnAlting()
	if Module.AltFire and #Setting:GetChildren() > 1 then
		if not CommonVariables.Reloading and not CommonVariables.Overheated and CommonVariables.ActuallyEquipped and CommonVariables.Enabled and not CommonVariables.HoldDown and not CommonVariables.Alting and not CommonVariables.Switching then
			CommonVariables.Alting = true
			SetAnimationTrack("InspectAnim", "Stop", nil, 0)
			SetADS(true)
			SetAnimationTrack("AltAnim", "Play", CurrentModule.AltAnimationSpeed)
			HandleToFire[CurrentFireMode].AltSound:Play()
			local Interrupted = false
			local StartTime = os.clock() repeat Thread:Wait() if not CommonVariables.ActuallyEquipped or CommonVariables.Reloading or CommonVariables.Overheated or not CommonVariables.Enabled then Interrupted = true break end until (os.clock() - StartTime) >= CurrentModule.AltTime
			if Interrupted then
				SetAnimationTrack("AltAnim", "Stop")
				HandleToFire[CurrentFireMode].AltSound:Stop()
			end
			CommonVariables.Alting = false
			if CommonVariables.ActuallyEquipped and not CommonVariables.Reloading and not CommonVariables.Overheated and CommonVariables.Enabled then
				RemoveStuff()

				HandleToFire = Tool:FindFirstChild(CurrentModule.Handles[1], true)

				CommonVariables.CurrentRate = 0
				CommonVariables.LastRate = 0
				CommonVariables.ElapsedTime = 0

				CurrentFireMode = CurrentFireMode % #Settings + 1
				CurrentModule = CommonVariables.SettingModules[CurrentFireMode]
				CurrentVariables = Variables[CurrentFireMode]
				CurrentAnimTable = CommonVariables.Animations[CurrentFireMode]
				CurrentCrosshair = GUI.Crosshair[CurrentFireMode]

				for i, v in pairs(GUI.Crosshair:GetChildren()) do
					if v:IsA("CanvasGroup") then
						v.Visible = (tonumber(v.Name) == CurrentFireMode)
					end
				end

				CommonVariables.ShootCounts = CurrentModule.ShootCounts

				if not Module.UniversalAmmoEnabled then
					UniversalTable = CurrentVariables
				end
				
				CurrentVariables.HandleIndex = 1
				CurrentVariables.FireAnimIndex = 1
				CurrentVariables.LastFireAnimIndex = 1
				CurrentVariables.AimFireAnimIndex = 1
				CurrentVariables.AimLastFireAnimIndex = 1
				CurrentVariables.ShotgunPumpinAnimIndex = 1

				CurrentAimFireAnim = #CurrentAnimTable.AimFireAnims > 0 and CurrentAnimTable.AimFireAnims[1][1] or nil
				CurrentAimFireAnimationSpeed = #CurrentAnimTable.AimFireAnims > 0 and CurrentAnimTable.AimFireAnims[1][2] or nil

				CurrentFireAnim = #CurrentAnimTable.FireAnims > 0 and CurrentAnimTable.FireAnims[1][1] or nil
				CurrentFireAnimationSpeed = #CurrentAnimTable.FireAnims > 0 and CurrentAnimTable.FireAnims[1][2] or nil

				CurrentAimLastFireAnim = #CurrentAnimTable.AimLastFireAnims > 0 and CurrentAnimTable.AimLastFireAnims[1][1] or nil
				CurrentAimLastFireAnimationSpeed = #CurrentAnimTable.AimLastFireAnims > 0 and CurrentAnimTable.AimLastFireAnims[1][2] or nil

				CurrentLastFireAnim = #CurrentAnimTable.LastFireAnims > 0 and CurrentAnimTable.LastFireAnims[1][1] or nil
				CurrentLastFireAnimationSpeed = #CurrentAnimTable.LastFireAnims > 0 and CurrentAnimTable.LastFireAnims[1][2] or nil

				CurrentShotgunPumpinAnim = #CurrentAnimTable.ShotgunPumpinAnims > 0 and CurrentAnimTable.ShotgunPumpinAnims[1][1] or nil
				CurrentShotgunPumpinAnimationSpeed = #CurrentAnimTable.ShotgunPumpinAnims > 0 and CurrentAnimTable.ShotgunPumpinAnims[1][2] or nil

				Springs.Scope.s = CurrentModule.ScopeSwaySpeed
				Springs.Scope.d = CurrentModule.ScopeSwayDamper

				Springs.Knockback.s = CurrentModule.ScopeKnockbackSpeed
				Springs.Knockback.d = CurrentModule.ScopeKnockbackDamper

				Springs.CameraSpring.s	= CurrentModule.RecoilSpeed
				Springs.CameraSpring.d	= CurrentModule.RecoilDamper

				for i, v in pairs(BeamTable) do
					if v then
						v:Destroy()
					end
				end
				table.clear(BeamTable)
				CrosshairPointAttachment:ClearAllChildren()
				LaserBeamEffect = GunVisualEffects:FindFirstChild(CurrentModule.LaserBeamEffect)
				if LaserBeamEffect then
					for i, v in pairs(LaserBeamEffect.HitEffect:GetChildren()) do
						if v.ClassName == "ParticleEmitter" then
							local particle = v:Clone()
							particle.Enabled = true
							particle.Parent = CrosshairPointAttachment
						end
					end
					for i, v in pairs(LaserBeamEffect.LaserBeams:GetChildren()) do
						if v.ClassName == "Beam" then
							local beam = v:Clone()
							table.insert(BeamTable, beam)
						end
					end	
				end

				table.clear(CommonVariables.Keyframes)
				for _, a in pairs(CurrentAnimTable) do
					if typeof(a) == "table" then
						for _, a2 in pairs(a) do
							FindAnimationNameForKeyframe(a2[1])
						end
					else
						FindAnimationNameForKeyframe(a)
					end 
				end
				for _, v in pairs(CommonVariables.Keyframes) do
					table.insert(CommonVariables.KeyframeConnections, v[1]:GetMarkerReachedSignal("AnimationEvents"):Connect(function(keyframeName)
						if v[2][keyframeName] then
							v[2][keyframeName](keyframeName, Tool)
						end
					end))
				end

				if Module.MagCartridge and not CurrentModule.BatteryEnabled and CurrentModule.AmmoPerMag ~= math.huge then
					for _, v in pairs(GUI.MagCartridge:GetChildren()) do
						if not v:IsA("UIGridLayout") then
							v:Destroy()
						end
					end
					for i = 1, CurrentModule.AmmoPerMag do
						local Bullet = GUI.MagCartridge.UIGridLayout.Template:Clone()
						Bullet.Name = i
						Bullet.LayoutOrder = i
						if i > CurrentVariables.Mag then
							Bullet.Visible = false
						end
						Bullet.Parent = GUI.MagCartridge
					end
				end

				CommonVariables.Radar = Scanners.Radars[CurrentModule.Radar]:Clone()
				CommonVariables.Radar.Name = "Scanner"
				CommonVariables.Radar.Parent = GUI

				SmokeTrail:StopEmission()

				if CurrentModule.ProjectileMotion then
					local MotionBeam = GunVisualEffects:FindFirstChild(CurrentModule.MotionBeam)
					if MotionBeam then
						CommonVariables.Beam, CommonVariables.Attach0, CommonVariables.Attach1 = ProjectileMotion.ShowProjectilePath(MotionBeam, HandleToFire:FindFirstChild("GunFirePoint"..CurrentFireMode).WorldPosition, Vector3.new(), 3, AddressTableValue("Acceleration", CurrentModule))
					end
				end

				if CurrentAnimTable.EmptyIdleAnim and CurrentVariables.Mag <= 0 then
					SetAnimationTrack("EmptyIdleAnim", "Play", CurrentModule.EmptyIdleAnimationSpeed)
				else
					SetAnimationTrack("IdleAnim", "Play", CurrentModule.IdleAnimationSpeed)
				end

				UpdateGUI()

				SetCrossSettings(CurrentModule.CrossSize, CurrentModule.CrossSpeed, CurrentModule.CrossDamper)

				if CommonVariables.ActuallyEquipped and Module.AutoReload and CurrentVariables.Mag <= 0 then
					Reload()
				end
			end	
		end
	end
end

function OnFiring()
	local function HasEnoughMag(AmmoCost)
		return CurrentVariables.Mag >= AmmoCost
	end
	if CurrentModule.LaserBeam then
		CommonVariables.Down = true
		if CommonVariables.ActuallyEquipped and CommonVariables.Enabled and CommonVariables.Down and not CommonVariables.Overheated and not CommonVariables.HoldDown and not CommonVariables.Switching and not CommonVariables.Alting and HasEnoughMag(CurrentModule.AmmoCost) and CurrentVariables.Heat < CurrentModule.MaxHeat and Humanoid.Health > 0 and CanShoot() then
			if Module.CancelReload then
				if CommonVariables.Reloading and not CommonVariables.CanCancelReload then
					CommonVariables.CanCancelReload = true
				end
			else
				if CommonVariables.Reloading then
					return
				end
			end			
			CommonVariables.Enabled = false	
			SetAnimationTrack("InspectAnim", "Stop", nil, 0)
			if CurrentModule.LaserBeamStartupDelay > 0 then
				SetAnimationTrack("LaserBeamStartupAnim", "Play", CurrentModule.LaserBeamStartupAnimationSpeed)
				if CommonVariables.ActuallyEquipped and HandleToFire[CurrentFireMode]:FindFirstChild("BeamStartupSound") then
					HandleToFire[CurrentFireMode].BeamStartupSound:Play()
				end
				local Interrupted = false
				local StartTime = os.clock() repeat Thread:Wait() if not CommonVariables.ActuallyEquipped then Interrupted = true break end until (os.clock() - StartTime) >= CurrentModule.LaserBeamStartupDelay
				if Interrupted then
					SetAnimationTrack("LaserBeamStartupAnim", "Stop")
					if HandleToFire[CurrentFireMode]:FindFirstChild("BeamStartupSound") then
						HandleToFire[CurrentFireMode].BeamStartupSound:Stop()
					end
				end
				--Thread:Wait(CurrentModule.LaserBeamStartupDelay)
			end
			local Start = false
			local MuzzlePoint = HandleToFire:FindFirstChild("GunMuzzlePoint"..CurrentFireMode)
			local FirePoint = HandleToFire:FindFirstChild("GunFirePoint"..CurrentFireMode)
			while CommonVariables.ActuallyEquipped and not CommonVariables.Overheated and not CommonVariables.HoldDown and CommonVariables.Down and not CommonVariables.Switching and not CommonVariables.Alting and HasEnoughMag(CurrentModule.AmmoCost) and CurrentVariables.Heat < CurrentModule.MaxHeat and Humanoid.Health > 0 and CanShoot() do
				SetAnimationTrack("LaserBeamLoopAnim", "Play", CurrentModule.LaserBeamLoopAnimationSpeed, nil, "IsNotPlaying")
				if not HandleToFire[CurrentFireMode].BeamLoopSound.Playing or not HandleToFire[CurrentFireMode].BeamLoopSound.Looped then
					HandleToFire[CurrentFireMode].BeamLoopSound:Play()
				end
				local FireDirection = (Get3DPosition2() - FirePoint.WorldPosition).Unit
				local Hit, Pos, Normal, Material = CastRay("Beam", FirePoint.WorldPosition, FireDirection, CurrentModule.LaserBeamRange, IgnoreList, true)
				if not Start then
					Start = true
					HandleToFire[CurrentFireMode].BeamFireSound:Play()
					VisibleMuzz(MuzzlePoint, true)
					VisibleMuzzle:FireServer(MuzzlePoint, true)
					for i, v in pairs(BeamTable) do
						if v then
							v.Parent = HandleToFire
							v.Attachment0 = FirePoint
							v.Attachment1 = CrosshairPointAttachment
						end
					end
					if CurrentModule.LaserTrailEnabled then
						CommonVariables.LaserTrail = Miscs[CurrentModule.LaserTrailShape.."Segment"]:Clone()
						CommonVariables.LaserTrail.CastShadow = false
						if CurrentModule.RandomizeLaserColorIn == "None" then
							CommonVariables.LaserTrail.Color = CurrentModule.LaserTrailColor
						end
						CommonVariables.LaserTrail.Material = CurrentModule.LaserTrailMaterial
						CommonVariables.LaserTrail.Reflectance = CurrentModule.LaserTrailReflectance
						CommonVariables.LaserTrail.Transparency = CurrentModule.LaserTrailTransparency
						CommonVariables.LaserTrail.Size = CurrentModule.LaserTrailShape == "Cone" and Vector3.new(CurrentModule.LaserTrailWidth, (FirePoint.WorldPosition - Pos).Magnitude, CurrentModule.LaserTrailHeight) or Vector3.new((FirePoint.WorldPosition - Pos).Magnitude, CurrentModule.LaserTrailHeight, CurrentModule.LaserTrailWidth)
						CommonVariables.LaserTrail.CFrame = CFrame.new((FirePoint.WorldPosition + Pos) * 0.5, Pos) * (CurrentModule.LaserTrailShape == "Cone" and CFrame.Angles(math.pi / 2, 0, 0) or CFrame.Angles(0, math.pi / 2, 0))
						CommonVariables.LaserTrail.Parent = Camera
					end
				end
				if CommonVariables.LaserTrail then
					if CurrentModule.RandomizeLaserColorIn ~= "None" then
						local Hue = os.clock() % CurrentModule.LaserColorCycleTime / CurrentModule.LaserColorCycleTime
						local Color = Color3.fromHSV(Hue, 1, 1)
						CommonVariables.LaserTrail.Color = Color
					end
					CommonVariables.LaserTrail.Size = CurrentModule.LaserTrailShape == "Cone" and Vector3.new(CurrentModule.LaserTrailWidth, (FirePoint.WorldPosition - Pos).Magnitude, CurrentModule.LaserTrailHeight) or Vector3.new((FirePoint.WorldPosition - Pos).Magnitude, CurrentModule.LaserTrailHeight, CurrentModule.LaserTrailWidth)
					CommonVariables.LaserTrail.CFrame = CFrame.new((FirePoint.WorldPosition + Pos) * 0.5, Pos) * (CurrentModule.LaserTrailShape == "Cone" and CFrame.Angles(math.pi / 2, 0, 0) or CFrame.Angles(0, math.pi / 2, 0))
				end
				if CurrentModule.LightningBoltEnabled then
					local BoltCFrameTable = {}
					local BoltRadius = CurrentModule.BoltRadius
					for i = 1, CurrentModule.BoltCount do
						if i == 1 then
							table.insert(BoltCFrameTable, CFrame.new(0, 0, 0))
						else
							table.insert(BoltCFrameTable, CFrame.new(math.random(-BoltRadius, BoltRadius), math.random(-BoltRadius, BoltRadius), 0))
						end
					end
					for _, v in ipairs(BoltCFrameTable) do
						local Start = (CFrame.new(FirePoint.WorldPosition, FirePoint.WorldPosition + FireDirection) * v).p
						local End = (CFrame.new(Pos, Pos + FireDirection) * v).p
						local Distance = (End - Start).Magnitude
						local LastPos = Start
						local RandomBoltColor = Color3.new(math.random(), math.random(), math.random())
						for i = 0, Distance, 10 do
							local FakeDistance = CFrame.new(Start, End) * CFrame.new(0, 0, -i - 10) * CFrame.new(-2 + (math.random() * CurrentModule.BoltWideness), -2 + (math.random() * CurrentModule.BoltWideness), -2 + (math.random() * CurrentModule.BoltWideness))
							local BoltSegment = Miscs[CurrentModule.BoltShape.."Segment"]:Clone()
							BoltSegment.CastShadow = false
							BoltSegment.CanQuery = false
							BoltSegment.CanTouch = false
							if CurrentModule.RandomizeBoltColorIn ~= "None" then
								if CurrentModule.RandomizeBoltColorIn == "Whole" then
									BoltSegment.Color = RandomBoltColor
								elseif CurrentModule.RandomizeBoltColorIn == "Segment" then
									BoltSegment.Color = Color3.new(math.random(), math.random(), math.random())
								end
							else
								BoltSegment.Color = CurrentModule.BoltColor
							end
							BoltSegment.Material = CurrentModule.BoltMaterial
							BoltSegment.Reflectance = CurrentModule.BoltReflectance
							BoltSegment.Transparency = CurrentModule.BoltTransparency
							if i + 10 > Distance then
								BoltSegment.CFrame = CFrame.new(LastPos, End) * CFrame.new(0, 0, -(LastPos - End).Magnitude / 2) * (CurrentModule.BoltShape == "Cone" and CFrame.Angles(math.pi / 2, 0, 0) or CFrame.Angles(0, math.pi / 2, 0))
							else
								BoltSegment.CFrame = CFrame.new(LastPos, FakeDistance.p) * CFrame.new(0, 0, -(LastPos - FakeDistance.p).Magnitude / 2) * (CurrentModule.BoltShape == "Cone" and CFrame.Angles(math.pi / 2, 0, 0) or CFrame.Angles(0, math.pi / 2, 0))
							end
							if i + 10 > Distance then
								BoltSegment.Size = CurrentModule.BoltShape == "Cone" and Vector3.new(CurrentModule.BoltWidth, (LastPos - End).Magnitude, CurrentModule.BoltHeight) or Vector3.new((LastPos - End).Magnitude, CurrentModule.BoltHeight, CurrentModule.BoltWidth)
							else
								BoltSegment.Size = CurrentModule.BoltShape == "Cone" and Vector3.new(CurrentModule.BoltWidth, (LastPos - FakeDistance.p).Magnitude, CurrentModule.BoltHeight) or Vector3.new((LastPos - FakeDistance.p).Magnitude, CurrentModule.BoltHeight, CurrentModule.BoltWidth)
							end
							BoltSegment.Parent = Camera
							table.insert(CommonVariables.BoltSegments, BoltSegment)
							Thread:Delay(CurrentModule.BoltVisibleTime, function()
								if CurrentModule.BoltFadeTime > 0 then
									local DesiredSize = BoltSegment.Size * (CurrentModule.ScaleBolt and Vector3.new(1, CurrentModule.BoltScaleMultiplier, CurrentModule.BoltScaleMultiplier) or Vector3.new(1, 1, 1))
									local Tween = TweenService:Create(BoltSegment, TweenInfo.new(CurrentModule.BoltFadeTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Transparency = 1, Size = DesiredSize})
									Tween:Play()
									Tween.Completed:Wait()
									local Index = table.find(CommonVariables.BoltSegments, BoltSegment)
									if Index then
										table.remove(CommonVariables.BoltSegments, Index)
									end
									BoltSegment:Destroy()
								else
									local Index = table.find(CommonVariables.BoltSegments, BoltSegment)
									if Index then
										table.remove(CommonVariables.BoltSegments, Index)
									end
									BoltSegment:Destroy()							
								end
							end)
							LastPos = FakeDistance.p
						end
					end
				end

				CrosshairPointAttachment.Parent = Workspace.Terrain
				CrosshairPointAttachment.WorldCFrame = CFrame.new(Pos)
				if CurrentModule.LookAtInput then
					MuzzlePoint.CFrame = MuzzlePoint.Parent.CFrame:toObjectSpace(CFrame.lookAt(MuzzlePoint.WorldPosition, Pos))
					CrosshairPointAttachment.WorldCFrame = CFrame.new(Pos, FireDirection)
				end

				CommonVariables.Misc = {
					ChargeLevel = CurrentVariables.ChargeLevel,
					ModuleName = CurrentModule.ModuleName
				}

				local lastUpdate = CommonVariables.LastUpdate or 0
				local now = os.clock()
				if (now - lastUpdate) > 0.1 then
					CommonVariables.LastUpdate = now
					--Replicate Beam or something
					VisualizeBeam:FireServer(true, {
						Id = GUID,
						Tool = Tool,
						ModuleName = CurrentModule.ModuleName,
						CrosshairPosition = Pos,
						Handle = HandleToFire,
						MuzzlePoint = MuzzlePoint,
						FirePoint = FirePoint,
					})
				end

				local lastUpdate2 = CommonVariables.LastUpdate2 or 0
				local now2 = os.clock()
				if (now2 - lastUpdate2) > CurrentModule.LaserTrailDamageRate then
					CommonVariables.LastUpdate2 = now2
					--Damage hum or something
					if Hit then
						if Hit.Name == "_glass" and CurrentModule.CanBreakGlass then
							ShatterGlass:FireServer(Hit, Pos, FireDirection)
						else
							local Target = Hit:FindFirstAncestorOfClass("Model")
							local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
							local TargetTorso = Target and (Target:FindFirstChild("HumanoidRootPart") or Target:FindFirstChild("Head"))
							if TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso then
								Thread:Spawn(function()
									local TempMisc = CloneTable(CommonVariables.Misc)
									TempMisc["ClientHitSize"] = Hit.Size
									InflictTarget:FireServer("GunLaser", Tool, Hit, CreatePacket(TempMisc))
								end)
								MarkHit(CurrentModule)
							end
						end
					end
					if CurrentModule.BatteryEnabled then
						CurrentVariables.ShotsForDepletion = CurrentVariables.ShotsForDepletion + 1
						if CurrentVariables.ShotsForDepletion >= CurrentModule.ShotsForDepletion then
							CurrentVariables.ShotsForDepletion = 0
							UniversalTable.Ammo = math.clamp(UniversalTable.Ammo - Random.new():NextInteger(CurrentModule.MinDepletion, CurrentModule.MaxDepletion), 0, UniversalTable.MaxAmmo)
						end	
						CurrentVariables.Heat = math.clamp(CurrentVariables.Heat + Random.new():NextInteger(CurrentModule.HeatPerFireMin, CurrentModule.HeatPerFireMax), 0, CurrentModule.MaxHeat)
					else
						local LastMag = CurrentVariables.Mag
						CurrentVariables.Mag = math.clamp(CurrentVariables.Mag - CurrentModule.AmmoCost, 0, CurrentModule.AmmoPerMag)
						if Module.MagCartridge and not CurrentModule.BatteryEnabled and CurrentModule.AmmoPerMag ~= math.huge then
							for i = 0, (LastMag - CurrentVariables.Mag) - 1 do
								local Bullet = GUI.MagCartridge:FindFirstChild(LastMag - i)
								if Module.Ejection then
									local Vel = Random2DDirection(Module.Velocity, math.random(Module.XMin, Module.XMax), math.random(Module.YMin, Module.YMax)) * (math.random() ^ 0.5)
									CreateCasing(Bullet.Rotation, Bullet.AbsolutePosition, Bullet.AbsoluteSize, Vel, "Shell", Module.Shockwave)								
								end
								Bullet.Visible = false	
							end
						end
					end
					ChangeMagAndAmmo:FireServer(CurrentFireMode, CurrentVariables.Mag, UniversalTable.Ammo)
					CommonVariables.ShootCounts = CommonVariables.ShootCounts - 1
					if CommonVariables.ShootCounts <= 0 then
						CommonVariables.ShootCounts = CurrentModule.ShootCounts
					end
					CurrentVariables.ShotID = CurrentVariables.ShotID + 1
					local LastShotID = CurrentVariables.ShotID
					Thread:Spawn(function()
						CommonVariables.CanBeCooledDown = false	
						local Interrupted = false
						local StartTime = os.clock() repeat Thread:Wait() if LastShotID ~= CurrentVariables.ShotID then break end until (os.clock() - StartTime) >= CurrentModule.TimeBeforeCooldown		
						if LastShotID ~= CurrentVariables.ShotID then Interrupted = true end				
						if not Interrupted then
							CommonVariables.CanBeCooledDown = true
						end
					end)
					UpdateGUI()
				end

				if CommonVariables.LaserTrail and CurrentModule.DamageableLaserTrail then
					local TouchingParts = Workspace:GetPartsInPart(CommonVariables.LaserTrail, RegionParams)
					for _, part in pairs(TouchingParts) do
						if part and part.Parent then
							local Target = part:FindFirstAncestorOfClass("Model")
							local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
							local TargetTorso = Target and (Target:FindFirstChild("HumanoidRootPart") or part.Parent:FindFirstChild("Head"))
							if TargetHumanoid and TargetHumanoid.Health > 0 and TargetHumanoid.Parent ~= Character and TargetTorso then
								if not table.find(CommonVariables.HitHumanoids, TargetHumanoid) then
									table.insert(CommonVariables.HitHumanoids, TargetHumanoid)
									Thread:Spawn(function()
										local TempMisc = CloneTable(CommonVariables.Misc)
										TempMisc["ClientHitSize"] = part.Size
										InflictTarget:FireServer("GunLaser", Tool, part, CreatePacket(TempMisc))
									end)
									MarkHit(CurrentModule)
									if CurrentModule.LaserTrailConstantDamage then
										Thread:Delay(CurrentModule.LaserTrailDamageRate, function()
											local Index = table.find(CommonVariables.HitHumanoids, TargetHumanoid)
											if Index then
												table.remove(CommonVariables.HitHumanoids, Index)
											end
										end)
									end
								end	
							end	
						end
					end
				end				

				CommonVariables.CurrentRate = CommonVariables.CurrentRate + CurrentModule.SmokeTrailRateIncrement

				Thread:Wait()
			end
			if CommonVariables.Misc then
				VisualizeBeam:FireServer(false, {
					Id = GUID,
					Tool = Tool,
					ModuleName = CurrentModule.ModuleName,
				})
				CommonVariables.Misc = nil				
			end
			for i, v in pairs(BeamTable) do
				if v then
					v.Attachment0 = nil
					v.Attachment1 = nil
					v.Parent = nil
				end
			end
			if CommonVariables.LaserTrail then
				Thread:Spawn(function()
					local LastLaserTrail = CommonVariables.LaserTrail
					if CurrentModule.LaserTrailFadeTime > 0 then
						local DesiredSize = LastLaserTrail.Size * (CurrentModule.ScaleLaserTrail and Vector3.new(1, CurrentModule.LaserTrailScaleMultiplier, CurrentModule.LaserTrailScaleMultiplier) or Vector3.new(1, 1, 1))
						local Tween = TweenService:Create(LastLaserTrail, TweenInfo.new(CurrentModule.LaserTrailFadeTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Transparency = 1, Size = DesiredSize})
						Tween:Play()
						Tween.Completed:Wait()
						LastLaserTrail:Destroy()
					else
						LastLaserTrail:Destroy()
					end	
				end)
				CommonVariables.LaserTrail = nil
			end
			if CrosshairPointAttachment then
				CrosshairPointAttachment.Parent = nil
			end
			VisibleMuzz(MuzzlePoint, false)
			VisibleMuzzle:FireServer(MuzzlePoint, false)
			if (CurrentModule.BatteryEnabled and CurrentVariables.Heat >= CurrentModule.MaxHeat or CurrentVariables.Mag <= 0) then
				if CommonVariables.CurrentRate >= CurrentModule.MaximumRate and CurrentModule.SmokeTrailEnabled then
					Thread:Spawn(function()
						SmokeTrail:StopEmission()
						SmokeTrail:EmitSmokeTrail(HandleToFire:FindFirstChild("SmokeTrail"..CurrentFireMode), CurrentModule.MaximumTime)
					end)
				end				
			end
			if HandleToFire[CurrentFireMode].BeamLoopSound.Playing and HandleToFire[CurrentFireMode].BeamLoopSound.Looped then
				HandleToFire[CurrentFireMode].BeamLoopSound:Stop()
			end
			SetAnimationTrack("LaserBeamLoopAnim", "Stop")
			SetAnimationTrack("LaserBeamStartupAnim", "Stop")
			if HandleToFire[CurrentFireMode].BeamFireSound.Playing then
				HandleToFire[CurrentFireMode].BeamFireSound:Stop()
			end
			if CommonVariables.ActuallyEquipped and HandleToFire[CurrentFireMode]:FindFirstChild("BeamEndSound") then
				HandleToFire[CurrentFireMode].BeamEndSound:Play()
			end
			local Overheated = false
			if CommonVariables.ActuallyEquipped then
				if CurrentModule.BatteryEnabled then
					if CurrentVariables.Heat >= CurrentModule.MaxHeat then
						Overheated = true
						CommonVariables.Enabled = true
						Thread:Spawn(Overheat)
					end
				end
			end
			if not Overheated then
				if CommonVariables.ActuallyEquipped then
					SetAnimationTrack("LaserBeamStopAnim", "Play", CurrentModule.LaserBeamStopAnimationSpeed)
				end
				Thread:Wait(CurrentModule.LaserBeamStopDelay)
				CommonVariables.Enabled = true
				if CommonVariables.ActuallyEquipped and Module.AutoReload and CurrentVariables.Mag <= 0 then
					Reload()
				end
			end
		end
	else
		if CurrentModule.ChargedShotAdvanceEnabled then
			CommonVariables.Charging = true
			if CommonVariables.ActuallyEquipped and CommonVariables.Enabled and CommonVariables.Charging and not CommonVariables.Overheated and not CommonVariables.HoldDown and not CommonVariables.Switching and not CommonVariables.Alting and HasEnoughMag(CurrentModule.AmmoCost) and CurrentVariables.Heat < CurrentModule.MaxHeat and Humanoid.Health > 0 and CanShoot() then
				if Module.CancelReload then
					if CommonVariables.Reloading and not CommonVariables.CanCancelReload then
						CommonVariables.CanCancelReload = true
					end
				else
					if CommonVariables.Reloading then
						return
					end
				end
				CommonVariables.Enabled = false
				SetAnimationTrack("InspectAnim", "Stop", nil, 0)
				local ChargingSound = HandleToFire[CurrentFireMode]:FindFirstChild("ChargingSound")
				local StartTime = os.clock()
				local StartTime2
				local Start = false
				local ChargeTime = CurrentModule.AdvancedChargingTime
				if CurrentVariables.ChargeLevelCap == 1 then
					ChargeTime = CurrentModule.Level1ChargingTime
				elseif CurrentVariables.ChargeLevelCap == 2 then
					ChargeTime = CurrentModule.Level2ChargingTime
				end
				while true do
					local DeltaTime = os.clock() - StartTime
					if DeltaTime >= CurrentModule.TimeBeforeAdvancedCharging then
						if not Start then
							Start = true
							StartTime2 = os.clock()
							SetAnimationTrack("ChargingAnim", "Play", CurrentModule.ChargingAnimationSpeed, CurrentModule.ChargingAnimationFadeTime, "IsNotPlaying")
							SetAnimationTrack("AimChargingAnim", "Play", CurrentModule.AimChargingAnimationSpeed, CurrentModule.AimChargingAnimationFadeTime, "IsNotPlaying")
							gunEvent:Fire("VisualizeCharge", CurrentModule.ChargeEffect, "Begin", Character, Tool, HandleToFire, CurrentVariables.ChargeLevel, true)
						end
						local DeltaTime2 = os.clock() - StartTime2
						if CurrentVariables.ChargeLevel == 0 and DeltaTime2 >= CurrentModule.Level1ChargingTime then
							CurrentVariables.ChargeLevel = 1
							SetChargeEffect(CurrentVariables.ChargeLevel, CurrentModule.ChargeEffect)	
						elseif CurrentVariables.ChargeLevel == 1 and DeltaTime2 >= CurrentModule.Level2ChargingTime and CurrentVariables.ChargeLevelCap >= 2 then
							CurrentVariables.ChargeLevel = 2
							SetChargeEffect(CurrentVariables.ChargeLevel, CurrentModule.ChargeEffect)						
						elseif CurrentVariables.ChargeLevel == 2 and DeltaTime2 >= CurrentModule.AdvancedChargingTime and CurrentVariables.ChargeLevelCap == 3 then
							CurrentVariables.ChargeLevel = 3
							SetChargeEffect(CurrentVariables.ChargeLevel, CurrentModule.ChargeEffect)						
						end
						local ChargePercent = math.min(DeltaTime2 / ChargeTime, 1)
						if ChargePercent < 0.5 then --Fade from red to yellow then to green
							GUI.ChargeBar.Fill.BackgroundColor3 = Color3.new(1, ChargePercent * 2, 0)
						else
							GUI.ChargeBar.Fill.BackgroundColor3 = Color3.new(1 - ((ChargePercent - 0.5) / 0.5), 1, 0)
						end
						GUI.ChargeBar.Fill.Size = UDim2.new(ChargePercent, 0, 1, 0)
						if ChargingSound then
							if not ChargingSound.Playing then
								ChargingSound:Play()
							end
							if CurrentModule.ChargingSoundIncreasePitch then
								ChargingSound.PlaybackSpeed = CurrentModule.ChargingSoundPitchRange[1] + (ChargePercent * (CurrentModule.ChargingSoundPitchRange[2] - CurrentModule.ChargingSoundPitchRange[1]))
							end
						end
					end
					Thread:Wait()
					if not CommonVariables.ActuallyEquipped or not CommonVariables.Charging then
						break
					end
				end
				SetAnimationTrack("ChargingAnim", "Stop")
				SetAnimationTrack("AimChargingAnim", "Stop")
				GUI.ChargeBar.Fill.Size = UDim2.new(0, 0, 1, 0)
				if ChargingSound then
					if ChargingSound.Playing then
						ChargingSound:Stop()
					end
					if CurrentModule.ChargingSoundIncreasePitch then
						ChargingSound.PlaybackSpeed = CurrentModule.ChargingSoundPitchRange[1]
					end
				end
				if not CommonVariables.ActuallyEquipped or (not CurrentModule.ShouldFireBeforeCharging and not Start) then
					CurrentVariables.ChargeLevel = 0
					CommonVariables.Enabled = true
				end
				if Start then
					gunEvent:Fire("VisualizeCharge", CurrentModule.ChargeEffect, "End", Character, Tool, HandleToFire, nil, true)
				end
				if (not CurrentModule.ShouldFireBeforeCharging and not Start) then
					return
				end				
				if CommonVariables.ActuallyEquipped and not CommonVariables.Enabled and not CommonVariables.Charging and not CommonVariables.Overheated and not CommonVariables.HoldDown and not CommonVariables.Switching and not CommonVariables.Alting and HasEnoughMag(CurrentModule.AmmoCost) and CurrentVariables.Heat < CurrentModule.MaxHeat and Humanoid.Health > 0 and CanShoot() then
					local ModNames			
					local TempModule = CloneTable(CurrentModule)
					for j, k in pairs(TempModule.Conditions) do
						if ConditionableGunMods[j] and ConditionableGunMods[j](Tool, Humanoid, CurrentVariables.Heat, TempModule.MaxHeat, CurrentVariables.Mag, TempModule.AmmoPerMag, UniversalTable.Ammo, UniversalTable.MaxAmmo, CommonVariables.ShootCounts, CommonVariables.CurrentFireRate) then
							TempModule = SettingModifier(TempModule, {k})
							if not ModNames then
								ModNames = {}
							end
							if not ModNames["Conditions"] then
								ModNames["Conditions"] = {}
							end
							table.insert(ModNames["Conditions"], j)
						end
					end
					local DidShoot = false
					local Playing = false
					local AudioId = "Audio_"..HttpService:GenerateGUID()
					for i = 1, (TempModule.BurstFireEnabled and AddressTableValue("BulletPerBurst", TempModule) or 1) do
						if not CommonVariables.ActuallyEquipped then
							break
						end
						if ModNames and ModNames["ConditionsInIndividualShot"] then
							ModNames["ConditionsInIndividualShot"] = nil
						end
						local TempModule2 = TempModule
						for j, k in pairs(TempModule2.ConditionsInIndividualShot) do
							if ConditionableGunMods[j] and ConditionableGunMods[j](Tool, Humanoid, CurrentVariables.Heat, TempModule2.MaxHeat, CurrentVariables.Mag, TempModule2.AmmoPerMag, UniversalTable.Ammo, UniversalTable.MaxAmmo, CommonVariables.ShootCounts, CommonVariables.CurrentFireRate) then
								TempModule2 = SettingModifier(TempModule2, {k})
								if not ModNames then
									ModNames = {}
								end
								if not ModNames["ConditionsInIndividualShot"] then
									ModNames["ConditionsInIndividualShot"] = {}
								end
								table.insert(ModNames["ConditionsInIndividualShot"], j)
							end
						end
						if not CanShoot() then
							break
						end
						if TempModule2.BatteryEnabled then
							if CurrentVariables.Heat >= TempModule2.MaxHeat then
								break
							end
						else
							if not HasEnoughMag(TempModule2.AmmoCost) then
								break
							end
						end
						if not Playing then
							Playing = true
							SetFireSoundLoopEnabled(AudioId, true)	
						end
						local Directions = {}
						if not TempModule2.ShotgunPump then
							Thread:Spawn(function()
								local StartTime = os.clock() repeat Thread:Wait() if not CommonVariables.ActuallyEquipped then break end until (os.clock() - StartTime) >= TempModule2.BulletShellDelay
								if CommonVariables.ActuallyEquipped then
									EjectShell(HandleToFire, TempModule2)
								end
							end)
						end
						CommonVariables.CurrentRate = CommonVariables.CurrentRate + TempModule2.SmokeTrailRateIncrement
						local Position = Get3DPosition2()
						if ModNames and ModNames["ConditionsInIndividualBullet"] then
							ModNames["ConditionsInIndividualBullet"] = nil
						end
						for ii = 1, (TempModule2.ShotgunEnabled and AddressTableValue("BulletPerShot", TempModule2) or 1) do							
							local BulletId = "Bullet_"..HttpService:GenerateGUID()
							local TempModule3 = TempModule2
							for j, k in pairs(TempModule3.ConditionsInIndividualBullet) do
								if ConditionableGunMods[j] and ConditionableGunMods[j](Tool, Humanoid, CurrentVariables.Heat, TempModule3.MaxHeat, CurrentVariables.Mag, TempModule3.AmmoPerMag, UniversalTable.Ammo, UniversalTable.MaxAmmo, CommonVariables.ShootCounts, CommonVariables.CurrentFireRate) then
									TempModule3 = SettingModifier(TempModule3, {k})
									if not ModNames then
										ModNames = {}
									end
									if not ModNames["ConditionsInIndividualBullet"] then
										ModNames["ConditionsInIndividualBullet"] = {}
										ModNames["ConditionsInIndividualBullet"][BulletId] = {}
									end
									table.insert(ModNames["ConditionsInIndividualBullet"][BulletId], j)
								end
							end

							local Spread = AddressTableValue("Spread", TempModule3)
							local CurrentSpread = Spread * 10 * (CommonVariables.AimDown and 1 - TempModule3.ADSSpreadRedution or 1)
							local cframe = CFrame.new(HandleToFire:FindFirstChild("GunFirePoint"..CurrentFireMode).WorldPosition, Position)

							local SpreadPattern = AddressTableValue("SpreadPattern", TempModule3)
							if AddressTableValue("ShotgunPattern", TempModule3) and #SpreadPattern > 0 then
								local X, Y = SpreadPattern[ii][1], SpreadPattern[ii][2]
								cframe = cframe * CFrame.Angles(math.rad(CurrentSpread * Y / 50), math.rad(CurrentSpread * X / 50), 0)
							else
								cframe = cframe * CFrame.Angles(math.rad(math.random(-CurrentSpread, CurrentSpread) / 50), math.rad(math.random(-CurrentSpread, CurrentSpread) / 50), 0)
							end

							local Direction	= cframe.LookVector
							table.insert(Directions, {Direction, BulletId})
						end
						Fire(HandleToFire, Position, Directions, TempModule2, ModNames)
						if TempModule2.BurstFireEnabled then
							if AddressTableValue("CycleHandles", TempModule2) then
								CycleHandles()
							end
							local BurstRate = AddressTableValue("BurstRate", TempModule2)
							local StartTime = os.clock() repeat Thread:Wait() if not CommonVariables.ActuallyEquipped then break end until (os.clock() - StartTime) >= BurstRate
							--Thread:Wait(BurstRate)
						end
						DidShoot = true
					end
					if CurrentFireAnim and CurrentFireAnim.Looped then
						SetAnimationTrack("FireAnim", "Stop")
					end
					if CurrentAimFireAnim and CurrentAimFireAnim.Looped then
						SetAnimationTrack("AimFireAnim", "Stop")
					end
					if Playing then
						Playing = false
						SetFireSoundLoopEnabled(AudioId, false)
					end
					if DidShoot and not TempModule.ShotgunPump and not (TempModule.BurstFireEnabled and AddressTableValue("CycleHandles", TempModule)) then
						CycleHandles()
					end
					if (TempModule.BatteryEnabled and CurrentVariables.Heat >= TempModule.MaxHeat or CurrentVariables.Mag <= 0) then
						if CommonVariables.CurrentRate >= TempModule.MaximumRate and TempModule.SmokeTrailEnabled then
							Thread:Spawn(function()
								SmokeTrail:StopEmission()
								SmokeTrail:EmitSmokeTrail(HandleToFire:FindFirstChild("SmokeTrail"..CurrentFireMode), TempModule.MaximumTime)
							end)
						end				
					end
					local Overheated = false
					if CommonVariables.ActuallyEquipped then
						if TempModule.BatteryEnabled then
							if CurrentVariables.Heat >= TempModule.MaxHeat then
								Overheated = true
								CurrentVariables.ChargeLevel = 0
								CommonVariables.Enabled = true
								Thread:Spawn(Overheat)
							end
						end
					end
					if not Overheated then
						if DidShoot then
							Thread:Wait(AddressTableValue("FireRate", TempModule))
							if TempModule.ShotgunPump then
								if CommonVariables.ActuallyEquipped then
									SetAnimationTrack("ShotgunPumpinAnim", "Play", CurrentShotgunPumpinAnimationSpeed)
									if HandleToFire[CurrentFireMode]:FindFirstChild("PumpSound") then
										HandleToFire[CurrentFireMode].PumpSound:Play()
									end
									Thread:Spawn(function()
										local StartTime = os.clock() repeat Thread:Wait() if not CurrentVariables.ActuallyEquipped then break end until (os.clock() - StartTime) >= TempModule.BulletShellDelay
										if CurrentVariables.ActuallyEquipped then
											EjectShell(HandleToFire, TempModule)
										end
									end)
								end
								if not (TempModule.BurstFireEnabled and AddressTableValue("CycleHandles", TempModule)) then
									CycleHandles()
								end
								Thread:Wait(TempModule.ShotgunPumpinSpeed)
							end
						end
						CurrentVariables.ChargeLevel = 0
						CommonVariables.Enabled = true
						if CommonVariables.ActuallyEquipped and Module.AutoReload and CurrentVariables.Mag <= 0 then
							Reload()
						end
					end
				end
			end
		elseif CurrentModule.HoldAndReleaseEnabled and not CurrentModule.SelectiveFireEnabled then
			CommonVariables.Charging = true
			if CommonVariables.ActuallyEquipped and CommonVariables.Enabled and CommonVariables.Charging and not CommonVariables.Overheated and not CommonVariables.HoldDown and not CommonVariables.Switching and not CommonVariables.Alting and HasEnoughMag(CurrentModule.AmmoCost) and CurrentVariables.Heat < CurrentModule.MaxHeat and Humanoid.Health > 0 and CanShoot() then
				if Module.CancelReload then
					if CommonVariables.Reloading and not CommonVariables.CanCancelReload then
						CommonVariables.CanCancelReload = true
					end
				else
					if CommonVariables.Reloading then
						return
					end
				end
				CommonVariables.Enabled = false
				SetAnimationTrack("InspectAnim", "Stop", nil, 0)
				local ChargingSound = HandleToFire[CurrentFireMode]:FindFirstChild("ChargingSound")
				local StartTime = os.clock()
				local StartTime2
				local Start = false
				local LockedOnTargets = {}
				local TargetCounts = 0
				local ScanInterval = CurrentModule.ScanRate
				while true do
					if not CurrentModule.LockOnScan then
						local DeltaTime = os.clock() - StartTime
						if DeltaTime >= CurrentModule.TimeBeforeHolding then
							if not Start then
								Start = true
								StartTime2 = os.clock()
								SetAnimationTrack("ChargingAnim", "Play", CurrentModule.ChargingAnimationSpeed, CurrentModule.ChargingAnimationFadeTime, "IsNotPlaying")
								SetAnimationTrack("AimChargingAnim", "Play", CurrentModule.AimChargingAnimationSpeed, CurrentModule.AimChargingAnimationFadeTime, "IsNotPlaying")
								gunEvent:Fire("VisualizeCharge", CurrentModule.HoldChargeEffect, "Begin", Character, Tool, HandleToFire, 0, true)
							end
							local DeltaTime2 = os.clock() - StartTime2
							if not CommonVariables.Charged and DeltaTime2 >= CurrentModule.HoldingTime then
								CommonVariables.Charged = true
								SetChargeEffect(3, CurrentModule.HoldChargeEffect)	
							end
							local ChargePercent = math.min(DeltaTime2 / CurrentModule.HoldingTime, 1)
							if ChargePercent < 0.5 then --Fade from red to yellow then to green
								GUI.ChargeBar.Fill.BackgroundColor3 = Color3.new(1, ChargePercent * 2, 0)
							else
								GUI.ChargeBar.Fill.BackgroundColor3 = Color3.new(1 - ((ChargePercent - 0.5) / 0.5), 1, 0)
							end
							GUI.ChargeBar.Fill.Size = UDim2.new(ChargePercent, 0, 1, 0)
							if ChargingSound then
								if not ChargingSound.Playing then
									ChargingSound:Play()
								end
								if CurrentModule.ChargingSoundIncreasePitch then
									ChargingSound.PlaybackSpeed = CurrentModule.ChargingSoundPitchRange[1] + (ChargePercent * (CurrentModule.ChargingSoundPitchRange[2] - CurrentModule.ChargingSoundPitchRange[1]))
								end
							end
						end
					else
						CommonVariables.Charged = true
						local DeltaTime = os.clock() - StartTime
						if DeltaTime >= CurrentModule.TimeBeforeScan then
							if not Start then
								Start = true
								StartTime2 = os.clock()
								CurrentModule.OnScannerToggle(CommonVariables.Radar, CurrentModule.MaximumTargets, true)
							end
							local DeltaTime2 = os.clock() - StartTime2
							if DeltaTime2 >= ScanInterval then
								StartTime2 = os.clock()
								local TargetEntity, TargetHumanoid, TargetTorso, AlreadyLocked = FindNearestEntity(LockedOnTargets)
								if TargetEntity and TargetHumanoid and TargetTorso then
									if TargetCounts < CurrentModule.MaximumTargets then
										TargetCounts = TargetCounts + 1
										if AlreadyLocked then
											ScanInterval = CurrentModule.ScanRateOnLockedTarget
										else
											ScanInterval = CurrentModule.ScanRate
										end
										CurrentModule.OnScannerUpdate(CommonVariables.Radar, TargetCounts, CurrentModule.MaximumTargets, AlreadyLocked, true)
										local TargetMarkerClone = Scanners.Markers[CurrentModule.Marker]:Clone()
										TargetMarkerClone.Name = "TargetMarker"
										TargetMarkerClone.Parent = GUI
										TargetMarkerClone.Adornee = TargetTorso
										TargetMarkerClone.Enabled = true
										CurrentModule.OnTrackingTarget(TargetMarkerClone)
										table.insert(LockedOnTargets, {TargetEntity = TargetEntity, TargetTorso = TargetTorso, TargetMarker = TargetMarkerClone})										
									end
								end
							end
							if CurrentModule.RemoveTargetsWhenOutbound then
								for i = #LockedOnTargets, 1, -1 do
									if LockedOnTargets[i].TargetEntity and LockedOnTargets[i].TargetTorso then
										if not CheckPartInScanner(LockedOnTargets[i].TargetTorso) then
											TargetCounts = TargetCounts - 1
											CurrentModule.OnScannerUpdate(CommonVariables.Radar, TargetCounts, CurrentModule.MaximumTargets)
											if LockedOnTargets[i].TargetMarker then
												LockedOnTargets[i].TargetMarker:Destroy()
											end
											table.remove(LockedOnTargets, i)	
										end
									else
										TargetCounts = TargetCounts - 1
										CurrentModule.OnScannerUpdate(CommonVariables.Radar, TargetCounts, CurrentModule.MaximumTargets)
										if LockedOnTargets[i].TargetMarker then
											LockedOnTargets[i].TargetMarker:Destroy()
										end
										table.remove(LockedOnTargets, i)	
									end
								end						
							end
						end
					end
					Thread:Wait()
					if not CommonVariables.ActuallyEquipped or not CommonVariables.Charging then
						break
					end
				end
				SetAnimationTrack("ChargingAnim", "Stop")
				SetAnimationTrack("AimChargingAnim", "Stop")
				if not CurrentModule.LockOnScan then
					GUI.ChargeBar.Fill.Size = UDim2.new(0, 0, 1, 0)
					if ChargingSound then
						if ChargingSound.Playing then
							ChargingSound:Stop()
						end
						if CurrentModule.ChargingSoundIncreasePitch then
							ChargingSound.PlaybackSpeed = CurrentModule.ChargingSoundPitchRange[1]
						end
					end
					if Start then
						gunEvent:Fire("VisualizeCharge", CurrentModule.HoldChargeEffect, "End", Character, Tool, HandleToFire, nil, true)
					end
				else
					if CommonVariables.Radar then
						CurrentModule.OnScannerToggle(CommonVariables.Radar, CurrentModule.MaximumTargets, false)
					end
					for i, v in pairs(LockedOnTargets) do
						if v.TargetMarker then
							v.TargetMarker:Destroy()
						end
					end	
				end
				if not CommonVariables.ActuallyEquipped or (CurrentModule.ShouldFireWhenTheresTarget and #LockedOnTargets <= 0) then
					CommonVariables.Charged = false
					CommonVariables.Enabled = true
				end
				if (CurrentModule.ShouldFireWhenTheresTarget and #LockedOnTargets <= 0) then
					return
				end
				if CommonVariables.ActuallyEquipped and not CommonVariables.Enabled and not CommonVariables.Charging and CommonVariables.Charged and not CommonVariables.Overheated and not CommonVariables.HoldDown and not CommonVariables.Switching and not CommonVariables.Alting and HasEnoughMag(CurrentModule.AmmoCost) and CurrentVariables.Heat < CurrentModule.MaxHeat and Humanoid.Health > 0 and CanShoot() then
					CommonVariables.Charged = false
					local ModNames			
					local TempModule = CloneTable(CurrentModule)
					for j, k in pairs(TempModule.Conditions) do
						if ConditionableGunMods[j] and ConditionableGunMods[j](Tool, Humanoid, CurrentVariables.Heat, TempModule.MaxHeat, CurrentVariables.Mag, TempModule.AmmoPerMag, UniversalTable.Ammo, UniversalTable.MaxAmmo, CommonVariables.ShootCounts, CommonVariables.CurrentFireRate) then
							TempModule = SettingModifier(TempModule, {k})
							if not ModNames then
								ModNames = {}
							end
							if not ModNames["Conditions"] then
								ModNames["Conditions"] = {}
							end
							table.insert(ModNames["Conditions"], j)
						end
					end
					local DidShoot = false
					local Playing = false
					local AudioId = "Audio_"..HttpService:GenerateGUID()
					for i = 1, TempModule.LockOnScan and (TargetCounts > 0 and TargetCounts or 1) or (TempModule.BurstFireEnabled and TempModule.BulletPerBurst or 1) do
						if not CommonVariables.ActuallyEquipped then
							break
						end
						if ModNames and ModNames["ConditionsInIndividualShot"] then
							ModNames["ConditionsInIndividualShot"] = nil
						end
						local TempModule2 = TempModule
						for j, k in pairs(TempModule2.ConditionsInIndividualShot) do
							if ConditionableGunMods[j] and ConditionableGunMods[j](Tool, Humanoid, CurrentVariables.Heat, TempModule2.MaxHeat, CurrentVariables.Mag, TempModule2.AmmoPerMag, UniversalTable.Ammo, UniversalTable.MaxAmmo, CommonVariables.ShootCounts, CommonVariables.CurrentFireRate) then
								TempModule2 = SettingModifier(TempModule2, {k})
								if not ModNames then
									ModNames = {}
								end
								if not ModNames["ConditionsInIndividualShot"] then
									ModNames["ConditionsInIndividualShot"] = {}
								end
								table.insert(ModNames["ConditionsInIndividualShot"], j)
							end
						end
						if not CanShoot() then
							break
						end
						if TempModule2.BatteryEnabled then
							if CurrentVariables.Heat >= TempModule2.MaxHeat then
								break
							end
						else
							if not HasEnoughMag(TempModule2.AmmoCost) then
								break
							end
						end
						if not Playing then
							Playing = true
							SetFireSoundLoopEnabled(AudioId, true)
						end
						local FirstShot
						if TempModule2.LockOnScan and TempModule2.InstaBurst and i == 1 then
							FirstShot = true
						end
						local Directions = {}
						if not TempModule2.ShotgunPump then
							Thread:Spawn(function()
								local CanEject = true
								if TempModule2.LockOnScan and TempModule2.InstaBurst then
									CanEject = (i == 1)
								end
								if not CanEject then
									return
								end
								local StartTime = os.clock() repeat Thread:Wait() if not CommonVariables.ActuallyEquipped then break end until (os.clock() - StartTime) >= TempModule2.BulletShellDelay
								if CommonVariables.ActuallyEquipped then
									EjectShell(HandleToFire, TempModule2)
								end
							end)
						end
						CommonVariables.CurrentRate = CommonVariables.CurrentRate + TempModule2.SmokeTrailRateIncrement
						local Position = (TempModule2.LockOnScan and #LockedOnTargets > 0) and (LockedOnTargets[i].TargetTorso and LockedOnTargets[i].TargetTorso.Position or Get3DPosition2()) or Get3DPosition2()
						if ModNames and ModNames["ConditionsInIndividualBullet"] then
							ModNames["ConditionsInIndividualBullet"] = nil
						end
						for ii = 1, (TempModule2.ShotgunEnabled and TempModule2.BulletPerShot or 1) do
							local BulletId = "Bullet_"..HttpService:GenerateGUID()
							local TempModule3 = TempModule2
							for j, k in pairs(TempModule3.ConditionsInIndividualBullet) do
								if ConditionableGunMods[j] and ConditionableGunMods[j](Tool, Humanoid, CurrentVariables.Heat, TempModule3.MaxHeat, CurrentVariables.Mag, TempModule3.AmmoPerMag, UniversalTable.Ammo, UniversalTable.MaxAmmo, CommonVariables.ShootCounts, CommonVariables.CurrentFireRate) then
									TempModule3 = SettingModifier(TempModule3, {k})
									if not ModNames then
										ModNames = {}
									end
									if not ModNames["ConditionsInIndividualBullet"] then
										ModNames["ConditionsInIndividualBullet"] = {}
										ModNames["ConditionsInIndividualBullet"][BulletId] = {}
									end
									table.insert(ModNames["ConditionsInIndividualBullet"][BulletId], j)
								end
							end

							local Spread = TempModule3.Spread * 10 * (CommonVariables.AimDown and 1 - TempModule3.ADSSpreadRedution or 1)				
							local cframe = CFrame.new(HandleToFire:FindFirstChild("GunFirePoint"..CurrentFireMode).WorldPosition, Position)

							if TempModule3.ShotgunPattern and #TempModule3.SpreadPattern > 0 then
								local X, Y = TempModule3.SpreadPattern[ii][1], TempModule3.SpreadPattern[ii][2]
								cframe = cframe * CFrame.Angles(math.rad(Spread * Y / 50), math.rad(Spread * X / 50), 0)
							else
								cframe = cframe * CFrame.Angles(math.rad(math.random(-Spread, Spread) / 50), math.rad(math.random(-Spread, Spread) / 50), 0)
							end

							local Direction	= cframe.LookVector
							table.insert(Directions, {Direction, BulletId})
						end
						Fire(HandleToFire, Position, Directions, TempModule2, ModNames, (TempModule2.LockOnScan and #LockedOnTargets > 0) and (LockedOnTargets[i].TargetEntity or nil) or nil, FirstShot)
						if TempModule2.LockOnScan then
							local CanCycle = true
							if TempModule2.InstaBurst and TempModule2.TriggerOnce then
								CanCycle = (i == 1)
							end
							if TempModule2.CycleHandles and CanCycle then
								CycleHandles()
							end
							if not TempModule2.InstaBurst then
								local StartTime = os.clock() repeat Thread:Wait() if not CommonVariables.ActuallyEquipped then break end until (os.clock() - StartTime) >= TempModule2.LockOnScanBurstRate
								--Thread:Wait(TempModule2.LockOnScanBurstRate)
							end
						else
							if TempModule2.BurstFireEnabled then
								if TempModule2.CycleHandles then
									CycleHandles()
								end
								local StartTime = os.clock() repeat Thread:Wait() if not CommonVariables.ActuallyEquipped then break end until (os.clock() - StartTime) >= TempModule2.BurstRate
								--Thread:Wait(TempModule2.BurstRate)
							end							
						end
						DidShoot = true
					end
					if CurrentFireAnim and CurrentFireAnim.Looped then
						SetAnimationTrack("FireAnim", "Stop")
					end
					if CurrentAimFireAnim and CurrentAimFireAnim.Looped then
						SetAnimationTrack("AimFireAnim", "Stop")
					end
					if Playing then
						Playing = false
						SetFireSoundLoopEnabled(AudioId, false)
					end
					if DidShoot and not TempModule.ShotgunPump and not ((TempModule.LockOnScan or TempModule.BurstFireEnabled) and TempModule.CycleHandles) then
						CycleHandles()
					end
					if (TempModule.BatteryEnabled and CurrentVariables.Heat >= TempModule.MaxHeat or CurrentVariables.Mag <= 0) then
						if CommonVariables.CurrentRate >= TempModule.MaximumRate and TempModule.SmokeTrailEnabled then
							Thread:Spawn(function()
								SmokeTrail:StopEmission()
								SmokeTrail:EmitSmokeTrail(HandleToFire:FindFirstChild("SmokeTrail"..CurrentFireMode), TempModule.MaximumTime)	
							end)
						end				
					end
					local Overheated = false
					if CommonVariables.ActuallyEquipped then
						if TempModule.BatteryEnabled then
							if CurrentVariables.Heat >= TempModule.MaxHeat then
								Overheated = true
								CommonVariables.Enabled = true
								Thread:Spawn(Overheat)
							end
						end
					end
					if not Overheated then
						if DidShoot then
							Thread:Wait(TempModule.FireRate)
							if TempModule.ShotgunPump then
								if CommonVariables.ActuallyEquipped then
									SetAnimationTrack("ShotgunPumpinAnim", "Play", CurrentShotgunPumpinAnimationSpeed)
									if HandleToFire[CurrentFireMode]:FindFirstChild("PumpSound") then
										HandleToFire[CurrentFireMode].PumpSound:Play()
									end
									Thread:Spawn(function()
										local StartTime = os.clock() repeat Thread:Wait() if not CommonVariables.ActuallyEquipped then break end until (os.clock() - StartTime) >= TempModule.BulletShellDelay
										if CommonVariables.ActuallyEquipped then
											EjectShell(HandleToFire, TempModule)
										end
									end)
								end
								if not ((TempModule.LockOnScan or TempModule.BurstFireEnabled) and TempModule.CycleHandles) then
									CycleHandles()
								end
								Thread:Wait(TempModule.ShotgunPumpinSpeed)
							end
						end
						CommonVariables.Enabled = true
						if CommonVariables.ActuallyEquipped and Module.AutoReload and CurrentVariables.Mag <= 0 then
							Reload()
						end
					end
				end
			end	
		else
			CommonVariables.Down = true
			if CommonVariables.ActuallyEquipped and CommonVariables.Enabled and CommonVariables.Down and not CommonVariables.Overheated and not CommonVariables.HoldDown and not CommonVariables.Switching and not CommonVariables.Alting and HasEnoughMag(CurrentModule.AmmoCost) and CurrentVariables.Heat < CurrentModule.MaxHeat and Humanoid.Health > 0 and CanShoot() then
				if Module.CancelReload then
					if CommonVariables.Reloading and not CommonVariables.CanCancelReload then
						CommonVariables.CanCancelReload = true
					end
				else
					if CommonVariables.Reloading then
						return
					end
				end
				CommonVariables.Enabled = false	
				SetAnimationTrack("InspectAnim", "Stop", nil, 0)
				if CurrentModule.MinigunEnabled then
					SetAnimationTrack("MinigunRevUpAnim", "Play", CurrentModule.MinigunRevUpAnimationSpeed)
					if CommonVariables.ActuallyEquipped and HandleToFire[CurrentFireMode]:FindFirstChild("WindUp") then
						HandleToFire[CurrentFireMode].WindUp:Play()
					end
					local Interrupted = false
					local StartTime = os.clock() repeat Thread:Wait() if not CommonVariables.ActuallyEquipped then Interrupted = true break end until (os.clock() - StartTime) >= CurrentModule.DelayBeforeFiring
					if Interrupted then
						SetAnimationTrack("MinigunRevUpAnim", "Stop")
						if HandleToFire[CurrentFireMode]:FindFirstChild("WindUp") then
							HandleToFire[CurrentFireMode].WindUp:Stop()
						end
					end	
					--Thread:Wait(CurrentModule.DelayBeforeFiring)
				end
				CommonVariables.CurrentFireRate = CurrentModule.FireRate
				local DidShoot = false
				local Playing = false
				local AudioId = "Audio_"..HttpService:GenerateGUID()
				while CommonVariables.ActuallyEquipped and not CommonVariables.Overheated and CommonVariables.Down and not CommonVariables.HoldDown and not CommonVariables.Switching and not CommonVariables.Alting and HasEnoughMag(CurrentModule.AmmoCost) and CurrentVariables.Heat < CurrentModule.MaxHeat and Humanoid.Health > 0 and CanShoot() do
					local IsChargedShot = false
					if CurrentModule.ChargedShotEnabled then
						if CommonVariables.ActuallyEquipped and HandleToFire[CurrentFireMode]:FindFirstChild("ChargeSound") then
							HandleToFire[CurrentFireMode].ChargeSound:Play()
						end
						local Interrupted = false
						local StartTime = os.clock() repeat Thread:Wait() if not CommonVariables.ActuallyEquipped then Interrupted = true break end until (os.clock() - StartTime) >= CurrentModule.ChargingTime
						if Interrupted then
							if HandleToFire[CurrentFireMode]:FindFirstChild("ChargeSound") then
								HandleToFire[CurrentFireMode].ChargeSound:Stop()
							end
						else
							IsChargedShot = true
						end					
						--Thread:Wait(CurrentModule.ChargingTime)
						if not IsChargedShot then
							break
						end
					end
					local ModNames					
					local TempModule = CloneTable(CurrentModule)
					for j, k in pairs(TempModule.Conditions) do
						if ConditionableGunMods[j] and ConditionableGunMods[j](Tool, Humanoid, CurrentVariables.Heat, TempModule.MaxHeat, CurrentVariables.Mag, TempModule.AmmoPerMag, UniversalTable.Ammo, UniversalTable.MaxAmmo, CommonVariables.ShootCounts, CommonVariables.CurrentFireRate) then
							TempModule = SettingModifier(TempModule, {k})
							if not ModNames then
								ModNames = {}
							end
							if not ModNames["Conditions"] then
								ModNames["Conditions"] = {}
							end
							table.insert(ModNames["Conditions"], j)
						end
					end
					for i = 1, ((TempModule.SelectiveFireEnabled and (CurrentVariables.FireModes[CurrentVariables.FireMode] ~= true and CurrentVariables.FireModes[CurrentVariables.FireMode] or 1)) or (TempModule.BurstFireEnabled and TempModule.BulletPerBurst) or 1) do
						if not CommonVariables.ActuallyEquipped then
							break
						end
						if ModNames and ModNames["ConditionsInIndividualShot"] then
							ModNames["ConditionsInIndividualShot"] = nil
						end
						local TempModule2 = TempModule
						for j, k in pairs(TempModule2.ConditionsInIndividualShot) do
							if ConditionableGunMods[j] and ConditionableGunMods[j](Tool, Humanoid, CurrentVariables.Heat, TempModule2.MaxHeat, CurrentVariables.Mag, TempModule2.AmmoPerMag, UniversalTable.Ammo, UniversalTable.MaxAmmo, CommonVariables.ShootCounts, CommonVariables.CurrentFireRate) then
								TempModule2 = SettingModifier(TempModule2, {k})
								if not ModNames then
									ModNames = {}
								end
								if not ModNames["ConditionsInIndividualShot"] then
									ModNames["ConditionsInIndividualShot"] = {}
								end
								table.insert(ModNames["ConditionsInIndividualShot"], j)
							end
						end
						if not CanShoot() then
							break
						end
						if TempModule2.BatteryEnabled then
							if CurrentVariables.Heat >= TempModule2.MaxHeat then
								break
							end
						else
							if not HasEnoughMag(TempModule2.AmmoCost) then
								break
							end
						end
						if not Playing then
							Playing = true
							SetFireSoundLoopEnabled(AudioId, true)
						end
						local Directions = {}
						if not TempModule2.ShotgunPump then
							Thread:Spawn(function()
								local StartTime = os.clock() repeat Thread:Wait() if not CommonVariables.ActuallyEquipped then break end until (os.clock() - StartTime) >= TempModule2.BulletShellDelay
								if CommonVariables.ActuallyEquipped then
									EjectShell(HandleToFire, TempModule2)
								end
							end)
						end
						CommonVariables.CurrentRate = CommonVariables.CurrentRate + TempModule2.SmokeTrailRateIncrement
						local Position = Get3DPosition2()
						if ModNames and ModNames["ConditionsInIndividualBullet"] then
							ModNames["ConditionsInIndividualBullet"] = nil
						end
						for ii = 1, (TempModule2.ShotgunEnabled and TempModule2.BulletPerShot or 1) do
							local BulletId = "Bullet_"..HttpService:GenerateGUID()
							local TempModule3 = TempModule2
							for j, k in pairs(TempModule3.ConditionsInIndividualBullet) do
								if ConditionableGunMods[j] and ConditionableGunMods[j](Tool, Humanoid, CurrentVariables.Heat, TempModule3.MaxHeat, CurrentVariables.Mag, TempModule3.AmmoPerMag, UniversalTable.Ammo, UniversalTable.MaxAmmo, CommonVariables.ShootCounts, CommonVariables.CurrentFireRate) then
									TempModule3 = SettingModifier(TempModule3, {k})
									if not ModNames then
										ModNames = {}
									end
									if not ModNames["ConditionsInIndividualBullet"] then
										ModNames["ConditionsInIndividualBullet"] = {}
										ModNames["ConditionsInIndividualBullet"][BulletId] = {}
									end
									table.insert(ModNames["ConditionsInIndividualBullet"][BulletId], j)
								end
							end

							local Spread = TempModule3.Spread * 10 * (CommonVariables.AimDown and 1 - TempModule3.ADSSpreadRedution or 1)
							local cframe = CFrame.new(HandleToFire:FindFirstChild("GunFirePoint"..CurrentFireMode).WorldPosition, Position)

							if TempModule3.ShotgunPattern and #TempModule3.SpreadPattern > 0 then
								local X, Y = TempModule3.SpreadPattern[ii][1], TempModule3.SpreadPattern[ii][2]
								cframe = cframe * CFrame.Angles(math.rad(Spread * Y / 50), math.rad(Spread * X / 50), 0)
							else
								cframe = cframe * CFrame.Angles(math.rad(math.random(-Spread, Spread) / 50), math.rad(math.random(-Spread, Spread) / 50), 0)
							end

							local Direction	= cframe.LookVector
							table.insert(Directions, {Direction, BulletId})
						end
						Fire(HandleToFire, Position, Directions, TempModule2, ModNames)
						if TempModule2.BurstFireEnabled or TempModule2.SelectiveFireEnabled then
							if TempModule2.CycleHandles then
								CycleHandles()
							end
							local StartTime = os.clock() repeat Thread:Wait() if not CommonVariables.ActuallyEquipped then break end until (os.clock() - StartTime) >= (TempModule2.SelectiveFireEnabled and TempModule2.BurstRates[CurrentVariables.FireMode] or TempModule2.BurstRate)
							--Thread:Wait(TempModule2.SelectiveFireEnabled and TempModule2.BurstRates[CurrentVariables.FireMode] or TempModule2.BurstRate)
						end
						DidShoot = true
					end
					if DidShoot and not TempModule.ShotgunPump and not ((TempModule.SelectiveFireEnabled or TempModule.BurstFireEnabled) and TempModule.CycleHandles) then
						CycleHandles()
					end
					if (TempModule.BatteryEnabled and CurrentVariables.Heat >= TempModule.MaxHeat or CurrentVariables.Mag <= 0) then
						if CommonVariables.CurrentRate >= TempModule.MaximumRate and TempModule.SmokeTrailEnabled then
							Thread:Spawn(function()
								SmokeTrail:StopEmission()
								SmokeTrail:EmitSmokeTrail(HandleToFire:FindFirstChild("SmokeTrail"..CurrentFireMode), TempModule.MaximumTime)	
							end)
						end				
					end
					if TempModule.BatteryEnabled then
						if CurrentVariables.Heat >= TempModule.MaxHeat then
							break
						end
					end
					if DidShoot then
						Thread:Wait(TempModule.SelectiveFireEnabled and TempModule.FireRates[CurrentVariables.FireMode] or ((TempModule.Auto and TempModule.GainFireRateAsAutoFire) and CommonVariables.CurrentFireRate or TempModule.FireRate))
						if TempModule.SelectiveFireEnabled then
							if CurrentVariables.FireModes[CurrentVariables.FireMode] ~= true then
								break
							end
						else
							if not TempModule.Auto then
								break
							else
								if TempModule.GainFireRateAsAutoFire then
									CommonVariables.CurrentFireRate = math.clamp(CommonVariables.CurrentFireRate - TempModule.FireRateIncrement, TempModule.MaximumFireRate, TempModule.FireRate)
								end
							end
						end
					else
						break
					end
				end
				if CurrentFireAnim and CurrentFireAnim.Looped then
					SetAnimationTrack("FireAnim", "Stop")
				end
				if CurrentAimFireAnim and CurrentAimFireAnim.Looped then
					SetAnimationTrack("AimFireAnim", "Stop")
				end
				if Playing then
					Playing = false
					SetFireSoundLoopEnabled(AudioId, false)
				end
				if CurrentModule.MinigunEnabled and CommonVariables.ActuallyEquipped and HandleToFire[CurrentFireMode]:FindFirstChild("WindDown") then
					HandleToFire[CurrentFireMode].WindDown:Play()
				end
				local Overheated = false
				if CommonVariables.ActuallyEquipped then
					if CurrentModule.BatteryEnabled then
						if CurrentVariables.Heat >= CurrentModule.MaxHeat then
							Overheated = true
							CommonVariables.Enabled = true
							Thread:Spawn(Overheat)
						end
					end
				end
				if not Overheated then
					if CurrentModule.MinigunEnabled then
						if CommonVariables.ActuallyEquipped then
							SetAnimationTrack("MinigunRevDownAnim", "Play", CurrentModule.MinigunRevDownAnimationSpeed)	
						end
						SetAnimationTrack("MinigunRevUpAnim", "Stop")
						Thread:Wait(CurrentModule.DelayAfterFiring)
					end
					if DidShoot then
						if CurrentModule.ShotgunPump then
							if CommonVariables.ActuallyEquipped then
								SetAnimationTrack("ShotgunPumpinAnim", "Play", CurrentShotgunPumpinAnimationSpeed)
								if HandleToFire[CurrentFireMode]:FindFirstChild("PumpSound") then
									HandleToFire[CurrentFireMode].PumpSound:Play()
								end
								Thread:Spawn(function()
									local StartTime = os.clock() repeat Thread:Wait() if not CommonVariables.ActuallyEquipped then break end until (os.clock() - StartTime) >= CurrentModule.BulletShellDelay
									if CommonVariables.ActuallyEquipped then
										EjectShell(HandleToFire, CurrentModule)
									end
								end)
							end
							if not (CurrentModule.BurstFireEnabled and CurrentModule.CycleHandles) then
								CycleHandles()
							end
							Thread:Wait(CurrentModule.ShotgunPumpinSpeed)
						end
					end
					CommonVariables.Enabled = true
					if CommonVariables.ActuallyEquipped and Module.AutoReload and CurrentVariables.Mag <= 0 then
						Reload()
					end
				end
			end
		end		
	end
end

function OnStoppingFiring()
	CommonVariables.Down = false
	if CurrentModule.ChargedShotAdvanceEnabled or CurrentModule.HoldAndReleaseEnabled then
		CommonVariables.Charging = false
	end
	if CurrentModule.HoldAndReleaseEnabled and not CommonVariables.Charged then
		CommonVariables.Enabled = true
	end
end

function OnMeleeHit(Hit, RegionalHitbox, RaycastHitboxTable)
	if Hit.Name == "_glass" and CurrentModule.MeleeCanBreakGlass then
		if not CommonVariables.AlreadyHit then
			CommonVariables.AlreadyHit = true
			ShatterGlass:FireServer(Hit, RegionalHitbox and Hit.Position or RaycastHitboxTable[2], (Hit.Position - HumanoidRootPart.Position).Unit)
			if not CurrentModule.TriggerEffectOnce then
				Thread:Delay(CurrentModule.EffectDelay, function()
					CommonVariables.AlreadyHit = false
				end)
			end
		end
	else
		local Target = Hit:FindFirstAncestorOfClass("Model")
		local CanBlock
		local TargetHumanoid
		local TargetTorso
		local TargetTorso2
		if Target then
			CanBlock = Target:FindFirstChild("CanBlock")
			TargetHumanoid = Target:FindFirstChildOfClass("Humanoid")
			TargetTorso = Target:FindFirstChild("HumanoidRootPart") or Target:FindFirstChild("Head")
			TargetTorso2 = Target:FindFirstChild("HumanoidRootPart") or Target:FindFirstChild("Torso") or Target:FindFirstChild("UpperTorso")
		end
		local Misc = {
			Tool = Tool,
			ModuleName = CurrentModule.ModuleName,
			Direction = ((TargetTorso and TargetTorso.Position or Hit.Position) - HumanoidRootPart.Position).Unit,
			Blocked = false,
		}
		local ShouldBlock = false
		local TEAM = Character:FindFirstChild("TEAM")
		if CanBlock and CurrentModule.BlockMelee then
			if TEAM and CanBlock:FindFirstChild("TEAM") then
				if CanBlock.TEAM.Value ~= TEAM.Value then
					ShouldBlock = true
					Misc.Blocked = ShouldBlock
				end
			else
				ShouldBlock = true
				Misc.Blocked = ShouldBlock
			end
		end
		local Pos = RegionalHitbox and Hit.Position or RaycastHitboxTable[2]
		local Normal = RegionalHitbox and Vector3.new(0, 0, 0) or RaycastHitboxTable[3]
		local Material = RegionalHitbox and Hit.Material or RaycastHitboxTable[4]
		if TargetHumanoid and TargetTorso then
			Pos = RegionalHitbox and TargetTorso2.Position or RaycastHitboxTable[2]
			if ShouldBlock then
				if not table.find(CommonVariables.BlockedModels, Target) then
					table.insert(CommonVariables.BlockedModels, Target)
					if not RegionalHitbox and CurrentModule.BlockDelay ~= math.huge then
						Thread:Delay(CurrentModule.BlockDelay, function()
							local Index = table.find(CommonVariables.BlockedModels, Target)
							if Index then
								table.remove(CommonVariables.BlockedModels, Index)
							end	
						end)
					end
					gunEvent:Fire("VisualizeHitEffect", "Normal", Hit, Pos, Normal, Material, Misc, true)
				end
				return
			end
			if TargetHumanoid.Health > 0 then
				if DamageModule.CanDamage(Target, Character, CurrentModule.FriendlyFire) then
					if #CommonVariables.MeleeHitHumanoids < CurrentModule.MaxHits then
						if not table.find(CommonVariables.MeleeHitHumanoids, TargetHumanoid) and not table.find(CommonVariables.BlockedModels, Target) then
							table.insert(CommonVariables.MeleeHitHumanoids, TargetHumanoid)
							if not RegionalHitbox and CurrentModule.HitIgnoreDelay ~= math.huge then
								Thread:Delay(CurrentModule.HitIgnoreDelay, function()
									local Index = table.find(CommonVariables.MeleeHitHumanoids, TargetHumanoid)
									if Index then
										table.remove(CommonVariables.MeleeHitHumanoids, Index)
									end	
								end)
							end
							gunEvent:Fire("VisualizeHitEffect", "Blood", Hit, Pos, Normal, Material, Misc, true)
							Thread:Spawn(function()
								InflictTarget:FireServer("GunMelee", Tool, Hit, Hit.Size, CurrentModule.ModuleName)
							end)
							MarkHit(CurrentModule, Hit.Name == "Head" and CurrentModule.MeleeHeadshotHitmarker)
						end					
					end
				end
			end
		else
			if ShouldBlock then
				if not table.find(CommonVariables.BlockedModels, Target) then
					table.insert(CommonVariables.BlockedModels, Target)
					if not RegionalHitbox and CurrentModule.BlockDelay ~= math.huge then
						Thread:Delay(CurrentModule.BlockDelay, function()
							local Index = table.find(CommonVariables.BlockedModels, Target)
							if Index then
								table.remove(CommonVariables.BlockedModels, Index)
							end	
						end)
					end
					gunEvent:Fire("VisualizeHitEffect", "Normal", Hit, Pos, Normal, Material, Misc, true)
				end
			else
				if not CommonVariables.AlreadyHit then
					CommonVariables.AlreadyHit = true
					gunEvent:Fire("VisualizeHitEffect", "Normal", Hit, Pos, Normal, Material, Misc, true)
					if not CurrentModule.TriggerEffectOnce then
						Thread:Delay(CurrentModule.EffectDelay, function()
							CommonVariables.AlreadyHit = false
						end)
					end
				end	
			end
		end
	end
end

function OnMeleeAttacking()
	if CurrentModule.MeleeAttackEnabled then
		if CurrentAnimTable.MeleeAttackAnim and CurrentAnimTable.MeleeAttackAnim.Length > 0 then
			local Connection
			local Connection2
			if CommonVariables.ActuallyEquipped and CommonVariables.Enabled and not CommonVariables.Overheated and not CommonVariables.Switching and not CommonVariables.Alting and not CommonVariables.AimDown and Humanoid.Health > 0 and CanShoot() then
				if Module.CancelReload then
					if CommonVariables.Reloading and not CommonVariables.CanCancelReload then
						CommonVariables.CanCancelReload = true
					end
				else
					if CommonVariables.Reloading then
						return
					end
				end
				CommonVariables.Enabled = false
				SetAnimationTrack("InspectAnim", "Stop", nil, 0)
				SetAnimationTrack("MeleeAttackAnim", "Play", CurrentModule.MeleeAttackAnimationSpeed, 0.05)
				if CommonVariables.ActuallyEquipped and HandleToFire[CurrentFireMode]:FindFirstChild("MeleeSwingSound") then
					HandleToFire[CurrentFireMode].MeleeSwingSound:Play()
				end
				Connection = CurrentAnimTable.MeleeAttackAnim:GetMarkerReachedSignal("MeleeDamageSequence"):Connect(function(ParamString)
					--print(ParamString)
					table.clear(CommonVariables.BlockedModels)
					table.clear(CommonVariables.MeleeHitHumanoids)

					if CurrentModule.HitboxType == "RotatedRegion" then
						local RegionalHitbox = Instance.new("Part")
						RegionalHitbox.CanCollide = false
						RegionalHitbox.CastShadow = false
						RegionalHitbox.Massless = true
						RegionalHitbox.Transparency = 1
						RegionalHitbox.Material = Enum.Material.SmoothPlastic
						RegionalHitbox.Shape = CurrentModule.HitboxShape
						RegionalHitbox.Size = CurrentModule.HitboxSize
						RegionalHitbox.Color = Color3.new(1, 0, 0)
						RegionalHitbox.CFrame = HumanoidRootPart.CFrame * CurrentModule.HitboxCFrame
						RegionalHitbox.Parent = Camera
						local Weld = Instance.new("WeldConstraint")
						Weld.Part0 = RegionalHitbox
						Weld.Part1 = HumanoidRootPart
						Weld.Parent = RegionalHitbox
						local Region = RotatedRegion3.new(RegionalHitbox.CFrame, RegionalHitbox.Size)
						local RegionTable = Region:FindPartsInRegion3WithIgnoreList(IgnoreList, CurrentModule.MaxPartsInRegion)
						for _, v in pairs(RegionTable) do
							if v and v.Parent ~= nil then
								OnMeleeHit(v, RegionalHitbox, nil)
							end
						end
						Debris:AddItem(RegionalHitbox, 0.2)
					else
						if CurrentModule.TriggerEffectOnce then
							CommonVariables.AlreadyHit = false		
						end

						local HBI = GetInstanceFromAncestor(CurrentModule.RaycastHitboxInstances[1])
						local HBI2

						if CurrentModule.RaycastHitboxInstances[2] then
							HBI2 = GetInstanceFromAncestor(CurrentModule.RaycastHitboxInstances[2])
						end

						if HBI and HBI:FindFirstChild("DamagePoint", true) then
							if not CommonVariables.Hitbox then
								CommonVariables.Hitbox = RaycastHitbox.new(HBI)
								CommonVariables.Hitbox.RaycastParams = RayParams
								CommonVariables.Hitbox.DetectionMode = RaycastHitbox.DetectionMode.PartMode
								CommonVariables.Hitbox.OnHit:Connect(function(part, humanoid, raycastResult)
									if part and part.Parent ~= nil then
										OnMeleeHit(part, nil, {raycastResult.Instance, raycastResult.Position, raycastResult.Normal, raycastResult.Material})
									end
								end)
								CommonVariables.Hitbox:HitStart()					
							end
						end

						if HBI2 and HBI2:FindFirstChild("DamagePoint", true) then
							if not CommonVariables.Hitbox2 then
								CommonVariables.Hitbox2 = RaycastHitbox.new(HBI2)
								CommonVariables.Hitbox2.RaycastParams = RayParams
								CommonVariables.Hitbox2.DetectionMode = RaycastHitbox.DetectionMode.PartMode
								CommonVariables.Hitbox2.OnHit:Connect(function(part, humanoid, raycastResult)
									if part and part.Parent ~= nil then
										OnMeleeHit(part, nil, {raycastResult.Instance, raycastResult.Position, raycastResult.Normal, raycastResult.Material})
									end
								end)
								CommonVariables.Hitbox2:HitStart()					
							end
						end
					end

					if Connection then
						--print("Disconnected")
						Connection:Disconnect()
						Connection = nil
					end
				end)
				Connection2 = CurrentAnimTable.MeleeAttackAnim:GetMarkerReachedSignal("MeleeDamageEndSequence"):Connect(function(ParamString)
					--print(ParamString)
					if CommonVariables.Hitbox then
						CommonVariables.Hitbox:HitStop()
						CommonVariables.Hitbox:Destroy()
						CommonVariables.Hitbox = nil
					end
					if CommonVariables.Hitbox2 then
						CommonVariables.Hitbox2:HitStop()
						CommonVariables.Hitbox2:Destroy()
						CommonVariables.Hitbox2 = nil
					end

					if Connection2 then
						--print("Disconnected")
						Connection2:Disconnect()
						Connection2 = nil
					end
				end)
				CurrentAnimTable.MeleeAttackAnim.Stopped:Wait()
				if CommonVariables.Hitbox then
					CommonVariables.Hitbox:HitStop()
					CommonVariables.Hitbox:Destroy()
					CommonVariables.Hitbox = nil
				end
				if CommonVariables.Hitbox2 then
					CommonVariables.Hitbox2:HitStop()
					CommonVariables.Hitbox2:Destroy()
					CommonVariables.Hitbox2 = nil
				end
				CommonVariables.Enabled = true
			end				
		end	
	end
end

function OnUnequipping(Remove)
	if Module.CustomGripEnabled and not Tool.RequiresHandle then
		SetCustomGrip(false)
	end
	if Module.DualWeldEnabled and not Module.CustomGripEnabled and Tool.RequiresHandle then
		if CommonVariables.Grip2 then
			CommonVariables.Grip2:Destroy()
		end
	end
	
	if CurrentModule.ChargedShotAdvanceEnabled then
		CommonVariables.Charging = false
	end
	if CurrentModule.HoldAndReleaseEnabled then
		CommonVariables.Charged = false
	end
	CommonVariables.Equipped = false
	CommonVariables.ActuallyEquipped = false
	if JumpButton then
		MobileButtons.AimButton.Parent = GUI.MobileButtons
		MobileButtons.FireButton.Parent = GUI.MobileButtons
		MobileButtons.HoldDownButton.Parent = GUI.MobileButtons
		MobileButtons.InspectButton.Parent = GUI.MobileButtons
		MobileButtons.ReloadButton.Parent = GUI.MobileButtons
		MobileButtons.SwitchButton.Parent = GUI.MobileButtons
		MobileButtons.AltButton.Parent = GUI.MobileButtons
	end
	GUI.Parent = script
	UserInputService.MouseIconEnabled = true
	RunService:UnbindFromRenderStep(BindToStepName)
	RemoveStuff(true)
	if CurrentModule.BatteryEnabled then
		gunEvent:Fire("VisualizeOverheat", CurrentModule.OverheatEffect, "End", Character, Tool, HandleToFire, true)
	end
	if Remove then
		if CurrentModule.LaserBeam then
			VisibleMuzz(HandleToFire:FindFirstChild("GunMuzzlePoint"..CurrentFireMode), false)
			VisibleMuzzle:FireServer(HandleToFire:FindFirstChild("GunMuzzlePoint"..CurrentFireMode), false)
			gunEvent:Fire("RemoveBeam", GUID, Tool, CurrentModule.ModuleName, BeamTable, CommonVariables.LaserTrail, CommonVariables.BoltSegments, CrosshairPointAttachment)			
		end
	end
	SetADS(true)
end

MobileButtons.AimButton.MouseButton1Click:Connect(function()
	SetADS()
end)

MobileButtons.HoldDownButton.MouseButton1Click:Connect(function()
	OnHoldingDown()
end)

MobileButtons.InspectButton.MouseButton1Click:Connect(function()
	OnInspecting()
end)

MobileButtons.SwitchButton.MouseButton1Click:Connect(function()
	OnSwitching()
end)

MobileButtons.ReloadButton.MouseButton1Click:Connect(function()
	Reload()
end)

MobileButtons.FireButton.MouseButton1Down:Connect(function()
	OnFiring()
end)

MobileButtons.FireButton.MouseButton1Up:Connect(function()
	OnStoppingFiring()
end)

MobileButtons.SubFireButton.MouseButton1Down:Connect(function()
	OnFiring()
end)

MobileButtons.SubFireButton.MouseButton1Up:Connect(function()
	OnStoppingFiring()
end)

MobileButtons.MeleeButton.MouseButton1Click:Connect(function()
	OnMeleeAttacking()
end)

MobileButtons.AltButton.MouseButton1Click:Connect(function()
	OnAlting()
end)

UserInputService.InputBegan:Connect(function(Input, GameProcessed)
	if GameProcessed then
		return
	end
	if not UserInputService.TouchEnabled then
		local InputType
		if Input.UserInputType == Enum.UserInputType.Keyboard then
			InputType = "Keyboard"
		elseif Input.UserInputType == Enum.UserInputType.Gamepad1 then
			InputType = "Controller"
		end
		local CanADS = ((Camera.Focus.p - Camera.CoordinateFrame.p).Magnitude <= 1) 
		if Module.ThirdPersonADS then
			CanADS = ((Camera.Focus.p - Camera.CoordinateFrame.p).Magnitude <= 1) or (UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter) 
		end
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or (InputType == "Controller" and Input.KeyCode == Module.Controller.Fire) then
			OnFiring()
		elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and CanADS then
			SetADS()
		end
		if InputType then
			if Input.KeyCode == Module[InputType].Reload then
				Reload()
			elseif Input.KeyCode == Module[InputType].HoldDown then
				OnHoldingDown()
			elseif Input.KeyCode == Module[InputType].Inspect then
				OnInspecting()
			elseif Input.KeyCode == Module[InputType].Switch then
				OnSwitching()
			elseif Input.KeyCode == Module[InputType].ToogleAim then
				SetADS()
			elseif Input.KeyCode == Module[InputType].Melee then
				OnMeleeAttacking()
			elseif Input.KeyCode == Module[InputType].AltFire then
				OnAlting()
			end			
		end
	end
end)

UserInputService.InputEnded:Connect(function(Input, GameProcessed)
	if GameProcessed then
		return
	end
	if not UserInputService.TouchEnabled then
		local InputType
		if Input.UserInputType == Enum.UserInputType.Keyboard then
			InputType = "Keyboard"
		elseif Input.UserInputType == Enum.UserInputType.Gamepad1 then
			InputType = "Controller"
		end
		local CanADS = ((Camera.Focus.p - Camera.CoordinateFrame.p).Magnitude <= 1) 
		if Module.ThirdPersonADS then
			CanADS = ((Camera.Focus.p - Camera.CoordinateFrame.p).Magnitude <= 1) or (UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter) 
		end
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or (InputType == "Controller" and Input.KeyCode == Module.Controller.Fire) then
			OnStoppingFiring()
		elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and CanADS then
			SetADS(true)
		end
	end
end)

MarkerEvent.Event:Connect(MarkHit)

ChangeMagAndAmmo.OnClientEvent:Connect(function(Values, Ammo)
	for i, v in ipairs(Values) do
		Variables[v.Id].Mag = v.Mag
		if not Module.UniversalAmmoEnabled then
			Variables[v.Id].Ammo = v.Ammo
		end
		Variables[v.Id].Heat = v.Heat
	end
	if Module.UniversalAmmoEnabled then
		UniversalTable.Ammo = Ammo
	end
	UpdateGUI()
end)

Tool.Equipped:Connect(function()
	if Module.CustomGripEnabled and not Tool.RequiresHandle then
		task.spawn(function()
			SetCustomGrip(true)
		end)
	end
	if Module.DualWeldEnabled and not Module.CustomGripEnabled and Tool.RequiresHandle then
		task.spawn(function()
			if RightArm then
				local Grip = RightArm:WaitForChild("RightGrip", 0.01)
				if Grip then
					CommonVariables.Grip2 = Grip:Clone()
					CommonVariables.Grip2.Name = "LeftGrip"
					CommonVariables.Grip2.Part0 = LeftArm
					CommonVariables.Grip2.Part1 = CommonVariables.Handle2
					--CommonVariables.Grip2.C1 = Grip2.C1:inverse()
					CommonVariables.Grip2.Parent = LeftArm
				end
			end
		end)
	end
	
	CommonVariables.Equipped = true
	if JumpButton then
		MobileButtons.AimButton.Parent = JumpButton
		MobileButtons.FireButton.Parent = JumpButton
		MobileButtons.HoldDownButton.Parent = JumpButton
		MobileButtons.InspectButton.Parent = JumpButton
		MobileButtons.ReloadButton.Parent = JumpButton
		MobileButtons.SwitchButton.Parent = JumpButton
		MobileButtons.AltButton.Parent = JumpButton
	end
	GUI.Parent = Player.PlayerGui
	UpdateGUI()
	UserInputService.MouseIconEnabled = false

	SetCrossSettings(CurrentModule.CrossSize, CurrentModule.CrossSpeed, CurrentModule.CrossDamper)

	if CommonVariables.Radar == nil then
		CommonVariables.Radar = Scanners.Radars[CurrentModule.Radar]:Clone()
		CommonVariables.Radar.Name = "Scanner"
		CommonVariables.Radar.Parent = GUI
	end

	if CurrentModule.ProjectileMotion then
		local MotionBeam = GunVisualEffects:FindFirstChild(CurrentModule.MotionBeam)
		if MotionBeam then
			CommonVariables.Beam, CommonVariables.Attach0, CommonVariables.Attach1 = ProjectileMotion.ShowProjectilePath(MotionBeam, HandleToFire:FindFirstChild("GunFirePoint"..CurrentFireMode).WorldPosition, Vector3.new(), 3, AddressTableValue("Acceleration", CurrentModule))
		end
	end

	RunService:BindToRenderStep(BindToStepName, Enum.RenderPriority.Camera.Value, Render)

	for _, v in pairs(CommonVariables.Keyframes) do
		table.insert(CommonVariables.KeyframeConnections, v[1]:GetMarkerReachedSignal("AnimationEvents"):Connect(function(keyframeName)
			if v[2][keyframeName] then
				v[2][keyframeName](keyframeName, Tool)
			end
		end))
	end

	if CurrentAnimTable.EmptyEquippedAnim and CurrentVariables.Mag <= 0 then
		SetAnimationTrack("EmptyEquippedAnim", "Play", CurrentModule.EmptyEquippedAnimationSpeed)
		HandleToFire[CurrentFireMode].EmptyEquippedSound:Play()
	else
		SetAnimationTrack("EquippedAnim", "Play", CurrentModule.EquippedAnimationSpeed)
		HandleToFire[CurrentFireMode].EquippedSound:Play()
	end

	if CurrentAnimTable.EmptyIdleAnim and CurrentVariables.Mag <= 0 then
		SetAnimationTrack("EmptyIdleAnim", "Play", CurrentModule.EmptyIdleAnimationSpeed)
	else
		SetAnimationTrack("IdleAnim", "Play", CurrentModule.IdleAnimationSpeed)
	end

	local StartTime = os.clock() repeat Thread:Wait() if not CommonVariables.Equipped then break end until (os.clock() - StartTime) >= ((CurrentVariables.Mag <= 0) and CurrentModule.EmptyEquipTime or CurrentModule.EquipTime)
	if CommonVariables.Equipped then
		CommonVariables.ActuallyEquipped = true
	end

	if CommonVariables.ActuallyEquipped and Module.AutoReload and CurrentVariables.Mag <= 0 then
		Reload()
	end	
end)

Tool.Unequipped:Connect(function()
	OnUnequipping(Tool.Parent == Workspace)
end)

Humanoid.Died:Connect(function()
	OnUnequipping(true)
end)

Tool.AncestryChanged:Connect(function()
	if not Tool:IsDescendantOf(game) then
		OnUnequipping(true)
	end
end)