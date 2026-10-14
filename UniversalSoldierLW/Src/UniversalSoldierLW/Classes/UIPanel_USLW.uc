//---------------------------------------------------------------------------------------
//  Added to every promotion screen. It opens the specialization choice once per soldier
//  when it is pending, offers the stat upgrades, and restores a tree that a respec
//  rebuilt from the class template. The soldier shown can change without the screen
//  being recreated, so it is polled.
//---------------------------------------------------------------------------------------
class UIPanel_USLW extends UIPanel;

var UIArmory ArmoryScreen;
var UIButton StatButton;
var int PromptedUnitID;

var localized string strUpgradeStats;

simulated function UIPanel_USLW InitUSLWPanel(UIArmory InScreen)
{
	ArmoryScreen = InScreen;
	InitPanel('USLW_Panel');
	SetAnchor(class'UIUtilities'.const.ANCHOR_BOTTOM_RIGHT);
	SetPosition(-330, -170);

	StatButton = Spawn(class'UIButton', self);
	StatButton.InitButton('USLW_StatButton', strUpgradeStats, OnStatButton);
	StatButton.SetPosition(0, 40);

	Poll();
	SetTimer(0.25, true, nameof(Poll));
	return self;
}

simulated function Poll()
{
	local XComGameState_Unit Unit;
	local bool bNeedsSpecs;

	Unit = ArmoryScreen != none ? ArmoryScreen.GetUnit() : none;
	if (Unit == none || !Unit.IsSoldier())
	{
		Hide();
		return;
	}
	Show();
	bNeedsSpecs = class'USLW_Specs'.static.NeedsSpecs(Unit);
	StatButton.SetVisible(class'USLW_Stats'.default.STAT_UPGRADES.Length > 0);

	if (`SCREENSTACK.GetCurrentScreen() != ArmoryScreen)
	{
		return;
	}
	if (class'USLW_Specs'.static.NeedsTreeRestore(Unit))
	{
		RestoreTree(Unit.GetReference());
	}
	else if (bNeedsSpecs && PromptedUnitID != Unit.ObjectID)
	{
		PromptedUnitID = Unit.ObjectID;
		OpenSpecScreen(Unit.GetReference());
	}
}

// A respec that ranked the soldier up again from the class template also reset the
// stats the upgrades had raised, so the record of those upgrades is dropped with it.
simulated function RestoreTree(StateObjectReference UnitRef)
{
	local XComGameState NewGameState;
	local XComGameState_Unit Unit;
	local XComGameState_USLW_Unit Comp;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("USLW restore ability tree");
	Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
	Comp = class'USLW_Specs'.static.GetOrCreateComponent(Unit, NewGameState);
	class'USLW_Specs'.static.RestoreTree(Unit, Comp, NewGameState);
	Comp.StatPurchases.Length = 0;
	`GAMERULES.SubmitGameState(NewGameState);
	RefreshArmory(UnitRef);
}

// The promotion screen is rebuilt for the soldier, since its columns change; the main
// menu only needs its data refreshed.
static function RefreshArmory(StateObjectReference UnitRef)
{
	local UIArmory_MainMenu MainMenu;

	if (`SCREENSTACK.GetFirstInstanceOf(class'UIArmory_Promotion') != none)
	{
		class'UIArmory_Promotion'.static.CycleToSoldier(UnitRef);
		return;
	}
	MainMenu = UIArmory_MainMenu(`SCREENSTACK.GetFirstInstanceOf(class'UIArmory_MainMenu'));
	if (MainMenu != none)
	{
		MainMenu.PopulateData();
	}
}

simulated function OpenSpecScreen(StateObjectReference UnitRef)
{
	local UIChooseSpecs_USLW SpecScreen;

	SpecScreen = Movie.Pres.Spawn(class'UIChooseSpecs_USLW', Movie.Pres);
	SpecScreen.UnitRef = UnitRef;
	`SCREENSTACK.Push(SpecScreen, `HQPRES.Get3DMovie());
}

simulated function OnStatButton(UIButton Button)
{
	local UIStatUpgrade_USLW StatScreen;

	StatScreen = Movie.Pres.Spawn(class'UIStatUpgrade_USLW', Movie.Pres);
	StatScreen.UnitRef = ArmoryScreen.GetUnit().GetReference();
	`SCREENSTACK.Push(StatScreen, `HQPRES.Get3DMovie());
}

defaultproperties
{
	PromptedUnitID = -1;
}
