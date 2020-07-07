------------------------------------------------------------------------
-- PC 관련 함수 
------------------------------------------------------------------------
-- Calculated Property 
------------------------------------------------------------------------
function Get_OverChargeCP(pc)
	-- 특성 BestCondition
	local result = pc.MaxCP;
	return result;
end
-- PC 분당 회복량.
function Get_RestoreCPPerMin(pc)
	local result = pc.Base_RestoreCPPerMin * 5;	
	return result;
end
function CalcRestoreCP(pc, sec)
	local restorePerMin = pc.RestoreCPPerMin;
	local nextCP = 0;
	nextCP = pc.CP + sec * (restorePerMin / 60);
	nextCP = math.min(nextCP, pc.OverChargeCP);	
	return nextCP - pc.CP;
end
function GetEstimatedCP(pc)
	local elapsed = 0;
	if pc.CPLastUpdateTime ~= 0 then
		if IsClient() then
			elapsed = os.servertime() - pc.CPLastUpdateTime;
		else
			elapsed = os.time() - pc.CPLastUpdateTime;
		end
	end
	return pc.CP + pc:CalcRestoreCP(elapsed);
end
function CalcRestoreByPcStatus(pc, type, sec)
	local pcStatus = GetClassList('PcStatus')[type];
	if not pcStatus then
		return 0;
	end
	local curSt = GetWithoutError(pc, type) or 0;
	local nextSt = 0;
	nextSt = curSt + math.floor(sec / 3600) * pcStatus.RestorePerHour;
	nextSt = math.max(nextSt, 0);
	return nextSt - curSt;
end
function GetEstimatedSatiety(pc)
	local elapsed = 0;
	if pc.CPLastUpdateTime ~= 0 then
		elapsed = os.time() - pc.CPLastUpdateTime;
	end
	return pc.Satiety + CalcRestoreByPcStatus(pc, 'Satiety', elapsed)
end
function GetEstimatedRefresh(pc)
	local elapsed = 0;
	if pc.CPLastUpdateTime ~= 0 then
		elapsed = os.time() - pc.CPLastUpdateTime;
	end
	return pc.Refresh + CalcRestoreByPcStatus(pc, 'Refresh', elapsed)
end
function CalcMissionRestoreByPcStatus(type, battleDuration)
	local pcStatus = GetClassList('PcStatus')[type];
	if not pcStatus then
		return 0;
	end
	local addSt = 0;
	addSt = addSt + pcStatus.RestorePerMission;
	addSt = addSt + math.floor(battleDuration / pcStatus.RestoreStepMissionTime) * pcStatus.RestorePerMissionTime;
	return addSt;
end
function Get_CPRestoreRamainTime(pc)
	return ( pc.MaxCP - pc.CP ) / pc.RestoreCPPerMin * 60 - ( os.time() - pc.CPLastUpdateTime );
end
function Get_TrainingPoint(pc, arg, masteryTable)
	if not masteryTable then
		masteryTable = GetMastery(pc);
	end
	local maxTp = Get_MaxTrainingPoint(pc);
	local used = GetCurrentMasteryCost(masteryTable);
	return maxTp - used;
end
function Get_MaxTrainingPoint(pc, arg, masteryTable)
	if not masteryTable then
		masteryTable = GetMastery(pc);
	end
	local result = pc.Lv +  pc.BonusTP + pc.Object.MaxPower;
	-- 인간용
	for _, masteryType in ipairs({'Frankness', 'ColdRefusal', 'LoveHate', 'SocialLife'}) do
		local mastery = GetMasteryMastered(masteryTable, masteryType);
		if mastery then
			result = result + mastery.ApplyAmount;
		end
	end
	-- 야수용
	for _, masteryType in ipairs({'GrowthPotential'}) do
		local mastery = GetMasteryMastered(masteryTable, masteryType);
		if mastery then
			result = result + mastery.ApplyAmount;
		end
	end
	return result;
end

