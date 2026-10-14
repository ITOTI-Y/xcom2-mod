//---------------------------------------------------------------------------------------
//  Specializations of the universal soldier class.
//
//  Nothing here names a soldier class. The pool is discovered from the templates once
//  they are created: every class that can be drawn for a new soldier (NumInDeck or
//  NumInForcedDeck above zero) contributes each of its ability columns as one
//  specialization, so class packs join the pool as soon as they are installed. The
//  names found then are kept in the USLW_Data template for the session, since the
//  templates a campaign iterates later do not report the same deck counts. A column is
//  the slot at the same index in every rank, counting only the slots that are neither
//  random (the XCOM row) nor bound to the pistol slot (the LWOTC pistol row).
//
//  The universal soldier's template holds SPECIALIZATION_COUNT empty slots per rank, so
//  the promotion screen counts exactly that many class columns. Choosing specializations
//  fills those slots. The first one chosen is the primary specialization: its class adds
//  its shared squaddie abilities and its XCOM and pistol rows.
//---------------------------------------------------------------------------------------
class USLW_Specs extends Object config(UniversalSoldierLW) dependson(X2USLWDataTemplate);

const CLASS_NAME = 'UniversalSoldier_LW';

struct USLW_Spec
{
	var name ClassName;
	var int Column;
	var array<SoldierClassAbilityType> RankAbilities;	// one per rank; rank 0 is empty when the class shares its squaddie abilities
	var array<SoldierClassAbilityType> CoreAbilities;	// squaddie abilities shared by all columns of the class
	var array<name> PrimaryCats;						// categories of the slots the column's abilities use, shown as a hint
	var array<name> SecondaryCats;
};

struct USLW_SpecRef
{
	var name ClassName;
	var int Column;
};

// Abilities that should not be learned together, ordered by priority.
struct USLW_Family
{
	var array<name> Members;
};

struct USLW_AbilityGroup
{
	var array<name> Abilities;
};

// An ability placed in a tree, and which part of the tree put it there.
struct USLW_Placed
{
	var name Ability;
	var int Source;		// specialization index; the specialization count for the XCOM and pistol rows, one more for origins
	var int Rank;
	var int Branch;
};

var config int SPECIALIZATION_COUNT;
var config array<name> EXCLUDED_CLASSES;
var config array<USLW_AbilityGroup> ABILITY_GROUPS;
var config int ORIGIN_ABILITY_COUNT;
var config array<name> ORIGIN_EXTRA_ABILITIES;
var config array<name> ORIGIN_EXCLUDED_ABILITIES;

var localized string strSpecTitle;		// "%CLASS: %TREE"
var localized string strColumnTitle;	// "Column %N", for columns without a localized title
var localized string strLockedBy;		// "Conflicts with %ABILITY, already learned"

//---------------------------------------------------------------------------------------
//  Class discovery

static function int GetSpecCount()
{
	return Max(1, default.SPECIALIZATION_COUNT);
}

static function X2SoldierClassTemplate FindClass(name ClassName)
{
	return class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager().FindSoldierClassTemplate(ClassName);
}

static function X2USLWDataTemplate GetData()
{
	return X2USLWDataTemplate(class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().FindStrategyElementTemplate('USLW_Data'));
}

static function array<name> GetSourceClassNames()
{
	local X2USLWDataTemplate Data;
	local array<name> Names;

	Data = GetData();
	if (Data != none)
	{
		Names = Data.SourceClassNames;
	}
	return Names;
}

static function bool IsSourceClass(X2SoldierClassTemplate ClassTemplate)
{
	local array<name> Names;

	Names = GetSourceClassNames();
	return ClassTemplate != none && Names.Find(ClassTemplate.DataName) != INDEX_NONE;
}

// Runs when the templates are created, while the classes report their deck counts.
static function array<name> DiscoverSourceClasses()
{
	local X2DataTemplate DataTemplate;
	local X2SoldierClassTemplate ClassTemplate;
	local X2SoldierClassTemplateManager Manager;
	local array<name> Names;

	Manager = class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager();
	foreach Manager.IterateTemplates(DataTemplate, none)
	{
		ClassTemplate = X2SoldierClassTemplate(DataTemplate);
		if (ClassTemplate != none
			&& ClassTemplate.DataName != CLASS_NAME
			&& !ClassTemplate.bMultiplayerOnly
			&& (ClassTemplate.NumInDeck > 0 || ClassTemplate.NumInForcedDeck > 0)
			&& default.EXCLUDED_CLASSES.Find(ClassTemplate.DataName) == INDEX_NONE
			&& Names.Find(ClassTemplate.DataName) == INDEX_NONE)
		{
			Names.AddItem(ClassTemplate.DataName);
		}
	}
	return Names;
}

static function array<X2SoldierClassTemplate> GetSourceClasses()
{
	local X2SoldierClassTemplate ClassTemplate;
	local array<X2SoldierClassTemplate> Classes;
	local array<name> Names;
	local name ClassName;

	Names = GetSourceClassNames();
	foreach Names(ClassName)
	{
		ClassTemplate = FindClass(ClassName);
		if (ClassTemplate != none)
		{
			Classes.AddItem(ClassTemplate);
		}
	}
	return Classes;
}

static function bool IsColumnSlot(SoldierClassAbilitySlot Slot)
{
	return Slot.RandomDeckName == '' && Slot.AbilityType.ApplyToWeaponSlot != eInvSlot_Pistol;
}

static function array<SoldierClassAbilitySlot> GetColumnSlots(X2SoldierClassTemplate ClassTemplate, int Rank)
{
	local SoldierClassAbilitySlot Slot;
	local array<SoldierClassAbilitySlot> Slots, AllSlots;

	AllSlots = ClassTemplate.GetAbilitySlots(Rank);
	foreach AllSlots(Slot)
	{
		if (IsColumnSlot(Slot))
		{
			Slots.AddItem(Slot);
		}
	}
	return Slots;
}

