//---------------------------------------------------------------------------------------
//  Chooses a universal soldier's specializations, then its origin abilities.
//
//  The left list offers every entry of the step, the chosen ones disabled; the right
//  panel lists the choices, each removable with a click, and previews the highlighted
//  entry as a grid of ability icons, describing the one under the mouse. A choice only
//  updates its own row, since rebuilding the whole list stalls the screen.
//  The first step moves on once SPECIALIZATION_COUNT specializations are chosen, the
//  second applies everything once ORIGIN_ABILITY_COUNT abilities are; Back returns to
//  the specializations, or closes the screen. Retraining undoes an applied choice.
//---------------------------------------------------------------------------------------
class UIChooseSpecs_USLW extends UIUSLW_ListScreen dependson(USLW_Specs);

const PANEL_X = 1230;
const PANEL_Y = 120;
const PANEL_WIDTH = 640;
const CHOSEN_HEIGHT = 230;
const PREVIEW_HEIGHT = 470;
const GRID_HEIGHT = 200;
const ICONS_PER_ROW = 7;
const ICON_STEP_X = 85;
const ICON_STEP_Y = 100;
const DESCRIPTION_FONT_SIZE = 22;

var StateObjectReference UnitRef;
var array<USLW_Spec> AllSpecs;
var array<USLW_Spec> Chosen;
var array<USLW_Spec> Candidates;
var array<SoldierClassAbilityType> OriginPool;
var array<SoldierClassAbilityType> ChosenOrigins;
var array<SoldierClassAbilityType> OriginCandidates;
var bool bChoosingOrigins;

var UIPanel RightPanel;
var UIX2PanelHeader ChosenHeader;
var UIList ChosenList;
var UIX2PanelHeader PreviewHeader;
var UIPanel PreviewGrid;
var array<UIUSLW_AbilityIcon> PreviewIcons;
var UITextContainer Preview;
var UIButton ConfirmButton;

var localized string strSpecsTitle;		// "CHOOSE SPECIALIZATIONS"
var localized string strOriginsTitle;		// "CHOOSE ORIGIN ABILITIES"
var localized string strProgress;			// "%N of %COUNT chosen"
var localized string strChosenTitle;		// "CHOSEN"
var localized string strRemoveHint;		// "Click to remove"
var localized string strPreviewTitle;		// "ABILITY PREVIEW"
var localized string strChoose;
var localized string strPrimaryOnly;		// note on the shared squaddie abilities: only the primary brings them
var localized string strNext;
var localized string strConfirm;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	AllSpecs = class'USLW_Specs'.static.GetAllSpecs();
	OriginPool = class'USLW_Specs'.static.GetOriginPool();
	super.InitScreen(InitController, InitMovie, InitName);
	BuildRightPanel();
	Refresh();
}

simulated function BuildRightPanel()
{
	local UIBGBox Background;

	RightPanel = Spawn(class'UIPanel', self);
	RightPanel.InitPanel('USLW_RightPanel');
	RightPanel.SetPosition(PANEL_X, PANEL_Y);

	Background = Spawn(class'UIBGBox', RightPanel);
	Background.InitBG('USLW_RightBG', 0, 0, PANEL_WIDTH, CHOSEN_HEIGHT + PREVIEW_HEIGHT + 150);

	ChosenHeader = Spawn(class'UIX2PanelHeader', RightPanel);
	ChosenHeader.InitPanelHeader('USLW_ChosenHeader', strChosenTitle, strRemoveHint);
	ChosenHeader.SetHeaderWidth(PANEL_WIDTH - 40);
	ChosenHeader.SetPosition(20, 10);

	ChosenList = Spawn(class'UIList', RightPanel);
	ChosenList.InitList('USLW_ChosenList', 20, 70, PANEL_WIDTH - 60, CHOSEN_HEIGHT - 70);
	ChosenList.OnItemClicked = OnChosenClicked;

	PreviewHeader = Spawn(class'UIX2PanelHeader', RightPanel);
	PreviewHeader.InitPanelHeader('USLW_PreviewHeader', strPreviewTitle, "");
	PreviewHeader.SetHeaderWidth(PANEL_WIDTH - 40);
	PreviewHeader.SetPosition(20, CHOSEN_HEIGHT + 10);

	PreviewGrid = Spawn(class'UIPanel', RightPanel);
	PreviewGrid.InitPanel('USLW_PreviewGrid');
	PreviewGrid.SetPosition(20, CHOSEN_HEIGHT + 70);

	Preview = Spawn(class'UITextContainer', RightPanel);
	Preview.InitTextContainer('USLW_Preview', "", 20, CHOSEN_HEIGHT + 70 + GRID_HEIGHT, PANEL_WIDTH - 40, PREVIEW_HEIGHT - GRID_HEIGHT);

	ConfirmButton = Spawn(class'UIButton', RightPanel);
	ConfirmButton.InitButton('USLW_Confirm', strNext, OnConfirmButton);
	ConfirmButton.SetPosition(PANEL_WIDTH - 220, CHOSEN_HEIGHT + PREVIEW_HEIGHT + 90);
}

