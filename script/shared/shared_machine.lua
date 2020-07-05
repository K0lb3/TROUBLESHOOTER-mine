------------------------------------------------------------------------
-- 기계 관련 함수 
------------------------------------------------------------------------
function Get_OverChargeCP_Machine(pc)
	return pc.MaxCP;
end
function Get_RestoreCPPerMin_Machine(pc)
	return 0;
end
function CalcRestoreCP_Machine(pc, sec)
	return math.min(pc.CP, pc.OverChargeCP);	
end
function GetEstimatedCP_Machine(pc)
	return pc.CP;
end
function Get_CPRestoreRamainTime_Machine(pc)
	return 0;
end
function GetPcStateFromConditionValue_Machine(currentCP, maxCP)
	return GetPcStateFromConditionValueByType('Duration', currentCP, maxCP);
end
---------------------------------------------------------
-- 기계 소환 가능
---------------------------------------------------------
function IsEnableSummonMachine(machine, obj, machineType)
	local mission = GetMission_Shared(obj);
	local missionWeather = mission.Weather.name;
	local missionTemperature = mission.Temperature.name;
	local missionTime = mission.MissionTime.name;
	local masteryTable = GetMastery(obj);
	
	local reason = {};
	local isEnable = true;
	
	if obj and IsDead(obj) then
		isEnable = false;
		table.insert(reason, { Type = 'Dead' });
	end
	
	if obj then
		local pcStateKey = GetPcStateFromConditionValue_Machine(obj.CP, obj.MaxCP);
		if pcStateKey == 'MachineDisable' then
			isEnable = false;
			table.insert(reason, { Type = 'Disable' });
		end
		
			
		if not IsInvalidPosition(GetPosition(obj)) then
			isEnable = false;
			table.insert(reason, { Type = 'AlreadySummoned' });
		end
		
		if obj.Load > obj.MaximumLoad then
			isEnable = false;
			table.insert(reason, { Type = 'MachineOverloaded' });
		end
		
		local bm = MasteryBoardManager.newWithObject(machine, obj, GetMastery(obj));
		if not bm:isValid() then
			isEnable = false;
			table.insert(reason, { Type = 'MachineLackOfPower' });
		end
	end

	
	return isEnable, reason;
end
---------------------------------------------------------
-- 기계 오브젝트 키
---------------------------------------------------------
function GetMachineObjKey(team, pcInfo)
	return string.format('%s_%s', team, pcInfo.RosterKey);
end
---------------------------------------------------------
-- 기계 소환 목록
---------------------------------------------------------
function GetSummonMachineList(user)
	local machineList = {};
	if IsMissionServer() then
		local company = GetCompany(user);
		if company then
			local lineup = GetLineupMembers(company) or {};
			local pcList = table.filter(lineup, function(pc)
				return pc.RosterType == 'Machine';
			end);
			table.append(machineList, table.map(pcList, function(pc)
				return { Pc = pc, MachineType = pc.MachineType, Object = pc.Object };
			end));
		end
	else
		local session = GetSession();
		local rosters = session.rosters;
		local pcList = table.filter(rosters, function(pc)
			return pc.RosterType == 'Machine';
		end);
		table.append(machineList, table.map(pcList, function(pc)
			local objKey = GetMachineObjKey(GetPlayerTeamName(), pc);
			return { Pc = pc, MachineType = pc.MachineType, Object = GetUnit(objKey, true) };
		end));
	end
	local tamingList = GetInstantProperty(user, 'TamingList') or {};
	table.append(machineList, table.map(tamingList, function(objKey)
		local obj = nil;
		if IsMissionServer() then
			obj = GetUnit(GetMission(user), objKey, true);
		else
			obj = GetUnit(objKey, true);
		end
		local machineCls = nil;
		local machineType = GetInstantProperty(obj, 'MachineType');
		if machineType then
			machineCls = GetClassList('MachineType')[machineType];
		end
		return { Pc = nil, MachineType = machineCls, Object = obj };
	end));
	return machineList;
end
---------------------------------------------------------
-- 기계 특성 슬롯 개수
---------------------------------------------------------
function CalculatedProperty_Machine_BaseMaxMasteryCount(self, arg)
	local startPos, endPos = string.find(arg, 'Base_');
	if startPos == nil then
		return 0;
	end
	local propName = string.sub(arg, endPos+1);
	local frameType = self.Object.Frame;
	if frameType and frameType.name then
		return frameType[propName];
	else
		return self.MachineType.Category[propName];
	end
