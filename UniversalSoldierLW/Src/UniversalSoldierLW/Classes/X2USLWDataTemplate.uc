// Holds what this mod finds when the templates are created. Class defaults changed at
// runtime are reset when a map loads, while templates live for the whole session.
class X2USLWDataTemplate extends X2StrategyElementTemplate;

// An ability and the weapon categories it needs: as Ability To Slot Reassignment lists
// them, or, for a column ability on the secondary slot, as its classes allow there.
struct USLW_WeaponNeed
{
	var name Ability;
	var EInventorySlot Slot;
	var array<name> Cats;
};

var array<name> SourceClassNames;
var array<USLW_WeaponNeed> WeaponNeeds;	// from the class columns, secondary slot only
var array<USLW_WeaponNeed> AtSRNeeds;	// from Ability To Slot Reassignment
