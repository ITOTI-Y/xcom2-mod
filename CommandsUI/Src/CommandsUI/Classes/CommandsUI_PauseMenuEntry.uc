//---------------------------------------------------------------------------------------
//  The pause menu entry that opens the command menu, placed above "Exit to main menu".
//
//  The pause menu handles a click by comparing the item's index with its m_opt indices,
//  so the entry shifts every index at or after its own, and wraps the list's click
//  callbacks to catch clicks on itself before the menu sees them. Both work from what
//  the menu holds when the entry is added, so other mods inserting entries the same
//  way, before or after this one, keep working. Enter on the keyboard
//  goes to the menu's own handler, which ignores indices it does not know.
//---------------------------------------------------------------------------------------
class CommandsUI_PauseMenuEntry extends Object;

const ENTRY_TAG = 'CommandsUI_OpenMenu';

var UIPauseMenu PauseMenu;
var delegate<UIList.OnItemSelectedCallback> OriginalOnItemClicked;
var delegate<UIList.OnItemSelectedCallback> OriginalOnItemDoubleClicked;

function Inject(UIPauseMenu Menu)
{
	local UIListItemString Item;
	local int Index, i;

	PauseMenu = Menu;
	Index = Menu.m_optExitGame;
	Item = UIListItemString(Menu.List.CreateItem()).InitListItem(class'UICommandsUI_Menu'.default.strTitle);
	Item.Tag = ENTRY_TAG;
	for (i = Menu.List.ItemCount - 1; i > Index; i--)
	{
		Menu.List.ItemContainer.SwapChildren(i, i - 1);
	}
	Menu.List.RealizeItems();

	ShiftOption(Menu.m_optReturnToGame, Index);
	ShiftOption(Menu.m_optSave, Index);
	ShiftOption(Menu.m_optLoad, Index);
	ShiftOption(Menu.m_optControllerMap, Index);
	ShiftOption(Menu.m_optOptions, Index);
	ShiftOption(Menu.m_optRestart, Index);
	ShiftOption(Menu.m_optChangeDifficulty, Index);
	ShiftOption(Menu.m_optViewSecondWave, Index);
	ShiftOption(Menu.m_optExitGame, Index);
	ShiftOption(Menu.m_optQuitGame, Index);
	ShiftOption(Menu.m_optAcceptInvite, Index);
	Menu.MAX_OPTIONS++;

	OriginalOnItemClicked = Menu.List.OnItemClicked;
	OriginalOnItemDoubleClicked = Menu.List.OnItemDoubleClicked;
	Menu.List.OnItemClicked = OnItemClicked;
	Menu.List.OnItemDoubleClicked = OnItemDoubleClicked;
}

function ShiftOption(out int Option, int Index)
{
	if (Option >= Index)
	{
		Option++;
	}
}

function bool IsEntry(UIList List, int ItemIndex)
{
	local UIPanel Item;

	Item = List.GetItem(ItemIndex);
	return Item != none && Item.Tag == ENTRY_TAG;
}

function OnItemClicked(UIList List, int ItemIndex)
{
	if (IsEntry(List, ItemIndex))
	{
		OpenCommandMenu();
	}
	else if (OriginalOnItemClicked != none)
	{
		OriginalOnItemClicked(List, ItemIndex);
	}
}

function OnItemDoubleClicked(UIList List, int ItemIndex)
{
	if (IsEntry(List, ItemIndex))
	{
		OpenCommandMenu();
	}
	else if (OriginalOnItemDoubleClicked != none)
	{
		OriginalOnItemDoubleClicked(List, ItemIndex);
	}
}

// The pause menu closes first, as Esc would, so the command menu runs over the unpaused
// game just as when it is opened with the hotkey.
function OpenCommandMenu()
{
	local XComPresentationLayerBase Pres;

	Pres = PauseMenu.Movie.Pres;
	Pres.PlayUISound(eSUISound_MenuSelect);
	PauseMenu.CloseScreen();
	if (Pres.ScreenStack.GetFirstInstanceOf(class'UICommandsUI_Menu') == none)
	{
		Pres.ScreenStack.Push(Pres.Spawn(class'UICommandsUI_Menu', Pres), Pres.Get2DMovie());
	}
}

defaultproperties
{
}