static function int GetColumnCount(X2SoldierClassTemplate ClassTemplate)
{
	local array<SoldierClassAbilitySlot> Slots;

	if (ClassTemplate.GetMaxConfiguredRank() < 2)
	{
		return 0;
	}
	// UnrealScript reads .Length of a returned array as 0, so the result goes through a local.
	Slots = GetColumnSlots(ClassTemplate, 1);
	return Slots.Length;
}

static function array<name> GetClassCats(X2SoldierClassTemplate ClassTemplate, EInventorySlot InvSlot)
{
	local SoldierClassWeaponType Allowed;
	local array<name> Cats;

	foreach ClassTemplate.AllowedWeapons(Allowed)
	{
		if (Allowed.SlotType == InvSlot && Cats.Find(Allowed.WeaponType) == INDEX_NONE)
		{
			Cats.AddItem(Allowed.WeaponType);
		}
	}
	return Cats;
}

//---------------------------------------------------------------------------------------
//  Specializations

// Returns false when the column holds no ability past squaddie.
static function bool BuildSpec(X2SoldierClassTemplate ClassTemplate, int Column, out USLW_Spec Spec)
{
	local array<SoldierClassAbilitySlot> Slots;
	local SoldierClassAbilityType EmptyAbility, Ability;
	local int Rank, Columns, i;
	local bool bHasAbility, bPrimary, bSecondary;

	Spec.ClassName = ClassTemplate.DataName;
	Spec.Column = Column;
	Spec.RankAbilities.Length = 0;
	Spec.CoreAbilities.Length = 0;
	Spec.PrimaryCats.Length = 0;
	Spec.SecondaryCats.Length = 0;
	Columns = GetColumnCount(ClassTemplate);

	for (Rank = 0; Rank < ClassTemplate.GetMaxConfiguredRank(); Rank++)
	{
		Slots = GetColumnSlots(ClassTemplate, Rank);
		if (Rank == 0 && Slots.Length != Columns)
		{
			for (i = 0; i < Slots.Length; i++)
			{
				if (Slots[i].AbilityType.AbilityName != '')
				{
					Spec.CoreAbilities.AddItem(Slots[i].AbilityType);
				}
			}
			Spec.RankAbilities.AddItem(EmptyAbility);
		}
		else if (Column < Slots.Length)
		{
			Spec.RankAbilities.AddItem(Slots[Column].AbilityType);
			bHasAbility = bHasAbility || (Rank > 0 && Slots[Column].AbilityType.AbilityName != '');
		}
		else
		{
			Spec.RankAbilities.AddItem(EmptyAbility);
		}
	}

	foreach Spec.RankAbilities(Ability)
	{
		bPrimary = bPrimary || (Ability.AbilityName != '' && Ability.ApplyToWeaponSlot == eInvSlot_PrimaryWeapon);
		bSecondary = bSecondary || (Ability.AbilityName != '' && Ability.ApplyToWeaponSlot == eInvSlot_SecondaryWeapon);
	}
	foreach Spec.CoreAbilities(Ability)
	{
		bPrimary = bPrimary || Ability.ApplyToWeaponSlot == eInvSlot_PrimaryWeapon;
		bSecondary = bSecondary || Ability.ApplyToWeaponSlot == eInvSlot_SecondaryWeapon;
	}
	if (bPrimary)
	{
		Spec.PrimaryCats = GetClassCats(ClassTemplate, eInvSlot_PrimaryWeapon);
	}
	if (bSecondary)
	{
		Spec.SecondaryCats = GetClassCats(ClassTemplate, eInvSlot_SecondaryWeapon);
	}
	return bHasAbility;
}

static function array<USLW_Spec> GetAllSpecs()
{
	local X2SoldierClassTemplate ClassTemplate;
	local array<X2SoldierClassTemplate> Classes;
	local USLW_Spec Spec;
	local array<USLW_Spec> Specs;
	local int Column;

	Classes = GetSourceClasses();
	foreach Classes(ClassTemplate)
	{
		for (Column = 0; Column < GetColumnCount(ClassTemplate); Column++)
		{
			if (BuildSpec(ClassTemplate, Column, Spec))
			{
				Specs.AddItem(Spec);
			}
		}
	}
	return Specs;
}

static function bool ResolveSpec(USLW_SpecRef Ref, out USLW_Spec Spec)
{
	local X2SoldierClassTemplate ClassTemplate;

	ClassTemplate = FindClass(Ref.ClassName);
	return ClassTemplate != none && Ref.Column < GetColumnCount(ClassTemplate) && BuildSpec(ClassTemplate, Ref.Column, Spec);
}

static function string GetSpecTitle(name ClassName, int Column)
{
	local X2SoldierClassTemplate ClassTemplate;
	local string TreeTitle;

	ClassTemplate = FindClass(ClassName);
	if (ClassTemplate == none)
	{
		return string(ClassName);
	}
	if (Column < ClassTemplate.AbilityTreeTitles.Length)
	{
		TreeTitle = ClassTemplate.AbilityTreeTitles[Column];
	}
	if (TreeTitle == "")
	{
		TreeTitle = Repl(default.strColumnTitle, "%N", string(Column + 1));
	}
	return Repl(Repl(default.strSpecTitle, "%CLASS", ClassTemplate.DisplayName), "%TREE", TreeTitle);
}

//---------------------------------------------------------------------------------------
//  Choices
//
//  Any specializations combine, each at most once. In each weapon slot the soldier may equip what any of
//  their classes allows there. Ability To Slot Reassignment, when installed, already
//  moves each ability it lists onto a fitting weapon in a mission, or drops it. For the
//  rest, a column ability on the secondary slot is only granted while the soldier
//  carries a weapon category its classes allow there (RemoveUnarmedAbilities); those
//  are mostly tied to one item, a Gremlin or a sword. Primary slot abilities are mostly
//  generic and always granted, as are origin, XCOM row and pistol row abilities.