function CalculateEstimatedRestExp(pc)
	local hourElapsed = math.floor((os.time() - pc.LastMissionPlayTime) / 3600);
	local recoverRatioPerHour = 4;					-- 1시간당 4%
	local recoverRatioSaved = hourElapsed * recoverRatioPerHour / 100;
	
	local CalcRestExpAmount = function (field, curExp, curRestExpRatio, curLv)
		local recoverRatio = curRestExpRatio + recoverRatioSaved;
		local curMaxExp = GetNextExp(field, curLv);
		local curRatio = curExp / curMaxExp;
		if curRatio + recoverRatio <= 1 then
			return curMaxExp * recoverRatio;				-- 현 레벨 일부
		end
		
		recoverRatio = curRatio + recoverRatio - 1;
		local nextMaxExp = GetNextExp(field, curLv + 1);
		if recoverRatio >= 1 then
			return nextMaxExp + (curMaxExp - curExp);					-- 풀
		else
			return nextMaxExp * recoverRatio + (curMaxExp - curExp);	-- 다음 레벨 일부
		end
	end;
	
	local restExp = CalcRestExpAmount(pc.ExpType, pc.Exp, pc.RestExp, pc.Lv);
	local restJobExp = CalcRestExpAmount(pc.JobExpType, pc.JobExp, pc.RestJobExp, pc.JobLv);
	return restExp, restJobExp;
end
function CalculateRestExpRatio(pc, restExp, restJobExp)
	local CalcRestExpRatio = function(field, curExp, curRestExp, curLv)
		local curMaxExp = GetNextExp(field, curLv);
		local curLeftExpAmount = curMaxExp - curExp;
		if curRestExp <= curLeftExpAmount then
			return curRestExp / curMaxExp;
		end
		
		local leftNextExpAmount = curRestExp - curLeftExpAmount;
		local nextMaxExp = GetNextExp(field, curLv + 1);
		return curLeftExpAmount / curMaxExp + math.min(1, leftNextExpAmount / nextMaxExp);
	end
	return CalcRestExpRatio(pc.ExpType, pc.Exp, restExp, pc.Lv), CalcRestExpRatio(pc.JobExpType, pc.JobExp, restJobExp, pc.JobLv);
end
--------------------------------------------------------------
-- 마스터리 타입별 슬롯 최대 소지 개수
--------------------------------------------------------------
function Get_MaxMasteryCountByType_PC(pc, arg)
	local result = 0;
	local pcCount = 0;
	local jobCount = 0;
	local espCount = 0;
	local masteryCount = 0;
	local sharedMasteryCount = 0;
	local job = pc.Object.Job;
	local esp = pc.Object.ESP;
	-- 1. PC에 따른 개수
	pcCount = pc['Base_'..arg];
	-- 2. 직업에 따른 개수
	if job and job.name and job.name ~= 'None' then
		jobCount = job[arg];
	end
	-- 3. 이능력에 따른 개수
	if esp and esp.name and esp.name ~= 'None' then
		espCount = esp[arg];
	end
	-- 4. 특성에 따른 추가 개수
	masteryCount = pc['Extra'..arg];
	result = pcCount + jobCount + espCount + masteryCount;
	return result;
end
function MasteryExistTestAndSumApplyAmount(masteryTable, targetMasteries, applyAmountKey, info)
	return table.foldr(targetMasteries, function(masteryType, result)
		local mastery = GetMasteryMastered(masteryTable, masteryType);
		if not mastery then
			return result;
		else
			local applyAmount = mastery[applyAmountKey];
			if info then
				table.insert(info, MakeMasteryStatInfo(mastery.name, applyAmount));
			end
			return result + applyAmount;
		end
	end, 0);
end
function FixedMasteryTestAndSumApplyAmount(masteryTable, slotType, applyAmount, info)
	local result = 0;
	for _, mastery in pairs(masteryTable) do
		(function()
			if mastery.Lv <= 0
				or mastery.Category.EquipSlot ~= slotType
				or not mastery.FixedMastery then
				return;
			end
			if info then
				table.insert(info, MakeMasteryStatInfo(mastery.name, applyAmount));
			end
			result = result + applyAmount;
		end)();
	end
	return result;