end
---------------------------------------------------------
-- 기계 모델 크기
---------------------------------------------------------
function CalculatedProperty_Machine_SceneScale(self)
	if IsLobby() then
		return self.MachineType.LobbyScale;
	elseif IsMission() then
		return self.MachineType.MissionScale;
	else
		return 1;
	end
end
---------------------------------------------------------
-- 기계 방출 가능한지
---------------------------------------------------------
function IsEnableRemoveMachine(pcInfo)
	return pcInfo.RosterType == 'Machine' and not pcInfo.Locked;
end
---------------------------------------------------------
-- 기계 수리 가능한지
---------------------------------------------------------
function IsEnableRepairMachine(company, pcInfo, checkPrice)
	local reason = {};
	local isEnable = true;
	
	if pcInfo.RosterType ~= 'Machine' then
		table.insert(reason, 'NotMachine');
		return false, reason;
	end
	if pcInfo.CP >= pcInfo.MaxCP then
		table.insert(reason, 'FullCP');
		return false, reason; 
	end
	local repairPrice = GetMachineRepairPrice(pcInfo);
	if checkPrice then
		if repairPrice > company.Vill then
			isEnable = false;
			table.insert(reason, 'NotEnoughVill');
		end
	end
	return isEnable, reason, repairPrice;	
end
function GetMachineRepairPrice(pcInfo)
	local totalPrice = 0;
	local equipmentList = GetClassList('Equipment');
	for equipPos, _ in pairs(equipmentList) do
		local equipItem = pcInfo.Object[equipPos];
		if equipItem and equipItem.name then
			totalPrice = totalPrice + equipItem.SellPrice;		
		end
	end
	return math.floor(totalPrice * 0.4 * (120 - pcInfo.CP) / 100);	
end
---------------------------------------------------------
-- 기계 제작 가능한지
---------------------------------------------------------
function IsEnableCraftMachine(company, machineType, osType, equipItems, itemCountAcquirer)
	local reason = {};
	local isEnable = true;	
	
	-- 언락 처리.
	if not StringToBool(company.WorkshopMenu.Machine.Opened, false) then
		table.insert(reason, 'NotEnableUseCraft');
		return false, reason;
	end
	
	local machineCount = 0;
	if IsLobbyServer() then
		local machineList = GetAllRoster(company, 'Machine');
		machineCount = #machineList;
	elseif IsClient() then
		local session = GetSession();
		local machineList = table.filter(session.rosters, function(pcInfo) return pcInfo.RosterType == 'Machine'; end);
		machineCount = #machineList;
	end
	if machineCount >= company.MaxMachineCountTotal then
		table.insert(reason, 'MaxMachineCount');
		return false, reason;
	end
	
	-- 유효 데이터 처리
	-- 1. 머신 타입 존재 여부.
	local curMachineType = GetClassList('MachineType')[machineType];
	if not curMachineType then
		table.insert(reason, 'NotExistMachineType');
		return false, reason;
	end
	
	-- 2. 아이템 존재 여부
	local itemList = GetClassList('Item');
	local itemSlotChecker = function(slotName)
		local itemInfo = equipItems[slotName];
		if itemInfo == nil then
			return 'EmptyEquipItem';
		end
		local itemName = itemInfo.Item;
		local curItem = itemList[itemName];
		if curItem == nil then
			return 'InvalidItem';
		end
		local isValidEquip = table.exist(curItem.Type.EquipmentPosition, function(equipPos)
			return equipPos == slotName;
		end);
		if not isValidEquip then
			return 'InvalidEquipPos';
		end
		-- 인벤토리에 아이템이 있는지
		local curItemCount = itemCountAcquirer(itemName);
		if curItemCount < 1 then
			return 'NotEnoughEquipItem';
		end
	end
	local testSlots = { 'Weapon', 'Body', 'Hand', 'Leg', 'Inventory1', 'Inventory2' };
	for _, slotName in ipairs(testSlots) do
		local checked = itemSlotChecker(slotName);
		if checked ~= nil then
			isEnable = false;
			table.insert(reason, checked);
			break;
		end
	end
	
	-- 3. 아이템 중량 체크
	local maximumLoad = curMachineType.Monster.Object.MaximumLoad;
	local osMastery = GetClassList('Mastery')[osType];
	if osMastery then
		maximumLoad = maximumLoad + osMastery.MaximumLoad;
	end
	local totalLoad = 0;
	for _, slotName in ipairs(testSlots) do
		local itemInfo = equipItems[slotName];
		if itemInfo then
			local itemName = equipItems[slotName].Item;
			local curItem = itemList[itemName];
			if curItem then
				totalLoad = totalLoad + curItem.Load;
			end
		end
	end
	if totalLoad > maximumLoad then
		isEnable = false;
		table.insert(reason, 'NotEnoughItemLoad');
	end
		
	return isEnable, reason;
