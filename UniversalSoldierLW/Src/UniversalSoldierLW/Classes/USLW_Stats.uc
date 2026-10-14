//---------------------------------------------------------------------------------------
//  Stat upgrades bought with ability points, open to every soldier.
//
//  Points are spent the way BuySoldierProgressionAbility spends them: the soldier's own
//  first, then the shared XCOM pool. The soldier's share is added to SpentAbilityPoints,
//  so retraining refunds it as it refunds abilities, and the shared share is not
//  refunded, again as for abilities. Retraining also removes the upgrades.
//---------------------------------------------------------------------------------------
class USLW_Stats extends Object config(UniversalSoldierLW);

struct USLW_StatUpgrade
{
	var ECharStatType Stat;
	var int Amount;			// added to the stat per purchase
	var int Cost;			// ability points for the first purchase
	var int CostIncrease;	// added to the cost by each earlier purchase
	var int MaxPurchases;
};

struct USLW_StatPurchase
{
	var ECharStatType Stat;
	var int Count;
	var int Amount;			// total added, so later config changes revert exactly
};

var config array<USLW_StatUpgrade> STAT_UPGRADES;
var config bool REQUIRE_TRAINING_CENTER;

var localized string strNeedTrainingCenter;
var localized string strMaxReached;
var localized string strNotEnoughPoints;

static function int GetPurchaseIndex(XComGameState_USLW_Unit Comp, ECharStatType Stat)
{
	return Comp != none ? Comp.StatPurchases.Find('Stat', Stat) : INDEX_NONE;
}

static function int GetPurchaseCount(XComGameState_Unit Unit, ECharStatType Stat)
{
	local XComGameState_USLW_Unit Comp;
	local int Index;

	Comp = class'USLW_Specs'.static.GetComponent(Unit);
	Index = GetPurchaseIndex(Comp, Stat);
	return Index != INDEX_NONE ? Comp.StatPurchases[Index].Count : 0;
}

static function int GetCost(XComGameState_Unit Unit, USLW_StatUpgrade Upgrade)
{
	return Upgrade.Cost + Upgrade.CostIncrease * GetPurchaseCount(Unit, Upgrade.Stat);
}

static function int GetSharedPoints()
{
	return `XCOMHQ.GetAbilityPoints();
}

// The reason the upgrade cannot be bought now, or "" when it can.
static function string GetBlockReason(XComGameState_Unit Unit, USLW_StatUpgrade Upgrade)
{
	if (default.REQUIRE_TRAINING_CENTER && !`XCOMHQ.HasFacilityByName('RecoveryCenter'))
	{
		return default.strNeedTrainingCenter;
	}
	if (GetPurchaseCount(Unit, Upgrade.Stat) >= Upgrade.MaxPurchases)
	{
		return default.strMaxReached;
	}
	if (Unit.AbilityPoints + GetSharedPoints() < GetCost(Unit, Upgrade))
	{
		return default.strNotEnoughPoints;
	}
	return "";
}

static function bool Buy(StateObjectReference UnitRef, USLW_StatUpgrade Upgrade)
{
	local XComGameState NewGameState;
	local XComGameState_Unit Unit;
	local XComGameState_USLW_Unit Comp;
	local XComGameState_HeadquartersXCom XComHQ;
	local USLW_StatPurchase Purchase;
	local int Cost, Index;

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
	if (Unit == none || GetBlockReason(Unit, Upgrade) != "")
	{
		return false;
	}
	Cost = GetCost(Unit, Upgrade);

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("USLW stat upgrade");
	Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
	if (Unit.AbilityPoints >= Cost)
	{
		Unit.AbilityPoints -= Cost;
		Unit.SpentAbilityPoints += Cost;
	}
	else
	{
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', `XCOMHQ.ObjectID));
		XComHQ.AddResource(NewGameState, 'AbilityPoint', -(Cost - Unit.AbilityPoints));
		Unit.SpentAbilityPoints += Unit.AbilityPoints;
		Unit.AbilityPoints = 0;
	}

	Unit.SetBaseMaxStat(Upgrade.Stat, Unit.GetBaseStat(Upgrade.Stat) + Upgrade.Amount);
	Unit.SetCurrentStat(Upgrade.Stat, Unit.GetCurrentStat(Upgrade.Stat) + Upgrade.Amount);

	Comp = class'USLW_Specs'.static.GetOrCreateComponent(Unit, NewGameState);
	Index = GetPurchaseIndex(Comp, Upgrade.Stat);
	if (Index == INDEX_NONE)
	{
		Purchase.Stat = Upgrade.Stat;
		Comp.StatPurchases.AddItem(Purchase);
		Index = Comp.StatPurchases.Length - 1;
	}
	Comp.StatPurchases[Index].Count++;
	Comp.StatPurchases[Index].Amount += Upgrade.Amount;

	`XEVENTMGR.TriggerEvent('AbilityPointsChange', Unit, , NewGameState);
	`GAMERULES.SubmitGameState(NewGameState);
	return true;
}

// Unit and Comp must already be part of the game state being built.
static function RevertUpgrades(XComGameState_Unit Unit, XComGameState_USLW_Unit Comp)
{
	local USLW_StatPurchase Purchase;

	foreach Comp.StatPurchases(Purchase)
	{
		Unit.SetBaseMaxStat(Purchase.Stat, Unit.GetBaseStat(Purchase.Stat) - Purchase.Amount);
		Unit.SetCurrentStat(Purchase.Stat, FMax(Unit.GetCurrentStat(Purchase.Stat) - Purchase.Amount, 1));
	}
	Comp.StatPurchases.Length = 0;
}

defaultproperties
{
}
