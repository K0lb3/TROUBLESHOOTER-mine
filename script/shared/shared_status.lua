---------------------------------------------------
--	기본 독립 함수										
---------------------------------------------------
---------------------------------------------------
-- Object
---------------------------------------------------
function GetBuffStatusCustom(self, stat, baseValue, op)
	if IsClass(self) then
		return baseValue;
	end
	local value = baseValue;
	if value == nil then
		value = 0;
	end
	op = op or function (from, another) return from + another; end;	-- 기본값으로 부터 시작해서 각 버프들에서 얻어진 값들에 대한 연산 함수
	
	if _G['GetBuffList'] == nil then
		return baseValue;
	end
	
	local buffList = GetBuffList(self);
	if buffList ~= nil then
		for i = 1, #buffList do
			local curBuff = buffList[i];
			local statValue = GetWithoutError(curBuff, stat);
			if statValue ~= nil then
				value = op(value, statValue);
			end
		end
	end
	return value;
end
function GetMission_Shared(self)
	if IsMissionServer() then
		return GetMission(self);
	elseif IsClient() then
		local session = GetSession();
		return session.current_mission;
	else
		return nil;
	end
end
function Get_WaitTime(self)
	if GetInstantProperty(self, 'NoWait') then
		return 1;
	end
	if self.NoTurn then
		return 999999;
	end
	local conditionalSpeed = GetConditionalStatus(self, 'Speed', {}, {MissionTemperature = GetMission_Shared(self).Temperature.name});
	local result = GetActionTime(self.Speed + conditionalSpeed, self.AddWait);
	return result;
end
function GetActionTime(speed, addtime)
	local result = 18 + 3600/speed + addtime;
	result = math.min(360, math.max(36, result));
	return math.floor(result);
end
-- 장비 슬롯 
function GetEquipmentList(obj, data)
	local equipments = GetClassList('Equipment');
	local list = {};
	if data then
		if data.Equipments then
			local itemList = GetClassList('Item');
			for key, value in pairs (data.Equipments) do
				table.insert(list, itemList[value]);
			end
		end
	else
		for key, value in pairs (equipments) do
			table.insert(list, obj[key]);
			if obj[key] == nil then
				LogAndPrint('GetEquipmentList:: 없음', key, debug.traceback());
			end
		end
	end
	return list;
end
--------------------------------------------------------------
--	장착장비 리스트 이름 리턴, object.xml 상단에 idspace Equipment에 등록									
--------------------------------------------------------------
__EquipmentSlotList = nil;
function GetEquipmentName()
	if __EquipmentSlotList then
		return __EquipmentSlotList;
	end
	local equipments = GetClassList('Equipment');
	local list = {};
	for key, value in pairs (equipments) do
		table.insert(list, key);
	end
	table.scoresort(list, function(key) return equipments[key].Order; end);
	__EquipmentSlotList = list;
	return list;
end
--------------------------------------------------------------
--	미션 들어갈 떄 서버에서 호출하는 함수.
--  지우면 미션서버 죽음.										
--------------------------------------------------------------
function GetItemSlotList()	
	return GetEquipmentName();
end
--------------------------------------------------------------
--	Status 커스터마이징 함수										
--------------------------------------------------------------
-- 능력치로 상승되는 부분
--------------------------------------------------------------
--------------------------------------------------------------
--	Status 공용 함수										
--------------------------------------------------------------
-- 오브젝트 능력치 받아오는 함수
-- 오브젝트 능력치 + 아이템 총합 + 특성 값 + 버프 값(전투중만)
---------------------------------------------------------------
function CalculatedProperty_Status(obj, arg, data)
	local result = CalculatedProperty_Status_BaseValue(obj, arg, data);
	-- 커스터마이징 값.
	local script = _G['CalculatedProperty_SpecialCase_'..arg];
	if script ~= nil then
		local succ, scValue = pcall(script, obj, arg, data);
		if not succ then
			LogAndPrint('Error', 'SpecialCase', scValue);
		else
			result = result + scValue;
		end
	end
	-- 직업 값.
	local jobScript = _G['CalculatedProperty_JobStatus_'..arg];
	if jobScript ~= nil then
		local succ, jobValue = pcall(jobScript, obj.Job, arg, data and data.Lv or obj.Lv);
		if not succ then
			LogAndPrint('Error', 'JobValue', jobValue);
		else
			result = result + jobValue;
		end
	end
	result = CheckLimitValue(arg, result, obj);
	return ValueLimiting(arg, result);
end
function CalculatedProperty_Status_Customized_MaxCost(obj, arg, data)
	local result = 0;
	if obj.CostType and obj.CostType.name and obj.CostType.name ~= 'None' then
		local propertyKey = 'Max'..obj.CostType.name;
		result = obj[propertyKey];
	end
	return ValueLimiting(arg, result);
end
function CalculatedProperty_Status_Customized_RegenCost(obj, arg, data)
	local result = 0;
	if obj.CostType and obj.CostType.name and obj.CostType.name ~= 'None' then
		local propertyKey = 'Regen'..obj.CostType.name;
		result = obj[propertyKey];
	end
	return ValueLimiting(arg, result);
end
function CalculatedProperty_Status_Customized_MaxSP(obj, arg, data)
	local result = 0;
	if obj.ESP and obj.ESP.name then
		local properetyType = obj.ESP.name;
		local properety = obj.ESP.name..'Point';
		local maxValuePropertyKey = 'Max'..properety;
		result = obj[maxValuePropertyKey] + obj.MaxAddSP;
	end
	return ValueLimiting(arg, result);
end
function CalculatedProperty_Status_Customized_MaximumLoad(obj, arg, data)
	local originalValue = CalculatedProperty_Status(obj, arg, data);
	local ret = originalValue * (1 + obj.IncreaseMaximumLoad / 100);
	return ValueLimiting(arg, ret);
end
function CalculatedProperty_Status_Customized_MaxPower(obj, arg, data)
	local result = 0;
	if SafeIndex(obj, 'Race', 'name') == 'Machine' then
		result = CalculatedProperty_Status_BaseValue(obj, arg, data);
	end
	result = CheckLimitValue(arg, result);
	return ValueLimiting(arg, result);
end
function CalculatedProperty_Status_Boolean_Or(obj, arg)
	local or_operator = function(base, new) 
		return base or new; 
	end;
	return CalculatedProperty_Status_Custom_Base(obj, arg, or_operator, false);
end
function CalculatedProperty_Status_Boolean_And(obj, arg)
	local or_operator = function(base, new) return base and new; end;
	return CalculatedProperty_Status_Custom_Base(obj, arg, or_operator, true);
end
function CalculatedProperty_Status_Custom_Base(obj, arg, operation, default)
	local baseValue = GetWithoutError(obj, 'Base_'..arg);
	if baseValue == nil then
		baseValue = default;
	end
	local itemApplied = CalculatedProeprty_Status_Item_Custom(obj, arg, operation, baseValue);
	local masteryApplied = CalculatedProperty_Status_Mastery_Custom(obj, arg, operation, itemApplied);
	return CalculatedProperty_Status_Buff_Custom(obj, arg, operation, masteryApplied);
end
function CalculatedProperty_Status_BaseValue(obj, arg, data)
	local result = 0;
	-- 1. 초기 값 가져오기 
	local result = GetWithoutError(obj, 'Base_'..arg) or 0;
	-- 2. 아이템 값 가져오기
	
	local succ, itemStat = pcall(CalculatedProperty_Status_Item, obj, arg, data);
	if not succ then
		LogAndPrint('ERROR', 'ItemStatus', itemStat);
	else
		result = result + itemStat;
	end
    -- 3. 특성값 가져오기
	local succ, masteryStat = pcall(CalculatedProperty_Status_Mastery, obj, arg, data);
	if not succ then
		LogAndPrint('ERROR', 'MasteryStatus', masteryStat);
	else
		result = result + masteryStat;
	end
	if not IsMission() then
		return result;
	end
	-- 4. 버프값 가져오기 / 전투 중 일때만
	local prev = result;
	local buffList = GetBuffList(obj);
	if buffList ~= nil then
		for i = 1, #buffList do
			local curBuff = buffList[i];
			local applyValue = GetWithoutError(curBuff, arg);
			if applyValue and applyValue ~= 'None' then
				result = result + applyValue;
			end
		end
	end
	-- 5. 공연 효과
	if obj.PerformanceType ~= 'None' then
		result = result + CalculatedProperty_Status_PerformanceEffect(obj, arg, data);
	end
	return result;
end
function CalculatedProperty_Status_Item(obj, arg, data)
	local result = 0;
	local info = {};
	local equipments = GetEquipmentList(obj, data);
	for i = 1, #equipments do
		local curEquip = equipments[i];
		if curEquip ~= nil then
			local newValue = GetWithoutError(curEquip, arg);
			if newValue and newValue ~= 'None' then
				if newValue ~= 0 then
					table.insert(info, { Type = curEquip.name, Value = newValue, ValueType = 'Equipment'});
				end
				result = result + newValue;
			end
		end
	end
	-- 장비 아이템 증감.
	if result > 0 then
		-- IncreaseEquipment_ 스탯
		local increaseEquipmentAmount = GetIncreaseEquipmentAmount(info, obj, result, arg);
		-- 강화된 기체
		local mastery_Module_EnhancedFrame = GetMasteryMasteredWithData(obj, 'Module_EnhancedFrame', data);
		if mastery_Module_EnhancedFrame then
			local isEnable = {
				Armor = true,
				Resistance = true,
				AttackPower = true,
				ESPPower = true,
				MaxHP = true,
			};
			if isEnable[arg] then
				local addAmount = math.floor(result * mastery_Module_EnhancedFrame.ApplyAmount / 100);
				if addAmount ~= 0 then
					increaseEquipmentAmount = increaseEquipmentAmount + addAmount;
					table.insert(info, MakeMasteryStatInfo(mastery_Module_EnhancedFrame.name, addAmount));
				end
				-- 보조 강화 프로그램
				local mastery_Module_SubEnhancement = GetMasteryMasteredWithData(obj, 'Module_SubEnhancement', data);
				if mastery_Module_SubEnhancement then
					local applyAmount = math.floor(mastery_Module_SubEnhancement.CustomCacheData / mastery_Module_SubEnhancement.ApplyAmount) * mastery_Module_SubEnhancement.ApplyAmount2;
					local addAmount = math.floor(result * applyAmount / 100);
					if addAmount ~= 0 then
						increaseEquipmentAmount = increaseEquipmentAmount + addAmount;
						table.insert(info, MakeMasteryStatInfo(mastery_Module_SubEnhancement.name, addAmount));
					end
				end
			end
		end
		result = result + increaseEquipmentAmount;
	end
	-- 무기의 달인 (무기 카테고리 한정)
	local mastery_Weaponmaster = GetMasteryMasteredWithData(obj, 'Weaponmaster', data);
	if mastery_Weaponmaster and (arg == 'AttackPower' or arg == 'ESPPower') then
		local applyAmount = mastery_Weaponmaster.ApplyAmount;
		-- 백병전의 달인
		local mastery_MeleeBattleMaster = GetMasteryMasteredWithData(obj, 'MeleeBattleMaster', data);
		if mastery_MeleeBattleMaster then
			applyAmount = applyAmount + mastery_MeleeBattleMaster.ApplyAmount;
		end
		local weaponAmount = 0;
		for i = 1, #equipments do
			local curEquip = equipments[i];
			if curEquip and curEquip.name and curEquip.Category.name == 'Weapon' then
				local newValue = GetWithoutError(curEquip, arg);
				if newValue and newValue ~= 'None' then
					weaponAmount = weaponAmount + newValue;
				end
			end
		end	
		if weaponAmount > 0 then
			local addAmount = math.floor(weaponAmount * applyAmount / 100);
			if addAmount ~= 0 then
				result = result + addAmount;
				table.insert(info, MakeMasteryStatInfo(mastery_Weaponmaster.name, addAmount));
			end
		end
	end
	return result, info;
end
local IncreaseEquipmentComposer = nil;
function GetIncreaseEquipmentAmount(info, obj, newValue, arg)
	local isEnable = {
		Armor = true,
		Resistance = true,
		AttackPower = true,
		ESPPower = true,
		MaxFuel = true,
	};
	local increaseEquipment_Add = 0;
	if isEnable[arg] then
		local curKey = 'IncreaseEquipment_'..arg;
		local curValue = obj[curKey];
		local infos = GetStatusInfo(obj, curKey, nil, true);
		if #infos > 0 or curValue ~= 0 then
			if IncreaseEquipmentComposer == nil then
				IncreaseEquipmentComposer = BattleFormulaComposer.new('math.floor(Base * (1 + (Plus - Minus) / 100))', {'Base', 'Plus', 'Minus'});
			end
			iec = IncreaseEquipmentComposer:Clone();
			iec:AddDecompData('Base', newValue, {});
			local plusInfos = {};
			local minusInfos = {};
			for _, info in ipairs(infos) do
				if info.Value >= 0 then
					table.insert(plusInfos, info);
				else
					info.Value = -info.Value;
					table.insert(minusInfos, info);
				end
			end
			local plusValue = table.sum(plusInfos, function(info) return info.Value end, 0);
			local minusValue = table.sum(minusInfos, function(info) return info.Value end, 0);
			iec:AddDecompData('Plus', curValue + minusValue, plusInfos);
			iec:AddDecompData('Minus', minusValue, minusInfos);
			
			increaseEquipment_Add = iec:ComposeFormula() - newValue;
			local retInfos = iec:ComposeInfoTable();
			table.append(info, retInfos);
		end
	end
	return increaseEquipment_Add;
end
function CalculatedProeprty_Status_Item_Custom(obj, arg, operation, startValue)
	local result = startValue;
	local equipments = GetEquipmentList(obj);
	for i = 1, #equipments do
		local curEquip = equipments[i];
		if curEquip ~= nil then
			local newValue = GetWithoutError(curEquip, arg);
			if newValue and newValue ~= 'None' then
				result = operation(result, newValue);
			end
		end
	end
	return result;
end
function CalculatedProperty_Status_Buff(obj, arg)
	local result = 0;
	-- 클래스는 버프를 받아올 수 없으므로 바로 리턴
	if IsClass(obj) then
		return result;
	end
	local buffList = GetBuffList(obj);	
	for i = 1, #buffList do
		local curBuff = buffList[i];
		result = result + curBuff[arg];
	end
	return result;
end
function CalculatedProperty_Status_Mastery(obj, arg, data)
	local result = 0;
	-- data 인자가 없으면 클래스는 특성을 받아올 수 없으므로 바로 리턴
	if IsClass(obj) and data == nil then
		return result;
	end
	if data then
		if data.Masteries then
			local masteryList = GetClassList('Mastery');
			for key, value in pairs(data.Masteries) do
				if value > 0 then
					local applyValue = GetWithoutError(masteryList[key], arg);
					if applyValue and applyValue ~= 'None' then
						result = result + applyValue;
					end
				end
			end
		end
	else
		local masteryTable = GetMastery(obj);
		for mType, mastery in pairs(masteryTable) do
			if mastery.Lv and mastery.Lv > 0 then
				local applyValue = GetWithoutError(mastery, arg);
				if applyValue and applyValue ~= 'None' then
					result = result + applyValue;
				end
			end
		end
	end
	local script = _G['CalculatedProperty_SpecialCase_Mastery_'..arg];
	if script ~= nil then
		result = result + script(obj, arg, data);
	end
	return result;
end
function CalculatedProperty_Status_Cloaking(obj, arg, data)
	return CalculatedProperty_Status_Boolean_Or(obj, arg, data);
end
---------------------------------------------------------------------------------------
-- CalculatedProperty_SpecialCase_Mastery_ 스테이터스에서 특성으로 추가계산해주는 부분.
---------------------------------------------------------------------------------------
function _GetAdditionalMasteryStatusByLevel(obj, masteryName, data, key)
	local result = 0;
	if data then
		local masteryList = GetClassList('Mastery');
		if data.Masteries[masteryName] then
			local mastery = masteryList[masteryName];
			result = result + data.Lv * mastery[key];
		end
	else
		local masteryTable = GetMastery(obj);
		local mastery = GetMasteryMastered(masteryTable, masteryName);
		if mastery then
			result = result + obj.Lv * mastery[key];
		end
	end
	return result;
end
function GetAdditionalMasteryStatusByLevel(obj, masteryName, data)
	return _GetAdditionalMasteryStatusByLevel(obj, masteryName, data, 'ApplyAmount');
end
function GetAdditionalMasteryStatusByLevel2(obj, masteryName, data)
	return _GetAdditionalMasteryStatusByLevel(obj, masteryName, data, 'ApplyAmount2');
end
function GetAdditionalMasteryStatusByLevelWithInfo(obj, masteryName, data, info)
	local addVal = GetAdditionalMasteryStatusByLevel(obj, masteryName, data);
	if addVal ~= 0 then
		table.insert(info, MakeMasteryStatInfo(masteryName, addVal));
	end
	return addVal;
end
function GetAdditionalMasteryStatusByLevelWithInfo2(obj, masteryName, data, info)
	local addVal = GetAdditionalMasteryStatusByLevel2(obj, masteryName, data);
	if addVal ~= 0 then
		table.insert(info, MakeMasteryStatInfo(masteryName, addVal));
	end
	return addVal;
end
---------------------------------------------------------------------------------------
-- CalculatedProperty_SpecialCase_Mastery_ 스테이터스에서 특성으로 추가계산해주는 부분.
---------------------------------------------------------------------------------------
function GetAdditionalMasteryStatusByCost(obj, masteryName, data)
	local result = 0;
	if data then
		local masteryList = GetClassList('Mastery');
		if data.Masteries[masteryName] then
			local mastery = masteryList[masteryName];
			local maxCost = data.MaxCost;
			if not cost then
				maxCost = obj.MaxCost;
			end
			result = result + maxCost * mastery.ApplyAmount;
		end
	else
		local masteryTable = GetMastery(obj);
		local mastery = GetMasteryMastered(masteryTable, masteryName);
		if mastery then
			result = result + obj.MaxCost * mastery.ApplyAmount;
		end
	end
	return result;
