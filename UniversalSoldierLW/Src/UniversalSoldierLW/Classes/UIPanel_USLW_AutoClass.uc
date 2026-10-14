//---------------------------------------------------------------------------------------
//  Skips the class choice of WOTC_ChooseMyClass. Every rookie becomes a universal
//  soldier, so its screen has nothing to offer: once it is up, the rookie is promoted
//  the way that mod promotes, the screen is closed, and the promotion screen opens,
//  where the specialization choice follows. The promotion waits a frame, since the
//  screen is still being pushed when the listener sees it.
//---------------------------------------------------------------------------------------
class UIPanel_USLW_AutoClass extends UIPanel;

const CHOOSER_SCREEN = 'UIChooseClass_WOTC_ChooseMyClass';

var UIScreen ChooserScreen;

static function bool IsClassChooser(UIScreen CandidateScreen)
{
	return CandidateScreen != none && CandidateScreen.Class.Name == CHOOSER_SCREEN;
}

simulated function UIPanel_USLW_AutoClass InitAutoClass(UIScreen InScreen)
{
	ChooserScreen = InScreen;
	InitPanel('USLW_AutoClass');
	Hide();
	SetTimer(0.01, false, nameof(Promote));
	return self;
}

simulated function Promote()
{
	local UIArmory_MainMenu MainMenu;
	local XComGameState NewGameState;
	local XComGameState_Unit Unit;
	local StateObjectReference UnitRef;

	MainMenu = UIArmory_MainMenu(`SCREENSTACK.GetFirstInstanceOf(class'UIArmory_MainMenu'));
	if (MainMenu == none)
	{
		return;
	}
	UnitRef = MainMenu.UnitReference;
	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
	if (Unit == none || Unit.GetRank() != 0 || !Unit.CanRankUpSoldier())
	{
		return;
	}

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("USLW promote rookie");
	Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
	Unit.MakeItemsAvailable(NewGameState, false);
	Unit.RankUpSoldier(NewGameState, class'USLW_Specs'.const.CLASS_NAME);
	Unit.ApplySquaddieLoadout(NewGameState);
	Unit.ApplyBestGearLoadout(NewGameState);
	`XEVENTMGR.TriggerEvent('PromotionEvent', Unit, Unit, NewGameState);
	`GAMERULES.SubmitGameState(NewGameState);
	`XSTRATEGYSOUNDMGR.PlaySoundEvent("StrategyUI_Recruit_Soldier");

	ChooserScreen.CloseScreen();
	`HQPRES.UIArmory_Promotion(UnitRef);
}
