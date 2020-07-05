-----------------------------------------------------
-- 기계 제작
----------------------------------------------------
function GetMasteryForMachineByMachineCracft(machine)
	
	-- 기체에 따른 특성 리스트.
	local machineCraftUniqueMasteryList = GetClassList('MachineCraftUniqueMastery');
	
	local picker = RandomPicker.new();
	for key, masteryInfo in pairs(machineCraftUniqueMasteryList) do
		-- 최소 1값이 리턴된다.
		local probability = _G['GetProbability_MachineUniqueMastery_'..masteryInfo.Type](machine, machine.Object, masteryInfo);
		picker:addChoice(math.max(probability, 1), key);
	end
	local pickType = picker:pick();
	return pickType;
end
------------------------------------------------------
-- 개별 조건에 따른 확률 조정.  MachineStatusRanges
------------------------------------------------------
-- 일반 형.
----------------------------------------------------
-- 적재량
function GetProbability_MachineUniqueMastery_MaximumLoad(machine, machineObj, masteryInfo)
	local machineStatusRangesList = GetClassList('MachineStatusRanges');
	local rangeValue = machineStatusRangesList[masteryInfo.Type];
	local probability = masteryInfo.Probability;
	local loadRatio = machineObj.Load/machineObj.MaximumLoad;
	-- 적재량이 남아돌면 안 뜬다.
	if loadRatio < 0.75 then
		return 1;
	end
	if machineObj.Load > rangeValue.Max * 0.7 then
		probability = probability * 1.5;
	elseif machineObj.Load > rangeValue.Max * 0.8 then
		probability = probability * 2;
	elseif machineObj.Load > rangeValue.Max * 0.9 then
		probability = probability * 3;
	elseif machineObj.Load == rangeValue.Max then
		probability = probability * 4;
	end	
	return probability;
end
-- 최대 출력
function GetProbability_MachineUniqueMastery_MaxPower(machine, machineObj, masteryInfo)
	local machineStatusRangesList = GetClassList('MachineStatusRanges');
	local rangeValue = machineStatusRangesList[masteryInfo.Type];
	local probability = masteryInfo.Probability;
	if machineObj.MaxPower > rangeValue.Max * 0.8 then
		probability = probability * 1.5;
	elseif machineObj.MaxPower > rangeValue.Max * 0.9 then
		probability = probability * 2;
	elseif machineObj.MaxPower > rangeValue.Max * 0.95 then
		probability = probability * 3;
	elseif machineObj.MaxPower == rangeValue.Max then
		probability = probability * 4;
	else
		probability = 1;
	end	
	return probability;
end
-- 기체 출력
function GetProbability_MachineUniqueMastery_FrameModule(machine, machineObj, masteryInfo)
	return GetProbability_MachineUniqueMastery_Module(machine, machineObj, masteryInfo);
end
function GetProbability_MachineUniqueMastery_SupportModule(machine, machineObj, masteryInfo)
	return GetProbability_MachineUniqueMastery_Module(machine, machineObj, masteryInfo);
end
function GetProbability_MachineUniqueMastery_ComplementaryModule(machine, machineObj, masteryInfo)
	return GetProbability_MachineUniqueMastery_Module(machine, machineObj, masteryInfo);
end
function GetProbability_MachineUniqueMastery_SaftyModule(machine, machineObj, masteryInfo)
	return GetProbability_MachineUniqueMastery_Module(machine, machineObj, masteryInfo);
end
function GetProbability_MachineUniqueMastery_AIModule(machine, machineObj, masteryInfo)
	return GetProbability_MachineUniqueMastery_Module(machine, machineObj, masteryInfo);