end
function Get_ExtraMaxBasicMasteryCount_PC(pc, arg, masteryTable)
	if not masteryTable then
		masteryTable = GetMastery(pc);
	end
	local result = 0;
	local info = {};
	-- ApplyAmount Type
	-- 열린마음, 설득, 자아성찰, 기체 강화
	result = result + MasteryExistTestAndSumApplyAmount(masteryTable, {'OpenMind', 'Persuasion', 'SelfExamination', 'Application_EnhancedFrame', 'HardBone', 'Module_FrameEnhanced', 'Module_FrameOptimaztion', 'BeastNormalTraining'}, 'ApplyAmount', info);
	-- FixedMastery
	result = result + FixedMasteryTestAndSumApplyAmount(masteryTable, 'Basic', 1, info);
	return result, info;
end
function Get_ExtraMaxSubMasteryCount_PC(pc, arg, masteryTable)
	if not masteryTable then
		masteryTable = GetMastery(pc);
	end
	local result = 0;
	local info = {};
	-- ApplyAmount Type
	-- 융통성, 원칙주의, 합리적 의심, 추가 지원 모듈
	result = result + MasteryExistTestAndSumApplyAmount(masteryTable, {'Flexibility', 'Principlism', 'ReasonablySuspects', 'Module_AuxiliarySupportModule', 'WildNatureKnowledge', 'BeastSubTraining'}, 'ApplyAmount', info);
	-- FixedMastery
	result = result + FixedMasteryTestAndSumApplyAmount(masteryTable, 'Sub', 1, info);
	return result, info;
end
function Get_ExtraMaxAttackMasteryCount_PC(pc, arg, masteryTable)
	if not masteryTable then
		masteryTable = GetMastery(pc);
	end
	local result = 0;
	local info = {};
	-- ApplyAmount Type
	-- 히스테리, 철면피, 추가 강화 모듈
	result = result + MasteryExistTestAndSumApplyAmount(masteryTable, {'Hysterie', 'Brazenface', 'Module_AuxiliaryComplementaryModule', 'TerritorialDisputes', 'BeastAttackTraining'}, 'ApplyAmount', info);
	-- FixedMastery
	result = result + FixedMasteryTestAndSumApplyAmount(masteryTable, 'Attack', 1, info);
	return result, info;
end
function Get_ExtraMaxDefenceMasteryCount_PC(pc, arg, masteryTable)
	if not masteryTable then
		masteryTable = GetMastery(pc);
	end
	local result = 0;
	local info = {};
	-- ApplyAmount Type
	-- 작전상 후퇴, 궤변 추가 보안 모듈
	result = result + MasteryExistTestAndSumApplyAmount(masteryTable, {'TacticalRetreat', 'Sophistry', 'Module_AuxiliarySaftyModule', 'PersistentLife', 'BeastDefenceTraining'}, 'ApplyAmount', info);
	-- FixedMastery
	result = result + FixedMasteryTestAndSumApplyAmount(masteryTable, 'Defence', 1, info);
	return result, info;
end
function Get_ExtraMaxAbilityMasteryCount_PC(pc, arg, masteryTable)
	if not masteryTable then
		masteryTable = GetMastery(pc);
	end
	local result = 0;
	local info = {};
	-- ApplyAmount Type
	-- 추가 인공지능 모듈
	result = result + MasteryExistTestAndSumApplyAmount(masteryTable, {'Module_AuxiliaryAIModule', 'BeastAbilityTraining'}, 'ApplyAmount', info);
	-- FixedMastery
	result = result + FixedMasteryTestAndSumApplyAmount(masteryTable, 'Ability', 1, info);
	return result, info;
end
--------------------------------------------------------------
-- 마스터리 타입별 현재 소지 개수
--------------------------------------------------------------
function Get_AbilityMasteryCount(pc)
	return GetCurrentArgMasteryCount(masteryTable, 'Ability');
