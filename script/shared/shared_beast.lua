------------------------------------------------------------------------
-- 야수 관련 함수 
------------------------------------------------------------------------
function Get_OverChargeCP_Beast(pc)
	return pc.MaxCP;
end
function Get_RestoreCPPerMin_Beast(pc)
	return 0;
end
function CalcRestoreCP_Beast(pc, sec)
	return math.min(pc.CP, pc.OverChargeCP);	
end
function GetEstimatedCP_Beast(pc)
	return pc.CP;
end
function Get_CPRestoreRamainTime_Beast(pc)
	return 0;
end
function GetPcStateFromConditionValue_Beast(currentCP, maxCP)
	return GetPcStateFromConditionValueByType('Loyalty', currentCP, maxCP);
end
---------------------------------------------------------
-- 야수 소환 가능
---------------------------------------------------------
function IsEnableSummonBeast(obj, beastType, owner, beast)
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
	
	if obj and GetInstantProperty(obj, 'BeastRoyaltyEscaped') then
		isEnable = false;
		table.insert(reason, { Type = 'Escaped' });
	end
	
	for _, disableWeather in ipairs(beastType.DisableSummonMissionWeather) do
		if disableWeather.name == missionWeather and not IsEnableSummonOnDisableWeather(missionWeather, masteryTable) then
			isEnable = false;
			table.insert(reason, { Type = 'DisableWeather', Value = missionWeather });
			break;
		end
	end
	for _, disableTemperature in ipairs(beastType.DisableSummonMissionTemperature) do
		if disableTemperature.name == missionTemperature and not IsEnableSummonOnDisableTemperature(missionTemperature, masteryTable) then
			isEnable = false;
			table.insert(reason, { Type = 'DisableTemperature', Value = missionTemperature });
			break;
		end
	end	
	for _, disableTime in ipairs(beastType.DisableSummonMissionTime) do
		if disableTime.name == missionTime and not IsEnableSummonOnDisableTime(missionTime, masteryTable) then
			isEnable = false;
			table.insert(reason, { Type = 'DisableTime', Value = missionTime });
			break;
		end
	end
	
	if not GetMasteryMastered(GetMastery(owner), 'MonsterTame') and SafeIndex(beast, 'LegendaryTamed') then
		isEnable = false;
		table.insert(reason, { Type = 'DisableRank', Value = beast.Object.Grade.name });
	end
	
	return isEnable, reason;
end
function IsEnableSummonOnDisableWeather(missionWeather, masteryTable)
	-- 혹한의 야수(눈)
	local mastery_ColdBeast = GetMasteryMastered(masteryTable, 'ColdBeast');
	if mastery_ColdBeast then
		if missionWeather == 'Snow' then
			return true;
		end
	end
	-- 빗속의 야수(비)
	local mastery_RainBeast = GetMasteryMastered(masteryTable, 'RainBeast');
	if mastery_RainBeast then
		if missionWeather == 'Rain' then
			return true;
		end
	end
	return false;
end
function IsEnableSummonOnDisableTemperature(missionTemperature, masteryTable)
	-- 혹한의 야수(추움, 한파)
	local mastery_ColdBeast = GetMasteryMastered(masteryTable, 'ColdBeast');
	if mastery_ColdBeast then
		if missionTemperature == 'Cold' or missionTemperature == 'Freezing' then
			return true;
		end
	end
	-- 폭염의 야수(더움, 폭염)
	local mastery_HotBeast = GetMasteryMastered(masteryTable, 'HotBeast');
	if mastery_HotBeast then
		if missionTemperature == 'Hot' or missionTemperature == 'ExtremelyHot' then
			return true;
		end
	end
	return false;
end
function IsEnableSummonOnDisableTime(missionTime, masteryTable)
	-- 달빛의 야수(저녁, 밤, 어두운 실내)
	local mastery_MoonBeast = GetMasteryMastered(masteryTable, 'MoonBeast');
	if mastery_MoonBeastt then
		if IsDarkTime(missionTime) then
			return true;
		end
	end
	return false;