end
-----------------------------------------------
-- 기체 장비 슬롯
---------------------------------------------------------
function GetMachineEquipSlots(basicOnly)
	local basicSlots = { 'Weapon', 'Body', 'Hand', 'Leg', 'Inventory1', 'Inventory2' };
	local extraSlots = { 'Module_AuxiliaryWeapon', 'Module_AssistEquipment' };
	
	local ret = {};
	table.append(ret, basicSlots);
	if basicOnly then
		return ret;
	end	
	table.append(ret, extraSlots);
	return ret;
end
-----------------------------------------------
-- 기체 변경 가능한지
---------------------------------------------------------
function IsEnableChangeMachine(company, roster, osType, equipItems, itemCountAcquirer)
	local reason = {};
	local isEnable = true;
	local needUnequip = {};
	local needEquip = {};
	local itemList = GetClassList('Item');
	local needStatement = 0;

	local basicSlots = GetMachineEquipSlots(true);
	local fullSlots = GetMachineEquipSlots(false);
	
	-- 1. 기본 슬롯 아이템 체크
	for _, equipSlot in ipairs(basicSlots) do
		local itemName = equipItems[equipSlot];
		if itemName == nil then
			isEnable = false;
			table.insert(reason, 'EmptyEquipItem');
			return isEnable, reason, needUnequip, needEquip, needStatement;
		end
	end
	
	local target = roster.Object;
	for _, equipSlot in ipairs(fullSlots) do
		local prevItem = GetWithoutError(target, equipSlot);
		local prevItemName = SafeIndex(prevItem, 'name');
		local newItemName = equipItems[equipSlot];

		-- 기존 장비랑 다를 때만 장비 해제 or 장비 처리
		if (prevItemName or newItemName) and prevItemName ~= newItemName then
			if prevItemName then
				needUnequip[equipSlot] = prevItemName;
			end
			if newItemName then
				needEquip[equipSlot] = newItemName;
			end
		end
	end
	
	-- 2. 새로 장착할 아이템 존재 여부
	local itemSlotChecker = function(slotName, itemName)
		local curItem = itemList[itemName];
		if curItem == nil then
			return 'InvalidItem';
		end
		local isValidEquip = table.exist(curItem.Type.EquipmentPosition, function(equipPos)
			return equipPos == slotName;
		end);
		if not isValidEquip then
			return 'InvalidEquipPos';
		end
		-- 인벤토리에 아이템이 있는지
		local curItemCount = itemCountAcquirer(itemName);
		if curItemCount < 1 then
			return 'NotEnoughEquipItem';
		end
	end
	for equipSlot, itemName in pairs(needEquip) do
		local checked = itemSlotChecker(equipSlot, itemName);
		if checked ~= nil then
			isEnable = false;
			table.insert(reason, checked);
			return isEnable, reason, needUnequip, needEquip, needStatement;
		end
	end
	
	-- 3. 아이템 중량, 출력 체크
	local maximumLoad = target.MaximumLoad;
	local maxPower = roster.MaxTP;
	if roster.OSType ~= osType then
		local prevMastery = GetClassList('Mastery')[roster.OSType];
		if prevMastery then
			maximumLoad = maximumLoad - prevMastery.MaximumLoad;
			maxPower = maxPower - prevMastery.MaxPower;
		end
		local newMastery = GetClassList('Mastery')[osType];
		if newMastery then
			maximumLoad = maximumLoad + newMastery.MaximumLoad;
			maxPower = maxPower + newMastery.MaxPower;
		end
		
		needStatement = (roster.AIUpgradeStage - 1) * 10;
		if itemCountAcquirer('Statement_Module') < needStatement then
			isEnable = false;
			table.insert(reason, 'NotEnoughStatementModule');
			return isEnable, reason, needUnequip, needEquip, needStatement;
		end
	end
	
	local totalLoad = target.Load;
	local curTP = roster.MaxTP - roster.TP;
	for _, itemName in pairs(needUnequip) do
		local curItem = itemList[itemName];
		if curItem then
			totalLoad = totalLoad - curItem.Load;
			maximumLoad = maximumLoad - curItem.MaximumLoad;
			maxPower = maxPower - curItem.MaxPower;
		end
	end
	for _, itemName in pairs(needEquip) do
		local curItem = itemList[itemName];
		if curItem then
			totalLoad = totalLoad + curItem.Load;
			maximumLoad = maximumLoad + curItem.MaximumLoad;
			maxPower = maxPower + curItem.MaxPower;
		end
	end
	
	if totalLoad > maximumLoad then
		isEnable = false;
		table.insert(reason, 'NotEnoughItemLoad');
	end
	if curTP > maxPower then
		isEnable = false;
		table.insert(reason, 'NotEnoughItemPower');
	end
	
	return isEnable, reason, needUnequip, needEquip, needStatement;
