//---------------------------------------------------------------------------------------
//  Compile-time stand-in for the config class of Ability To Slot Reassignment
//  (Workshop 2133397762), whose own sources do not build with the current SDK.
//  build.py compiles it into the SDK only, and the mod ships without it: at runtime
//  the game loads the real class from that mod, which the mod therefore requires.
//  The declarations must match the real class.
//---------------------------------------------------------------------------------------
class AbilityToSlotReassignmentLib extends Object config (AbilityToSlotReassignment);

struct WeaponCategorySet
{
	var name WeaponCategorySetName;
	var array<name> WeaponCategories;
};

struct AbilityWeaponCategory
{
	var name AbilityName;
	var name WeaponCategorySetName;
};

struct AbilityOverride
{
	var name OverrideAbility;
	var array<name> OverriddenAbilities;
};

var config array<WeaponCategorySet> WeaponCategorySets;
var config array<AbilityWeaponCategory> AbilityWeaponCategories;
var config array<AbilityWeaponCategory> MandatoryAbilities;