end
function Get_BasicMasteryCount(pc)
	return GetCurrentArgMasteryCount(masteryTable, 'Normal');
end
function Get_SubMasteryCount(pc)
	return GetCurrentArgMasteryCount(masteryTable, 'Sub');
end
function Get_AttackMasteryCount(pc)
	return GetCurrentArgMasteryCount(masteryTable, 'Attack');
end
function Get_DefenceMasteryCount(pc)
	return GetCurrentArgMasteryCount(masteryTable, 'Defence');
end
function Get_UniqueMasteryCount(pc)
	return GetCurrentUniqueMasteryCount(GetMastery(pc));
end
--------------------------------------------------------------
-- 마스터리 타입별 초대 코스트 수.
--------------------------------------------------------------
function Get_MaxMasteryCost_Shared_PC(pc, arg, masteryTable)
	local result = 0;
	-- 인간용
	result = result + MasteryExistTestAndSumApplyAmount(masteryTable, {'PangOfConscience', 'Consideration', 'GraciousRefusal', 'ForthrightStatement', 'Sortilege', 'SocialLife', 'Egoist', 'Illuminati', 'KeyboardWarrior'}, 'ApplyAmount');

	-- 야수용
	result = result + MasteryExistTestAndSumApplyAmount(masteryTable, {'AdaptiveTraining', 'ParentalLove'}, 'ApplyAmount');
	
	-- 기계용
	result = result + MasteryExistTestAndSumApplyAmount(masteryTable, {'Application_PowerControl', 'Module_AuxiliaryPowerControl', 'Module_PowerProvider'}, 'ApplyAmount');
	return result;
end
function Get_MaxAbilityMasteryCost_PC(pc, arg, masteryTable)
	if not masteryTable then
		masteryTable = GetMastery(pc);
	end
	local result = 1;
	result = result + 2 * ( pc.MaxAbilityMasteryCount - 1 ) + pc.BonusAbilityMasteryCost;
	result = result + Get_MaxMasteryCost_Shared_PC(pc, arg, masteryTable);
	-- 인공지능 모듈
	result = result + MasteryExistTestAndSumApplyAmount(masteryTable, {'MachineUnique_AIModule'}, 'ApplyAmount');
	-- 추가 기체 최적화
	result = result + MasteryExistTestAndSumApplyAmount(masteryTable, {'Module_FrameOptimaztion'}, 'ApplyAmount3');
	-- FixedMastery
	result = result + FixedMasteryTestAndSumApplyAmount(masteryTable, 'Ability', -2);
	return result;
end
function Get_MaxBasicMasteryCost_PC(pc, arg, masteryTable)
	if not masteryTable then
		masteryTable = GetMastery(pc);
	end
	local result = 1;
	result = result + 2 * ( pc.MaxBasicMasteryCount - 1 )  + pc.BonusBasicMasteryCost;
	result = result + Get_MaxMasteryCost_Shared_PC(pc, arg, masteryTable);
	-- 기체 모듈
	result = result + MasteryExistTestAndSumApplyAmount(masteryTable, {'MachineUnique_FrameModule'}, 'ApplyAmount');
	-- FixedMastery
	result = result + FixedMasteryTestAndSumApplyAmount(masteryTable, 'Basic', -2);
	return result;
end
function Get_MaxSubMasteryCost_PC(pc, arg, masteryTable)
	if not masteryTable then
		masteryTable = GetMastery(pc);
	end
	local result = 1;
	result = result + 2 * ( pc.MaxSubMasteryCount - 1 )  + pc.BonusSubMasteryCost;
	result = result + Get_MaxMasteryCost_Shared_PC(pc, arg, masteryTable);
	-- 지원 모듈
	result = result + MasteryExistTestAndSumApplyAmount(masteryTable, {'MachineUnique_SupportModule'}, 'ApplyAmount');
	-- 추가 기체 강화
	result = result + MasteryExistTestAndSumApplyAmount(masteryTable, {'Module_FrameEnhanced'}, 'ApplyAmount3');
	-- FixedMastery
	result = result + FixedMasteryTestAndSumApplyAmount(masteryTable, 'Sub', -2);
	return result;
