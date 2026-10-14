//---------------------------------------------------------------------------------------
//  Opens and closes the cheat menu on HOTKEY, before any screen sees the key.
//
//  The Highlander's global input subscription must be removed before its callback's
//  owner goes away, so this invisible panel lives on the HUD of the current layer and
//  unsubscribes when it is removed or destroyed with the map.
//---------------------------------------------------------------------------------------
class UICheatUI_Hotkey extends UIPanel;

var bool bSubscribed;

simulated function UICheatUI_Hotkey InitHotkey()
{
	InitPanel('CheatUI_Hotkey');
	Hide();
	Movie.Pres.ScreenStack.SubscribeToOnInput(OnInput);
	bSubscribed = true;
	return self;
}

simulated function bool OnInput(int iInput, int ActionMask)
{
	local UIScreenStack Stack;
	local UIScreen Menu;

	if (iInput != class'CheatUI_Commands'.default.HOTKEY)
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
	Menu = Stack.GetFirstInstanceOf(class'UICheatUI_Menu');
	if (Menu != none)
	{
		Menu.CloseScreen();
	}
	else
	{
		Stack.Push(Movie.Pres.Spawn(class'UICheatUI_Menu', Movie.Pres), Movie.Pres.Get2DMovie());
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