end
function GetAdditionalMasteryStatusByCostWithInfo(obj, masteryName, data, info)
	local addVal = GetAdditionalMasteryStatusByCost(obj, masteryName, data);
	if addVal ~= 0 then
		table.insert(info, MakeMasteryStatInfo(masteryName, addVal));
	end
	return addVal;
end
---------------------------------------------------------------------------------------
-- CalculatedProperty_SpecialCase_Mastery_ 스테이터스에서 특성으로 추가계산해주는 부분.
---------------------------------------------------------------------------------------
function GetAdditionalMasteryStatusByMasteryCount(obj, masteryName, data, ifFunc, field)
	local result = 0;
	if not field then
		field = 'ApplyAmount';
	end	
	if data then
		local masteryList = GetClassList('Mastery');
		if data.Masteries[masteryName] then
			local mastery = masteryList[masteryName];
			local matchedMasteryCount = 0;
			for k, v in pairs(data.Masteries) do
				if v and ifFunc(masteryList[k]) then
					matchedMasteryCount = matchedMasteryCount + 1;
				end
			end
			if matchedMasteryCount > 0 then
				result = result + matchedMasteryCount * mastery[field];
			end
		end
	else
		local masteryTable = GetMastery(obj);
		local mastery = GetMasteryMastered(masteryTable, masteryName);
		if mastery then
			local matchedMasteryCount = table.count(masteryTable, ifFunc);
			if matchedMasteryCount > 0 then
				result = result + matchedMasteryCount * mastery[field];
			end
		end
	end
	return result;
end
function GetAdditionalMasteryStatusByCustomFunc(obj, masteryName, data, customFunc)
	if data then
		local masteryList = GetClassList('Mastery');
		if data.Masteries[masteryName] then
			local mastery = masteryList[masteryName];
			return customFunc(data, mastery);
		end
	else
		local masteryTable = GetMastery(obj);
		local mastery = GetMasteryMastered(masteryTable, masteryName);
		if mastery then
			return customFunc(obj, mastery);
		end
	end
	return 0;
end
function GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, masteryName, data, info, customFunc)
	local addVal = GetAdditionalMasteryStatusByCustomFunc(obj, masteryName, data, customFunc);
	if addVal ~= 0 then
		table.insert(info, MakeMasteryStatInfo(masteryName, addVal));
	end
	return addVal;
end
function GetAdditionalPerformanceStatusWithInfo(obj, effectName, info)
	local effectCls = GetClassList('PerformanceEffect')[effectName];
	if not effectCls then
		return 0;
	end	
	local effectLv = 0;
	local performanceList = GetInstantProperty(obj, 'PerformanceList') or {};
	for _, info in ipairs(performanceList) do
		if info.Type == effectName then
			effectLv = effectLv + info.Lv;
		end
	end
	if effectLv == 0 then
		return 0;
	end
	local addVal = effectCls.ApplyAmount * effectLv;
	if addVal ~= 0 then
		table.insert(info, { Type = effectName, Value = addVal, ValueType = 'PerformanceEffect' });
	end
	return addVal;
end
--------------------------------------------------------------------------------------
function GetMasteryMasteredWithData(obj, masteryName, data)
	local mastery = nil;
	if data then
		local value = data.Masteries[masteryName];
		if value and value > 0 then
			local masteryList = GetClassList('Mastery');
			mastery = masteryList[masteryName];
		end
	else
		local masteryTable = GetMastery(obj);
		mastery = GetMasteryMastered(masteryTable, masteryName);
	end
	return mastery;
end
function GetMasteryStatus(obj, masteryName, data, statusName)
	local result = 0;
	if data then
		local masteryList = GetClassList('Mastery');
		if data.Masteries[masteryName] then
			local mastery = masteryList[masteryName];
			result = GetWithoutError(mastery, statusName);
		end
	else
		local masteryTable = GetMastery(obj);
		local mastery = GetMasteryMastered(masteryTable, masteryName);
		if mastery then
			result = GetWithoutError(mastery, statusName);
		end
	end
	return result;
end
function MakeMasteryStatInfo(masteryName, value)
	return { Type = masteryName, Value = value, ValueType = 'Mastery'};
