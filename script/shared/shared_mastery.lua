-----------------------------------------------------------------------------------
------------------------- 특성 습득 체크 함수 -------------------------------------
-----------------------------------------------------------------------------------
-- return type : possible(가능여부), consumePoint(소모TP), errorMsg(왜 안되는지) --
-----------------------------------------------------------------------------------
function MasteryTrainingTest(pc, company, masteryTable, masteryName)
	local isEnable = true;
	local needPoint = 0;
	local reason = {};
	
	local masteryList = GetClassList('Mastery');
	local mastery = masteryList[masteryName];

	-- 1. PC, Company 존재하는지 여부 체크.
	if company == nil or pc == nil then
		LogAndPrint('[Error] Mastery CostOwner not exist!!');
		return false, 0, { 'CostOwnerNotExist' };
	end	
	-- 2. 마스터리 조건 체크
	isEnable, reason = IsEnableMasterRosterMastery(company, pc, mastery, masteryTable);
	return isEnable, reason;
end
-----------------------------------------------------------------------------------
------------------------- 특성 추출 함수 -------------------------------------
-----------------------------------------------------------------------------------
function MasteryExtractTest(pc, company, masteryTable, masteryName, itemCounter)
	local isEnable = true;
	local needPoint = 0;
	local reason = {};
	
	local masteryList = GetClassList('Mastery');
	local mastery = masteryList[masteryName];

	-- 1. PC, Company 존재하는 지여부 체크.
	if company == nil or pc == nil then
		LogAndPrint('[Error] Mastery CostOwner not exist!!');
		return false, 0, { 'CostOwnerNotExist' };
	end	
	-- 2. 마스터리 조건 체크
	isEnable, reason = IsEnableExtractRosterMastery(company, pc, mastery, masteryTable, itemCounter);
	return isEnable, reason;
end
function MasteryExtractAllTest(pc, company, masteryTable, itemCounter)
	local isEnable = true;
	local reason = {};
	local masteryList = {};
	local needItemCount = {};
	
	-- 1. PC, Company 존재하는 지여부 체크.
	if company == nil or pc == nil then
		LogAndPrint('[Error] Mastery CostOwner not exist!!');
		return false, { 'CostOwnerNotExist' }, {}, {};
	end	
	-- 2. 마스터리 조건 체크
	isEnable, reason, masteryList, needItemCount = IsEnableExtractRosterMasteryAll(company, pc, masteryTable, itemCounter);
	return isEnable, reason, masteryList, needItemCount;
end
-----------------------------------------------------------------
-- 마스터리. PC 특성 체크 함수 - 
-----------------------------------------------------------------
function IsEnableByMasteryCheckType(pc, mastery, reason)
	local isEnable = true;
	local masteryTypeName = mastery.Type.name;
	local masteryCheckType = mastery.Type.CheckType;
	if masteryCheckType ~= 'All' then
		if mastery.FixedMastery then
			local hasFixedMastery = false;
			local fixedMastery = nil;
			if pc.RosterType == 'Pc' then
				fixedMastery = SafeIndex(pc, 'FixedMastery');
			end
			if fixedMastery then
				for _, masteryName in ipairs(fixedMastery) do
					if masteryName == mastery.name then
						hasFixedMastery = true;
						break;
					end
				end
			end
			if not hasFixedMastery then
				isEnable = false;
				table.insert(reason, 'NotMasteredMastery');
			end
		elseif masteryCheckType == 'PC' then
			if pc.name ~= masteryTypeName then
				isEnable = false;
				table.insert(reason, 'NotSatisfiedPC');
			end
		elseif masteryCheckType == 'ESP' then
			if pc.Object.ESP.name ~= masteryTypeName then
				isEnable = false;
				table.insert(reason, 'NotSatisfiedESP');
			end
		elseif masteryCheckType == 'Job' then
			local isEnableJobMastery = false;
			local job = pc.Object.Job;
			if job and job.name and job.name ~= 'None' then
				local enableJobMasteryList = GetEnableJobMastery(pc.Object.Job);
				for key, value in pairs (enableJobMasteryList) do
					if key == masteryTypeName then
						isEnableJobMastery = true;
						break;
					end
				end
			end
			if not isEnableJobMastery then
				isEnable = false;
				table.insert(reason, 'NotSatisfiedJob');
			end
		elseif masteryCheckType == 'Race' then
			if pc.Object.Race.name ~= masteryTypeName then
				isEnable = false;
				table.insert(reason, 'NotSatisfiedRace');
			end
		elseif masteryCheckType == 'Company' then
			isEnable = false;
			table.insert(reason, 'NotMasteredCompanyMastery');
		elseif masteryCheckType == 'None' then
			isEnable = false;
			table.insert(reason, 'NotMasteredMastery');
		end
	else
		-- 기계는 공용 특성이어도 착용 불가
		if pc.Object.Race.name == 'Machine' then
			isEnable = false;
			table.insert(reason, 'NotSatisfiedRace');
		end
	end
	return isEnable;
end
function IsEnableMasterRosterMastery(company, pc, mastery, masteryTable)
	
	local isEnable = true;
	local reason = {};	
	local currentMasteryList = GetCurrentMasteryList(masteryTable);
	local totalCost = GetCurrentMasteryCost(masteryTable);
	local masteryLv = SafeIndex(masteryTable[mastery.name], 'Lv');
	if masteryLv == nil then
		masteryLv = 0;
	end
	
	-- 1. 이미 배운 어빌리티인가?
	if masteryLv > 0 then
		isEnable = false;
		table.insert(reason, 'Mastered');		
	end
	
	-- 2. 배울 수 있는 개수가 존재하는가?
	if company.Mastery[mastery.name].Amount == 0 then
		isEnable = false;
		table.insert(reason, 'NotEnoughAmount');		
	end
	
	-- 3. TP 가능 테스트
	if totalCost + mastery.Cost > pc.MaxTP then
		isEnable = false;
		table.insert(reason, 'OverTP');	
	end
	-- 타입별 데이터 구분.
	local currentMasteryTypeList = GetCurrentMasteryTypeList(masteryTable, mastery.Category.name);
	local masteryCategory = mastery.Category.EquipSlot;
	local masteryEquipSlot = mastery.Category.EquipSlot;
	local masteryCategoryMaxCount = 0;
	local masteryCategoryMaxCost = 0;
	local masteryCategoryExtraCount = 0;
	if masteryEquipSlot ~= 'None' then
		masteryCategoryMaxCount = pc[string.format('Max%sMasteryCount', masteryEquipSlot)];
		masteryCategoryMaxCost = pc[string.format('Max%sMasteryCost', masteryEquipSlot)];
		masteryCategoryExtraCount = pc[string.format('ExtraMax%sMasteryCount', masteryEquipSlot)];
	else
		isEnable = false;
		table.insert(reason, 'MaxMasteryCatergoryError');
	end
	-- 4. 타입별 최대 개수 체크  
	if #currentMasteryTypeList + 1 > masteryCategoryMaxCount then
		isEnable = false;
		table.insert(reason, 'MaxMasteryTypeCount');
	end
	-- 5. 타입별 최대 코스트 체크  
	local totalTypeCost = 0;
	for i = 1, #currentMasteryTypeList do
		totalTypeCost = totalTypeCost + currentMasteryTypeList[i].Cost;
	end
	if totalTypeCost + mastery.Cost > masteryCategoryMaxCost then
		isEnable = false;
		table.insert(reason, 'OverTPByCategory');
	end
	-- 6. 언락 레벨 체크.
	local masteryUnlockLevelList = GetClassList('MasteryUnlockLevel');
	local unlockLvList = masteryUnlockLevelList[mastery.Category.name].Unlock;
	local unlockMasteryCount = 0;
	for index, unlockLv in ipairs (unlockLvList) do
		if unlockLv > pc.Lv then
			break;
		end
		unlockMasteryCount = unlockMasteryCount + 1;
	end
	unlockMasteryCount = unlockMasteryCount + masteryCategoryExtraCount;
	if #currentMasteryTypeList + 1 > unlockMasteryCount then
		isEnable = false;
		table.insert(reason, 'MaxMasteryTypeUnlockCount');		
	end
	-- 7. 타입에 따른 조건 체크
	isEnable = isEnable and IsEnableByMasteryCheckType(pc, mastery, reason);
	-- 8. 배타적 마스터리 체크
	for _, masteryName in ipairs(mastery.ExclusiveMastery) do
		local masteryLv = SafeIndex(masteryTable[masteryName], 'Lv');
		if masteryLv and masteryLv > 0 then
			isEnable = false;
			table.insert(reason, 'ExclusiveMastery');
		end
	end
	return isEnable, reason;
end
-----------------------------------------------------------------
-- 마스터리 카테고리 리스트 용
-----------------------------------------------------------------
function IsEnableMasterRosterMasteryForCategory(company, pc, mastery)
	local isEnable = true;
	local reason = {};	
	
	-- 타입별 데이터 구분.
	if mastery.Category.EquipSlot == 'None' then
		isEnable = false;
		table.insert(reason, 'MaxMasteryCatergoryError');
	elseif #mastery.Category.EnableRace > 0 then
		if not table.exist(mastery.Category.EnableRace, function(r) return r.name == pc.Object.Race.name end) then
			isEnable = false;
			table.insert(reason, 'MasteryEnableRaceError');
		end
	end
	
	-- 2. 타입에 따른 조건 체크
	isEnable = isEnable and IsEnableByMasteryCheckType(pc, mastery, reason);
	return isEnable, reason;