// Names a weapon category the way its weapons are named in ability descriptions, or by
// the friendly name of its lowest tier weapon, falling back to the internal name.
static function string NameCategory(name Cat)
{
	local X2ItemTemplateManager Manager;
	local X2DataTemplate DataTemplate;
	local X2WeaponTemplate WeaponTemplate, Lowest;

	Manager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	foreach Manager.IterateTemplates(DataTemplate, none)
	{
		WeaponTemplate = X2WeaponTemplate(DataTemplate);
		if (WeaponTemplate == none || WeaponTemplate.WeaponCat != Cat)
		{
			continue;
		}
		if (WeaponTemplate.AbilityDescName != "")
		{
			return WeaponTemplate.AbilityDescName;
		}
		if (WeaponTemplate.FriendlyName != "" && (Lowest == none || WeaponTemplate.Tier < Lowest.Tier))
		{
			Lowest = WeaponTemplate;
		}
	}
	return Lowest != none ? Lowest.FriendlyName : string(Cat);
}

//---------------------------------------------------------------------------------------
//  Origin abilities
//
//  Besides its specializations, a soldier chooses ORIGIN_ABILITY_COUNT passive abilities
//  that it starts with. The pool is every passive ability in the random decks of the
//  source classes, the XCOM row abilities their authors made to suit any class, plus
//  ORIGIN_EXTRA_ABILITIES and minus ORIGIN_EXCLUDED_ABILITIES. Abilities that need a
//  weapon none of the chosen specializations' classes allow are left out (CanUseOrigin).

static function array<SoldierClassAbilityType> GetOriginPool()
{
	local array<X2SoldierClassTemplate> Sources;
	local X2SoldierClassTemplate Source;
	local SoldierClassRandomAbilityDeck Deck;
	local SoldierClassAbilityType Ability, EmptyAbility;
	local array<SoldierClassAbilityType> Pool;
	local name AbilityName;

	Sources = GetSourceClasses();
	foreach Sources(Source)
	{
		foreach Source.RandomAbilityDecks(Deck)
		{
			foreach Deck.Abilities(Ability)
			{
				AddOrigin(Pool, Ability);
			}
		}
	}
	foreach default.ORIGIN_EXTRA_ABILITIES(AbilityName)
	{
		Ability = EmptyAbility;
		Ability.AbilityName = AbilityName;
		AddOrigin(Pool, Ability);
	}
	return Pool;
}

static function AddOrigin(out array<SoldierClassAbilityType> Pool, SoldierClassAbilityType Ability)
{
	local X2AbilityTemplate AbilityTemplate;

	if (Ability.AbilityName == '' || Pool.Find('AbilityName', Ability.AbilityName) != INDEX_NONE
		|| default.ORIGIN_EXCLUDED_ABILITIES.Find(Ability.AbilityName) != INDEX_NONE)
	{
		return;
	}
	AbilityTemplate = FindAbility(Ability.AbilityName);
	if (AbilityTemplate != none && AbilityTemplate.bIsPassive && AbilityTemplate.LocFriendlyName != "")
	{
		Pool.AddItem(Ability);
	}
}

// Records, for every column ability attached to the secondary slot, the categories its
// classes allow there. Runs when the templates are created.
static function array<USLW_WeaponNeed> DiscoverWeaponNeeds(array<X2SoldierClassTemplate> Sources)
{
	local array<USLW_WeaponNeed> Needs;
	local USLW_WeaponNeed Need;
	local X2SoldierClassTemplate Source;
	local array<SoldierClassAbilitySlot> Slots;
	local SoldierClassAbilitySlot Slot;
	local array<name> Cats;
	local name Cat;
	local int Rank, Index;

	foreach Sources(Source)
	{
		for (Rank = 0; Rank < Source.GetMaxConfiguredRank(); Rank++)
		{
			Slots = GetColumnSlots(Source, Rank);
			foreach Slots(Slot)
			{
				if (Slot.AbilityType.AbilityName == '' || Slot.AbilityType.ApplyToWeaponSlot != eInvSlot_SecondaryWeapon)
				{
					continue;
				}
				for (Index = 0; Index < Needs.Length; Index++)
				{
					if (Needs[Index].Ability == Slot.AbilityType.AbilityName && Needs[Index].Slot == Slot.AbilityType.ApplyToWeaponSlot)
					{
						break;
					}
				}
				if (Index == Needs.Length)
				{
					Need.Ability = Slot.AbilityType.AbilityName;
					Need.Slot = Slot.AbilityType.ApplyToWeaponSlot;
					Need.Cats.Length = 0;
					Needs.AddItem(Need);
				}
				Cats = GetClassCats(Source, Slot.AbilityType.ApplyToWeaponSlot);
				foreach Cats(Cat)
				{
					if (Needs[Index].Cats.Find(Cat) == INDEX_NONE)
					{
						Needs[Index].Cats.AddItem(Cat);
					}
				}
			}
		}
	}
	return Needs;
}

// Drops the column abilities of a universal soldier that carries no weapon they need,
// along with the abilities they add on that weapon.
static function RemoveUnarmedAbilities(XComGameState_Unit Unit, out array<AbilitySetupData> SetupData, XComGameState StartState)
{
	local X2USLWDataTemplate Data;
	local array<AbilitySetupData> Removed;
	local AbilitySetupData Entry;
	local name Extra;
	local int i;

	Data = GetData();
	if (!IsUniversal(Unit) || Data == none)
	{
		return;
	}
	for (i = SetupData.Length - 1; i >= 0; i--)
	{
		if (IsColumnAbility(Unit, SetupData[i].TemplateName) && !IsArmedFor(Data, SetupData[i], StartState))
		{
			Removed.AddItem(SetupData[i]);
			SetupData.Remove(i, 1);
		}
	}
	foreach Removed(Entry)
	{
		foreach Entry.Template.AdditionalAbilities(Extra)
		{
			for (i = SetupData.Length - 1; i >= 0; i--)
			{
				if (SetupData[i].TemplateName == Extra && SetupData[i].SourceWeaponRef.ObjectID == Entry.SourceWeaponRef.ObjectID)
				{
					SetupData.Remove(i, 1);
				}
			}
		}
	}
}

