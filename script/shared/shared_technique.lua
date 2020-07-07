---------------------------------------------------------------------
--- 특성연구 테스트.
---------------------------------------------------------------------
function IsEnableTechniqueResearch(company, tech, addMasteries, itemCounter, count)

	local techniquList = GetClassList('Technique');
	local masteryList = GetClassList('Mastery');
	
	local isEnable = true;
	local reason = {};	
	local favoriteMasteries = {};
	
	local curTechniqueMastery = company.Technique[tech.name];

	local list = {};
	local set = {};
	local itemList = {};
	if tech.Type == 'Mastery' then
		for key, value in pairs (tech.RequireMasteries) do
			set[key] = true;
			table.insert(list, key);
		end
	elseif tech.Type == 'Module' then
		for _, itemData in ipairs(tech.RequireItems) do
			itemList[itemData.Item] = (itemList[itemData.Item] or 0) + itemData.Count;
		end
	end
	for index, value in ipairs (addMasteries) do
		if value.MasteryName then
			set[value.MasteryName] = true;
			table.insert(list, value.MasteryName);
		end
	end
	table.sort(list);
	
	-- 1. 제작 가능한 마스터리인가.
	if not curTechniqueMastery or not curTechniqueMastery.Opened then
		isEnable = false;
		table.insert(reason, 'DisableTechnique');
	end	
	-- 2. 회사에 다음 마스터리들이 존재하는지 체크.
	for i = 1, #list do
		local curMastery = company.Mastery[list[i]];
		if curMastery.Amount < count then
			isEnable = false;
			table.insert(reason, 'NotEnoughMasteryCount');
			break;
		end
		if curMastery.Favorite then
			table.insert(favoriteMasteries, curMastery);
		end
	end	
	-- 3. 총 스코어 보다 작은 문제.
	local addMasteryTotalCost = GetCurrentTechniqueAddMasteriesTotalPoints(company, addMasteries);
	if addMasteryTotalCost < tech.RequireCost then
		isEnable = false;
		table.insert(reason, 'LowCost');
	end
	
	-- 4. 중복된 마스터리가 존재하는가?
	local isDupliated = false;
	for i = 2, #list do
		if list[i-1] == list[i] then
			isDupliated = true;
			break;
		end
	end
	if isDupliated then
		isEnable = false;
		table.insert(reason, 'DupliatedMastery');	
	end

	-- 5. 연구와 같은 마스터리를 재료로 넣었는가?
	if set[tech.name] then
		isEnable = false;
		table.insert(reason, 'SameMasteryWithTechnique');
	end
	
	-- 6. 제작에 필요한 아이템이 충분한가
	for itemKey, needCount in pairs(itemList) do
		if itemCounter(itemKey) < needCount * count then
			isEnable = false;
			table.insert(reason, 'NotEnoughItemCount');
		end
	end
	return isEnable, list, reason, favoriteMasteries, itemList;