end
---------------------------------------------------------
-- 야수 길들이기 시간
---------------------------------------------------------
function GetTamingTimeCalculator(self, target, ability, abilityDetailInfo)
	local info = {};
	local totalTamingTime = 0;

	local addTimeByHP = math.floor(target.HP * 0.1);
	totalTamingTime = totalTamingTime + addTimeByHP;
	table.insert(info, { Type = 'DefenderHPFix', Value = addTimeByHP, ValueType = 'Formula' });
	
	-- 레벨차이에 의한 시간 보정
	local addTimeByLevelDiff = (target.Lv - self.Lv) * 2;
	totalTamingTime = totalTamingTime + addTimeByLevelDiff;
	table.insert(info, {Type = 'LevelDiff', Value = addTimeByLevelDiff, ValueType = 'Formula'});
	
	-- 충성도에 따른 시간 보정
	local pcStateList = GetClassList('PcState');
	for _, pcState in pairs(pcStateList) do
		if pcState.Buff ~= 'None' and HasBuff(target, pcState.Buff) and pcState.TameDurationRatio > 1 then
			local tameDurationRatio = pcState.TameDurationRatio;
			local addTimeByPcState = totalTamingTime * (tameDurationRatio - 1);
			totalTamingTime = totalTamingTime + addTimeByPcState;
			table.insert(info, {Type = pcState.Buff, Value = addTimeByPcState, ValueType = 'Buff'});
			break;
		end
	end
	
	-- info 정보 넣기.
	table.sort(info, function (a, b)
		return a.Value > b.Value;
	end);
	local infoValue = 0;
	for index, value in ipairs (info) do
		infoValue = infoValue + value.Value;
	end
	local basicValue = totalTamingTime - infoValue;
	if basicValue ~= 0 then
		table.insert(info, 1, { Type = 'TamingTime', Value = basicValue, ValueType = 'Formula' });
	end
	return math.max(totalTamingTime, 0), info;
end
---------------------------------------------------------
-- 야수 오브젝트 키
---------------------------------------------------------
function GetBeastObjKey(team, pcInfo)
	return string.format('%s_%s', team, pcInfo.RosterKey);
end
---------------------------------------------------------
-- 야수 소환 목록
---------------------------------------------------------
function GetSummonBeastList(user)
	local beastList = {};
	if IsMissionServer() then
		local company = GetCompany(user);
		if company then
			local lineup = GetLineupMembers(company) or {};
			local pcList = table.filter(lineup, function(pc)
				return pc.RosterType == 'Beast' and pc.Object.Tamer == GetObjKey(user) and not pc.Stored;
			end);
			table.append(beastList, table.map(pcList, function(pc)
				return { Pc = pc, BeastType = pc.BeastType, Object = pc.Object };
			end));
		end
	else
		local session = GetSession();
		local rosters = session.rosters;
		local pcList = table.filter(rosters, function(pc)
			return pc.RosterType == 'Beast' and pc.Object.Tamer == GetObjKey(user) and not pc.Stored;
		end);
		table.append(beastList, table.map(pcList, function(pc)
			local objKey = GetBeastObjKey(GetPlayerTeamName(), pc);
			return { Pc = pc, BeastType = pc.BeastType, Object = GetUnit(objKey, true) };
		end));
	end
	local tamingList = GetInstantProperty(user, 'TamingList') or {};
	table.append(tamingList, GetInstantProperty(user, 'BeastList') or {});
	table.append(beastList, table.map(tamingList, function(objKey)
		local obj = nil;
		if IsMissionServer() then
			obj = GetUnit(GetMission(user), objKey, true);
		else
			obj = GetUnit(objKey, true);
		end
		local beastCls = nil;
		local beastType = GetInstantProperty(obj, 'BeastType');
		if beastType then
			beastCls = GetClassList('BeastType')[beastType];
		end
		return { Pc = nil, BeastType = beastCls, Object = obj };
	end));
	return beastList;
end
function GetEnableSummonBeastList(user)
	local summonBeastList = GetSummonBeastList(user);
	return table.filter(summonBeastList, function(info)
		return info.Object.HP > 0 and not IsDead(info.Object) and IsEnableSummonBeast(info.Object, info.BeastType, user, info.Pc);
	end);
