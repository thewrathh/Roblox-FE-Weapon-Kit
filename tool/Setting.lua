local Module = {
	--	====================
	--	BASIC
	--	A basic settings for the gun
	--	====================
	
	AltFire = false; --Enable the user to alt fire. NOTE: Must have aleast two setting modules
	
	ThirdPersonADS = true; --Enable the user to aim down sight in third person. NOTE: RMB-ADS only works when user has ShiftLock enabled
	ForceFirstPerson = false; --Lock the user camera to first person while ADS. NOTE: Only works when "ThirdPersonADS" is enabled
	
	AutoReload = true; --Reload automatically when you run out of mag; disabling it will make you reload manually
	CancelReload = true; --Exit reload state when you fire the gun
	
	DirectShootingAt = "None"; --"FirstPerson", "ThirdPerson" or "Both". Make bullets go straight from the fire point instead of going to input position. Set to "None" to disable this

	CustomGripEnabled = false; --NOTE: Must disable "RequiresHandle" first
	CustomGrips = {
		[1] = {
			CustomGripName = "Handle";
			CustomGripPart0 = {"Character", "Right Arm"}; --Base
			CustomGripPart1 = {"Tool", "Handle"}; --Target
			AlignC0AndC1FromDefaultGrip = true;
			CustomGripCFrame = false;
			CustomGripC0 = CFrame.new(0, 0, 0);
			CustomGripC1 = CFrame.new(0, 0, 0);	
		}
		--CustomGripPart[0/1] = {Ancestor, InstanceName}
		--Supported ancestors: Tool, Character
		--NOTE: Don't set "CustomGripName" to "RightGrip"
		--NOTE 2: "CustomGripPart0" must always be character limb, while "CustomGripPart1" is tool handle
		--NOTE 3: "AlignC0AndC1FromDefaultGrip" only works when there's at least one tool handle named "Handle" existing
	};

	--	====================
	--	UNIVERSAL AMMO
	--	Use shared ammo instead of individual one. Useful for double barrel shotgun, ect. NOTE: This will disable "LimitedAmmo" setting in each setting module
	--	====================	

	UniversalAmmoEnabled = false;
	Ammo = 60;
	MaxAmmo = 60; --Set to "math.huge" to allow user to carry unlimited ammo	

	--	====================
	--	WALK SPEED MODIFIER
	--	Modify walk speed upon equipping the gun
	--	====================

	WalkSpeedModifierEnabled = false;
	WalkSpeed = 32;

	--	====================
	--	MISCELLANEOUS
	--	Etc. settings for the gun
	--	====================
	
	DualWeldEnabled = false; --Enable the user to hold two guns instead one. In order to make this setting work, you must have second handle named "Handle2". NOTE: Enabling "CustomGripEnabled" won't make this setting work	

	MagCartridge = false; --Display magazine cartridge interface (cosmetic only)
	MaxCount = 200;
	RemoveOldAtMax = false;
	MaxRotationSpeed = 360;
	Drag = 1;
	Gravity = Vector2.new(0, 1000);
	Ejection = true;
	Shockwave = true;
	Velocity = 50;
	XMin = -4;
	XMax = -2;
	YMin = -6;
	YMax = -5;
	DropAllRemainingBullets = false;
	DropVelocity = 10;
	DropXMin = -5;
	DropXMax = 5;
	DropYMin = -0.1;
	DropYMax = 0;

	--	====================
	--	INPUTS
	--	List of inputs that can be customized
	--	====================

	Keyboard = {
		Reload = Enum.KeyCode.R;
		HoldDown = Enum.KeyCode.E;
		Inspect = Enum.KeyCode.F;
		Switch = Enum.KeyCode.V;
		ToogleAim = Enum.KeyCode.Q;
		Melee = Enum.KeyCode.H;
		AltFire = Enum.KeyCode.C;
	};

	Controller = {
		Fire = Enum.KeyCode.ButtonR1;
		Reload = Enum.KeyCode.ButtonX;
		HoldDown = Enum.KeyCode.DPadUp;
		Inspect = Enum.KeyCode.DPadDown;
		Switch = Enum.KeyCode.DPadRight;
		ToogleAim = Enum.KeyCode.ButtonL1;
		Melee = Enum.KeyCode.ButtonR3;
		AltFire = Enum.KeyCode.DPadRight;
	};

	--	====================
	--	END OF SETTING
	--	====================
}

return table.isfrozen(Module) and Module or table.freeze(Module)