end
---------------------------------------------------------------------
--- 특성 연구 재료로 추가가능한지 여부.
---------------------------------------------------------------------
function IsEnableAddTechniqueMastery(company, tech, masteryName, slotInfo)

	local masteryList = GetClassList('Mastery');
	local curMastery = masteryList[masteryName];
	
	local isEnable = true;
	local reason = {};	

	local curMastery_company = company.Mastery[masteryName];
	
	local isSameMasteryEquiped = false;
	local isSameRequireMastery = false;
	local isFullSlot = true;
	local isEmptyCategorySlot = false;
	
	-- 0개인 마스터리 리스트를 제거해 준다.
	for index, slot in ipairs (slotInfo) do
		-- 마스터리가 있다.
		if slot.MasteryName then
			if company.Mastery[slot.MasteryName].Amount <= 0 then
				slot.MasteryName = nil;
			end
		end		
	end
	
	-- 0 - 1) 슬롯 검사
	for index, slot in ipairs (slotInfo) do
		if slot.MasteryName then
			if slot.MasteryName == masteryName then
				isSameMasteryEquiped = true;
			end
		else
			isFullSlot = false;
			if slot.Type == curMastery.Category.name then
				isEmptyCategorySlot = true;
			end
		end
	end
	-- 0 - 2) 필수 연구 재료 중복 검사.
	for key, mName in pairs (tech.RequireMasteries) do
		if key == masteryName then
			isSameRequireMastery = true;
		end
	end

	-- 2. 장착 가능한 슬롯이 없습니다.
	if isFullSlot then
		isEnable = false;
		table.insert(reason, 'FullSlot');
	end
	-- 3. 해당 타입의 장착 가능한 슬롯이 없습니다.
	if not isEmptyCategorySlot then
		isEnable = false;
		table.insert(reason, 'NotExistEmptyCategorySlot');		
	end
	-- 4. 이미 같은 특성이 존재합니다.
	if isSameMasteryEquiped then
		isEnable = false;
		table.insert(reason, 'SameMasteryEquiped');		
	end
	-- 5. 리콰이어 특성과 동일합니다.
	if isSameRequireMastery then
		isEnable = false;
		table.insert(reason, 'SameRequireMastery');		
	end
	-- 6. 마스터리 개수 검사	
	if not curMastery_company or curMastery_company.Amount <= 0 then
		isEnable = false;
		table.insert(reason, 'NotEnoughMasteryCount');
	end
	-- 7. 코스트 초과.
	local addMasteryTotalCost = GetCurrentTechniqueAddMasteriesTotalPoints(company, slotInfo);
	if addMasteryTotalCost + curMastery.Cost > tech.RequireCost then
		isEnable = false;
		table.insert(reason, 'OverCost');
	end
	-- 8. 연구 대상과 같은 마스터리
	if tech.name == masteryName then
		isEnable = false;
		table.insert(reason, 'SameMasteryWithTechnique');
	end
	return isEnable, reason;
end
---------------------------------------------------------------------
--- 보상 주는 함수.
---------------------------------------------------------------------
function ExecuteRewardTechnique(dc, company, curMasteryList)

	local reward = {};	
	local list = {};
	local totalCost = 0;
	local masteryList = GetClassList('Mastery');
	local rpPoint = 0;
	-- 1. 기본 추출 아이템 보상 넣기.(기술서)
	for i = 1, #curMasteryList do
		local masteryName = curMasteryList[i];
		local mastery = masteryList[masteryName];
		table.insert(list, { Type = 'Item', Prob = 10, Value = mastery.ExtractItem});
		totalCost = totalCost + mastery.Cost;
	end	
	-- 2. 연구 점수 보상 넣기.
	rpPoint = #curMasteryList + totalCost;
	rpPoint = math.max(1, math.floor(math.random(0.5 * rpPoint, rpPoint)));
	table.insert(list, { Type = 'ResearchPoint', Prob = 100, Value = rpPoint});
	
	-- 3. 새로운 특성 획득.
	SetMasteryFromTechnique(list, totalCost);
	
	local picker = RandomPicker.new();
	for index, value in ipairs (list) do
		picker:addChoice(value.Prob, value);
	end	
	return picker:pick();
end
-------------------------------------------------------------------------
-- 새로운 특성 연구
------------------------------------------------------------------------
function SetMasteryFromTechnique(list, totalCost)
	local techniqueMastery = GetClassList('TechniqueMastery');
	for key, value in pairs (techniqueMastery) do
		if totalCost > value.MinPoint then
			table.insert(list, { Type = 'Mastery', Prob = value.Prob, Value = key});
		end
	end