simulated function int GetOriginCount()
{
	return Min(Max(0, class'USLW_Specs'.default.ORIGIN_ABILITY_COUNT), OriginPool.Length);
}

simulated function bool IsStepFull()
{
	return bChoosingOrigins ? (ChosenOrigins.Length >= GetOriginCount()) : (Chosen.Length >= class'USLW_Specs'.static.GetSpecCount());
}

// Rebuilds the left list for the current step, then the right panel.
simulated function Refresh()
{
	GetItems();
	PopulateData();
	RefreshSide();
}

// Updates the chosen list, the header, the button and the preview.
simulated function RefreshSide()
{
	PopulateChosen();
	if (bChoosingOrigins)
	{
		SetHeader(strOriginsTitle, Repl(Repl(strProgress, "%N", string(ChosenOrigins.Length)), "%COUNT", string(GetOriginCount())));
	}
	else
	{
		SetHeader(strSpecsTitle, Repl(Repl(strProgress, "%N", string(Chosen.Length)), "%COUNT", string(class'USLW_Specs'.static.GetSpecCount())));
	}
	if (ConfirmButton != none)
	{
		ConfirmButton.SetText((bChoosingOrigins || GetOriginCount() == 0) ? strConfirm : strNext);
		ConfirmButton.SetDisabled(!IsStepFull());
	}
	UpdatePreview(List.SelectedIndex);
}

simulated function GetItems()
{
	local USLW_Spec Spec;
	local SoldierClassAbilityType Ability;
	local X2AbilityTemplate AbilityTemplate;
	local Commodity Item;
	local int i;

	arrItems.Length = 0;
	if (bChoosingOrigins)
	{
		OriginCandidates.Length = 0;
		foreach OriginPool(Ability)
		{
			if (!class'USLW_Specs'.static.SpecsHaveAbility(Chosen, Ability.AbilityName)
				&& class'USLW_Specs'.static.CanUseOrigin(Chosen, Ability.AbilityName))
			{
				OriginCandidates.AddItem(Ability);
			}
		}
		foreach OriginCandidates(Ability)
		{
			AbilityTemplate = class'USLW_Specs'.static.FindAbility(Ability.AbilityName);
			Item.Title = AbilityTemplate.LocFriendlyName;
			Item.Image = AbilityTemplate.IconImage;	// drawn by the row as an icon, see PopulateData
			Item.Desc = AbilityTemplate.GetMyLongDescription();
			arrItems.AddItem(Item);
		}
		return;
	}

	Candidates.Length = 0;
	foreach AllSpecs(Spec)
	{
		for (i = 0; i < Candidates.Length && SortsBefore(Candidates[i], Spec); i++) {}
		Candidates.InsertItem(i, Spec);
	}
	foreach Candidates(Spec)
	{
		Item.Title = class'USLW_Specs'.static.GetSpecTitle(Spec.ClassName, Spec.Column);
		Item.Image = class'USLW_Specs'.static.FindClass(Spec.ClassName).IconImage;
		Item.Desc = class'USLW_Specs'.static.FindClass(Spec.ClassName).ClassSummary;
		arrItems.AddItem(Item);
	}
}

simulated function bool SortsBefore(USLW_Spec A, USLW_Spec B)
{
	local string NameA, NameB;

	NameA = class'USLW_Specs'.static.FindClass(A.ClassName).DisplayName;
	NameB = class'USLW_Specs'.static.FindClass(B.ClassName).DisplayName;
	return NameA < NameB || (NameA == NameB && A.Column < B.Column);
}

simulated function PopulateData()
{
	local int i;

	List.ClearItems();
	List.bSelectFirstAvailable = false;
	for (i = 0; i < arrItems.Length; i++)
	{
		Spawn(class'UIInventory_USLW_ListItem', List.itemContainer).InitUSLWItem(arrItems[i], "", strChoose, bChoosingOrigins ? arrItems[i].Image : "");
	}
	if (List.ItemCount > 0)
	{
		List.SetSelectedIndex(0);
		List.Navigator.SetSelected(List.GetItem(0));
	}
}

simulated function PopulateChosen()
{
	local SoldierClassAbilityType Ability;
	local string Title;
	local int i;

	if (ChosenList == none)
	{
		return;
	}
	ChosenList.ClearItems();
	for (i = 0; i < Chosen.Length; i++)
	{
		Title = class'USLW_Specs'.static.GetSpecTitle(Chosen[i].ClassName, Chosen[i].Column);
		AddChosenRow(i == 0 ? class'UIUtilities_Text'.static.GetColoredText(Title, eUIState_Warning) : Title, bChoosingOrigins);
	}
	foreach ChosenOrigins(Ability)
	{
		AddChosenRow(class'USLW_Specs'.static.FindAbility(Ability.AbilityName).LocFriendlyName, false);
	}
}