end
function CalculatedProperty_SpecialCase_Mastery_MaxHP(obj, arg, data)
	local result = 0;
	local info = {};
	-- 신체 단련
	local stat_BodyTraining = GetAdditionalMasteryStatusByLevelWithInfo(obj, 'BodyTraining', data, info);
	if stat_BodyTraining > 0 then
		result = result + stat_BodyTraining;
		-- 규칙적인 운동
		result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'RegularExercise', data, info);
	end
	-- 황소의 인장
	local addMastery_Amulet_AngryBull = GetAdditionalMasteryStatusByLevel(obj, 'Amulet_AngryBull', data);
	if addMastery_Amulet_AngryBull ~= 0 then
		result = result + addMastery_Amulet_AngryBull;
		table.insert(info, { Type = 'Amulet_AngryBull', Value = addMastery_Amulet_AngryBull, ValueType = 'Equipment'});
	end	
	-- 대형종
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'LargeType', data, info);
	-- 지구력 훈련
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'EnduranceTraining', data, info);
	-- 반복 훈련
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'RepetitiveTraining', data, info);
	-- 이능 제어 훈련
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'ESPControlTraining', data, info);
	-- 자가 면역
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'Autoimmunity', data, info);
	-- 심신단련
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'BodyAndMindTraining', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData['All'] / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	-- 풍요
	local addMastery_Abundance = GetAdditionalMasteryStatusByCost(obj, 'Abundance', data);
	if addMastery_Abundance > 0 then
		-- 번쩍이는 빛
		local applyAmount_TwinkleLight = GetMasteryStatus(obj, 'TwinkleLight', data, 'ApplyAmount');
		if applyAmount_TwinkleLight > 0 then
			addMastery_Abundance = addMastery_Abundance + addMastery_Abundance * applyAmount_TwinkleLight / 100;
		end
		result = result + addMastery_Abundance;
		table.insert(info, MakeMasteryStatInfo('Abundance', addMastery_Abundance));
	end
	-- 거리의 싸움꾼
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'StreetFighter', data, info, function(obj, mastery)
		return mastery.CustomCacheData * mastery.ApplyAmount;
	end);
	
	-- 대학자
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'ArchScholar', data, info, function(obj, mastery)
		return mastery.CustomCacheData['Normal'] * mastery.ApplyAmount2;
	end);
	
	-- 가려진 과거
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'BehindStory', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData['All'] / mastery.ApplyAmount) * mastery.ApplyAmount4;
	end);
	
	-- 리듬에 맞춰 흥겹게
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'RhythmicalMovements', data, info, function(obj, mastery)
		return mastery.CustomCacheData['Normal'] * mastery.ApplyAmount2;
	end);
	
	-- 단단한 비늘
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'HardScale', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData.All / mastery.ApplyAmount) * mastery.ApplyAmount4;
	end);
	
	-- 생명의 불꽃
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'LifeFlame', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	-- 노익장
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'LegendVeteran', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_AttackPower(obj, arg, data)
	local result = 0;
	local info = {};
	-- 근육 단련
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'MuscleTraining', data, info);
	-- 백호의 인장
	local addMastery_Amulet_WhiteTiger = GetAdditionalMasteryStatusByLevel(obj, 'Amulet_WhiteTiger', data);
	if addMastery_Amulet_WhiteTiger ~= 0 then
		result = result + addMastery_Amulet_WhiteTiger;
		table.insert(info, { Type = 'Amulet_WhiteTiger', Value = addMastery_Amulet_WhiteTiger, ValueType = 'Equipment'});
	end
	-- 반복 훈련
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'RepetitiveTraining', data, info);
	-- 대학자
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'ArchScholar', data, info, function(obj, mastery)
		return mastery.CustomCacheData['Attack'] * mastery.ApplyAmount2;
	end);
	-- 마검술사
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'MagicianSwordMaster', data, info, function(obj, mastery)
		local addAmount1 = math.floor(mastery.CustomCacheData['Swordsman'] / mastery.ApplyAmount) * mastery.ApplyAmount2;
		local addAmount2 = math.floor(mastery.CustomCacheData['Swordmagician'] / mastery.ApplyAmount) * mastery.ApplyAmount3;
		return addAmount1 + addAmount2;
	end);
	-- 강경
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'ExternalEnergy', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	-- 심신단련
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'BodyAndMindTraining', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData['Job'] / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	-- 다재다능
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Versatility', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_ESPPower(obj, arg, data)
	local result = 0;
	local info = {};
	-- 정신력
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'Willpower', data, info);
	-- 지옥불 인장
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'Amulet_Hellfire', data, info);
	-- 마법사
	result = result + GetAdditionalMasteryStatusByCostWithInfo(obj, 'Magician', data, info);
	-- 마력 증폭
	local buff_SpellPowerUp = GetBuff(obj, 'SpellPowerUp');
	if buff_SpellPowerUp then
		local addBuff_SpellPowerUp = obj.Lv * buff_SpellPowerUp.ApplyAmount;
		table.insert(info, { Type = buff_SpellPowerUp.name, Value = addBuff_SpellPowerUp, ValueType = 'Buff'});
		result = result + addBuff_SpellPowerUp;
	end
	
	-- 대학자
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'ArchScholar', data, info, function(obj, mastery)
		return mastery.CustomCacheData['Attack'] * mastery.ApplyAmount2;
	end);
	-- 마검술사
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'MagicianSwordMaster', data, info, function(obj, mastery)
		local addAmount1 = math.floor(mastery.CustomCacheData['Mage'] / mastery.ApplyAmount) * mastery.ApplyAmount2;
		local addAmount2 = math.floor(mastery.CustomCacheData['Swordmagician'] / mastery.ApplyAmount) * mastery.ApplyAmount3;
		return addAmount1 + addAmount2;
	end);
	-- 평경
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'InternalEnergy', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	-- 이능 제어 훈련
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'ESPControlTraining', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData['InternalEnergy'] / mastery.ApplyAmount2) * mastery.ApplyAmount3;
	end);
	-- 심신단련
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'BodyAndMindTraining', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData['ESP'] / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	-- 다재다능
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Versatility', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_Accuracy(obj, arg, data)
	local result = 0;
	local info = {};
	-- 특성 현자
	local addMastery_Sage = GetAdditionalMasteryStatusByMasteryCount(obj, 'Sage', data, function(mastery)
		if mastery.Lv <= 0 then
			return false;
		end
		return mastery.Type.name == 'All';
	end, 'ApplyAmount2');
	if addMastery_Sage ~= 0 then
		result = result + addMastery_Sage;
		table.insert(info, MakeMasteryStatInfo('Sage', addMastery_Sage));
	end
	
	-- 감춰진 야성
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'RevealWildNature', data, info, function(obj, mastery)
		return mastery.CustomCacheData * mastery.ApplyAmount2 / mastery.ApplyAmount;
	end);
	
	-- 추상화
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Abstraction', data, info, function(obj, mastery)
		return mastery.CustomCacheData * mastery.ApplyAmount2 / mastery.ApplyAmount;
	end);
	
	-- 대학자
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'ArchScholar', data, info, function(obj, mastery)
		return mastery.CustomCacheData['Ability'] * mastery.ApplyAmount3;
	end);
	
	-- 제어 관리
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Application_ControlManager', data, info, function(obj, mastery)
		return mastery.CustomCacheData * mastery.ApplyAmount2 / mastery.ApplyAmount;
	end);
	
	-- 하중 분산
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Module_LoadDistribution', data, info, function(obj, mastery)
		return math.floor((obj.MaximumLoad - obj.Load) / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	-- 가려진 과거
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'BehindStory', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData['Singer'] / mastery.ApplyAmount) * mastery.ApplyAmount3;
	end);
	
	-- 다재다능
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Versatility', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount3;
	end);
	
	-- 리듬에 맞춰 흥겹게
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'RhythmicalMovements', data, info, function(obj, mastery)
		return mastery.CustomCacheData['Attack'] * mastery.ApplyAmount4;
	end);
	
	-- 신경망 가속
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'NeuralNetworkAcceleration', data, info, function(obj, mastery)
		local addValue = 0;
		-- 강화된 신경망
		local mastery_EnhancedNeuralNetwork = GetMasteryMasteredWithData(obj, 'EnhancedNeuralNetwork', data);
		if mastery_EnhancedNeuralNetwork then
			addValue = addValue + math.floor(mastery.CustomCacheData / mastery_EnhancedNeuralNetwork.ApplyAmount2) * mastery_EnhancedNeuralNetwork.ApplyAmount3;
		end
		return addValue;
	end);
	
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_CriticalStrikeChance(obj, arg, data)
	local result = 0;
	local info = {};
	-- 특성 현자
	local addMastery_Sage = GetAdditionalMasteryStatusByMasteryCount(obj, 'Sage', data, function(mastery)
		if mastery.Lv <= 0 then
			return false;
		end
		return mastery.Type.CheckType == 'ESP';
	end, 'ApplyAmount2');
	if addMastery_Sage ~= 0 then
		result = result + addMastery_Sage;
		table.insert(info, MakeMasteryStatInfo('Sage', addMastery_Sage));
	end
	-- 흑마법 회로
	local addMastery_BlackMagicCircuit = GetAdditionalMasteryStatusByCustomFunc(obj, 'BlackMagicCircuit', data, function(obj, mastery)
		return mastery.CustomCacheData * mastery.ApplyAmount2 / mastery.ApplyAmount;
	end);
	if addMastery_BlackMagicCircuit ~= 0 then
		result = result + addMastery_BlackMagicCircuit;
		table.insert(info, MakeMasteryStatInfo('BlackMagicCircuit', addMastery_BlackMagicCircuit));
	end
	
	-- 우뢰
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Thunder', data, info, function(obj, mastery)
		return mastery.CustomCacheData * mastery.ApplyAmount2 / mastery.ApplyAmount;
	end);
	
	-- 감춰진 야성
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'RevealWildNature', data, info, function(obj, mastery)
		return mastery.CustomCacheData * mastery.ApplyAmount2 / mastery.ApplyAmount;
	end);
	
	-- 전문 서적
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'MajorTextbooks', data, info, function(obj, mastery)
		return mastery.CustomCacheData * mastery.ApplyAmount;
	end);
	
	-- 제어 관리
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Application_ControlManager', data, info, function(obj, mastery)
		return mastery.CustomCacheData * mastery.ApplyAmount2 / mastery.ApplyAmount;
	end);
	
	-- 기체 제어 프로그램
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Module_FrameControl', data, info, function(obj, mastery)
		local masteryCount = mastery.CustomCacheData['Application_Control'] or 0;
		local stepCount = math.floor(masteryCount / mastery.ApplyAmount);	-- ApplyAmount 당
		return stepCount * mastery.ApplyAmount2;							-- ApplyAmount2 만큼 증가
	end);
	
	-- 가려진 과거
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'BehindStory', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData['Musician'] / mastery.ApplyAmount) * mastery.ApplyAmount3;
	end);
	
	-- 다재다능
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Versatility', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount3;
	end);
	
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_CriticalStrikeDeal(obj, arg, data)
	local result = 0;
	local info = {};
	-- 특성 현자
	local addMastery_Sage = GetAdditionalMasteryStatusByMasteryCount(obj, 'Sage', data, function(mastery)
		if mastery.Lv <= 0 then
			return false;
		end
		return mastery.Type.CheckType == 'Job';
	end, 'ApplyAmount3');
	if addMastery_Sage ~= 0 then
		result = result + addMastery_Sage;
		table.insert(info, MakeMasteryStatInfo('Sage', addMastery_Sage));
	end
	-- 무술 교본
	local addMastery_FigterBook = GetAdditionalMasteryStatusByCustomFunc(obj, 'FigterBook', data, function(obj, mastery)
		return mastery.CustomCacheData * mastery.ApplyAmount;
	end);
	if addMastery_FigterBook ~= 0 then
		result = result + addMastery_FigterBook;
		table.insert(info, MakeMasteryStatInfo('FigterBook', addMastery_FigterBook));
	end
	-- 검술서
	local addMastery_SwordsmanshipBook = GetAdditionalMasteryStatusByCustomFunc(obj, 'SwordsmanshipBook', data, function(obj, mastery)
		return mastery.CustomCacheData * mastery.ApplyAmount;
	end);
	if addMastery_SwordsmanshipBook ~= 0 then
		result = result + addMastery_SwordsmanshipBook;
		table.insert(info, MakeMasteryStatInfo('SwordsmanshipBook', addMastery_SwordsmanshipBook));
	end
	-- 흑마법 회로
	local addMastery_BlackMagicCircuit = GetAdditionalMasteryStatusByCustomFunc(obj, 'BlackMagicCircuit', data, function(obj, mastery)
		return mastery.CustomCacheData * mastery.ApplyAmount3 / mastery.ApplyAmount;
	end);
	if addMastery_BlackMagicCircuit ~= 0 then
		result = result + addMastery_BlackMagicCircuit;
		table.insert(info, MakeMasteryStatInfo('BlackMagicCircuit', addMastery_BlackMagicCircuit));
	end
	
	-- 폭풍
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Stormwind', data, info, function(obj, mastery)
		return mastery.CustomCacheData * mastery.ApplyAmount2 / mastery.ApplyAmount;
	end);
	
	-- 전문 서적
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'MajorTextbooks', data, info, function(obj, mastery)
		return mastery.CustomCacheData * mastery.ApplyAmount2;
	end);
	
	-- 기체 제어 프로그램
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Module_FrameControl', data, info, function(obj, mastery)
		local masteryCount = mastery.CustomCacheData['Application_Enhancement'] or 0;
		local stepCount = math.floor(masteryCount / mastery.ApplyAmount);	-- ApplyAmount 당
		return stepCount * mastery.ApplyAmount3;							-- ApplyAmount3 만큼 증가
	end);
	
	-- 보조 강화 프로그램
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Module_SubEnhancement', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount3;
	end);
	
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_Armor(obj, arg, data)
	local result = 0;
	local info = {};
	local muscleArmor = 0;
	if data then
		local masteryList = GetClassList('Mastery');
		if data.Masteries['MuscleArmor'] then
			local mastery = masteryList['MuscleArmor'];
			muscleArmor = math.floor(CalculatedProperty_Status(obj, 'MaxHP', data) * mastery.ApplyAmount/100);
		end
	else
		local masteryTable = GetMastery(obj);
		local mastery = GetMasteryMastered(masteryTable, 'MuscleArmor');
		if mastery then
			muscleArmor = math.floor(obj.MaxHP * mastery.ApplyAmount/100);
		end
	end
	if muscleArmor ~= 0 then
		table.insert(info, MakeMasteryStatInfo('MuscleArmor', muscleArmor));
		result = result + muscleArmor;
	end
	local addVal_RegularExercise = 0;
	-- 튼튼함
	local addMastery_Robust = GetAdditionalMasteryStatusByLevel(obj, 'Robust', data);
	if addMastery_Robust ~= 0 then
		table.insert(info, MakeMasteryStatInfo('Robust', addMastery_Robust));
		result = result + addMastery_Robust;
		-- 규칙적인 운동
		addVal_RegularExercise = addVal_RegularExercise + GetAdditionalMasteryStatusByLevel(obj, 'RegularExercise', data);
	end
	-- 인내심
	local addMastery_Patience = GetAdditionalMasteryStatusByLevel(obj, 'Patience', data);
	if addMastery_Patience ~= 0 then
		table.insert(info, MakeMasteryStatInfo('Patience', addMastery_Patience));
		result = result + addMastery_Patience;
		-- 규칙적인 운동
		addVal_RegularExercise = addVal_RegularExercise + GetAdditionalMasteryStatusByLevel2(obj, 'RegularExercise', data);
	end
	if addVal_RegularExercise > 0 then
		result = result + addVal_RegularExercise;
		table.insert(info, MakeMasteryStatInfo('RegularExercise', addVal_RegularExercise));
	end
	-- 강철의 야수
	local addMastery_IronBeast = GetAdditionalMasteryStatusByLevel(obj, 'IronBeast', data);
	if addMastery_IronBeast ~= 0 then
		table.insert(info, MakeMasteryStatInfo('IronBeast', addMastery_IronBeast));
		result = result + addMastery_IronBeast;
	end
	-- 거친 가죽
	local addMastery_ToughSkin = GetAdditionalMasteryStatusByLevel(obj, 'ToughSkin', data);
	if addMastery_ToughSkin ~= 0 then
		table.insert(info, MakeMasteryStatInfo('ToughSkin', addMastery_ToughSkin));
		result = result + addMastery_ToughSkin;
	end
	-- 대학자
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'ArchScholar', data, info, function(obj, mastery)
		return mastery.CustomCacheData['Defence'] * mastery.ApplyAmount2;
	end);
	-- 다재다능
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Versatility', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	-- 단단한 비늘
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'HardScale', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData.Beast / mastery.ApplyAmount) * mastery.ApplyAmount2
		 + math.floor(mastery.CustomCacheData.Draky / mastery.ApplyAmount) * mastery.ApplyAmount3;
	end);
	-- 신경망 제어
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'NeuralNetworkControl', data, info, function(obj, mastery)
		local addValue = 0;
		-- 강화된 신경망
		local mastery_EnhancedNeuralNetwork = GetMasteryMasteredWithData(obj, 'EnhancedNeuralNetwork', data);
		if mastery_EnhancedNeuralNetwork then
			addValue = addValue + math.floor(mastery.CustomCacheData / mastery_EnhancedNeuralNetwork.ApplyAmount4) * mastery_EnhancedNeuralNetwork.ApplyAmount5;
		end
		return addValue;
	end);
	-- 야샤의 딱딱한 껍질
	local addMastery_Amulet_Yasha_Scale = GetAdditionalMasteryStatusByLevel(obj, 'Amulet_Yasha_Scale', data);
	if addMastery_Amulet_Yasha_Scale ~= 0 then
		result = result + addMastery_Amulet_Yasha_Scale;
		table.insert(info, { Type = 'Amulet_Yasha_Scale', Value = addMastery_Amulet_Yasha_Scale, ValueType = 'Equipment'});
	end
	
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_Resistance(obj, arg, data)
	local result = 0;
	local info = {};
	local muscleResistance = 0;
	if data then
		local masteryList = GetClassList('Mastery');
		if data.Masteries['MuscleResistance'] then
			local mastery = masteryList['MuscleResistance'];
			muscleResistance = math.floor(CalculatedProperty_Status(obj, 'MaxHP', data) * mastery.ApplyAmount/100);
		end
	else
		local masteryTable = GetMastery(obj);
		local mastery = GetMasteryMastered(masteryTable, 'MuscleResistance');
		if mastery then
			muscleResistance = math.floor(obj.MaxHP * mastery.ApplyAmount/100);
		end
	end
	if muscleResistance ~= 0 then
		table.insert(info, MakeMasteryStatInfo('MuscleResistance', muscleResistance));
		result = result + muscleResistance;
	end
	-- 회복력
	local addVal_RegularExercise = 0;
	local addMastery_Resilient = GetAdditionalMasteryStatusByLevel(obj, 'Resilient', data);
	if addMastery_Resilient ~= 0 then
		table.insert(info, MakeMasteryStatInfo('Resilient', addMastery_Resilient));
		result = result + addMastery_Resilient;
		-- 규칙적인 운동
		addVal_RegularExercise = addVal_RegularExercise + GetAdditionalMasteryStatusByLevel(obj, 'RegularExercise', data);
	end
	-- 인내심
	local addMastery_Patience = GetAdditionalMasteryStatusByLevel(obj, 'Patience', data);
	if addMastery_Patience ~= 0 then
		table.insert(info, MakeMasteryStatInfo('Patience', addMastery_Patience));
		result = result + addMastery_Patience;
		-- 규칙적인 운동
		addVal_RegularExercise = addVal_RegularExercise + GetAdditionalMasteryStatusByLevel2(obj, 'RegularExercise', data);
	end
	if addVal_RegularExercise > 0 then
		result = result + addVal_RegularExercise;
		table.insert(info, MakeMasteryStatInfo('RegularExercise', addVal_RegularExercise));
	end
	-- 거친 가죽
	local addMastery_ToughSkin = GetAdditionalMasteryStatusByLevel(obj, 'ToughSkin', data);
	if addMastery_ToughSkin ~= 0 then
		table.insert(info, MakeMasteryStatInfo('ToughSkin', addMastery_ToughSkin));
		result = result + addMastery_ToughSkin;
	end
	-- 대학자
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'ArchScholar', data, info, function(obj, mastery)
		return mastery.CustomCacheData['Defence'] * mastery.ApplyAmount2;
	end);
	-- 다재다능
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Versatility', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	-- 단단한 비늘
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'HardScale', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData.ESP / mastery.ApplyAmount) * mastery.ApplyAmount2
		+ math.floor(mastery.CustomCacheData.Draky / mastery.ApplyAmount) * mastery.ApplyAmount3;
	end);
	-- 신경망 제어
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'NeuralNetworkControl', data, info, function(obj, mastery)
		local addValue = 0;
		-- 강화된 신경망
		local mastery_EnhancedNeuralNetwork = GetMasteryMasteredWithData(obj, 'EnhancedNeuralNetwork', data);
		if mastery_EnhancedNeuralNetwork then
			addValue = addValue + math.floor(mastery.CustomCacheData / mastery_EnhancedNeuralNetwork.ApplyAmount4) * mastery_EnhancedNeuralNetwork.ApplyAmount5;
		end
		return addValue;
	end);
	
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_MaxVigor(obj, arg, data)
	local result = 0;
	local info = {};
	-- 특성 대마법사
	local mastery_Archmage = nil;
	if data then
		local masteryList = GetClassList('Mastery');
		if data.Masteries['Archmage'] then
			mastery_Archmage = masteryList['Archmage'];
		end
	else
		local masteryTable = GetMastery(obj);
		mastery_Archmage = GetMasteryMastered(masteryTable, 'Archmage');
	end
	if mastery_Archmage then
		local baseMaxCost = GetWithoutError(obj, 'Base_MaxVigor') or 0;
		-- 기본 특성 값
		if data then
			local masteryList = GetClassList('Mastery');
			for key, value in pairs(data.Masteries) do
				if value then
					local mastery = masteryList[key];
					if mastery.Lv > 0 and mastery.Category.Type == 'Basic' then
						baseMaxCost = baseMaxCost + mastery.MaxVigor;
					end
				end
			end
		else
			local masteryTable = GetMastery(obj);
			table.foreach(masteryTable, function(key, mastery)
				if mastery.Lv > 0 and mastery.Category.Type == 'Basic' then
					baseMaxCost = baseMaxCost + mastery.MaxVigor;
				end
			end);
		end
		-- 커스터마이징 값.
		local script = _G['CalculatedProperty_SpecialCase_'..arg];
		if script ~= nil then
			baseMaxCost = baseMaxCost + script(obj, arg, data);
		end
		-- 직업 값.
		local jobScript = _G['CalculatedProperty_JobStatus_'..arg];
		if jobScript ~= nil then
			baseMaxCost = baseMaxCost + jobScript(obj.Job, arg, data and data.Lv or obj.Lv);
		end
		local addMaxCost = math.floor(baseMaxCost * mastery_Archmage.ApplyAmount / 100);
		result = result + addMaxCost;
		table.insert(info, MakeMasteryStatInfo('Archmage', addMaxCost));
	end
	
	-- 대학자
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'ArchScholar', data, info, function(obj, mastery)
		return mastery.CustomCacheData['Sub'] * mastery.ApplyAmount;
	end);
	
	-- 자료구조
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'DataStructure', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	-- 리듬에 맞춰 흥겹게
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'RhythmicalMovements', data, info, function(obj, mastery)
		return mastery.CustomCacheData['Sub'] * mastery.ApplyAmount3;
	end);
	
	-- 호연지기
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'VastSpirit', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_MaxRage(obj, arg, data)
	local result = 0;
	local info = {};
	
	-- 호연지기
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'VastSpirit', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_RegenVigor(obj, arg, data)
	local result = 0;
	local info = {};
	
	-- 호연지기
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'VastSpirit', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount3;
	end);
	
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_RegenRage(obj, arg, data)
	local result = 0;
	local info = {};
	
	-- 호연지기
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'VastSpirit', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount3;
	end);
	
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_Dodge(obj, arg, data)
	local result = 0;
	local info = {};
	local masteryTable = GetMastery(obj);
	
	-- 급류
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'RapidStream', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	-- 감춰진 야성
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'RevealWildNature', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	-- 교양 서적
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Educationalbooks', data, info, function(obj, mastery)
		return mastery.CustomCacheData * mastery.ApplyAmount;
	end);
	
	-- 제어 관리
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Application_ControlManager', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	-- 하중 관리 프로그램
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Module_LoadManager', data, info, function(obj, mastery)
		return math.floor((obj.MaximumLoad - obj.Load) / mastery.ApplyAmount) * mastery.ApplyAmount3;
	end);
	
	-- 가려진 과거
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'BehindStory', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData['Dancer'] / mastery.ApplyAmount) * mastery.ApplyAmount3;
	end);
	
	-- 다재다능
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Versatility', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount3;
	end);
	
	-- 리듬에 맞춰 흥겹게
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'RhythmicalMovements', data, info, function(obj, mastery)
		return mastery.CustomCacheData['Defence'] * mastery.ApplyAmount4;
	end);
	
	-- 신경망 제어
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'NeuralNetworkControl', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount3) * mastery.ApplyAmount4;
	end);
	
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_Block(obj, arg, data)
	local result = 0;
	local info = {};
	local masteryTable = GetMastery(obj);
	
	-- 심록
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'DarkGreen', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	-- 감춰진 야성
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'RevealWildNature', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	-- 교양 서적
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Educationalbooks', data, info, function(obj, mastery)
		return mastery.CustomCacheData * mastery.ApplyAmount2;
	end);
	
	-- 제어 관리
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Application_ControlManager', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	-- 다재다능
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Versatility', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount3;
	end);
	
	-- 신경망 제어
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'NeuralNetworkControl', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount3) * mastery.ApplyAmount4;
	end);
	
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_IncreaseDamage(obj, arg, data)
	local result = 0;
	local info = {};
	local masteryTable = GetMastery(obj);
	
	-- 강화 관리
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Application_EnhancedManager', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	-- 통합 강화 프로그램
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Module_ApplicationEnhancement', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	-- 맹화
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'RagedFire', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_DecreaseDamage(obj, arg, data)
	local result = 0;
	local info = {};
	local masteryTable = GetMastery(obj);
	
	-- 강화 관리
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Application_EnhancedManager', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2 ;
	end);
	
	-- 중앙 제어 프로그램
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Module_ApplicationControl', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2 ;
	end);
	
	-- 하중 관리 프로그램
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Module_LoadManager', data, info, function(obj, mastery)
		return math.floor(obj.Load / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_Speed(obj, arg, data)
	local result = 0;
	local info = {};
	local masteryTable = GetMastery(obj);
	
	-- 하중 최적화
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Module_LoadLighten', data, info, function(obj, mastery)
		return math.floor(obj.Load / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	-- 가려진 과거
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'BehindStory', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData['Clown'] / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	-- 리듬에 맞춰 흥겹게
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'RhythmicalMovements', data, info, function(obj, mastery)
		return mastery.CustomCacheData['Ability'] * mastery.ApplyAmount5;
	end);
	
	-- 신경망 가속
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'NeuralNetworkAcceleration', data, info, function(obj, mastery)
		return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_IncreaseMaximumLoad(obj, arg, data)
	local result = 0;
	local info = {};
	local masteryTable = GetMastery(obj);
	
	-- 드론 장비: 하복 엔진.
	if obj.Info.name == 'Drone_Transport' then
		local masteryList = { 'SubSupportDevice_SubEngineHB', 'SubSupportDevice_SubEngineHB_Uncommon', 'SubSupportDevice_SubEngineHB_Rare', 'SubSupportDevice_SubEngineHB_Epic' };
		for _, value in pairs (masteryList) do
			local curMasery = GetMasteryMastered(masteryTable, value);
			if curMasery then
				result = result + curMasery.ApplyAmount;
				table.insert(info, MakeMasteryStatInfo(curMasery.name, curMasery.ApplyAmount));
			end
		end
	end
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_FireResistance(obj, arg, data)
	local result = 0;
	local info = {};
	-- 화염 내성 I
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'FireResistance1', data, info);
	-- 화염 내성 II
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'FireResistance2', data, info);
	-- 화염 내성 III
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'FireResistance3', data, info);
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_IceResistance(obj, arg, data)
	local result = 0;
	local info = {};
	-- 얼음 내성 I
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'IceResistance1', data, info);
	-- 얼음 내성 II
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'IceResistance2', data, info);
	-- 얼음 내성 III
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'IceResistance3', data, info);
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_LightningResistance(obj, arg, data)
	local result = 0;
	local info = {};
	-- 번개 내성 I
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'LightningResistance1', data, info);
	-- 번개 내성 II
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'LightningResistance2', data, info);
	-- 번개 내성 III
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'LightningResistance3', data, info);
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_EarthResistance(obj, arg, data)
	local result = 0;
	local info = {};
	-- 대지 내성 I
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'EarthResistance1', data, info);
	-- 대지 내성 II
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'EarthResistance2', data, info);
	-- 대지 내성 III
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'EarthResistance3', data, info);
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_WaterResistance(obj, arg, data)
	local result = 0;
	local info = {};
	-- 물 내성 I
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'WaterResistance1', data, info);
	-- 물 내성 II
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'WaterResistance2', data, info);
	-- 물 내성 III
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'WaterResistance3', data, info);
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_WindResistance(obj, arg, data)
	local result = 0;
	local info = {};
	-- 바람 내성 I
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'WindResistance1', data, info);
	-- 바람 내성 II
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'WindResistance2', data, info);
	-- 바람 내성 III
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'WindResistance3', data, info);
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_SlashingResistance(obj, arg, data)
	local result = 0;
	local info = {};
	-- 참격 내성 I
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'SlashingResistance1', data, info);
	-- 참격 내성 II
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'SlashingResistance2', data, info);
	-- 참격 내성 III
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'SlashingResistance3', data, info);
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_PiercingResistance(obj, arg, data)
	local result = 0;
	local info = {};
	-- 관통 내성 I
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'PiercingResistance1', data, info);
	-- 관통 내성 II
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'PiercingResistance2', data, info);
	-- 관통 내성 III
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'PiercingResistance3', data, info);
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_BluntResistance(obj, arg, data)
	local result = 0;
	local info = {};
	-- 타격 내성 I
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'BluntResistance1', data, info);
	-- 타격 내성 II
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'BluntResistance2', data, info);
	-- 타격 내성 III
	result = result + GetAdditionalMasteryStatusByLevelWithInfo(obj, 'BluntResistance3', data, info);
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_PerformanceSlot(obj, arg, data)
	local result = 0;
	local info = {};
	-- 신기한 재주
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'ClownTalent', data, info, function(obj, mastery)
		return mastery.ApplyAmount;
	end);
	-- 흥겨운 몸짓
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'DancerTalent', data, info, function(obj, mastery)
		return mastery.ApplyAmount;
	end);
	-- 빛나는 재능
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'ShiningTalent', data, info, function(obj, mastery)
		return mastery.ApplyAmount;
	end);
	-- 천부적 재능
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'Genius_Leton', data, info, function(obj, mastery)
		return mastery.ApplyAmount;
	end);
	-- 열연
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'EnthusiasticPerformance', data, info, function(obj, mastery)
		return mastery.ApplyAmount;
	end);
	-- 직업 특성이 없는 경우
	-- 신기한 재주, 흥겨운 몸짓
	local masteryTable = GetMastery(obj);
	local mastery_ClownTalent = GetMasteryMastered(masteryTable, 'ClownTalent');
	local mastery_DancerTalent = GetMasteryMastered(masteryTable, 'DancerTalent');
	if not mastery_ClownTalent and not mastery_DancerTalent then
		-- 경쾌한 안무
		result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'NimbleMovements', data, info, function(obj, mastery)
			return mastery.ApplyAmount;
		end);
		-- 화려한 안무
		result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'FlashyHandMovements', data, info, function(obj, mastery)
			return mastery.ApplyAmount;
		end);
		-- 정교한 안무
		result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'UnderstatedMovements', data, info, function(obj, mastery)
			return mastery.ApplyAmount;
		end);
		-- 격렬한 안무
		result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'PowerfulMovements', data, info, function(obj, mastery)
			return mastery.ApplyAmount;
		end);
	end
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_IncreaseDamage_ESP(obj, arg, data)
	local result = 0;
	local info = {};
	-- 마도서
	local spellBookCount = nil;
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'SpellBook', data, info, function(obj, mastery)
		spellBookCount = mastery.CustomCacheData;
		return spellBookCount * mastery.ApplyAmount;
	end);
	if spellBookCount ~= nil then
		-- 금지된 마도서
		result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'ForbiddenBook', data, info, function(obj, mastery)
			return spellBookCount * mastery.ApplyAmount;
		end);
	end
	
	-- 마녀의 책
	local witchBookCount = nil;
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'WitchBook', data, info, function(obj, mastery)
		witchBookCount = mastery.CustomCacheData;
		return witchBookCount * mastery.ApplyAmount;
	end);
	if witchBookCount ~= nil then
		-- 대마녀
		result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'ArchWitch', data, info, function(obj, mastery)
			return witchBookCount * mastery.ApplyAmount;
		end);
	end
	
	-- 특성 현자
	local addMastery_Sage = GetAdditionalMasteryStatusByMasteryCount(obj, 'Sage', data, function(mastery)
		if mastery.Lv <= 0 then
			return false;
		end
		return mastery.Category.name == 'Set';
	end, 'ApplyAmount2');
	if addMastery_Sage ~= 0 then
		result = result + addMastery_Sage;
		table.insert(info, MakeMasteryStatInfo('Sage', addMastery_Sage));
	end
	
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_IncreaseDamage_Physical(obj, arg, data)
	local result = 0;
	local info = {};
	
	return result, info;
