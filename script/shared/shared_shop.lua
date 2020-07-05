----------------------------------------------------------------
-- 아이템 상점
---------------------------------------------------------------
function SampleShopItemOption(identifyOption)
	if not identifyOption then
		return {};
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
	-- 2. 옵션 선택이 55% ~ 85% 를 넘지 않으면 보너스 기회를 주자.
	local reTry = 0;
	local averagePickValue = totalPickValue/optionCount;
	while ( averagePickValue < 0.65 or averagePickValue > 0.95 ) do
		local reTotalPickValue = 0;
		for index, option in ipairs (list) do
			local minValue = option.Value;
			local maxValue = option.Max;
			if averagePickValue > 0.95 then
				minValue = (option.Min + option.Value)/2;
				maxValue = option.Value;		
			end		
			if statusList[option.Type].Format == 'Percent' then
				option.Value = GetRandomValueInUniformDistribution(minValue, maxValue, 'Percent');
			else
				option.Value = GetRandomValueInUniformDistribution(minValue, maxValue, 'Int');
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
	return list, averagePickValue;
end
function BuildFakeItemOption(optionKey, optionList)
	local ret = {};
	ret.OptionKey = optionKey;
	ret.Ratio = 0;
	for index, status in ipairs (optionList) do
		ret['Type' .. index] = status.Type;
		ret['Value' .. index] = status.Value;
	end
	return ret;
end