simulated function AddChosenRow(string Text, bool bLocked)
{
	local UIListItemString Row;

	Row = Spawn(class'UIListItemString', ChosenList.ItemContainer);
	Row.InitListItem(Text);
	if (bLocked)
	{
		Row.SetDisabled(true);
	}
}

// Specializations are locked while origins are chosen; Back unlocks them.
simulated function OnChosenClicked(UIList ContainerList, int ItemIndex)
{
	if (!bChoosingOrigins && ItemIndex >= 0 && ItemIndex < Chosen.Length)
	{
		Chosen.Remove(ItemIndex, 1);
	}
	else if (bChoosingOrigins && ItemIndex >= Chosen.Length && ItemIndex - Chosen.Length < ChosenOrigins.Length)
	{
		ChosenOrigins.Remove(ItemIndex - Chosen.Length, 1);
	}
	else
	{
		return;
	}
	RealizeRows();
	RefreshSide();
}

simulated function SelectedItemChanged(UIList ContainerList, int ItemIndex)
{
	UpdatePreview(ItemIndex);
}

// Lays out the highlighted entry's abilities as icons and describes the first.
simulated function UpdatePreview(int ItemIndex)
{
	local USLW_Spec Spec;
	local UIUSLW_AbilityIcon Icon;
	local int i;

	if (PreviewGrid == none)
	{
		return;
	}
	foreach PreviewIcons(Icon)
	{
		Icon.Remove();
	}
	PreviewIcons.Length = 0;

	if (bChoosingOrigins && ItemIndex >= 0 && ItemIndex < OriginCandidates.Length)
	{
		AddPreviewIcon(OriginCandidates[ItemIndex].AbilityName, "", false);
	}
	else if (!bChoosingOrigins && ItemIndex >= 0 && ItemIndex < Candidates.Length)
	{
		Spec = Candidates[ItemIndex];
		// The shared squaddie abilities only come with the primary specialization.
		for (i = 0; i < Spec.CoreAbilities.Length && (Chosen.Length == 0 || IsSameSpec(Chosen[0], Spec)); i++)
		{
			AddPreviewIcon(Spec.CoreAbilities[i].AbilityName, class'X2ExperienceConfig'.static.GetShortRankName(1, class'USLW_Specs'.const.CLASS_NAME), true);
		}
		for (i = 0; i < Spec.RankAbilities.Length; i++)
		{
			AddPreviewIcon(Spec.RankAbilities[i].AbilityName, class'X2ExperienceConfig'.static.GetShortRankName(i + 1, class'USLW_Specs'.const.CLASS_NAME), false);
		}
	}

	if (PreviewIcons.Length > 0)
	{
		OnPreviewHover(PreviewIcons[0]);
	}
	else
	{
		Preview.SetHTMLText("");
	}
}

simulated function AddPreviewIcon(name AbilityName, string RankLabel, bool bPrimaryOnly)
{
	local X2AbilityTemplate AbilityTemplate;
	local UIUSLW_AbilityIcon Icon;
	local int Index;

	AbilityTemplate = class'USLW_Specs'.static.FindAbility(AbilityName);
	if (AbilityTemplate == none || AbilityTemplate.LocFriendlyName == "")
	{
		return;
	}
	Index = PreviewIcons.Length;
	Icon = Spawn(class'UIUSLW_AbilityIcon', PreviewGrid);
	Icon.InitAbilityIcon(AbilityName, RankLabel, bPrimaryOnly, AbilityTemplate);
	Icon.SetPosition((Index % ICONS_PER_ROW) * ICON_STEP_X, (Index / ICONS_PER_ROW) * ICON_STEP_Y);
	Icon.OnHover = OnPreviewHover;
	PreviewIcons.AddItem(Icon);
}

// Shows the hovered ability's name, rank and description under the icons.
simulated function OnPreviewHover(UIUSLW_AbilityIcon Icon)
{
	local X2AbilityTemplate AbilityTemplate;
	local string Title;

	AbilityTemplate = class'USLW_Specs'.static.FindAbility(Icon.AbilityName);
	if (AbilityTemplate == none)
	{
		return;
	}
	Title = class'UIUtilities_Text'.static.GetColoredText(AbilityTemplate.LocFriendlyName, eUIState_Header, 28);
	if (Icon.RankLabel != "")
	{
		Title $= "  " $ class'UIUtilities_Text'.static.GetColoredText(Icon.RankLabel, eUIState_Normal, 22);
	}
	if (Icon.bPrimaryOnly)
	{
		Title $= "  " $ class'UIUtilities_Text'.static.GetColoredText(strPrimaryOnly, eUIState_Warning, 22);
	}
	Preview.SetHTMLText(Title $ "\n<font size='" $ DESCRIPTION_FONT_SIZE $ "'>" $ AbilityTemplate.GetMyLongDescription() $ "</font>");
}