// Whether the ability sits in one of the unit's specialization columns, or among its
// squaddie abilities other than the origin ones.
static function bool IsColumnAbility(XComGameState_Unit Unit, name AbilityName)
{
	local int Rank, Branch, Columns;

	Columns = GetSpecCount();
	for (Rank = 0; Rank < Unit.AbilityTree.Length; Rank++)
	{
		for (Branch = 0; Branch < Unit.AbilityTree[Rank].Abilities.Length; Branch++)
		{
			if (Unit.AbilityTree[Rank].Abilities[Branch].AbilityName == AbilityName)
			{
				return Rank == 0 || Branch < Columns;
			}
		}
	}
	return false;
}

static function bool IsArmedFor(X2USLWDataTemplate Data, AbilitySetupData Entry, XComGameState StartState)
{
	local XComGameState_Item Item;
	local USLW_WeaponNeed Need;
	local bool bNeedsWeapon;

	if (Entry.SourceWeaponRef.ObjectID != 0)
	{
		if (StartState != none)
		{
			Item = XComGameState_Item(StartState.GetGameStateForObjectID(Entry.SourceWeaponRef.ObjectID));
		}
		if (Item == none)
		{
			Item = XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(Entry.SourceWeaponRef.ObjectID));
		}
	}
	// Any slot counts, as Ability To Slot Reassignment may have moved the ability onto
	// a fitting weapon elsewhere.
	foreach Data.WeaponNeeds(Need)
	{
		if (Need.Ability != Entry.TemplateName)
		{
			continue;
		}
		bNeedsWeapon = true;
		if (Item != none && Need.Cats.Find(Item.GetWeaponCategory()) != INDEX_NONE)
		{
			return true;
		}
	}
	return !bNeedsWeapon;
}

// Whether the specializations' classes allow a weapon the ability needs, as Ability To
// Slot Reassignment lists it, or as the column classes allow on the secondary slot.
// An ability neither lists needs no particular weapon.
static function bool CanUseOrigin(array<USLW_Spec> Specs, name AbilityName)
{
	local X2USLWDataTemplate Data;
	local array<name> Allowed;
	local USLW_WeaponNeed Need;
	local USLW_Spec Spec;
	local array<SoldierClassWeaponType> Weapons;
	local SoldierClassWeaponType Weapon;
	local name Cat;
	local bool bNeedsWeapon;

	Data = GetData();
	if (Data == none)
	{
		return true;
	}
	foreach Specs(Spec)
	{
		Weapons = FindClass(Spec.ClassName).AllowedWeapons;
		foreach Weapons(Weapon)
		{
			if (Allowed.Find(Weapon.WeaponType) == INDEX_NONE)
			{
				Allowed.AddItem(Weapon.WeaponType);
			}
		}
	}
	foreach Data.AtSRNeeds(Need)
	{
		if (Need.Ability != AbilityName)
		{
			continue;
		}
		foreach Need.Cats(Cat)
		{
			if (Allowed.Find(Cat) != INDEX_NONE)
			{
				return true;
			}
		}
		return false;
	}
	foreach Data.WeaponNeeds(Need)
	{
		if (Need.Ability != AbilityName)
		{
			continue;
		}
		bNeedsWeapon = true;
		foreach Need.Cats(Cat)
		{
			if (Allowed.Find(Cat) != INDEX_NONE)
			{
				return true;
			}
		}
	}
	return !bNeedsWeapon;
}

static function bool SpecsHaveAbility(array<USLW_Spec> Specs, name AbilityName)
{
	local USLW_Spec Spec;

	foreach Specs(Spec)
	{
		if (Spec.RankAbilities.Find('AbilityName', AbilityName) != INDEX_NONE)
		{
			return true;
		}
	}
	return Specs.Length > 0 && Specs[0].CoreAbilities.Find('AbilityName', AbilityName) != INDEX_NONE;
}

// The categories the specializations' classes allow in the slot, together.
static function array<name> GetAllowedCats(array<USLW_Spec> Specs, EInventorySlot InvSlot)
{
	local USLW_Spec Spec;
	local array<name> Cats, ClassCats;
	local name Cat;

	foreach Specs(Spec)
	{
		ClassCats = GetClassCats(FindClass(Spec.ClassName), InvSlot);
		foreach ClassCats(Cat)
		{
			if (Cats.Find(Cat) == INDEX_NONE)
			{
				Cats.AddItem(Cat);
			}
		}
	}
	return Cats;
}

static function EquipAllowedWeapons(XComGameState_Unit Unit, XComGameState_USLW_Unit Comp, XComGameState NewGameState)
{
	local XComGameState_HeadquartersXCom XComHQ;

	XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
	EquipSlot(Unit, eInvSlot_PrimaryWeapon, Comp.PrimaryCats, XComHQ, NewGameState);
	EquipSlot(Unit, eInvSlot_SecondaryWeapon, Comp.SecondaryCats, XComHQ, NewGameState);
}