end
function CalculatedProperty_SpecialCase_Mastery_IncreaseDamage_Melee(obj, arg, data)
	local result = 0;
	local info = {};
	
	-- 발경
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'ReleaseEnergy', data, info, function(obj, mastery)
		return mastery.ApplyAmount;
	end);
	-- 사석위호
	result = result + GetAdditionalMasteryStatusByCustomFuncWithInfo(obj, 'StuckArrowheadInStone', data, info, function(obj, mastery)
		return mastery.ApplyAmount;
	end);
	
	return result, info;
end
---------------------------------------------------------------------------------------
function CalculatedProperty_Status_PerformanceEffect(obj, arg, data)
	local result = 0;
	local info = {};
	
	for _, effectCls in pairs(GetClassList('PerformanceEffect')) do
		if effectCls.Status == arg then
			result = result + GetAdditionalPerformanceStatusWithInfo(obj, effectCls.name, info);
		end
	end
	
	return result, info;
end
---------------------------------------------------------------------------------------
function CalculatedProperty_Status_Mastery_Custom(obj, arg, operation, startValue)
	if IsClass(obj) then
		return startValue;
	end
	local result = startValue;
	local masteryTable = GetMastery(obj);
	for mType, mastery in pairs(masteryTable) do
		if mastery.Lv and mastery.Lv > 0 then
			local applyValue = GetWithoutError(mastery, arg);
			if applyValue and applyValue ~= 'None' then
				result = operation(result, applyValue);
			end
		end
	end
	return result;
end
function CalculatedProperty_Status_Buff_Custom(obj, arg, operation, startValue)
	return GetBuffStatusCustom(obj, arg, startValue, operation);
end
function CalculatedProperty_StatusBool_And_Simple(obj, arg)
	-- 1. 초기 값 가져오기 
	local result = obj['Base_'..arg];
	if not IsMission() then
		return result;
	end
	-- 2. 버프값 가져오기 / 전투 중 일때만
	if result then
		result = GetBuffStatus(obj, arg, 'And');
	end
	return result;
end
function CalculatedProperty_Object_Invisible(obj, arg)
	-- 1. Shape 값 가져오기 
	local result = obj.Shape.Invisible;
	if not IsMission() then
		return result;
	end
	-- 2. 버프값 가져오기 / 전투 중 일때만
	if not result then
		result = GetBuffStatus(obj, 'Invisible', 'Or');
	end
	return result;
end
function CalculatedProperty_AIFieldBonus(fieldBonus, key)
	local obj = fieldBonus.parent;
	local bonus = GetWithoutError(obj.Job.AIFieldBonus, key) or 0;	-- 직업 보너스
	
	local masteryTable = GetMastery(obj);
	for mType, mastery in pairs(masteryTable) do
		if mastery.Lv > 0 then
			bonus = bonus + (GetWithoutError(GetWithoutError(mastery, 'AIFieldBonus'), key) or 0);
		end
	end
	return bonus;
end
------------------------------------------------------------------
-- 아이템 능력치 받아오는 함수.
-- 기본값 가져오고, 개조 능력값 가져온다.
------------------------------------------------------------------
function CalculatedProperty_ItemStatus(obj, arg)
	local result = 0;
	-- 1. 초기 값 가져오기 
	local result = GetBaseStatusByItem(obj, arg);
	-- 2. 강화값 가져오기.
	if obj.MainStatus == arg then		
		result = result + GetItemUpgradeStatus(obj, obj.Lv);
	end
	-- 3. 옵션값 더하기
	result = result + GetItemOptionStatus(obj, arg);
	return result;
end
function GetBaseStatusByItem(obj, arg)
	return GetWithoutError(obj, 'Base_'..arg) or 0;
end
------------------------------------------------------------------
-- 특성 능력치 받아오는 함수.
-- 기본값 가져오고, 레벨에 따른 성장값 가져온다.
------------------------------------------------------------------
function CalculatedProperty_MasteryStatus(obj, arg)
	local argLv = obj.Lv;
	local baseArg = GetWithoutError(obj, 'Base_'..arg);
	local status = 0;
	if baseArg then
		if argLv <= 0 then
			argLv = 1;
		elseif argLv > #baseArg then		
			argLv = #baseArg;
		end
		status = baseArg[argLv];
	end
	if status == nil then
		if obj.name == 'Dummy' then
			return 0;
		end
		LogAndPrint('MasteryStatus is wrong', obj.name, obj.Lv, arg);
	end
	local evalArg = GetWithoutError(obj, 'Eval_'..arg) or 0;
	status = status + evalArg;	
	return status;
end
------------------------------------------------------------------
-- 버프 능력치 받아오는 함수.
-- 기본값 가져오고, 중첩에 따른 성장값 가져온다.
------------------------------------------------------------------
function CalculatedProperty_BuffStatus(obj, arg)
	local argLv = obj.Lv;
	local baseArg = GetWithoutError(obj, 'Base_'..arg);
	local status = 0;
	if baseArg then
		if argLv > #baseArg then
			-- LogAndPrint('BuffStatus do not have value', obj.name, obj.Lv, arg);
			argLv = #baseArg;
		end
		argLv = math.max(1, argLv);
		status = baseArg[argLv];
		if status == nil then
			LogAndPrint('BuffStatus is wrong', obj.name, obj.Lv, arg);
			status = 0;
		end
	end
	local eavalArg = GetWithoutError(obj, 'Eval_'..arg) or 0;
	status = status + eavalArg;
	return status;
end
------------------------------------------------------------------
-- 공연 능력치 받아오는 함수.
-- 기본값 가져오고, 중첩에 따른 성장값 가져온다.
------------------------------------------------------------------
function CalculatedProperty_PerformanceStatus(obj, arg)
	local argLv = obj.Lv;
	local baseArg = GetWithoutError(obj, 'Base_'..arg);
	local status = 0;
	if baseArg then
		if argLv <= 0 then
			argLv = 1;
		elseif argLv > #baseArg then		
			argLv = #baseArg;
		end
		status = baseArg[argLv];
	end
	if status == nil then
		LogAndPrint('CalculatedProperty_PerformanceStatus is wrong', obj.name, obj.Lv, arg);
	end
	local evalArg = GetWithoutError(obj, 'Eval_'..arg) or 0;
	status = status + evalArg;	
	return status;
end
---------------------------------------------------
--	General Properties											
---------------------------------------------------
---------------------------------------------------
--	Attributes									
---------------------------------------------------
function GetAbilityPriority_Default(ability, owner)
	return ability.BasePriority;
end
function GetAbilityPriority_Rest(ability, owner)
	local base = GetAbilityPriority_Default(ability, owner);
	if owner.Cost <= 10 then
		return base + 200;
	else
		return base;
	end
end
function GetAbilityPriority_Heal(ability, owner)
	local base = GetAbilityPriority_Default(ability, owner);
	for _, obj in ipairs(table.filter(GetNearObject(owner, 6), function(o) return GetTeam(o) == GetTeam(owner); end)) do
		if owner.HP / owner.MaxHP < 0.3 then
			base = base + 50;
		end
	end
	return base;
end
---------------------------------------------------
--	Action Properties									
---------------------------------------------------

---------------------------------------------------
--	Ability Properties									
---------------------------------------------------
function CalculatedProperty_Ability_ApplyAmount(obj, arg)
	local result = 0;
	if obj.ApplyAmountChangeStep ~= nil and #obj.ApplyAmountChangeStep > 0 then
		if obj.ApplyAmountChangeStep[obj.Lv] ~= nil then
			result = obj.ApplyAmountChangeStep[obj.Lv];
		end
	end
	return result;
end
-- SP 어빌리티
function CalculatedProperty_Ability_SPAbility(obj, arg)
	local result = false;
	if obj.SlotType == 'Ultimate' then
		result = true;
	end
	return result;
end
function CalculatedProperty_Ability_SPFullAbility(obj, arg)
	local result = false;
	if obj.SlotType == 'Ultimate' then
		result = true;
	end
	return result;
end
-- 타겟 칼라.
function CalculatedProperty_Ability_TargetOutlineColor(obj, arg)
	local key = obj.Type;
	if obj.Type == 'Assist' and ( obj.ApplyTarget == 'Enemy' or obj.ApplyTarget == 'PureEnemy' ) then
		key = 'Attack';
	end
	local color = {
		Interaction = 'FF1CEDED',
		Assist = 'FF2D9E6F',
		StateChange = 'FFFFFFFF',
		Summon = 'FF13FF88',
		Heal = 'FF3C6AD9',
		Attack = 'FFED1C24',
		Trap = 'FFED1C24',
	}
	return color[key] or 'FFFFFFFF';
end
---------------------------------------------------------------------
-- TargetRange 와 ApplyRange를 해석해서 사용.
---------------------------------------------------------------------
function CalculatedProperty_Ability_ApplyTargetType(obj, arg)
	
	local abilityApplyTargetTypeList = GetClassList('AbilityApplyTargetType');
	local result = SafeIndex(abilityApplyTargetTypeList[obj.TargetType], 'Title');
	if result == nil then
		return 'None';
	end
	
	if obj.TargetType == 'Single' and obj.Target == 'Self' and obj.ApplyTarget == 'Self' then
		result = GetWord('SelfUse');
	elseif obj.ApplyTarget == 'Enemy' or obj.ApplyTarget == 'PureEnemy' then
		result = GetWord('Enemy').. ' / '..result;
	elseif obj.ApplyTarget == 'NotEnemy' or obj.ApplyTarget == 'Ally' then
		result = GetWord('Ally').. ' / '..result;
	elseif obj.ApplyTarget == 'Any' then
		result = result;
	elseif obj.ApplyTarget == 'Interaction' then
		local interactionList = GetClassList('Interaction');
		result = SafeIndex(interactionList[obj.ApplyTargetDetail], 'Title');
		if result == nil then
			return 'None';
		end
	elseif obj.ApplyTarget == 'InteractionArea' then
		local interactionList = GetClassList('InteractionArea');
		result = SafeIndex(interactionList[obj.ApplyTargetDetail], 'Title');
		if result == nil then
			return 'None';
		end
	end	
	return result;
end
function CalculatedProperty_Ability_RangeDistance(obj, arg)
	local result = 0;
	local rangeList = GetClassList('Range');
	local curDistanceType = obj.TargetRange;	
	local applyRangeType = SafeIndex(rangeList[curDistanceType], 'Type');
	local applyRangeRadius = SafeIndex(rangeList[curDistanceType], 'Radius');
	local applyRangeDistance = SafeIndex(rangeList[curDistanceType], 'Distance');
	if applyRangeRadius == nil then
		applyRangeRadius = 0;
	end
	if applyRangeDistance == nil then
		applyRangeDistance = 0;
	end
	result = math.max(applyRangeRadius, applyRangeDistance);
	if result < 2 and result > 1 then
		result = math.floor(result * 2)/2;
	end
	return result;
end
function CalculatedProperty_Ability_RangeRadius(obj, arg)
	local result = 0;
	local rangeList = GetClassList('Range');
	local curDistanceType = obj.ApplyRange;
	local applyRangeType = SafeIndex(rangeList[curDistanceType], 'Type');
	local applyRangeRadius = SafeIndex(rangeList[curDistanceType], 'Radius');
	local applyRangeDistance = SafeIndex(rangeList[curDistanceType], 'Distance');
	if applyRangeRadius == nil then
		applyRangeRadius = 0;
	end
	if applyRangeDistance == nil then
		applyRangeDistance = 0;
	end
	result = math.max(applyRangeRadius, applyRangeDistance);
	if applyRangeType == 'Chain' then
		result = 0;
	end	
	if result < 2 and result > 1 then
		result = math.floor(result * 2)/2;
	end
	return result;
end
function CalculatedProperty_Ability_FullTitle(obj, arg)
	local ret = {obj.Title};
	local hideSet = {};
	if obj.AbilitySubMenu ~= '' then
		local detailClsList = GetClassList(obj.AbilitySubMenu);
		if detailClsList then
			for _, detailCls in pairs(detailClsList) do
				hideSet[detailCls.Ability.name] = true;
			end
		end
	end
	local abilityClsList = GetClassList('Ability');
	for i, autoAbility in ipairs(obj.AutoActiveAbility) do
		local abilityCls = abilityClsList[autoAbility];
		if abilityCls and abilityCls.name and not hideSet[abilityCls.name] then
			table.insert(ret, abilityCls.Title);
		end
	end
	return table.concat(ret, ' / ');
end
function CalculatedProperty_Ability_ServantAbility(obj, arg)
	local ret = {};
	local abilityClsList = GetClassList('Ability');
	for i, abilityCls in pairs(abilityClsList) do
		if abilityCls.MasterAbility == obj.name then
			table.insert(ret, abilityCls.name);
		end
	end
	return ret;
end
function CalculatedProperty_Ability_NoSightLimit(obj, arg)
	local targetRangeCls = GetClassList('Range')[obj.TargetRange];
	return not SafeIndex(targetRangeCls, 'SightFilter');
end
function CalculatedProperty_ItemTradable(item, arg)
	if not item.Category.IsTradable then
		return false;
	end
	return not item.Binded;
end
function CalculatedProperty_ItemSellable(item, arg)
	return item.Rank.Sellable and item.Category.IsSellable and item.Type.Sellable;
end
function CalculatedProperty_ReactionAttack(obj, arg)
	return obj.ReactionMeleeAttack or obj.ReactionShooting;
end
function CalculatedProperty_CounterAttack(obj, arg)
	return obj.CounterMeleeAttack or obj.CounterShooting;
end
----------
-- UTILITY Function
-------------------------------------------------------------------------------------------------------------
local limiterTable = {
	Float = function (value) 
		return math.max(value,0);
	end,
	Int = function (value) 
		return math.round(value);
	end,
	UInt = function (value) 
		return math.max(math.round(value), 0);
	end,
	UIntSpeed = function (value) 
		return math.clamp(math.round(value), 20, 200);
	end,
	Percent = function (value) 
		return math.max(math.round(value, 2), 0);
	end,
	SPercent = function (value)
		return math.round(value, 2);
	end,
	Percent100 = function (value) 
		return math.clamp(math.round(value, 2), 0, 100);
	end
};
function ValueLimiting(arg, result)
	local limitType = GetClassList('Status')[arg]['LimitType'];
	local limiter = limiterTable[limitType]
	if limiter == nil then
		LogAndPrint(string.format('Error in ValueLimiting, not handled LimitType [%s]', limitType))
		return nil;
	end	
	return limiter(result), result;
end
function CheckLimitValue(arg, value, obj)
	if arg == 'Speed' and not SafeIndex(obj, 'NoTurn') then
		value = math.clamp(math.round(value), 10, 360);
	end
	return value;
end
---------------------------------------------------------------------------------------
-- 활용 함수
---------------------------------------------------------------------------------------
function CalcAddIntByLv(obj, arg, lv)
	if obj and obj.name and obj.name ~= 'None' then
		if obj.Status.name then
			local curValue = 0;
			for index, value in ipairs (obj.Status[arg]) do
				if index <= lv then
					curValue = curValue + value;
				else
					break;
				end
			end
			return math.floor(curValue);
		else
			LogAndPrint('DataError::', 'Status data is invalid', obj.name);
			return 0;
		end
	else
		return 0;
	end
