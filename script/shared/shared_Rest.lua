function IsEnableRestAction(company, rosters, restAction, pc)
	local reason = {};
	local isEnable = true;	
	local rosterCount = #rosters;
	local fee = restAction.Vill * rosterCount;
	-- 1. 비용 검사
	if company.Vill < fee then
		isEnable = false;
		table.insert(reason, 'NotEnoughVill');
	end
	return isEnable, fee, reason;
end
function GetResultRestAction(restAction, pc)
	-- 1. 추가될 카운트 구하기.
	local addCount = restAction.AddCount;
	local applyEffective = 1.0;
	if restAction.Type == 'Satiety' or restAction.Type == 'Refresh' then
		local pcMaxCount = pc['Max'..restAction.Type];
		local pcCurCount = pc['GetEstimated' .. restAction.Type](pc);
		if restAction.AddCount + pcCurCount > pcMaxCount then
			applyEffective = math.clamp(pcMaxCount / pcCurCount, 0.5, 1);
		end
	end
	
	-- 2. 현재 CP 구하기.
	local minCP = restAction.AddMinCP;
	local maxCP = restAction.AddMaxCP;
	local ratio = pc.Rest[restAction.Type..'Ratio'];
	minCP = math.floor(minCP * ratio/100);
	maxCP = math.floor(maxCP * ratio/100);
	local resultCP = math.random(minCP, maxCP) * applyEffective;
	resultCP = math.floor(resultCP);
	-- 3. 리액션 구하기.
	local isFullCP = false;
	local interval = maxCP - minCP;
	local range = resultCP - minCP;
	local gradeRatio = range/interval * 100;
	
	local curReaction = pc.Rest.Reaction[restAction.name].ActionType;
	
	local category = 'None';
	if resultCP < 0 or applyEffective < 1.0 then
		category = 'Bad';
	else
		category = 'Good';
	end
	return resultCP, addCount, category;
end
function GetFoodRestAction(pc, amount_Condition, curOrderList)
	local resultCP = amount_Condition;
	local minusCP = 0;
	local dishList, drinkList = table.split(curOrderList, function(food) return food.Type.name ~= 'Beverage' end);
	-- 포만감 최대, 요리 섭취에 따른 CP 페널티
	if pc.Satiety >= pc.MaxSatiety and #dishList > 0 then
		for _, food in ipairs(dishList) do
			minusCP = minusCP + math.floor(food.CP * math.random(25, 50) / 100);
		end
	end
	-- 청량감 최대, 음료 섭취에 따른 CP 페널티
	if pc.Refresh >= pc.MaxRefresh and #drinkList > 0 then
		for _, food in ipairs(drinkList) do
			minusCP = minusCP + math.floor(food.CP * math.random(25, 50) / 100);
		end
	end
	-- CP 페널티가 있으면 덮었씀
	if minusCP > 0 then
		resultCP = -minusCP;
	end
	local category = 'None';
	if resultCP < 0 then
		category = 'Bad';
	else
		category = 'Good';
	end
	return resultCP, category;
end