end
function Get_MaxAttackMasteryCost_PC(pc, arg, masteryTable)
	if not masteryTable then
		masteryTable = GetMastery(pc);
	end
	local result = 1;
	result = result + 2 * ( pc.MaxAttackMasteryCount - 1 )  + pc.BonusAttackMasteryCost;
	result = result + Get_MaxMasteryCost_Shared_PC(pc, arg, masteryTable);
	-- 강화 모듈
	result = result + MasteryExistTestAndSumApplyAmount(masteryTable, {'MachineUnique_ComplementaryModule'}, 'ApplyAmount');
	-- 추가 기체 강화
	result = result + MasteryExistTestAndSumApplyAmount(masteryTable, {'Module_FrameEnhanced'}, 'ApplyAmount3');
	-- FixedMastery
	result = result + FixedMasteryTestAndSumApplyAmount(masteryTable, 'Attack', -2);
	return result;
end
function Get_MaxDefenceMasteryCost_PC(pc, arg, masteryTable)
	if not masteryTable then
		masteryTable = GetMastery(pc);
	end
	local result = 1;
	result = result + 2 * ( pc.MaxDefenceMasteryCount - 1 )  + pc.BonusDefenceMasteryCost;
	result = result + Get_MaxMasteryCost_Shared_PC(pc, arg, masteryTable);
	-- 보안 모듈
	result = result + MasteryExistTestAndSumApplyAmount(masteryTable, {'MachineUnique_SaftyModule'}, 'ApplyAmount');
	-- 추가 기체 최적화
	result = result + MasteryExistTestAndSumApplyAmount(masteryTable, {'Module_FrameOptimaztion'}, 'ApplyAmount3');
	-- FixedMastery
	result = result + FixedMasteryTestAndSumApplyAmount(masteryTable, 'Defence', -2);
	return result;
end
function GetMasteryUnlockSlotCountByLv(category, lv)
	local masteryUnlockLevel = GetClassList('MasteryUnlockLevel')[category];
	if not masteryUnlockLevel then
		return 0;
	end
	local slotCount = 0;
	for index, unlockLevel in ipairs(masteryUnlockLevel.Unlock) do
		if unlockLevel > lv then
			break;
		end
		slotCount = slotCount + 1;
	end
	return slotCount;
end
function Get_UnlockAbilityMasteryCost_PC(pc, arg)
	return GetMasteryUnlockSlotCountByLv('Ability', pc.Lv);
end
function Get_UnlockAttackMasteryCost_PC(pc, arg)
	return GetMasteryUnlockSlotCountByLv('Attack', pc.Lv);
end
function Get_UnlockBasicMasteryCost_PC(pc, arg)
	return GetMasteryUnlockSlotCountByLv('Normal', pc.Lv);
end
function Get_UnlockDefenceMasteryCost_PC(pc, arg)
	return GetMasteryUnlockSlotCountByLv('Defence', pc.Lv);
end
function Get_UnlockSubMasteryCost_PC(pc, arg)
	return GetMasteryUnlockSlotCountByLv('Sub', pc.Lv);
end			
function Get_UnlockAbilityMasteryCost_Machine(pc, arg)
	return GetMasteryUnlockSlotCountByLv('AIModule', pc.Lv);
end
function Get_UnlockAttackMasteryCost_Machine(pc, arg)
	return GetMasteryUnlockSlotCountByLv('ComplementaryModule', pc.Lv);
end
function Get_UnlockBasicMasteryCost_Machine(pc, arg)
	return GetMasteryUnlockSlotCountByLv('FrameModule', pc.Lv);
end
function Get_UnlockDefenceMasteryCost_Machine(pc, arg)
	return GetMasteryUnlockSlotCountByLv('SaftyModule', pc.Lv);
