//---------------------------------------------------------------------------------------
//  Base of this mod's list screens, shown at the armory's promotion display.
//
//  UIInventory leaves the list's position and height to the Flash layout of the screen
//  it was made for; at the promotion display that leaves an empty list, so they are set
//  here, as WOTC_ChooseMyClass does for its class list at the same display. The
//  promotion screen, which stays drawn under a screen pushed over it, is hidden while
//  this screen is up.
//---------------------------------------------------------------------------------------
class UIUSLW_ListScreen extends UISimpleCommodityScreen;

const LIST_HEIGHT = 780;

var UIScreen HiddenScreen;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	HiddenScreen = `SCREENSTACK.GetFirstInstanceOf(class'UIArmory_Promotion');
	if (HiddenScreen != none)
	{
		HiddenScreen.Hide();
	}
	super.InitScreen(InitController, InitMovie, InitName);
	ItemCard.Hide();
	Navigator.SetSelected(List);
	List.SetSelectedIndex(0);
}

simulated function BuildScreen()
{
	TitleHeader = Spawn(class'UIX2PanelHeader', self);
	TitleHeader.InitPanelHeader('TitleHeader', m_strTitle, "");
	TitleHeader.SetHeaderWidth(580);
	TitleHeader.SetPosition(48, 130);

	ListContainer = Spawn(class'UIPanel', self).InitPanel('InventoryContainer').SetPosition(40, 120);
	ItemCard = Spawn(class'UIItemCard', ListContainer).InitItemCard('ItemCard');

	ListBG = Spawn(class'UIPanel', ListContainer);
	ListBG.InitPanel('InventoryListBG');
	ListBG.bShouldPlayGenericUIAudioEvents = false;
	ListBG.SetHeight(LIST_HEIGHT);
	ListBG.Show();

	List = Spawn(class'UIList', ListContainer);
	List.InitList(InventoryListName);
	List.bSelectFirstAvailable = false;
	List.ItemPadding = 4;
	List.SetHeight(LIST_HEIGHT);
	List.bStickyHighlight = true;
	List.OnSelectionChanged = SelectedItemChanged;
	Navigator.SetSelected(ListContainer);
	ListContainer.Navigator.SetSelected(List);

	SetCategory("");
	SetBuiltLabel("");
	ListBG.ProcessMouseEvents(List.OnChildMouseEvent);

	if (bIsIn3D)
	{
		class'UIUtilities'.static.DisplayUI3D(DisplayTag, CameraTag, OverrideInterpTime != -1 ? OverrideInterpTime : `HQINTERPTIME);
	}
}

// Sets the header's subtitle, which the subclasses use for their state.
simulated function SetSubtitle(string Subtitle)
{
	SetHeader(m_strTitle, Subtitle);
}

simulated function SetHeader(string Title, string Subtitle)
{
	if (TitleHeader != none)
	{
		TitleHeader.SetText(Title, Subtitle);
	}
}

simulated function PopulateResearchCard(optional Commodity ItemCommodity, optional StateObjectReference ItemRef)
{
}

simulated function OnRemoved()
{
	if (HiddenScreen != none)
	{
		HiddenScreen.Show();
	}
	super.OnRemoved();
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	UpdateNavHelp();
}

defaultproperties
{
	InputState = eInputState_Consume;
	bHideOnLoseFocus = true;
	bConsumeMouseEvents = true;
	DisplayTag = "UIBlueprint_Promotion";
	CameraTag = "UIBlueprint_Promotion";
	ConfirmButtonX = 5;
	ConfirmButtonY = 123;
}