end
function CalcAddFloat100ByLv(obj, arg, lv)
	if obj and obj.name and obj.name ~= 'None' then
		if obj.Status.name then
			local curValue = 0;
			for index, value in ipairs (obj.Status[arg]) do
				if index <= lv then
					curValue = curValue + value;
				else
					break;
				end
			end
			return math.floor(curValue*100)/100;
		else
			LogAndPrint('DataError::', 'Status data is invalid', obj.name);
			return 0;
		end
	else
		return 0;
	end
end
---------------------------------------------------------------------------------------
-- CalculatedProperty_SpecialCase_ 스테이터스에서 추가계산해주는 부분.
---------------------------------------------------------------------------------------
function CalculatedProperty_SpecialCase_MoveDist(obj, arg, data)
	local result = 0;
	local info = {};
	
	local value_Temperature = 0;
	local temperature = 'Normal';
	local mission = GetMission_Shared(obj);
	if mission then
		temperature = mission.Temperature.name;
	end
	if temperature == 'ExtremelyHot' then
		value_Temperature = -1;
	elseif temperature == 'Freezing' then
		value_Temperature = -1;
	end
	if value_Temperature ~= 0 then
		result = result + value_Temperature;
		table.insert(info, {Type = 'Temperature', Value = value_Temperature, ValueType = 'Formula', Temperature = temperature});
	end
	-- 야생 생활 / 환경 적응
	if value_Temperature < 0 then
		local immuneMastery = GetMasteryMasteredWithDataLikeWildLife(obj, data);
		-- 혹한의 야수(한파)
		if not immuneMastery and temperature == 'Freezing' then
			immuneMastery = GetMasteryMasteredWithData(obj, 'ColdBeast', data)
		end
		-- 폭염의 야수(폭염)
		if not immuneMastery and temperature == 'ExtremelyHot' then
			immuneMastery = GetMasteryMasteredWithData(obj, 'HotBeast', data)
		end
		if immuneMastery then
			result = result - value_Temperature;
			table.insert(info, {Type = immuneMastery.name, Value = -1 * value_Temperature, ValueType = 'Mastery'});
		end
	end
	
	return result, info;
end
function CalculatedProperty_SpecialCase_RegenVigor(obj, arg, data)
	local result = 0;
	local lv = obj.Lv;
	if data then
		lv = data.Lv;
	end	
	return result;
end
function CalculatedProperty_SpecialCase_FireResistance(obj, arg, data)
	local result = 0;
	local lv = obj.Lv;
	if data then
		lv = data.Lv;
	end
	-- 레벨업에 따른 화염 저항력 증가.
	if obj.ESP and obj.ESP.name then
		result = result + CalcAddIntByLv(obj.ESP, 'FireResistance', lv);
	end
	return result;
end
function CalculatedProperty_SpecialCase_IceResistance(obj, arg, data)
	local result = 0;
	local lv = obj.Lv;
	if data then
		lv = data.Lv;
	end
	-- 레벨업에 따른 얼음 저항력 증가.
	if obj.ESP and obj.ESP.name then
		result = result + CalcAddIntByLv(obj.ESP, 'IceResistance', lv);
	end
	return result;
end
function CalculatedProperty_SpecialCase_LightningResistance(obj, arg, data)
	local result = 0;
	local lv = obj.Lv;
	if data then
		lv = data.Lv;
	end
	-- 레벨업에 따른 번개 저항력 증가.
	if obj.ESP and obj.ESP.name then
		result = result + CalcAddIntByLv(obj.ESP, 'LightningResistance', lv);
	end
	return result;
end
function CalculatedProperty_SpecialCase_WindResistance(obj, arg, data)
	local result = 0;
	local lv = obj.Lv;
	if data then
		lv = data.Lv;
	end
	-- 레벨업에 따른 바람 저항력 증가.
	if obj.ESP and obj.ESP.name then
		result = result + CalcAddIntByLv(obj.ESP, 'WindResistance', lv);
	end
	return result;
end
function CalculatedProperty_SpecialCase_EarthResistance(obj, arg, data)
	local result = 0;
	local lv = obj.Lv;
	if data then
		lv = data.Lv;
	end
	-- 레벨업에 따른 대지 저항력 증가.
	if obj.ESP and obj.ESP.name then
		result = result + CalcAddIntByLv(obj.ESP, 'EarthResistance', lv);
	end
	return result;
end
function CalculatedProperty_SpecialCase_WaterResistance(obj, arg, data)
	local result = 0;
	local lv = obj.Lv;
	if data then
		lv = data.Lv;
	end
	-- 레벨업에 따른 물 저항력 증가.
	if obj.ESP and obj.ESP.name then
		result = result + CalcAddIntByLv(obj.ESP, 'WaterResistance', lv);
	end
	return result;
end
function CalculatedProperty_SpecialCase_ESPPower(obj, arg, data)
	local result = 0;
	local lv = obj.Lv;
	if data then
		lv = data.Lv;
	end	
	-- 레벨업에 따른 초능력 증가. - 이능력 속성
	result = result + CalcAddIntByLv(obj.ESP, 'ESPPower', lv);
	return result;
end
----------------------------------------------------
--- JobStatus 직업스탯 반영
----------------------------------------------------
function CalculatedProperty_JobStatus_AddInt(job, arg, lv)
	return CalcAddIntByLv(job, arg, lv) or 0;
end
function CalculatedProperty_JobStatus_AddFloat100(job, arg, lv)
	return CalcAddFloat100ByLv(job, arg, lv) or 0;
end
--- 레벨에 따른 스텟 증가분 적용
function CalculatedProperty_JobStatus_MaxHP(job, arg, lv)
	local baseValue = 0; 
	if job and job.name and job.name ~= 'None' then
		baseValue = job[arg];
	end
	local result = baseValue + CalculatedProperty_JobStatus_AddInt(job, arg, lv);
	return result;
end
function CalculatedProperty_JobStatus_MaxVigor(job, arg, lv)
	local baseValue = 0; 
	if job and job.name and job.name ~= 'None' then
		baseValue = job[arg];
	end
	local result = baseValue;
	return result;
end
function CalculatedProperty_JobStatus_RegenVigor(job, arg, lv)
	local baseValue = 0; 
	if job and job.name and job.name ~= 'None' then
		baseValue = job[arg];
	end
	local result = baseValue;
	return result;
end
function CalculatedProperty_JobStatus_SightRange(job, arg, lv)
	local baseValue = 0; 
	if job and job.name and job.name ~= 'None' then
		baseValue = job[arg];
	end
	local result = baseValue;
	return result;
end
function CalculatedProperty_JobStatus_Speed(job, arg, lv)
	local baseValue = 0; 
	if job and job.name and job.name ~= 'None' then
		baseValue = job[arg];
	end
	local result = baseValue;
	return result;
end
function CalculatedProperty_JobStatus_MoveDist(job, arg, lv)
	local baseValue = 0; 
	if job and job.name and job.name ~= 'None' then
		baseValue = job[arg];
	end
	local result = baseValue;
	return result;
end
function CalculatedProperty_JobStatus_Accuracy(job, arg, lv)
	local baseValue = 0; 
	if job and job.name and job.name ~= 'None' then
		baseValue = job[arg];
	end
	local result = baseValue + CalculatedProperty_JobStatus_AddFloat100(job, arg, lv);
	return math.floor(result*100)/100;
end
function CalculatedProperty_JobStatus_AttackPower(job, arg, lv)
	local baseValue = 0; 
	if job and job.name and job.name ~= 'None' then
		baseValue = job[arg];
	end
	local result = baseValue + CalculatedProperty_JobStatus_AddInt(job, arg, lv);
	return result;
end
function CalculatedProperty_JobStatus_ESPPower(job, arg, lv)
	local baseValue = 0; 
	if job and job.name and job.name ~= 'None' then
		baseValue = job[arg];
	end
	local result = baseValue + CalculatedProperty_JobStatus_AddInt(job, arg, lv);
	return result;
end
function CalculatedProperty_JobStatus_Armor(job, arg, lv)
	local baseValue = 0; 
	if job and job.name and job.name ~= 'None' then
		baseValue = job[arg];
	end
	local result = baseValue + CalculatedProperty_JobStatus_AddInt(job, arg, lv);
	return result;
end
function CalculatedProperty_JobStatus_Resistance(job, arg, lv)
	local baseValue = 0; 
	if job and job.name and job.name ~= 'None' then
		baseValue = job[arg];
	end
	local result = baseValue + CalculatedProperty_JobStatus_AddInt(job, arg, lv);
	return result;
end
function CalculatedProperty_JobStatus_Block(job, arg, lv)
	local baseValue = 0; 
	if job and job.name and job.name ~= 'None' then
		baseValue = job[arg];
	end
	local result = baseValue + CalculatedProperty_JobStatus_AddFloat100(job, arg, lv);
	return math.floor(result*100)/100;
end
function CalculatedProperty_JobStatus_Dodge(job, arg, lv)
	local baseValue = 0; 
	if job and job.name and job.name ~= 'None' then
		baseValue = job[arg];
	end
	local result = baseValue + CalculatedProperty_JobStatus_AddFloat100(job, arg, lv);
	return math.floor(result*100)/100;
end
function CalculatedProperty_JobStatus_CriticalStrikeChance(job, arg, lv)
	local baseValue = 0; 
	if job and job.name and job.name ~= 'None' then
		baseValue = job[arg];
	end
	local result = baseValue + CalculatedProperty_JobStatus_AddFloat100(job, arg, lv);
	return math.floor(result*100)/100;
end
function CalculatedProperty_JobStatus_CriticalStrikeDeal(job, arg, lv)
	local baseValue = 0; 
	if job and job.name and job.name ~= 'None' then
		baseValue = job[arg];
	end
	local result = baseValue + CalculatedProperty_JobStatus_AddFloat100(job, arg, lv);
	return math.floor(result*100)/100;
end
function CalculatedProperty_JobStatus_PiercingResistance(job, arg, lv)
	return CalculatedProperty_JobStatus_AddInt(job, arg, lv);
end
function CalculatedProperty_JobStatus_SlashingResistance(job, arg, lv)
	return CalculatedProperty_JobStatus_AddInt(job, arg, lv);
end
function CalculatedProperty_JobStatus_BluntResistance(job, arg, lv)
	return CalculatedProperty_JobStatus_AddInt(job, arg, lv);
end
----------------------------------------------------

function IsLightTime(timeName)
	return timeName == 'Daytime' or timeName == 'Morning' or timeName == 'Indoor_Light';
end
function IsDarkTime(timeName)
	return timeName == 'Night' or timeName == 'Evening' or timeName == 'Indoor_Dark';
end
function CalculatedProperty_SpecialCase_SightRange(obj, arg, data)
	local result = 0;
	local info = {};
	
	local mission = nil;
	-- case 1. 미션의 낮/밤에 따른 시야 증감.
	if not IsMission() then
		return result;
	end

	if IsMissionServer() then
		mission = GetMission(obj);
	elseif IsClient() then
		local session = GetSession();
		mission = session.current_mission;
	else
		return result;
	end
	-- 1. 미션 낮/밤 기본 패널티.
		if obj.Race.name ~= 'Object' then
		local sightPenalty = mission.MissionTime.SightPenalty;
		result = result + sightPenalty;
		if sightPenalty ~= 0 then
			table.insert(info, {Type = 'MissionTime', Value = sightPenalty, ValueType = 'Formula', MissionTime = mission.MissionTime.name});
			-- 달빛의 야수(저녁, 밤, 어두운 실내)
			local immuneMastery = nil;
			if IsDarkTime(mission.MissionTime.name) then
				immuneMastery = GetMasteryMasteredWithData(obj, 'MoonBeast', data);
				if not immuneMastery and HasBuff(obj, 'Illumination') then
					immuneMastery = GetClassList('Mastery')['Illumination'];
				end
			end
			if immuneMastery then
				result = result - sightPenalty;
				table.insert(info, MakeMasteryStatInfo(immuneMastery.name, -1 * sightPenalty));
			end
		end
		-- 2. 미션 낮/밤에 따른 시야 적용.
		if IsLightTime(mission.MissionTime.name) then
			result = result + obj.SightRange_Day;
		elseif IsDarkTime(mission.MissionTime.name) then
			result = result + obj.SightRange_Night;
		end
	end
	return result, info;