end
---------------------------------------------------------
-- 진화 단계 CP
---------------------------------------------------------
function CalculatedProperty_BeastType_EvolutionStage(self)
	for _, beastCls in pairs(GetClassList('BeastType')) do
		for key, _ in pairs(beastCls.Evolutions) do
			if key == self.name then
				return 1 + beastCls.EvolutionStage;
			end
		end	
	end
	return 1;
end
---------------------------------------------------------
-- 길들이기, 진화 특성 후보
---------------------------------------------------------
function GetBeastUniqueMasteryCandidate(beastType)
	local candidateList_NoTraining = {};
	local candidateList_Training = {};
	local candidateList_Nature = {};
	local candidateList_GeneOrESP = {};
	
	local beastUniqueSet = {};
	for key, _ in pairs(GetClassList('BeastUniqueEvolutionMastery')) do
		beastUniqueSet[key] = true;
	end
	
	for key, masteryCls in pairs(GetClassList('Mastery')) do
		if masteryCls.Category.name == 'Beast' and not beastUniqueSet[masteryCls.name] then
			if masteryCls.Type.name == 'Training' then
				table.insert(candidateList_Training, key);
			elseif masteryCls.Type.name == 'Nature' then
				table.insert(candidateList_NoTraining, key);
				table.insert(candidateList_Nature, key);
			elseif masteryCls.Type.name == 'Gene' then
				table.insert(candidateList_NoTraining, key);
				table.insert(candidateList_GeneOrESP, key);
			else
				-- 초능력 타입
				if masteryCls.Type.name == beastType.Monster.Object.ESP.name then
					table.insert(candidateList_NoTraining, key);
					table.insert(candidateList_GeneOrESP, key);
				end
			end
		end
	end
	return candidateList_NoTraining, candidateList_Training, candidateList_Nature, candidateList_GeneOrESP;
end
function PickBeastUniqueMasteryCandidate(object, beastType, noTraining, pickCount, useFixedMastery)
	local masteryTable = GetMastery(object);
	local candWithoutTraining, candTraining, candNature, candGeneOrESP = GetBeastUniqueMasteryCandidate(beastType);
	
	local ret = {};
	
	local fixedMasteryList = {};
	local fixedMasterySet = {};
	if useFixedMastery then
		local fixedClsList = table.filter(beastType.FixedEvolutionMastery, function(cls)
			return not GetMasteryMastered(masteryTable, cls.Name);
		end);
		local pickerMap = {};
		for _, fixedCls in ipairs(fixedClsList) do
			local picker = pickerMap[fixedCls.Slot];
			if picker == nil then
				picker = RandomPicker.new();
				pickerMap[fixedCls.Slot] = picker;
			end
			picker:addChoice(fixedCls.Rate, fixedCls.Name);			
		end
		local pickedList = {};
		for slot, picker in pairs(pickerMap) do
			local picked = picker:pick();
			if picked then
				table.insert(fixedMasteryList, picked);
				fixedMasterySet[picked] = slot;
			end
		end
		fixedMasteryList = table.scoresort(fixedMasteryList, function(m) return fixedMasterySet[m] end);
		
		local totalCount = pickCount + #fixedMasteryList;
		local maxCount = math.min(totalCount, 6);
		pickCount = maxCount - #fixedMasteryList;
	end
	
	local filter = function(l)
		return table.filter(l, function(m)
			return not GetMasteryMastered(masteryTable, m) and not fixedMasterySet[m];
		end)
	end;
	if not noTraining then
		-- 우선뽑기
		table.insert(ret, table.randompick(filter(candTraining)));
		local natureOne = table.randompick(filter(candNature));
		table.insert(ret, natureOne);
		local geneOne = table.randompick(filter(candGeneOrESP));
		table.insert(ret,geneOne);
		pickCount = pickCount - #ret;
		
		-- 뽑은거 제거
		candWithoutTraining = table.filter(candWithoutTraining, function(m) return m ~= natureOne and m ~= geneOne; end);
	end

	local picker = RandomPicker.new(false);
	for _, masteryName in ipairs(candWithoutTraining) do
		if not GetMasteryMastered(masteryTable, masteryName) then
			picker:addChoice(1, masteryName);	
		end
	end
	table.append(ret, picker:pickMulti(pickCount));
	
	local masteryList = GetClassList('Mastery');
	local scoreTable = {Gene = 1, [beastType.Monster.Object.ESP.name] = 2, Nature = 3, Training = 4};
	ret = table.scoresort(ret, function(m) return scoreTable[masteryList[m].Type.name] end);
	
	if #fixedMasteryList > 0 then
		table.append(ret, fixedMasteryList);
	end
	
	return ret;