end
-----------------------------------------------------------------
-- 마스터리. 카테고리 최대 코스트 함수 -
-----------------------------------------------------------------
function GetMasteryTotalTypeCost(masteryTable, type)
	local currentMasteryTypeList = GetCurrentMasteryTypeList(masteryTable, type);
	local totalTypeCost = 0;
	for i = 1, #currentMasteryTypeList do
		totalTypeCost = totalTypeCost + currentMasteryTypeList[i].Cost;
	end
	return totalTypeCost;
end
-----------------------------------------------------------------
-- 마스터리. PC 특성 추출 체크 함수 - 
-----------------------------------------------------------------
function IsEnableExtractRosterMastery(company, pc, mastery, masteryTable, itemCounter)
	
	local isEnable = true;
	local reason = {};
	local acquiredCompanyMasteryList = GetAcquiredCompanyMasteryList(company);
	local totalCost = GetCurrentMasteryCost(masteryTable);
	local masteryLv = SafeIndex(masteryTable[mastery.name], 'Lv');
	if masteryLv == nil then
		masteryLv = 0;
	end
	
	-- 1. 습득한 어빌리티인가?
	if masteryLv == 0 then
		isEnable = false;
		table.insert(reason, 'NotMastered');		
	end	
	-- 2. 추출할 회사의 공간이 존재하는가?
	if company.Mastery[mastery.name].Amount == 0 and #acquiredCompanyMasteryList + 1 > company.MaxMasteryCount then
		isEnable = false;
		table.insert(reason, 'NotEnoughAmount');
	end
	-- 3. 추출 시 필요한 재료 여부 존재. 마스터리 코스트 만큼 필요.
	if mastery.ExtractItem == 'None' then
		isEnable = false;
		table.insert(reason, 'DisableExtract');
	else	
		local extractItemCount = itemCounter(mastery.ExtractItem);
		if extractItemCount < mastery.Cost then
			isEnable = false;
			table.insert(reason, 'NotEnoughExtractItem');	
		end
	end
	-- 4. 추출 후의 특성판이 유효한지?
	local mbm = MasteryBoardManager.new(pc, masteryTable);
	local removeEnable, removeReason = mbm:isEnableRemoveMastery(mastery.name);
	if not removeEnable then
		isEnable = false;
		table.append(reason, removeReason);
	end
	
	return isEnable, reason;
end
function IsEnableExtractRosterMasteryAll(company, pc, masteryTable, itemCounter)
	local isEnable = true;
	local reason = {};
	local acquiredCompanyMasteryList = GetAcquiredCompanyMasteryList(company);
	
	-- 1. 추출 가능한 특성들만 뽑음
	local masteryList = {};
	for masteryName, mastery in pairs(masteryTable) do
		if mastery.Lv > 0 and mastery.Category.EquipSlot ~= 'None' and mastery.ExtractItem ~= 'None' then
			table.insert(masteryList, mastery);
		end
	end
	
	-- 2. 추출할 회사의 공간이 존재하는가?
	local needEnoughAmount = 0;
	for _, mastery in ipairs(masteryList) do
		if company.Mastery[mastery.name].Amount == 0 then
			needEnoughAmount = needEnoughAmount + 1;
		end
	end
	if #acquiredCompanyMasteryList + needEnoughAmount > company.MaxMasteryCount then
		isEnable = false;
		table.insert(reason, 'NotEnoughAmount');
	end
	
	-- 3. 추출 시 필요한 재료 여부 존재. 마스터리 코스트 만큼 필요.
	local needItemCount = {};
	for _, mastery in ipairs(masteryList) do
		needItemCount[mastery.ExtractItem] = (needItemCount[mastery.ExtractItem] or 0) + mastery.Cost;
	end
	for extractItem, needCount in pairs(needItemCount) do
		local extractItemCount = itemCounter(extractItem);
		if extractItemCount < needCount then
			isEnable = false;
			table.insert(reason, 'NotEnoughExtractItem');	
		end
	end
	
	return isEnable, reason, masteryList, needItemCount;
end
---------------------------------------------------------------------
----------------- 현재 배운 마스터리 체크 함수 --------------------
---------------------------------------------------------------------
function GetMasteryMastered(masteryTable, masteryName)
	if masteryTable then
		local mastery = masteryTable[masteryName];
		local masteryLv = SafeIndex(mastery, 'Lv');
		if masteryLv and masteryLv > 0 then
			return mastery;
		end
	end
	return nil;
end
function GetMasteryMasteredList(masteryTable, masteryList)
	for _, masteryName in ipairs(masteryList) do
		local mastery = GetMasteryMastered(masteryTable, masteryName);
		if mastery then
			return mastery;
		end
	end
	return nil;
end
---------------------------------------------------------------------
----------------- 야생생활 류 마스터리 체크 함수 --------------------
---------------------------------------------------------------------
local s_likeWildLifeMastery = {'WildLife', 'WildLife2', 'EnvironmentalAdaptation'};
function GetMasteryMasteredLikeWildLife(masteryTable)
	for _, masteryName in ipairs(s_likeWildLifeMastery) do
		local mastery = GetMasteryMastered(masteryTable, masteryName);
		if mastery then
			return mastery;
		end	
	end
end
function GetMasteryMasteredWithDataLikeWildLife(obj, data)
	for _, masteryName in ipairs(s_likeWildLifeMastery) do
		local mastery = GetMasteryMasteredWithData(obj, masteryName, data)
		if mastery then
			return mastery;
		end	
	end
end
function GetMasteryMasteredImmuneWeather(masteryTable)
	return GetMasteryMasteredLikeWildLife(masteryTable) or GetMasteryMastered(masteryTable, 'Coat_Collector_Set');
end
function GetMasteryMasteredImmuneTemperature(masteryTable)
	return GetMasteryMasteredLikeWildLife(masteryTable);
end
---------------------------------------------------------------------
----------------- 현재 1레벨 이상 마스터리 체크 함수 --------------------
---------------------------------------------------------------------
function GetCurrentMasteryList(masteryTable)
	local list = {};
	local mastertyList = GetClassList('Mastery');
	if masteryTable then
		for key, mastery in pairs (masteryTable) do
			local masteryLv = SafeIndex(mastery, 'Lv');
			local curMastery = mastertyList[mastery.name];
			if curMastery then
				if curMastery.Category.Type == 'Normal' or curMastery.Category.Type == 'Unique' or curMastery.Category.Type == 'Ability' then
					if masteryLv and masteryLv > 0 then
						table.insert(list, curMastery);
					end
				end
			end
		end	
	end
	return list;
end
---------------------------------------------------------------------
----------------- 현재 타입별 마스터리 체크 함수 --------------------
---------------------------------------------------------------------
function GetCurrentMasteryTypeList(masteryTable, arg)
	local list = {};
	local mastertyList = GetClassList('Mastery');
	if masteryTable then
		for key, mastery in pairs (masteryTable) do
			local masteryLv = SafeIndex(mastery, 'Lv');
			local curMastery = mastertyList[mastery.name];
			if curMastery then
				if curMastery.Category.name == arg then
					if masteryLv and masteryLv > 0 then
						table.insert(list, curMastery);
					end
				end
			end
		end	
	end
	return list;
end
---------------------------------------------------------------------
----------------- 현재 습득한 어빌리티 마스터리 개수  --------------------
---------------------------------------------------------------------
function GetCurrentArgMasteryCount(masteryTable, arg)
	local count = 0;
	local mastertyList = GetClassList('Mastery');
	if masteryTable then
		for key, mastery in pairs (masteryTable) do
			local masteryLv = SafeIndex(mastery, 'Lv');
			if masteryLv and masteryLv > 0 then
				local curMastery = mastertyList[mastery.name];
				if curMastery then
					if curMastery.Category.name == arg then
						count = count + 1;
					end
				end
			end
		end	
	end
	return count;
end
---------------------------------------------------------------------
----------------- 현재 1레벨 이상 기본 마스터리 체크 함수 --------------------
---------------------------------------------------------------------
function GetCurrentBasicMasteryList(masteryTable)
	local list = {};
	local mastertyList = GetClassList('Mastery');
	if masteryTable then
		for key, mastery in pairs (masteryTable) do
			local masteryLv = SafeIndex(mastery, 'Lv');
			local curMastery = mastertyList[mastery.name];
			if curMastery then
				if curMastery.Category.Type == 'Basic' then
					if masteryLv and masteryLv > 0 then
						table.insert(list, curMastery);
					end
				end
			end
		end	
	end
	return list;
end
---------------------------------------------------------------------
----------------- 현재 습득한마스터리 코스트  --------------------
---------------------------------------------------------------------
function GetCurrentMasteryCost(masteryTable)
	local cost = 0;
	local mastertyList = GetClassList('Mastery');
	if masteryTable then
		for key, mastery in pairs (masteryTable) do
			local masteryLv = SafeIndex(mastery, 'Lv');
			local curMastery = mastertyList[mastery.name];
			if curMastery then
				if curMastery.Category.Type == 'Normal' or curMastery.Category.Type == 'Unique' or curMastery.Category.Type == 'Ability' then
					if masteryLv and masteryLv > 0 then
						cost = cost + curMastery.Cost;
					end
				end
			end
		end	
	end
	return cost;
end
---------------------------------------------------------------------
----------------- 현재 습득한 유니크 마스터리 개수  --------------------
---------------------------------------------------------------------
function GetCurrentUniqueMasteryCount(masteryTable)
	local count = 0;
	local mastertyList = GetClassList('Mastery');
	if masteryTable then
		for key, mastery in pairs (masteryTable) do
			local masteryLv = SafeIndex(mastery, 'Lv');
			if masteryLv and masteryLv > 0 then
				local curMastery = mastertyList[mastery.name];
				if curMastery then
					if curMastery.Category.Type == 'Unique' then
						count = count + 1;
					end
				end
			end
		end	
	end
	return count;
