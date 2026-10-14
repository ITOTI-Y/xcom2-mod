// One ability in the choice screen's preview: its icon on the colored background the
// promotion screen uses, gold and diamond shaped when only the primary specialization
// grants it, its name under it, and a hover callback that shows its description.
class UIUSLW_AbilityIcon extends UIPanel;

const ICON_SIZE = 56;
const LABEL_WIDTH = 80;

var name AbilityName;
var string RankLabel;
var bool bPrimaryOnly;

delegate OnHover(UIUSLW_AbilityIcon Source);

simulated function UIUSLW_AbilityIcon InitAbilityIcon(name InAbilityName, string InRankLabel, bool bInPrimaryOnly, X2AbilityTemplate AbilityTemplate)
{
	local UIIcon Icon;
	local UIText Label;

	AbilityName = InAbilityName;
	RankLabel = InRankLabel;
	bPrimaryOnly = bInPrimaryOnly;
	InitPanel();
	SetSize(LABEL_WIDTH, ICON_SIZE + 40);

	Icon = Spawn(class'UIIcon', self);
	Icon.InitIcon('', AbilityTemplate.IconImage, true, true, ICON_SIZE, eUIState_Normal);
	Icon.SetForegroundColor(class'UIUtilities_Colors'.const.BLACK_HTML_COLOR);
	Icon.SetPosition((LABEL_WIDTH - ICON_SIZE) / 2, 0);
	Icon.ProcessMouseEvents(OnIconMouseEvent);

	if (bPrimaryOnly)
	{
		Icon.SetBGShape(eDiamond);
		Icon.SetBGColorState(eUIState_Warning);
	}

	Label = Spawn(class'UIText', self);
	Label.InitText('', class'UIUtilities_Text'.static.AlignCenter(
		class'UIUtilities_Text'.static.GetColoredText(AbilityTemplate.LocFriendlyName, eUIState_Normal, 14)));
	Label.SetPosition(0, ICON_SIZE + 2);
	Label.SetSize(LABEL_WIDTH, 38);
	return self;
}

simulated function OnIconMouseEvent(UIPanel Control, int Cmd)
{
	if (Cmd == class'UIUtilities_Input'.const.FXS_L_MOUSE_IN || Cmd == class'UIUtilities_Input'.const.FXS_L_MOUSE_OVER)
	{
		OnHover(self);
	}
}
