------------------------------------------------------------------------
-- CP
------------------------------------------------------------------------
function CalculatedProperty_Recipe_AdditionalCraftExpRatio(recipe, arg)
	local result = 0;
	local itemList = GetClassList('Item');
	if not itemList[recipe.name] then
		return result;
	end
	local professionList = GetClassList('Profession');
	local item = itemList[recipe.name];
	local curProfession = professionList[recipe.Category];
	if not curProfession then
		return result;
	end
	result = math.max(2, 0.5 * curProfession.AddExpRatio * ( math.floor(item.RequireLv/5) + item.Rank.Weight));
	result = math.floor(result*100)/100;
	return result;
end