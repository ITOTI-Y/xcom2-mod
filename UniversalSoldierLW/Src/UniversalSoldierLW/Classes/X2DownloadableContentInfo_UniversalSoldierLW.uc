class X2DownloadableContentInfo_UniversalSoldierLW extends X2DownloadableContentInfo;

var localized string strWeaponNotInSpecs;

// Runs last (see XComGame.ini), so every class has its final deck counts and ranks.
static event OnPostTemplatesCreated()
{
	class'USLW_Specs'.static.SetupClassTemplate();
}

// A mission grants a column ability only with a weapon its classes allow in its slot.
static function FinalizeUnitAbilitiesForInit(XComGameState_Unit UnitState, out array<AbilitySetupData> SetupData, optional XComGameState StartState, optional XComGameState_Player PlayerState, optional bool bMultiplayerDisplay)
{
	class'USLW_Specs'.static.RemoveUnarmedAbilities(UnitState, SetupData, StartState);
}

// The class template allows every weapon of the source classes; this narrows a
// universal soldier's primary and secondary slots to what its specializations' classes
// allow. Return values follow the hook's contract in X2DownloadableContentInfo.
static function bool CanAddItemToInventory_CH_Improved(out int bCanAddItem, const EInventorySlot Slot, const X2ItemTemplate ItemTemplate, int Quantity, XComGameState_Unit UnitState, optional XComGameState CheckGameState, optional out string DisabledReason, optional XComGameState_Item ItemState)
{
	local X2WeaponTemplate WeaponTemplate;
	local XComGameState_USLW_Unit Comp;
	local array<name> Cats;

	WeaponTemplate = X2WeaponTemplate(ItemTemplate);
	if (WeaponTemplate == none || (Slot != eInvSlot_PrimaryWeapon && Slot != eInvSlot_SecondaryWeapon)
		|| !class'USLW_Specs'.static.IsUniversal(UnitState))
	{
		return CheckGameState == none;
	}
	Comp = class'USLW_Specs'.static.GetComponent(UnitState);
	if (Comp == none || Comp.Specs.Length == 0)
	{
		return CheckGameState == none;
	}
	if (Slot == eInvSlot_PrimaryWeapon)
	{
		Cats = Comp.PrimaryCats;
	}
	else
	{
		Cats = Comp.SecondaryCats;
	}
	if (Cats.Find(WeaponTemplate.WeaponCat) != INDEX_NONE)
	{
		return CheckGameState == none;
	}
	DisabledReason = class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(default.strWeaponNotInSpecs);
	bCanAddItem = 0;
	return CheckGameState != none;
}