// Swaps a weapon the slot no longer allows for the best infinite one of an allowed
// category. The weapon stays when the inventory holds none.
static function EquipSlot(XComGameState_Unit Unit, EInventorySlot InvSlot, array<name> Cats, XComGameState_HeadquartersXCom XComHQ, XComGameState NewGameState)
{
	local XComGameStateHistory History;
	local XComGameState_Item Current, ItemState;
	local X2WeaponTemplate WeaponTemplate, Best;
	local StateObjectReference ItemRef;

	if (Cats.Length == 0)
	{
		return;
	}
	Current = Unit.GetItemInSlot(InvSlot, NewGameState);
	if (Current != none)
	{
		WeaponTemplate = X2WeaponTemplate(Current.GetMyTemplate());
		if (WeaponTemplate != none && Cats.Find(WeaponTemplate.WeaponCat) != INDEX_NONE)
		{
			return;
		}
	}

	History = `XCOMHISTORY;
	foreach XComHQ.Inventory(ItemRef)
	{
		ItemState = XComGameState_Item(History.GetGameStateForObjectID(ItemRef.ObjectID));
		WeaponTemplate = ItemState != none ? X2WeaponTemplate(ItemState.GetMyTemplate()) : none;
		if (WeaponTemplate != none && WeaponTemplate.bInfiniteItem && Cats.Find(WeaponTemplate.WeaponCat) != INDEX_NONE
			&& (Best == none || WeaponTemplate.Tier > Best.Tier))
		{
			Best = WeaponTemplate;
		}
	}
	if (Best == none)
	{
		return;
	}
	if (Current != none)
	{
		Current = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', Current.ObjectID));
		if (!Unit.RemoveItemFromInventory(Current, NewGameState))
		{
			return;
		}
		XComHQ.PutItemInInventory(NewGameState, Current);
	}
	ItemState = Best.CreateInstanceFromTemplate(NewGameState);
	if (!Unit.AddItemToInventory(ItemState, InvSlot, NewGameState))
	{
		XComHQ.PutItemInInventory(NewGameState, ItemState);
	}
}

//---------------------------------------------------------------------------------------
//  Ability tree

static function array<SoldierRankAbilities> BuildTree(array<USLW_Spec> Specs, array<SoldierClassAbilityType> Origins, out array<USLW_Family> Families)
{
	local X2SoldierClassTemplate UniversalClass, PrimaryClass;
	local array<SoldierClassRandomAbilityDeck> Decks;
	local array<SoldierRankAbilities> Tree;
	local SoldierRankAbilities EmptyRank;
	local SoldierClassAbilitySlot Slot;
	local array<SoldierClassAbilitySlot> PrimarySlots;
	local SoldierClassAbilityType Ability, EmptyAbility;
	local array<USLW_Placed> Placed;
	local array<name> Seen;
	local int Rank, i, j;

	UniversalClass = FindClass(CLASS_NAME);
	PrimaryClass = FindClass(Specs[0].ClassName);
	Decks = PrimaryClass.RandomAbilityDecks;

	for (Rank = 0; Rank < UniversalClass.GetMaxConfiguredRank(); Rank++)
	{
		Tree.AddItem(EmptyRank);
		if (Rank == 0)
		{
			// Squaddie abilities are all granted, so duplicates are dropped and nothing
			// needs to stay aligned. Only the primary class adds its shared ones.
			for (i = 0; i < Specs.Length; i++)
			{
				PlaceAbility(Tree, Placed, Seen, Specs[i].RankAbilities[0], i, false);
			}
			for (j = 0; j < Specs[0].CoreAbilities.Length; j++)
			{
				PlaceAbility(Tree, Placed, Seen, Specs[0].CoreAbilities[j], 0, false);
			}
			foreach Origins(Ability)
			{
				PlaceAbility(Tree, Placed, Seen, Ability, Specs.Length + 1, false);
			}
			continue;
		}

		// Each specialization keeps its column, so a duplicate leaves its slot empty.
		for (i = 0; i < Specs.Length; i++)
		{
			Ability = EmptyAbility;
			if (Rank < Specs[i].RankAbilities.Length)
			{
				Ability = Specs[i].RankAbilities[Rank];
			}
			PlaceAbility(Tree, Placed, Seen, Ability, i, true);
		}
		if (Rank < PrimaryClass.GetMaxConfiguredRank())
		{
			PrimarySlots = PrimaryClass.GetAbilitySlots(Rank);
			foreach PrimarySlots(Slot)
			{
				if (Slot.RandomDeckName != '')
				{
					PlaceAbility(Tree, Placed, Seen, DrawFromDeck(Decks, Slot.RandomDeckName, Seen), Specs.Length, true);
				}
				else if (Slot.AbilityType.ApplyToWeaponSlot == eInvSlot_Pistol)
				{
					PlaceAbility(Tree, Placed, Seen, Slot.AbilityType, Specs.Length, true);
				}
			}
		}
	}

	Families = FindFamilies(Placed);
	return Tree;
}

// Adds the ability to the last rank of the tree. An ability already in the tree is
// dropped, or replaced by an empty slot when bKeepSlot is set.
static function PlaceAbility(out array<SoldierRankAbilities> Tree, out array<USLW_Placed> Placed, out array<name> Seen,
	SoldierClassAbilityType Ability, int Source, bool bKeepSlot)
{
	local SoldierClassAbilityType EmptyAbility;
	local USLW_Placed Entry;
	local int Rank;

	Rank = Tree.Length - 1;
	if (Ability.AbilityName == '' || Seen.Find(Ability.AbilityName) != INDEX_NONE)
	{
		if (bKeepSlot)
		{
			Tree[Rank].Abilities.AddItem(EmptyAbility);
		}
		return;
	}
	Seen.AddItem(Ability.AbilityName);
	Entry.Ability = Ability.AbilityName;
	Entry.Source = Source;
	Entry.Rank = Rank;
	Entry.Branch = Tree[Rank].Abilities.Length;
	Placed.AddItem(Entry);
	Tree[Rank].Abilities.AddItem(Ability);
}

// Removes and returns a random ability of the deck that the tree does not hold yet.
static function SoldierClassAbilityType DrawFromDeck(out array<SoldierClassRandomAbilityDeck> Decks, name DeckName, array<name> Seen)
{
	local SoldierClassAbilityType Ability;
	local array<int> Candidates;
	local int DeckIndex, i, Pick;

	DeckIndex = Decks.Find('DeckName', DeckName);
	if (DeckIndex == INDEX_NONE)
	{
		return Ability;
	}
	for (i = 0; i < Decks[DeckIndex].Abilities.Length; i++)
	{
		if (Seen.Find(Decks[DeckIndex].Abilities[i].AbilityName) == INDEX_NONE)
		{
			Candidates.AddItem(i);
		}
	}
	if (Candidates.Length == 0)
	{
		return Ability;
	}
	Pick = Candidates[`SYNC_RAND_STATIC(Candidates.Length)];
	Ability = Decks[DeckIndex].Abilities[Pick];
	Decks[DeckIndex].Abilities.Remove(Pick, 1);
	return Ability;
}