end
function Get_UnlockSubMasteryCost_Machine(pc, arg)
	return GetMasteryUnlockSlotCountByLv('SupportModule', pc.Lv);
end
--------------------------------------------------------------
-- 오브젝트 CP
--------------------------------------------------------------
function GetPcStateFromConditionValue(currentCP, maxCP)
	return GetPcStateFromConditionValueByType('Condition', currentCP, maxCP);
end
function GetPcStateFromConditionValueByType(objectType, currentCP, maxCP)
	local pcStateList = GetClassList('PcState');
	local temp = {};
	for key, objState in pairs (pcStateList) do
		if objState.Type == objectType then
			table.insert(temp, objState);
		end
	end
	table.sort(temp, function(a, b)
		return a.Order < b.Order;
	end);
	
	local curObjState = nil;
	for index, state in ipairs (temp) do
		if objectType == 'Condition' or objectType == 'Loyalty' then
			if currentCP >= maxCP * state.Min * 0.01 then
				curObjState = state.name;
				break;
			end
		elseif objectType == 'Duration' then
			if currentCP >= state.Min then
				curObjState = state.name;
				break;
			end
		end
	end
	return curObjState;
end
function GetAddResultCP_Beast(target, win)
	local addCP = 0;
	if win ~= nil then
		if win then
			-- 소환 중이고 주인과 자신이 살아있으면 5 증가
			local summonMasterKey = GetInstantProperty(target, 'SummonMaster');
			if summonMasterKey then
				local mission = GetMission(target);
				local summonMaster = GetUnit(mission, summonMasterKey);
				if summonMaster and not IsDead(summonMaster) and not IsDead(target) then
					addCP = addCP + 5;
				end
			end
		else
			-- 소환된 적이 있으면 5 감소
			local summonCount = GetInstantProperty(target, 'SummonCount') or 0;
			if summonCount > 0 then
				addCP = addCP - 5;
			end
		end
	end
	-- 소환 해제된 횟수마다 1 감소
	local unsummonCount = GetInstantProperty(target, 'UnsummonCount') or 0;
	if unsummonCount > 0 then
		addCP = addCP - 1 * unsummonCount;
	end
	return addCP;
end
---------------------------------------------------------
-- 캐릭터 특성 변경
---------------------------------------------------------
function IsEnableChangeCharacterMastery(pcInfo, characterMasteryName, itemCountAcquirer)
	
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
	local isStartingMastery = false;
	for i = 1, #pcInfo.StartingMastery do
		local curStartingMasteryName = pcInfo.StartingMastery[i];
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
-- 특성판 추가
---------------------------------------------------------
function IsEnableAddMasteryBoard(pcInfo, itemCountAcquirer)
	local reason = {};
	local isEnable = true;
	
	local curBoardCount = pcInfo.MasteryBoard.Count;
	local maxBoardCount = pcInfo.MasteryBoard.MaxCount;
	if curBoardCount >= maxBoardCount then
		table.insert(reason, 'AlreadyMaxCount');
		isEnable = false;
		return isEnable, 'None', 0, reason;
	end
	
	local nextIndex = curBoardCount + 1;
	if nextIndex > #pcInfo.MasteryBoard.Board then
		LogAndPrint('DataError - Not Enough Board Property - nextIndex:', nextIndex);
		table.insert(reason, 'DataError');
		isEnable = false;
		return isEnable, 'None', 0, reason;
	end
	
	local needItem = pcInfo.MasteryBoard.Board[nextIndex].NeedItem;
	local needCount = pcInfo.MasteryBoard.Board[nextIndex].NeedCount;
	
	if needItem ~= 'None' and needCount > 0 then
		local needItemCount = itemCountAcquirer(needItem);
		if needItemCount < needCount then
			table.insert(reason, 'NotEnoughItem');
			isEnable = false;
		end
	end
	return isEnable, needItem, needCount, reason;
end