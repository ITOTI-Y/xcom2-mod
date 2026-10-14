class X2EventListener_USLW extends X2EventListener dependson(USLW_Specs);

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateStrategyListeners());
	Templates.AddItem(CreateClassInfoListeners());
	return Templates;
}

static function CHEventListenerTemplate CreateStrategyListeners()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'USLW_StrategyListeners');
	Template.RegisterInStrategy = true;
	Template.AddCHEvent('FirstPromotionOverrideClass', OnFirstPromotion, ELD_Immediate);
	Template.AddCHEvent('CompleteRespecSoldier', OnCompleteRespec, ELD_Immediate);
	Template.AddCHEvent('ValidateGTSClassTraining', OnValidateClassTraining, ELD_Immediate);
	Template.AddCHEvent('OverrideLocalizedAbilityTreeTitle', OnAbilityTreeTitle, ELD_Immediate);
	// Below LWOTC's default priority, so its own purchase rules run first.
	Template.AddCHEvent('CPS_OverrideCanPurchaseAbility', OnCanPurchaseAbility, ELD_Immediate, 40);
	return Template;
}

static function CHEventListenerTemplate CreateClassInfoListeners()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'USLW_ClassInfoListeners');
	Template.RegisterInStrategy = true;
	Template.RegisterInTactical = true;
	Template.AddCHEvent('SoldierClassIcon', OnSoldierClassIcon, ELD_Immediate);
	Template.AddCHEvent('SoldierClassSummary', OnSoldierClassSummary, ELD_Immediate);
	return Template;
}

// Every soldier that would become one of the source classes becomes a universal
// soldier instead; classes outside the pool, such as Psi Operatives, are kept.
static function EventListenerReturn OnFirstPromotion(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComLWTuple Tuple;
	local name ClassName;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
	{
		return ELR_NoInterrupt;
	}
	ClassName = Tuple.Data[0].n;
	if (ClassName == '' || class'USLW_Specs'.static.IsSourceClass(class'USLW_Specs'.static.FindClass(ClassName)))
	{
		Tuple.Data[0].n = class'USLW_Specs'.const.CLASS_NAME;
	}
	return ELR_NoInterrupt;
}

// Class lists for rookies, in the GTS and in mods such as WOTC_ChooseMyClass, offer the
// universal soldier in place of the classes it draws from, which it would replace anyway.
static function EventListenerReturn OnValidateClassTraining(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComLWTuple Tuple;
	local X2SoldierClassTemplate ClassTemplate;

	Tuple = XComLWTuple(EventData);
	ClassTemplate = Tuple != none ? X2SoldierClassTemplate(Tuple.Data[1].o) : none;
	if (ClassTemplate == none)
	{
		return ELR_NoInterrupt;
	}
	if (ClassTemplate.DataName == class'USLW_Specs'.const.CLASS_NAME)
	{
		Tuple.Data[0].b = true;
	}
	else if (class'USLW_Specs'.static.IsSourceClass(ClassTemplate))
	{
		Tuple.Data[0].b = false;
	}
	return ELR_NoInterrupt;
}

// Retraining lets the soldier choose specializations again and removes stat upgrades.
static function EventListenerReturn OnCompleteRespec(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState_Unit Unit;
	local XComGameState_USLW_Unit Comp;

	Unit = XComGameState_Unit(EventSource);
	if (Unit == none || GameState == none)
	{
		return ELR_NoInterrupt;
	}
	Comp = class'USLW_Specs'.static.GetComponent(Unit);
	if (Comp == none)
	{
		return ELR_NoInterrupt;
	}
	Unit = XComGameState_Unit(GameState.ModifyStateObject(class'XComGameState_Unit', Unit.ObjectID));
	Comp = XComGameState_USLW_Unit(GameState.ModifyStateObject(class'XComGameState_USLW_Unit', Comp.ObjectID));
	class'USLW_Stats'.static.RevertUpgrades(Unit, Comp);
	if (class'USLW_Specs'.static.IsUniversal(Unit))
	{
		class'USLW_Specs'.static.ClearSpecs(Unit, Comp);
	}
	return ELR_NoInterrupt;
}