//---------------------------------------------------------------------------------------
//  Ability conflicts
//
//  Two abilities placed by different parts of the tree form a family when the player
//  should learn only one of them:
//  - an ABILITY_GROUPS entry lists both;
//  - one replaces the other through OverrideAbilities, without being its upgrade
//    (PrerequisiteAbilities);
//  - both show the same localized name, as variants of one ability do.
//  Abilities from one specialization never conflict, since its class designed them
//  together. The first family member learned locks the others. Squaddie abilities are
//  granted without a choice, so only the family member with the highest priority is:
//  the one that overrides the other, then the earlier in ABILITY_GROUPS, then the earlier
//  in the tree.

static function array<USLW_Family> FindFamilies(array<USLW_Placed> Placed)
{
	local array<int> Root;
	local array<USLW_Family> Families;
	local USLW_Family Family;
	local array<USLW_Placed> Members;
	local int i, j, k, RootI, RootJ;

	for (i = 0; i < Placed.Length; i++)
	{
		Root.AddItem(i);
	}
	for (i = 0; i < Placed.Length; i++)
	{
		for (j = i + 1; j < Placed.Length; j++)
		{
			if (Placed[i].Source != Placed[j].Source && AreRelated(Placed[i].Ability, Placed[j].Ability))
			{
				RootI = FindRoot(Root, i);
				RootJ = FindRoot(Root, j);
				Root[RootJ] = RootI;
			}
		}
	}

	for (i = 0; i < Placed.Length; i++)
	{
		if (FindRoot(Root, i) != i)
		{
			continue;
		}
		Members.Length = 0;
		for (j = 0; j < Placed.Length; j++)
		{
			if (FindRoot(Root, j) != i)
			{
				continue;
			}
			// Insertion by priority.
			for (k = 0; k < Members.Length && Outranks(Members[k], Placed[j]); k++) {}
			Members.InsertItem(k, Placed[j]);
		}
		if (Members.Length < 2)
		{
			continue;
		}
		Family.Members.Length = 0;
		for (k = 0; k < Members.Length; k++)
		{
			Family.Members.AddItem(Members[k].Ability);
		}
		Families.AddItem(Family);
	}
	return Families;
}

static function int FindRoot(array<int> Root, int i)
{
	while (Root[i] != i)
	{
		i = Root[i];
	}
	return i;
}

static function X2AbilityTemplate FindAbility(name AbilityName)
{
	return class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate(AbilityName);
}

// The index of the ABILITY_GROUPS entry listing both abilities, or INDEX_NONE.
static function int FindSharedGroup(name A, name B)
{
	local int i;

	for (i = 0; i < default.ABILITY_GROUPS.Length; i++)
	{
		if (default.ABILITY_GROUPS[i].Abilities.Find(A) != INDEX_NONE && default.ABILITY_GROUPS[i].Abilities.Find(B) != INDEX_NONE)
		{
			return i;
		}
	}
	return INDEX_NONE;
}

static function bool AreRelated(name A, name B)
{
	local X2AbilityTemplate TemplateA, TemplateB;

	if (FindSharedGroup(A, B) != INDEX_NONE)
	{
		return true;
	}
	TemplateA = FindAbility(A);
	TemplateB = FindAbility(B);
	if (TemplateA == none || TemplateB == none)
	{
		return false;
	}
	if (TemplateA.PrerequisiteAbilities.Find(B) != INDEX_NONE || TemplateB.PrerequisiteAbilities.Find(A) != INDEX_NONE)
	{
		return false;
	}
	if (TemplateA.OverrideAbilities.Find(B) != INDEX_NONE || TemplateB.OverrideAbilities.Find(A) != INDEX_NONE)
	{
		return true;
	}
	return TemplateA.LocFriendlyName != "" && TemplateA.LocFriendlyName ~= TemplateB.LocFriendlyName;
}

static function bool Outranks(USLW_Placed A, USLW_Placed B)
{
	local X2AbilityTemplate TemplateA, TemplateB;
	local int Group;

	TemplateA = FindAbility(A.Ability);
	TemplateB = FindAbility(B.Ability);
	if (TemplateA != none && TemplateA.OverrideAbilities.Find(B.Ability) != INDEX_NONE)
	{
		return true;
	}
	if (TemplateB != none && TemplateB.OverrideAbilities.Find(A.Ability) != INDEX_NONE)
	{
		return false;
	}
	Group = FindSharedGroup(A.Ability, B.Ability);
	if (Group != INDEX_NONE)
	{
		return default.ABILITY_GROUPS[Group].Abilities.Find(A.Ability) < default.ABILITY_GROUPS[Group].Abilities.Find(B.Ability);
	}
	return A.Rank < B.Rank || (A.Rank == B.Rank && A.Branch < B.Branch);
}

// The learned family member that keeps the unit from learning this ability, or ''.
static function name GetLockingAbility(XComGameState_Unit Unit, XComGameState_USLW_Unit Comp, name AbilityName)
{
	local USLW_Family Family;
	local name Member;

	foreach Comp.Families(Family)
	{
		if (Family.Members.Find(AbilityName) == INDEX_NONE)
		{
			continue;
		}
		foreach Family.Members(Member)
		{
			if (Member != AbilityName && Unit.HasSoldierAbility(Member))
			{
				return Member;
			}
		}
	}
	return '';
}

// Buys the squaddie abilities, skipping any outranked by a family member at the same rank.
static function GrantSquaddieAbilities(XComGameState_Unit Unit, XComGameState_USLW_Unit Comp, XComGameState NewGameState)
{
	local USLW_Family Family;
	local name AbilityName, Member;
	local int i;
	local bool bOutranked;

	for (i = 0; i < Unit.AbilityTree[0].Abilities.Length; i++)
	{
		AbilityName = Unit.AbilityTree[0].Abilities[i].AbilityName;
		if (AbilityName == '')
		{
			continue;
		}
		bOutranked = false;
		foreach Comp.Families(Family)
		{
			if (Family.Members.Find(AbilityName) == INDEX_NONE)
			{
				continue;
			}
			foreach Family.Members(Member)
			{
				if (Unit.AbilityTree[0].Abilities.Find('AbilityName', Member) != INDEX_NONE)
				{
					bOutranked = Member != AbilityName;
					break;
				}
			}
		}
		if (!bOutranked)
		{
			Unit.BuySoldierProgressionAbility(NewGameState, 0, i);
		}
	}
}