end
---------------------------------------------------------
-- 야수 모델 크기
---------------------------------------------------------
function CalculatedProperty_Beast_SceneScale(self)
	if IsLobby() then
		return self.BeastType.LobbyScale;
	elseif IsMission() then
		return self.BeastType.MissionScale;
	else
		return 1;
	end
end
---------------------------------------------------------
-- 야수 방출 가능한지
---------------------------------------------------------
function IsEnableRemoveBeast(pcInfo)
--	return pcInfo.RosterType == 'Beast' and pcInfo.CP >= 100;
	return pcInfo.RosterType == 'Beast' and not pcInfo.Locked;
end
---------------------------------------------------------
-- 야수 특성 변경 가능한지
---------------------------------------------------------
function IsEnableChangeEvolutionMastery(pcInfo)
	if pcInfo.RosterType ~= 'Beast' then
		return false;
	end
	if IsNeedSelectEvolutionMastery(pcInfo) then
		return false;
	end
	local evolutionStage = pcInfo.BeastType.EvolutionStage;
	local propName = string.format('EvolutionMastery%d', evolutionStage);
	local evolutionMastery = GetWithoutError(pcInfo, propName);
	local masteryCls = GetClassList('Mastery')[evolutionMastery];
	if masteryCls and masteryCls.Type.name ~= 'Training' and masteryCls.Type.name ~= 'Nature' then
		return false, 'Beast_DisableChangeEvolutionMastery';
	end
	return true;
end
---------------------------------------------------------
-- 변경 가능한 야수 특성 목록
---------------------------------------------------------
function GetEnableChangeEvolutionMasteryList(pcInfo)
	local list = {};
	if pcInfo.RosterType ~= 'Beast' then
		return list;
	end
	local usingSet = {};
	for i = 1, pcInfo.BeastType.EvolutionMaxStage do
		local evolutionMastery = GetWithoutError(pcInfo, string.format('EvolutionMastery%d', i));
		if evolutionMastery and evolutionMastery ~= 'None' then
			usingSet[evolutionMastery] = true;
		end
	end
	local masteryList = GetClassList('Mastery');
	for key, masteryCls in pairs(masteryList) do
		if masteryCls.Category.name == 'Beast' and masteryCls.Type.name == 'Training' and not usingSet[key] then
			table.insert(list, masteryCls);
		end
	end
	return list;
end
function IsEnableChangeCharacterMastery_Beast(pcInfo, characterMasteryName, itemCountAcquirer)
	local reason = {};
	local isEnable = true;
	local trainingManualCount = itemCountAcquirer('Statement_Mastery');
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
	local enableList = GetEnableChangeEvolutionMasteryList(pcInfo);
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
---------------------------------------------------------
-- 야수 진화 가능한지
---------------------------------------------------------
function IsEnableAnyEvolution(pcInfo)
	if pcInfo.RosterType ~= 'Beast' then
		return false, nil, nil;
	end
	local isEnable = false;
	local minLv = 99;
	local evolutionCount = 0;
	for key, info in pairs(pcInfo.BeastType.Evolutions) do
		if pcInfo.Lv >= info.RequireLv then
			isEnable = true;
		end
		minLv = math.min(minLv, info.RequireLv);
		evolutionCount = evolutionCount + 1;
	end
	return isEnable, minLv, evolutionCount;
