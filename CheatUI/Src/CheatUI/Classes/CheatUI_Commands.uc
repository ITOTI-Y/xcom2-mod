//---------------------------------------------------------------------------------------
//  The commands the cheat menu offers, read from XComCheatUI.ini.
//
//  A command is a console command line whose %1, %2, ... are filled from its
//  parameters in order. Labels come from CheatUI.int and its translations, keyed by the
//  command, category or choice name; a missing label falls back to the name itself.
//---------------------------------------------------------------------------------------
class CheatUI_Commands extends Object config(CheatUI);

// Kind is one of: Number, Text, Choice (from Choices), Item, Ability, Tech, Character,
// SoldierClass (template names), Soldier (a soldier's full name).
struct CheatUI_Param
{
	var name Kind;
	var array<string> Choices;
	var string Default;
};

// Context is Strategy, Tactical or Any.
struct CheatUI_Command
{
	var name Id;
	var name Category;
	var name Context;
	var string Command;
	var array<CheatUI_Param> Params;
};

struct CheatUI_Option
{
	var string Value;
	var string Label;
};

var config int HOTKEY;
var config int MAX_OPTIONS;
var config array<CheatUI_Command> MENU_COMMANDS;

static function bool IsStrategy()
{
	return XComHQPresentationLayer(`PRESBASE) != none;
}

static function bool IsAvailable(CheatUI_Command Command)
{
	switch (Command.Context)
	{
	case 'Strategy':
		return IsStrategy();
	case 'Tactical':
		return !IsStrategy();
	default:
		return true;
	}
}

static function string LocalizeOr(string Section, string Key, string Fallback)
{
	local string Text;

	Text = Localize(Section, Key, "CheatUI");
	return (Text == "" || Left(Text, 1) == "?") ? Fallback : Text;
}

static function string GetLabel(CheatUI_Command Command)
{
	return LocalizeOr("CommandLabels", string(Command.Id), Command.Command);
}

static function string GetCategoryLabel(name Category)
{
	return LocalizeOr("CategoryLabels", string(Category), string(Category));
}

static function string GetParamLabel(CheatUI_Command Command, int Index)
{
	return LocalizeOr("ParamLabels", Command.Id $ "_" $ (Index + 1), string(Command.Params[Index].Kind));
}

// Fills %1, %2, ... with the arguments; an argument with spaces is quoted, as the
// console splits arguments at spaces.
static function string BuildCommandLine(CheatUI_Command Command, array<string> Args)
{
	local string Line, Arg;
	local int i;

	Line = Command.Command;
	for (i = Args.Length - 1; i >= 0; i--)
	{
		Arg = Args[i];
		if (InStr(Arg, " ") != INDEX_NONE)
		{
			Arg = "\"" $ Arg $ "\"";
		}
		Line = Repl(Line, "%" $ (i + 1), Arg);
	}
	return Line;
}

// The options of a list parameter whose value or label contains Filter, at most
// MAX_OPTIONS of them; Total receives how many matched.
static function array<CheatUI_Option> GetOptions(CheatUI_Param Param, string Filter, out int Total)
{
	local array<CheatUI_Option> Options;
	local CheatUI_Option Option;
	local string Choice;

	Total = 0;
	switch (Param.Kind)
	{
	case 'Choice':
		foreach Param.Choices(Choice)
		{
			Option.Value = Choice;
			Option.Label = LocalizeOr("ChoiceLabels", Choice, Choice);
			AddOption(Options, Option, Filter, Total);
		}
		break;
	case 'Item':
		AddItemOptions(Options, Filter, Total);
		break;
	case 'Ability':
		AddAbilityOptions(Options, Filter, Total);
		break;
	case 'Tech':
		AddTechOptions(Options, Filter, Total);
		break;
	case 'Character':
		AddCharacterOptions(Options, Filter, Total);
		break;
	case 'SoldierClass':
		AddSoldierClassOptions(Options, Filter, Total);
		break;
	case 'Soldier':
		AddSoldierOptions(Options, Filter, Total);
		break;
	}
	return Options;
}

static function bool IsListKind(name Kind)
{
	return Kind != 'Number' && Kind != 'Text';
}

static function AddOption(out array<CheatUI_Option> Options, CheatUI_Option Option, string Filter, out int Total)
{
	if (Filter != "" && InStr(Caps(Option.Value), Caps(Filter)) == INDEX_NONE && InStr(Caps(Option.Label), Caps(Filter)) == INDEX_NONE)
	{
		return;
	}
	Total++;
	if (Options.Length < default.MAX_OPTIONS)
	{
		Options.AddItem(Option);
	}
}

static function CheatUI_Option MakeTemplateOption(name DataName, string FriendlyName)
{
	local CheatUI_Option Option;

	Option.Value = string(DataName);
	Option.Label = FriendlyName != "" ? FriendlyName $ "  (" $ DataName $ ")" : string(DataName);
	return Option;
}

static function AddItemOptions(out array<CheatUI_Option> Options, string Filter, out int Total)
{
	local X2ItemTemplateManager Manager;
	local X2DataTemplate DataTemplate;
	local X2ItemTemplate ItemTemplate;

	Manager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	foreach Manager.IterateTemplates(DataTemplate, none)
	{
		ItemTemplate = X2ItemTemplate(DataTemplate);
		if (ItemTemplate != none)
		{
			AddOption(Options, MakeTemplateOption(ItemTemplate.DataName, ItemTemplate.GetItemFriendlyName()), Filter, Total);
		}
	}
}

static function AddAbilityOptions(out array<CheatUI_Option> Options, string Filter, out int Total)
{
	local X2AbilityTemplateManager Manager;
	local X2DataTemplate DataTemplate;
	local X2AbilityTemplate AbilityTemplate;

	Manager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	foreach Manager.IterateTemplates(DataTemplate, none)
	{
		AbilityTemplate = X2AbilityTemplate(DataTemplate);
		if (AbilityTemplate != none)
		{
			AddOption(Options, MakeTemplateOption(AbilityTemplate.DataName, AbilityTemplate.LocFriendlyName), Filter, Total);
		}
	}
}

static function AddTechOptions(out array<CheatUI_Option> Options, string Filter, out int Total)
{
	local X2StrategyElementTemplateManager Manager;
	local X2DataTemplate DataTemplate;
	local X2TechTemplate TechTemplate;

	Manager = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	foreach Manager.IterateTemplates(DataTemplate, none)
	{
		TechTemplate = X2TechTemplate(DataTemplate);
		if (TechTemplate != none)
		{
			AddOption(Options, MakeTemplateOption(TechTemplate.DataName, TechTemplate.DisplayName), Filter, Total);
		}
	}
}

static function AddCharacterOptions(out array<CheatUI_Option> Options, string Filter, out int Total)
{
	local X2CharacterTemplateManager Manager;
	local X2DataTemplate DataTemplate;
	local X2CharacterTemplate CharacterTemplate;

	Manager = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
	foreach Manager.IterateTemplates(DataTemplate, none)
	{
		CharacterTemplate = X2CharacterTemplate(DataTemplate);
		if (CharacterTemplate != none)
		{
			AddOption(Options, MakeTemplateOption(CharacterTemplate.DataName, CharacterTemplate.strCharacterName), Filter, Total);
		}
	}
}

static function AddSoldierClassOptions(out array<CheatUI_Option> Options, string Filter, out int Total)
{
	local X2SoldierClassTemplateManager Manager;
	local X2DataTemplate DataTemplate;
	local X2SoldierClassTemplate ClassTemplate;

	Manager = class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager();
	foreach Manager.IterateTemplates(DataTemplate, none)
	{
		ClassTemplate = X2SoldierClassTemplate(DataTemplate);
		if (ClassTemplate != none && !ClassTemplate.bMultiplayerOnly)
		{
			AddOption(Options, MakeTemplateOption(ClassTemplate.DataName, ClassTemplate.DisplayName), Filter, Total);
		}
	}
}

static function AddSoldierOptions(out array<CheatUI_Option> Options, string Filter, out int Total)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_Unit Unit;
	local array<XComGameState_Unit> Soldiers;
	local CheatUI_Option Option;

	XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom', true));
	if (XComHQ == none)
	{
		return;
	}
	Soldiers = XComHQ.GetSoldiers();
	foreach Soldiers(Unit)
	{
		Option.Value = Unit.GetFullName();
		Option.Label = Unit.GetFullName() $ "  (" $ Unit.GetSoldierClassDisplayName() $ ")";
		AddOption(Options, Option, Filter, Total);
	}
}

static function Run(string CommandLine)
{
	local PlayerController PC;

	PC = class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController();
	// Retail builds create the cheat manager only with -allowconsole; forcing it lets
	// most cheats run without the launch option. A forced AddCheats replaces an existing
	// manager, and with it the toggles it holds (unlimited actions and the like), so it
	// only runs when there is none.
	if (PC.CheatManager == none)
	{
		PC.AddCheats(true);
	}
	PC.ConsoleCommand(CommandLine);
}

defaultproperties
{
}