end
---------------------------------------------------------------------
----------------- 현재 보유한 회사 마스터리 개수  --------------------
---------------------------------------------------------------------
function GetAcquiredCompanyMasteryList(company, includeZero, isMachine)
	local list = {};
	for key, mastery in pairs (company.Mastery) do
		(function()
			if not includeZero and mastery.Amount <= 0 then
				return;
			end
			if mastery.Amount == 0 then
				local technique = GetWithoutError(company.Technique, key);
				if not technique or not technique.Opened then
					return;
				end
			end
			if isMachine ~= nil and mastery.Category.IsMachine ~= isMachine then
				return;
			end
			if mastery.Category.Type == 'Normal' or mastery.Category.Type == 'Unique' or mastery.Category.Type == 'Ability' then
				table.insert(list, mastery);
			end
		end)();
	end
	table.sort(list, function (a, b)
		return a.Title < b.Title;
	end);
	return list;
end
------------------------------------------------------------------------
-- 팀에 따른 마스터리 키.
-----------------------------------------------------------------------
function GetMasteryEventKey(owner)
	local team = GetTeam(owner);
	local key = '';
	if team == 'player' then
		key = 'PlayerMasteryEvent';
	else
		key = 'EnemyMasteryEvent';
	end
	return key;
end
------------------------------------------------------------------------
-- 마스터리셋 하위 마스터리 리스트로 받아오기
-----------------------------------------------------------------------
function GetMasterySetList(curMastery)
	local list = {};
	local masterySetList = GetClassList('MasterySet');
	local masteryList = GetClassList('Mastery');
	local curMasterySet = masterySetList[curMastery.name];
	if curMasterySet and curMasterySet.name ~= nil then
		for i = 1, 4 do
			local curKey = 'Mastery'..i;
			local subMasteryName = curMasterySet[curKey];
			if subMasteryName ~= 'None' then
				local subMastery = masteryList[subMasteryName];
				if subMastery and subMastery.name ~= nil then
					table.insert(list, subMastery);
				end
			end
		end		
	end
	table.sort(list, function(a, b)
		if a.Category.Order == b.Category.Order then
			if a.Cost == b.Cost then
				return a.Title > b.Title;
			else
				return a.Cost > b.Cost;
			end
		else
			return a.Category.Order > b.Category.Order
		end		
	end);
	return list;
end
------------------------------------------------------------------------
-- CalculatedProperty
------------------------------------------------------------------------
function CalculatedProperty_EnableSetMasteries(mastery)
	local result = {};
	local masterSetList = GetClassList('MasterySet');
	for _, setCls in pairs(GetClassList('MasterySet')) do
		local index = 1;
		while true do
			local m = GetWithoutError(setCls, 'Mastery'..index);
			if m == nil then
				break;
			end
			index = index + 1;
			if m == mastery.name then
				table.insert(result, setCls);
				break;
			end
		end
	end
	return result;
end
function CalculatedProperty_EmptyBuffModifier(mastery)
	return {}
end
function BuffTableColumnReseter(buff, column)
	for i = 1, #buff[column] do
		buff[column][i] = 0;
	end
end
function BuffNeutralizer_Swamp(buff)
	buff.Disabled = true;
	BuffTableColumnReseter(buff, 'Base_MoveDist');
	BuffTableColumnReseter(buff, 'Base_Speed');
	buff.Stable = true;
end
function BuffNeutralizer_Water(buff)
	buff.Disabled = true;
	buff.Desc_Base = '';
	BuffTableColumnReseter(buff, 'Base_ApplyAmount');
	BuffTableColumnReseter(buff, 'Base_MoveDist');
	BuffTableColumnReseter(buff, 'Base_Dodge');
	BuffTableColumnReseter(buff, 'Base_Block');
end
function BuffNeutralizer_Web(buff)
	buff.Disabled = true;
	BuffTableColumnReseter(buff, 'Base_MoveDist');
	BuffTableColumnReseter(buff, 'Base_Dodge');
end
function BuffNeutralizer_Ice(buff)
	buff.Disabled = true;
	buff.Desc_Base = '';
	buff.Stable = true;
	BuffTableColumnReseter(buff, 'Base_ApplyAmount');
	BuffTableColumnReseter(buff, 'Base_Accuracy');
	BuffTableColumnReseter(buff, 'Base_Dodge');
	BuffTableColumnReseter(buff, 'Base_Block');
end
function BuffNeutralizer_Lava(buff)
	buff.Disabled = true;
	buff.Desc_Base = '';
	buff.Stable = true;
	BuffTableColumnReseter(buff, 'Base_Accuracy');
	BuffTableColumnReseter(buff, 'Base_Dodge');
	BuffTableColumnReseter(buff, 'Base_Block');
	BuffTableColumnReseter(buff, 'Base_Speed');
end
function BuffNeutralizer_ContaminatedWater(buff)
	buff.Disabled = true;
	buff.Desc_Base = '';
	BuffTableColumnReseter(buff, 'Base_ApplyAmount');
	BuffTableColumnReseter(buff, 'Base_RegenVigor');
	BuffTableColumnReseter(buff, 'Base_MoveDist');
	BuffTableColumnReseter(buff, 'Base_Dodge');
	BuffTableColumnReseter(buff, 'Base_Block');
end
function CalculatedProperty_BuffModifier_WildLife(mastery)
	return {
		SmokeScreen = function(buff)
			for i = 1, #buff.Base_ApplyAmount do
				buff.Base_ApplyAmount[i] = buff.Base_ApplyAmount[i] + mastery.ApplyAmount;
			end
		end,
		Bush = function(buff)
			for i = 1, #buff.Base_ApplyAmount do
				buff.Base_ApplyAmount[i] = buff.Base_ApplyAmount[i] + mastery.ApplyAmount;
			end
		end,
		Swamp = BuffNeutralizer_Swamp,
		Water = BuffNeutralizer_Water,
		Web = BuffNeutralizer_Web,
		Ice = BuffNeutralizer_Ice,
		ContaminatedWater = BuffNeutralizer_ContaminatedWater,
		Lava = BuffNeutralizer_Lava,
	};
end
function CalculatedProperty_BuffModifier_Hovering(mastery)
	return Linq.new(mastery.NeutralizeFieldEffect)
		:selectMany(function(fieldEffect) return table.map(fieldEffect.BuffAffector, function(affector) return {affector.ApplyBuff.name, _G['BuffNeutralizer_' .. affector.ApplyBuff.name]} end); end)
		:where(function(data) return data[2] ~= nil end)
		:toMap();
end
function CalculatedProperty_BuffModifier_Flight(mastery)
	return Linq.new(mastery.NeutralizeFieldEffect)
		:selectMany(function(fieldEffect) return table.map(fieldEffect.BuffAffector, function(affector) return {affector.ApplyBuff.name, _G['BuffNeutralizer_' .. affector.ApplyBuff.name]} end); end)
		:where(function(data) return data[2] ~= nil end)
		:toMap();
end
function CP_BuffModifier_EnvironmentalAdaptation(mastery)
	local BuffModifierApplyAmountAdder = function (buff)
		for i = 1, #buff.Base_ApplyAmount do
			buff.Base_ApplyAmount[i] = buff.Base_ApplyAmount[i] * (1 + mastery.ApplyAmount / 100);
		end
	end
	return {
		SmokeScreen = BuffModifierApplyAmountAdder,
		Bush = BuffModifierApplyAmountAdder,
		Swamp = BuffNeutralizer_Swamp,
		Water = BuffNeutralizer_Water,
		Web = BuffNeutralizer_Web,
		Ice = BuffNeutralizer_Ice,
		ContaminatedWater = BuffNeutralizer_ContaminatedWater,
		Lava = BuffNeutralizer_Lava,
	}
end
-- 등가 교환
function CP_BuffModifier_PassionForGold(mastery)
	return {
		ExchangeOfEquivalents = function(buff)
			for i = 1, #buff.Base_ApplyAmount do
				buff.Base_ApplyAmount[i] = buff.Base_ApplyAmount[i] + mastery.ApplyAmount;
			end
		end
	};
end
-- 성실한 연구가
function CP_BuffModifier_SincereResearcher(mastery)
	return {
		[mastery.Buff.name] = function(buff)
			buff.Base_MaxStack = buff.Base_MaxStack + mastery.ApplyAmount2;
		end
	};
end
-- 각인된 적개심
function CP_BuffModifier_Hostility(mastery)
	local BuffModifierDisableLoseIFF = function(buff)
		buff.LoseIFF = false;
	end;
	return {
		Confusion = BuffModifierDisableLoseIFF,
		MachineFury = BuffModifierDisableLoseIFF,
		Frenzy = BuffModifierDisableLoseIFF,
	};
end
-- 자각몽
function CP_BuffModifier_LucidDream(mastery)
	local ret = {};
	local sightRangeResetter = function(buff) 
		BuffTableColumnReseter(buff, 'Base_SightRange');
	end
	for _, buffCls in pairs(GetClassList('Buff')) do
		if buffCls.Group == mastery.BuffGroup.name and buffCls.SightRange < 0 then
			ret[buffCls.name] = sightRangeResetter;
		end
	end
	return ret;
end
-- 지형효과 디버프 면역 (ex. 전문 사냥꾼의 부츠, 철거업자 운동화)
function CP_BuffModifier_ImmuneDebuff_FieldEffect(mastery)
	return {
		Swamp = BuffNeutralizer_Swamp,
		Water = BuffNeutralizer_Water,
		Web = BuffNeutralizer_Web,
		Ice = BuffNeutralizer_Ice,
		ContaminatedWater = BuffNeutralizer_ContaminatedWater,
		Lava = BuffNeutralizer_Lava,
	};