end
---------------------------------------------------------
-- 기계 AI 강화 가능한지
---------------------------------------------------------
function IsEnableAnyAIUpgrade(pcInfo)
	if pcInfo.RosterType ~= 'Machine' then
		return false, nil, nil;
	end
	local isEnable = false;
	local minLv = SafeIndex(GetClassList('ExpLimit'), pcInfo.JobExpType, 'Limit') or 99999;
	local evolutionCount = 0;
	if pcInfo.AIUpgradeStage < pcInfo.AIUpgradeMaxStage then
		if pcInfo.JobLv >= minLv then
			isEnable = true;
		end
		evolutionCount = 1;
	end
	return isEnable, minLv, evolutionCount;
end
--------------------------------------------------
-- AI 강화 가능한가.
--------------------------------------------------
function IsSatisfiedMachineAIUpgrade(pcInfo, upgradeTypeName)
	local isEnable = true;
	local reason = {};
	
	local machineType = pcInfo.MachineType;
	local upgradeInfo = GetWithoutError(SafeIndex(machineType, 'AIUpgradeType'), upgradeTypeName);
	local requireLv = GetWithoutError(upgradeInfo, 'RequireLv');
	local requireJobLv = GetWithoutError(upgradeInfo, 'RequireJobLv');
	
	-- 0. 데이터 유효성 검사.
	if not upgradeInfo then
		table.insert(reason, 'NotExistEnableAIUpgrade');
		return isEnable, reason;
	end
	
	-- 1. PC 레벨	
	if requireLv and requireLv > pcInfo.Lv then
		isEnable = false;
		table.insert(reason, 'NotEnoughPcLevel');
	end
	-- 2. 클래스 레벨	
	if requireJobLv and requireJobLv > pcInfo.JobLv then
		isEnable = false;
		table.insert(reason, 'NotEnoughJobLevel');
	end
	
	return isEnable, reason;
end
function IsEnableMachineAIUpgrade(company, pcInfo, upgradeTypeName, itemCounter)
	local isEnable = false;
	local needItem = nil;
	local needCount = nil;
	local reason = {};
	-- 1. 강화 가능한 AI 단계가 Open 되었는가.
	if IsSatisfiedMachineAIUpgrade(pcInfo, upgradeTypeName) then
		isEnable = true;
	else
		table.insert(reason, 'MachineAIUpgrade_IsNotOpened');
	end
	-- 2. 진화에 필요한 아이템이 존재하는가.
	local machineType = pcInfo.MachineType;
	local upgradeInfo = GetWithoutError(SafeIndex(machineType, 'AIUpgradeType'), upgradeTypeName);
	if upgradeInfo then
		needItem = GetWithoutError(upgradeInfo, 'RequireItem');
		needCount = GetWithoutError(upgradeInfo, 'RequireItemCount');
		if needItem and needItem ~= 'None' and needCount and needCount > 0 then
			local extractItemCount = itemCounter(needItem);
			if extractItemCount < needCount then
				isEnable = false;
				table.insert(reason, 'NotEnoughExtractItem');	
			end
		else
			needItem = nil;
			needCount = nil;
		end
	end
	
	return isEnable, needItem, needCount, reason;
