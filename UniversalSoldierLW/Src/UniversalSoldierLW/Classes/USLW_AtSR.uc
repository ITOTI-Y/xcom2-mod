//---------------------------------------------------------------------------------------
//  Reads Ability To Slot Reassignment's config class. Only this class names it, and no
//  other class depends on this one, so the compile-time stand-in in BuildStubs/ stays
//  out of every other class's dependencies.
//---------------------------------------------------------------------------------------
class USLW_AtSR extends Object dependson(X2USLWDataTemplate, AbilityToSlotReassignmentLib);

// Reads the abilities Ability To Slot Reassignment ties to weapon category sets, after
// the mods that adjust that list have run. Runs when the templates are created.
static function array<USLW_WeaponNeed> DiscoverAtSRNeeds()
{
	local array<USLW_WeaponNeed> Needs;
	local USLW_WeaponNeed Need;
	local AbilityWeaponCategory Entry;
	local array<WeaponCategorySet> Sets;
	local array<name> Cats;
	local name Cat;
	local int SetIndex, Index;

	Sets = class'AbilityToSlotReassignmentLib'.default.WeaponCategorySets;
	foreach class'AbilityToSlotReassignmentLib'.default.AbilityWeaponCategories(Entry)
	{
		SetIndex = Sets.Find('WeaponCategorySetName', Entry.WeaponCategorySetName);
		if (SetIndex == INDEX_NONE)
		{
			continue;
		}
		Index = Needs.Find('Ability', Entry.AbilityName);
		if (Index == INDEX_NONE)
		{
			Need.Ability = Entry.AbilityName;
			Need.Slot = eInvSlot_Unknown;
			Need.Cats.Length = 0;
			Needs.AddItem(Need);
			Index = Needs.Length - 1;
		}
		Cats = Sets[SetIndex].WeaponCategories;
		foreach Cats(Cat)
		{
			if (Needs[Index].Cats.Find(Cat) == INDEX_NONE)
			{
				Needs[Index].Cats.AddItem(Cat);
			}
		}
	}
	return Needs;
}