end
-- 부분 출력 확률 구하는 함수.
function GetProbability_MachineUniqueMastery_Module(machine, machineObj, masteryInfo)
	local machineStatusRangesList = GetClassList('MachineStatusRanges');
	local rangeValue = machineStatusRangesList['MaxPower'];
	local probability = masteryInfo.Probability;

	-- 최대 출력이 40 이하면 안 붙는다.
	if machineObj.MaxPower < 0.8 * rangeValue.Max then
		return 1;
	end
	-- 다른 기체 출력 보다 슬롯수가 차이 많이 나야 한다.
	local subPowerTable = {
		{ Type = 'FrameModule', Count = machine.MaxBasicMasteryCount },
		{ Type = 'SupportModule', Count = machine.MaxSubMasteryCount },
		{ Type = 'ComplementaryModule', Count = machine.MaxAttackMasteryCount},
		{ Type = 'SaftyModule', Count = machine.MaxDefenceMasteryCount},
		{ Type = 'AIModule', Count = machine.MaxAbilityMasteryCount }
	};
	table.sort(subPowerTable, function (a, b)
		return a.Count > b.Count;
	end);
	
	if subPowerTable[1].Type == masteryInfo.Type then
		if subPowerTable[1].Count > subPowerTable[2].Count then
			probability = probability * 4;
		elseif subPowerTable[2].Count > subPowerTable[3].Count then
			probability = probability * 3;
		elseif subPowerTable[3].Count > subPowerTable[4].Count then
			probability = probability * 2;
		elseif subPowerTable[4].Count > subPowerTable[5].Count then
			probability = probability * 1.5;
		else
			probability = 1;
		end
	else
		probability = 1;
	end
	return probability;
end
-- 최대 체력
function GetProbability_MachineUniqueMastery_MaxHP(machine, machineObj, masteryInfo)
	return GetProbability_MachineUniqueMastery_LowStatus(machine, machineObj, masteryInfo);
end
function GetProbability_MachineUniqueMastery_CriticalStrikeDeal(machine, machineObj, masteryInfo)
	return GetProbability_MachineUniqueMastery_LowStatus(machine, machineObj, masteryInfo);
end
function GetProbability_MachineUniqueMastery_Armor(machine, machineObj, masteryInfo)
	return GetProbability_MachineUniqueMastery_LowStatus(machine, machineObj, masteryInfo);
end
function GetProbability_MachineUniqueMastery_Resistance(machine, machineObj, masteryInfo)
	return GetProbability_MachineUniqueMastery_LowStatus(machine, machineObj, masteryInfo);
end
function GetProbability_MachineUniqueMastery_Block(machine, machineObj, masteryInfo)
	return 0.5 * GetProbability_MachineUniqueMastery_LowStatus(machine, machineObj, masteryInfo);
end
function GetProbability_MachineUniqueMastery_Dodge(machine, machineObj, masteryInfo)
	return 0.5 * GetProbability_MachineUniqueMastery_LowStatus(machine, machineObj, masteryInfo);
end
-- Status 가 작으면 붙여주기.
function GetProbability_MachineUniqueMastery_LowStatus(machine, machineObj, masteryInfo)
	local machineStatusRangesList = GetClassList('MachineStatusRanges');
	local rangeValue = machineStatusRangesList[masteryInfo.Type];
	local probability = masteryInfo.Probability;
	-- 오히려 체력이 작으면 붙여주자.
	if machineObj.MaxHP < rangeValue.Max * 0.3 then
		probability = probability * 1.5;
	elseif machineObj.MaxHP < rangeValue.Max * 0.2 then
		probability = probability * 2;
	elseif machineObj.MaxHP < rangeValue.Max * 0.15 then
		probability = probability * 3;
	elseif machineObj.MaxHP < rangeValue.Max * 0.1 then
		probability = probability * 4;
	else
		probability = 1;
	end	
	return probability;
end
-- 최대 시야
function GetProbability_MachineUniqueMastery_SightRange(machine, machineObj, masteryInfo)
	local machineStatusRangesList = GetClassList('MachineStatusRanges');
	local rangeValue = machineStatusRangesList[masteryInfo.Type];
	local probability = masteryInfo.Probability;
	-- 시야 너무 크면 안 붙임
	if machineObj.SightRange > rangeValue.Max * 0.7 then
		return 1;
	end
	if machineObj.SightRange > rangeValue.Max * 0.6 then
		probability = probability * 1.5;
	elseif machineObj.SightRange < rangeValue.Max * 0.5 then
		probability = probability * 2;
	end	
	return probability;