end
------------------------------------------------------------------------
-- 기본 마스터리 설정 (PC는 서버 스크립트에서만)
-----------------------------------------------------------------------
-- DB에는 존재하지 않을 수 있으나 무조건 기본으로 들고 들어갈 마스터리 설정
function GetBaseMastery_Monster(target, monster)	-- 현 시점에서 targetster가 따로 있는게 아니니까 그냥 Object임
	local masteryList = GetClassList('Mastery');	
	-- 1. 기본 마스터리 (PC 공용)
	local list = SetBasicMasteries(target, false);
	-- 2. 몬스터가 자신의 특성에서 배워야만 하는 고정 특성.
	local monsterList = GetClassList('Monster');
	local curMonster = monster;
	if not monster then
		local monsterKey = GetInstantProperty(target, 'MonsterType');
		curMonster = monsterList[monsterKey];
	end
	local monsterMasteries = SafeIndex(curMonster, 'Masteries');
	if monsterMasteries then
		if #monsterMasteries > 0 then
			for key, value in pairs (monsterMasteries) do
				list[key] = value;
			end
		end
	end
	-- 3. 몬스터 등급에 따른 추가 마스터리
	if target.Grade.name == 'Elite' then
		list['Elite'] = 1;
	elseif target.Grade.name == 'Epic' then
		list['Epic'] = 1;
	elseif target.Grade.name == 'Legend' then
		list['Legend'] = 1;
	end
	return list;
end
function SetBasicMasteries(obj, isPc)
	local list = {};
	local masteryList = GetClassList('Mastery');
	-- 1. 종족 특성
	local raceBasicMasteryName = SafeIndex(obj.Race, 'BasicMastery');
	if raceBasicMasteryName and raceBasicMasteryName ~= 'None' then
		local curRaceBasicMastery = SafeIndex(masteryList[raceBasicMasteryName], 'name');
		if curRaceBasicMastery and curRaceBasicMastery ~= 'None' then
			list[curRaceBasicMastery] = 1;
		end
	end
	-- Object 종족은 전투 대상이 아니므로 직업, 초능력, 조직 특성을 주지 않음 (종족 특성은 필요한가?)
	if obj.Race.name == 'Object' then
		return list;
	end	
	-- 2. 직업 특성
	local jobBasicMasteryName = SafeIndex(obj.Job, 'BasicMastery');
	if jobBasicMasteryName and jobBasicMasteryName ~= 'None' then
		local curJobBasicMastery = SafeIndex(masteryList[jobBasicMasteryName], 'name');
		if curJobBasicMastery and curJobBasicMastery ~= 'None' then
			list[curJobBasicMastery] = 1;
		end
		-- 빛나는 재능 (StartJob의 직업 특성 추가)
		if jobBasicMasteryName == 'ShiningTalent' then
			local startJobBasicMasteryName = SafeIndex(obj.StartJob, 'BasicMastery');
			if startJobBasicMasteryName and startJobBasicMasteryName ~= 'None' then
				local startJobBasicMastery = SafeIndex(masteryList[startJobBasicMasteryName], 'name');
				if startJobBasicMastery and startJobBasicMastery ~= 'None' then
					list[startJobBasicMastery] = 1;
				end
			end
		end
	end
	-- 3. 초능력 특성
	local espBasicMasteryName = SafeIndex(obj.ESP, 'BasicMastery');
	if espBasicMasteryName and espBasicMasteryName ~= 'None' then
		local curESPBasicMastery = SafeIndex(masteryList[espBasicMasteryName], 'name');
		if curESPBasicMastery and curESPBasicMastery ~= 'None' then
			list[curESPBasicMastery] = 1;
		end
	end
	-- 4. 조직 특성 추가. (PC 오브젝트는 조직 특성 무시)
	local organizationBasicMasteryName = SafeIndex(obj.Affiliation, 'BasicMastery');
	if organizationBasicMasteryName and organizationBasicMasteryName ~= 'None' and not isPc then
		local curOrganizationBasicMastery = GetWithoutError(masteryList[organizationBasicMasteryName], 'name');
		if curOrganizationBasicMastery and curOrganizationBasicMastery ~= 'None' then
			list[curOrganizationBasicMastery] = 1;
		end
	end
	-- 5. 세트 아이템 특성
	local itemSetInfoList = GetItemSetList(obj);
	for _, itemSetInfo in ipairs(itemSetInfoList) do
		for _, masteryInfo in ipairs(itemSetInfo.Masteries) do
			if masteryInfo.Activated then
				list[masteryInfo.Mastery.name] = 1;
			end
		end
	end
	return list;
end
g_masterySetReference = nil;
g_masterySetFull = nil;
function GetMasterySetTestSet()
	if g_masterySetReference ~= nil then
		return g_masterySetReference, table.deepcopy(g_masterySetFull);
	end
	local masteryClsList = GetClassList('Mastery');
	g_masterySetReference = {};
	g_masterySetFull = {};
	local subPropList = {'Mastery1', 'Mastery2', 'Mastery3', 'Mastery4'};
	
	local IterFunc = function(masterySetCls)
		-- 대상 마스터리 체크
		local acquiereMastery = masteryClsList[masterySetCls.name];
		if acquiereMastery == nil then
			LogAndPrint(string.format('GetMasterySetTestSet >> Mastery [%s] is not Exist', masterySetCls.name));
			return;
		end
		if acquiereMastery.name == 'None' or acquiereMastery.Category.name ~= 'Set' then
			LogAndPrint('유효하지 않은 세트 마스터리 : ', masterySetCls.name);
			return;
		end
		
		for _, propName in ipairs(subPropList) do
			local propValue = masterySetCls[propName];
			if propValue ~= 'None' then
				local needMastery = masteryClsList[propValue];
				if not needMastery or needMastery.name == 'None' then
					LogAndPrint('유효하지 않은 필요 마스터리 : ', masterySetCls.name, propName, propValue);
					return;
				end
				ForceNewInsert(g_masterySetReference, propValue, masterySetCls.name);
			end
		end
		g_masterySetFull[masterySetCls.name] = masterySetCls;
	end
	
	for _, masterySetCls in pairs(GetClassList('MasterySet')) do
		IterFunc(masterySetCls);
	end
	--LogAndPrint('GetMasterySetTestSet', g_masterySetReference);
	return g_masterySetReference, table.deepcopy(g_masterySetFull);
end
function GetSetMastery(obj, masteryTable)
	local masteryClsList = GetClassList('Mastery');
	local masterySetClsList = GetClassList('MasterySet');
	
	local masterySetRef, remainSet = GetMasterySetTestSet();
	local subPropList = {'Mastery1', 'Mastery2', 'Mastery3', 'Mastery4'};
	local checkSetFunc = function(masterySetCls)
		if remainSet[masterySetCls.name] == nil then
			return false;
		end
		for _, propName in ipairs(subPropList) do
			local subMastery = masterySetCls[propName];
			if subMastery ~= 'None' and not GetMasteryMastered(masteryTable, subMastery) then
				for _, refSetMastery in ipairs(masterySetRef[subMastery]) do
					remainSet[refSetMastery] = nil;
				end
				return false;
			end
		end
		return true;
	end
	local list = {};
	for _, remainSetMastery in pairs(remainSet) do
		if checkSetFunc(remainSetMastery) then
			table.bininsert(list, remainSetMastery, function(cls) return cls.Priority end);
		end
	end
	
	return table.map(list, function(cls) return cls.name end);
end
function GetSetMasteryLackList(pc, masteryTable, lackCount)
	local list = {};
	local masterySets = {};
	
	local masteryClsList = GetClassList('Mastery');
	local masterySetClsList = GetClassList('MasterySet');
	for _, masterySetCls in pairs(masterySetClsList) do
		(function()
			-- 대상 마스터리 체크
			local acquiereMastery = masteryClsList[masterySetCls.name];
			if acquiereMastery == nil then
				LogAndPrint(string.format('GetSetMasteryLackList >> Mastery [%s] is not Exist', masterySetCls.name));
				return;
			end
			if acquiereMastery.name == 'None' or acquiereMastery.Category.name ~= 'Set' then
				LogAndPrint('유효하지 않은 세트 마스터리 : ', masterySetCls.name);
				return;
			end
			-- 필요 마스터리 체크
			local needCount = 0;
			local hasCount = 0;
			for _, propName in ipairs({'Mastery1', 'Mastery2', 'Mastery3', 'Mastery4'}) do
				local propValue = masterySetCls[propName];
				if propValue ~= 'None' then
					local needMastery = masteryClsList[propValue];
					if not needMastery or needMastery.name == 'None' then
						LogAndPrint('유효하지 않은 필요 마스터리 : ', masterySetCls.name, propName, propValue);
						return;
					end
					-- 아예 착용이 불가능함
					local reason = {};
					if not IsEnableByMasteryCheckType(pc, needMastery, reason) then
						return;
					end
					needCount = needCount + 1;
					-- 필요 마스터리를 가지고 있지 않음
					if GetMasteryMastered(masteryTable, needMastery.name) then
						hasCount = hasCount + 1;
					end
				end	
			end
			-- 일단 목록에 포함
			if needCount - hasCount == lackCount then
				table.insert(masterySets, masterySetCls);
			end
		end)();
	end
	
	-- 우선 순위 정렬
	table.sort(masterySets, function (lhs, rhs) return lhs.Priority < rhs.Priority end);
	
	for i = 1, #masterySets do
		table.insert(list, masterySets[i].name);
	end
	return list;
end
-----------------------------------------------------------------
-- 커스텀 캐시 데이터
-----------------------------------------------------------------
function Mastery_CustomCache_MasteryCountByFunc(obj, testFunc)
	if IsClass(obj) then
		return 0;
	end
	local owner = GetMasteryOwner(obj);
	if owner == nil then
		return 0;
	end
	local masteryTable = GetMastery(owner);
	return table.count(masteryTable, function(mastery)
		if mastery.Lv <= 0 then
			return false;
		elseif mastery.Type.name == 'Equipment' then
			return false;
		end
		return testFunc(mastery);
	end);