end
-------------------------------------------------------------------
-- CP 포맷
-------------------------------------------------------------------
local sharedKeywordTable = nil;
local sharedKeywordTableNoColor = nil;
g_masteryApplyAmountExplain = false;
local customKeywordTable = {
	Buff = {
		Dead = function(buff)
			return GetDeadText();
		end,
		BuffTitleColor = function(buff)
			return GetBuffTitleColor(buff);
		end,
		BuffTitle = function(buff)
			return GetBuffText(buff);
		end,
		StatusMessage = function(buff)
			return GetStatusMessage(buff);
		end,
		StatusMessageByLevel = function(buff)
			return GetStatusMessageByLevel(buff);
		end,
		ImmortalMessage = function(buff)
			return GetBuffImmortalMessageText(buff);
		end,
		ImmuneRace = function(buff)
			return GetBuffImmuneRaceText(buff);
		end,
		ImmuneRaceMessage = function(buff)
			return GetBuffImmuneRaceMessageText(buff);
		end,
		BreakTypeMessage = function(buff)
			return GetBuffBreakTypeMessageText(buff);
		end,
		GroupTypeMessage = function(buff)
			return GetBuffGroupTypeMessageText(buff);
		end,
		TurnMessage = function(buff)
			return GetBuffTurnMessageText(buff);
		end,
		HPModifyTimingValue = function(buff)
			return GetBuffHPModifyTimingText(buff);
		end,
		HPChange = function(buff)
			return GetBuffHPChangeText(buff);
		end,
		HPChangeType = function(buff)
			return GetBuffHPChangeTypeText(buff);
		end,
		HPModifier = function(buff)
			return GetBuffHPModifierText(buff);
		end,
		DischargeOnAttack = function(buff)
			return GetBuffDischargeOnAttackText(buff);
		end,
		DischargeOnHit = function(buff)
			return GetBuffDischargeOnHitText(buff);
		end,
		DischargeDamageType = function(buff)
			return GetBuffDischargeDamageTypeText(buff);
		end,
		ActionController = function(buff)
			return GetBuffActionControllerText(buff);
		end,
		HPDrainValue = function(buff)
			return GetBuffHPDrainValueText(buff);
		end,
		HPDrainMessage = function(buff)
			return GetBuffHPDrainMessageText(buff);
		end,
		Explosion = function(buff)
			return GetBuffExplosionText(buff);
		end,		
		ApplyAmountValue = function(buff)
			return MasteryApplyAmountValue(buff.ApplyAmountType, 'ApplyAmount');
		end,
		ApplyAmountValue2 = function(buff)
			return MasteryApplyAmountValue(buff.ApplyAmountType2, 'ApplyAmount2');
		end,
		ApplyAmountValue3 = function(buff)
			return MasteryApplyAmountValue(buff.ApplyAmountType3, 'ApplyAmount3');
		end,
		ApplyAmountValue4 = function(buff)
			return MasteryApplyAmountValue(buff.ApplyAmountType4, 'ApplyAmount4');
		end,
		Overcharge = function(buff)
			return '$White$'..GetWord('SPFullGained')..'$Blue_ON$';
		end,
		AddBuffName = function(buff)
			local buffList = GetClassList('Buff');
			local buff = SafeIndex(buffList, buff.AddBuff);
			if buff then
				return GetBuffText(buff);
			else
				return nil;
			end
		end,
		AddBuffName2 = function(buff)
			local buffList = GetClassList('Buff');
			local buff = SafeIndex(buffList, buff.AddBuff2);
			if buff then
				return GetBuffText(buff);
			else
				return nil;
			end
		end,
		AuraBuffName = function(buff)
			local buffList = GetClassList('Buff');
			local buff = SafeIndex(buffList, buff.AuraBuff);
			if buff then
				return GetBuffText(buff);
			else
				return nil;
			end
		end,
		BuffSystemMessage = function(buff)
			return GetBuffSystemMessageText(buff);
		end,
		NonCoverableMessage = function(buff)
			return GetNonCoverableMessage(buff);
		end,
		MaxStack = function(buff)
			return '$White$'..buff.Base_MaxStack..'$Blue_ON$';
		end,
		BuffGroup = function(buff)
			return GetBuffGroupText(buff);
		end,
	},
	Mastery = {
		Dead = function(mastery)
			return GetDeadText(true);
		end,
		MasteryAbility = function(mastery)
			local result = '';
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				local color = GetAbilityTitleColor(ability) ;
				result = '$'..color..'$'..ability.FullTitle..'$Blue_ON$';
			end
			return result;
		end,
		ModifyAbility = function(mastery)
			local result = '';
			local ability = GetMasteryModifyAbility(mastery);
			if ability then
				local color = GetAbilityTitleColor(ability) ;
				result = '$'..color..'$'..ability.Title..'$Blue_ON$';
			end
			return result;
		end,
		MasteryAbilityToolTip = function(mastery)
			local result = '';
			local first = true;
			local AddAbilityTooltipOne = function(ability)
				if not first then
					result = result .. '\n\n';
				end
				first = false;
				local color = GetAbilityTitleColor(ability) ;
				result = result .. '$'..color..'$'..ability.Title..'\n'..'$Blue_ON$';
				result = result .. GetAbilityTypeDataText(ability)..'\n'..'$Blue_ON$';
				result = result .. AbilityTooltip_CommonShared(ability, {}, true);
			end
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				AddAbilityTooltipOne(ability);
				if #ability.AutoActiveAbility > 0 then
					local hideSet = {};
					if ability.AbilitySubMenu ~= '' then
						local detailClsList = GetClassList(ability.AbilitySubMenu);
						if detailClsList then
							for _, detailCls in pairs(detailClsList) do
								hideSet[detailCls.Ability.name] = true;
							end
						end
					end
					local abilityList = GetClassList('Ability');
					for _, autoActiveAbility in ipairs(ability.AutoActiveAbility) do
						local abilityCls = abilityList[autoActiveAbility];
						if abilityCls and not hideSet[abilityCls.name] then
							AddAbilityTooltipOne(abilityCls);
						end
					end
				end
			end
			return result;
		end,
		MasteryChainAbilityToolTip = function(mastery)
			local result = '';
			local first = true;
			local AddAbilityTooltipOne = function(ability)
				if not first then
					result = result .. '\n\n';
				end
				first = false;
				local color = GetAbilityTitleColor(ability) ;
				result = result .. '$'..color..'$'..ability.Title..'\n'..'$Blue_ON$';
				result = result .. GetAbilityTypeDataText(ability)..'\n'..'$Blue_ON$';
				result = result .. AbilityTooltip_CommonShared(ability, {}, true);
			end
			local ability = GetMasteryAbility(mastery, 'ChainAbility');
			if ability then
				AddAbilityTooltipOne(ability);
				if #ability.AutoActiveAbility > 0 then
					local hideSet = {};
					if ability.AbilitySubMenu ~= '' then
						local detailClsList = GetClassList(ability.AbilitySubMenu);
						if detailClsList then
							for _, detailCls in pairs(detailClsList) do
								hideSet[detailCls.Ability.name] = true;
							end
						end
					end
					local abilityList = GetClassList('Ability');
					for _, autoActiveAbility in ipairs(ability.AutoActiveAbility) do
						local abilityCls = abilityList[autoActiveAbility];
						if abilityCls and not hideSet[abilityCls.name] then
							AddAbilityTooltipOne(abilityCls);
						end
					end
				end
			end
			return result;
		end,
		ModifyAbilityToolTip = function(mastery)
			local result = '';
			local ability = GetMasteryModifyAbility(mastery);
			if ability then
				result = '$ModifyAbility$'..'\n'..'$Blue_ON$';
				if ability.Desc_Base == '' then
					result = result .. ability.Desc;
				else
					result = result..ability.Desc_Base..' '..ability.Desc;
				end
			end
			return result;
		end,
		Target = function(mastery)
			local result = '';
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				result = GetAbilityTargetText(ability);
			end
			return result;
		end,
		AttackSubType = function(mastery)
			return GetAbilityAttackSubTypeText(mastery); 
		end,
		Attacker = function(mastery)
			return GetAbilityAttackerText();
		end,
		BaseDamage = function(mastery)
			local result = '';
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				result = GetAbilityApplyAmount(ability);
			end
			return result;
		end,
		ApplyAct = function(mastery)
			local result = '';
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				result = '$White$'..ability.ApplyAct..'$Blue_ON$';
			end	
			return result;
		end,
		CoolValue = function(mastery)
			local result = '';
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				result = GetAbilityCoolValueText(ability);
			end
			return result;
		end,
		DamageAmount = function(mastery)
			local result = '$BaseDamage$';
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				result = GetDamageAmountText(ability);
			end
			return result;
		end,
		DamageType = function(mastery)
			local result = ''
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				result = GetAbilityDamageTypeText(ability);
			end
			return result;
		end,
		ApplyBuffChance = function(mastery)
			local result = '';
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				result = GetAbilityApplyBuffChanceText(ability);
			end
			return result;
		end,
		ApplyBuffLv = function(mastery)
			local result = '';
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				result = GetAbilityApplyBuffLvText(ability);
			end
			return result;
		end,
		ApplyBuffConvertLv = function(mastery)
			local result = '';
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				result = GetAbilityApplyBuffConvertLvText(ability);
			end
			return result;
		end,
		ApplyBuffColor = function(mastery)
			local result = '';
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				result = GetAbilityApplyBuffColorText(ability);
			end
			return result;
		end,
		ApplyBuff = function(mastery)
			local result = '';
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				result = GetAbilityApplyBuffText(ability);
			end			
			return result;
		end,
		MasteryBuff = function(mastery)
			return GetMasteryBuffText(mastery.Buff);
		end,
		MasterySubBuff = function(mastery)
			return GetMasteryBuffText(mastery.SubBuff);
		end,
		MasteryThirdBuff = function(mastery)
			return GetMasteryBuffText(mastery.ThirdBuff);
		end,
		MasteryForthBuff = function(mastery)
			return GetMasteryBuffText(mastery.ForthBuff);
		end,
		MasteryBuffGroup = function(mastery)
			return GetMasteryBuffGroupText(mastery.BuffGroup);
		end,
		MasterySubBuffGroup = function(mastery)
			return GetMasteryBuffGroupText(mastery.SubBuffGroup);
		end,
		MasteryThirdBuffGroup = function(mastery)
			return GetMasteryBuffGroupText(mastery.ThirdBuffGroup);
		end,
		MasteryForthBuffGroup = function(mastery)
			return GetMasteryBuffGroupText(mastery.ForthBuffGroup);
		end,
		MasteryFifthBuffGroup = function(mastery)
			return GetMasteryBuffGroupText(mastery.FifthBuffGroup);
		end,
		MasteryBuffToolTip = function(mastery)
			return GetBuffToolTip(mastery.Buff);
		end,
		MasterySubBuffToolTip = function(mastery)
			return GetBuffToolTip(mastery.SubBuff)
		end,
		MasteryThirdBuffToolTip = function(mastery)
			return GetBuffToolTip(mastery.ThirdBuff)
		end,
		MasteryForthBuffToolTip = function(mastery)
			return GetBuffToolTip(mastery.ForthBuff)
		end,
		MasteryFieldEffect = function(mastery)
			return GetMasteryFieldEffectText(mastery.FieldEffect);
		end,
		MasteryMastery = function(mastery)
			return GetMasteryTitleText(mastery.Mastery);
		end,
		MasteryStartJobMastey = function(mastery)
			local owner = nil;
			if IsObject(mastery) then
				owner = GetMasteryOwner(mastery);
			end
			local startJobMasteryName = SafeIndex(owner, 'StartJob', 'BasicMastery');
			if startJobMasteryName then
				return string.format(GuideMessage('MasteryTooltip_GetJobMasteryByOwnerExplainSuperStar'), GetMasteryTitleText(GetClassList('Mastery')[startJobMasteryName]));
			else
				local jobList = GetClassList('Job');
				local job = '$White$'..jobList['Clown'].Title..'$ColorEnd$';
				local job2 = '$White$'..jobList['Dancer'].Title..'$ColorEnd$';
				local job3 = '$White$'..jobList['Singer'].Title..'$ColorEnd$';
				local job4 = '$White$'..jobList['Musician'].Title..'$ColorEnd$';
				return FormatMessage(GuideMessage('MasteryTooltip_GetJobMasteryByCommonExplainSuperStar'),
					{ Job = job, Job2 = job2, Job3 = job3, Job4 = job4 }, nil, true				
				);
			end
		end,
		MasteryStartJobMasteyToolTip = function(mastery)
			local owner = nil;
			if IsObject(mastery) then
				owner = GetMasteryOwner(mastery);
			end
			local startJobMasteryName = SafeIndex(owner, 'StartJob', 'BasicMastery');
			if startJobMasteryName then
				return GetMasteryToolTip(GetClassList('Mastery')[startJobMasteryName]);
			else
				return '';
			end
		end,
		MasteryImmuneMachine = function(mastery)
			local raceList = GetClassList('Race');
			return FormatMessage(GuideMessage('MasteryImmuneRace'), { ImmuneRace = raceList['Machine'].Title });
		end,
		MasteryMasteryToolTip = function(mastery)
			return GetMasteryToolTip(mastery.Mastery);
		end,
		MasteryExclusiveToolTip = function(mastery)
			return GetMasteryExclusiveText(mastery);
		end,
		MasteryNeedCostToolTip = function(mastery)
			return GetMasteryNeedCostText(mastery);
		end,
		RequireBuff = function(mastery)
			local result = '';
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				result = GetAbilityRequireBuffText(ability);	
			end			
			return result;
		end,
		RemoveBuff = function(mastery)
			local result = '';
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				result = GetAbilityRemoveBuffText(ability);	
			end			
			return result;
		end,
		ApplyBuffToolTip = function(mastery)
			local result = '';
			return result;
		end,
		RemoveBuffTooltip = function(mastery)
			local result = '';
			return result;
		end,
		HitRateType = function(mastery)
			local result = '';
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				result = GetAbilityHitRateTypeText(ability);
			end				
			return result;
		end,
		TargetType = function(mastery)
			local result = '';
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				result = GetAbilityTargetTypeText(ability);
			end				
			return result;
		end,
		UseCount = function(mastery)
			local result = '';
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				result = GetAbilityUseCountText(ability);
			end				
			return result;
		end,
		RangeDistance = function(mastery)
			local result = '';
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				result = GetAbilityRangeDistanceText(ability);
			end				
			return result;
		end,
		RangeRadius = function(mastery)
			local result = '';
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				result = GetAbilityRangeRadiusText(ability);
			end				
			return result;
		end,
		AbilitySystemMessage = function(mastery)
			local result = '';
			local ability = GetMasteryAbility(mastery, 'Ability');
			if ability then
				result = GetAbilitySystemMessageText(ability);
			end				
			return result;			
		end,
		StatusMessage = function(mastery)
			return GetStatusMessage(mastery);
		end,
		StatusMessageByLevel = function(mastery)
			return GetStatusMessageByLevel(mastery);
		end,
		ApplyAmountValue = function(mastery)
			return MasteryApplyAmountValue(mastery.ApplyAmountType, 'ApplyAmount', true);
		end,
		ApplyAmountValue2 = function(mastery)
			return MasteryApplyAmountValue(mastery.ApplyAmountType2, 'ApplyAmount2', true);
		end,
		ApplyAmountValue3 = function(mastery)
			return MasteryApplyAmountValue(mastery.ApplyAmountType3, 'ApplyAmount3', true);
		end,
		ApplyAmountValue4 = function(mastery)
			return MasteryApplyAmountValue(mastery.ApplyAmountType4, 'ApplyAmount4', true);
		end,
		ApplyAmountValue5 = function(mastery)
			return MasteryApplyAmountValue(mastery.ApplyAmountType5, 'ApplyAmount5', true);
		end,
		MasterySystemMessage = function(mastery)
			return GetMasterySystemMessageText(mastery);
		end,
		MasteryBuffMessage = function(mastery)
			return GetMasteryBuffMessageText(mastery);
		end,
		MasterySPMessage = function(mastery)
			return GetMasterySPMessageText(mastery);
		end,
		DetailedSnipeDesc = function(mastery)
			return GetMasteryDetailedSnipeDescText(mastery);
		end,
		MasteryPerformanceMessage = function(mastery)
			return GetMasteryPerformanceMessageText(mastery);
		end,
		MasteryPerformanceEffectList = function(mastery)
			return GetMasteryPerformanceEffectListText(mastery);
		end,
		MasteryWeather = function(mastery)
			return GetMasteryWeatherText(mastery.Weather);
		end,
		MasteryWeather2 = function(mastery)
			return GetMasteryWeatherText(mastery.Weather2);
		end,
		MasteryWeather3 = function(mastery)
			return GetMasteryWeatherText(mastery.Weather3);
		end,
		MasteryWeather4 = function(mastery)
			return GetMasteryWeatherText(mastery.Weather4);
		end,
		MasteryStat = function(mastery)
			return GetMasteryStatText(mastery.Stat, 'Normal');
		end,
		MasteryStat2 = function(mastery)
			return GetMasteryStatText(mastery.Stat2, 'Normal');
		end,
		MasteryStat3 = function(mastery)
			return GetMasteryStatText(mastery.Stat3, 'Normal');
		end,
		MasteryStat4 = function(mastery)
			return GetMasteryStatText(mastery.Stat4, 'Normal');
		end,
		MasteryStat5 = function(mastery)
			return GetMasteryStatText(mastery.Stat5, 'Normal');
		end,
		MasteryMaxStat = function(mastery)
			return GetMasteryStatText(mastery.Stat, 'Max');
		end,
		MasteryMaxStat2 = function(mastery)
			return GetMasteryStatText(mastery.Stat2, 'Max');
		end,
		MasteryMaxStat3 = function(mastery)
			return GetMasteryStatText(mastery.Stat3, 'Max');
		end,
		MasteryMaxStat4 = function(mastery)
			return GetMasteryStatText(mastery.Stat4, 'Max');
		end,
		MasteryMaxStat5 = function(mastery)
			return GetMasteryStatText(mastery.Stat5, 'Max');
		end,
		MasteryAbilityType = function(mastery)
			return GetMasteryAbilityTypeText(mastery.RefAbilityType);
		end,
		MasteryAbilityType2 = function(mastery)
			return GetMasteryAbilityTypeText(mastery.RefAbilityType2);
		end,
		MasteryAbilityType3 = function(mastery)
			return GetMasteryAbilityTypeText(mastery.RefAbilityType3);
		end,
		MasteryAbilityType4 = function(mastery)
			return GetMasteryAbilityTypeText(mastery.RefAbilityType4);
		end,
		MasteryOrganizationType = function(mastery)
			return GetMasteryOrganizationTypeText(mastery.RefOrganizationType);
		end,	
		CharacterLevel = function(mastery)
			return GetWord('CharacterLevel');
		end,
		MasteryDescBase = function(mastery)
			return GetMasteryMasteryDescBaseText(mastery.Desc_Base);
		end
	},
	Ability = {
		Dead = function(ability)
			return GetDeadText();
		end,
		Title = function(ability)
			return ability.Title;
		end,
		ApplyAct = function(ability)
			return '$White$'..ability.ApplyAct..'$Blue_ON$';
		end,
		CoolValue = function(ability)
			return GetAbilityCoolValueText(ability);
		end,
		BaseDamage = function(ability)
			return GetAbilityApplyAmount(ability);
		end,
		DamageType = function(ability)
			return GetAbilityDamageTypeText(ability);
		end,
		Target = function(ability)
			return GetAbilityTargetText(ability);
		end,
		ApplyBuffChance = function(ability)
			return GetAbilityApplyBuffChanceText(ability);
		end,
		ApplyBuffLv = function(ability)
			return GetAbilityApplyBuffLvText(ability);
		end,
		ApplySubBuffChance = function(ability)
			return GetAbilityApplySubBuffChanceText(ability);
		end,
		ApplySubBuffLv = function(ability)
			return GetAbilityApplySubBuffLvText(ability);
		end,
		ApplyBuffConvertLv = function(ability)
			return GetAbilityApplyBuffConvertLvText(ability);
		end,
		ApplyBuff = function(ability)
			return GetAbilityApplyBuffText(ability);
		end,
		CancelBuff = function(ability)
			return GetAbilityCancelBuffText(ability);
		end,
		ApplySubBuff = function(ability)
			return GetAbilityApplySubBuffText(ability);
		end,
		ApplyBuffColor = function(ability)
			return GetAbilityApplyBuffColorText(ability);
		end,		
		RequireBuff = function(ability)
			return GetAbilityRequireBuffText(ability);	
		end,
		RemoveBuff = function(ability)
			return GetAbilityRemoveBuffText(ability);	
		end,
		ApplyBuffToolTip = function(ability)
			return GetAbilityBuffToolTip(ability);
		end,
		CancelBuffTooltip = function(ability)
			return GetBuffToolTip(ability.CancelTargetBuff, ability.CancelTargetBuffLv);
		end,
		RemoveBuffTooltip = function(ability)
			return GetBuffToolTip(ability.RemoveBuff);
		end,
		HitRateType = function(ability)
			return GetAbilityHitRateTypeText(ability);
		end,
		TargetType = function(ability)
			return GetAbilityTargetTypeText(ability);
		end,
		RangeDistance = function(ability)
			return GetAbilityRangeDistanceText(ability);
		end,
		RangeRadius = function(ability)
			return GetAbilityRangeRadiusText(ability);
		end,
		AbilityDescMessage = function(ability)
			return GetAbilityDescMessageText(ability);
		end,
		ChainAttackMessage = function(ability)
			return GetChainAttackMessage(ability);
		end,
		KnockbackPowerApplyActMessage = function(ability)
			return GetKnockbackPowerApplyActMessage(ability);
		end,		
		KnockbackPowerMessage = function(ability)
			return GetKnockbackPowerMessage(ability);
		end,
		ApplyActMessage = function(ability)
			return GetApplyActMessage(ability);
		end,
		ApplyBuffMessage = function(ability)
			return GetApplyBuffMessage(ability);
		end,
		ApplySubBuffMessage = function(ability)
			return GetApplySubBuffMessage(ability);
		end,
		ApplyFieldEffectsMessage = function(ability)
			return GetApplyFieldEffectsMessage(ability);
		end,
		NotMoveAttackApplyMessage = function(ability)
			return GetNotMoveAttackApplyMessage(ability);
		end,
		DistanceAttackApplyMessage = function(ability)
			return GetDistanceAttackApplyMessage(ability);
		end,
		NoCoverAttackApplyMessage = function(ability)
			return GetNoCoverAttackApplyMessage(ability);
		end,
		RelocatorMoveTypeFlashMessage = function(ability)
			return GetRelocatorMoveTypeFlashMessage(ability);
		end,
		NotMoveAttackApplyAmountRatio = function(ability)
			return GetNotMoveAttackApplyAmountRatioText(ability);
		end,
		DistanceAttackApplyAmountRatio = function(ability)
			return GetDistanceAttackApplyAmountRatioText(ability);
		end,
		NoCoverAttackApplyAmountRatio = function(ability)
			return GetNoCoverAttackApplyAmountRatioText(ability);
		end,
		CostBurnMessage = function(ability)
			return GetCostBurnMessage(ability);
		end,
		CostBurnRatio = function(ability)
			return GetCostBurnRatioText(ability);
		end,
		CostBurnDamage = function(ability)
			return GetCostBurnDamageText(ability);
		end,
		HPDrainRatioMessage = function(ability)
			return GetHPDrainRatioMessage(ability);
		end,
		HPDrainRatio = function(ability)
			return GetHPDrainRatioText(ability);
		end,
		ApplyCost = function(ability)
			return GetAbilityApplyCostText(ability);
		end,
		ApplyBuffDuration = function(ability)
			return GetApplyBuffDurationText(ability);
		end,
		StatusMessage = function(ability)
			return GetStatusMessage(ability);
		end,
		StatusMessageByLevel = function(ability)
			return GetStatusMessageByLevel(ability);
		end,
		ImmuneRace = function(ability)
			return GetAbilityImmuneRaceText(ability);
		end,
		ImmuneRaceMessage = function(ability)
			return GetAbilityImmuneRaceMessageText(ability);
		end,
	},
	Status = {
		Dead = function(status)
			return GetDeadText();
		end,
		Status = function(status)
			local result = '$White$'..status.Title..'$Blue_ON$';
			return result;
		end,
		CriticalStrikeChance = function(status)
			local result = '';
			local statusList = GetClassList('Status');
			local criticalStrikeChanceTitle = GetWithoutError(statusList['CriticalStrikeChance'], 'Title');
			if criticalStrikeChanceTitle then
				result = '$White$'..criticalStrikeChanceTitle..'$Blue_ON$';
			end
			return result;
		end		
	},
	Organization = {
		OrganizationDescMessage = function(Organization)
			return GetOrganizationDescMessageText(Organization);
		end
	},
	CostType = {
		Cost = function(costType)
			local result = '$'..costType.Color..'$'..costType.Title..'$Blue_ON$';
			return result;
		end	
	},
	DanceFinish = {
		ApplyAmountValue = function(danceFinish)
			return MasteryApplyAmountValue(danceFinish.ApplyAmountType, 'ApplyAmount');
		end,
		ApplyAmountValue2 = function(danceFinish)
			return MasteryApplyAmountValue(danceFinish.ApplyAmountType2, 'ApplyAmount2');
		end,
		MasteryBuff = function(danceFinish)
			return GetMasteryBuffText(danceFinish.Buff);
		end
	},
	PcStatus = {
		Status = function(status)
			local result = '$Yellow$'..status.Title..'$Blue_ON$';
			return result;
		end	
	},
	ReputationPolicy = {
		SupportItem = function(policy)
			return string.format('%s:$White$', GetWord('SupportItem'));			
		end,
		Troubleshooter = function(policy)
			return GetWord('Troubleshooter');
		end
	},
	Reputation = {
		WindWallArea = function(reputation)
			return GetWord('WindWallArea');			
		end,
		Troubleshooter = function(reputation)
			return GetWord('Troubleshooter');
		end,
		Division = function(reputation)
			return reputation.Division.Title;
		end,
		AreaType = function(reputation)
			return reputation.Type.Title;
		end,
		Sector = function(reputation)
			return reputation.Title;
		end,
		AllowDivisionReward	= function(reputation)
			return GetWord('AllowDivisionReward');
		end,
		OrganizationName = function(reputation)
			return reputation.Organization.Title;
		end
	},
	Item = {
		ItemSystemMessage = function(item)
			return GetItemSystemMessageText(item);
		end,
		Dead = function(item)
			return GetDeadText();
		end,
		ApplyBuff = function(item)
			local result = '';
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				result = GetAbilityApplyBuffText(ability);
			end			
			return result;
		end,
		ApplyTargetBuffLv = function(item)
			return item.Ability.ApplyTargetBuffLv;
		end,
		ApplyAct = function(item)
			local result = '';
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				result = '$White$'..ability.ApplyAct..'$Blue_ON$';
			end	
			return result;
		end,
		ItemAbility = function(item)
			local result = '';
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				local color = GetAbilityTitleColor(ability) ;
				result = '$'..color..'$'..ability.Title..'$Blue_ON$';
			end
			return result;
		end,
		ItemAbilityToolTip = function(item)
			local result = '';
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				result = '$ItemAbility$'..'\n'..'$Blue_ON$';
				result = result .. GetAbilityTypeDataText(ability)..'\n'..'$Blue_ON$';
				if ability.Desc_Base == '' then
					result = result .. ability.Desc;
				else
					result = result..ability.Desc_Base..' '..ability.Desc;
				end
				result = result..'$AbilitySystemMessage$';
			end
			return result;
		end,
		AbilitySystemMessage = function(item)
			local result = '';
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				result = GetAbilitySystemMessageText(ability);
			end				
			return result;			
		end,
		ApplyBuffToolTip = function(item)
			local result = '';
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				result = GetAbilityBuffToolTip(ability);
			end				
			return result;			
		end,
		RemoveBuff = function(item)
			local result = '';
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				result = GetAbilityRemoveBuffText(ability);	
			end			
			return result;
		end,
		RemoveBuffTooltip = function(item)
			local result = '';
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				result = GetBuffToolTip(ability.RemoveBuff);
			end
			return result;
		end,
		ItemAbilityApplyBuffToolTip = function(item)
			return GetBuffToolTip(item.Ability.ApplyTargetBuff, item.Ability.ApplyTargetBuffLv)
		end,
		DamageAmount = function(item)
			local result = '$BaseDamage$';
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				result = GetDamageAmountText(ability);
			end
			return result;
		end,
		Target = function(item)
			local result = '';
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				result = GetAbilityTargetText(ability);
			end
			return result;
		end,
		Attacker = function(item)
			return GetAbilityAttackerText();
		end,
		BaseDamage = function(item)
			local result = '';
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				result = GetAbilityApplyAmount(ability);
			end
			return result;
		end,
		CoolValue = function(item)
			local result = '';
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				result = GetAbilityCoolValueText(ability);
			end
			return result;
		end,
		DamageType = function(item)
			local result = ''
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				result = GetAbilityDamageTypeText(ability);
			end
			return result;
		end,		
		ApplyBuffChance = function(item)
			local result = '';
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				result = '$White$'..GetAbilityApplyBuffChanceText(ability)..'$Blue_ON$';
			end
			return result;
		end,
		ApplyBuffLv = function(item)
			local result = '';
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				result = GetAbilityApplyBuffLvText(ability);
			end
			return result;
		end,
		ApplyBuffConvertLv = function(item)
			local result = '';
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				result = GetAbilityApplyBuffConvertLvText(ability);
			end
			return result;
		end,
		ApplyBuffColor = function(item)
			local result = '';
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				result = GetAbilityApplyBuffColorText(ability);
			end
			return result;
		end,
		KnockbackPower = function(item)
			local result = '';
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				result = GetAbilityKnockbackPower(ability);
			end
			return result;
		end,
		ApplyCost = function(item)
			local result = '';
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				result = GetAbilityApplyCostText(ability);
			end
			return result;
		end,
		ApplyBuffDuration = function(item)
			local result = '';
			local ability = GetClassList('Ability')[item.Ability.name];
			if ability then
				result = GetApplyBuffDurationText(ability);
			end
			return result;
		end,
		MasteryBuff = function(item)
			local result = '';
			local mastery = GetClassList('Mastery')[item.Mastery.name];
			if mastery then
				result = GetMasteryBuffText(mastery.Buff);
			end
			return result;
		end,
		MasterySubBuff = function(item)
			local result = '';
			local mastery = GetClassList('Mastery')[item.Mastery.name];
			if mastery then
				result = GetMasteryBuffText(mastery.SubBuff);
			end
			return result;
		end,
		MasteryThirdBuff = function(item)
			local result = '';
			local mastery = GetClassList('Mastery')[item.Mastery.name];
			if mastery then
				result = GetMasteryBuffText(mastery.ThirdBuff);
			end
			return result;
		end,
		MasteryForthBuff = function(item)
			local result = '';
			local mastery = GetClassList('Mastery')[item.Mastery.name];
			if mastery then
				result = GetMasteryBuffText(mastery.ForthBuff);
			end
			return result;
		end,
		MasteryBuffGroup = function(item)
			local result = '';
			local mastery = GetClassList('Mastery')[item.Mastery.name];
			if mastery then
				result = GetMasteryBuffGroupText(mastery.BuffGroup);
			end
			return result;
		end,
		MasterySubBuffGroup = function(item)
			local result = '';
			local mastery = GetClassList('Mastery')[item.Mastery.name];
			if mastery then
				result = GetMasteryBuffGroupText(mastery.SubBuffGroup);
			end
			return result;
		end,
		MasteryBuffToolTip = function(item)
			local result = '';
			local mastery = GetClassList('Mastery')[item.Mastery.name];
			if mastery then
				result = GetBuffToolTip(mastery.Buff);
			end
			return result;
		end,
		MasterySubBuffToolTip = function(item)
			local result = '';
			local mastery = GetClassList('Mastery')[item.Mastery.name];
			if mastery then
				result = GetBuffToolTip(mastery.SubBuff);
			end
			return result;
		end,
		MasteryThirdBuffToolTip = function(item)
			local result = '';
			local mastery = GetClassList('Mastery')[item.Mastery.name];
			if mastery then
				result = GetBuffToolTip(mastery.ThirdBuff);
			end
			return result;
		end,
		MasteryForthBuffToolTip = function(item)
			local result = '';
			local mastery = GetClassList('Mastery')[item.Mastery.name];
			if mastery then
				result = GetBuffToolTip(mastery.ForthBuff);
			end
			return result;
		end,
		MasteryDesc = function(item)
			local result = '';
			local mastery = GetClassList('Mastery')[item.Mastery.name];
			if mastery then
				local msg = GetMasterySystemMessageText(mastery);
				result = GetFormatMessageText(mastery, msg);
			end
			return result;
		end,
	},
	MachineCategory = {
		StatusMessage = function(machineCategory)
			return GetStatusMessage(machineCategory.Monster.Object);
		end,
	},
	PerformanceEffect = {
		ApplyAmountValue = function(obj)
			return MasteryApplyAmountValue(obj.ApplyAmountType, 'ApplyAmount');
		end,
		ApplyAmountValue2 = function(obj)
			return MasteryApplyAmountValue(obj.ApplyAmountType2, 'ApplyAmount2');
		end,
		ApplyBuffName = function(obj)
			if obj.Buff then
				return GetBuffText(obj.Buff);
			else
				return nil;
			end
		end,
	},
	PerformanceGreat = {
		ApplyAmountValue = function(obj)
			return MasteryApplyAmountValue(obj.ApplyAmountType, 'ApplyAmount');
		end,
		ApplyAmountValue2 = function(obj)
			return MasteryApplyAmountValue(obj.ApplyAmountType2, 'ApplyAmount2');
		end,
		ApplyBuffName = function(obj)
			if obj.Buff then
				return GetBuffText(obj.Buff);
			else
				return nil;
			end
		end,
	},
	PerformanceFinish = {
		ApplyAmountValue = function(obj)
			return MasteryApplyAmountValue(obj.ApplyAmountType, 'ApplyAmount');
		end,
		ApplyAmountValue2 = function(obj)
			return MasteryApplyAmountValue(obj.ApplyAmountType2, 'ApplyAmount2');
		end,
		ApplyBuffName = function(obj)
			if obj.Buff then
				return GetBuffText(obj.Buff);
			else
				return nil;
			end
		end,
	},
	Performance = {
		PerformanceDescMessage = function(obj, target)
			return GetPerformanceDescMessageText(obj, target);
		end,
		PerformanceType = function(obj, target)
			return GetPerformanceTypeText(obj, target);
		end,
		PerformanceGreatList = function(obj, target)
			return GetPerformanceGreatListText(obj, target);
		end,
		PerformanceFinishList = function(obj, target)
			return GetPerformanceFinishListText(obj, target);
		end,
	},
	Quest = {
		QuestObjectiveSystemMessage = function(quest)
			return GetQuestSystemMessageText(quest, 'Objective');
		end,
		QuestTitleSystemMessage = function(quest)
			return GetQuestSystemMessageText(quest, 'Title');
		end,
		QuestType = function(quest)
			return GetQuestTypeMessageText(quest);
		end,
		TargetItem = function(quest)
			return GetQuestTargetItemText(quest);
		end,
		TargetCivilName = function(quest)
			return GetQuestTargetCivilNameText(quest);
		end
	},
	ApplyAmount = {
		ApplyAmountValue = function(obj)
			return MasteryApplyAmountValue(obj.ApplyAmountType, 'ApplyAmount', true);
		end,
		ApplyAmountValue2 = function(obj)
			return MasteryApplyAmountValue(obj.ApplyAmountType2, 'ApplyAmount2', true);
		end,
		ApplyAmountValue3 = function(obj)
			return MasteryApplyAmountValue(obj.ApplyAmountType3, 'ApplyAmount3', true);
		end,
		ApplyAmountValue4 = function(obj)
			return MasteryApplyAmountValue(obj.ApplyAmountType4, 'ApplyAmount4', true);
		end,
		ApplyAmountValue5 = function(obj)
			return MasteryApplyAmountValue(obj.ApplyAmountType5, 'ApplyAmount5', true);
		end,
	},
};
function GetCustomKeywordTable(idspace)
	return customKeywordTable[idspace];