simulated function bool CanAffordItem(int ItemIndex)
{
	return !IsStepFull() && !IsItemPurchased(ItemIndex)
		&& ItemIndex >= 0 && ItemIndex < (bChoosingOrigins ? OriginCandidates.Length : Candidates.Length);
}

// Once the step is full the remaining entries are disabled too; RealizeDisabledState
// reads this and IsItemPurchased.
simulated function bool MeetsItemReqs(int ItemIndex)
{
	return !IsStepFull();
}

// Chosen entries stay in the left list, disabled; RealizeDisabledState reads this.
simulated function bool IsItemPurchased(int ItemIndex)
{
	local USLW_Spec Spec;

	if (bChoosingOrigins)
	{
		return ItemIndex >= 0 && ItemIndex < OriginCandidates.Length
			&& ChosenOrigins.Find('AbilityName', OriginCandidates[ItemIndex].AbilityName) != INDEX_NONE;
	}
	if (ItemIndex < 0 || ItemIndex >= Candidates.Length)
	{
		return false;
	}
	foreach Chosen(Spec)
	{
		if (IsSameSpec(Spec, Candidates[ItemIndex]))
		{
			return true;
		}
	}
	return false;
}

simulated function bool IsSameSpec(USLW_Spec A, USLW_Spec B)
{
	return A.ClassName == B.ClassName && A.Column == B.Column;
}

// Updates which rows of the left list can be chosen, without rebuilding them.
simulated function RealizeRows()
{
	local int i;

	for (i = 0; i < List.ItemCount; i++)
	{
		RealizeRow(i);
	}
}

// A row's bad state hides its button and follows CanAffordItem; its disabled state
// follows MeetsItemReqs and IsItemPurchased. Both are set when the row is built, so
// both are realized again whenever a choice changes them.
simulated function RealizeRow(int Index)
{
	local UIInventory_ListItem Row;

	Row = UIInventory_ListItem(List.GetItem(Index));
	if (Row != none)
	{
		Row.RealizeBadState();
		Row.RealizeDisabledState();
	}
}
simulated function OnPurchaseClicked(UIList kList, int ItemIndex)
{
	if (!CanAffordItem(ItemIndex))
	{
		PlayNegativeSound();
		return;
	}
	if (bChoosingOrigins)
	{
		ChosenOrigins.AddItem(OriginCandidates[ItemIndex]);
	}
	else
	{
		Chosen.AddItem(Candidates[ItemIndex]);
	}
	// Filling the step disables every row, otherwise only the chosen one changes.
	if (IsStepFull())
	{
		RealizeRows();
	}
	else
	{
		RealizeRow(ItemIndex);
	}
	RefreshSide();
}

simulated function OnConfirmButton(UIButton Button)
{
	if (!IsStepFull())
	{
		PlayNegativeSound();
		return;
	}
	if (!bChoosingOrigins && GetOriginCount() > 0)
	{
		bChoosingOrigins = true;
		Refresh();
		return;
	}
	Commit();
}

simulated function Commit()
{
	local XComGameState NewGameState;
	local XComGameState_Unit Unit;
	local array<USLW_SpecRef> Refs;
	local USLW_SpecRef Ref;
	local USLW_Spec Spec;

	foreach Chosen(Spec)
	{
		Ref.ClassName = Spec.ClassName;
		Ref.Column = Spec.Column;
		Refs.AddItem(Ref);
	}
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("USLW choose specializations");
	Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
	if (class'USLW_Specs'.static.ApplySpecs(Unit, Refs, ChosenOrigins, NewGameState))
	{
		`GAMERULES.SubmitGameState(NewGameState);
	}
	else
	{
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
	}
	CloseScreen();
	class'UIPanel_USLW'.static.RefreshArmory(UnitRef);
}

simulated function OnCancel()
{
	if (bChoosingOrigins)
	{
		bChoosingOrigins = false;
		ChosenOrigins.Length = 0;
		Refresh();
		return;
	}
	CloseScreen();
}

simulated function OnCancelButton(UIButton kButton)
{
	OnCancel();
}

simulated function UpdateNavHelp()
{
	local UINavigationHelp NavHelp;

	NavHelp = `HQPRES.m_kAvengerHUD.NavHelp;
	NavHelp.ClearButtonHelp();
	NavHelp.AddBackButton(OnCancel);
	if (`ISCONTROLLERACTIVE)
	{
		NavHelp.AddSelectNavHelp();
	}
}

defaultproperties
{
}
