// The Avenger HUD and the tactical HUD stay up for their whole layer, so the hotkey panel
// lives on them. The pause menu of a single-player campaign gets an entry that opens the
// command menu.
class UIScreenListener_CommandsUI extends UIScreenListener;

event OnInit(UIScreen Screen)
{
	local UIPauseMenu PauseMenu;
	local CommandsUI_PauseMenuEntry Entry;

	if ((UIAvengerHUD(Screen) != none || UITacticalHUD(Screen) != none) && Screen.GetChildByName('CommandsUI_Hotkey', false) == none)
	{
		Screen.Spawn(class'UICommandsUI_Hotkey', Screen).InitHotkey();
	}
	PauseMenu = UIPauseMenu(Screen);
	if (PauseMenu != none && PauseMenu.Movie.Pres.m_eUIMode != eUIMode_Shell && XComMPTacticalGRI(PauseMenu.WorldInfo.GRI) == none)
	{
		Entry = new class'CommandsUI_PauseMenuEntry';
		Entry.Inject(PauseMenu);
	}
}

defaultproperties
{
	ScreenClass = none;
}
