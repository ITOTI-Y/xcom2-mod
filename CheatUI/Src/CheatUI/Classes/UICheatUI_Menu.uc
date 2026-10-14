//---------------------------------------------------------------------------------------
//  The cheat menu. It lists the commands of the current layer by category; choosing one
//  asks for its parameters in order, a dialog for numbers and text and a filterable
//  list for everything else, then runs the command line and stays open. Everything sits
//  in one container anchored to the screen center, so wider screens keep it centered.
//---------------------------------------------------------------------------------------
class UICheatUI_Menu extends UIScreen dependson(CheatUI_Commands);

const PANEL_WIDTH = 800;
const PANEL_HEIGHT = 920;

var UIPanel Container;
var UIBGBox Background;
var UIX2PanelHeader Header;
var UIText Status;
var UIList List;
var UIButton FilterButton;
var UIButton BackButton;

var array<int> RowCommands;				// command index per list row, INDEX_NONE for category rows
var array<CheatUI_Option> RowOptions;	// option per list row while choosing a parameter

var bool bPicking;
var int CommandIndex;
var array<string> Args;
var string Filter;

var localized string strTitle;
var localized string strNoConsole;		// shown without -allowconsole
var localized string strRan;			// "Ran: %COMMAND"
var localized string strMatches;		// "%SHOWN of %TOTAL shown"
var localized string strFilter;
var localized string strFilterTitle;
var localized string strBack;
var localized string strClose;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	Container = Spawn(class'UIPanel', self);
	Container.InitPanel('CheatUI_Container');
	Container.SetAnchor(class'UIUtilities'.const.ANCHOR_MIDDLE_CENTER);
	Container.SetPosition(-PANEL_WIDTH / 2, -PANEL_HEIGHT / 2);

	Background = Spawn(class'UIBGBox', Container);
	Background.InitBG('CheatUI_Background', 0, 0, PANEL_WIDTH, PANEL_HEIGHT);

	Header = Spawn(class'UIX2PanelHeader', Container);
	Header.InitPanelHeader('CheatUI_Header', strTitle, "");
	Header.SetPosition(20, 15);
	Header.SetHeaderWidth(PANEL_WIDTH - 40);

	Status = Spawn(class'UIText', Container);
	Status.InitText('CheatUI_Status', "");
	Status.SetPosition(20, 80);
	Status.SetSize(PANEL_WIDTH - 40, 60);

	List = Spawn(class'UIList', Container);
	List.InitList('CheatUI_List', 20, 145, PANEL_WIDTH - 60, PANEL_HEIGHT - 225);
	List.OnItemClicked = OnRowClicked;

	FilterButton = Spawn(class'UIButton', Container);
	FilterButton.InitButton('CheatUI_Filter', strFilter, OnFilterButton);
	FilterButton.SetPosition(20, PANEL_HEIGHT - 60);

	BackButton = Spawn(class'UIButton', Container);
	BackButton.InitButton('CheatUI_Back', strClose, OnBackButton);
	BackButton.SetPosition(PANEL_WIDTH - 220, PANEL_HEIGHT - 60);

	SetStatus(class'Engine'.static.IsConsoleAllowed() ? "" : strNoConsole);
	ShowCommands();
}

simulated function SetStatus(string Text)
{
	Status.SetText(Text);
}

simulated function ShowCommands()
{
	local array<name> Categories;
	local CheatUI_Command Command;
	local name Category;
	local int i;

	bPicking = false;
	List.ClearItems();
	RowCommands.Length = 0;
	Header.SetText(strTitle, "");
	FilterButton.Hide();
	BackButton.SetText(strClose);

	foreach class'CheatUI_Commands'.default.MENU_COMMANDS(Command)
	{
		if (class'CheatUI_Commands'.static.IsAvailable(Command) && Categories.Find(Command.Category) == INDEX_NONE)
		{
			Categories.AddItem(Command.Category);
		}
	}
	foreach Categories(Category)
	{
		AddRow(class'UIUtilities_Text'.static.GetColoredText(class'CheatUI_Commands'.static.GetCategoryLabel(Category), eUIState_Header), true);
		RowCommands.AddItem(INDEX_NONE);
		for (i = 0; i < class'CheatUI_Commands'.default.MENU_COMMANDS.Length; i++)
		{
			Command = class'CheatUI_Commands'.default.MENU_COMMANDS[i];
			if (Command.Category == Category && class'CheatUI_Commands'.static.IsAvailable(Command))
			{
				AddRow("    " $ class'CheatUI_Commands'.static.GetLabel(Command), false);
				RowCommands.AddItem(i);
			}
		}
	}
}

