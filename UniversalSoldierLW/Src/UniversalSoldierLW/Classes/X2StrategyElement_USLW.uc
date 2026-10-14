class X2StrategyElement_USLW extends X2StrategyElement;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;
	local X2USLWDataTemplate Template;

	`CREATE_X2TEMPLATE(class'X2USLWDataTemplate', Template, 'USLW_Data');
	Templates.AddItem(Template);
	return Templates;
}
