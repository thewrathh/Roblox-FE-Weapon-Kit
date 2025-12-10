local Module = {
	--	====================
	--	BASIC
	--	A basic settings for the gun
	--	====================

	ModuleName = script.Name; --For security purpose
	
	--Even if effect names are typos or not existing, no errors will be thrown. Same with "FireSound"
	MuzzleEffect = "MuzzleEffect";
	HitEffect = "HitEffect";
	BloodEffect = "BloodEffect";
	MetalEffect = "MetalEffect";
	BlockEffect = "BlockEffect";
	ExplosionEffect = "ExplosionEffect";
	LaserBeamEffect = "LaserBeamEffect";
	MeleeHitEffect = "MeleeHitEffect";
	MeleeBloodEffect = "MeleeBloodEffect";
	MeleeMetalEffect = "MeleeMetalEffect";
	MeleeBlockEffect = "MeleeBlockEffect";
	GoreEffect = "GoreEffect";
	ShellEjectEffect = "ShellEjectEffect";
	MotionBeam = "MotionBeam";

	FireSound = "FireSounds"; --Must be either Sound or Folder instance
	LowAmmoSound = "LowAmmoSound";
	
	--Table to define the names of handles that exist inside the gun in order (from top to bottom). Useful for dual (or multiple) fire. You can add duplicated name into it
	--Also check "FireAnimations", "AimFireAnimations" and "ShotgunPumpinAnimations" tables. You can also unsynchronize by making their index counts fluctuated
	Handles = {
		"Handle";
	};		

	Auto = false;
	BaseDamage = 20;
	FireRate = 0.125; --In second
	ReloadTime = 3; --In second
	AmmoPerMag = 12; --Set to "math.huge" to make this gun have infinite ammo and never reload
	AmmoCost = 1; --Amount of ammo should be costed upon firing
	Spread = 5; --In degree
	DamageMultipliers = { --You can add more body parts to modify damage
		["Head"] = 2,
	};
	HeadshotHitmarker = true;
	EquipTime = 0;
	EmptyEquipTime = 0;
	
	GainFireRateAsAutoFire = false;
	FireRateIncrement = 0.025;
	MaximumFireRate = 0.1;

	ShootCounts = 0;
	
	EquippedAnimationID = nil;
	EquippedAnimationSpeed = 1;
	
	EmptyEquippedAnimationID = nil;
	EmptyEquippedAnimationSpeed = 1;
	
	IdleAnimationID = nil; --Set to "nil" if you don't want to animate
	IdleAnimationSpeed = 1;
	
	EmptyIdleAnimationID = nil;
	EmptyIdleAnimationSpeed = 1;
	
	ReloadAnimationID = nil; --Set to "nil" if you don't want to animate
	ReloadAnimationSpeed = 1;
	
	FireAnimations = {
		{
			FireAnimationID = nil; --Set to "nil" if you don't want to animate
			FireAnimationSpeed = 1;
		};
	};
	
	LastFireAnimations = {
		{
			LastFireAnimationID = nil; --Set to "nil" if you don't want to animate
			LastFireAnimationSpeed = 1;
		};
	};		

	--Aim animations
	AimIdleAnimationID = nil; --Set to "nil" if you don't want to animate
	AimIdleAnimationSpeed = 1;
	
	EmptyAimIdleAnimationID = nil; --Set to "nil" if you don't want to animate
	EmptyAimIdleAnimationSpeed = 1;
	
	AimFireAnimations = {
		{
			AimFireAnimationID = nil; --Set to "nil" if you don't want to animate
			AimFireAnimationSpeed = 1;
		};
	};
	
	AimLastFireAnimations = {
		{
			AimLastFireAnimationID = nil; --Set to "nil" if you don't want to animate
			AimLastFireAnimationSpeed = 1;
		};
	};
	
	--If FireAnimations or AimFireAnimations has a looped animation, it will play until you stop firing. NOTE: This only works well with Auto or BurstFire enabled, and only one animation in each fire animation table
	
	--Must enable "AltFire" first
	AltAnimationID = nil;
	AltAnimationSpeed = 1;
	AltTime = 1;
	AltName = "";	

	--  ====================
	--  MELEE ATTACK
	--  Gain an ability to perform melee attack
	--  ====================

	MeleeAttackEnabled = false;

	MeleeAttackAnimationID = nil;
	MeleeAttackAnimationSpeed = 1;

	MeleeDamage = 20;	
	MeleeDamageMultipliers = { --You can add more body parts to modify damage
		["Head"] = 2,
	};
	MeleeHeadshotHitmarker = true;
	
	HitboxType = "RotatedRegion"; --Two types: RotatedRegion and RaycastHitbox
	--RotatedRegion
	HitboxShape = Enum.PartType.Block;
	HitboxSize = Vector3.new(2.5, 2.5, 3);
	HitboxCFrame = CFrame.new(0, 0, -2);
	MaxPartsInRegion = 50;
	
	MaxHits = 1;
	
	HitIgnoreDelay = math.huge;
	
	--RaycastHitboxInstances = {{Ancestor, InstanceName}, {Ancestor, InstanceName}}	--NOTE: Can only have two tables at one frame. Also, the second table is optional. NOTE 2: Instance from character must have "DamagePoint" attachments
	--Ancestor = Two Types: "Tool" and "Character"
	RaycastHitboxInstances = {{"Tool", "Handle"}};
	RespectAltFireMode = true; --If this is set to true, the script will find damage points with prefix of current fire mode at the end of their names ("DamagePoint"..CurrentFireMode) [Example: "DamagePoint1", "DamagePoint2", etc.]

	BlockMelee = true; --Enable the melee to be blocked upon hitting. NOTE: Must tag model "CanBlock" (any value-type object with that name) in order to make it work
	BlockDelay = 0.1;	
	MeleeBlockEffectEnabled = true;
	MeleeBlockSoundIDs = {13583794181};
	MeleeBlockSoundPitchMin = 1; --Minimum pitch factor you will acquire
	MeleeBlockSoundPitchMax = 1; --Maximum pitch factor you will acquire
	MeleeBlockSoundVolume = 1;
	NormalizeMeleeBlockEffect = true;
	
	--To make melee ignore CanBlock-tagged model, add "TEAM" (BrickColor value) into "CanBlock". The melee will ignore it based on team colors (like Roblox's team system). NOTE: Your character must have "TEAM" tag to make this work
	
	--Hit effect
	MeleeHitEffectEnabled = true;
	MeleeHitSoundIDs = {6000828622};
	MeleeHitSoundPitchMin = 1; --Minimum pitch factor you will acquire
	MeleeHitSoundPitchMax = 1.5; --Maximum pitch factor you will acquire
	MeleeHitSoundVolume = 1;
	CustomMeleeHitEffect = false; --Emits your custom hit effect. NOTE: If you this setting disabled, hit effect will set to default(material tracker included)
	NormalizeMeleeHitEffect = true;
	
	MarkerEffectEnabled = true;
	MarkerEffectSize = 0.5;
	MarkerEffectTexture = {2078626}; --You can insert more IDs
	MarkerEffectVisibleTime = 3; --In second
	MarkerEffectFadeTime = 1; --In second
	MarkerPartColor = true; --Set to hit object color
	
	TriggerEffectOnce = false;	
	EffectDelay = 0.1; --Duration to trigger effect again after hitting solid part. NOTE: Must disable "TriggerEffectOnce" first; the effect won't be triggered on the same hit part
	
	--Blood
	MeleeBloodEnabled = true;
	MeleeHitCharSndIDs = {6398015798, 6398016125, 6398016391, 6398016618};
	MeleeHitCharSndPitchMin = 1; --Minimum pitch factor you will acquire
	MeleeHitCharSndPitchMax = 1; --Maximum pitch factor you will acquire
	MeleeHitCharSndVolume = 1;
	NormalizeMeleeBlood = false;

	MeleeBloodWoundEnabled = true;
	MeleeBloodWoundSize = 0.5;
	MeleeBloodWoundTexture = {2078626}; --You can insert more IDs
	MeleeBloodWoundTextureColor = Color3.fromRGB(255, 0, 0);
	MeleeBloodWoundVisibleTime = 3; --In second
	MeleeBloodWoundFadeTime = 1; --In second
	MeleeBloodWoundPartColor = true; --Set to hit object color
	
	--Metal
	MeleeMetalEnabled = true; --Enable the bullet to create metal effect upon hitting character. NOTE: Must tag character "IAmMetal" in order to make it work
	MeleeHitMetalSndIDs = {5462109045, 5462111332, 5462112925, 5462114029};
	MeleeHitMetalSndPitchMin = 1; --Minimum pitch factor you will acquire
	MeleeHitMetalSndPitchMax = 1; --Maximum pitch factor you will acquire
	MeleeHitMetalSndVolume = 1;
	
	MeleeMetalHoleEnabled = true;
	MeleeMetalHoleSize = 0.5;
	MeleeMetalHoleTexture = {2078626}; --You can insert more IDs
	MeleeMetalHoleTextureColor = Color3.fromRGB(255, 0, 0);
	MeleeMetalHoleVisibleTime = 3; --In second
	MeleeMetalHoleFadeTime = 1; --In second
	MeleeMetalHolePartColor = true; --Set to hit object color

	--Miscs
	MeleeKnockback = 0; --Setting above 0 will enabling the gun to push enemy back.
	MeleeLifesteal = 0; --In percent - Setting above 0 will allow user to steal enemy's health by dealing a damage to them.
	MeleeDebuff = false; --Enable the melee to give enemy a debuff. Source of debuff can be found inside "ReplicatedStorage" -> "Miscs" -> "Debuffs"
	MeleeDebuffName = "";
	MeleeDebuffChance = 100;
	ApplyMeleeDebuffOnCritical = false; --Enable "MeleeCriticalDamageEnabled" first
	MeleeCanBreakGlass = true;

	--Critical
	MeleeCriticalDamageEnabled = false;
	MeleeCriticalBaseChance = 5; --In percent
	MeleeCriticalDamageMultiplier = 3;

	OnMeleeHitEventName = "None";	
	OnMeleeHitEventData = {};
	
	--To make this feature functional, the animation must be included with "KeyFrameMarker" named "MeleeDamageSequence" (and additional marker named "MeleeDamageEndSequence" if "HitboxType" value is "RaycastHitbox"). Learn more about it here:
	--https://developer.roblox.com/en-us/api-reference/function/AnimationTrack/GetMarkerReachedSignal
	--https://developer.roblox.com/en-us/api-reference/class/KeyframeMarker	
	--https://developer.roblox.com/en-us/articles/using-animation-editor (Animation Events part)

	--	====================
	--	LASER TRAIL
	--	Create a trail of laser when travelling
	--	====================	

	LaserTrailEnabled = false;
	LaserTrailWidth = 0.5;
	LaserTrailHeight = 0.5;
	LaserTrailColor = Color3.fromRGB(0, 170, 255);
	RandomizeLaserColorIn = "None"; --"Whole" or "Segment"? Set to "None" to not use this
	LaserColorCycleTime = 5; --Duration of time to go through rainbow (not random colors). NOTE: This setting only works when "LaserBeam" and "RandomizeLaserColorIn" are enabled
	LaserTrailMaterial = Enum.Material.Neon;
	LaserTrailShape = "Block"; --"Block", "Cylinder" or... "Cone"?
	LaserTrailReflectance = 0;
	LaserTrailTransparency = 0;
	LaserTrailVisibleTime = 1; --In second
	LaserTrailFadeTime = 0.5; --In second
	ScaleLaserTrail = false; --Scale time is influenced by "LaserTrailFadeTime"
	LaserTrailScaleMultiplier = 1.5;

	DamageableLaserTrail = false; --Make laser trail become deadly
	LaserTrailDamage = 20;
	LaserTrailConstantDamage = true; --Make laser damage humanoids overtime
	LaserTrailDamageRate = 0.1; --In second

	--Miscs
	LaserTrailKnockback = 0; --Setting above 0 will enabling the gun to push enemy back.
	LaserTrailLifesteal = 0; --In percent - Setting above 0 will allow user to steal enemy's health by dealing a damage to them.
	LaserTrailDebuff = false; --Enable the laser to give enemy a debuff. Source of debuff can be found inside "ReplicatedStorage" -> "Miscs" -> "Debuffs"
	LaserTrailDebuffName = "";
	LaserTrailDebuffChance = 100;
	ApplyLaserTrailDebuffOnCritical = false; --Enable "LaserTrailCriticalDamageEnabled" first

	--Critical
	LaserTrailCriticalDamageEnabled = false;
	LaserTrailCriticalBaseChance = 5; --In percent
	LaserTrailCriticalDamageMultiplier = 3;

	OnLaserHitEventName = "None";	
	OnLaserHitEventData = {};

	--	====================
	--	LIGHTNING BOLT
	--	Create a trail of lightning when travelling
	--	====================		

	LightningBoltEnabled = false;
	BoltCount = 1;
	BoltRadius = 5;
	BoltWideness = 5;
	BoltWidth = 0.5;
	BoltHeight = 0.5;
	BoltColor = Color3.fromRGB(0, 170, 255);
	RandomizeBoltColorIn = "None"; --"Whole" or "Segment"? Set to "None" to not use this
	BoltMaterial = Enum.Material.Neon;
	BoltShape = "Block"; --"Block", "Cylinder" or... "Cone"?
	BoltReflectance = 0;
	BoltTransparency = 0;
	BoltVisibleTime = 1; --In second
	BoltFadeTime = 0.5; --In second
	ScaleBolt = false; --Scale time is influenced by "BoltFadeTime"
	BoltScaleMultiplier = 1.5;	

	--	====================
	--	LASER BEAM
	--  Enable the gun to fire focus beam. NOTE: This setting will enter automatic mode, and disable most of settings by default	
	--	====================		

	LaserBeam = false;
	LaserBeamRange = 100;
	LaserBeamStartupDelay = 1;
	LaserBeamStopDelay = 1;
	IgnoreHumanoids = false;
	LookAtInput = false; --Make both muzzle and hit points look at input's position

	LaserBeamStartupAnimationID = nil;
	LaserBeamStartupAnimationSpeed = 1;
	LaserBeamLoopAnimationID = nil;
	LaserBeamLoopAnimationSpeed = 1;
	LaserBeamStopAnimationID = nil;
	LaserBeamStopAnimationSpeed = 1;	

	--To configure damage for laser beam, see "LaserTrail" settings. NOTE: You don't have to set "LaserTrailEnabled", "DamageableLaserTrail" and "LaserTrailConstantDamage" to true

	--When this setting is enabled, the system won't visualize muzzle flash from visual effect folder (see ReplicatedStorage -> Miscs -> GunVisualEffects), but instead will visualize it from muzzle point of gun handle. So you have to put your effect inside muzzle point (Example effect is in it). NOTEL This is optional and is not affected by "MuzzleFlashEnabled" 

	--If you want muzzle flash to be bursted, you can add "EmitCount" int value into it, just like the rest of visual effects. Otherwise, muzzle flash will be (in)visible (depends on whether you are firing or not)

	--	====================
	--	LIMITED AMMO
	--	Make a gun has a limit ammo
	--	====================

	LimitedAmmoEnabled = true;
	Ammo = 60;
	MaxAmmo = 60; --Set to "math.huge" to allow user to carry unlimited ammo	

	--	====================
	--	CROSSHAIR
	--	A gun cursor
	--	====================

	CrossSize = 7;
	CrossExpansion = 100;
	CrossSpeed = 15;
	CrossDamper	= 0.8;	

	--	====================
	--	HITMARKER
	--	Mark hit when melee hits character
	--	====================

	HitmarkerEnabled = true;
	HitmarkerSoundIDs = {3748776946, 3748777642, 3748780065};
	--Normal
	HitmarkerColor = Color3.fromRGB(255, 255, 255);
	HitmarkerFadeTime = 0.4;
	HitmarkerSoundPitch = 1;
	--Headshot
	HitmarkerColorHS = Color3.fromRGB(255, 0, 0);
	HitmarkerFadeTimeHS = 0.4;
	HitmarkerSoundPitchHS = 1;	

	--	====================
	--	CAMERA RECOILING
	--	Make user's camera recoiling when shooting
	--	====================

	CameraRecoilingEnabled = true;
	Recoil = 25;
	AngleXMin = 1; --In degree
	AngleXMax = 1; --In degree
	AngleYMin = 0; --In degree
	AngleYMax = 0; --In degree
	AngleZMin = -1; --In degree
	AngleZMax = 1; --In degree
	Accuracy = 0.1; --In percent
	RecoilSpeed = 15; 
	RecoilDamper = 0.65;
	
	--	====================
	--	ADS
	--	Allow user to aim down sight
	--	====================

	ADSEnabled = true;
	ADSType = "Ironsight";
	ADSFieldOfView = 50;
	ADSMouseSensitivity = 0.2; --In percent
	ADSSpreadRedution = 0.6; --In percent
	ADSRecoilRedution = 0.6; --In percent
	ADSCrossScale = 0.6;
	HideCrosshair = true;
	ScopeDelay = 0; --Only works when "ADSType" value is "Sniper"
	ScopeSensitivity = 0.25;
	ScopeKnockbackMultiplier = 5;
	ScopeKnockbackSpeed = 15;
	ScopeKnockbackDamper = 0.65;
	ScopeSwaySpeed = 15;
	ScopeSwayDamper	= 0.65;

	TweenLength = 0.5; --In second
	EasingStyle = Enum.EasingStyle.Quart;
	EasingDirection = Enum.EasingDirection.Out;

	TweenLengthNAD = 0.5; --In second
	EasingStyleNAD = Enum.EasingStyle.Quart;
	EasingDirectionNAD = Enum.EasingDirection.Out;

	--  ====================
	--  SMOKE TRAIL
	--  Emit smoke trail while firing. NOTE: This setting is only for client
	--  ====================

	SmokeTrailEnabled = false;
	SmokeTrailRateIncrement = 1;
	MaximumRate = 4; --Beyond this will return "CurrentRate" to 0 and emit smoke trail. NOTE: Last smoke trail will be terminated after this
	MaximumTime = 1; --Maximum time that smoke trail won't be emitted

	--	====================
	--	FIRE SOUND EFFECTS
	--	Special effects for fire sound
	--	====================

	SilenceEffect = false; --Lower volume
	EchoEffect = true; --Create echo effect from distance
	LowAmmo = true; --Play sound when low ammo
	RaisePitch = false; --"LowAmmo" only. The lower ammo is, the higher pitch will play
	ShouldLoop = false; --Loop sound until stop firing. NOTE: "FireSound" must be Sound instance

	--	====================
	--	GORE VISUALIZER
	--	Create gore effect when humanoid died
	--	====================

	GoreEffectEnabled = false;
	GoreSoundIDs = {1930359546};
	GoreSoundPitchMin = 1; --Minimum pitch factor you will acquire
	GoreSoundPitchMax = 1.5; --Maximum pitch factor you will acquire
	GoreSoundVolume = 1;
	FullyGibbedLimbChance = 50; --In percent

	--	====================
	--	INSPECT ANIMATION
	--	Inspect the gun just to see how it looks
	--	====================

	InspectAnimationEnabled = false;
	InspectAnimationID = nil; --Set to "nil" if you don't want to animate
	InspectAnimationSpeed = 1;
	
	EmptyInspectAnimationID = nil;
	EmptyInspectAnimationSpeed = 1;
	
	--	====================
	--	TACTICAL RELOAD ANIMATION
	--	Reload the gun that has only fired a few rounds out of its magazine
	--	====================

	TacticalReloadAnimationEnabled = false;
	TacticalReloadAnimationID = nil; --Set to "nil" if you don't want to animate
	TacticalReloadAnimationSpeed = 1;
	TacticalReloadTime = 3;

	--	====================
	--	HOLD DOWN ANIMATION
	--	Character won't fire if hold down the gun
	--	====================

	HoldDownEnabled = false;
	HoldDownAnimationID = nil;
	HoldDownAnimationSpeed = 0.5;	

	--  ====================
	--  DAMAGE DROPOFF
	--  Calculate how the damage of a single shot decreases when the target hit is at a distance away from the gun shot. NOTE: This setting won't apply with "ExplosiveEnabled"
	--  ====================

	DamageDropOffEnabled = false;
	ZeroDamageDistance = 10000; --Anything hit at or beyond this distance will receive no damage; default is 10000
	FullDamageDistance = 1000; --Maximum distance that shots will do full damage. Default is 1000 and anything hit beyond this distance will receive less and less damage as the distance nears "ZeroDamageDistance"

	--	====================
	--	CRITICAL DAMAGE
	--	Damage critically within its chance
	--	====================

	CriticalDamageEnabled = false;
	CriticalBaseChance = 5; --In percent
	CriticalDamageMultiplier = 3;

	--	====================
	--	HIT VISUALIZER
	--	Create hit effect when a bullet hit something but not character(And hit sound, too)
	--	====================

	HitEffectEnabled = true;
	HitSoundIDs = {186809061, 186809249, 186809250, 186809252};
	HitSoundPitchMin = 1; --Minimum pitch factor you will acquire
	HitSoundPitchMax = 1.5; --Maximum pitch factor you will acquire
	HitSoundVolume = 1;
	CustomHitEffect = false; --Emits your custom hit effect. NOTE: If you this setting disabled, hit effect will set to default(material tracker included)
	NormalizeHitEffect = true;
	
	BulletHoleEnabled = true;
	BulletHoleSize = 0.5;
	BulletHoleTexture = {2078626}; --You can insert more IDs
	BulletHoleVisibleTime = 3; --In second
	BulletHoleFadeTime = 1; --In second
	PartColor = true; --Set to hit object color

	--How to add custom sounds for any material	

	--Go to ReplicatedStorage -> Miscs -> GunVisualEffects -> Common (Folder with specific tool name if you don't use common effects)
	-->>>
	--Open "HitEffect" folder and choose one of material folders
	-->>>
	--Add a "MaterialSounds" folder into it and insert any sound you desire
	-->>>
	--To play sound with different volume and pitch, add a folder named "Volume" or "Pitch" into specific sound object. Then insert two "Min" and "Max" number values into that folder, and adjust them whatever you like

	--How to add custom decals for bullet hole	

	--Do the same thing as first two steps of the way adding custom sound
	-->>>
	--Add a "MaterialDecals" folder into it and insert int value which defines id of decal. Don't forget to add "PartColor" bool value into value object, and keep it disabled if you don't want decal's color to be blended into hit part's

	--	====================
	--	BLOOD VISUALIZER
	--	Create blood when a bullet hit character(And hit character sound, too)
	--	====================
	
	--Blood
	BloodEnabled = true;
	HitCharSndIDs = {3802437008, 3802437361, 3802437696, 3802440043, 3802440388, 3802442962};
	HitCharSndPitchMin = 1; --Minimum pitch factor you will acquire
	HitCharSndPitchMax = 1; --Maximum pitch factor you will acquire
	HitCharSndVolume = 1;
	NormalizeBlood = false;

	BloodWoundEnabled = true;
	BloodWoundSize = 0.5;
	BloodWoundTexture = {2078626}; --You can insert more IDs
	BloodWoundTextureColor = Color3.fromRGB(255, 0, 0);
	BloodWoundVisibleTime = 3; --In second
	BloodWoundFadeTime = 1; --In second
	BloodWoundPartColor = true; --Set to hit object color
	
	--Metal
	MetalEnabled = true; --Enable the bullet to create metal effect upon hitting character. NOTE: Must tag character "IAmMetal" in order to make it work
	HitMetalSndIDs = {5462109045, 5462111332, 5462112925, 5462114029};
	HitMetalSndPitchMin = 1; --Minimum pitch factor you will acquire
	HitMetalSndPitchMax = 1; --Maximum pitch factor you will acquire
	HitMetalSndVolume = 1;
	
	MetalHoleEnabled = true;
	MetalHoleSize = 0.5;
	MetalHoleTexture = {2078626}; --You can insert more IDs
	MetalHoleTextureColor = Color3.fromRGB(255, 0, 0);
	MetalHoleVisibleTime = 3; --In second
	MetalHoleFadeTime = 1; --In second
	MetalHolePartColor = true; --Set to hit object color	

	--	====================
	--	BULLET WHIZZING SOUND
	--	Create a sound when a bullet travelling through character
	--	====================

	WhizSoundEnabled = true;
	WhizSoundIDs = {3809084884, 3809085250, 3809085650, 3809085996, 3809086455};
	WhizSoundVolume = 1;
	WhizSoundPitchMin = 1; --Minimum pitch factor you will acquire
	WhizSoundPitchMax = 1; --Maximum pitch factor you will acquire
	WhizDistance = 25;

	--	====================
	--	MUZZLE
	--	Create a muzzle flash when firing
	--	====================

	MuzzleFlashEnabled = true;
	MuzzleLightEnabled = true;
	LightBrightness = 4;
	LightColor = Color3.new(255/255, 283/255, 0/255);
	LightRange = 15;
	LightShadows = true;
	VisibleTime = 0.01; --In second

	--	====================
	--	BULLET SHELL EJECTION
	--	Eject bullet shells when firing
	--	====================

	BulletShellEnabled = true;
	BulletShellType = "Normal";
	BulletShellDelay = 0;
	BulletShellVelocity = 17;
	BulletShellRotVelocity = 40;
	RadomizeRotVelocity = true;
	AllowCollide = false; --If false, a bullet shell will go through any parts
	DisappearTime = 5; --In second
	BulletShellParticles = false;

	BulletShellHitSoundEnabled = true;
	BulletShellHitSoundIDs = {3909012115};
	BulletShellHitSoundVolume = 1;
	BulletShellHitSoundPitchMin = 1; --Minimum pitch factor you will acquire
	BulletShellHitSoundPitchMax = 1; --Maximum pitch factor you will acquire

	--	====================
	--	SHOTGUN
	--	Enable the gun to fire multiple bullet in one shot
	--	====================

	ShotgunEnabled = false;
	BulletPerShot = 8;

	ShotgunPump = false; --Make user pumping like Shotgun after firing
	ShotgunPumpinSpeed = 0.5; --In second
	ShotgunPumpinAnimations = {
		{
			ShotgunPumpinAnimationID = nil; --Set to "nil" if you don't want to animate
			ShotgunPumpinAnimationSpeed = 1;
		};
	};

	ShotgunReload = false; --Make user reloading like Shotgun, which user clipin shell one by one
	ShotgunClipinAnimationID = nil; --Set to "nil" if you don't want to animate
	ShotgunClipinAnimationSpeed = 1;
	ShellClipinSpeed = 0.5; --In second
	PreShotgunReload = false; --Make user pre-reloading before consecutive reload. NOTE: "ShotgunReload" must be enabled
	PreShotgunReloadAnimationID = nil; --Set to "nil" if you don't want to animate
	PreShotgunReloadAnimationSpeed = 1;
	PreShotgunReloadSpeed = 0.5; --In second

	ShotgunPattern = false;
	SpreadPattern = { --{x, y}. The number of tables inside it should be the same as "BulletPerShot"
		-- inner 3
		{0, -0.4};
		{-0.35, 0.2};
		{0.35, 0.2};

		-- outer five
		{0, 1};
		{0.95, 0.31};
		{0.59, -0.81};
		{-0.59, -0.81};
		{-0.95, 0.31};
	};

	--How "ShotgunPump" works [Example 1]:

	--Fire a (shot)gun
	-->>>
	--After "FireRate", user will pump it, creates pumpin delay + "PumpSound"

	--How "ShotgunReload" works [Example 2]:

	--Play "ShotgunClipinAnimation" + Play "ShotgunClipin" Audio
	-->>>
	--Wait "ShellClipinSpeed" second(s)
	-->>>
	--Repeat "AmmoPerClip" - "Current Ammo" times
	-->>>
	--Play "ReloadAnimation" + Play "ReloadSound"
	-->>>
	--Wait "ReloadTime"

	--	====================
	--	BURST FIRE
	--	Enable the gun to do burst firing like Assault Rifle
	--	====================

	BurstFireEnabled = false;
	BulletPerBurst = 3;
	BurstRate = 0.075; --In second
	CycleHandles = false; --Change handle every time you fire in burst state. This also affects "FireAnimations", "AimFireAnimations", "ShotgunPumpinAnimations", "LockOnScan" and "SelectiveFire"

	--	====================
	--	SELECTIVE FIRE
	--	Enable the user to switch firemode. NOTE: The following settings: "Auto", "FireRate", "BurstFireEnabled", "BulletPerBurst", "BurstRate" and "ChargedShotAdvanceEnabled" will be disabled if "SelectiveFireEnabled" is enabled
	--	====================

	SelectiveFireEnabled = false;
	FireModes = {1, 2, 3, true}; --"true" is a boolean which uses for autofire, while integer is being used for burst counts
	FireRates = {0.125, 0.5, 0.5, 0.1};
	BurstRates = {0, 0.075, 0.075, 0};
	FireModeTexts = {"SEMI-AUTO", "2-ROUND-BURST", "3-ROUND-BURST", "AUTO"};
	SwitchTime = 0.25; --In second

	SwitchAnimationID = nil; --Set to "nil" if you don't want to animate
	SwitchAnimationSpeed = 1;

	--The priority of firemode is from left to right

	--	====================
	--	EXPLOSIVE
	--	Make a bullet explosive so user can deal a damage to multiple enemy in single shot. NOTE: Explosion won't break joints
	--	====================

	ExplosiveEnabled = false;
	ExplosionSoundEnabled = true;
	ExplosionSoundIDs = {163064102};
	ExplosionSoundVolume = 1;
	ExplosionSoundPitchMin = 1; --Minimum pitch factor you will acquire
	ExplosionSoundPitchMax = 1.5; --Maximum pitch factor you will acquire
	ExplosionRadius = 8;

	DamageBasedOnDistance = false;
	DamageThroughWall = true;

	SelfDamage = false;
	SelfDamageRedution = 0.5; --In percent
	ReduceSelfDamageOnAirOnly = false;

	CustomExplosion = false;

	ExplosionKnockback = false; --Enable the explosion to knockback player. Useful for rocket jumping
	ExplosionKnockbackPower = 50;
	ExplosionKnockbackMultiplierOnPlayer = 2;
	ExplosionKnockbackMultiplierOnTarget = 2;

	ExplosionCraterEnabled = true;
	ExplosionCraterSize = 3;
	ExplosionCraterTexture = {53875997}; --You can insert more IDs
	ExplosionCraterVisibleTime = 3; --In second
	ExplosionCraterFadeTime = 1; --In second
	ExplosionCraterPartColor = false; --Set to hit object color

	--	====================
	--	PROJECTILE VISUALIZER
	--	Display a travelling projectile
	--	====================

	ProjectileType = "NewBullet"; --Set to "None" to not to visualize projectile
	BulletSpeed = 2000;
	TravelType = "Distance"; --Switch to either "Distance" or "Lifetime" to change how the bullet travels
	Range = 5000; --The furthest distance the bullet can travel
	Lifetime = 5; --The longest time the bullet can travel
	Acceleration = Vector3.new(0, 0, 0);
	RealAcceleration = 0;
	InvertRealAcceleration = false; --Set to true to make "BulletSpeed" fade out, and vice versa
	InitialBulletSpeed = 0; --Only works when "RealAcceleration" is over 0 and "InvertRealAcceleration" is not set to true	

	BulletParticle = false;
	BulletType = "Normal";
	MotionBlur = true;
	BulletSize = 0.4;
	BulletBloom = 0.005;
	BulletBrightness = 400;

	CanSpinPart = false;
	SpinX = 3;
	SpinY = 0;
	SpinZ = 0;

	DebrisProjectile = false; --Enable the projectile to become debris after hit
	AnchorDebris = false;
	CollideDebris = true;
	NormalizeDebris = false;
	BounceDebris = true; --Disable "AnchorDebris" first
	BounceVelocity = 30;
	WeldDebris = false; --Disable "AnchorDebris" and "CollideDebris" first

	DecayProjectile = false; --Enable the projectile to become debris when it stops travelling
	AnchorDecay = false;
	CollideDecay = true;
	DecayVelocity = 30;
	VelocityInfluence = true; --Apply previous velocity of travelling projectile to decaying one's, instead of "DecayVelocity"

	DisableDebrisContents = {  --Disable projectile's contents when it becomes debris
		Light = false;
		Particle = false;
		Trail = false;
		Beam = false;
		Sound = false;
	};

	Homing = false; --Allow projectile to move towards target
	HomingDistance = 250;
	TurnRatePerSecond = 1;
	HomeThroughWall = false;
	LockOnOnHovering = false;
	LockOnRadius = 10;
	LockOnDistance = 100;
	LockOnThroughWall = true;
	
	BlockBullet = true; --Enable the bullet to be blocked upon hitting. NOTE: Must tag model "CanBlock" (any value-type object with that name) in order to make it work
	BlockEffectEnabled = true;
	BlockSoundIDs = {13583794181};
	BlockSoundPitchMin = 1; --Minimum pitch factor you will acquire
	BlockSoundPitchMax = 1; --Maximum pitch factor you will acquire
	BlockSoundVolume = 1;
	NormalizeBlockEffect = true;
	ReflectBullet = true; --Enable the bullet to be reflected after getting blocked. NOTE: If model has	"CanBlock" tag, add "CanReflect" (any value-type object with that name) into it in order to make this setting work
	
	--To make bullet ignore CanBlock-tagged model, add "TEAM" (BrickColor value) into "CanBlock". The bullet will ignore it based on team colors (like Roblox's team system). NOTE: Your character must have "TEAM" tag to make this work
	
	RaycastHitbox = false; --Expand raycast. Useful for a projectile with bigger size and unique shape. NOTE: Experimental and very expensive, use it wisely
	RaycastHitboxData = { --Ray point data for raycast hitbox. Use CFrame only as it does same thing as Vector3, but also respects object space
		CFrame.new(-1, 1, -1);
		CFrame.new(1, 1, -1);
		CFrame.new(-1, -1, -1);
		CFrame.new(1, -1, -1);
		CFrame.new(1, -1, 1);
		CFrame.new(-1, -1, 1);
		CFrame.new(-1, 1, 1);
		CFrame.new(1, 1, 1);
	};
	
	--To make raycast hitbox data easily, add an attachment to projectile (create a new part if projectile doesn't exist), position it and then copy and paste its position to "RaycastHitboxData" table (CFrame.new(AttachmentPosition)). And repeat

	ShapeCast = false; --Use Roblox's official shapecast. NOTE: Enabling this will disable "RaycastHitbox" setting
	CastShape = "Block"; --"Block" or "Sphere"?
	CastSize = Vector3.new(1, 1, 1); --For "Block" shape
	CastRadius = 5; --For "Sphere" shape

	AnchorPoint = CFrame.new(0, 0, 0); --Specific point to align with ray point. NOTE: This only works when "BounceAmount" value is above 0 or "SuperBounce" is enabled
	BounceDelay = 1; --Duration of ignoring last hit object. Useful for avoiding unexpected behaviour when projectile's hitbox point overlaps object that was hit previously. For "RaycastHitbox" and "ShapeCast" only

	UpdateRayInExtra = false; --Additional update for your custom raycast behavior, such as sine wave projectile
	ExtraRayUpdater = "Template"; --Name of updater, see "ReplicatedStorage" -> "Modules" -> "RayUpdateFolder"

	ShootType = "Projectile";
	CustomShotName = "Template"; --For "Custom" shoot type only
	CustomShotData = {};

	--Projectile: Shoot bullet with physic-based arc
	--Hitscan: Shoot bullet with light-speed
	--Custom: Shoot fully customizable bullet that doesn't rely on gun settings. NOTE: For server only

	--NOTE: Setting "ShootType" "Hitscan" will restrict the following physic-based settings:
	--"Acceleration"
	--"Homing"
	--"RaycastHitbox"
	--Ricochet effect ("BounceElasticity", "FrictionConstant", "IgnoreSlope", "SuperBounce", "HitEventOnTermination") [Ricochet effect still works for hitscan however. But only physic-based settings are disabled]

	--	====================
	--	CHARGED SHOT
	--	Make a gun charging before firing. Useful for a gun like "Railgun" or "Laser Cannon"
	--	====================

	ChargedShotEnabled = false;
	ChargingTime = 1;

	--	====================
	--	MINIGUN
	--	Make a gun delay before/after firing
	--	====================

	MinigunEnabled = false;
	DelayBeforeFiring = 1;
	DelayAfterFiring = 1;
	MinigunRevUpAnimationID = nil;
	MinigunRevUpAnimationSpeed = 1;
	MinigunRevDownAnimationID = nil;
	MinigunRevDownAnimationSpeed = 1;

	--	====================
	--	BATTERY
	--	Make a gun overheat when overcharge
	--	====================

	BatteryEnabled = false;
	MaxHeat = 100;
	TimeBeforeCooldown = 3;
	CooldownTime = 0.05;
	CooldownRate = 1; 
	OverheatTime = 2.5;
	HeatPerFireMin = 7;
	HeatPerFireMax = 8;
	MinDepletion = 2;
	MaxDepletion = 4;
	ShotsForDepletion = 12;
	
	OverheatEffect = "Template";
	
	OverheatAnimationID = nil;
	OverheatAnimationSpeed = 1;

	--	====================
	--	MISCELLANEOUS
	--	Etc. settings for the gun
	--	====================

	Knockback = 0; --Setting above 0 will enabling the gun to push enemy back
	Lifesteal = 0; --In percent - Setting above 0 will allow user to steal enemy's health by dealing a damage to them

	Debuff = false; --Enable the bullet to give enemy a debuff. Source of debuff can be found inside "ReplicatedStorage" -> "Miscs" -> "Debuffs"
	DebuffName = "";
	DebuffChance = 100;
	ApplyDebuffOnCritical = false; --Enable "CriticalDamageEnabled" first

	PenetrationType = "HumanoidPenetration"; --2 types: "WallPenetration" and "HumanoidPenetration"
	PenetrationDepth = 0; --"WallPenetration" only. This is how many studs a bullet can penetrate into a wall. So if penetration is 0.5 and the wall is 1 studs thick, the bullet won't come out the other side. NOTE: "ExplosiveEnabled" doesn't apply to this, and having "RaycastHitbox" enabled can take more studs at a time when penetrating solid objects 
	PenetrationAmount = 0; --"HumanoidPenetration" only. Setting above 0 will enabling the gun to penetrate up to XX victim(s). Cannot penetrate wall. NOTE: "ExplosiveEnabled" doesn't apply to this
	PenetrationIgnoreDelay = math.huge; --Time before removing penetrated objects from ignore list. Useful for when you have "Homing" enabled. Set to "math.huge" to prevent from removing
	PenetrationModifiers = {
		--["Plastic"] = 1;
	}; --"WallPenetration" only. Allow to modify "PenetrationDepth" reduction based on material of hit part. The value range for each listed material is 0-XX (Default is 1), and increasing the value makes reduction more potent
	
	BounceAmount = 0; --Setting above 0 will enabling the bullet to bounce objects in amount of bounces. NOTE: This will disable "PenetrationDepth" setting but "PenetrationAmount", and having "RaycastHitbox" enabled will sometimes make the bullet bounce weirdly
	BounceElasticity = 1;
	FrictionConstant = 0;
	IgnoreSlope = false; -- Enable the bullet to keep bouncing forwards on slope. Useful for a Metal Slug's Drop Shot styled projectile. NOTE: This only works when "Acceleration" is not a zero vector, and its Y axis is lower than 0
	SlopeAngle = 45; -- Angle of slope to stop bouncing forwards
	BounceHeight = 50;
	NoExplosionWhileBouncing = false; --Enable the bullet to be prevented from exploding on bounce. NOTE: "NoExplosionWhileBouncing" will be disabled after reaching 0 bounce
	StopBouncingOn = "None"; --Enable the bullet to be forced to stop bouncing after hitting "Humanoid" or "Object". Set to "None" to disable this
	SuperBounce = false; --Enable the bullet to bounce indefinitely. NOTE: This doesn't affect "BounceAmount" but won't remove bullet regardless of its limited amount of bounces
	BounceBetweenHumanoids = false; --Enable the bullet to reflect on other humanoids. NOTE: This has shared settings with "Homing" like "HomingDistance" and "HomeThroughWall" (No need to enable "Homing" however)
	PredictDirection = false; --Predict humanoid's movement to bounce at. NOTE: This does not apply to "HitscanMode"
	MaxBounceAngle = 0; --The maximum angle for a bounce. Value range is 0-90, and lowering the value will make bullet become likely to be bounced and vice versa
	UsePartDensity = false; --Affects bounce angle
	UseBulletSpeed = false; --Affects bounce angle
	
	HitEventOnTermination = true; --Trigger "FinalHit" event after exceeding maximum lifetime or travel distance. Useful for a TF2 styled grenade launcher

	SelfKnockback = false; --Enable the gun to knockback player. Useful for shotgun jumping
	SelfKnockbackPower = 50;
	SelfKnockbackMultiplier = 2;
	SelfKnockbackRedution = 0.8;

	ProjectileMotion = false; --Enable the gun to visible trajectory. Useful for projectile arc weapon	

	FriendlyFire = false; --Enable the user to inflict damage on teammates (works with custom "TEAM" as well)

	BlacklistParts = {["Part Name Here"] = true}; --Put any part name you want here to blacklist
	IgnoreBlacklistedParts = true; --Enable the bullet to go through blacklisted parts. Set to false to make bullet hit at them (won't detect humanoid at that moment) 	

	CanBreakGlass = true;

	OnHitEventName = "None";
	OnHitEventData = {};

	OnShootEventName = "None";
	OnShootEventData = {};	
	
	OnClientShootEventName = "None";
	OnClientShootEventData = {};		

	--	====================
	--	CHARGED SHOT ADVANCE
	--	Unlike "ChargedShot", this advanced version will allow gun to charge by holding down input. NOTE: This setting will disable some features such as "Auto", "ChargedShot", "MinigunEnabled"
	--	====================
	
	ChargedShotAdvanceEnabled = false;
	ShouldFireBeforeCharging = true;
	TimeBeforeAdvancedCharging = 0;
	AdvancedChargingTime = 5; --Known as Level3ChargingTime
	Level1ChargingTime = 1;
	Level2ChargingTime = 2;
	ChargeLevelCap = 3; --Maximum level of charge. Affects charge time. Max value is 3
	ChargingSoundIncreasePitch = true;
	ChargingSoundPitchRange = {1, 1.5};

	ChargeEffect = "Template";

	ChargingAnimationEnabled = false; --You need an animation ID in order to enable it
	ChargingAnimationID = nil; --Set to "nil" if you don't want to animate
	ChargingAnimationSpeed = 1;
	ChargingAnimationFadeTime = 0.1;
	
	AimChargingAnimationID = nil; --Set to "nil" if you don't want to animate
	AimChargingAnimationSpeed = 1;
	AimChargingAnimationFadeTime = 0.1;
	
	ChargeAlterTable = {
		--[[
		FireRate = {
			Level1 = 1;
			Level2 = 2;
			Level3 = 3;
		};
		]]
	};

	--	====================
	--	HOLD AND RELEASE
	--	Similar to "ChargedShotAdvance", but this is just hold-the-trigger-and-release-to-fire feature
	--	====================
	
	HoldAndReleaseEnabled = false;
	TimeBeforeHolding = 0;
	HoldingTime = 1; --Time before being able to fire

	HoldChargeEffect = "Template";
	
	LockOnScan = false; --Enable the gun to track targets that are within frame when holding down input, and fire at them when holding up. NOTE: This will overwrite "BurstFire" and "HoldingTime" settings
	TimeBeforeScan = 0.5;
	ScanRate = 0.5;
	ScanRateOnLockedTarget = 0.5;
	MaximumTargets = 3; --Amount of targets to track
	LockOnScanBurstRate = 0.1; --In second
	InstaBurst = false;
	TriggerOnce = false; --Should increase heat, consume ammo once. NOTE: Only works when "InstaBurst" is enabled, also affects "CycleHandles"
	RemoveTargetsWhenOutbound = true;
	ShouldFireWhenTheresTarget = false;
	IgnoreLockedTargets = true;
	ContinueTrackingTargets = true; --Continue tracking nearby targets (even tracked ones) when number of them within scan frame lesser than "MaximumTargets". NOTE: Not affected by "IgnoreLockedTarget"
	StayInCenter = false;
	Radar = "Default";
	Marker = "Default";
	OnScannerToggle = function(Frame, MaximumTargets, Enabled)
		if Frame then
			local TweenService = game:GetService("TweenService")
			if Enabled then
				Frame.Scan:Play()
				Frame.Message.Text = "Searching targets... (0/"..MaximumTargets..")"
				TweenService:Create(Frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.5, 0.5)}):Play()
				TweenService:Create(Frame.UIStroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0}):Play()
				TweenService:Create(Frame.Message, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextStrokeTransparency = 0.75, TextTransparency = 0}):Play()
			else
				Frame.Message.Text = ""
				TweenService:Create(Frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.5 * 1.25, 0.5 * 1.25)}):Play()
				TweenService:Create(Frame.UIStroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 1}):Play()
				TweenService:Create(Frame.Message, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextStrokeTransparency = 1, TextTransparency = 1}):Play()
			end
		end
	end;
	OnScannerUpdate = function(Frame, TargetCounts, MaximumTargets, AlreadyLocked, Track)
		if Frame then
			if TargetCounts < MaximumTargets then
				if Track then
					Frame["LockOn"..(AlreadyLocked and "Continue" or "")]:Play()
				end
				Frame.Message.Text = "Searching targets... ("..TargetCounts.."/"..MaximumTargets..")"
			else
				if Track then
					Frame.LockOnFull:Play()
				end
				Frame.Message.Text = "Ready! ("..TargetCounts.."/"..MaximumTargets..")"
			end
		end
	end;
	OnScannerRender = function(Frame, dt)

	end;
	OnTrackingTarget = function(Marker)

	end;

	--Charging animation and charging sound are shared from "ChargedShotAdvance" to this feature	

	--You can adjust scan distance by changing "LockOnDistance" value, or lock on through wall by checking "LockOnThroughWall". NOTE: No need to enable "Homing" and "LockOnOnHovering" settings
	
	--	====================
	--	CONDITIONABLE MODS
	--	Mod settings under special conditions
	--	====================

	Conditions = {
		--[[
		["Maxwell"] = {
			Settings = {
				Auto = true;
				FireRate = 0.1;
			}; --Set values from existing settings
			Mods = {
				BaseDamage = 1.5;
			}; --Multiplies values of existing settings. NOTE: Must be number
			Adds = {
				NewValue = true;
			}; --Add new settings
		};
		]]
	}; --Affect shot generally
	ConditionsInIndividualShot = {}; --Affect shot from burst fire
	ConditionsInIndividualBullet = {}; --Affect individual bullet (shotgun)
	
	--	====================
	--	ANIMATION KEYFRAMES
	--	List of keyframes that can be customized for existing animations
	--	====================

	AnimationKeyframes = {
	};

	--Template:

