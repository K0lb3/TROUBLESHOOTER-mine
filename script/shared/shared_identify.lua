-------------------------------------------------------------
-- 강화 가능한지 여부.
-------------------------------------------------------------
function IsEnableIdentifyItem(item, company)

	local reason = {};
	local itemList = GetClassList('Item');
	local identifyList = GetClassList('Identify');
	local itemIdentifyTypeList = GetClassList('ItemIdentifyType');
	local isEnable = true;	
	local eanbleUpgradeCount = 99999999;

	local itemList = GetClassList('Item');	
	-- 유효 데이터 처리
	if not item then
		return false, reason;
	end
	
	-- 1. 옵션이 있는가?	
	if not item.Category.IsIdentify then
		table.insert(reason, 'DisableIdentifyItem');
		isEnable = false;
	end 
	-- 2. 아이템 감정 랭크
	if item.Rank.Weight == 1 then
		table.insert(reason, 'RankPoor');
		isEnable = false;
	end
	-- 3. 감정 가능 카테고리가 맞는가.
	local identifyType = identifyList[item.Category.name];
	if not identifyType  or identifyType.name == nil then
		table.insert(reason, 'BadIdentifyCateogy');
		isEnable = false;
	end	
	-- 4. 이미 옵션이 붙은 아이템인가.	
	if item.Option.OptionKey ~= 'None' then
		table.insert(reason, 'AlreadyOptioned');
		isEnable = false;
	end
	-- 5. 감정 불가 아이템인가
	if not item.Rank.Identifiable then
		table.insert(reason, 'NotIdentifiableItem');
		isEnable = false;
	end
	-- 6. 옵션 그룹이 있는가.
	local itemOptionGroup = itemIdentifyTypeList[item.Type.name];
	if not itemOptionGroup then
		table.insert(reason, 'NoItemOptionGroup');
		isEnable = false;
	end
	-- 7. 돈이 있는가?
	if company and company.Vill < item.IdentifyPrice then
		table.insert(reason, 'NotEnoughVill');
		isEnable = false;
	end
	return isEnable, reason;
end
----------------------------------------------------
-- 아이템 감정시 옵션 가져오는 함수.
-----------------------------------------------------
function GetIdentifyItemOptions(item)
	local itemIdentifyTypeList = GetClassList('ItemIdentifyType');
	local itemIdentifyList = GetClassList('ItemIdentify');
	local itemOptionGroup = itemIdentifyTypeList[item.Type.name];
	
	local picker = RandomPicker.new();
	for key, value in pairs (itemOptionGroup.Options) do
		local curItemOptionType = itemIdentifyList[key];
		if curItemOptionType then
			local optionCounts = #curItemOptionType.IdentifyOptions;
			if item.Rank.OptionMaxCount >= optionCounts and item.Rank.OptionMinCount <= optionCounts then
				picker:addChoice(curItemOptionType.Prob, curItemOptionType);
			end
		else
			LogAndPrint(string.format('[Error] %s Option Group not exist on ItemIdentify.xml', key));
		end	
	end
	local curOption, index = picker:pick();
	return curOption;
end
function GetRandomValueInUniformDistribution(min, max, precision)
	if precision == nil or precision == 'Int' then
		return math.random(math.floor(min), math.floor(max));
	elseif precision == 'Percent' then
		return math.random(math.floor(min * 100), math.floor(max * 100)) / 100;
	end
end
function GetIdentifyItemOptionValue(identifyOption, luck)
	if not identifyOption then
		return {};
	end
	if not luck then
		luck = 0;
	end
	local statusList = GetClassList('Status');
	
	local list = {};	
	-- 1. 기본 랜덤 분배
	local totalPickValue = 0;
	local optionCount = #identifyOption.IdentifyOptions;
	for index, status in ipairs (identifyOption.IdentifyOptions) do
		local curValue = nil;
		local statusCls = statusList[status.Type];
		if statusCls.name == nil or statusCls.name == 'None' then
			LogAndPrint('Not Exist Status - IdentifyOption : ', identifyOption.name, ', Status : ', status.Type);
		end
		if statusCls.Format == 'Percent' then
			curValue = GetRandomValueInUniformDistribution(status.Min, status.Max, 'Percent');
		else
			curValue = GetRandomValueInUniformDistribution(status.Min, status.Max, 'Int');
		end
		local rangeValue = status.Max - status.Min;
		local pickValue = (curValue - status.Min) / rangeValue; 
		if rangeValue == 0 then
			pickValue = 1;
		end
		totalPickValue = totalPickValue + pickValue;		
		local curList = { Type = status.Type, Value = curValue, PickValue = pickValue, RangeValue = rangeValue, Max = status.Max, Min = status.Min};
		table.insert(list, curList);
	end
	-- 2. 옵션 선택이 40%를 넘지 않으면 보너스 기회를 주자.
	local reTry = 0;
	local originalList = nil;
	local averagePickValue = totalPickValue/optionCount;
	while ( averagePickValue < 0.4 + luck * 0.005 ) do
		if not originalList and averagePickValue > 0.4 then
			originalList = list;
		end
		local reTotalPickValue = 0;
		for index, option in ipairs (list) do
			if statusList[option.Type].Format == 'Percent' then
				option.Value = GetRandomValueInUniformDistribution(option.Value, option.Max, 'Percent');
			else
				option.Value = GetRandomValueInUniformDistribution(option.Value, option.Max, 'Int');
			end			
			option.PickValue = (option.Value - option.Min) / option.RangeValue;
			if option.RangeValue == 0 then
				option.PickValue = 1;
			end
			reTotalPickValue = reTotalPickValue + option.PickValue;
		end
		reTry = reTry + 1;
		averagePickValue = reTotalPickValue/optionCount;
		if reTry > 10 then
			break;
		end
	end
	-- 90%이상이 아니면 기존값대로.
	if originalList and averagePickValue < 0.9 then
		list = originalList;
	end
	return list, averagePickValue;
end

----------------------------------------------------------------
-- 감정시 획득하는 숙련도 포인트
---------------------------------------------------------------
function GetIdentifyWorkmanShipPoint(itemWeight)
	return itemWeight;
end
function GetIdentifyItemPrice(item, friendship, reputation)
	-- Npc 할인율
	local discountRatio = GetNpcDiscountRatio(friendship, reputation);
	
	return math.max(1, math.floor(item.IdentifyPrice * (1 - discountRatio)));
end