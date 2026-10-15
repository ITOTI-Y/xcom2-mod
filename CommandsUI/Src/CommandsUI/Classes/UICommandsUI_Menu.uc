//---------------------------------------------------------------------------------------
//  The command menu. It lists the commands of the current layer by category; choosing one
//  asks for its parameters in order, a dialog for numbers and text and a filterable
//  list for everything else, then runs the command line and stays open. Toggle commands
//  carry a read-only checkbox with their current state. Everything sits
//  in one container anchored to the screen center, so wider screens keep it centered.
//---------------------------------------------------------------------------------------
class UICommandsUI_Menu extends UIScreen dependson(CommandsUI_Commands);

const PANEL_WIDTH = 800;
const PANEL_HEIGHT = 920;

var UIPanel Container;
var UIBGBox Background;
var UIX2PanelHeader Header;
var UIText Status;
var UIList List;
var UIButton FilterButton;
var UIButton BackButton;
var UIButton AdvancedButton;

var array<int> RowCommands;				// command index per list row, INDEX_NONE for category rows
var array<CommandsUI_Option> RowOptions;	// option per list row while choosing a parameter

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
var localized string strShowAll;		// shows the advanced commands too
var localized string strShowCommon;		// back to the common commands

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	Container = Spawn(class'UIPanel', self);
	Container.InitPanel('CommandsUI_Container');
	Container.SetAnchor(class'UIUtilities'.const.ANCHOR_MIDDLE_CENTER);
	Container.SetPosition(-PANEL_WIDTH / 2, -PANEL_HEIGHT / 2);

	Background = Spawn(class'UIBGBox', Container);
	Background.InitBG('CommandsUI_Background', 0, 0, PANEL_WIDTH, PANEL_HEIGHT);

	Header = Spawn(class'UIX2PanelHeader', Container);
	Header.InitPanelHeader('CommandsUI_Header', strTitle, "");
	Header.SetPosition(20, 15);
	Header.SetHeaderWidth(PANEL_WIDTH - 40);

	Status = Spawn(class'UIText', Container);
	Status.InitText('CommandsUI_Status', "");
	Status.SetPosition(20, 80);
	Status.SetSize(PANEL_WIDTH - 300, 60);

	AdvancedButton = Spawn(class'UIButton', Container);
	AdvancedButton.InitButton('CommandsUI_Advanced', "", OnAdvancedButton);
	AdvancedButton.SetPosition(PANEL_WIDTH - 260, 85);

	List = Spawn(class'UIList', Container);
	List.InitList('CommandsUI_List', 20, 145, PANEL_WIDTH - 60, PANEL_HEIGHT - 225);
	List.OnItemClicked = OnRowClicked;

	FilterButton = Spawn(class'UIButton', Container);
	FilterButton.InitButton('CommandsUI_Filter', strFilter, OnFilterButton);
	FilterButton.SetPosition(20, PANEL_HEIGHT - 60);

	BackButton = Spawn(class'UIButton', Container);
	BackButton.InitButton('CommandsUI_Back', strClose, OnBackButton);
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
	local CommandsUI_Command Command;
	local UIListItemString Row;
	local name Category;
	local int i;

	bPicking = false;
	List.ClearItems();
	RowCommands.Length = 0;
	Header.SetText(strTitle, "");
	FilterButton.Hide();
	BackButton.SetText(strClose);
	AdvancedButton.SetText(class'CommandsUI_Settings'.default.SHOW_ADVANCED ? strShowCommon : strShowAll);
	AdvancedButton.Show();

	foreach class'CommandsUI_Commands'.default.MENU_COMMANDS(Command)
	{
		if (class'CommandsUI_Commands'.static.IsShown(Command) && Categories.Find(Command.Category) == INDEX_NONE)
		{
			Categories.AddItem(Command.Category);
		}
	}
	foreach Categories(Category)
	{
		AddRow(class'UIUtilities_Text'.static.GetColoredText(class'CommandsUI_Commands'.static.GetCategoryLabel(Category), eUIState_Header), true);
		RowCommands.AddItem(INDEX_NONE);
		for (i = 0; i < class'CommandsUI_Commands'.default.MENU_COMMANDS.Length; i++)
		{
			Command = class'CommandsUI_Commands'.default.MENU_COMMANDS[i];
			if (Command.Category == Category && class'CommandsUI_Commands'.static.IsShown(Command))
			{
				Row = AddRow("    " $ class'CommandsUI_Commands'.static.GetLabel(Command), false);
				if (Command.Toggle != '')
				{
					AddToggleBox(Row, class'CommandsUI_Commands'.static.GetToggleState(Command.Toggle));
				}
				RowCommands.AddItem(i);
			}
		}
	}
}

simulated function UIListItemString AddRow(string Text, bool bDisabled)
{
	local UIListItemString Row;

	Row = Spawn(class'UIListItemString', List.ItemContainer);
	Row.InitListItem(Text);
	if (bDisabled)
	{
		Row.SetDisabled(true);
	}
	return Row;
}

// Read-only, so a click reaches the row and runs the toggle command.
simulated function AddToggleBox(UIListItemString Row, bool bChecked)
{
	local UICheckbox Checkbox;

	Checkbox = Spawn(class'UICheckbox', Row);
	Checkbox.InitCheckbox('', "", bChecked, , true);
	Checkbox.SetPosition(List.Width - 50, 0);
}

simulated function OnAdvancedButton(UIButton Button)
{
	class'CommandsUI_Settings'.static.SetShowAdvanced(!class'CommandsUI_Settings'.default.SHOW_ADVANCED);
	ShowCommands();
}

simulated function CommandsUI_Command GetCommand()
{
	return class'CommandsUI_Commands'.default.MENU_COMMANDS[CommandIndex];
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
	local CommandsUI_Command Command;
	local CommandsUI_Param Param;

	Command = GetCommand();
	if (Args.Length >= Command.Params.Length)
	{
		RunCommand();
		return;
	}
	Param = Command.Params[Args.Length];
	if (class'CommandsUI_Commands'.static.IsListKind(Param.Kind))
	{
		Filter = "";
		ShowOptions();
	}
	else
	{
		AskText(class'CommandsUI_Commands'.static.GetParamLabel(Command, Args.Length), Param.Default, OnParamEntered, OnParamCancelled);
	}
}

simulated function ShowOptions()
{
	local CommandsUI_Command Command;
	local CommandsUI_Option Option;
	local int Total;

	Command = GetCommand();
	bPicking = true;
	RowOptions = class'CommandsUI_Commands'.static.GetOptions(Command.Params[Args.Length], Filter, Total);
	List.ClearItems();
	foreach RowOptions(Option)
	{
		AddRow(Option.Label, false);
	}
	Header.SetText(class'CommandsUI_Commands'.static.GetLabel(Command), class'CommandsUI_Commands'.static.GetParamLabel(Command, Args.Length));
	SetStatus(Repl(Repl(strMatches, "%SHOWN", string(RowOptions.Length)), "%TOTAL", string(Total))
		$ (Filter != "" ? "  [" $ Filter $ "]" : ""));
	FilterButton.Show();
	AdvancedButton.Hide();
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
	local CommandsUI_Command Command;
	local string Line;

	Command = GetCommand();
	Line = class'CommandsUI_Commands'.static.BuildCommandLine(Command, Args);
	class'CommandsUI_Commands'.static.Run(Line);
	if (Command.Toggle != '')
	{
		class'CommandsUI_Settings'.static.SetToggleActive(Command.Toggle, class'CommandsUI_Commands'.static.GetToggleState(Command.Toggle));
	}
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
