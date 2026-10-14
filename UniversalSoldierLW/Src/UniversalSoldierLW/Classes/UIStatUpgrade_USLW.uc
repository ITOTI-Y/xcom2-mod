// Lists the configured stat upgrades for one soldier and buys them with ability points.
class UIStatUpgrade_USLW extends UIUSLW_ListScreen dependson(USLW_Stats);

var StateObjectReference UnitRef;

var localized string strPoints;			// "Soldier AP: %SOLDIER    XCOM AP: %SHARED"
var localized string strItemTitle;		// "%STAT +%AMOUNT"
var localized string strItemDesc;		// "Now %NOW, after %AFTER. Bought %COUNT of %MAX."
var localized string strItemCost;		// "%COST AP"
var localized string strUpgrade;

simulated function XComGameState_Unit GetUnit()
{
	return XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
}

simulated function GetItems()
{
	local XComGameState_Unit Unit;
	local USLW_StatUpgrade Upgrade;
	local Commodity Item;
	local int Now;

	Unit = GetUnit();
	arrItems.Length = 0;
	foreach class'USLW_Stats'.default.STAT_UPGRADES(Upgrade)
	{
		Now = int(Unit.GetBaseStat(Upgrade.Stat));
		Item.Title = Repl(Repl(strItemTitle, "%STAT", class'X2TacticalGameRulesetDataStructures'.default.m_aCharStatLabels[Upgrade.Stat]), "%AMOUNT", string(Upgrade.Amount));
		Item.Desc = Repl(Repl(Repl(Repl(strItemDesc, "%NOW", string(Now)), "%AFTER", string(Now + Upgrade.Amount)),
			"%COUNT", string(class'USLW_Stats'.static.GetPurchaseCount(Unit, Upgrade.Stat))), "%MAX", string(Upgrade.MaxPurchases));
		arrItems.AddItem(Item);
	}

	SetSubtitle(Repl(Repl(strPoints, "%SOLDIER", string(Unit.AbilityPoints)), "%SHARED", string(class'USLW_Stats'.static.GetSharedPoints())));
}

simulated function string GetNote(int ItemIndex)
{
	local XComGameState_Unit Unit;
	local USLW_StatUpgrade Upgrade;
	local string Reason;

	Unit = GetUnit();
	Upgrade = class'USLW_Stats'.default.STAT_UPGRADES[ItemIndex];
	Reason = class'USLW_Stats'.static.GetBlockReason(Unit, Upgrade);
	if (Reason != "" && Reason != class'USLW_Stats'.default.strNotEnoughPoints)
	{
		return Reason;
	}
	return Repl(strItemCost, "%COST", string(class'USLW_Stats'.static.GetCost(Unit, Upgrade)));
}

simulated function PopulateData()
{
	local int i, Selected;

	Selected = Max(0, List.SelectedIndex);
	List.ClearItems();
	List.bSelectFirstAvailable = false;
	for (i = 0; i < arrItems.Length; i++)
	{
		Spawn(class'UIInventory_USLW_ListItem', List.itemContainer).InitUSLWItem(arrItems[i], GetNote(i), strUpgrade);
	}
	if (List.ItemCount > 0)
	{
		Selected = Min(Selected, List.ItemCount - 1);
		List.SetSelectedIndex(Selected);
		List.Navigator.SetSelected(List.GetItem(Selected));
	}
}

simulated function bool CanAffordItem(int ItemIndex)
{
	return ItemIndex >= 0 && ItemIndex < class'USLW_Stats'.default.STAT_UPGRADES.Length
		&& class'USLW_Stats'.static.GetBlockReason(GetUnit(), class'USLW_Stats'.default.STAT_UPGRADES[ItemIndex]) == "";
}

simulated function OnPurchaseClicked(UIList kList, int ItemIndex)
{
	if (!CanAffordItem(ItemIndex) || !class'USLW_Stats'.static.Buy(UnitRef, class'USLW_Stats'.default.STAT_UPGRADES[ItemIndex]))
	{
		PlayNegativeSound();
		return;
	}
	`XSTRATEGYSOUNDMGR.PlaySoundEvent("StrategyUI_Staff_Assign");
	GetItems();
	PopulateData();
}

simulated function OnCancel()
{
	CloseScreen();
}

simulated function OnCancelButton(UIButton kButton)
{
	OnCancel();
}

defaultproperties
{
}