--[[	
	["AnimationName"] = {
		["KeyframeName"] = function(keyframeName, tool)
			print(keyframeName)
		end;
	};	
]]

	--How to use:

	--Copy and paste template table above into "AnimationKeyframes" table and uncomment it
	-->>>
	--Change "AnimationName" to specific string that is listed below
	-->>>
	--Change "KeyframeName" to existing keyframe name from your existing animation
	-->>>
	--Now write something you want inside its callback function

	--NOTE: To make this work, open animation editor and import your animation. Next, add animation event (edit if it exists), and then move (event) keyframe names to "Parameter" side whilst everything in "Event Name" side is renamed to "AnimationEvents"
	--NOTE 2: You can add more than one table. For an example:

--[[
	AnimationKeyframes = {
		["EquippedAnim"] = {
			["1"] = function(keyframeName, tool)
				print(keyframeName)
			end;
			["2"] = function(keyframeName, tool)
				print(keyframeName)
			end;
		};
		["ReloadAnim"] = {
			["1"] = function(keyframeName, tool)
				print(keyframeName)
			end;
			["2"] = function(keyframeName, tool)
				print(keyframeName)
			end;
			["3"] = function(keyframeName, tool)
				print(keyframeName)
			end;
		};
	};
]]

	--List of supported animations:
	--IdleAnim
	--EmptyIdleAnim
	--FireAnim_[index]
	--LastFireAnim_[index]
	--ReloadAnim
	--TacticalReloadAnim
	--ShotgunClipinAnim
	--ShotgunPumpinAnim_[index]
	--HoldDownAnim
	--EquippedAnim
	--EmptyEquippedAnim
	--AimIdleAnim
	--AimFireAnim
	--AimFireAnim_[index]
	--AimLastFireAnim_[index]
	--AimChargingAnim
	--InspectAnim
	--EmptyInspectAnim
	--PreShotgunReloadAnim
	--MinigunRevUpAnim
	--MinigunRevDownAnim
	--ChargingAnim
	--SwitchAnim
	--OverheatAnim
	--MeleeAttackAnim		
	--AltAnim
	--LaserBeamStartupAnim
	--LaserBeamLoopAnim
	--LaserBeamStopAnim			

	--	====================
	--	END OF SETTING
	--	====================
}

return table.isfrozen(Module) and Module or table.freeze(Module)