end
---------------------------------------------------------
-- AI 강화 특성 후보
---------------------------------------------------------
function GetMachineAIUpgradeMasteryCandidate(roster, upgradeType)
	local upgradeMastery = GetClassList('MachineAIUpgrade')[roster.OSType];
	if not upgradeMastery or not upgradeMastery.name then
		return {};
	end

	local masteryTable = GetMastery(roster);
	local filter = table.filter(upgradeMastery.AIUpgrade, function(cls)
		return cls.Lv < upgradeType and not GetMasteryMastered(masteryTable, cls.Type);
	end);
	return table.map(filter, function(cls) return cls.Type end);
end
--------------------------------------------------------
-- AI 강화 특성 재선택이 필요한지
--------------------------------------------------------
function IsNeedSelectAIUpgradeMastery(pcInfo)
	if pcInfo.RosterType ~= 'Machine' then
		return false;
	end
	local upgradeStage = pcInfo.AIUpgradeStage;
	if upgradeStage <= 1 then
		return false;
	end
	-- 중간에 빈 단계가 하나라도 있으면 허용
	for i = 2, upgradeStage do
		local propName = string.format('AIUpgradeMastery%d', i-1);
		local upgradeMastery = GetWithoutError(pcInfo, propName);
		if upgradeMastery and upgradeMastery == 'None' then
			return true, i;
		end
	end
	return false;
end
---------------------------------------------------------
-- 변경 가능한 AI 강화 특성 목록
---------------------------------------------------------
function GetEnableChangeAIUpgradeMasteryList(pcInfo)
	local list = {};
	if pcInfo.RosterType ~= 'Machine' then
		return list;
	end
	local upgradeMastery = GetClassList('MachineAIUpgrade')[pcInfo.OSType];
	if not upgradeMastery or not upgradeMastery.name then
		return list;
	end
	
	local usingSet = {};
	for i = 1, 3 do
		local upgradeMastery = GetWithoutError(pcInfo, string.format('AIUpgradeMastery%d', i));
		if upgradeMastery and upgradeMastery ~= 'None' then
			usingSet[upgradeMastery] = true;
		end
	end
	local filter = table.filter(upgradeMastery.AIUpgrade, function(cls)
		return cls.Lv < pcInfo.AIUpgradeStage and not usingSet[cls.Type];
	end);
	local masteryList = GetClassList('Mastery');
	list = table.map(filter, function(cls) return masteryList[cls.Type] end);
	return list;
end
function IsEnableChangeCharacterMastery_Machine(pcInfo, characterMasteryName, itemCountAcquirer)
	local reason = {};
	local isEnable = true;
	local trainingManualCount = itemCountAcquirer('Statement_Module');
	local characterMasteries = pcInfo.CharacterMasteries;
	local curCharacterMastery = characterMasteries[characterMasteryName];
	-- 0 .데이터 에러.
	if not curCharacterMastery then
		LogAndPrint('DataError - NotExist CompanyMasteries - companyMasteryName', characterMasteryName);
		table.insert(reason, 'DataError');
		isEnable = false;
		return isEnable, reason;
	end
	-- 1. 습득 가능한 개인 특성인가.
	-- 2. 스타팅 여부 체크.
	local enableList = GetEnableChangeAIUpgradeMasteryList(pcInfo);
	local isStartingMastery = false;
	for i = 1, #enableList do
		local curStartingMasteryName = enableList[i].name;
		if curStartingMasteryName == characterMasteryName then
			isStartingMastery = true;
			break;
		end
	end
	if not isStartingMastery and not mastery.Opened then
		table.insert(reason, 'notOpened');
		isEnable = false;
	end
	-- 3. 회사에 훈련서가 충분히 있는가?
	if trainingManualCount < curCharacterMastery.TrainingManual then
		table.insert(reason, 'NotEnoughTrainingManual');
		isEnable = false;
	end	
	return isEnable, curCharacterMastery.TrainingManual, reason;
end