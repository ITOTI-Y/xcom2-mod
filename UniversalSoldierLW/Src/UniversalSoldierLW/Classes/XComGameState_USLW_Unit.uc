//---------------------------------------------------------------------------------------
//  What this mod adds to a soldier, stored as a component of the unit state.
//  Tree keeps the ability tree written at the choice, including the XCOM row drawn
//  then, so a respec that rebuilds the tree from the class template can restore it.
//---------------------------------------------------------------------------------------
class XComGameState_USLW_Unit extends XComGameState_BaseObject dependson(USLW_Specs, USLW_Stats);

var array<USLW_SpecRef> Specs;
var array<SoldierRankAbilities> Tree;
var array<USLW_Family> Families;
var array<name> Origins;			// origin abilities chosen with the specializations
var array<name> PrimaryCats;		// weapon categories the specializations' classes allow
var array<name> SecondaryCats;
var array<USLW_StatPurchase> StatPurchases;

defaultproperties
{
}