simulated function AddRow(string Text, bool bDisabled)
{
	local UIListItemString Row;

	Row = Spawn(class'UIListItemString', List.ItemContainer);
	Row.InitListItem(Text);
	if (bDisabled)
	{
		Row.SetDisabled(true);
	}
}

simulated function CheatUI_Command GetCommand()
{
	return class'CheatUI_Commands'.default.MENU_COMMANDS[CommandIndex];
}

simulated function OnRowClicked(UIList ContainerList, int ItemIndex)
{
	if (bPicking)
	{
		if (ItemIndex >= 0 && ItemIndex < RowOptions.Length)
		{
			Args.AddItem(RowOptions[ItemIndex].Value);
			NextParam();
		}
		return;
	}
	if (ItemIndex < 0 || ItemIndex >= RowCommands.Length || RowCommands[ItemIndex] == INDEX_NONE)
	{
		return;
	}
	CommandIndex = RowCommands[ItemIndex];
	Args.Length = 0;
	NextParam();
}

simulated function NextParam()
{
	local CheatUI_Command Command;
	local CheatUI_Param Param;

	Command = GetCommand();
	if (Args.Length >= Command.Params.Length)
	{
		RunCommand();
		return;
	}
	Param = Command.Params[Args.Length];
	if (class'CheatUI_Commands'.static.IsListKind(Param.Kind))
	{
		Filter = "";
		ShowOptions();
	}
	else
	{
		AskText(class'CheatUI_Commands'.static.GetParamLabel(Command, Args.Length), Param.Default, OnParamEntered, OnParamCancelled);
	}
}

simulated function ShowOptions()
{
	local CheatUI_Command Command;
	local CheatUI_Option Option;
	local int Total;

	Command = GetCommand();
	bPicking = true;
	RowOptions = class'CheatUI_Commands'.static.GetOptions(Command.Params[Args.Length], Filter, Total);
	List.ClearItems();
	foreach RowOptions(Option)
	{
		AddRow(Option.Label, false);
	}
	Header.SetText(class'CheatUI_Commands'.static.GetLabel(Command), class'CheatUI_Commands'.static.GetParamLabel(Command, Args.Length));
	SetStatus(Repl(Repl(strMatches, "%SHOWN", string(RowOptions.Length)), "%TOTAL", string(Total))
		$ (Filter != "" ? "  [" $ Filter $ "]" : ""));
	FilterButton.Show();
	BackButton.SetText(strBack);
}

simulated function AskText(string Title, string Text, delegate<UIInputDialogue.TextInputAcceptedCallback> OnAccepted, delegate<UIInputDialogue.TextInputCancelledCallback> OnCancelled)
{
	local TInputDialogData Data;

	Data.strTitle = Title;
	Data.strInputBoxText = Text;
	Data.iMaxChars = 64;
	Data.fnCallbackAccepted = OnAccepted;
	Data.fnCallbackCancelled = OnCancelled;
	Movie.Pres.UIInputDialog(Data);
}

simulated function OnParamEntered(string Text)
{
	Args.AddItem(Text);
	NextParam();
}

simulated function OnParamCancelled(string Text)
{
	ShowCommands();
}

simulated function OnFilterButton(UIButton Button)
{
	AskText(strFilterTitle, Filter, OnFilterEntered, OnFilterCancelled);
}

simulated function OnFilterEntered(string Text)
{
	Filter = Text;
	ShowOptions();
}

simulated function OnFilterCancelled(string Text)
{
}

simulated function RunCommand()
{
	local string Line;

	Line = class'CheatUI_Commands'.static.BuildCommandLine(GetCommand(), Args);
	class'CheatUI_Commands'.static.Run(Line);
	`XSTRATEGYSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
	ShowCommands();
	SetStatus(Repl(strRan, "%COMMAND", Line));
}

simulated function OnBackButton(UIButton Button)
{
	GoBack();
}

simulated function GoBack()
{
	if (bPicking)
	{
		ShowCommands();
		return;
	}
	CloseScreen();
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
	{
		return false;
	}
	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_BUTTON_B:
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE:
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN:
		GoBack();
		return true;
	}
	return super.OnUnrealCommand(cmd, arg);
}

defaultproperties
{
	InputState = eInputState_Consume;
	bConsumeMouseEvents = true;
}
