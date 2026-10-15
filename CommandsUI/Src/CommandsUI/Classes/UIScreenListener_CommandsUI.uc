// The Avenger HUD and the tactical HUD stay up for their whole layer, so the hotkey panel lives on them.
class UIScreenListener_CommandsUI extends UIScreenListener;

event OnInit(UIScreen Screen)
{
	if ((UIAvengerHUD(Screen) != none || UITacticalHUD(Screen) != none) && Screen.GetChildByName('CommandsUI_Hotkey', false) == none)
	{
		Screen.Spawn(class'UICommandsUI_Hotkey', Screen).InitHotkey();
	}
}

defaultproperties
{
	ScreenClass = none;
}