end
-- 이동 거리
function GetProbability_MachineUniqueMastery_MoveDist(machine, machineObj, masteryInfo)
	local machineStatusRangesList = GetClassList('MachineStatusRanges');
	local rangeValue = machineStatusRangesList[masteryInfo.Type];
	local probability = masteryInfo.Probability;
	-- 이동 거리 너무 크면 안 붙임
	if machineObj.SightRange > rangeValue.Max * 0.8 then
		return 1;
	end
	if machineObj.SightRange > rangeValue.Max * 0.7 then
		probability = probability * 1.5;
	elseif machineObj.SightRange < rangeValue.Max * 0.6 then
		probability = probability * 2;
	end	
	return probability;
end
-- 턴 속도
function GetProbability_MachineUniqueMastery_Speed(machine, machineObj, masteryInfo)
	local machineStatusRangesList = GetClassList('MachineStatusRanges');
	local rangeValue = machineStatusRangesList[masteryInfo.Type];
	local probability = masteryInfo.Probability;
	-- 턴 속도 너무 크면 안 붙임
	if machineObj.Speed > rangeValue.Max * 0.9 then
		return 1;
	end
	if machineObj.Speed > rangeValue.Max * 0.8 then
		probability = probability * 4;
	elseif machineObj.Speed < rangeValue.Max * 0.7 then
		probability = probability * 3;
	elseif machineObj.Speed < rangeValue.Max * 0.6 then
		probability = probability * 2;
	elseif machineObj.Speed < rangeValue.Max * 0.5 then
		probability = probability * 1.5;
	end	
	return probability;
end
-- 공격력
function GetProbability_MachineUniqueMastery_AttackPower(machine, machineObj, masteryInfo)
	return GetProbability_MachineUniqueMastery_BattleStatus(machine, machineObj, masteryInfo);
end
-- 초능력
function GetProbability_MachineUniqueMastery_ESPPower(machine, machineObj, masteryInfo)
	return GetProbability_MachineUniqueMastery_BattleStatus(machine, machineObj, masteryInfo);
end
-- 명중률
function GetProbability_MachineUniqueMastery_Accuracy(machine, machineObj, masteryInfo)
	return GetProbability_MachineUniqueMastery_BattleStatus(machine, machineObj, masteryInfo);
end
-- 치명타 적중률
function GetProbability_MachineUniqueMastery_CriticalStrikeChance(machine, machineObj, masteryInfo)
	return GetProbability_MachineUniqueMastery_BattleStatus(machine, machineObj, masteryInfo);
end
-- 일반 Status 용.
function GetProbability_MachineUniqueMastery_BattleStatus(machine, machineObj, masteryInfo)
	local machineStatusRangesList = GetClassList('MachineStatusRanges');
	local rangeValue = machineStatusRangesList[masteryInfo.Type];
	local probability = masteryInfo.Probability;
	-- 수치 너무 작으면 안 붙임
	if machineObj.AttackPower < rangeValue.Max * 0.5 then
		return 1;
	end
	if machineObj.Speed > rangeValue.Max * 0.9 then
		probability = probability * 4;
	elseif machineObj.Speed < rangeValue.Max * 0.8 then
		probability = probability * 3;
	elseif machineObj.Speed < rangeValue.Max * 0.7 then
		probability = probability * 2;
	elseif machineObj.Speed < rangeValue.Max * 0.6 then
		probability = probability * 1.5;
	end	
	return probability;
end
function GetProbability_MachineUniqueMastery_Overcharge(machine, machineObj, masteryInfo)
	return masteryInfo.Probability;
end
function GetProbability_MachineUniqueMastery_LowEnergy(machine, machineObj, masteryInfo)
	return masteryInfo.Probability;
end
function GetProbability_MachineUniqueMastery_DealyCast(machine, machineObj, masteryInfo)
	return masteryInfo.Probability;
end
function GetProbability_MachineUniqueMastery_StablePosture(machine, machineObj, masteryInfo)
	return masteryInfo.Probability;
end
function GetProbability_MachineUniqueMastery_HighPosition(machine, machineObj, masteryInfo)
	return masteryInfo.Probability;
end
function GetProbability_MachineUniqueMastery_Waiting(machine, machineObj, masteryInfo)
	return masteryInfo.Probability;
end