end
--------------------------------------------------
-- 진화 가능한가.
--------------------------------------------------
function IsSatisfiedBeastEvolution(pcInfo, beastTypeName)
	local isEnable = true;
	local reason = {};
	
	local beastType = pcInfo.BeastType;
	local evolutionInfo = GetWithoutError(SafeIndex(beastType, 'Evolutions'), beastTypeName);
	local requireLv = GetWithoutError(evolutionInfo, 'RequireLv');
	local requireJobLv = GetWithoutError(evolutionInfo, 'RequireJobLv');
	
	-- 0. 데이터 유효성 검사.
	if not evolutionInfo then
		table.insert(reason, 'NotExistEnableBeastEvolution');
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
function IsEnableBeastEvolution(company, pcInfo, beastTypeName, itemCounter)
	local isEnable = false;
	local needItem = nil;
	local needCount = nil;
	local reason = {};
	-- 1. 진화 가능한 야수 타입이 Open 되었는가.
	if IsSatisfiedBeastEvolution(pcInfo, beastTypeName) then
		isEnable = true;
	else
		table.insert(reason, 'BeastEvolutionIsNotOpened');
	end
	-- 2. 진화에 필요한 아이템이 존재하는가.
	local beastType = pcInfo.BeastType;
	local evolutionInfo = GetWithoutError(SafeIndex(beastType, 'Evolutions'), beastTypeName);
	if evolutionInfo then
		needItem = SafeIndex(evolutionInfo, 'RequireItem');
		needCount = SafeIndex(evolutionInfo, 'RequireItemCount');
		if needItem ~= 'None' and needCount > 0 then
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
--------------------------------------------------------
-- 진화 레벨 제한에 걸렸는지
--------------------------------------------------------
function GetTamerObject(target)
	if IsMission() then
		local mission = GetMission_Shared(target);
		local tamerObj = nil;
		local tamerKey = target.Tamer;
		if tamerKey == '' then
			-- 테이머 정보가 없으면 안 되지만, 기존 개발 중인 데이터 때문에 일단 땜빵침
			tamerKey = GetInstantProperty(target, 'SummonMaster') or '';
		end
		if tamerKey == '' then
			return nil;
		end
		if IsMissionServer() then
			return GetUnit(mission, tamerKey, true);
		else
			return GetUnit(tamerKey, true);
		end
	else
		local rosters = {};
		local pcInfo = nil;
		if IsLobbyServer() then
			local company = GetCompany(target);
			rosters = GetAllRoster(company);
			pcInfo = GetRosterFromObject(target);
		else
			local session = GetSession();
			rosters = session.rosters;
			pcInfo = GetPcInfo(target, rosters);
		end
		local tamerKey = pcInfo.Tamer;
		if tamerKey == '' then
			-- 테이머 정보가 없으면 안 되지만, 기존 개발 중인 데이터 때문에 일단 땜빵침
			for _, pcInfo in ipairs(rosters) do
				if pcInfo.Object.Job.name == 'Hunter' then
					tamerKey = pcInfo.RosterKey;
					break;
				end
			end
		end
		if tamerKey == '' then
			return nil;
		end
		local tamerPc = GetPcInfoByName(tamerKey, rosters);
		local tamerObj = tamerPc.Object;
		return tamerObj, tamerPc;
	end
end
function IsLevelUpLimitedByTamer(target)
	local tamer = GetTamerObject(target);
	if not tamer then
		return false;
	end
	local isLimited = false;
	if target.Lv >= tamer.Lv then
		isLimited = true;
	end	
	return isLimited, tamer.Lv, tamer;
end
--------------------------------------------------------
-- 진화 특성 재선택이 필요한지
--------------------------------------------------------
function IsNeedSelectEvolutionMastery(pcInfo)
	if pcInfo.RosterType ~= 'Beast' then
		return false;
	end
	local evolutionStage = pcInfo.BeastType.EvolutionStage;
	local propName = string.format('EvolutionMastery%d', evolutionStage);
	local evolutionMastery = GetWithoutError(pcInfo, propName);
	if not evolutionMastery or evolutionMastery ~= 'None' then
		return false;
	end
	return true;	
