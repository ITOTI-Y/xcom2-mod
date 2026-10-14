// The Avenger HUD and the tactical HUD stay up for their whole layer, so the hotkey panel lives on them.
class UIScreenListener_CheatUI extends UIScreenListener;

event OnInit(UIScreen Screen)
{
	if ((UIAvengerHUD(Screen) != none || UITacticalHUD(Screen) != none) && Screen.GetChildByName('CheatUI_Hotkey', false) == none)
	{
		Screen.Spawn(class'UICheatUI_Hotkey', Screen).InitHotkey();
	}
}

defaultproperties
{
	ScreenClass = none;
}