static function EventListenerReturn OnAbilityTreeTitle(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComLWTuple Tuple;
	local XComGameState_Unit Unit;
	local XComGameState_USLW_Unit Comp;
	local int Row;

	Tuple = XComLWTuple(EventData);
	Unit = XComGameState_Unit(EventSource);
	if (Tuple == none || !class'USLW_Specs'.static.IsUniversal(Unit))
	{
		return ELR_NoInterrupt;
	}
	Comp = class'USLW_Specs'.static.GetComponent(Unit);
	Row = Tuple.Data[0].i;
	if (Comp != none && Row >= 0 && Row < Comp.Specs.Length)
	{
		Tuple.Data[1].s = class'USLW_Specs'.static.GetSpecTitle(Comp.Specs[Row].ClassName, Comp.Specs[Row].Column);
	}
	return ELR_NoInterrupt;
}

static function EventListenerReturn OnCanPurchaseAbility(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComLWTuple Tuple;
	local XComGameState_Unit Unit;
	local XComGameState_USLW_Unit Comp;
	local X2AbilityTemplate AbilityTemplate;
	local name Locker;

	Tuple = XComLWTuple(EventData);
	Unit = XComGameState_Unit(EventSource);
	if (Tuple == none || !class'USLW_Specs'.static.IsUniversal(Unit) || !Tuple.Data[13].b)
	{
		return ELR_NoInterrupt;
	}
	Comp = class'USLW_Specs'.static.GetComponent(Unit);
	if (Comp == none)
	{
		return ELR_NoInterrupt;
	}
	Locker = class'USLW_Specs'.static.GetLockingAbility(Unit, Comp, Tuple.Data[0].n);
	if (Locker != '')
	{
		AbilityTemplate = class'USLW_Specs'.static.FindAbility(Locker);
		Tuple.Data[13].b = false;
		Tuple.Data[15].s = Repl(class'USLW_Specs'.default.strLockedBy, "%ABILITY",
			AbilityTemplate != none ? AbilityTemplate.LocFriendlyName : string(Locker));
	}
	return ELR_NoInterrupt;
}

// The icon of the first specialization's class tells universal soldiers apart.
static function EventListenerReturn OnSoldierClassIcon(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComLWTuple Tuple;
	local XComGameState_Unit Unit;
	local XComGameState_USLW_Unit Comp;
	local X2SoldierClassTemplate ClassTemplate;

	Tuple = XComLWTuple(EventData);
	Unit = XComGameState_Unit(EventSource);
	if (Tuple == none || !class'USLW_Specs'.static.IsUniversal(Unit))
	{
		return ELR_NoInterrupt;
	}
	Comp = class'USLW_Specs'.static.GetComponent(Unit);
	if (Comp != none && Comp.Specs.Length > 0)
	{
		ClassTemplate = class'USLW_Specs'.static.FindClass(Comp.Specs[0].ClassName);
		if (ClassTemplate != none && ClassTemplate.IconImage != "")
		{
			Tuple.Data[0].s = ClassTemplate.IconImage;
		}
	}
	return ELR_NoInterrupt;
}

static function EventListenerReturn OnSoldierClassSummary(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComLWTuple Tuple;
	local XComGameState_Unit Unit;
	local XComGameState_USLW_Unit Comp;
	local array<string> Titles;
	local USLW_SpecRef Ref;
	local string Summary;

	Tuple = XComLWTuple(EventData);
	Unit = XComGameState_Unit(EventSource);
	if (Tuple == none || !class'USLW_Specs'.static.IsUniversal(Unit))
	{
		return ELR_NoInterrupt;
	}
	Comp = class'USLW_Specs'.static.GetComponent(Unit);
	if (Comp == none || Comp.Specs.Length == 0)
	{
		return ELR_NoInterrupt;
	}
	foreach Comp.Specs(Ref)
	{
		Titles.AddItem(class'USLW_Specs'.static.GetSpecTitle(Ref.ClassName, Ref.Column));
	}
	JoinArray(Titles, Summary, "\n");
	Tuple.Data[0].s = Summary;
	return ELR_NoInterrupt;
}