end
function FormatMessageWithCustomKeywordTable(msg, obj, customKey, removeColor, ...)
	if sharedKeywordTable == nil then
		sharedKeywordTable = {};
		sharedKeywordTableNoColor = {};
		for key, cls in pairs(GetClassList('Color')) do
			sharedKeywordTable[key] = string.format("[colour='%s']", cls.ARGB);
			sharedKeywordTableNoColor[key] = '';
		end
		sharedKeywordTable['ColorEnd'] = '[colour-end]';
		sharedKeywordTableNoColor['ColorEnd'] = '';
	end
	local keywordTable = sharedKeywordTable;
	if removeColor then
		keywordTable = sharedKeywordTableNoColor;
	end
	local args = { ... };
	local prevMt = getmetatable(keywordTable);
	setmetatable(keywordTable, {__index = function(t, key)
		local customTable = customKeywordTable[customKey];
		if not customTable then
			return SafeIndex(obj, unpack(string.split(key, '%.')));
		end
		local keywordMapper = customTable[key];
		if keywordMapper == nil then
			return SafeIndex(obj, unpack(string.split(key, '%.')));
		else
			return keywordMapper(obj, unpack(args));
		end
	end});
	local retMsg = FormatMessage(msg, keywordTable);
	setmetatable(keywordTable, prevMt);
	return retMsg;
end
function CalculatedProperty_TextFormater_Common(obj, arg)
	local idspace = GetIdspace(obj);
	local desc = obj[arg .. '_Format'];
	return FormatMessageWithCustomKeywordTable(desc, obj, idspace, false);
end
function CalculatedProperty_TextFormater_BuffFormat(buff, arg)
	local result = '';
	
	-- 버프 타입
	if buff.Type == 'Buff' or buff.Type == 'Debuff' then
		local buffTypeList = GetClassList('BuffType');
		local buffSubTypeList = GetClassList('BuffSubType');
		local typeTextColor = '$'..buffTypeList[buff.Type].TypeColor..'$';
		local typeText = '';
		if buff.Type == 'Buff' then
			typeText = buffSubTypeList[buff.SubType].Title_Buff;
		elseif buff.Type == 'Debuff' then
			typeText = buffSubTypeList[buff.SubType].Title_Debuff;
		end
		if typeText ~= '' then
			result = typeTextColor..typeText;
		end
	end
	-- 기본 설명.
	if buff.Desc_Base ~= '' then
		if result == '' then
			result = '$Blue_ON$'..buff.Desc_Base;
		else
			result = result..'\n'..'$Blue_ON$'..buff.Desc_Base;
		end
	end
	-- 자동 설명
	if buff.IsAutoTooltip then
		local autoMessage = GetBuffSystemMessageText(buff);
		if autoMessage ~= '' then
			if result == '' then
				result = '$Blue_ON$'..autoMessage;
			else
				result = result..'\n$Blue_ON$'..autoMessage;
			end
		end
	end
	return result;
end
function CalculatedProperty_TextFormater_MasteryFormat(mastery, arg)
	return '$MasterySystemMessage$';
end
function CalculatedProperty_TextFormater_MasteryFormat2(mastery, arg)
	return '$MasterySPMessage$';
end
function CalculatedProperty_TextFormater_MasteryFormatBuff(mastery, arg)
	return '$MasteryBuffMessage$';
end
function CalculatedProperty_TextFormater_ItemFormat(item, arg)
	local result = '$ItemSystemMessage$';
	return result;
end
function CalculatedProperty_TextFormater_AbilityFormat(ability, arg)
	return '$AbilityDescMessage$';
end
function CalculatedProperty_TextFormater_DeragementProtocol(ability, arg)
	local appliedList = {};
	if ability.ModifyMasteryList ~= '' then
		appliedList = UnpackTableFromString(ability.ModifyMasteryList);
	end
	local ret = CalculatedProperty_TextFormater_AbilityFormat(ability, arg);
	
	local appliedMasteriesSet = Set.new(appliedList);
	if appliedMasteriesSet['DivideAndConquerAlgorithm'] then
		ret = FormatMessage(ability.Enhance_Desc, {EnhanceMastery = GetMasteryTitleText(GetClassList('Mastery').DivideAndConquerAlgorithm.Mastery)}) .. ret;
	end
	if appliedMasteriesSet['InformationControl'] then
		ret = FormatMessage(ability.Enhance_Desc, {EnhanceMastery = GetMasteryTitleText(GetClassList('Mastery').InformationControl.Mastery)}) .. ret;
	end
	return ret;