end
--------------------------------------------------------
-- 야수 보관
--------------------------------------------------------
function IsEnableStoreBeast(company, pcInfo)
	local reason = {};
	if pcInfo.RosterType ~= 'Beast' or pcInfo.Stored then
		return false;
	end
	local rosters = {};
	if IsLobbyServer() then
		rosters = GetAllRoster(company);
	else
		local session = GetSession();
		rosters = session.rosters;
	end
	local storedCount = #table.filter(rosters, function(r)
		return r.RosterType == 'Beast' and r.Stored;
	end);
	if storedCount + 1 > company.MaxBeastStoreCount then
		local curReason = { Type = 'NotUseByMaxBeastStoreCount', Value = company.MaxBeastStoreCount };
		table.insert(reason, curReason);
		return false, reason;
	end
	return true;	
end
function IsEnablePickupBeast(company, pcInfo)
	local reason = {};
	if pcInfo.RosterType ~= 'Beast' or not pcInfo.Stored then
		return false;
	end
	local rosters = {};
	if IsLobbyServer() then
		rosters = GetAllRoster(company);
	else
		local session = GetSession();
		rosters = session.rosters;
	end
	local myTotalCount = #table.filter(rosters, function(r)
		return r.RosterType == 'Beast' and not r.Stored;
	end);
	local myPerTypeCount = #table.filter(rosters, function(r)
		return r.RosterType == 'Beast' and not r.Stored and r.Object.Job.name == pcInfo.Object.Job.name;
	end);
	if myTotalCount + 1 > company.MaxBeastCountTotal then
		local curReason = { Type = 'NotUseByMaxBeastCount', Value = company.MaxBeastCountTotal };
		table.insert(reason, curReason);
		return false, reason;
	end
	if myPerTypeCount + 1 > company.MaxBeastCountPerType then
		local curReason = { Type = 'NotUseByMaxBeastCountType', Value = company.MaxBeastCountPerType, JobName = pcInfo.Object.Job.name };
		table.insert(reason, curReason);
		return false, reason;
	end
	return true;
end
function IsEnableSwapBeast(company, pcInfo1, pcInfo2)
	local reason = {};
	if pcInfo1.RosterType ~= 'Beast' or pcInfo1.Stored then
		return false;
	end
	if pcInfo2.RosterType ~= 'Beast' or not pcInfo2.Stored then
		return false;
	end
	local rosters = {};
	if IsLobbyServer() then
		rosters = GetAllRoster(company);
	else
		local session = GetSession();
		rosters = session.rosters;
	end
	-- 데려올 야수(pcInfo2)과 같은 타입 야수들 중에서 맡길 야수(pcInfo1)는 제외한다.
	local myPerTypeCount = #table.filter(rosters, function(r)
		return r.RosterType == 'Beast' and not r.Stored and r.Object.Job.name == pcInfo2.Object.Job.name and r.RosterKey ~= pcInfo1.RosterKey;
	end);
	if myPerTypeCount + 1 > company.MaxBeastCountPerType then
		local curReason = { Type = 'NotUseByMaxBeastCountType', Value = company.MaxBeastCountPerType, JobName = pcInfo2.Object.Job.name };
		table.insert(reason, curReason);
		return false, reason;
	end
	return true;
end
----------------------------------------------------
-- 야수 몬스터 타입
----------------------------------------------------
local g_MonsterToBeastRehash = nil;
function GetBeastTypeClassFromObject(obj)
	if IsMissionServer() then
		local roster = GetRosterFromObject(obj);
		if roster then
			if roster.RosterType ~= 'Beast' then
				return nil;
			end
			return GetHostClass(roster.BeastType);
		end
	end
	
	local monType = FindBaseMonsterTypeWithCache(obj);
	if monType == nil then
		return nil;
	end
	
	if g_MonsterToBeastRehash == nil then
		g_MonsterToBeastRehash = {};
		for _, beastTypeCls in pairs(GetClassList('BeastType')) do
			g_MonsterToBeastRehash[beastTypeCls.Monster.name] = beastTypeCls;
		end
	end
	
	return g_MonsterToBeastRehash[monType];
end