end
-------------------------------------------------------------------------
-- 특성 제작 필요 코스트 계산
------------------------------------------------------------------------
function CalculatedProperty_TechniqueRequireMaxCost(tech, arg)
	local result = 0;
	local masteryList = GetClassList('Mastery');
	for key, value in pairs (tech.RequireMasteries) do
		local curMastery = masteryList[key];
		if curMastery and curMastery.name ~= nil then
			result = result + curMastery.Cost;
		end
	end
	result = result + tech.RequireCost;
	return result;
end
function CalculatedProperty_TechniqueRequireCost(tech, arg)
	local masteryList = GetClassList('Mastery');
	local result = 0;
	result = masteryList[tech.name].Cost;
	if tech.Type == 'Mastery' then
		result = result + math.floor(#tech.RequireMasteries * 1.5);
	else
		result = tech.RequireModuleCost;
	end
	return result;
end
-------------------------------------------------------------------------
-- 특성 현재 리스트 총점 구하는 공식.
------------------------------------------------------------------------
function GetCurrentTechniqueTotalPoints(company, tech, addMasteries)
	
	local masteryList = GetClassList('Mastery');
	
	local result = 0;
	local requireMasteryPoint = 0;
	local addMasteryPoint = GetCurrentTechniqueAddMasteriesTotalPoints(company, addMasteries);
	for key, value in pairs (tech.RequireMasteries) do
		local curMastery = company.Mastery[key];
		if curMastery and curMastery.name ~= nil then
			if curMastery.Amount > 0 then
				requireMasteryPoint = requireMasteryPoint + curMastery.Cost;
			end
		end
	end	
	result = requireMasteryPoint + addMasteryPoint;
	return result;
end
-------------------------------------------------------------------------
-- 특성 현재 리스트 값.
------------------------------------------------------------------------
function GetCurrentTechniqueAddMasteriesTotalPoints(company, addMasteries)
	
	local masteryList = GetClassList('Mastery');
	local result = 0;
	for index, value in ipairs (addMasteries) do
		if value.MasteryName then
			local curMastery = masteryList[value.MasteryName];
			if curMastery then
				local curMastery_Company = company.Mastery[value.MasteryName];
				if curMastery_Company and curMastery_Company.name ~= nil then
					if curMastery_Company.Amount > 0 then
						result = result + curMastery_Company.Cost;
					end
				end
			end
		end
	end
	return result;
end
-------------------------------------------------------------------------
-- 특성 슬롯 자동 구성.
------------------------------------------------------------------------
function GetCurrentTechniqueAddSlotData(tech)
	if tech.Type == 'Mastery' then
		return GetCurrentTechniqueAddSlotData_Mastery(tech);
	else
		return GetCurrentTechniqueAddSlotData_Module(tech);
	end
end
function GetCurrentTechniqueAddSlotData_Mastery(tech)
	if not tech.IsAutoSlot then
		-- 훈련서 예외 처리	
		-- 5종 슬롯을 준다.
		local list = {
			{ Type = 'Normal', MasteryName = nil},
			{ Type = 'Sub', MasteryName = nil},
			{ Type = 'Attack', MasteryName = nil},
			{ Type = 'Defence', MasteryName = nil},
			{ Type = 'Ability', MasteryName = nil},
		};		
		return list;
	end

	local masteryList = GetClassList('Mastery');
	local list = {};
	local requireCost = tech.RequireCost;
	local slotOrder = {'Normal', 'Sub', 'Attack', 'Defence', 'Ability'};
	local totalSlotData = {
		Normal = 0,
		Sub = 0,
		Attack = 0,
		Defence = 0,
		Ability = 0
	};
	local nextSlotData = {
		Normal = 1,
		Sub = 2,
		Attack = 3,
		Defence = 4,
		Ability = 5
	};
	
	-- 1,2 슬롯 만들기.
	local makeSlotCount = 1;
	local techMastery = masteryList[tech.name];
	local firstSlotName = techMastery.Category.name;
	totalSlotData[firstSlotName] = totalSlotData[techMastery.Category.name] + 1;	
	local orderRand = (nextSlotData[firstSlotName] + techMastery.Cost) % 5;
	if orderRand == 0 then
		orderRand = 5;
	end
	local secondSlotName = slotOrder[orderRand];
	totalSlotData[secondSlotName] = totalSlotData[secondSlotName] + 1;
	requireCost = requireCost - 2;
	makeSlotCount = makeSlotCount + 1;
	
	for key, rm in pairs (tech.RequireMasteries) do
		local curRm = masteryList[key];
		local curSlotName = curRm.Category.name;
		if requireCost > 0 and makeSlotCount < 5 then
			totalSlotData[curSlotName] = totalSlotData[curSlotName] + 1;
			requireCost = requireCost - 1.5;
			makeSlotCount = makeSlotCount + 1;
		else
			break;
		end
	end
	
	if makeSlotCount < 2 and requireCost > 0 then
		totalSlotData[firstSlotName] = totalSlotData[techMastery.Category.name] + 1;
	end

	-- 데이터 정리.
	for _, slotKey in ipairs(slotOrder) do
		local curSlotCount = totalSlotData[slotKey];
		for i = 1, curSlotCount do
			table.insert(list, { Type = slotKey, MasteryName = nil});
		end	
	end
	return list;
end
function GetCurrentTechniqueAddSlotData_Module(tech)
	if not tech.IsAutoSlot then
		-- 훈련서 예외 처리	
		-- 5종 슬롯을 준다.
		local list = {
			{ Type = 'FrameModule', MasteryName = nil},
			{ Type = 'SupportModule', MasteryName = nil},
			{ Type = 'ComplementaryModule', MasteryName = nil},
			{ Type = 'SaftyModule', MasteryName = nil},
			{ Type = 'AIModule', MasteryName = nil},
		};		
		return list;
	end

	local masteryList = GetClassList('Mastery');
	local list = {};
	local requireCost = tech.RequireCost;
	local slotOrder = {'FrameModule', 'SupportModule', 'ComplementaryModule', 'SaftyModule', 'AIModule'};
	local totalSlotData = {
		FrameModule = 0,
		SupportModule = 0,
		ComplementaryModule = 0,
		SaftyModule = 0,
		AIModule = 0
	};
	local nextSlotData = {
		FrameModule = 1,
		SupportModule = 2,
		ComplementaryModule = 3,
		SaftyModule = 4,
		AIModule = 5
	};
	
	-- 1,2 슬롯 만들기.
	local makeSlotCount = 1;
	local techMastery = masteryList[tech.name];
	local firstSlotName = techMastery.Category.name;
	totalSlotData[firstSlotName] = totalSlotData[techMastery.Category.name] + 1;	
	local orderRand = (nextSlotData[firstSlotName] + techMastery.Cost) % 5;
	if orderRand == 0 then
		orderRand = 5;
	end
	local secondSlotName = slotOrder[orderRand];
	totalSlotData[secondSlotName] = totalSlotData[secondSlotName] + 1;
	requireCost = requireCost - 2;
	makeSlotCount = makeSlotCount + 1;
	
	for key, rm in pairs (tech.RequireMasteries) do
		local curRm = masteryList[key];
		local curSlotName = curRm.Category.name;
		if requireCost > 0 and makeSlotCount < 5 then
			totalSlotData[curSlotName] = totalSlotData[curSlotName] + 1;
			requireCost = requireCost - 1.5;
			makeSlotCount = makeSlotCount + 1;
		else
			break;
		end
	end
	
	if makeSlotCount < 2 and requireCost > 0 then
		totalSlotData[firstSlotName] = totalSlotData[techMastery.Category.name] + 1;
	end

	-- 데이터 정리.
	for _, slotKey in ipairs(slotOrder) do
		local curSlotCount = totalSlotData[slotKey];
		for i = 1, curSlotCount do
			table.insert(list, { Type = slotKey, MasteryName = nil});
		end	
	end
	return list;
end