end
function CalculatedProperty_TextFormater_ProtocolAbility(ability, arg)
	local appliedList = {};
	if ability.ModifyMasteryList ~= '' then
		appliedList = UnpackTableFromString(ability.ModifyMasteryList);
	end
	local ret = CalculatedProperty_TextFormater_AbilityFormat(ability, arg);
	
	local appliedMasteriesSet = Set.new(appliedList);
	if appliedMasteriesSet['DivideAndConquerAlgorithm'] and GetWithoutError(ability, 'DACA_Desc') then
		ret = ability.DACA_Desc .. ' ' .. ret;
	end
	if appliedMasteriesSet['InformationControl'] and GetWithoutError(ability, 'InformationControl_Desc') then
		ret = ability.InformationControl_Desc .. ' ' .. ret;
	end
	return ret;
end
function CalculatedProperty_TextFormater_QuestFormat(mastery, arg)
	local result = '';
	if arg == 'Objective_Format' then
		result = '$QuestObjectiveSystemMessage$';
	elseif arg == 'Title_Format' then
		result = '$QuestTitleSystemMessage$';
	end
	return result;
end
function CalculatedProperty_TextFormater_OrganizationFormat(obj, arg)
	local result = '$OrganizationDescMessage$';
	return result;
end
function CalculatedProperty_TextFormater_MachineCategoryFormat(obj, arg)
	local result = '$StatusMessage$';
	return result;
end
function CalculatedProperty_TextFormater_PerformanceFormat(obj, arg)
	local result = '$PerformanceDescMessage$';
	return result;
end
function CalculatedProperty_TextFormater_PerformanceSubFormat(obj, arg)
	local result = obj.Desc_Base;
	if result ~= '' then
		result = '$Blue_ON$'..result;
	end	
	return result;
end
function CalculatedProperty_TextFormater_GameDifficulty(obj, arg)
	local idspace = GetIdspace(obj);
	local desc = ''
	if #obj.Desc_Base > 0 then
		desc = desc..GetMasteryMasteryDescBaseText(obj.Desc_Base, '$White$', '$White$');
	end
	return FormatMessageWithCustomKeywordTable(desc, obj, idspace, false);
end
function CalculatedProperty_TextFormater_ApplyAmount(obj, arg)
	local desc = ''
	local descBase = GetWithoutError(obj, 'Desc_Base');
	if descBase and #descBase > 0 then
		desc = desc..GetMasteryMasteryDescBaseText(descBase, '$White$', '$White$');
	end
	return FormatMessageWithCustomKeywordTable(desc, obj, 'ApplyAmount', false);
end
function GetMasteryAbility(mastery, abilityType)
	local result = nil;
	if mastery[abilityType] ~= 'None' then
		local abilityList = GetClassList('Ability');
		local curAbility = GetWithoutError(abilityList, mastery[abilityType]);
		if curAbility and curAbility ~= 'None' then
			result = curAbility;
		end
	end
	return result;
end
function GetMasteryModifyAbility(mastery)
	local result = nil;
	if mastery.ModifyAbility ~= 'None' and mastery.ModifyAbility ~= 'Custom' then
		local abilityList = GetClassList('Ability');
		local curAbility = GetWithoutError(abilityList, mastery.ModifyAbility);
		if curAbility and curAbility ~= 'None' then
			result = curAbility;
		end
	end
	return result;
end
function GetJumpingLandingOverhead(obj, diffHeight)
	-- 점프나 착지시에만 들어옵니다. 나머지는 내부로직에 의해서 직선거리값으로 계산됨
	-- 일반 한칸 이동을 1로 생각하고 점프와 착지에 대한 이동력 소모량을 계산해야함
	if not obj.Jumpable then -- 점프가 불가능한 캐릭터인가
		return 99999;
	end

	local movement_Overhead = 0;
	local penalty = 0;
	local masteryTable = GetMastery(obj);
	-- 도약이나 착지에 이동력 제한이 없는 캐릭인가
	local mastery_BoundingLeap = GetMasteryMastered(masteryTable, 'BoundingLeap');
	local mastery_Module_EnhancedHover = GetMasteryMastered(masteryTable, 'Module_EnhancedHover');
	local mastery_FastWingStroke = GetMasteryMastered(masteryTable, 'FastWingStroke');
	local mastery_StrongBackLeg = GetMasteryMastered(masteryTable, 'StrongBackLeg');
	local mastery_Sneakers_Extractor_Set = GetMasteryMastered(masteryTable, 'Sneakers_Extractor_Set');
	local freeJumper = IsLobbyServer() or mastery_BoundingLeap or mastery_Module_EnhancedHover or mastery_FastWingStroke or mastery_StrongBackLeg or mastery_Sneakers_Extractor_Set;
	if freeJumper then
		return movement_Overhead;
	end
	
	local isJump = diffHeight > 0;
	if isJump then
		if diffHeight < 0.75 then
		-- ~ 1.125m
			movement_Overhead = 0.5;
		elseif diffHeight < 1 then
		-- 1.125m ~ 1.5m
			movement_Overhead = 0.75;
		elseif diffHeight < 1.25 then
		-- 1.5m ~ 1.875m 
			movement_Overhead = 1;
		elseif diffHeight < 0.75 then
		-- 1.875m ~ 2.25m
			movement_Overhead = 1.25;
		else
		-- 2.25m ~
			movement_Overhead = 2;
		end
	else
		if diffHeight > -1 then
			-- 1.125m ~ 1.5m
			movement_Overhead = 0.25;
		elseif diffHeight > -1.5 then
			-- 1.875m ~ 2.25m
			movement_Overhead = 0.5;
		else
			movement_Overhead = 0.75;
		end
	end
	return math.max(0, movement_Overhead)
end
function CalculatedProperty_Object_EyeOffset(obj, arg)
	local result = 0;
	-- 1. 초기 값 가져오기 
	local result = obj['Base_'..arg];
	if not IsMission() then
		return result;
	end
	-- 2. 버프값 가져오기 / 전투 중 일때만
	local buffList = GetBuffList(obj);
	if buffList ~= nil then
		for i = 1, #buffList do
			local curBuff = buffList[i];
			local applyValue = GetWithoutError(curBuff, arg);
			if applyValue and applyValue ~= 'None' then
				result = result + applyValue;
			end
		end
	end

	local limitType = 'UInt';
	local limiter = limiterTable[limitType]
	if limiter == nil then
		LogAndPrint(string.format('Error in ValueLimiting, not handled LimitType [%s]', limitType))
		return nil;
	end	
	return limiter(result);
end
---------------------------------------------------------------------
-- 아이템 판매 가격
---------------------------------------------------------------------
function CalculatedProperty_ItemSellPrice(obj, arg)	
	return ItemCalculateSellPrice(obj, obj.Option);
end
---------------------------------------------------------------------
-- 아이템 판매 가격
---------------------------------------------------------------------
function ItemCalculateSellPrice(obj, option)	
	-- 1. 기본 판매 가격 가져오기
	-- 1-1. 기본 착용레벨에 따른 비용. 
	local baseSellPrice = 10 * math.max(1, math.floor(1 + obj.RequireLv/5)); 
	-- 1-2. 카테고리 비율. / 타입 비율. / 랭크 비율.
	baseSellPrice = baseSellPrice * obj.Category.ItemSellPriceRatio * obj.Type.ItemSellPriceRatio * obj.Rank.ItemSellPriceRatio;
		
	-- 2. 아이템 옵션 추가 가격 가져오기
	local result = baseSellPrice;
	if option then
		if option.OptionKey ~= 'None' then
			local itemIdentifyList = GetClassList('ItemIdentify');
			local curOption = itemIdentifyList[option.OptionKey];
			if curOption then
				for index, curOption in ipairs (curOption.IdentifyOptions) do
					local valueKey = 'Value'..index;
					local curOptionValue = tonumber(option[valueKey]);
					local maxOptionValue = curOption.Max;
					local addPrice = 0.35 * baseSellPrice * math.max(0.25, math.min(2, 2 * curOptionValue/maxOptionValue));
					result = result + addPrice;
				end
			else
				LogAndPrint('ItemCalculateSellPrice', 'OptionKey Error', option.OptionKey);
			end
		end
	end
	
	-- 3. 아이템 강화 추가 가격 가져오기.
	result = result + baseSellPrice * obj.Lv;

	-- 4. 조합 재료 보정
	if obj.Category.IsItemSellPriceByRecipe then
		local recipeCls = GetClassList('Recipe')[obj.name];
		if recipeCls then
			local itemClsList = GetClassList('Item');
			local recipePrice = 0;
			for _, rm in ipairs(recipeCls.RequireMaterials) do
				recipePrice = recipePrice + ((SafeIndex(itemClsList, rm.Item, 'SellPrice') or 0) * rm.Amount);
			end
			recipePrice = recipePrice * obj.Rank.MaxSellpriceRatio;	-- 재료비의 80%가 언더바운드
			if result < recipePrice then
				result = recipePrice;
			end
		end
	end	
	result = math.max(1, math.floor(result));	
	return result;
end
---------------------------------------------------------------------
-- 아이템 감정 비용.
---------------------------------------------------------------------
function CalculatedProperty_ItemIdentifyPrice(obj, arg)	
	local result = 0;
	-- 1. 기본 감정 비용 가격 가져오기
	local baseIdentifyPrice = 5;
	-- 2. 최소 요구 레벨에 따른 비용 증가.
	local requireLvPrice = math.floor(obj.RequireLv/5) * 5;
	-- 3. 아이템 랭크에 따른 비용 증가.
	local rankPrice = obj.Rank.IdentifyPrice;
	
	result = baseIdentifyPrice + requireLvPrice + rankPrice;
	result = math.floor(result);
	return result;
end
function CP_GetItemIdentifyType(obj, arg)
	if obj.Custom_IdentifyType ~= '' then
		return;
	end
	return obj.Type.name;
end
---------------------------------------------------------------------
-- 아이템 최대 스택.
---------------------------------------------------------------------
function CalculatedProperty_ItemMaxStack(obj, arg)	
	return obj.Type.MaxStack;
end
---------------------------------------------------------------------
-- 직업에 따라 장착 가능한 아이템 받아오는 함수
---------------------------------------------------------------------
function Get_EnableEquipItemFromeJob(self, arg)
	local list = {};
	if self.Job and self.Job.name ~= nil then
		list = self.Job[arg];
	end
	table.print(list)
	return list;
end
---------------------------------------------------------------------
-- 마스터리 포맷팅
---------------------------------------------------------------------
function GetFormatMessageText(obj, msg)
	if sharedKeywordTable == nil then
		sharedKeywordTable = {};
		for key, cls in pairs(GetClassList('Color')) do
			sharedKeywordTable[key] = string.format("[colour='%s']", cls.ARGB);
		end
		sharedKeywordTable['ColorEnd'] = '[colour-end]';
	end
	local prevMt = getmetatable(sharedKeywordTable);
	setmetatable(sharedKeywordTable, {__index = function(t, key)
		local customTable = customKeywordTable[GetIdspace(obj)];
		if not customTable then
			return obj[key];
		end
		local keywordMapper = customTable[key];
		if keywordMapper == nil then
			return obj[key];
		else
			return keywordMapper(obj);
		end
	end});
	local retMsg = FormatMessage(msg, sharedKeywordTable);
	setmetatable(sharedKeywordTable, prevMt);
	return retMsg;
end
---------------------------------------------------------------------
-- 추가 이동 거리 비율
---------------------------------------------------------------------
function CalculatedProperty_Object_SecondaryMoveRatio(obj, arg)	
	local moveRatio = obj.Base_SecondaryMoveRatio;
	
	-- 특성 치고 빠지기로 인한 추가 이동이 활성화될 때
	if obj.TurnState.UsedMainAbility and obj.TurnState.ExtraMovable then
		-- 특성 완벽주의자
		local masteryTable = GetMastery(obj);
		local mastery_Perfectionist = GetMasteryMastered(masteryTable, 'Perfectionist');
		if mastery_Perfectionist then
			moveRatio = moveRatio * (1 + mastery_Perfectionist.ApplyAmount2 / 100);
		end
	end	
	
	return moveRatio;
end
---------------------------------------------------------------------
-- Overwatch 어빌리티
---------------------------------------------------------------------
function CalculatedProperty_Object_OverwatchAbility(obj, arg)
	local activeAbilitySet = {};
	-- 오브젝트 어빌리티
	for _, ability in ipairs(obj.Ability) do
		if ability.Active then
			activeAbilitySet[ability.name] = true;
		end
	end
	-- 아이템 어빌리티
	local equipmentList = GetClassList('Equipment');
	local equipClsList = {};
	for key, value in pairs(equipmentList) do
		table.insert(equipClsList, value);
	end
	table.scoresort(equipClsList, function(equipCls) return equipCls.Order; end);
	for _, equipCls in ipairs(equipClsList) do
		local equipPos = equipCls.name;
		local inventorySlot = GetWithoutError(obj, equipPos);
		local abilityName = SafeIndex(inventorySlot, 'Ability', 'name');
		if abilityName ~= nil then
			activeAbilitySet[abilityName] = true;
		end
	end
	-- OverwatchAbilityList에서 활성화된 첫번째 선택
	for _, abilityName in ipairs(obj.OverwatchAbilityList) do
		if activeAbilitySet[abilityName] then
			return abilityName;
		end
	end
	return 'None';
end
---------------------------------------------------------------------
-- 공연 타입
---------------------------------------------------------------------
function CalculatedProperty_Object_PerformanceType(obj, arg)
	if not SafeIndex(obj, 'Job', 'name') then
		return 'None';
	end
	local ret = obj.Job.PerformanceType;
	if ret == 'None' then
		ret = obj.StartJob.PerformanceType;
	end
	return ret;
end
function CalculatedProperty_Object_PerformanceList(obj, arg)
	local ret = {};
	local masteryTable = GetMastery(obj);

	-- 직업 특성이 있는 경우
	-- 신기한 재주
	local mastery_ClownTalent = GetMasteryMastered(masteryTable, 'ClownTalent');
	-- 흥겨운 몸짓
	local mastery_DancerTalent = GetMasteryMastered(masteryTable, 'DancerTalent');
	if mastery_ClownTalent or mastery_DancerTalent then
		local performanceCls = GetClassList('Performance')[obj.PerformanceType];
		if performanceCls then
			for i, info in ipairs(performanceCls.Effect) do
				table.insert(ret, { Type = info.Type, StepIndex = i, StepCount = #performanceCls.Effect });
			end
			return ret;
		end
	end
	
	-- 직업 특성이 없지만, 속성 부여 특성이 있는 경우
	-- 경쾌한 안무
	local mastery_NimbleMovements = GetMasteryMastered(masteryTable, 'NimbleMovements');
	if mastery_NimbleMovements then
		table.insert(ret, { Type = 'Dance_Nimble', StepIndex = mastery_NimbleMovements.ApplyAmount4, StepCount = mastery_NimbleMovements.ApplyAmount3 });
	end
	-- 화려한 안무
	local mastery_FlashyHandMovements = GetMasteryMastered(masteryTable, 'FlashyHandMovements');
	if mastery_FlashyHandMovements then
		table.insert(ret, { Type = 'Dance_FlashyHand', StepIndex = mastery_FlashyHandMovements.ApplyAmount4, StepCount = mastery_FlashyHandMovements.ApplyAmount3 });
	end
	-- 정교한 안무
	local mastery_UnderstatedMovements = GetMasteryMastered(masteryTable, 'UnderstatedMovements');
	if mastery_UnderstatedMovements then
		table.insert(ret, { Type = 'Dance_Understated', StepIndex = mastery_UnderstatedMovements.ApplyAmount4, StepCount = mastery_UnderstatedMovements.ApplyAmount3 });
	end
	-- 격렬한 안무
	local mastery_PowerfulMovements = GetMasteryMastered(masteryTable, 'PowerfulMovements');
	if mastery_PowerfulMovements then
		table.insert(ret, { Type = 'Dance_Powerful', StepIndex = mastery_PowerfulMovements.ApplyAmount4, StepCount = mastery_PowerfulMovements.ApplyAmount3 });
	end
	return ret;
end
---------------------------------------------------------------------
-- 순찰 발각 회피
---------------------------------------------------------------------
function CalculatedProperty_Object_UsePatrolAvoidChecker(obj, arg)
	if obj.Cloaking then
		return true;
	end
	local masteryTable = GetMastery(obj);
	local mastery_Camouflage = GetMasteryMastered(masteryTable, 'Camouflage');
	if mastery_Camouflage then
		return true;
	end
	return false;
end
function CalculatedProperty_Object_PatrolAvoidChecker(obj, arg)
	return function(finder, testPos)
		-- 은신 상태에서는 항상 통과
		if obj.Cloaking then
			return true;
		end	
		local masteryTable = GetMastery(obj);
		local mastery_Camouflage = GetMasteryMastered(masteryTable, 'Camouflage');
		if mastery_Camouflage then
			-- 수풀
			local fieldEffects = {};
			if IsMissionServer() then
				fieldEffects = GetFieldEffectByPosition(GetMission(obj), testPos);
			else
				fieldEffects = GetFieldEffectByPosition(testPos);
			end
			local isBush = table.findif(fieldEffects, function(instance) return instance.Owner.name == 'Bush' end);
			if isBush then
				return true;
			end
			-- 완전 엄폐
			local coverState = GetCoverStateForCritical(obj, masteryTable, GetPosition(finder), finder);
			if coverState == 'Full' then
				return true;
			end
		end
		return false;
	end
end
---------------------------------------------------------------------
-- 모델 크기
---------------------------------------------------------------------
function CalculatedProperty_Object_SceneScale(obj, arg)
	local scale = obj.Base_SceneScale;
	if obj.Shape and obj.Shape.name then
		scale = scale * obj.Shape.Scale;
	end
	if HasBuff(obj, 'Giant') then
		scale = scale * 1.25;
	elseif HasBuff(obj, 'Giant_SideEffect') then
		scale = scale * 0.75;
	end
	
	return scale;
end
---------------------------------------------------------------------
-- ESP 능력치
---------------------------------------------------------------------
function MakeESPStatInfo(espName, value, state)
	return { Type = 'ESP', Value = value, ValueType = 'Formula', ESP = espName, State = state };
end