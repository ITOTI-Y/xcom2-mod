//---------------------------------------------------------------------------------------
//  Menu state kept between sessions, in the user's XComCommandsUIState.ini. The mod ships
//  no such file, since a shipped copy would replace the saved values on every launch.
//---------------------------------------------------------------------------------------
class CommandsUI_Settings extends Object config(CommandsUIState);

var config bool SHOW_ADVANCED;
var config array<name> ACTIVE_TOGGLES;

static function SetShowAdvanced(bool bShow)
{
	default.SHOW_ADVANCED = bShow;
	StaticSaveConfig();
}

static function SetToggleActive(name Toggle, bool bActive)
{
	local array<name> Active;

	Active = default.ACTIVE_TOGGLES;
	Active.RemoveItem(Toggle);
	if (bActive)
	{
		Active.AddItem(Toggle);
	}
	default.ACTIVE_TOGGLES = Active;
	StaticSaveConfig();
}