//---------------------------------------------------------------------------------------
//  Unit state

static function bool IsUniversal(XComGameState_Unit Unit)
{
	return Unit != none && Unit.GetSoldierClassTemplateName() == CLASS_NAME;
}

static function XComGameState_USLW_Unit GetComponent(XComGameState_Unit Unit)
{
	return XComGameState_USLW_Unit(Unit.FindComponentObject(class'XComGameState_USLW_Unit'));
}

// Unit must already be part of NewGameState.
static function XComGameState_USLW_Unit GetOrCreateComponent(XComGameState_Unit Unit, XComGameState NewGameState)
{
	local XComGameState_USLW_Unit Comp;

	Comp = GetComponent(Unit);
	if (Comp != none)
	{
		return XComGameState_USLW_Unit(NewGameState.ModifyStateObject(class'XComGameState_USLW_Unit', Comp.ObjectID));
	}
	Comp = XComGameState_USLW_Unit(NewGameState.CreateNewStateObject(class'XComGameState_USLW_Unit'));
	Unit.AddComponentObject(Comp);
	return Comp;
}

static function bool NeedsSpecs(XComGameState_Unit Unit)
{
	local XComGameState_USLW_Unit Comp;

	if (!IsUniversal(Unit) || Unit.GetRank() < 1)
	{
		return false;
	}
	Comp = GetComponent(Unit);
	return Comp == none || Comp.Specs.Length == 0;
}

// True when something rebuilt the unit's tree from the class template, as LWOTC's
// respec does, after specializations were chosen.
static function bool NeedsTreeRestore(XComGameState_Unit Unit)
{
	local XComGameState_USLW_Unit Comp;
	local int Rank, i;

	if (!IsUniversal(Unit))
	{
		return false;
	}
	Comp = GetComponent(Unit);
	if (Comp == none || Comp.Specs.Length == 0)
	{
		return false;
	}
	if (Unit.AbilityTree.Length != Comp.Tree.Length)
	{
		return true;
	}
	for (Rank = 0; Rank < Comp.Tree.Length; Rank++)
	{
		if (Unit.AbilityTree[Rank].Abilities.Length != Comp.Tree[Rank].Abilities.Length)
		{
			return true;
		}
		for (i = 0; i < Comp.Tree[Rank].Abilities.Length; i++)
		{
			if (Unit.AbilityTree[Rank].Abilities[i].AbilityName != Comp.Tree[Rank].Abilities[i].AbilityName)
			{
				return true;
			}
		}
	}
	return false;
}

// Unit must already be part of NewGameState. Returns false when a specialization no
// longer exists, for instance because its class pack was removed.
static function bool ApplySpecs(XComGameState_Unit Unit, array<USLW_SpecRef> Refs, array<SoldierClassAbilityType> Origins, XComGameState NewGameState)
{
	local SoldierClassAbilityType Origin;
	local XComGameState_USLW_Unit Comp;
	local array<USLW_Spec> Specs;
	local array<USLW_Family> Families;
	local USLW_Spec Spec;
	local USLW_SpecRef Ref;

	foreach Refs(Ref)
	{
		if (!ResolveSpec(Ref, Spec))
		{
			return false;
		}
		Specs.AddItem(Spec);
	}
	Comp = GetOrCreateComponent(Unit, NewGameState);
	Comp.Specs = Refs;
	Comp.Origins.Length = 0;
	foreach Origins(Origin)
	{
		Comp.Origins.AddItem(Origin.AbilityName);
	}
	Comp.Tree = BuildTree(Specs, Origins, Families);
	Comp.Families = Families;
	Comp.PrimaryCats = GetAllowedCats(Specs, eInvSlot_PrimaryWeapon);
	Comp.SecondaryCats = GetAllowedCats(Specs, eInvSlot_SecondaryWeapon);
	RestoreTree(Unit, Comp, NewGameState);
	EquipAllowedWeapons(Unit, Comp, NewGameState);
	return true;
}

static function RestoreTree(XComGameState_Unit Unit, XComGameState_USLW_Unit Comp, XComGameState NewGameState)
{
	Unit.AbilityTree = Comp.Tree;
	GrantSquaddieAbilities(Unit, Comp, NewGameState);
}

// Forgets the specializations and rebuilds the empty tree of the class template, so the
// unit chooses again. Unit and Comp must already be part of NewGameState.
static function ClearSpecs(XComGameState_Unit Unit, XComGameState_USLW_Unit Comp)
{
	Comp.Specs.Length = 0;
	Comp.Tree.Length = 0;
	Comp.Families.Length = 0;
	Comp.Origins.Length = 0;
	Comp.PrimaryCats.Length = 0;
	Comp.SecondaryCats.Length = 0;
	Unit.BuildAbilityTree();
	Unit.ResetSoldierAbilities();
}

//---------------------------------------------------------------------------------------
//  Class template