end
function Mastery_CustomCache_MasteryCostByFunc(obj, testFunc)
	if IsClass(obj) then
		return 0;
	end
	local owner = GetMasteryOwner(obj);
	if owner == nil then
		return 0;
	end
	local masteryTable = GetMastery(owner);
	local totalCost = 0;
	for _, mastery in pairs(masteryTable) do
		if mastery.Lv > 0 and mastery.Type.name ~= 'Equipment' and testFunc(mastery) then
			totalCost = totalCost + mastery.Cost;
		end
	end
	return totalCost;
end
function Mastery_CustomCache_MasteryCountByType(obj, testTypeSet)
	return Mastery_CustomCache_MasteryCountByFunc(obj, function(mastery) return testTypeSet[mastery.Type.name] end);
end
function Mastery_CustomCache_WitchBook(obj, arg)
	return Mastery_CustomCache_MasteryCountByType(obj, Set.new({'Shaman', 'Witch'}));
end
function Mastery_CustomCache_ArchWitch(obj, arg)
	return Mastery_CustomCache_MasteryCountByFunc(obj, function(mastery) return mastery.Type.CheckType == 'ESP'; end);
end
function Mastery_CustomCache_FigterBook(obj, arg)
	return Mastery_CustomCache_MasteryCountByType(obj, Set.new({'Fighter', 'MartialArtist'}));
end
function Mastery_CustomCache_SwordsmanshipBook(obj, arg)
	return Mastery_CustomCache_MasteryCountByType(obj, Set.new({'Swordsman', 'Greatswordsman', 'Swordmagician'}));
end
function Mastery_CustomCache_BlackMagicCircuit(obj, arg)
	local owner = GetMasteryOwner(obj);
	if owner == nil then
		return 0;
	end
	return Mastery_CustomCache_MasteryCountByType(obj, Set.new({owner.ESP.name}));
end
function Mastery_CustomCache_StreetFighter(obj, arg)
	return Mastery_CustomCache_MasteryCountByType(obj, Set.new({'Fighter', 'All'}));
end
function Mastery_CustomCache_SameTypeMasteryCount(obj, arg)
	return Mastery_CustomCache_MasteryCountByType(obj, Set.new({obj.Type.name}));
end
function Mastery_CustomCache_RevealWildNature(obj, arg)
	return Mastery_CustomCache_MasteryCountByFunc(obj, function(mastery) return mastery.Category.name == 'Beast' or mastery.Type.name == 'Beast' end);
end
function Mastery_CustomCache_MajorTextbooks(obj, arg)
	return Mastery_CustomCache_JobMasteryCount(obj,arg);
end
function Mastery_CustomCache_StandAlone(obj, arg)
	return Mastery_CustomCache_JobMasteryCount(obj, arg);
end
function Mastery_CustomCache_Educationalbooks(obj, arg)
	return Mastery_CustomCache_MasteryCountByFunc(obj, function(mastery) return mastery.Type.CheckType ~= 'Job'; end);
end
function Mastery_CustomCache_JobMasteryCount(obj, arg)
	return Mastery_CustomCache_MasteryCountByFunc(obj, function(mastery) return mastery.Type.CheckType == 'Job'; end);
end
function Mastery_CustomCache_ScholarHacker(obj, arg)
	return Mastery_CustomCache_MasteryCountByType(obj, Set.new({'Scholar', 'Hacker'}));
end
function Mastery_CustomCache_ArchScholar(obj, arg)
	local ret = {};
	local maxCategories = nil;
	local maxValue = 0;
	for _, category in ipairs({ 'Normal', 'Sub', 'Attack', 'Defence', 'Ability' }) do
		ret[category] = Mastery_CustomCache_MasteryCostByFunc(obj, function(mastery) return mastery.Category.name == category; end);
		if ret[category] > maxValue then
			maxValue = ret[category];
			maxCategories = {category};
		elseif ret[category] == maxValue then
			table.insert(maxCategories, category);
		end
	end
	local owner = GetMasteryOwner(obj);
	local mastery_SincereResearcher = GetMasteryMastered(GetMastery(owner), 'SincereResearcher');
	if mastery_SincereResearcher and maxCategories then
		for _, category in ipairs(maxCategories) do
			ret[category] = mastery_SincereResearcher.ApplyAmount * ret[category];
		end
	end
	return ret;
end
-- 단단한 비늘
function Mastery_CustomCache_HardScale(obj, arg)
	local ret = {};
	for _, mType in ipairs({'Beast', 'Draky', 'All'}) do
		ret[mType] = Mastery_CustomCache_MasteryCountByFunc(obj, function(mastery) return mastery.Type.name == mType; end);
	end
	ret.ESP = Mastery_CustomCache_MasteryCountByFunc(obj, function(mastery) return mastery.Type.CheckType == 'ESP'; end);
	return ret;
end
function Mastery_CustomCache_ModuleCount(obj, arg)
	local moduleCategories = Set.new({'FrameModule', 'SupportModule', 'ComplementaryModule', 'SaftyModule', 'AIModule', 'Set', 'Machine'});
	return Mastery_CustomCache_MasteryCountByFunc(obj, function(mastery) return moduleCategories[mastery.Category.name]; end);
end
function Mastery_CustomCache_EquipmentCompatibility(obj, arg)
	local applyAbility = {};
	for _, itemCls in pairs(GetClassList('Item')) do
		if SafeIndex(itemCls, 'Mastery', 'name') == obj.name then
			for _, abilitySlot in ipairs({'Ability', 'SubAbility', 'UpgradeAbility'}) do
				local abilityName =SafeIndex(itemCls, 'Ability', 'name');
				if abilityName then
					table.insert(applyAbility, abilityName);
				end
			end
		end
	end
	return Set.new(applyAbility);
end
function Mastery_CustomCache_Application_Control_Count(obj, arg)
	return Mastery_CustomCache_MasteryCountByType(obj, Set.new({'Application_Control'}));
end
function Mastery_CustomCache_Application_Enhancement_Count(obj, arg)
	return Mastery_CustomCache_MasteryCountByType(obj, Set.new({'Application_Enhancement'}));
end
function Mastery_CustomCache_Application_EachType_Count(obj, arg)
	local ret = {};
	for _, type in ipairs({ 'Application_Control', 'Application_Enhancement' }) do
		ret[type] = Mastery_CustomCache_MasteryCountByType(obj, Set.new({type}));
	end
	return ret;
end
function Mastery_CustomCache_MagicianSwordWall(obj, arg)
	return Mastery_CustomCache_MasteryCountByFunc(obj, function(mastery) return mastery.Type.name == 'Swordmagician' or mastery.Type.CheckType == 'ESP'; end);
end
function Mastery_CustomCache_MagicianSwordMaster(obj, arg)
	local ret = {};
	for _, type in ipairs({ 'Swordsman', 'Mage', 'Swordmagician' }) do
		ret[type] = Mastery_CustomCache_MasteryCountByType(obj, Set.new({type}));
	end
	return ret;
end
-- 가려진 과거
function Mastery_CustomCache_BehindStory(obj, arg)
	local ret = {};
	for _, type in ipairs({ 'Clown', 'Dancer', 'Singer', 'Musician', 'All' }) do
		ret[type] = Mastery_CustomCache_MasteryCountByType(obj, Set.new({type}));
	end
	local owner = GetMasteryOwner(obj);
	-- 빛의 그림자
	local mastery_ShadowOfLight = GetMasteryMastered(GetMastery(owner), 'ShadowOfLight');
	if mastery_ShadowOfLight then
		local testMasteryCount = Mastery_CustomCache_MasteryCountByType(obj, Set.new({'SuperStar'}));
		local addCount = math.floor(testMasteryCount / mastery_ShadowOfLight.ApplyAmount) * mastery_ShadowOfLight.ApplyAmount2;
		for type, count in pairs(ret) do
			ret[type] = count + addCount;
		end
	end
	return ret;
end
-- 다재다능
function Mastery_CustomCache_Versatility(obj, arg)
	local ret = Mastery_CustomCache_MasteryCountByType(obj, Set.new({ 'Clown', 'Dancer', 'Singer', 'Musician', 'SuperStar' }));
	-- 빛의 그림자
	local owner = GetMasteryOwner(obj);
	local mastery_ShadowOfLight = GetMasteryMastered(GetMastery(owner), 'ShadowOfLight');
	if mastery_ShadowOfLight then
		local testMasteryCount = Mastery_CustomCache_MasteryCountByType(obj, Set.new({'All', 'Human'}));
		local addCount = math.floor(testMasteryCount / mastery_ShadowOfLight.ApplyAmount3) * mastery_ShadowOfLight.ApplyAmount2;
		ret = ret + addCount;
	end
	return ret;
end
-- 리듬에 맞춰 흥겹게
function Mastery_CustomCache_RhythmicalMovements(obj, arg)
	local ret = {};
	for _, category in ipairs({ 'Normal', 'Sub', 'Attack', 'Defence', 'Ability' }) do
		ret[category] = Mastery_CustomCache_MasteryCountByFunc(obj, function(mastery) return mastery.Category.name == category; end);
	end
	return ret;
end
-- 이능 제어 훈련
function Mastery_CustomCache_ESPControlTraining(obj, arg)
	local ret = {};
	ret['InternalEnergy'] = Mastery_CustomCache_MasteryCountByType(obj, Set.new({'All'}));
	ret['GoodBodyControl'] = Mastery_CustomCache_MasteryCountByType(obj, Set.new({'Dancer', 'MartialArtist'}));
	return ret;
