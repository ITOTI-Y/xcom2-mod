// The class list row of UIChooseClass, with the training time slot showing Note instead.
// An ability icon is drawn on the colored background the promotion screen uses, since
// the row shows images as they are and ability icons are made to be tinted. The
// commodity stays as the screen built it, because the screen finds a row's index by
// comparing it.
class UIInventory_USLW_ListItem extends UIInventory_ClassListItem;

const ABILITY_ICON_SIZE = 64;

var string Note;
var bool bOwnIcon;

simulated function UIInventory_USLW_ListItem InitUSLWItem(Commodity Item, string InNote, string ButtonText, optional string AbilityIcon)
{
	local UIIcon Icon;

	Note = InNote;
	bOwnIcon = AbilityIcon != "";
	InitInventoryListCommodity(Item, , ButtonText, eUIConfirmButtonStyle_Default, , 126);
	if (AbilityIcon != "")
	{
		Icon = Spawn(class'UIIcon', self);
		Icon.InitIcon('', AbilityIcon, false, true, ABILITY_ICON_SIZE, eUIState_Normal);
		Icon.SetForegroundColor(class'UIUtilities_Colors'.const.BLACK_HTML_COLOR);
		Icon.SetPosition(22, 26);
	}
	return self;
}

// The red "cannot afford" state is not used; rows that cannot be chosen are disabled.
simulated function RealizeBadState()
{
	SetBad(false);
}

simulated function PopulateData(optional bool bRealizeDisabled)
{
	MC.BeginFunctionOp("populateData");
	MC.QueueString(bOwnIcon ? "" : ItemComodity.Image);
	MC.QueueString(ItemComodity.Title);
	MC.QueueString(Note);
	MC.QueueString(ItemComodity.Desc);
	MC.EndOp();

	if (bRealizeDisabled)
	{
		RealizeDisabledState();
	}
}