// Finds the source classes, then shapes every difficulty variant of the universal class
// after them.
static function SetupClassTemplate()
{
	local array<X2DataTemplate> Variants;
	local X2DataTemplate Variant;
	local array<X2SoldierClassTemplate> Sources;
	local array<USLW_WeaponNeed> AtSRNeeds;

	StoreSourceClasses(DiscoverSourceClasses());
	Sources = GetSourceClasses();
	AtSRNeeds = class'USLW_AtSR'.static.DiscoverAtSRNeeds();
	StoreWeaponNeeds(DiscoverWeaponNeeds(Sources), AtSRNeeds);
	`Log("UniversalSoldierLW:" @ AtSRNeeds.Length @ "abilities with weapon needs from Ability To Slot Reassignment");
	`Log("UniversalSoldierLW: source classes" @ JoinNames(GetSourceClassNames()));
	if (Sources.Length == 0)
	{
		`RedScreen("UniversalSoldierLW: no source classes");
		return;
	}
	class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager().FindDataTemplateAllDifficulties(CLASS_NAME, Variants);
	foreach Variants(Variant)
	{
		ShapeClassTemplate(X2SoldierClassTemplate(Variant), Sources);
	}
}

static function StoreSourceClasses(array<name> Names)
{
	local array<X2DataTemplate> Variants;
	local X2DataTemplate Variant;

	class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().FindDataTemplateAllDifficulties('USLW_Data', Variants);
	foreach Variants(Variant)
	{
		X2USLWDataTemplate(Variant).SourceClassNames = Names;
	}
}

static function StoreWeaponNeeds(array<USLW_WeaponNeed> Needs, array<USLW_WeaponNeed> AtSRNeeds)
{
	local array<X2DataTemplate> Variants;
	local X2DataTemplate Variant;

	class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().FindDataTemplateAllDifficulties('USLW_Data', Variants);
	foreach Variants(Variant)
	{
		X2USLWDataTemplate(Variant).WeaponNeeds = Needs;
		X2USLWDataTemplate(Variant).AtSRNeeds = AtSRNeeds;
	}
}

static function string JoinNames(array<name> Names)
{
	local array<string> Strings;
	local string Result;
	local name Entry;

	foreach Names(Entry)
	{
		Strings.AddItem(string(Entry));
	}
	JoinArray(Strings, Result, ", ");
	return Result;
}

// SPECIALIZATION_COUNT empty slots per rank, as many ranks as the longest class, the
// average stat progression, and every weapon and armor any of them allows.
static function ShapeClassTemplate(X2SoldierClassTemplate Template, array<X2SoldierClassTemplate> Sources)
{
	local X2SoldierClassTemplate Source;
	local SoldierClassRank RankData, EmptyRankData;
	local SoldierClassAbilitySlot EmptySlot;
	local SoldierClassWeaponType Allowed;
	local name Armor;
	local int MaxRank, Rank, i, ApSum, ApIncrementSum, AssistSum, AwcCount;

	if (Template == none)
	{
		return;
	}

	foreach Sources(Source)
	{
		MaxRank = Max(MaxRank, Source.GetMaxConfiguredRank());
		ApSum += Source.BaseAbilityPointsPerPromotion;
		ApIncrementSum += Source.AbilityPointsIncrementPerPromotion;
		AssistSum += Source.KillAssistsPerKill;
		AwcCount += Source.bAllowAWCAbilities ? 1 : 0;
		foreach Source.AllowedWeapons(Allowed)
		{
			if (!HasAllowedWeapon(Template.AllowedWeapons, Allowed))
			{
				Template.AllowedWeapons.AddItem(Allowed);
			}
		}
		foreach Source.AllowedArmors(Armor)
		{
			if (Template.AllowedArmors.Find(Armor) == INDEX_NONE)
			{
				Template.AllowedArmors.AddItem(Armor);
			}
		}
	}

	Template.SoldierRanks.Length = 0;
	for (Rank = 0; Rank < MaxRank; Rank++)
	{
		RankData = EmptyRankData;
		if (Rank > 0)
		{
			for (i = 0; i < GetSpecCount(); i++)
			{
				RankData.AbilitySlots.AddItem(EmptySlot);
			}
		}
		RankData.aStatProgression = AverageStatProgression(Sources, Rank);
		Template.SoldierRanks.AddItem(RankData);
	}

	Template.BaseAbilityPointsPerPromotion = Round(float(ApSum) / Sources.Length);
	Template.AbilityPointsIncrementPerPromotion = Round(float(ApIncrementSum) / Sources.Length);
	Template.KillAssistsPerKill = Max(1, Round(float(AssistSum) / Sources.Length));
	Template.bAllowAWCAbilities = AwcCount * 2 > Sources.Length;
}

static function bool HasAllowedWeapon(array<SoldierClassWeaponType> AllowedWeapons, SoldierClassWeaponType Allowed)
{
	local SoldierClassWeaponType Entry;

	foreach AllowedWeapons(Entry)
	{
		if (Entry.WeaponType == Allowed.WeaponType && Entry.SlotType == Allowed.SlotType)
		{
			return true;
		}
	}
	return false;
}

// Per stat, the mean of what the classes with this rank grant; caps take the highest.
static function array<SoldierClassStatType> AverageStatProgression(array<X2SoldierClassTemplate> Sources, int Rank)
{
	local array<SoldierClassStatType> Result;
	local SoldierClassStatType Entry, Stat;
	local X2SoldierClassTemplate Source;
	local array<int> Amounts, RandAmounts, Caps, Counts;
	local array<SoldierClassStatType> Progression;
	local int Classes, i;

	Amounts.Length = eStat_MAX;
	RandAmounts.Length = eStat_MAX;
	Caps.Length = eStat_MAX;
	Counts.Length = eStat_MAX;
	foreach Sources(Source)
	{
		if (Rank >= Source.GetMaxConfiguredRank())
		{
			continue;
		}
		Classes++;
		Progression = Source.GetStatProgression(Rank);
		foreach Progression(Stat)
		{
			Amounts[Stat.StatType] += Stat.StatAmount;
			RandAmounts[Stat.StatType] += Stat.RandStatAmount;
			Caps[Stat.StatType] = Max(Caps[Stat.StatType], Stat.CapStatAmount);
			Counts[Stat.StatType]++;
		}
	}
	for (i = 0; i < eStat_MAX && Classes > 0; i++)
	{
		if (Counts[i] == 0)
		{
			continue;
		}
		Entry.StatType = ECharStatType(i);
		Entry.StatAmount = Round(float(Amounts[i]) / Classes);
		Entry.RandStatAmount = Round(float(RandAmounts[i]) / Classes);
		Entry.CapStatAmount = Caps[i];
		Result.AddItem(Entry);
	}
	return Result;
}

defaultproperties
{
}