end
-- 심신단련
function Mastery_CustomCache_BodyAndMindTraining(obj, arg)
	local ret = {};
	ret['All'] = Mastery_CustomCache_MasteryCountByType(obj, Set.new({'All'}));
	ret['Job'] = Mastery_CustomCache_MasteryCountByFunc(obj, function(mastery) return mastery.Type.CheckType == 'Job'; end);
	ret['ESP'] = Mastery_CustomCache_MasteryCountByFunc(obj, function(mastery) return mastery.Type.CheckType == 'ESP'; end);
	return ret;
end
-- 호연지기
function Mastery_CustomCache_VastSpirit(obj, arg)
	return Mastery_CustomCache_MasteryCountByType(obj, Set.new({'Spirit'}));
end
-- 숨결주머니
function Mastery_CustomCache_BreathSac(obj, arg)
	local ret = {};
	ret['Beast'] = Mastery_CustomCache_MasteryCountByType(obj, Set.new({'Beast'}));
	ret['Draky'] = Mastery_CustomCache_MasteryCountByType(obj, Set.new({'Draky'}));
	ret['ESP'] = Mastery_CustomCache_MasteryCountByFunc(obj, function(mastery) return mastery.Type.CheckType == 'ESP'; end);
	return ret;
end
-- 탐욕의 눈
function Mastery_CustomCache_GreedEye(obj, arg)
	local ret = {};
	ret['Legend'] = obj.ApplyAmount;
	ret['Epic'] = obj.ApplyAmount2;
	ret['Rare'] = obj.ApplyAmount3;
	ret['Uncommon'] = obj.ApplyAmount4;
	return ret;
end
-----------------------------------------------------------------
-- MasteryBoardManager
-----------------------------------------------------------------
MasteryBoardManager = {}
function MasteryBoardManager.new(pcInfo, masteryTable)
	local ret = {Target = pcInfo, TP = 0, MasteryTable = {}, SetMasteries = {}};
	ret.CategoryList = {'Basic', 'Sub', 'Attack', 'Defence', 'Ability'};
	for _, slot in ipairs(ret.CategoryList) do
		ret[slot] = {Count = 0, Cost = 0, Masteries = {}};
	end
	ret.MasterySet = {};
	ret.MasterySetRef = {};	
	setmetatable(ret, {__index = MasteryBoardManager});
	ret:initialize();
	if masteryTable then
		ret:loadMasteryTable(masteryTable);
	end
	return ret;
end
function MasteryBoardManager.newWithObject(pcInfo, object, masteryTable)
	local ret = {Target = pcInfo, Object = object, TP = 0, MasteryTable = {}, SetMasteries = {}};
	ret.CategoryList = {'Basic', 'Sub', 'Attack', 'Defence', 'Ability'};
	for _, slot in ipairs(ret.CategoryList) do
		ret[slot] = {Count = 0, Cost = 0, Masteries = {}};
	end
	ret.MasterySet = {};
	ret.MasterySetRef = {};	
	setmetatable(ret, {__index = MasteryBoardManager});
	ret:initialize();
	if masteryTable then
		ret:loadMasteryTable(masteryTable);
	end
	return ret;
end
function MasteryBoardManager.newDummyPc(self)
	local dummy = WrapperObject.new(self.Target, {
		Object = WrapperObject.new(self.Object and self.Object or self.Target.Object),
	});
	-- MaxTP
	dummy:addCachedValue('MaxTP', function()
		return Get_MaxTrainingPoint(dummy, nil, self:getMasteryTable());
	end);
	-- MasteryCost
	dummy:addCachedValue('MaxBasicMasteryCost', function()
		return Get_MaxBasicMasteryCost_PC(dummy, nil, self:getMasteryTable());
	end);
	dummy:addCachedValue('MaxSubMasteryCost', function()
		return Get_MaxSubMasteryCost_PC(dummy, nil, self:getMasteryTable());
	end);
	dummy:addCachedValue('MaxAttackMasteryCost', function()
		return Get_MaxAttackMasteryCost_PC(dummy, nil, self:getMasteryTable());
	end);
	dummy:addCachedValue('MaxDefenceMasteryCost', function()
		return Get_MaxDefenceMasteryCost_PC(dummy, nil, self:getMasteryTable());
	end);
	dummy:addCachedValue('MaxAbilityMasteryCost', function()
		return Get_MaxAbilityMasteryCost_PC(dummy, nil, self:getMasteryTable());
	end);
	-- MasteryCount
	if dummy.RosterType == 'Machine' then
		dummy:addCachedValue('Base_MaxBasicMasteryCount', function()
			return CalculatedProperty_Machine_BaseMaxMasteryCount(dummy, 'Base_MaxBasicMasteryCount');
		end);
		dummy:addCachedValue('Base_MaxSubMasteryCount', function()
			return CalculatedProperty_Machine_BaseMaxMasteryCount(dummy, 'Base_MaxSubMasteryCount');
		end);
		dummy:addCachedValue('Base_MaxAttackMasteryCount', function()
			return CalculatedProperty_Machine_BaseMaxMasteryCount(dummy, 'Base_MaxAttackMasteryCount');
		end);
		dummy:addCachedValue('Base_MaxDefenceMasteryCount', function()
			return CalculatedProperty_Machine_BaseMaxMasteryCount(dummy, 'Base_MaxDefenceMasteryCount');
		end);
		dummy:addCachedValue('Base_MaxAbilityMasteryCount', function()
			return CalculatedProperty_Machine_BaseMaxMasteryCount(dummy, 'Base_MaxAbilityMasteryCount');
		end);
	end
	dummy:addCachedValue('MaxBasicMasteryCount', function()
		return Get_MaxMasteryCountByType_PC(dummy, 'MaxBasicMasteryCount');
	end);
	dummy:addCachedValue('MaxSubMasteryCount', function()
		return Get_MaxMasteryCountByType_PC(dummy, 'MaxSubMasteryCount');
	end);
	dummy:addCachedValue('MaxAttackMasteryCount', function()
		return Get_MaxMasteryCountByType_PC(dummy, 'MaxAttackMasteryCount');
	end);
	dummy:addCachedValue('MaxDefenceMasteryCount', function()
		return Get_MaxMasteryCountByType_PC(dummy, 'MaxDefenceMasteryCount');
	end);
	dummy:addCachedValue('MaxAbilityMasteryCount', function()
		return Get_MaxMasteryCountByType_PC(dummy, 'MaxAbilityMasteryCount');
	end);
	dummy:addCachedValue('ExtraMaxBasicMasteryCount', function()
		return Get_ExtraMaxBasicMasteryCount_PC(dummy, nil, self:getMasteryTable());
	end);
	dummy:addCachedValue('ExtraMaxSubMasteryCount', function()
		return Get_ExtraMaxSubMasteryCount_PC(dummy, nil, self:getMasteryTable());
	end);
	dummy:addCachedValue('ExtraMaxAttackMasteryCount', function()
		return Get_ExtraMaxAttackMasteryCount_PC(dummy, nil, self:getMasteryTable());
	end);
	dummy:addCachedValue('ExtraMaxDefenceMasteryCount', function()
		return Get_ExtraMaxDefenceMasteryCount_PC(dummy, nil, self:getMasteryTable());
	end);
	dummy:addCachedValue('ExtraMaxAbilityMasteryCount', function()
		return Get_ExtraMaxAbilityMasteryCount_PC(dummy, nil, self:getMasteryTable());
	end);
	return dummy;
