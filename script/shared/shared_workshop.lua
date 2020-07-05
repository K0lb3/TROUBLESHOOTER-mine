-- 아이템 개수에 따른 비용 결정 함수 --
--- 제조 확률 구하는 함수 ---
function GetCraftProbability(company, recipeCls)
	local baseProbability = recipeCls.Result;
	local common = 0;
	local uncommon = 0;
	local rare = 0;
	local legend = 0;
	
	for i = 1, #baseProbability do
		if baseProbability[i].Rank == 'Common' then
			common = baseProbability[i].Probability;
		elseif baseProbability[i].Rank == 'Uncommon' then
			uncommon = baseProbability[i].Probability;
		elseif baseProbability[i].Rank == 'Rare' then
			rare = baseProbability[i].Probability;
		elseif baseProbability[i].Rank == 'Legend' then
			legend = baseProbability[i].Probability;
		end
	end

	-- 담당자에 의한 확률 변경  부분 추가 예정
	return common, uncommon, rare, legend;
	
	-- 제안
	--[[
	local possibleTable = {};
	setmetatable(possibleTable, {__index = function(t, k) return 0 end});
	for i = 1, #baseProbability do
		possibleTable[baseProbability[i].Rank] = baseProbability[i].Probability;
	end
	return possibleTable.Common, possibleTable.UnCommon, possibleTable.Rare, possibleTable.Legend;
	]]
end

function IsEnableResearchItem(company, item, quality, research, production, quantity)
	-- 테스트 항목
	--[[
		1. 연구옵션 적합성 체크
		2. 연구 가능 아이템 여부 체크
		3. 비용 체크 (있나?)
	]]
	
	-- 연구옵션 적합성 체크
	-- * 각 옵션 항목은 1~3 사이어야 함수
	-- * quality + quantity == 4, research + production == 4 여야함
	if quality < 1 or quality > 3
		or quantity < 1 or quantity > 3
		or research < 1 or research > 3
		or production < 1 or production > 3 then
		return false, 'Research Option is Invalid, value out of range';
	end
	
	if quality + quantity ~= 4
		or research + production ~= 4 then
		return false, 'Research Option is Invalid, value sum missmatched';
	end

	
	-- 연구 가능 아이템 여부 체크
	-- 보드 장착이나 뭐 런거 체크하면 될듯
	
	return true;
end
----------- 아이템 연구의 가치(기술집약도)를 결정하는 함수 ----------
function GetTechPointItem(curItem)
	local result = 10;
	-- 요구 레벨 추가값(고레벨무기) --
	result = result + curItem.RequireLevel * 10;
	-- 전력 소켓값 
	result = result + math.floor(curItem.MaxPowerCapacity/10);
    -- 소켓 칩 계산하기(적용해야함)
	return result;
end
------- 획득 RP 구하는 함수 -------
function GetResearchPointFromtechPoint(techPoint, researchGrade)
	local result = math.floor(techPoint/10);
	--- 연구 개발 그레이드에 따른 포인트 획득률 ---
	result = result * researchGrade * 0.5;
	result = math.min(999, math.floor(result));
	return result;
end
------- 연구시 아이템 보상 및 확률 예상 목록 리스트  ------
function GetExpectedRewardByResearch(item, quality, production, techPoint)
    local rewardList = {};
	local totalProbability = 100;
	local materyPoint = 1;
	-- 고급 보상은 기본 1
	-- 기술집약도에 따라 최대 4증가
	-- 고급 보상 목록은 
	local rareRewardCount = 1 + ( quality - 2) + materyPoint;
	rareRewardCount = math.max(0, math.min( 5, rareRewardCount));
	local output = GetClassList('ItemResearch')[item.Category.name].Output;
	for i = 1, #output do
		if techPoint >= output[i].TechPoint and techPoint < output[i + 1].TechPoint then
			for j = 1, rareRewardCount do
				local itemName = output[i][string.format('ItemName%d', j)];
				local itemProbability = 1 + production/rareRewardCount;
				totalProbability = totalProbability - itemProbability;
				local list = {
					Type = 'Rare',
					Name = itemName,
					Probability = itemProbability
				};
				table.insert(rewardList, list);
			end
		end
	end
	
	-- 일반 보상은 고정 --
	-- 아이템의 장착되어 있는 현재 칩이 고정 보상이 된다. 최대 10개 --
	--- 장착된 칩들의 속성과 등급에 따라 아이템 배분 ---
	-- 테스트용 ---
	local normalItemList = {
		'StormDust', 'MistDust', 'VendureDust', 'DarkDust', 'FlameFragment', 'FrostFragment', 'FlashFragment', 'StormFragment', 'MistFragment', 'VendureFragment'
	};
	for k = 1, #normalItemList do
		local normalList = {
			Type = 'Normal',
			Name = normalItemList[k],
			Probability = totalProbability/#normalItemList;
		};
		table.insert(rewardList, normalList);
	end
	return rewardList;
end
------- 획득 가능 아이템 개수 결정  ------
function GetExpectedRewardCountByResearch(quantityGrade, techPoint)
    -- 기본 아이템 보상 개수 2
	local result = 2;
	-- 기술집약도 500 당 1 증가
	result = result + math.floor(techPoint/500);
	-- 다이어그램 값 반영
	result = result + ( quantityGrade - 2);
	result = math.max(1, math.min(10, result));
	return result;
end
--- 기타 워크샵 개발 관련 공유 함수
function Calc_RecipeNeedTechnique(self)
	local recipeName = self.name;
	local techClsList = GetClassList('Technique');
	for technique, techniqueCls in pairs(techClsList) do
		for i, unlock in ipairs(techniqueCls.Unlock) do
			if unlock.Type == 'Recipe' and unlock.Target == recipeName then
				return technique;
			end
		end
	end
	-- 열어주는 기술이 없음.. 이경우는 실수 예방차원에서 막는것이 좋을듯
	return nil;
end
-- 개발용 더미함수. 
function Calc_RecipeNeedTechniqueDummy(self)
	local properAnswer = Calc_RecipeNeedTechnique(self);
	if properAnswer == nil then
		return 'None';
	else
		return properAnswer;
	end
end
function GetRecipeRewardItemBase(self, rank)
	for i, result in ipairs(self.Result) do
		if result.Rank == rank then
			return result.ItemName;
		end
	end
	return nil;
end
function Calc_RecipeMaterialBoard(self)
	local itemClsList = GetClassList('Item');
	for i, material in ipairs(self.Material) do
		local itemCls = itemClsList[material.ItemName];
		if itemCls.Type == 'Board' then
			return GetClassList('BoardType')[itemCls.name];
		end
	end
	return nil;
end
---- 칩 장착시 소모 연구 포인트 계산 ----
function GetNeedResearchPointForUpgrade(item, chip)
	local result = 0;
	local rankBonus = 0;
	if chip.Rank == 'Uncommon' then
		rankBonus = 25;
	elseif chip.Rank == 'Rare' then
		rankBonus = 50;
	elseif chip.Rank == 'Legend' then
		rankBonus = 100;
	end
	result = item.PowerCapacity + item.MaxPowerCapacity + chip.ConsumePower + rankBonus;
	return result;
end

function GetItemCoreState(circuit, slotType)
	local boardCls = GetClassList('BoardType')[circuit.BoardType];
	local state = {Opened = false, ChipType='None', Chip = 'None'}
	if boardCls == nil or not boardCls[slotType] then
		return state;
	end
	state.Opened = true;
	state.ChipType = circuit[slotType].ChipType;
	state.Chip = circuit[slotType].Chip;
	return state;
end