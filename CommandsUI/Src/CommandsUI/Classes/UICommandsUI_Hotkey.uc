//---------------------------------------------------------------------------------------
//  Opens and closes the command menu on HOTKEY, before any screen sees the key.
//
//  The Highlander's global input subscription must be removed before its callback's
//  owner goes away, so this invisible panel lives on the HUD of the current layer and
//  unsubscribes when it is removed or destroyed with the map. On the tactical HUD it
//  also turns the recorded toggles back on, once the mission has finished loading.
//---------------------------------------------------------------------------------------
class UICommandsUI_Hotkey extends UIPanel;

const TOGGLE_DELAY = 3.0;

var bool bSubscribed;

simulated function UICommandsUI_Hotkey InitHotkey()
{
	InitPanel('CommandsUI_Hotkey');
	Hide();
	Movie.Pres.ScreenStack.SubscribeToOnInput(OnInput);
	bSubscribed = true;
	if (UITacticalHUD(Screen) != none)
	{
		SetTimer(TOGGLE_DELAY, false, nameof(ApplySavedToggles));
	}
	return self;
}

simulated function ApplySavedToggles()
{
	class'CommandsUI_Commands'.static.ApplySavedToggles();
}

simulated function bool OnInput(int iInput, int ActionMask)
{
	local UIScreenStack Stack;
	local UIScreen Menu;

	if (iInput != class'CommandsUI_Commands'.default.HOTKEY)
	{
		return false;
	}
	Stack = Movie.Pres.ScreenStack;
	// Typing into a dialog must not toggle the menu.
	if (Stack.IsInStack(class'UIInputDialogue'))
	{
		return false;
	}
	if ((ActionMask & class'UIUtilities_Input'.const.FXS_ACTION_RELEASE) == 0)
	{
		return true;
	}
	Menu = Stack.GetFirstInstanceOf(class'UICommandsUI_Menu');
	if (Menu != none)
	{
		Menu.CloseScreen();
	}
	else
	{
		Stack.Push(Movie.Pres.Spawn(class'UICommandsUI_Menu', Movie.Pres), Movie.Pres.Get2DMovie());
	}
	return true;
}

simulated function Unsubscribe()
{
	if (bSubscribed && Movie != none && Movie.Pres != none && Movie.Pres.ScreenStack != none)
	{
		Movie.Pres.ScreenStack.UnsubscribeFromOnInput(OnInput);
	}
	bSubscribed = false;
}

simulated event Removed()
{
	Unsubscribe();
	super.Removed();
}

simulated event Destroyed()
{
	Unsubscribe();
	super.Destroyed();
}