end
function NewMasterySetRefs()
	local retMasterySet = {};
	local retMasterySetRef = {};
	if table.empty(retMasterySet) then
		local masterySetClsList = GetClassList('MasterySet');
		local columnList = { 'Mastery1', 'Mastery2', 'Mastery3', 'Mastery4' };	
		for setName, masterySetCls in pairs(masterySetClsList) do
			-- 필요 마스터리 체크
			local subList = {};
			for _, propName in ipairs(columnList) do
				local propValue = masterySetCls[propName];
				if propValue ~= 'None' then
					table.insert(subList, propValue);
				end	
			end
			local setInfo = { RefCount = 0, NeedCount = #subList, SubList = subList };
			retMasterySet[setName] = setInfo;
			for _, subName in ipairs(subList) do
				local refList = retMasterySetRef[subName] or {};
				table.insert(refList, { Set = setName, Ref = setInfo });
				retMasterySetRef[subName] = refList;
			end
		end
	end
	return retMasterySet, retMasterySetRef;
end
function MasteryBoardManager.initialize(self)
	-- TargetWrapper
	self.TargetWrapper = self:newDummyPc();
	-- MaxTP
	self.MaxTP = CachedValue.new(function()
		return self.TargetWrapper.MaxTP;
	end);
	-- MaxCost
	self['Basic'].MaxCost = CachedValue.new(function()
		return self.TargetWrapper.MaxBasicMasteryCost;
	end);
	self['Sub'].MaxCost = CachedValue.new(function()
		return self.TargetWrapper.MaxSubMasteryCost;
	end);
	self['Attack'].MaxCost = CachedValue.new(function()
		return self.TargetWrapper.MaxAttackMasteryCost;
	end);
	self['Defence'].MaxCost = CachedValue.new(function()
		return self.TargetWrapper.MaxDefenceMasteryCost;
	end);
	self['Ability'].MaxCost = CachedValue.new(function()
		return self.TargetWrapper.MaxAbilityMasteryCost;
	end);
	-- MaxCount
	self['Basic'].MaxCount = CachedValue.new(function()
		return self.TargetWrapper.MaxBasicMasteryCount;
	end);
	self['Sub'].MaxCount = CachedValue.new(function()
		return self.TargetWrapper.MaxSubMasteryCount;
	end);
	self['Attack'].MaxCount = CachedValue.new(function()
		return self.TargetWrapper.MaxAttackMasteryCount;
	end);
	self['Defence'].MaxCount = CachedValue.new(function()
		return self.TargetWrapper.MaxDefenceMasteryCount;
	end);
	self['Ability'].MaxCount = CachedValue.new(function()
		return self.TargetWrapper.MaxAbilityMasteryCount;
	end);
	-- ExtraCount
	self['Basic'].ExtraCount = CachedValue.new(function()
		return self.TargetWrapper.ExtraMaxBasicMasteryCount;
	end);
	self['Sub'].ExtraCount = CachedValue.new(function()
		return self.TargetWrapper.ExtraMaxSubMasteryCount;
	end);
	self['Attack'].ExtraCount = CachedValue.new(function()
		return self.TargetWrapper.ExtraMaxAttackMasteryCount;
	end);
	self['Defence'].ExtraCount = CachedValue.new(function()
		return self.TargetWrapper.ExtraMaxDefenceMasteryCount;
	end);
	self['Ability'].ExtraCount = CachedValue.new(function()
		return self.TargetWrapper.ExtraMaxAbilityMasteryCount;
	end);
	-- Unlock
	local slotToCategory = { Basic = 'Normal', Sub = 'Sub', Attack = 'Attack', Defence = 'Defence', Ability = 'Ability' };
	if self.TargetWrapper.Object.Race.name == 'Machine' then
		slotToCategory = { Basic = 'FrameModule', Sub = 'SupportModule', Attack = 'ComplementaryModule', Defence = 'SaftyModule', Ability = 'AIModule' };
	end
	for _, category in ipairs(self.CategoryList) do
		self[category].Unlock = CachedValue.new(function()
			return GetMasteryUnlockSlotCountByLv(slotToCategory[category], self.TargetWrapper.Lv) + self[category].ExtraCount:get();
		end);
	end
	-- MasterySet
	self.MasterySet, self.MasterySetRef = NewMasterySetRefs();
end
function MasteryBoardManager.invalidate(self)
	self.TargetWrapper:invalidate();
	self.MaxTP:invalidate();
	for _, slot in ipairs(self.CategoryList) do
		self[slot].MaxCost:invalidate();
		self[slot].MaxCount:invalidate();
		self[slot].Unlock:invalidate();
	end
end
function MasteryBoardManager.setLv(self, lv)
	self.TargetWrapper.Lv = lv;
	self.TargetWrapper.Object.Lv = lv;
	self:invalidate();
end
function MasteryBoardManager.setJob(self, jobName)
	self.TargetWrapper.Object.Job = WrapperObject.new(GetClassList('Job')[jobName]);
	self:invalidate();
end
function MasteryBoardManager.getTP(self)
	return self.TP;
end
function MasteryBoardManager.getMaxTP(self)
	return self.MaxTP:get();
end
function MasteryBoardManager.getRemainTP(self)
	return self:getMaxTP() - self:getTP();
end
function MasteryBoardManager.getCost(self, category)
	local slot = self[category];
	if not slot then
		return 0;
	else
		return slot.Cost;
	end
end
function MasteryBoardManager.getMaxCost(self, category)
	local slot = self[category];
	if not slot then
		return 0;
	else
		return slot.MaxCost:get();
	end
end
function MasteryBoardManager.getRemainCost(self, category)
	return self:getMaxCost(category) - self:getCost(category);
end
function MasteryBoardManager.getUnlock(self, category)
	local slot = self[category];
	if not slot then
		return 0;
	else
		return slot.Unlock:get();
	end
end
function MasteryBoardManager.getCount(self, category)
	local slot = self[category];
	if not slot then
		return 0;
	else
		return slot.Count;
	end
end
function MasteryBoardManager.getMaxCount(self, category, ignoreUnlock)
	local slot = self[category];
	if not slot then
		return 0;
	elseif ignoreUnlock then
		return slot.MaxCount:get();
	else
		return math.min(slot.MaxCount:get(), slot.Unlock:get());
	end
end
function MasteryBoardManager.getRemainCount(self, category)
	return self:getMaxCount(category) - self:getCount(category);
end
function MasteryBoardManager.getMasteryByCategory(self, category, host)
	local ret = {};
	if category == 'Set' then
		ret = table.shallowcopy(self.SetMasteries);
	else
		local slot = self[category];
		if slot then
			ret = table.shallowcopy(slot.Masteries);
		end
	end
	if host then
		ret = table.map(ret, function(wo) return wo:getHost() end);
	end
	return ret;
end
function MasteryBoardManager.getMasteryTable(self, host)
	local ret = table.shallowcopy(self.MasteryTable);
	for _, mastery in ipairs(self.SetMasteries) do
		ret[mastery.name] = mastery;
	end
	if host then
		ret = table.map(ret, function(wo) return wo:getHost() end);
	end
	return ret;
end
function MasteryBoardManager.loadMasteryTable(self, masteryTable)
	self.MasteryTable = {};
	self.SetMasteries = {};
	self.TP = 0;
	for _, slot in ipairs(self.CategoryList) do
		self[slot].Count = 0;
		self[slot].Cost = 0;
		self[slot].Masteries = {};
	end
	for masteryName, mastery in pairs(masteryTable) do
		if mastery.Lv > 0 and mastery.Category.name ~= 'Set' then
			-- 이미 더미 데이터면 재사용한다.
			if type(mastery) ~= 'table' then
				mastery = self:newDummyMastery(masteryName);
			end
			self:_addMastery(mastery);
		end
	end
	self:buildSetMastery();
	self:invalidate();
end
function MasteryBoardManager.buildSetMastery(self)
	self.SetMasteries = {};
	for setName, setInfo in pairs(self.MasterySet) do
		if setInfo.RefCount == setInfo.NeedCount then
			table.insert(self.SetMasteries, self:newDummyMastery(setName));
		end
	end
end
function MasteryBoardManager.doValidAction(self, actionFunc)
	if not self:isValid() then
		return false;
	end
	local masteryTable = table.shallowcopy(self.MasteryTable);
	actionFunc();
	if self:isValid() then
		return true;
	end
	self:loadMasteryTable(masteryTable);
	return false;
end
function MasteryBoardManager.newDummyMastery(self, mastery)
	-- Lv을 1로 넘겨주는 더미 데이터를 생성
	local masteryCls = nil;
	if type(mastery) == 'string' then
		masteryCls = GetClassList('Mastery')[mastery];
	elseif type(mastery) == 'table' then
		masteryCls = mastery:getHost();
	else
		masteryCls = mastery;
	end
	return WrapperObject.new(masteryCls, { Lv = 1 });
end
function MasteryBoardManager._addMastery(self, mastery)
	self.MasteryTable[mastery.name] = mastery;
	self.TP = self.TP + mastery.Cost;
	local slots = self[mastery.Category.EquipSlot];
	if slots then
		slots.Count = slots.Count + 1;
		slots.Cost = slots.Cost + mastery.Cost;
		table.insert(slots.Masteries, mastery);
	end
	local needBuildSetMastery = false;
	local refList = self.MasterySetRef[mastery.name];
	if refList then
		for _, refInfo in ipairs(refList) do
			refInfo.Ref.RefCount = refInfo.Ref.RefCount + 1;
			if refInfo.Ref.RefCount == refInfo.Ref.NeedCount then
				needBuildSetMastery = true;
			end
		end
	end
	return needBuildSetMastery;	
end
function MasteryBoardManager.isEnableAddMastery(self, masteryName)
	local mastery = GetClassList('Mastery')[masteryName];
	if not mastery then
		return false, 'NotExist';
	end
	if self.MasteryTable[masteryName] ~= nil then
		return false, 'Duplicated';
	end	
	local category = mastery.Category.EquipSlot;
	local slots = self[category];
	if not slots then
		return false, 'InvalidCategory';
	end
	local reason = {};
	if not IsEnableByMasteryCheckType(self.TargetWrapper, mastery, reason) then
		return false, 'NotEnableType';
	end
	if self:getRemainTP() < mastery.Cost then
		return false, 'RemainTP';
	end	
	if self:getRemainCost(category) < mastery.Cost then
		return false, 'RemainSlotCost';
	end
	if self:getRemainCount(category) <= 0 then
		return false, 'RemainSlotCount';
	end
	-- 배타적 마스터리 체크
	for _, masteryName in ipairs(mastery.ExclusiveMastery) do
		if self.MasteryTable[masteryName] ~= nil then
			return false, 'ExclusiveMastery';
		end
	end
	return true;
end
function MasteryBoardManager.hasMastery(self, masteryName)
	if self.MasteryTable[masteryName] ~= nil then
		return true;
	end
	for _, mastery in ipairs(self.SetMasteries) do
		if mastery.name == masteryName then
			return true;
		end
	end
	return false;
end
function MasteryBoardManager.addMastery(self, masteryName, noCheck)
	if not noCheck then
		if not self:isEnableAddMastery(masteryName) then
			return false;
		end
	end
	local mastery = self:newDummyMastery(masteryName);
	local needBuildSetMastery = self:_addMastery(mastery);
	if needBuildSetMastery then
		self:buildSetMastery();
	end
	self:invalidate();
	return true;
end
function MasteryBoardManager.removeMastery(self, masteryName)
	if self.MasteryTable[masteryName] == nil then
		return false;
	end
	local mastery = self.MasteryTable[masteryName];
	self.MasteryTable[masteryName] = nil;
	self.TP = self.TP - mastery.Cost;
	local slots = self[mastery.Category.EquipSlot];
	if slots then
		slots.Count = slots.Count - 1;
		slots.Cost = slots.Cost - mastery.Cost;
		slots.Masteries = table.filter(slots.Masteries, function(mastery)
			return mastery.name ~= masteryName;
		end);
	end
	-- 하나만 빠져도 세트 특성은 해제됨
	local needBuildSetMastery = false;
	local refList = self.MasterySetRef[masteryName];
	if refList then
		for _, refInfo in ipairs(refList) do
			refInfo.Ref.RefCount = refInfo.Ref.RefCount - 1;
			needBuildSetMastery = true;
		end
	end
	if needBuildSetMastery then
		self:buildSetMastery();
	end
	self:invalidate();
	return true;
end
function MasteryBoardManager.isValid(self)
	return self:isValidTP() and self:isValidCost() and self:isValidCount();
end
function MasteryBoardManager.isValidTP(self)
	return self.TP <= self.MaxTP:get();
end
function MasteryBoardManager.isValidCost(self, category)
	if category ~= nil then
		return self:getCost(category) <= self:getMaxCost(category);
	else
		for _, category in ipairs(self.CategoryList) do
			if not self:isValidCost(category) then
				return false;
			end
		end
		return true;
	end
end
function MasteryBoardManager.isValidCount(self, category)
	if category ~= nil then
		return self:getCount(category) <= self:getMaxCount(category);
	else
		for _, category in ipairs(self.CategoryList) do
			if not self:isValidCount(category) then
				return false;
			end
		end
		return true;
	end
end
function MasteryBoardManager.dumpStr(self, shortForm)
	if shortForm then
		local masteryList = {};	
		for _, category in ipairs(self.CategoryList) do
			local masteries = self:getMasteryByCategory(category);
			table.sort(masteries, function (a, b)
				return a.Cost < b.Cost;
			end);
			if #masteries > 0 then
				table.append(masteryList, table.map(masteries, function(mastery)
					return mastery.name;
				end));
			end
		end
		-- 세트 정보
		local setList = self:getMasteryByCategory('Set');
		if #setList > 0 then
			table.append(masteryList, table.map(setList, function(mastery)
				return mastery.name;
			end));
		end
		return table.concat(masteryList, ', ');
	end

	local text = '';
	local target = self.TargetWrapper;
	local job = target.Object.Job;	
	text = text..string.format('name: %s, Lv: %d, Job: %s', target.name, target.Lv, job and job.name or 'None');

	-- 훈련 점수
	text = text..', '..string.format('TP: (%d/%d)', self:getTP(), self:getMaxTP());

	-- 타입별 정보
	for _, category in ipairs(self.CategoryList) do
		text = text..'\n'..string.format('%s - Count: (%d/%d) Cost: (%d/%d)',
			category, self:getCount(category), self:getMaxCount(category), self:getCost(category), self:getMaxCost(category));
		
		local masteries = self:getMasteryByCategory(category);
		table.sort(masteries, function (a, b)
			return a.Cost < b.Cost;
		end);
		
		local maxCount = self:getMaxCount(category, true);
		local unlockCount = self:getUnlock(category);
		
		local masteryTextList = {};
		for i = 1, math.max(maxCount, #masteries) do
			if i <= #masteries then
				local mastery = masteries[i];
				local masteryText = string.format('%s (%d)', mastery.name, mastery.Cost)
				if i > unlockCount then
					masteryText = string.format('[!%s]', masteryText);
				end
				table.insert(masteryTextList, masteryText);
			elseif i > maxCount then
				-- 최대 개수를 초과했으면 무시
			elseif i <= unlockCount then
				table.insert(masteryTextList, '_');
			else
				table.insert(masteryTextList, 'X');
			end
		end
		text = text..'\n- '..table.concat(masteryTextList, ', ');
	end
	
	-- 세트 정보
	local setList = self:getMasteryByCategory('Set');
	if #setList > 0 then
		text = text..'\n'..'Set';
		text = text..'\n- '..table.concat(table.map(setList, function(mastery)
			return mastery.name;
		end), ', ');
	end
	
	return text;
end
function MasteryBoardManager.isEnableRemoveMastery(self, masteryName)
	local reason = {};
	if not self:hasMastery(masteryName) then
		return false, reason;
	end
	if self:isValid() then
		-- 해제하고 특성판이 망가지지만 않으면 다 허용
		local masteryTable = table.shallowcopy(self.MasteryTable);
		self:removeMastery(masteryName);
		if self:isValid() then
			return true, reason;
		end
		if not self:isValidTP() then
			table.insert(reason, 'OverTP');
		end
		if not self:isValidCost() then
			table.insert(reason, 'OverTPByCategory');
		end
		if not self:isValidCount() then
			table.insert(reason, 'OverCountByCategory');
		end
		self:loadMasteryTable(masteryTable);
		return false, reason;
	else
		local prevRemainTP = self:getRemainTP();
		local prevState = {};
		for _, category in ipairs(self.CategoryList) do
			prevState[category] = { Cost = self:getRemainCost(category), Count = self:getRemainCount(category) };			
		end
		self:removeMastery(masteryName);
		-- 해제하고 유효하면 OK
		if self:isValid() then
			return true, reason;
		end
		local enable = true;
		-- TP가 부족한데 남는 TP가 오히려 줄었으면 거절
		local remainTP = self:getRemainTP();
		if remainTP < 0 and remainTP < prevRemainTP then
			enable = false;
			table.insert(reason, 'OverTP');
		end
		local reasonSet = {};
		for _, category in ipairs(self.CategoryList) do
			-- Cost가 부족한데 남는 Cost가 오히려 줄었으면 거절
			local remainCost = self:getRemainCost(category);
			if remainCost < 0 and remainCost < prevState[category].Cost then
				enable = false;
				if not reasonSet.Cost then
					table.insert(reason, 'OverTPByCategory');
					reasonSet.Cost = true;
				end
			end
			-- 슬롯 개수가 부족한데 남는 슬롯 개수가 오히려 줄었으면 거절
			local remainCount = self:getRemainCount(category);
			if remainCount < 0 and remainCount < prevState[category].Count then
				enable = false;
				if not reasonSet.Count then
					table.insert(reason, 'OverCountByCategory');
					reasonSet.Count = true;
				end
			end
		end
		self:loadMasteryTable(masteryTable);
		return enable, reason;	
	end	
end

function CalculatedProperty_InfoRange(obj)
	return obj.Base_InfoRange;
end

function CalculatedProperty_InfoRange_MoraleBoosting(obj)
	local owner = GetMasteryOwner(obj);
	if owner == nil then
		return CalculatedProperty_InfoRange(obj);
	end
	local mastery_GeneralSpirit = GetMasteryMastered(GetMastery(owner), 'GeneralSpirit');
	if mastery_GeneralSpirit == nil then
		return CalculatedProperty_InfoRange(obj);
	end
	return mastery_GeneralSpirit.Range;
end

function CalculatedProperty_InfoRange_CatharsisOfIncineration(obj)
	local owner = GetMasteryOwner(obj);
	if owner == nil then
		return CalculatedProperty_InfoRange(obj);
	end
	local mastery_SeaOfFire = GetMasteryMastered(GetMastery(owner), 'SeaOfFire');
	if mastery_SeaOfFire == nil then
		return CalculatedProperty_InfoRange(obj);
	end
	return mastery_SeaOfFire.Range;
end

function CalculatedProperty_InfoRange_Hideout(obj)
	local owner = GetMasteryOwner(obj);
	if owner == nil then
		return CalculatedProperty_InfoRange(obj);
	end
	
	local masteryTable = GetMastery(owner);
	-- 너보다 조금 더 높은 곳에
	local mastery_HigherThanYou = GetMasteryMastered(masteryTable, 'HigherThanYou');	
	-- 초원의 사냥꾼
	local mastery_BushHunting = GetMasteryMastered(masteryTable, 'BushHunting');
	
	if mastery_HigherThanYou then
		return 'MoveRange'..mastery_HigherThanYou.ApplyAmount;
	elseif mastery_BushHunting then
		return 'MoveRange'..mastery_BushHunting.ApplyAmount;
	end
	return CalculatedProperty_InfoRange(obj);
end

function CalculatedProperty_InfoRange_Conflagration(obj)
	local owner = GetMasteryOwner(obj);
	if owner == nil then
		return CalculatedProperty_InfoRange(obj);
	end
	local mastery_SeaOfFire = GetMasteryMastered(GetMastery(owner), 'SeaOfFire');
	if mastery_SeaOfFire == nil then
		return CalculatedProperty_InfoRange(obj);
	end
	return mastery_SeaOfFire.Range;
end

function CalculatedProperty_MasteryRefAbilityType(obj, arg)
	if obj.Idspace == 'Text' then
		return '$White$'..obj.Text..'$Blue_ON$';
	end
	local idSpace = GetClassList(obj.Idspace);
	if not idSpace then
		return '$Red$ERROR_MASTERY_ABILITYTYPE_IDSPACE$Blue_ON$';
	end
	local cls = GetWithoutError(idSpace, obj.Key);
	if not cls then
		return '$Red$ERROR_MASTERY_ABILITYTYPE_CLASS$Blue_ON$';
	end
	local title = cls.Title;
	if obj.Short and cls.Title_Short then
		title = cls.Title_Short;
	end
	local result = '$White$'..title..'$Blue_ON$';
	return result;
end

function CalculatedProperty_MasteryTitle(obj, arg)
	local result = '';
	if obj.Category.name == 'Equipment' and obj.Type.name == 'Equipment' then
		local itemList = GetClassList('Item');
		local item = itemList[obj.name];
		if item then
			result = item.Base_Title;
		else
			result = '[Error] ItemName_'..obj.name;
		end
	else
		result = obj.Base_Title;
	end
	return result;
end

function CalculatedProperty_MasteryBoardRCount(obj, arg)
	return obj.Count + obj.ExtraCount;
end