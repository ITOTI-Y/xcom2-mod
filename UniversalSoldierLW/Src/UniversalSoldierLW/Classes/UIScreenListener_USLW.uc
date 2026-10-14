// Every promotion screen, including the Community Promotion Screen, extends UIArmory_Promotion.
// The class choice of WOTC_ChooseMyClass is skipped, as every rookie becomes a universal
// soldier.
class UIScreenListener_USLW extends UIScreenListener;

event OnInit(UIScreen Screen)
{
	if (UIArmory_Promotion(Screen) != none)
	{
		Screen.Spawn(class'UIPanel_USLW', Screen).InitUSLWPanel(UIArmory(Screen));
	}
	else if (class'UIPanel_USLW_AutoClass'.static.IsClassChooser(Screen))
	{
		Screen.Spawn(class'UIPanel_USLW_AutoClass', Screen).InitAutoClass(Screen);
	}
}

defaultproperties
{
	ScreenClass = none;
}
