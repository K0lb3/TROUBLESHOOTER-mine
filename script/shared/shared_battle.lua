function BuildDamageFlagFromResultModifier(resultModifier)	
	local damageFlag = {};
	for _, key in ipairs({'Overwatch', 'Counter', 'Forestallment', 'ReactionAbility', 'CloseCheckFire', 'AttackWithBeast', 'InvokedByTrap', 'Dash', 'Inevitable', 'Retribution', 'Devastate', 'SupportHeal'}) do
		if SafeIndex(resultModifier, key) then
			damageFlag[key] = true;
		end
	end
	return damageFlag;
end
------------------------------------------------------------------------------------------------
-------------------------------------- 명중률 계산 공식 ----------------------------------------
------------------------------------------------------------------------------------------------
-- calculationMode: nil | 'Static' | 'PositionRelative'
MockPerfChecker = {StartRoutine = function() end, EndRoutine = function() end, Dive = function() end, Rise = function() end};
function GetHitRateCalculator(Attacker, Defender, Ability, usingPos, weather, missionTime, missionTemperature, resultModifier, aiFlag, abilityDetailInfo, perfChecker)
	if perfChecker == nil then
		perfChecker = MockPerfChecker;
	end
	perfChecker:StartRoutine('Begin');
	
	local damageFlag = BuildDamageFlagFromResultModifier(resultModifier);
	
	local masteryTable_Attacker = GetMastery(Attacker);
	local masteryTable_Defender = GetMastery(Defender);

	local isDummy = false;	
	local totalAccuracy = 0;
	local defenderDodge = 0;
	local baseDefenderDodge = 0;
	
	local stableState = 0;
	local hitRateType = Ability.HitRateType;
	
	-- info 정보 넣기.
	-- BttleFomula.xml idspace HitRateCondition에 타입을 추가해야 한다.
	local info = {};
	
	if Ability.Type == 'Heal' or Ability.IgnoreDodge
		or Defender ~= nil and Defender.Obstacle 
		or damageFlag.Inevitable then
		if aiFlag ~= 'PositionRelative' then
			return 100, {{Type = 'Inevitable', Value = 100, ValueType = 'Formula'}}, 100;
		else
			return 0, {}, 0;
		end
	end
	
	-- 특성 기습 & 어둠사냥꾼
	if Defender ~= nil and IsDarkTime(missionTime) then
		local mastery_Ambush = GetMasteryMastered(masteryTable_Attacker, 'Ambush');
		local mastery_DarkHunter = GetMasteryMastered(masteryTable_Attacker, 'DarkHunter');
		if mastery_Ambush and mastery_DarkHunter and not HasBuff(Attacker, 'ExposurePosition') then
			local group_Sleep_List = GetBuffType(Defender, nil, nil, mastery_DarkHunter.BuffGroup);
			if #group_Sleep_List > 0 or Defender.PreBattleState then
				if aiFlag ~= 'PositionRelative' then
					return 100, {{Type = mastery_DarkHunter.name, Value = 100, ValueType = 'Mastery'}}, 100;
				else
					return 0, {}, 0;
				end
			end
		end
	end
	
	-- 1. 공격자 명중률. / 방어자 없이 계산되는 부분.
	perfChecker:StartRoutine('GetCurrentAccuracy');
	local abilityAccuracy = GetCurrentAccuracy(info, Ability, Attacker, masteryTable_Attacker, aiFlag, resultModifier);
	-- 2. 스탯으로 인한 상승하는 공격자 명중률.
	perfChecker:StartRoutine('GetModifyAbilityAccuracyFromStatus_Attacker');
	local passiveAccuracy_Attacker = GetModifyAbilityAccuracyFromStatus_Attacker(info, Ability, Attacker, aiFlag);
	-- 3. 상황에 따라 상승하는 공격자 명중률.
	perfChecker:StartRoutine('GetModifyAbilityAccuracyFromEvent');
	local addAccuracy = GetModifyAbilityAccuracyFromEvent(info, Ability, Attacker, Defender, usingPos, masteryTable_Attacker, masteryTable_Defender, weather, missionTime, damageFlag, aiFlag, abilityDetailInfo);
	-- 4. 방어자가 있어야 계산 되는 부분.
	if Defender ~= nil then
		-- 5. 회피 구하기.
		perfChecker:StartRoutine('GetDodgeRateCalculator');
		local curDodge, dodgeInfos = GetDodgeRateCalculator(Attacker, Defender, Ability, missionTime, missionTemperature, damageFlag, aiFlag, perfChecker);
		defenderDodge = curDodge;
		if aiFlag == nil then
			for index, dodgeInfo in ipairs (dodgeInfos) do
				dodgeInfo.Value = -1 * dodgeInfo.Value;
				table.insert(info, dodgeInfo);
			end
		end
		perfChecker:StartRoutine('KnownJobs');
		if Attacker.KnownJobs[Defender.Job.name] and aiFlag ~= 'PositionRelative' then
			local hitRateValue = 0.25 * Attacker.JobLv;
			if Defender.Job.name == Attacker.Job.name then
				hitRateValue = hitRateValue * 2;
			end
			if hitRateValue ~= 0 then
				addAccuracy = addAccuracy + hitRateValue;
				table.insert(info, {Type = 'Job', Value = hitRateValue, ValueType = 'Formula', Job = Defender.Job.name});
			end
		end
	end
	perfChecker:StartRoutine('Else');
	-- 3. 적의 회피율과 엊어맞을 확률을 계산한다.
	totalAccuracy = abilityAccuracy + passiveAccuracy_Attacker + addAccuracy - defenderDodge;
	
	-- 4. 경계 사격인 경우
	if damageFlag.Overwatch then
		if damageFlag.Dash then
			totalAccuracy = totalAccuracy - 40;
		else
			totalAccuracy = totalAccuracy - 20;
		end
	end
	
	local maxAccuracy = math.floor(totalAccuracy * 100)/100;
	local resultAccuracy = math.max(0, math.min(maxAccuracy, 100));
	if aiFlag == nil then
		-- info 정보 소트 및. 조준 정보 추가.
		if #info > 0 then
			table.sort(info, function (a, b)
				return a.Value > b.Value;
			end);
		end
		
		local infoValue = 0;
		for index, value in ipairs (info) do
			infoValue = infoValue + value.Value;
		end
		local basicValue = totalAccuracy - infoValue;
		if basicValue ~= 0 then
			table.insert(info, 1, { Type = 'Aim', Value = basicValue, ValueType = 'Formula'});
		end
	end
	perfChecker:EndRoutine();
	return resultAccuracy, info, maxAccuracy;
end
function GetHitRateCalculator_Buff(self, target, ability, usingPos, weather, missionTime)
	local info = {{Type='AbilityBase', Value = ability.ApplyTargetBuffChance, ValueType='Formula'}};
	local total = math.max(0, math.min(ability.ApplyTargetBuffChance, 100));
	return total, info, ability.ApplyTargetBuffChance;
end
function GetHitRateCalculator_Provocation(self, target, ability, usingPos, weather, missionTime)
	local _, info, total = GetHitRateCalculator_Buff(self, target, ability, usingPos, weather, missionTime);
	-- 레벨차이에 의한 명중률 보정
	local levelDiff = self.Lv - target.Lv;
	table.insert(info, {Type = 'LevelDiff', Value = levelDiff, ValueType = 'Formula'});
	
	total = total + levelDiff;
	return math.max(0, math.min(total, 100)), info, total;
end
function GetHitRateCalculator_Inevitable(self, target, ability, usingPos, weather, missionTime)
	return 100, {{Type = 'Inevitable', Value = 100, ValueType = 'Formula'}}, 100;
end
function GetHitRateCalculator_HackingSuicideCode(self, target, ability, usingPos, weather, missionTime)
	local _, info, total = GetHitRateCalculator_Buff(self, target, ability, usingPos, weather, missionTime);
	-- 타겟의 체력 비율에 의한 명중률 보정
	local hpFix = 50 * (1 - target.HP / target.MaxHP);
	table.insert(info, {Type = 'DefenderHPFix', Value = hpFix, ValueType = 'Formula'});
	
	total = total + hpFix;
	return math.max(0, math.min(total, 100)), info, total;
end
function GetHitRateCalculator_HackingProtocol(Attacker, Defender, Ability, usingPos, weather, missionTime, missionTemperature, resultModifier, aiFlag, abilityDetailInfo)
	local detailType = SafeIndex(abilityDetailInfo, 'ProtocolDetail');
	local ret = 0;
	local info = {};
	if detailType == nil then
		return 0, {}, 0;
	end
	local protocolCls = GetClassList('HackingProtocol')[detailType];
	
	local checker = _G[Ability.TargetUseableChecker];
	if checker then
		local ret = checker(Attacker, Ability, Defender, {});
		if ret ~= nil and ret ~= 'Able' then
			return 0, {}, 0;
		end
	end
	
	-- 기본 명중률
	local ability = protocolCls.Ability;
	ability = GetAbilityObject(Attacker, ability.name) or ability;
	ret = ret + ability.Accuracy;
	table.insert(info, {Type = 'HackingProtocol', Value = ability.Accuracy, ValueType = 'Formula', HackingProtocol = detailType});
	
	-- 목표거리
	local distance, height = GetDistanceFromObjectToObjectAbility(Ability, Attacker, Defender);
	local penaltyHitRate = -math.floor(distance * 3);
	if penaltyHitRate ~= 0 then
		ret = ret + penaltyHitRate;
		table.insert(info, { Type = 'Distance', Value = penaltyHitRate, ValueType = 'Formula'});
	end
	
	-- 해당 대상과 나의 레벨 차이 X 몬스터의 Grade(일반 ~ 전설)의 HackingPenalty 값만큼 성공률 감소.
	local levelDiff = Attacker.Lv -  Defender.Lv;
	local gradeMod = levelDiff * Defender.Grade.HackingPenalty;
	if gradeMod ~= 0 then
		ret = ret + gradeMod;
		table.insert(info, { Type = 'LevelDiff', Value = gradeMod, ValueType = 'Formula'});
	end
	
	-- 특성 천재성
	local masteryTable = GetMastery(Attacker);
	local mastery_Genius = GetMasteryMastered(masteryTable, 'Genius');
	if mastery_Genius then
		ret = ret + mastery_Genius.ApplyAmount;
		table.insert(info, MakeMasteryStatInfo(mastery_Genius.name, mastery_Genius.ApplyAmount));
	end	
	
	-- 분할 정복 알고리즘
	local mastery_DivideAndConquerAlgorithm = GetMasteryMastered(masteryTable, 'DivideAndConquerAlgorithm');
	if mastery_DivideAndConquerAlgorithm then
		ret = ret + mastery_DivideAndConquerAlgorithm.ApplyAmount2;
		table.insert(info, MakeMasteryStatInfo(mastery_DivideAndConquerAlgorithm.name, mastery_DivideAndConquerAlgorithm.ApplyAmount2));
	end
	
	-- 정보 제어
	local mastery_InformationControl = GetMasteryMastered(masteryTable, 'InformationControl');
	if mastery_InformationControl then
		ret = ret + mastery_InformationControl.ApplyAmount2;
		table.insert(info, MakeMasteryStatInfo(mastery_InformationControl.name, mastery_InformationControl.ApplyAmount2));
	end
	
	-- 버프 관리자 권한
	local buff_ManagerAuthority = GetBuff(Attacker, 'ManagerAuthority');
	if buff_ManagerAuthority then
		ret = ret + buff_ManagerAuthority.ApplyAmount;
		table.insert(info, { Type = buff_ManagerAuthority.name, Value = buff_ManagerAuthority.ApplyAmount, ValueType = 'Buff' });
	end
	
	-- 시스템 보안
	local mastery_Module_SystemSecurity = GetMasteryMastered(masteryTable, 'Module_SystemSecurity');
	if mastery_Module_SystemSecurity then
		ret = ret - mastery_Module_SystemSecurity.ApplyAmount;
		table.insert(info, MakeMasteryStatInfo(mastery_Module_SystemSecurity.name, -mastery_Module_SystemSecurity.ApplyAmount));
	end
	
	-- 방화벽
	local buff_Firewall = GetBuff(Defender, 'Firewall');
	if buff_Firewall then
		ret = ret - buff_Firewall.ApplyAmount;
		table.insert(info, { Type = buff_Firewall.name, Value = - buff_Firewall.ApplyAmount, ValueType = 'Buff' });
	end
	
	-- 역공학
	local mastery_ReverseEngineering = GetMasteryMastered(masteryTable, 'ReverseEngineering');
	if mastery_ReverseEngineering then
		ret = ret + mastery_ReverseEngineering.ApplyAmount;
		table.insert(info, MakeMasteryStatInfo(mastery_ReverseEngineering.name, mastery_ReverseEngineering.ApplyAmount));
	end	
	
	table.sort(info, function (infoA, infoB) return infoA.Value > infoB.Value end);
	
	return math.max(0, math.min(100, ret)), info, ret;
end
function GetHitRateCalculator_InvestigateLock(Attacker, Defender, Ability, usingPos, weather, missionTime, missionTemperature, resultModifier, aiFlag, abilityDetailInfo)
	local subCommand = SafeIndex(abilityDetailInfo, 'SubCommand');
	if subCommand == nil then
		subCommand = 'InvestigateLock_Force';
	end
	
	local ret = 0;
	local info = {};
	if subCommand == nil then
		return 0, {}, 0;
	end
	
	if subCommand == 'InvestigateLock_Key' then
		-- 기본 명중률
		local basicHitRate = 100;
		ret = ret + basicHitRate;
		table.insert(info, {Type = 'Basic', Value = basicHitRate, ValueType = 'Formula'});
	else
		-- 기본 명중률
		local basicHitRate = 10;
		ret = ret + basicHitRate;
		table.insert(info, {Type = 'Basic', Value = basicHitRate, ValueType = 'Formula'});
	end
	
	table.sort(info, function (infoA, infoB) return infoA.Value > infoB.Value end);
	
	return math.max(0, math.min(100, ret)), info, ret;
end
function GetHitRateCalculator_InvestigateLock_Force(Attacker, Defender, Ability, usingPos, weather, missionTime, missionTemperature, resultModifier, aiFlag, abilityDetailInfo)
	local ret = 0;
	local info = {};
	if subCommand == nil then
		return 0, {}, 0;
	end
	
	-- 기본 명중률
	local basicHitRate = 10;
	ret = ret + basicHitRate;
	table.insert(info, {Type = 'Basic', Value = basicHitRate, ValueType = 'Formula'});
	
	table.sort(info, function (infoA, infoB) return infoA.Value > infoB.Value end);
	
	return math.max(0, math.min(100, ret)), info, ret;
end
------------------------------------------------------------------------------
-- 기본 명중 수치 얻어오기.
------------------------------------------------------------------------------
function GetCurrentAccuracy(info, Ability, Attacker, masteryTable_Attacker, aiFlag, resultModifier)
	local result = 0;
	if aiFlag ~= 'PositionRelative' then
		local arg = 'Accuracy';
		result = Attacker.Accuracy + Ability.Accuracy;
		if Ability.Accuracy ~= 0 then
			table.insert(info, { Type = Ability.name, Value = Ability.Accuracy, ValueType = 'Ability'});
		end
		tableAppend(info, GetStatusInfo(Attacker, 'Accuracy'));
	end
	if aiFlag ~= 'Static' then
		local calcOption = {};
		calcOption.UsePrevAbilityPosition = SafeIndex(Ability, 'AbilityWithMove');
		calcOption.MasteryTable = masteryTable_Attacker;		
		if resultModifier then
			local reactionAbility = SafeIndex(resultModifier, 'ReactionAbility') and true or false;
			local counterAttack = SafeIndex(resultModifier, 'Counter') and true or false;
			calcOption.NotStableAttack = reactionAbility or counterAttack;
		end
		result = result + (GetConditionalStatus(Attacker, 'Accuracy_Base', info, calcOption) or 0);
	end
	return result;
end
------------------------------------------------------------------------------
-- 기본 회피 얻어 오기
------------------------------------------------------------------------------
local DodgeComposer = nil;
function GetDodgeRateCalculator(Attacker, Defender, Ability, missionTime, missionTemperature, damageFlag, aiFlag, perfChecker)
	if perfChecker == nil then
		perfChecker = MockPerfChecker;
	end
	perfChecker:Dive();
	perfChecker:StartRoutine('Begin');
	local dodge = 0;
	local masteryTable_Attacker = GetMastery(Attacker);
	local masteryTable_Defender = GetMastery(Defender);	
	local info = {};

	-- 1. 회피는 방어자가 있어야만 한다.
	-- 2. 힐은 막는게 없다.
	if not Defender or Ability.Type == 'Heal' or Ability.IgnoreDodge then
		perfChecker:Rise();
		return dodge, info, 0;
	end
	-- 3. 의식불명 상태에서는 회피 불가
	if GetBuffStatus(Defender, 'Unconscious', 'Or') then
		perfChecker:Rise();
		return 0, info, 0;
	end
	-- 4. 대기중에는 막지 못한다.
	if GetBuff(Defender, 'Stand') then
		perfChecker:Rise();
		return 0, info, 0;
	end
	-- 5. 은신 공격은 회피하지 못한다.
	if GetBuff(Attacker, 'Stealth') then
		perfChecker:Rise();
		return 0, info, 0;
	end
	perfChecker:StartRoutine('CreateComposer');
	if DodgeComposer == nil then
		DodgeComposer = BattleFormulaComposer.new('math.max((Dodge - MinusDodge) * (1 + Multiplier / 100), 0)', {'Dodge', 'MinusDodge', 'Multiplier'});
	end
	local dodgeComposer = DodgeComposer:Clone();
	
	-- 1. 방어자 기본 회피 확률
	if aiFlag ~= 'PositionRelative' then
		perfChecker:StartRoutine('Basic');
		local baseInfo = {};
		local baseDodge = GetCurrentDodge(baseInfo, Ability, Defender);
		
		dodgeComposer:AddDecompData('Dodge', baseDodge, {});
	end
	-- 2. 특정 상황에서만 발생하는 회피율
	perfChecker:StartRoutine('GetCurrentDodge_Normal');
	local normalInfo = {};
	local minusInfo = {};
	local abilityDodge_Normal, abilityDodge_Minus = GetCurrentDodge_Normal(normalInfo, minusInfo, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, missionTime, missionTemperature, damageFlag, aiFlag);
	dodgeComposer:AddDecompData('Dodge', abilityDodge_Normal, normalInfo);
	dodgeComposer:AddDecompData('MinusDodge', abilityDodge_Minus, minusInfo);
	-- 3. 트러블메이커 보정
	perfChecker:StartRoutine('DodgeEtc');
	local abilityDodge_Troublemaker = 0;
	if aiFlag ~= 'PositionRelative' then
		local tmInfo = {};
		abilityDodge_Troublemaker = GetCurrentDodge_Troublemaker(tmInfo, Attacker, Defender);
		dodgeComposer:AddDecompData('Dodge', abilityDodge_Troublemaker, tmInfo);
	end

	-- 사전 계획
	-- 비율로 빠지는 거라서 aiFlag랑 상관없이 다 계산
	local mastery_PriorPlanning = GetMasteryMastered(masteryTable_Attacker, 'PriorPlanning');
	if mastery_PriorPlanning then
		dodgeComposer:AddDecompData('Multiplier', -mastery_PriorPlanning.ApplyAmount, {MakeMasteryStatInfo(mastery_PriorPlanning.name, -mastery_PriorPlanning.ApplyAmount)});
	end
	
	local resultDodge = dodgeComposer:ComposeFormula();
	local info;
	if aiFlag == nil then
		info = dodgeComposer:ComposeInfoTable();
		
		-- info 정보 넣기.
		table.sort(info, function (a, b)
			return a.Value > b.Value;
		end);
		info = table.filter(info, function (i) return i.Value ~= 0; end);
		
		local infoValue = 0;
		for index, value in ipairs (info) do
			infoValue = infoValue + value.Value;
		end
		local basicValue = resultDodge - infoValue;
		if basicValue ~= 0 then
			table.insert(info, 1, { Type = 'Dodge', Value = basicValue, ValueType = 'Formula'});
		end
	end
	perfChecker:Rise();
	return resultDodge, info;
end
function GetCurrentDodge(info, Ability, Defender)
	local arg = 'Dodge';
	local result = Defender.Dodge;
	if result > 0 then
		tableAppend(info, GetStatusInfo(Defender, arg));
	end
	return result;
end
function GetCurrentDodge_Normal(addInfo, minusInfo, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, missionTime, missionTemperature, damageFlag, aiFlag)
	local addValue = 0;
	local minusValue = 0;
	
	if aiFlag ~= 'PositionRelative' then
		-- 방어자 한정 조건부 회피율
		addValue = addValue + GetConditionalStatus(Defender, 'Dodge', {}, {MissionTime = missionTime, MissionTemperature = missionTemperature, MasteryTable = masteryTable_Defender});
		
		-- 마셜 아츠
		local mastery_MartialArt = GetMasteryMastered(masteryTable_Defender, 'MartialArt');
		if mastery_MartialArt then
			if IsLongDistanceAttack(Ability) then
				addValue = addValue + mastery_MartialArt.ApplyAmount2;
				table.insert(addInfo, MakeMasteryStatInfo(mastery_MartialArt.name, mastery_MartialArt.ApplyAmount2));
			end
		end
		-- 질풍 신뢰
		local buff_FlashAura = GetBuff(Defender, 'FlashAura');
		if buff_FlashAura and Ability.HitRateType == 'Melee' then
			addValue = addValue + 30;
			table.insert(addInfo, {Type = buff_FlashAura.name, Value = 30, ValueType = 'Buff'});
		end
		-- 보이지 않는 검
		local mastery_InvisibleSword = GetMasteryMastered(masteryTable_Defender, 'InvisibleSword');
		if mastery_InvisibleSword and IsLongDistanceAttack(Ability) then
			local targetKey = GetObjKey(Attacker);
			local prevTargets = GetInstantProperty(Defender, 'InvisibleSword') or {};
			if not prevTargets[targetKey] then
				addValue = addValue + mastery_InvisibleSword.ApplyAmount;
				table.insert(addInfo, MakeMasteryStatInfo(mastery_InvisibleSword.name, mastery_InvisibleSword.ApplyAmount));
			end
		end
		-- 예측 사격
		local mastery_PredictedFire = GetMasteryMastered(masteryTable_Attacker, 'PredictedFire')
		if mastery_PredictedFire and Ability.HitRateType == 'Force' and IsGetAbilitySubType(Ability, 'Piercing') then
			local mValue = mastery_PredictedFire.ApplyAmount;
			minusValue = minusValue + mValue;
			table.insert(minusInfo, MakeMasteryStatInfo(mastery_PredictedFire.name, mValue));
		end
		-- 압도하는 기백
		local mastery_HeavyPressure = GetMasteryMastered(masteryTable_Attacker, 'HeavyPressure')
		if mastery_HeavyPressure and Attacker.Lv > Defender.Lv then
			local mValue = mastery_HeavyPressure.ApplyAmount;
			-- 영웅의 기백
			local mastery_HeroSpirit = GetMasteryMastered(masteryTable_Attacker, 'HeroSpirit');
			if mastery_HeroSpirit then
				mValue = mValue + math.floor(GetCurrentSP(Attacker) / mastery_HeroSpirit.ApplyAmount) * mastery_HeroSpirit.ApplyAmount2;
			end
			minusValue = minusValue + mValue;
			table.insert(minusInfo, MakeMasteryStatInfo(mastery_HeavyPressure.name, mValue));
		end
		-- 기계 공학
		if Defender.Race.name == 'Machine' then
			local mastery_MechanicalEngineering = GetMasteryMastered(masteryTable_Attacker, 'MechanicalEngineering') or GetMasteryMastered(masteryTable_Attacker, 'MechanicalEngineering_Machine');
			if mastery_MechanicalEngineering then
				local mValue = mastery_MechanicalEngineering.ApplyAmount;
				minusValue = minusValue + mValue;
				table.insert(minusInfo, MakeMasteryStatInfo(mastery_MechanicalEngineering.name, mValue));
			end
		end
		if Attacker.Race.name == 'Machine' then
			local mastery_MechanicalEngineering = GetMasteryMastered(masteryTable_Defender, 'MechanicalEngineering') or GetMasteryMastered(masteryTable_Defender, 'MechanicalEngineering_Machine');
			if mastery_MechanicalEngineering then
				local addDodge = mastery_MechanicalEngineering.ApplyAmount;
				addValue = addValue + addDodge;
				table.insert(addInfo, MakeMasteryStatInfo(mastery_MechanicalEngineering.name, addDodge));
			end
		end
		-- 대인 살상 훈련
		local mastery_HumanKillTraining = GetMasteryMastered(masteryTable_Defender, 'HumanKillTraining');
		if mastery_HumanKillTraining then
			if Ability.Type == 'Attack' and SafeIndex(Attacker, 'Race', 'name') == 'Human' and GetRelation(Defender, Attacker) == 'Enemy' then
				local addDodge = mastery_HumanKillTraining.ApplyAmount;
				addValue = addValue + addDodge;
				table.insert(addInfo, MakeMasteryStatInfo(mastery_HumanKillTraining.name, addDodge));
			end
		end
		-- 굴하지 않는 기백
		local mastery_UndefeatedSpirit = GetMasteryMastered(masteryTable_Defender, 'UndefeatedSpirit');
		if mastery_UndefeatedSpirit then
			if Ability.Type == 'Attack' and Attacker.Lv > Defender.Lv then
				local addDodge = mastery_UndefeatedSpirit.ApplyAmount;
				-- 영웅의 기백
				local mastery_HeroSpirit = GetMasteryMastered(masteryTable_Defender, 'HeroSpirit');
				if mastery_HeroSpirit then
					addDodge = addDodge + math.floor(GetCurrentSP(Defender) / mastery_HeroSpirit.ApplyAmount) * mastery_HeroSpirit.ApplyAmount2;
				end
				addValue = addValue + addDodge;
				table.insert(addInfo, MakeMasteryStatInfo(mastery_UndefeatedSpirit.name, addDodge));
			end
		end
		-- 고급 반동 제어 프로그램
		local mastery_Module_HighControlReactor = GetMasteryMastered(masteryTable_Attacker, 'Module_HighControlReactor');
		if mastery_Module_HighControlReactor and Ability.Type == 'Attack' and not Attacker.TurnState.Moved then
			local mValue = math.floor((Attacker.MaximumLoad - Attacker.Load) / mastery_Module_HighControlReactor.ApplyAmount) * mastery_Module_HighControlReactor.ApplyAmount2;
			if mValue > 0 then
				minusValue = minusValue + mValue;
				table.insert(minusInfo, MakeMasteryStatInfo(mastery_Module_HighControlReactor.name, mValue));
			end
		end
		-- 청경 (회피)
		local mastery_ListeningEnergy = GetMasteryMastered(masteryTable_Attacker, 'ListeningEnergy');
		if mastery_ListeningEnergy and SafeIndex(damageFlag, 'ReactionAbility') then
			minusValue = minusValue + mastery_ListeningEnergy.ApplyAmount;
			table.insert(minusInfo, MakeMasteryStatInfo(mastery_ListeningEnergy.name, mastery_ListeningEnergy.ApplyAmount));
		end
		
		-- 예측불허
		local mastery_Unpredictability = GetMasteryMastered(masteryTable_Attacker, 'Unpredictability');
		if mastery_Unpredictability and table.exist({'Retribution', 'Devastate', 'Forestallment', 'Counter'}, function(flag) return damageFlag[flag] ~= nil; end) then
			minusValue = minusValue + mastery_Unpredictability.ApplyAmount;
			table.insert(minusInfo, MakeMasteryStatInfo(mastery_Unpredictability.name, mastery_Unpredictability.ApplyAmount));
		end
		
		-- 포식자의 청각
		addValue = addValue + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'PredatorEar', addInfo, function(mastery)
			if Ability.Type == 'Attack' and Attacker.HP < Defender.HP then
				if not GetMasteryMasteredList(masteryTable_Attacker, { 'StealthyFootsteps', 'StealthyFootsteps_Beast', 'Module_NoiseControl' }) then
					return mastery.ApplyAmount;
				end
			end
		end);
		
		-- 돌연변이의 청각
		addValue = addValue + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'MutationEar', addInfo, function(mastery)
			if Ability.Type == 'Attack' and Attacker.HP > Defender.HP then
				if not GetMasteryMasteredList(masteryTable_Attacker, { 'StealthyFootsteps', 'StealthyFootsteps_Beast', 'Module_NoiseControl' }) then
					return mastery.ApplyAmount;
				end
			end
		end);
		
		-- 해골복/해골 자켓/해골 코트/해골 활동복
		if IsDarkTime(missionTime) and (Ability.HitRateType == 'Force' or Ability.HitRateType == 'Throw' or Ability.HitRateType == 'Fall') then
			local mastery_ScullArmor = GetMasteryMasteredList(masteryTable_Defender, {'Jacket_Skull', 'Jacket_Skull_Legend', 'Coat_Skull_Legend', 'Tracksuit_Skull_Legend'});
			if mastery_ScullArmor then
				addValue = addValue + mastery_ScullArmor.ApplyAmount;
				table.insert(addInfo, MakeMasteryStatInfo(mastery_ScullArmor.name, mastery_ScullArmor.ApplyAmount));
			end
		end
		
		-- 왕의 청각
		addValue = addValue + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'KingEar', addInfo, function(mastery)
			if Ability.Type == 'Attack' and Attacker.Grade.Weight < Defender.Grade.Weight and GetRelation(Defender, Attacker) == 'Enemy' then
				if not GetMasteryMasteredList(masteryTable_Attacker, { 'StealthyFootsteps', 'StealthyFootsteps_Beast', 'Module_NoiseControl' }) then
					return mastery.ApplyAmount;
				end
			end
		end);
		
		-- 마도의 빛 - 3 세트
		minusValue = minusValue + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'GoldNeguriESPSet3', minusInfo, function(mastery)
			if Ability.Type == 'Attack' and IsGetAbilitySubType(Ability, 'ESP') and GetRelation(Attacker, Defender) == 'Enemy' then
				return mastery.ApplyAmount;
			end
		end);
		
		-- 살수의 길
		minusValue = minusValue + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'GoldNeguriESPSet3', minusInfo, function(mastery)
			if Defender.Race.name == 'Human' then
				return mastery.ApplyAmount;
			end
		end);
		
		-- 무모함
		minusValue = minusValue + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'Recklessness', minusInfo, function(mastery)
			if Ability.Type == 'Attack' and HasBuffType(Defender, nil, nil, mastery.BuffGroup.name) then
				return mastery.ApplyAmount2;
			end
		end);
	end
	if aiFlag ~= 'Static' then
		if IsMeleeDistance(GetAbilityUsingPosition(Attacker), GetAbilityUsingPosition(Defender)) then
			-- 검술사의 영역
			local mastery_SwordsmanArea = GetMasteryMastered(masteryTable_Attacker, 'SwordsmanArea');
			if mastery_SwordsmanArea then
				minusValue = minusValue + mastery_SwordsmanArea.ApplyAmount;
				table.insert(minusInfo, MakeMasteryStatInfo(mastery_SwordsmanArea.name, mastery_SwordsmanArea.ApplyAmount));
			end
			-- 눈부신 칼날
			local mastery_GlaringBlade = GetMasteryMastered(masteryTable_Attacker, 'GlaringBlade');
			if mastery_GlaringBlade then
				minusValue = minusValue + mastery_GlaringBlade.ApplyAmount;
				table.insert(minusInfo, MakeMasteryStatInfo(mastery_GlaringBlade.name, mastery_GlaringBlade.ApplyAmount));
			end
		end
		local distance, height = GetDistanceFromObjectToObjectAbility(Ability, Attacker, Defender);
		-- 하늘 위를 걷는 자
		local mastery_OntheSkyWalker = GetMasteryMastered(masteryTable_Defender, 'OntheSkyWalker');
		if mastery_OntheSkyWalker then
			local attackerHigh, attackerLow = IsAttakerHighPosition(height, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender);
			if attackerLow then
				addValue = addValue + mastery_OntheSkyWalker.ApplyAmount;
				table.insert(addInfo, MakeMasteryStatInfo(mastery_OntheSkyWalker.name, mastery_OntheSkyWalker.ApplyAmount));
			end
		end
		-- 병렬처리 (공격시)
		local mastery_ParallelProcessing = GetMasteryMastered(masteryTable_Attacker, 'ParallelProcessing');
		if mastery_ParallelProcessing then
			local enableUseCount = 0;
			for _, ability in ipairs(GetEnableProtocolAbilityList(Attacker, Ability)) do
				if ability.IsUseCount then
					enableUseCount = enableUseCount + ability.UseCount;
				end
			end
			
			local applyRatio = mastery_ParallelProcessing.ApplyAmount3;
			local mastery_InformationSpecialist = GetMasteryMastered(masteryTable_Attacker, 'InformationSpecialist');
			if mastery_InformationSpecialist and distance <= mastery_InformationSpecialist.ApplyAmount2 + 0.4 then
				applyRatio = applyRatio * (1 + mastery_InformationSpecialist.ApplyAmount / 100);
			end
			
			local stepCount = math.floor(enableUseCount / mastery_ParallelProcessing.ApplyAmount);				-- ApplyAmount 당
			if stepCount > 0 then
				local multiplier_ParallelProcessing = math.floor(stepCount * applyRatio);	-- ApplyAmount 만큼 minus가 증가
				minusValue = minusValue + multiplier_ParallelProcessing;
				table.insert(minusInfo, MakeMasteryStatInfo(mastery_ParallelProcessing.name, multiplier_ParallelProcessing));
			end
		end
		
		-- 낮은 엄폐 자세
		local mastery_LowPosition = GetMasteryMastered(masteryTable_Defender, 'LowPosition');
		if mastery_LowPosition then
			local coverState = GetCoverStateForCritical(Defender, masteryTable_Defender, GetAbilityUsingPosition(Attacker), Attacker);
			local addDodge;
			if coverState == 'Full' then
				addDodge = mastery_LowPosition.ApplyAmount;
			elseif coverState == 'Half' then
				addDodge = mastery_LowPosition.ApplyAmount2;
			else
				addDodge = 0;
			end
			if addDodge > 0 then
				addValue = addValue + addDodge;
				table.insert(addInfo, MakeMasteryStatInfo(mastery_LowPosition.name, addDodge));
			end
		end
		
		-- 고지대 엄폐
		local mastery_HighPositionCover = GetMasteryMastered(masteryTable_Defender, 'HighPositionCover');
		if mastery_HighPositionCover then
			local attackerHigh, attackerLow = IsAttakerHighPosition(height, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender);
			if attackerLow then
				local coverState = GetCoverStateForCritical(Defender, masteryTable_Defender, GetAbilityUsingPosition(Attacker), Attacker);
				local addDodge = 0;
				if coverState == 'Full' then
					addDodge = mastery_HighPositionCover.ApplyAmount;
				elseif coverState == 'Half' then
					addDodge = mastery_HighPositionCover.ApplyAmount2;
				else
					addDodge = 0;
				end
				if addDodge > 0 then
					addValue = addValue + addDodge;
					table.insert(addInfo, MakeMasteryStatInfo(mastery_HighPositionCover.name, addDodge));
				end
			end
		end
		
		-- 플람베
		minusValue = minusValue + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'Flambee', minusInfo, function(mastery)
			if Ability.Type == 'Attack' and IsGetAbilitySubType(Ability, 'Fire') and IsObjectOnFieldEffect(Defender, 'Fire') then
				return mastery.ApplyAmount;
			end
		end);
	end
	
	return addValue, minusValue;
end
------------------------------------------------------------------------------
-- Status (특성, 아이템, 캐릭터, 버프) 등에서 얻어오는 값.
------------------------------------------------------------------------------
-- 공격자
function GetModifyAbilityAccuracyFromStatus_Attacker(info, Ability, Attacker, usingPos, aiFlag)
	if aiFlag == 'Position' then
		return 0;
	end	
	local result = 0;
		
	local InfoAdder = function(stat)
		local status = Attacker[stat];
		if status and status ~= 0 then
			result = result + status;
			tableAppend(info, GetStatusInfo(Attacker, stat));
		end
	end
	
	-- 어빌리티 공격, 공격자 스탯.
	-- 1. 공격자 스탯
	if Ability.Type == 'Attack' then
		if Ability.SubType ~= 'None' then
			local superType = GetAbilitySuperType(Ability);
			if superType ~= nil then
				InfoAdder('IncreaseHitRate_'..superType);
			end
			InfoAdder('IncreaseHitRate_'..Ability.SubType);
		end
		if Ability.HitRateType ~= 'None' then
			InfoAdder('IncreaseHitRate_'..Ability.HitRateType);
		end
	end
	return result;
end
------------------------------------------------------------------------------
-- 특정 상황에서 적용되는 값.
------------------------------------------------------------------------------
function IsStableAttack(Attacker)
	return (Attacker.TurnState.Stable and not Attacker.TurnState.TurnEnded and GetBuffStatus(Attacker, 'Stable', 'And'));
end
function GetModifyAbilityAccuracyFromEvent(info, Ability, Attacker, Defender, usingPos, masteryTable_Attacker, masteryTable_Defender, weather, missionTime, damageFlag, aiFlag, abilityDetailInfo)
	local totalAccuracy = 0;
	if not IsMission() then
		return totalAccuracy;
	end
	
	-- 1. 공격자 순수 계산 가능한 값.
	-- 1) 날씨
	if Ability.Type == 'Attack' and aiFlag ~= 'PositionRelative' then
		local weatherStateAccuracy = 0;
		
		local weatherList = GetClassList('MissionWeather');
		local weatherCls = weatherList[weather];
		if weather == 'Windy' then
			if Ability.HitRateType == 'Force' then
				weatherStateAccuracy = -weatherCls.ApplyAmount4;
			elseif Ability.HitRateType == 'Throw' then
				weatherStateAccuracy = -weatherCls.ApplyAmount5;
			end
		elseif weather == 'Rain' then
			weatherStateAccuracy = -weatherCls.ApplyAmount5;
		elseif weather == 'Snow' then
			if Ability.HitRateType == 'Force' or Ability.HitRateType == 'Throw' or Ability.HitRateType == 'Fall' then
				weatherStateAccuracy = -weatherCls.ApplyAmount5;
			end
		elseif weather == 'Fog' then
			if Ability.HitRateType == 'Force' or Ability.HitRateType == 'Throw' or Ability.HitRateType == 'Fall' then
				weatherStateAccuracy = -weatherCls.ApplyAmount2;
			end
		end
		
		if weatherStateAccuracy ~= 0 then
			totalAccuracy = totalAccuracy + weatherStateAccuracy;
			table.insert(info, { Type = 'Weather', Value = weatherStateAccuracy, ValueType = 'Formula', Weather = weather});
		end
		
		-- 야생 생활 / 환경 적응
		local immuneMastery = GetMasteryMasteredImmuneWeather(masteryTable_Attacker);
		-- 혹한의 야수(눈)
		if not immuneMastery and weather == 'Snow' then
			immuneMastery = GetMasteryMastered(masteryTable_Attacker, 'ColdBeast');
		end
		-- 빗속의 야수(비)
		if not immuneMastery and weather == 'Rain' then
			immuneMastery = GetMasteryMastered(masteryTable_Attacker, 'RainBeast');
		end
		if immuneMastery then
			local addAmount = -weatherStateAccuracy;
			totalAccuracy = totalAccuracy + addAmount;
			table.insert(info, MakeMasteryStatInfo(immuneMastery.name, addAmount));
		end
	end
	-- 2) 주위 반경 유닛 조건 (타겟이 없어도 주위 반경으로 타겟을 찾아 반응을 하는 것들.)
	local addAccuracy_Range = (aiFlag ~= 'Static') and GetModifyAbilityAccuracyFromEvent_Range_Attacker(info, Ability, Attacker, masteryTable_Attacker) or 0;
	totalAccuracy = totalAccuracy + addAccuracy_Range;
	
	-- 3) 환경에 의한 조건부 명중률
	if aiFlag ~= 'PositionRelative' then
		totalAccuracy = totalAccuracy + GetConditionalStatus(Attacker, 'Accuracy_Environment', info, {MissionTime = missionTime, MissionWeather = weather, MasteryTable = masteryTable_Attacker});
	end
	
	-- 4) 공격 위치에 따른 명중률
	if aiFlag == nil then	-- 비용이 비싸기 때문에 실제 aiFlag가 없을 때에만 계산함
		local mastery_Scattershot = GetMasteryMastered(masteryTable_Attacker, 'Scattershot');
		if mastery_Scattershot then
			local applyTargets = BuildApplyTargetInfos(Attacker, Ability, usingPos);
			if #applyTargets >= 2 then
				local addAccuracy = #applyTargets * mastery_Scattershot.ApplyAmount;
				totalAccuracy = totalAccuracy + addAccuracy;
				table.insert(info, MakeMasteryStatInfo(mastery_Scattershot.name, addAccuracy));
			end
		end
	end

	if Defender == nil then
		return totalAccuracy;
	end
	-- 2, 방어자가 있을 경우에만
	-- 1) 방어자 위치, 엄폐, 거리, 타일 효과.
	if aiFlag ~= 'Static' then
		local addAccuracy_Position = GetModifyAbilityAccuracyFromEvent_Normal_Position(info, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, damageFlag);
		totalAccuracy = totalAccuracy + addAccuracy_Position;
	end
	-- 2) 공격자 일반.
	if aiFlag ~= 'PositionRelative' then
		local addAccuracy_Normal_Attacker = GetModifyAbilityAccuracyFromEvent_Normal_Attacker(info, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, missionTime, abilityDetailInfo, damageFlag);
		totalAccuracy = totalAccuracy + addAccuracy_Normal_Attacker;
		-- 3) 트러블메이커 보정
		local addAccuracy_Troublemaker = GetModifyAbilityAccuracyFromEvent_Troublemaker(info, Attacker, Defender);
		totalAccuracy = totalAccuracy + addAccuracy_Troublemaker;	
		
		-- 4) 목표 확인
		local buff_TargetChecking = GetBuff(Attacker, 'TargetChecking');
		if buff_TargetChecking and GetObjKey(Defender) == buff_TargetChecking.ReferenceTarget then
			local addHitRate = buff_TargetChecking.ApplyAmount;
			totalAccuracy = totalAccuracy + addHitRate;
			table.insert(info, { Type = buff_TargetChecking.name, Value = addHitRate, ValueType = 'Buff'});
		end
	end
	return totalAccuracy;
end
---------------------------------------------------------------------
-- 위치, 거리, 엎폐, 지형(타일)에 따른 명중률 패널티
---------------------------------------------------------------------
function GetModifyAbilityAccuracyFromEvent_Normal_Position(info, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, damageFlag)
	local result = 0;
	local distance, height = GetDistanceFromObjectToObjectAbility(Ability, Attacker, Defender);
	-- 1) 대상과의 거리에 따른 명중률 패널티
	result = result + GetHitRateByDistance(info, Attacker, Ability.HitRateType, distance, masteryTable_Attacker, masteryTable_Defender);
	-- 2) 대상간의 고저차에 따른 명중률 패널티/보너스
	result = result + GetPenaltyHitRateByHeight(info, Attacker, Defender, Ability.HitRateType, height, masteryTable_Attacker, masteryTable_Defender);
	-- 3) 대상간의 엄폐에 따른 패널티 (경계 사격 시에는 적용되지 않음)
	if not damageFlag.Overwatch then
		result = result + GetHitRateByCoverState(info, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, Ability.HitRateType, Ability.AbilityWithMove);
	end
	
	if IsMeleeDistanceHeight(distance, height) then
		-- 맞잡고 싸우기
		local mastery_Grappling = GetMasteryMastered(masteryTable_Attacker, 'Grappling');
		if mastery_Grappling then
			result = result + mastery_Grappling.ApplyAmount;
			table.insert(info, MakeMasteryStatInfo(mastery_Grappling.name, mastery_Grappling.ApplyAmount));
		end
	end
	
	-- 조건이 복수로 적용 가능한 특성들
	local notStableAttack = damageFlag.ReactionAbility or damageFlag.Counter;
	local passCount = IsStableAttack(Attacker) and not notStableAttack and 1 or 0;
	passCount = passCount + (IsAttakerHighPosition(height, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender) and 1 or 0);
	if passCount > 0 then
		local mastery_SnipingTraining = GetMasteryMastered(masteryTable_Attacker, 'SnipingTraining');
		if mastery_SnipingTraining then
			local curAdditionalAccuracy = mastery_SnipingTraining.ApplyAmount * passCount;
			result = result + curAdditionalAccuracy;
			table.insert(info, MakeMasteryStatInfo(mastery_SnipingTraining.name, curAdditionalAccuracy));
		end
	end
	
	return result;
end
---------------------------------------------------------------------
-- 공격자 일반.
---------------------------------------------------------------------
function GetModifyAbilityAccuracyFromEvent_Normal_Attacker(info, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, missionTime, abilityDetailInfo, damageFlag)
	local result = 0;
	--  버프 표식.
	local buff_TargetMarking = GetBuff(Defender, 'TargetMarking');
	if buff_TargetMarking then
		local curAdditionalAccuracy = buff_TargetMarking.ApplyAmount;
		result = result + curAdditionalAccuracy;
		table.insert(info, { Type = buff_TargetMarking.name, Value = curAdditionalAccuracy, ValueType = 'Buff'});	
	end
	--  버프 위치 노출.
	local buff_ExposurePosition = GetBuff(Defender, 'ExposurePosition');
	if buff_ExposurePosition then
		local curAdditionalAccuracy = buff_ExposurePosition.ApplyAmount;
		result = result + curAdditionalAccuracy;
		table.insert(info, { Type = buff_ExposurePosition.name, Value = curAdditionalAccuracy, ValueType = 'Buff'});	
	end
	-- 연막.
	local buff_SmokeScreen = GetBuff(Defender, 'SmokeScreen');
	if buff_SmokeScreen then
		if Ability.HitRateType == 'Force' then
			local curAdditionalAccuracy = -buff_SmokeScreen.ApplyAmount;
			result = result + curAdditionalAccuracy;
			table.insert(info, { Type = buff_SmokeScreen.name, Value = curAdditionalAccuracy, ValueType = 'Buff'});
		end
	end
	-- 수풀.
	local buff_Bush = GetBuff(Defender, 'Bush');
	if buff_Bush then
		local curAdditionalAccuracy = -buff_Bush.ApplyAmount;
		result = result + curAdditionalAccuracy;
		table.insert(info, { Type = buff_Bush.name, Value = curAdditionalAccuracy, ValueType = 'Buff'});
	end
	-- 번개 갑옷
	local buff_LightningArmor = GetBuff(Defender, 'LightningArmor');
	if buff_LightningArmor then
		if Ability.HitRateType ~= 'Melee' then
			local curAdditionalAccuracy = -1 * buff_LightningArmor.ApplyAmount;
			result = result + curAdditionalAccuracy;
			table.insert(info, { Type = buff_LightningArmor.name, Value = curAdditionalAccuracy, ValueType = 'Buff'});
		end
	end
	-- 천둥 갑옷
	local buff_ThunderArmor = GetBuff(Defender, 'ThunderArmor');
	if buff_ThunderArmor then
		if Ability.HitRateType ~= 'Melee' then
			local curAdditionalAccuracy = -1 * buff_ThunderArmor.ApplyAmount;
			result = result + curAdditionalAccuracy;
			table.insert(info, { Type = buff_ThunderArmor.name, Value = curAdditionalAccuracy, ValueType = 'Buff'});
		end
	end	
	-- 바람 장막
	local buff_WindArmor = GetBuff(Defender, 'WindArmor');
	if buff_WindArmor then
		if Ability.HitRateType == 'Melee' then
			local curAdditionalAccuracy = -1 * buff_WindArmor.ApplyAmount;
			result = result + curAdditionalAccuracy;
			table.insert(info, { Type = buff_WindArmor.name, Value = curAdditionalAccuracy, ValueType = 'Buff'});
		end
	end	
	
	-- 셧 다운
	local buff_Shotdown = GetBuff(Defender, 'Shotdown');
	if buff_Shotdown then
		local curAdditionalAccuracy = 100;
		result = result + curAdditionalAccuracy;
		table.insert(info, { Type = buff_Shotdown.name, Value = curAdditionalAccuracy, ValueType = 'Buff'});
	end	
	
	-- 특성 사냥개	시야 내에서 가장 잃은 체력이 많은 녀석에게 명중률 적용.
	local mastery_HuntingDog = GetMasteryMastered(masteryTable_Attacker, 'HuntingDog');
	if mastery_HuntingDog then
		local targetList = GetTargetInRangeSightReposition(SafeIndex(Ability, 'AbilityWithMove'), Attacker, 'Sight', 'Enemy', true);
		local list = {};
		for index, target in ipairs (targetList) do
			if target.HP < target.MaxHP then
				table.insert(list, target);
			end
		end
		if #list > 0 then
			table.sort(list, function (a, b)
				return ( a.MaxHP - a.HP ) > ( b.MaxHP - b.HP );
			end);
			if list[1] == Defender then
				local curAdditionalAccuracy = mastery_HuntingDog.ApplyAmount;
				result = result + curAdditionalAccuracy;
				table.insert(info, { Type = mastery_HuntingDog.name, Value = curAdditionalAccuracy, ValueType = 'Mastery'});
			end
		end
	end
	-- 특성 포식자의 눈, 내 체력보다 체력이 낮은 녀석에게 명중률 적용.
	if Attacker.HP > Defender.HP then
		local mastery_PredatorEye = GetMasteryMastered(masteryTable_Attacker, 'PredatorEye');
		if mastery_PredatorEye then
			local curAdditionalAccuracy = mastery_PredatorEye.ApplyAmount;
			result = result + curAdditionalAccuracy;	
			table.insert(info, { Type = mastery_PredatorEye.name, Value = curAdditionalAccuracy, ValueType = 'Mastery'});
		end
	end
	-- 특성 피냄새	출혈 상태의 적에게 명중률 적용.
	if HasBuffType(Defender, nil, nil, 'Bleeding') then
		local mastery_BloodScent = GetMasteryMastered(masteryTable_Attacker, 'BloodScent');
		if mastery_BloodScent then
			local curAdditionalAccuracy = mastery_BloodScent.ApplyAmount;
			result = result + curAdditionalAccuracy;
			table.insert(info, { Type = mastery_BloodScent.name, Value = curAdditionalAccuracy, ValueType = 'Mastery'});
		end
	end
	-- 특성 인과율.
	local mastery_PrincipleOfCausality = GetMasteryMastered(masteryTable_Attacker, 'PrincipleOfCausality');
	if mastery_PrincipleOfCausality and IsGetAbilitySubType(Ability, 'ESP') and Ability.Type == 'Attack' then
		local curAdditionalAccuracy = Attacker.Cost * mastery_PrincipleOfCausality.ApplyAmount;
		result = result + curAdditionalAccuracy;
		table.insert(info, { Type = mastery_PrincipleOfCausality.name, Value = curAdditionalAccuracy, ValueType = 'Mastery'});
	end
	-- 특성 사술.
	local mastery_Witchcraft = GetMasteryMastered(masteryTable_Attacker, 'Witchcraft');
	if mastery_Witchcraft and IsGetAbilitySubType(Ability, 'ESP') and Ability.Type == 'Attack' then
		local curAdditionalAccuracy = -1 * Attacker.Cost * mastery_Witchcraft.ApplyAmount2;
		result = result + curAdditionalAccuracy;
		table.insert(info, { Type = mastery_Witchcraft.name, Value = curAdditionalAccuracy, ValueType = 'Mastery'});
	end
	-- 특성 동일한 표적
	if Ability.Type == 'Attack' then	
		local mastery_SameTarget = GetMasteryMastered(masteryTable_Attacker, 'SameTarget');
		if mastery_SameTarget then
			local targetKey = GetObjKey(Defender);
			local prevTargets = GetInstantProperty(Attacker, 'SameTarget') or {};
			if prevTargets[targetKey] then
				local curAdditionalAccuracy = mastery_SameTarget.ApplyAmount;
				result = result + curAdditionalAccuracy;
				table.insert(info, { Type = mastery_SameTarget.name, Value = curAdditionalAccuracy, ValueType = 'Mastery'});
			end
		end
	end
	-- 특성 전술적 보완, 전황 정보 분석, 전술적 집중
	if Ability.Type == 'Attack' then	
		for _, testMasteryType in ipairs({'TacticalSupplementation', 'Module_TacticalSupplementation', 'TacticalConcentration'}) do
			result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, testMasteryType, info, function(mastery)
				local targetKey = GetObjKey(Defender);
				local prevTargets = GetInstantProperty(Attacker, mastery.name) or {};
				if prevTargets[targetKey] then
					return mastery.ApplyAmount;
				end
			end);
		end
	end
	-- 특성 마검
	if IsGetAbilitySubType(Ability, 'Physical') then
		local mastery_MagicalSword = GetMasteryMastered(masteryTable_Attacker, 'MagicalSword');
		if mastery_MagicalSword then
			local curAdditionalAccuracy = Attacker.ESPPower * mastery_MagicalSword.ApplyAmount / 100;
			result = result + curAdditionalAccuracy;
			table.insert(info, MakeMasteryStatInfo(mastery_MagicalSword.name, curAdditionalAccuracy));
		end
	end
	-- 특성 보이지 않는 검
	if Ability.Type == 'Attack' and Ability.HitRateType == 'Melee' then	
		local mastery_InvisibleSword = GetMasteryMastered(masteryTable_Attacker, 'InvisibleSword');
		if mastery_InvisibleSword then
			local targetKey = GetObjKey(Defender);
			local prevTargets = GetInstantProperty(Attacker, 'InvisibleSword') or {};
			if not prevTargets[targetKey] then
				local curAdditionalAccuracy = mastery_InvisibleSword.ApplyAmount;
				result = result + curAdditionalAccuracy;
				table.insert(info, { Type = mastery_InvisibleSword.name, Value = curAdditionalAccuracy, ValueType = 'Mastery'});
			end
		end
	end
	-- 정밀한 저격
	if Ability.AbilitySubMenu == 'DetailedSnipe' then
		local snipeTypeList = GetClassList('SnipeType');
		local snipeTypeName = SafeIndex(abilityDetailInfo, 'SnipeType') or 'Head';
		local snipeType = SafeIndex(snipeTypeList, snipeTypeName);
		
		local applyRatio = 100;
		local mastery_Infallibility = GetMasteryMastered(masteryTable_Attacker, 'Infallibility');
		if mastery_Infallibility then
			applyRatio = applyRatio + mastery_Infallibility.ApplyAmount;
		end
		if snipeType and snipeType.Accuracy ~= 0 then
			local accuracyAdd = snipeType.Accuracy * applyRatio / 100;
			result = result + accuracyAdd;
			table.insert(info, {Type = 'DetailedSnipe', Value = accuracyAdd, ValueType = 'Formula', SnipeType = snipeType.name});
		end
	end
	-- 돌연변이의 눈
	if Attacker.HP < Defender.HP then
		local mastery_MutationEye = GetMasteryMastered(masteryTable_Attacker, 'MutationEye');
		if mastery_MutationEye then
			result = result + mastery_MutationEye.ApplyAmount;
			table.insert(info, MakeMasteryStatInfo(mastery_MutationEye.name, mastery_MutationEye.ApplyAmount));
		end
	end
	-- 숨결주머니
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'BreathSac', info, function(mastery)
		if Ability.Type == 'Attack' and Ability.HitRateType == 'Force' then
			return math.floor(mastery.CustomCacheData['Beast'] / mastery.ApplyAmount) * mastery.ApplyAmount2;
		end
	end);
	-- 보석 세공기
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'Amulet_JewelCollector_Set', info, function(mastery)
		if Ability.Type == 'Attack' and IsGetAbilitySubType(Ability, 'ESP') then
			return mastery.ApplyAmount;
		end
	end);
	-- 버프 정보 공유
	result = result + GetBuffValueByCustomFuncWithInfo(Attacker, 'InformationSharing', info, function(buff)
		local targetKey = GetObjKey(Defender);
		local prevTargets = GetInstantProperty(Attacker, buff.name) or {};
		if Ability.Type == 'Attack' and prevTargets[targetKey] then
			return buff.ApplyAmount;
		end
	end);
	-- 반응 사격 제어 프로그램
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'Module_WeaponAimResponsiveFire', info, function(mastery)
		if Ability.Type == 'Attack' and SafeIndex(damageFlag, 'ReactionAbility') then
			return mastery.ApplyAmount;
		end
	end);
	-- 질투의 눈
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'JealousEye', info, function(mastery)
		if Ability.Type == 'Attack' then
			local buffList = GetBuffType(Defender, 'Buff');
			return math.floor(#buffList / mastery.ApplyAmount) * mastery.ApplyAmount2;
		end
	end);
	-- 능숙한 도살자
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'ExpertButchery', info, function(mastery)
		if Ability.Type == 'Attack' and (Defender.Race.name == 'Human' or Defender.Race.name == 'Beast') then
			return mastery.ApplyAmount;
		end
	end);
	-- 유효 사격
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'EffectiveFire', info, function(mastery)
		if Ability.Type == 'Attack' and IsGetAbilitySubType(Ability, 'Piercing') and Ability.HitRateType == 'Force' and IsUnprotectedExposureState(Defender) then
			return mastery.ApplyAmount;
		end
	end);
	-- 무모함
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'Recklessness', info, function(mastery)
		if Ability.Type == 'Attack' and HasBuffType(Attacker, nil, nil, mastery.BuffGroup.name) then
			return mastery.ApplyAmount;
		end
	end);
		
	-- 사냥감 확인
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'ConfirmTarget', info, function(mastery)
		local summonBeastKey = GetInstantProperty(Attacker, 'SummonBeastKey');
		local summonBeast;
		if IsMissionServer() then
			summonBeast = GetUnit(Attacker, summonBeastKey);
		elseif IsClient() then
			summonBeast = GetUnit(summonBeastKey);
		end
		if summonBeast == nil then
			return;
		end
		if Ability.Type == 'Attack' and IsInSight(summonBeast, GetPosition(Defender), true) then
			return mastery.ApplyAmount;
		end
	end);
	
	-- 방어자 특성.
	-- 특성 사각 지대. 거리 1타일당 명중률 2% 감소.
	local mastery_ShadowZone = GetMasteryMastered(masteryTable_Defender, 'ShadowZone');
	if mastery_ShadowZone then
		local distance = GetDistanceFromObjectToObjectAbility(Ability, Attacker, Defender);
		local curAdditionalAccuracy = -1 * math.floor(distance) * mastery_ShadowZone.ApplyAmount;
		result = result + curAdditionalAccuracy;
		table.insert(info, { Type = mastery_ShadowZone.name, Value = curAdditionalAccuracy, ValueType = 'Mastery'});
	end
	-- 어둠 속의 그림자
	local mastery_ShadowInDark = GetMasteryMastered(masteryTable_Defender, 'ShadowInDark');
	if mastery_ShadowInDark then
		local distance = GetDistanceFromObjectToObjectAbility(Ability, Attacker, Defender);
		local curAdditionalAccuracy = -1 * math.floor(distance) * mastery_ShadowInDark.ApplyAmount;
		result = result + curAdditionalAccuracy;
		table.insert(info, { Type = mastery_ShadowInDark.name, Value = curAdditionalAccuracy, ValueType = 'Mastery'});
	end
	-- 왕의 눈
	local mastery_KingEye = GetMasteryMastered(masteryTable_Attacker, 'KingEye');
	if mastery_KingEye and Attacker.Grade.Weight > Defender.Grade.Weight then
		result = result + mastery_KingEye.ApplyAmount;
		table.insert(info, MakeMasteryStatInfo(mastery_KingEye.name, mastery_KingEye.ApplyAmount));
	end
	return result;
end
---------------------------------------------------------------------
-- 거리에 따른 명중률 패널티
---------------------------------------------------------------------
function GetHitRateByDistance(info, Attacker, hitRateType, distance, masteryTable_Attacker, masteryTable_Defender)
	local penaltyHitRate = 0;
	
	-- 턴 시작 시
	if not Attacker.TurnState.Moved and not Attacker.TurnState.UsedMainAbility and not Attacker.TurnState.TurnEnded then
		-- 수풀 속의 포식자.
		local mastery_AmbushingPredator = GetMasteryMastered(masteryTable_Attacker, 'AmbushingPredator');
		if mastery_AmbushingPredator and GetBuff(Attacker, mastery_AmbushingPredator.Buff.name) then
			return 0;
		end
		-- 그물 속의 포식자
		local mastery_AmbushingSpider = GetMasteryMastered(masteryTable_Attacker, 'AmbushingSpider');
		if mastery_AmbushingSpider and GetBuff(Attacker, mastery_AmbushingSpider.Buff.name) then
			return 0;
		end
		-- 수면 위의 포식자
		local mastery_AmbushingNeguri = GetMasteryMastered(masteryTable_Attacker, 'AmbushingNeguri');
		if mastery_AmbushingNeguri and ( GetBuff(Attacker, mastery_AmbushingNeguri.Buff.name) or GetBuff(Attacker, mastery_AmbushingNeguri.SubBuff.name)) then
			return 0;
		end
		-- 안개 속의 포식자
		local mastery_IntheSmokePredator = GetMasteryMastered(masteryTable_Attacker, 'IntheSmokePredator');
		if mastery_IntheSmokePredator and HasBuff(Attacker, mastery_IntheSmokePredator.Buff.name) then
			return 0;
		end
	end
	
	-- 거리에 따른 명중률 패널티
	-- 공격 형태에 따른 패널티 비율.
	local penaltyRatio = 1;
	local abilityHitRateTypeList = GetClassList('AbilityHitRateType');
	local curhitRateType = SafeIndex(abilityHitRateTypeList, hitRateType);
	if curhitRateType then
		penaltyRatio = curhitRateType.DistancePenalty/100;
	end
	-- 거리 기본 패널티.
	local forcePenalty = 0;
	if distance < 10 then
		forcePenalty = math.min(0, 2 + -1 * distance);
	else
		forcePenalty = -2.5 * distance + 15;
	end
	penaltyHitRate = forcePenalty * penaltyRatio;
	
	local mastery_RiflingEnhancement = GetMasteryMastered(masteryTable_Attacker, 'RiflingEnhancement');
	if mastery_RiflingEnhancement then
		local addRate = math.floor(- penaltyHitRate * mastery_RiflingEnhancement.ApplyAmount ) / 100;
		penaltyHitRate = penaltyHitRate + addRate;
		table.insert(info, MakeMasteryStatInfo(mastery_RiflingEnhancement.name, addRate));
	end
	
	penaltyHitRate = math.floor( penaltyHitRate * 100 ) / 100;
	if penaltyHitRate ~= 0 then
		table.insert(info, { Type = 'Distance', Value = penaltyHitRate, ValueType = 'Formula'});
	end
	return penaltyHitRate;
end
---------------------------------------------------------------------
-- 높이에 따른 명중률 패널티
---------------------------------------------------------------------
local highHeightAmount = nil;
function IsAttakerHighPosition(height, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender)
	if highHeightAmount == nil then
		highHeightAmount = GetSystemConstant('HighHeight');
	end
	if masteryTable_Attacker == nil then
		masteryTable_Attacker = GetMastery(Attacker);
	end
	if masteryTable_Defender == nil then
		masteryTable_Defender = GetMastery(Defender);
	end
	local mastery_Flight_Attacker = GetMasteryMastered(masteryTable_Attacker, 'Flight') or HasBuff(Attacker, 'ClimbWeb');
	local mastery_Flight_Defender = GetMasteryMastered(masteryTable_Defender, 'Flight') or HasBuff(Defender, 'ClimbWeb');
	local attackerHigh = false;
	local attackerLow = false;
	if not mastery_Flight_Attacker and not mastery_Flight_Defender then
		attackerHigh = height > highHeightAmount;
		attackerLow = height < -highHeightAmount;
	elseif mastery_Flight_Attacker then
		attackerHigh = true;
	else
		attackerLow = true;
	end
	return attackerHigh, attackerLow;
end
function GetPenaltyHitRateByHeight(info, Attacker, Defender, hitRateType, height, masteryTable_Attacker, masteryTable_Defender)
	local penaltyHitRate = 0;
	local additionalHitRate = 0;
	
	local attackerHigh, attackerLow = IsAttakerHighPosition(height, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender);
	if attackerHigh then
		if hitRateType == 'Force' then
			local penaltyHitRateBase = 20;
			penaltyHitRate = penaltyHitRateBase;
			local mastery_PositionOfAdvantage = GetMasteryMastered(masteryTable_Attacker, 'PositionOfAdvantage');
			if mastery_PositionOfAdvantage then 
				penaltyHitRate = penaltyHitRate + mastery_PositionOfAdvantage.ApplyAmount;
			end
			-- 호환성 증가 - 높은 위치
			local mastery_MachineUnique_HighPosition = GetMasteryMastered(masteryTable_Attacker, 'MachineUnique_HighPosition');
			if mastery_MachineUnique_HighPosition then 
				penaltyHitRate = penaltyHitRate + penaltyHitRateBase * (mastery_MachineUnique_HighPosition.ApplyAmount / 100);
			end
		end
		local mastery_OntheSkyPredator = GetMasteryMastered(masteryTable_Attacker, 'OntheSkyPredator');
		if mastery_OntheSkyPredator then
			additionalHitRate = additionalHitRate + mastery_OntheSkyPredator.ApplyAmount;
			table.insert(info, MakeMasteryStatInfo(mastery_OntheSkyPredator.name, mastery_OntheSkyPredator.ApplyAmount));
		end	
	elseif attackerLow then
		if hitRateType == 'Force' then
			penaltyHitRate = -10;
		end
	end
	if hitRateType == 'Melee' and mastery_Flight_Defender then
		additionalHitRate = additionalHitRate - mastery_Flight_Defender.ApplyAmount;
		table.insert(info, MakeMasteryStatInfo(mastery_Flight_Defender.name, -mastery_Flight_Defender.ApplyAmount));
	end
	if penaltyHitRate > 0 then
		table.insert(info, { Type = 'Height', Value = penaltyHitRate, ValueType = 'Formula'});
	elseif penaltyHitRate < 0 then
		table.insert(info, { Type = 'Height2', Value = penaltyHitRate, ValueType = 'Formula'});
	end
	return penaltyHitRate + additionalHitRate;
end
----------------------------------------------------------------------
--- 나와 적 사이의 엄폐 상태에 따라 패널티 적용
---------------------------------------------------------------------
function GetHitRateByCoverState(info, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, hitRateType, abilityWithMove)
	local myPosition = GetPosition(Attacker);
	if IsClient() and abilityWithMove then
		myPosition = GetSession().current_using_pos;
	end
	local coverState = GetCoverState(Defender, myPosition, Attacker);	
	local hitRate = 0;
	local addCoverValue = 0;
	local addConcealValue = 0;
	
	-- 엄폐에 따른 명중률 패널티.
	if Defender.Coverable then
		if coverState == 'Half' then
			addCoverValue = -20;
		elseif coverState == 'Full' then
			addCoverValue = -40;
		end
	end
	-- 공격 형태에 따른 엄폐 적용
	local abilityHitRateTypeList = GetClassList('AbilityHitRateType');
	local curhitRateType = SafeIndex(abilityHitRateTypeList, hitRateType);
	if curhitRateType then
		addCoverValue = addCoverValue * curhitRateType.CoverRatio/100;
	end
	
	if addCoverValue ~= 0 then
		table.insert(info, { Type = 'CoverState_'..coverState, Value = addCoverValue, ValueType = 'Formula'});
		-- 잠복 적용.
		local buff_Conceal = GetBuff(Defender, 'Conceal') or GetBuff(Defender, 'Conceal_For_Aura');
		if buff_Conceal then			
			addConcealValue = -10;
			table.insert(info, { Type = buff_Conceal.name, Value = addConcealValue, ValueType = 'Buff'});
		end
		
		local mastery_MoveWithCover = GetMasteryMastered(masteryTable_Defender, 'MoveWithCover');
		if mastery_MoveWithCover then
			local newCoverValue = addCoverValue * mastery_MoveWithCover.ApplyAmount / 100;
			addCoverValue = addCoverValue + newCoverValue;
			table.insert(info, MakeMasteryStatInfo(mastery_MoveWithCover.name, newCoverValue));
		end
	end
	
	if hitRateType == 'Throw' and coverState ~= 'None' then
		local mastery_ParabolicOrbit = GetMasteryMastered(masteryTable_Attacker, 'ParabolicOrbit');
		if mastery_ParabolicOrbit then
			local newCoverValue = mastery_ParabolicOrbit.ApplyAmount;
			addCoverValue = addCoverValue + newCoverValue;
			table.insert(info, MakeMasteryStatInfo(mastery_ParabolicOrbit.name, newCoverValue));
		end
	end
	
	hitRate = addCoverValue + addConcealValue;
	return hitRate;
end
----------------------------------------------------------------------
--- 명중률 보정 : 주위 반경.
---------------------------------------------------------------------
function GetModifyAbilityAccuracyFromEvent_Range_Attacker(info, Ability, Attacker, masteryTable_Attacker)
	local cache = SafeIndex(GetInstantProperty(Attacker, 'ModifyAbilityAccuracyFromEvent_Range_Attacker_Cache'), Ability.name);
	if cache then
		table.append(info, cache.Info);
		return cache.Result;
	end
	local calcOption = {};
	calcOption.UsePrevAbilityPosition = SafeIndex(Ability, 'AbilityWithMove');
	calcOption.MasteryTable = masteryTable_Attacker;
	local newInfo = {};
	-- 주위 반경에 대한 공격자 조건
	local result = GetConditionalStatus(Attacker, 'Accuracy_RangeAttacker', newInfo, calcOption);
	
	local saveCache = GetInstantProperty(Attacker, 'ModifyAbilityAccuracyFromEvent_Range_Attacker_Cache') or {};
	saveCache[Ability.name] = {Info = newInfo, Result = result};
	SetInstantProperty(Attacker, 'ModifyAbilityAccuracyFromEvent_Range_Attacker_Cache', saveCache);
	table.append(info, newInfo);
	return result;
end
-----------------------------------------------------------------------------------------------
-------------------------------------- 피해량 계산 공식 ----------------------------------------
------------------------------------------------------------------------------------------------
function IsUnprotectedExposureState(obj, testPosition)
	-- 예민한 감각, 드라키의 완벽한 비늘
	if GetMasteryMasteredList(GetMastery(obj), {'AcuteSense', 'Amulet_Draky_Scale3'}) then
		return false;
	end
	if not obj.Coverable then
		return true;
	end	
	testPosition = testPosition or GetPosition(obj);
	if IsMissionServer() then
		return not IsCoveredPosition(GetMission(obj), testPosition);
	elseif IsClient() then
		return not IsCoveredPosition(testPosition);
	else
		return false;
	end
end
function CalculateAbilityMinDamage(Ability, Phase, Attacker, Defender)
	local minDamage = Ability.Type == 'Attack' and 1 or 0;
	if Ability.DirectingScript and Ability.DirectingScript ~= '' then
		return minDamage;
	end

	local hitRatios = CalculateAbilityHitRatio(Ability.name, Phase, Attacker, Defender);
	return math.max(#hitRatios, minDamage);
end
DamageComposer = nil;
function GetDamageCalculator(Attacker, Defender, Ability, weather, temperature, usingPos, chainIndex, aiFlag, additionalDamage, abilityDetailInfo, perfChecker, damageFlag)
	if perfChecker == nil then
		perfChecker = MockPerfChecker;
	end
	local masteryTable_Attacker = GetMastery(Attacker);
	local masteryTable_Defender = GetMastery(Defender);
	
	local calcOption = {MissionWeather = weather,
						MissionTemperature = temperature};

	local originalInfo = {};
	-- C1. 공격자, 어빌리티로 산출할 수 있는 피해량을 계산한다.
	-- 1) 어빌리티와 공격자의 능력치로만 산출된 순수한 어빌리티 피해량.
	if DamageComposer == nil then
		DamageComposer = BattleFormulaComposer.new('((OriginalDamage * SplashRatio * (1 + (OriginalMultiplier - OriginalDemultiplier) / 100)) + AdditionalDamage) * (1 + FinalMultiplier / 100) * (1 - Defence)', {'OriginalDamage', 'SplashRatio', 'OriginalMultiplier', 'OriginalDemultiplier', 'AdditionalDamage', 'FinalMultiplier', 'Defence'});
	end
	perfChecker:StartRoutine('CloneComposer');
	local damageComposer = DamageComposer:Clone();
	perfChecker:StartRoutine('BasicDamage');
	if aiFlag ~= 'PositionRelative' then
		damageComposer:AddDecompData('OriginalDamage', GetCurrentAbilityDamage(originalInfo, Ability, Attacker, Defender), originalInfo);
		
		if usingPos and Defender then
			-- 0) 기본 스플레시 데미지 계산
			local distance = GetDistance3D(usingPos, GetPosition(Defender));
			damageComposer:AddDecompData('SplashRatio', Ability:SplashMethod(distance, chainIndex), {});
		else
			damageComposer:AddDecompData('SplashRatio', 1);
		end
	end
	perfChecker:EndRoutine();
	if Ability.DamageType ~= 'Explosion' then
		if aiFlag ~= 'PositionRelative' then
			-- 2) Status로 얻어지는 피해량 증감 / Multiplier 라 피해 계산해줘야함.
			local info_Multiplier = {};
			perfChecker:StartRoutine('GetModifyAbilityDamageFromStatus');
			damageComposer:AddDecompData('OriginalMultiplier', GetModifyAbilityDamageFromStatus(info_Multiplier, Ability, Attacker, calcOption), info_Multiplier);
			
			-- 3) 방어자의 Status로 얻어지는 피해량 경감
			local info_Demultiplier = {};
			perfChecker:StartRoutine('GetDecreaseAbilityDamageFromStatus');
			damageComposer:AddDecompData('OriginalDemultiplier', GetDecreaseAbilityDamageFromStatus(info_Demultiplier, Ability, Defender, calcOption), info_Demultiplier);
			perfChecker:EndRoutine();
		end

		-- 4) 공격자, 방어자의 상황에 따라 발생하는 이벤트
		local info_event = {};
		local info_eventMulti = {};
		perfChecker:StartRoutine('GetModifyAbilityDamageFromEvent');
		local eventMultiplier, eventAdd = GetModifyAbilityDamageFromEvent(info_event, info_eventMulti, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, weather, temperature, usingPos, aiFlag, perfChecker, damageFlag);
		damageComposer:AddDecompData('OriginalMultiplier', eventMultiplier, info_eventMulti);
		damageComposer:AddDecompData('AdditionalDamage', eventAdd, info_event);
		
		-- 5) 외부 요소로 증가하는 피해량
		if additionalDamage ~= nil then
			damageComposer:AddDecompData('AdditionalDamage', additionalDamage, {});
		end
		perfChecker:EndRoutine();
	end
	
	if Ability.Type == 'Heal' then
		if Ability.RestoreMaxHP then
			return Defender.MaxHP, {}, DamageComposer:Clone();
		end
		-- Heal 공식에서 OriginalMultiplier에 묶여서 곱해지지 않고, 따로 곱셈으로 적용되어야 하는 처리
		if aiFlag ~= 'PositionRelative' then
			local info_final = {};
			local finalMultiplier = GetModifyAbilityDamageFromEvent_Normal_Heal_Final(info_final, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender);
			if finalMultiplier ~= 0 or not table.empty(info_final) then
				damageComposer:AddDecompData('FinalMultiplier', finalMultiplier, info_final);
			end
		end
		local totalDamage = damageComposer:ComposeFormula();
		local info = damageComposer:ComposeInfoTable();
		-- 피해량 정보 정렬.
		if #info > 0 then
			table.sort(info, function (a, b)
				return a.Value > b.Value;
			end);
		end
		local infoValue = 0;
		for index, value in ipairs (info) do
			infoValue = infoValue + value.Value;
		end
		local basicValue = totalDamage - infoValue;
		if basicValue ~= 0 then
			table.insert(info, 1, { Type = 'Heal', Value = basicValue, ValueType = 'Formula'});
		end
		return totalDamage, info, damageComposer;		
	end
	
	-- C2. 피격 대상이 존재할 경우, 해당 대상과의 영향력을 고려한 부분의 계산
	if Defender ~= nil and aiFlag ~= 'PositionRelative' then
		local demultiplier = 0;
		local demultiInfo = {};
		-- 1) 방어/저항 에의한 감소된 피해량
		perfChecker:StartRoutine('GetDefenceRatio');
		local defenceRatio = GetDefenceRatio(Attacker, Defender, Ability, masteryTable_Attacker, masteryTable_Defender, perfChecker);
		if defenceRatio > 0 then
			damageComposer:AddDecompData('Defence', defenceRatio, {{ Type = 'Defence', Value = defenceRatio, ValueType = 'Formula'}});
		end
		perfChecker:StartRoutine('Troublemaker');
		if Ability.DamageType ~= 'Explosion' then		
			-- 2) 트러블메이커 정보에 의해 감소된 피해량
			local defenceAmount_Troublemaker = GetDefenceRatio_Troublemaker(Attacker, Defender);
			if defenceAmount_Troublemaker > 0 then
				demultiplier = demultiplier + defenceAmount_Troublemaker;
				table.insert(demultiInfo, { Type = 'TMGrade', Value = defenceAmount_Troublemaker, ValueType = 'Formula' });
			end
		end
		
		perfChecker:StartRoutine('Etc');
		-- 노림수
		local mastery_Aiming = GetMasteryMastered(masteryTable_Attacker, 'Aming');
		if mastery_Aiming and IsUnprotectedExposureState(Defender) then
			damageComposer:AddDecompData('OriginalMultiplier', mastery_Aiming.ApplyAmount, {MakeMasteryStatInfo(mastery_Aiming.name, mastery_Aiming.ApplyAmount)});
		end
		
		if Ability.Type == 'Attack' then
			-- 특성 철의 요새
			local buff_FortressOfIronForAura = GetBuff(Defender, 'FortressOfIron_For_Aura');
			if buff_FortressOfIronForAura then
				local defenceAmount = buff_FortressOfIronForAura.ApplyAmount;
				demultiplier = demultiplier + defenceAmount;
				table.insert(demultiInfo, {Type = buff_FortressOfIronForAura.name, Value = defenceAmount, ValueType = 'Buff'});
			end
			-- 움직이는 성
			local buff_MovingCastleForAura = GetBuff(Defender, 'MovingCastle_For_Aura');
			if buff_MovingCastleForAura then
				local defenceAmount = buff_MovingCastleForAura.ApplyAmount;
				demultiplier = demultiplier + defenceAmount;
				table.insert(demultiInfo, {Type = buff_MovingCastleForAura.name, Value = defenceAmount, ValueType = 'Buff'});
			end
			-- 반복 훈련
			local mastery_RepetitiveTraining = GetMasteryMastered(masteryTable_Defender, 'RepetitiveTraining');
			if mastery_RepetitiveTraining then
				local mastery_FigterBook = GetMasteryMastered(masteryTable_Defender, 'FigterBook');
				if mastery_FigterBook then	-- 사실 없을 수 없음..
					local defenceAmount = mastery_FigterBook.CustomCacheData * mastery_RepetitiveTraining.ApplyAmount2;
					demultiplier = demultiplier + defenceAmount;
					table.insert(demultiInfo, MakeMasteryStatInfo(mastery_RepetitiveTraining.name, defenceAmount));
				end
			end
			-- 하중 제어
			local mastery_Application_MaximumLoadControl = GetMasteryMastered(masteryTable_Defender, 'Application_MaximumLoadControl');
			if mastery_Application_MaximumLoadControl then
				local defenceAmount = mastery_Application_MaximumLoadControl.ApplyAmount2 * math.floor(Defender.Load / mastery_Application_MaximumLoadControl.ApplyAmount);
				demultiplier = demultiplier + defenceAmount;
				table.insert(demultiInfo, MakeMasteryStatInfo(mastery_Application_MaximumLoadControl.name, defenceAmount));
			end
			-- 기계공학도
			if Attacker.Race.name == 'Machine' then
				local mastery_BaseOfMechanicalEngineering = GetMasteryMastered(masteryTable_Defender, 'BaseOfMechanicalEngineering') or GetMasteryMastered(masteryTable_Defender, 'BaseOfMechanicalEngineering_Machine');
				if mastery_BaseOfMechanicalEngineering then
					local minusAmount = mastery_BaseOfMechanicalEngineering.ApplyAmount;
					demultiplier = demultiplier + minusAmount;
					table.insert(demultiInfo, MakeMasteryStatInfo(mastery_BaseOfMechanicalEngineering.name, minusAmount));
				end
			end
			-- 장갑 호환성 - 강화
			if Defender.Info.name == 'Drone_Enhanced' then
				local mastery_ArmorDeviceList = { 'ArmorDevice_CarbonArmor_Epic', 'ArmorDevice_TitianArmor_MagicOuterArmor_Epic', 'ArmorDevice_BlackIronArmor_Epic' };
				for _, value in pairs (mastery_ArmorDeviceList) do
					local mastery_ArmorDevice = GetMasteryMastered(masteryTable_Defender, value);
					if mastery_ArmorDevice then
						local minusValue = mastery_ArmorDevice.ApplyAmount;
						demultiplier = demultiplier + minusValue;
						table.insert(demultiInfo, MakeMasteryStatInfo(mastery_ArmorDevice.name, minusValue));
					end
				end
			end
			
			-- 촘촘한 비늘
			local mastery_DenseScale = GetMasteryMastered(masteryTable_Defender, 'DenseScale');
			if mastery_DenseScale then
				if IsGetAbilitySubType(Ability, GetInstantProperty(Defender, 'DenseScale_LastDamageType')) then
					local minusValue = mastery_DenseScale.ApplyAmount;
					-- 반짝이는 비늘
					local mastery_ShiningScale = GetMasteryMastered(masteryTable_Defender, 'ShiningScale');
					if mastery_ShiningScale then
						minusValue = minusValue + mastery_ShiningScale.ApplyAmount;
					end
					demultiplier = demultiplier + minusValue;
					table.insert(demultiInfo, MakeMasteryStatInfo(mastery_DenseScale.name, minusValue));
				end
			end
			-- 익숙한 고통
			local mastery_FamiliarSuffering = GetMasteryMastered(masteryTable_Defender, 'FamiliarSuffering');
			if mastery_FamiliarSuffering then
				if IsGetAbilitySubType(Ability, GetInstantProperty(Defender, 'FamiliarSuffering_LastDamageType')) then
					local minusValue = mastery_FamiliarSuffering.ApplyAmount;
					demultiplier = demultiplier + minusValue;
					table.insert(demultiInfo, MakeMasteryStatInfo(mastery_FamiliarSuffering.name, minusValue));
				end
			end
			
			damageComposer:AddDecompData('OriginalDemultiplier', demultiplier, demultiInfo);
		end
		-- 덫 사용자 특성 (DamageType이 Explosion이어도 적용되어야 함)
		if Attacker.name == 'Utility_TrapInstance' and GetExpTaker(Attacker) ~= nil then
			local trapHost = GetExpTaker(Attacker);
			local masteryTable = GetMastery(trapHost);
			-- 강력한 덫
			local mastery_PowerfulTrap = GetMasteryMastered(masteryTable, 'PowerfulTrap');
			if mastery_PowerfulTrap then
				-- 화염 계열
				if Ability.name == 'FireTrapActivate' and HasBuffType(Defender, 'Debuff', nil, mastery_PowerfulTrap.BuffGroup.name) then
					local multiplier_PowerfulTrap = mastery_PowerfulTrap.ApplyAmount;
					damageComposer:AddDecompData('OriginalMultiplier', multiplier_PowerfulTrap, {MakeMasteryStatInfo(mastery_PowerfulTrap.name, multiplier_PowerfulTrap)});
				end
			end
			-- 연계된 함정
			local mastery_ChainTrap = GetMasteryMastered(masteryTable, 'ChainTrap');
			if mastery_ChainTrap then
				local multiplier_ChainTrap = mastery_ChainTrap.ApplyAmount;
				damageComposer:AddDecompData('OriginalMultiplier', multiplier_ChainTrap, {MakeMasteryStatInfo(mastery_ChainTrap.name, multiplier_ChainTrap)});
			end
		end
	end
	perfChecker:StartRoutine('NonStatic');
	if Defender ~= nil and aiFlag ~= 'Static' then
		local demultiplier = 0;
		local demultiInfo = {};
		local distance = GetDistanceFromObjectToObjectAbility(Ability, Attacker, Defender);
		
		-- 특성 나는 아직 끝나지 않았다.
		local mastery_ImNotDoneYet = GetMasteryMastered(masteryTable_Defender, 'ImNotDoneYet');
		if mastery_ImNotDoneYet and GetCoverState(Defender, GetAbilityUsingPosition(Attacker), Attacker) ~= 'None' and Ability.HitRateType == 'Force' then
			damageComposer:AddDecompData('OriginalDemultiplier', mastery_ImNotDoneYet.ApplyAmount, {MakeMasteryStatInfo(mastery_ImNotDoneYet.name, mastery_ImNotDoneYet.ApplyAmount)});
		end
		
		-- 특성 직격탄 (DamageType이 Explosion이어도 적용되어야 함)
		local mastery_DirectShot = GetMasteryMastered(masteryTable_Attacker, 'DirectShot');
		if mastery_DirectShot and Ability.Type == 'Attack' and Ability.HitRateType == 'Throw' and GetRelation(Attacker, Defender) == 'Enemy' then
			if IsUnprotectedExposureState(Defender) then
				if distance <= mastery_DirectShot.ApplyAmount + 0.4 then
					local multiplier_DirectShot = mastery_DirectShot.ApplyAmount2;
					damageComposer:AddDecompData('OriginalMultiplier', multiplier_DirectShot, {MakeMasteryStatInfo(mastery_DirectShot.name, multiplier_DirectShot)});
					if IsMissionServer() then
						SetInstantProperty(Defender, 'DirectShotApplied', true);
					end
				end
			end
		end
		
		-- 지연 처리 (방어 시)
		local mastery_DeferredProcessing = GetMasteryMastered(masteryTable_Defender, 'DeferredProcessing');
		if mastery_DeferredProcessing then
			local enableUseCount = 0;
			for _, ability in ipairs(GetEnableProtocolAbilityList(Defender, Ability)) do
				if ability.IsUseCount then
					enableUseCount = enableUseCount + ability.UseCount;
				end
			end
			local applyRatio = mastery_DeferredProcessing.ApplyAmount2;
			local mastery_InformationSpecialist = GetMasteryMastered(masteryTable_Defender, 'InformationSpecialist');
			if mastery_InformationSpecialist and distance <= mastery_InformationSpecialist.ApplyAmount2 + 0.4 then
				applyRatio = applyRatio * (1 + mastery_InformationSpecialist.ApplyAmount / 100);
			end
			
			local stepCount = math.floor(enableUseCount / mastery_DeferredProcessing.ApplyAmount);				-- ApplyAmount 당
			if stepCount > 0 then
				local multiplier_DeferredProcessing = math.floor(stepCount * applyRatio);	-- ApplyAmount2 만큼 증가
				
				demultiplier = demultiplier + multiplier_DeferredProcessing;
				table.insert(demultiInfo, MakeMasteryStatInfo(mastery_DeferredProcessing.name, multiplier_DeferredProcessing));
			end
		end
		damageComposer:AddDecompData('OriginalDemultiplier', demultiplier, demultiInfo);
	end
	perfChecker:StartRoutine('ComposeFormula');
	local totalDamage = damageComposer:ComposeFormula();
	local info;
	if aiFlag == nil then
		perfChecker:StartRoutine('DataSortingAndArrange');
		-- C6. 최소 피해량: hitCount
		if Defender ~= nil then
			local minDamage = CalculateAbilityMinDamage(Ability, 'Primary', Attacker, Defender);
			if totalDamage < minDamage then
				totalDamage = minDamage;
			end
		end	
		info = damageComposer:ComposeInfoTable();
		-- 피해량 정보 정렬.
		if #info > 0 then
			table.sort(info, function (a, b)
				return a.Value > b.Value;
			end);
		end
		local infoValue = 0;
		for index, value in ipairs (info) do
			infoValue = infoValue + value.Value;
		end
		local basicValue = totalDamage - infoValue;
		if basicValue ~= 0 then
			table.insert(info, 1, { Type = 'Damage', Value = basicValue, ValueType = 'Formula'});
		end
	end
	perfChecker:EndRoutine();
	return totalDamage, info, damageComposer;
end
-------------------------------------------------------------------------------
-- 어빌리티의 기본 공격력
-----------------------------------------------------------------------------
function GetCurrentAbilityDamage(info, Ability, Attacker, Defender)
	-- 1. 어빌리티(캐릭터 능력치)에 의한 피해량.
	local result = Ability.ApplyAmount;
	if Ability.AdditionalApplyAmount then
		for key, value in pairs (Ability.AdditionalApplyAmount) do
			if key == 'EnemyHP' then
				result = result + math.floor(Defender.MaxHP * value / 100);
			elseif key == 'SP' then
				local addAmount = math.floor(GetCurrentSP(Attacker) * value/100);
				if addAmount ~= 0 then
					result = result + addAmount;
				end
			elseif key == 'Cost' then
				local addAmount = math.floor(GetCurrentCost(Attacker) * value/100);
				if addAmount ~= 0 then
					result = result + addAmount;
				end
			elseif Attacker[key] ~= nil then
				local addAmount = math.floor(Attacker[key] * value/100);
				if addAmount ~= 0 then
					result = result + addAmount;					
				end
			end
		end
	end	
	return result;
end	
-------------------------------------------------------------------------------
-- 어빌리티의 기본 Status로 얻어지는 Multiplier
-----------------------------------------------------------------------------
function GetModifyAbilityDamageFromStatus(info_Multiplier, Ability, Attacker, calcOption)	
	local multiplier = 0;
	local InfoAdder = function(stat)
		local newStat = Attacker[stat];
		if newStat and newStat ~= 0 then
			multiplier = multiplier + newStat;
			table.append(info_Multiplier, GetStatusInfo(Attacker, stat, nil, true));
		end
		multiplier = multiplier + GetConditionalStatus(Attacker, stat, info_Multiplier, calcOption);
	end
	if Ability.Type == 'Attack' then
		InfoAdder('IncreaseDamage');
		if Ability.SubType ~= 'None' then
			local superType = GetAbilitySuperType(Ability);
			if superType ~= nil then
				InfoAdder('IncreaseDamage_'..superType)
			end
			InfoAdder('IncreaseDamage_'..Ability.SubType);
		end
		if Ability.HitRateType ~= 'None' then
			InfoAdder('IncreaseDamage_'..Ability.HitRateType);
		end
	end
	return multiplier;
end
-------------------------------------------------------------------------------
-- 캐릭터 어빌리티 피해량 감소
-----------------------------------------------------------------------------
function GetDecreaseAbilityDamageFromStatus(info_Demultiplier, Ability, Defender, calcOption)
	if Defender == nil then
		return 0;
	end
	local demultiplier = 0;
	local InfoAdder = function(stat)
		local newStat = Defender[stat];
		if newStat and newStat ~= 0 then
			demultiplier = demultiplier + newStat;
			table.append(info_Demultiplier, GetStatusInfo(Defender, stat));
		end
		demultiplier = demultiplier + GetConditionalStatus(Defender, stat, info_Demultiplier, calcOption);
	end
	if Ability.Type == 'Attack' then
		InfoAdder('DecreaseDamage');
		if Ability.SubType ~= 'None' then
			local superType = GetAbilitySuperType(Ability);
			if superType ~= nil then
				InfoAdder('DecreaseDamage_'..superType)
			end
			-- 아직 이건 없음..
			-- InfoAdder('IncreaseDamage_'..Ability.SubType);
		end
		-- 이것도 없음
		--[[
		if Ability.HitRateType ~= 'None' then
			InfoAdder('DecreaseDamage_'..Ability.HitRateType);
		end
		]]
	end
	return demultiplier;
end
-------------------------------------------------------------------------------
-- 특정 상황에서 얻어지는 Multiplier
-----------------------------------------------------------------------------
function GetModifyAbilityDamageFromEvent(info, info_Multiplier, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, weather, temperature, usingPos, aiFlag, perfChecker, damageFlag)
	local multiplier = 0;
	local add = 0;
	if not IsMission() then
		return multiplier, add;
	end
	-- 어빌리티 타입이 Heal에 영향을 주는 경우, 해당 if 안으로 선언한다.
	if Ability.Type == 'Heal' then
		if aiFlag ~= 'PositionRelative' then
			local multiplier_Normal_Heal, add_Normal_Heal = GetModifyAbilityDamageFromEvent_Normal_Heal(info, info_Multiplier, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender);
			multiplier = multiplier + multiplier_Normal_Heal;
			add = add + add_Normal_Heal;	
		end
		return multiplier, add;
	end
	
	-- 1. 날씨 특성
	if aiFlag ~= 'PositionRelative' then
		local multiplier_Normal_Environment, add_Normal_Environment = GetbilityDamageByEnvironment(info, info_Multiplier, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, weather);
		multiplier = multiplier + multiplier_Normal_Environment;
		add = add + add_Normal_Environment;

		-- 2. SP 페이지.
		local multiplier_Normal_SP, add_Normal_SP = GetAbilityDamageBySP(info, info_Multiplier, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, weather);
		multiplier = multiplier + multiplier_Normal_SP;
		add = add + add_Normal_SP;
		
		-- 3. 일반.
		local multiplier_Normal, add_Normal = GetModifyAbilityDamageFromEvent_Normal(info, info_Multiplier, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, usingPos, weather, temperature, damageFlag);
		multiplier = multiplier + multiplier_Normal;
		add = add + add_Normal;
		
		-- 4. 트러블메이커 보정.
		local multiplier_Troublemaker, add_Troublemaker = GetModifyAbilityDamageFromEvent_Troublemaker(info, info_Multiplier, Attacker, Defender);
		multiplier = multiplier + multiplier_Troublemaker;
		add = add + add_Troublemaker;
	end

	if aiFlag == nil then	-- AI모드에서는 그냥 쓰지 말자
		-- 5. 위치기반
		local multiplier_Position, add_Position = GetModifyAbilityDamageFromEvent_Position(info, info_Multiplier, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender);
		multiplier = multiplier + multiplier_Position;
		add = add + add_Position;
	end

	return multiplier, add;
end
----------------------------------------------------------------------------------------
-- 특정 상황에서 얻어지는 Multiplier : 환경, 지형효과, 날씨.
-----------------------------------------------------------------------------
function GetbilityDamageByEnvironment(info, info_Multiplier, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, weather)
	local multiplier = 0;
	local add = 0;	
	if IsGetAbilitySubType(Ability, 'Lightning') then
		-- 지형 특성. 물
		local buff_Water = GetBuff(Defender, 'Water');
		if buff_Water and not buff_Water.Disabled then
			multiplier = multiplier + buff_Water.ApplyAmount;
			table.insert(info_Multiplier, { Type = 'TileType_Water', Value = buff_Water.ApplyAmount, ValueType = 'Formula'});			
		end
		-- 지형 특성. 오염수
		local buff_ContaminatedWater = GetBuff(Defender, 'ContaminatedWater');
		if buff_ContaminatedWater and not buff_ContaminatedWater.Disabled then
			multiplier = multiplier + buff_ContaminatedWater.ApplyAmount;
			table.insert(info_Multiplier, {Type = 'TileType_ContaminatedWater', Value = buff_ContaminatedWater.ApplyAmount, ValueType = 'Formula'});
		end
	end	
	return multiplier, add;
end
----------------------------------------------------------------------------------------
-- SP로 인해 증가하는 추가 피해량.
-----------------------------------------------------------------------------
function GetAbilityDamageBySP(info, info_Multiplier, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, weather)
	local multiplier = 0;
	local add = 0;
	-- 1. 공격자 특성: 화염.
	if Attacker.ESP and Attacker.ESP.name == 'Fire' then
		local curAdd = GetCurrentBattleValue_SP(Attacker);
		if not curAdd then
			curAdd = 0;
		elseif curAdd ~= 0 then
			table.insert(info, MakeESPStatInfo(Attacker.ESP.name, curAdd, 'Attacker'));
		end
		add = add + curAdd;
	end
	-- 2. 방어자 특성: 얼음.
	if Defender and Defender.ESP and Defender.ESP.name == 'Ice' then
		local curAdd = GetCurrentBattleValue_SP(Defender);
		if not curAdd then
			curAdd = 0;
		elseif curAdd ~= 0 then
			curAdd = -1 * curAdd;
			table.insert(info, MakeESPStatInfo(Defender.ESP.name, curAdd, 'Defender'));
		end
		add = add + curAdd;
	end
	return multiplier, add;
end
----------------------------------------------------------------------------------------
-- 특정 상황에서 얻어지는 Multiplier : 일반
-----------------------------------------------------------------------------
function IfHaveMastery(masteryTable, testMastery, onDoFunc)
	local mastery = GetMasteryMastered(masteryTable, testMastery)
	if mastery then
		onDoFunc(mastery);
	end
end
function GetMasteryValueByCustomFunc(masteryTable, masteryName, customFunc)
	local mastery = GetMasteryMastered(masteryTable, masteryName)
	if mastery then
		return customFunc(mastery) or 0;
	end
	return 0;
end
function GetMasteryValueByCustomFuncWithInfo(masteryTable, masteryName, info, customFunc)
	local value = GetMasteryValueByCustomFunc(masteryTable, masteryName, customFunc)
	if value ~= 0 then
		table.insert(info, MakeMasteryStatInfo(masteryName, value));
	end
	return value;
end
function GetBuffValueByCustomFunc(owner, buffName, customFunc)
	local buff = GetBuff(owner, buffName)
	if buff then
		return customFunc(buff) or 0;
	end
	return 0;
end
function GetBuffValueByCustomFuncWithInfo(owner, buffName, info, customFunc)
	local value = GetBuffValueByCustomFunc(owner, buffName, customFunc)
	if value ~= 0 then
		table.insert(info, { Type = buffName, Value = value, ValueType = 'Buff'});
	end
	return value;
end
function GetModifyAbilityDamageFromEvent_Normal(info, info_Multiplier, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, usingPos, weather, temperature, damageFlag)
	local multiplier = 0;
	local add = 0;
	
	-- 1. 공격자 특성
	-- 무 이동 공격 추가 데미지
	if IsStableAttack(Attacker) then
		-- 특성 고정 사격
		if Ability.HitRateType == 'Force' and Ability.SubType == 'Piercing' then
			local mastery_FixedFire = GetMasteryMastered(masteryTable_Attacker, 'FixedFire');
			if mastery_FixedFire then
				local multiplier_FixedFire = mastery_FixedFire.ApplyAmount;
				multiplier = multiplier + multiplier_FixedFire;
				table.insert(info_Multiplier, { Type = mastery_FixedFire.name, Value = multiplier_FixedFire, ValueType = 'Mastery'});
			end
		end
		-- 기본
		if Ability.NotMoveAttackApplyAmountRatio > 0 then
			multiplier = multiplier + Ability.NotMoveAttackApplyAmountRatio;
			table.insert(info_Multiplier, { Type = Ability.name, Value = Ability.NotMoveAttackApplyAmountRatio, ValueType = 'Ability'});
		end
	end	
	--특성 기습
	local mastery_Ambush = GetMasteryMastered(masteryTable_Attacker, 'Ambush');
	if mastery_Ambush then
		local group_Sleep_List = GetBuffType(Defender, nil, nil, mastery_Ambush.BuffGroup.name);
		if #group_Sleep_List > 0 or Defender.PreBattleState then
			local multiplier_Ambush = mastery_Ambush.ApplyAmount;
			multiplier = multiplier + multiplier_Ambush;
			table.insert(info_Multiplier, { Type = mastery_Ambush.name, Value = multiplier_Ambush, ValueType = 'Mastery'});
		end
	end
	-- 특성 근육 폭발. 최대 체력의 5% 
	if Ability.Type == 'Attack' and IsGetAbilitySubType(Ability, 'Physical') then
		local mastery_MusclePower = GetMasteryMastered(masteryTable_Attacker, 'MusclePower');
		if mastery_MusclePower then
			local add_MusclePower = math.floor(Attacker.MaxHP * mastery_MusclePower.ApplyAmount/100);
			if add_MusclePower > 0 then
				add = add + add_MusclePower;
				table.insert(info, { Type = mastery_MusclePower.name, Value = add_MusclePower, ValueType = 'Mastery'});
			end
		end
	end
	-- 특성 근접 격투술(공격자 부분)
	if Ability.Type == 'Attack' then
		local mastery_CloseCombatant = GetMasteryMastered(masteryTable_Attacker, 'CloseCombatant');
		if mastery_CloseCombatant then
			if IsMeleeDistanceAbility(Attacker, Defender) then
				local multiplier_CloseCombatant = mastery_CloseCombatant.ApplyAmount;
				multiplier = multiplier + multiplier_CloseCombatant;
				table.insert(info_Multiplier, { Type = mastery_CloseCombatant.name, Value = multiplier_CloseCombatant, ValueType = 'Mastery'});
			end
		end
	end
	
	-- 특성 백병전 (공격자 부분)
	if Ability.Type == 'Attack' then
		local mastery_HandToHandCombat = GetMasteryMastered(masteryTable_Attacker, 'HandToHandCombat');
		if mastery_HandToHandCombat then
			local targetList = GetTargetInRangeSightReposition(SafeIndex(Ability, 'AbilityWithMove'), Attacker, mastery_HandToHandCombat.Range, 'All', true);
			if #targetList > 0 then
				for i = 1, #targetList do
					local target = targetList[i];
					if target == Defender then
						local multiplier_HandToHandCombat = mastery_HandToHandCombat.ApplyAmount;
						multiplier = multiplier + multiplier_HandToHandCombat;
						table.insert(info_Multiplier, { Type = mastery_HandToHandCombat.name, Value = multiplier_HandToHandCombat, ValueType = 'Mastery'});
						break;
					end
				end				
			end
		end
	end	
	-- 특성 근접 사격
	if Ability.HitRateType == 'Force' and Ability.SubType == 'Piercing' then
		local mastery_CloseFire = GetMasteryMastered(masteryTable_Attacker, 'CloseFire');
		if mastery_CloseFire then
			local targetList = GetTargetInRangeSightReposition(SafeIndex(Ability, 'AbilityWithMove'), Attacker, mastery_CloseFire.Range, 'All', true);
			if #targetList > 0 then
				for i = 1, #targetList do
					local target = targetList[i];
					if target == Defender then
						local multiplier_CloseFire = mastery_CloseFire.ApplyAmount2;
						multiplier = multiplier + multiplier_CloseFire;
						table.insert(info_Multiplier, { Type = mastery_CloseFire.name, Value = multiplier_CloseFire, ValueType = 'Mastery'});
						break;
					end
				end				
			end
		end
	end
	-- 특성 심판.
	if Ability.Type == 'Attack' then
		-- 심판. 자신 잃은 체력의 일정 비율 피해량 추가.
		if Attacker.HP < Attacker.MaxHP then
			local mastery_Judgment = GetMasteryMastered(masteryTable_Attacker, 'Judgment');
			if mastery_Judgment then
				local lostHP = Attacker.MaxHP - Attacker.HP;
				local add_Judgment = math.floor(lostHP * mastery_Judgment.ApplyAmount/100);
				if add_Judgment > 0 then
					add = add + add_Judgment;
					table.insert(info, { Type = mastery_Judgment.name, Value = add_Judgment, ValueType = 'Mastery'});
				end
			end
		end
	end
	-- 특성 벤데타
	if Ability.Type == 'Attack' then
		-- 벤데타. 자신 잃은 체력의 일정 비율 피해량 추가.
		if Attacker.HP < Attacker.MaxHP then
			local mastery_Vendetta = GetMasteryMastered(masteryTable_Attacker, 'Vendetta');
			if mastery_Vendetta then
				local lostHP = Attacker.MaxHP - Attacker.HP;
				local add_Judgment = math.floor(lostHP * mastery_Vendetta.ApplyAmount/100);
				if add_Judgment > 0 then
					add = add + add_Judgment;
					table.insert(info, { Type = mastery_Vendetta.name, Value = add_Judgment, ValueType = 'Mastery'});
				end
			end
		end
	end
	-- 증오의 군주
	if Ability.Type == 'Attack' and Ability.SubType == 'Fire' then
		if Attacker.HP < Attacker.MaxHP then
			local mastery_LordOfHatred = GetMasteryMastered(masteryTable_Attacker, 'LordOfHatred');
			if mastery_LordOfHatred then
				local lostHPRatio = (Attacker.MaxHP - Attacker.HP) / Attacker.MaxHP;
				local stepCount = math.floor(lostHPRatio * 100 / mastery_LordOfHatred.ApplyAmount);	-- ApplyAmount 당
				if stepCount > 0 then
					local multiplier_LordOfHatred = stepCount * mastery_LordOfHatred.ApplyAmount;	-- ApplyAmount 만큼 증가
					multiplier = multiplier + multiplier_LordOfHatred;
					table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_LordOfHatred.name, multiplier_LordOfHatred));
				end
			end
		end
	end
	if Ability.Type == 'Attack' and Ability.SubType == 'Ice' then
		-- 얼어붙은 낫
		if Attacker.HP < Attacker.MaxHP then
			local mastery_FrozenScythe = GetMasteryMastered(masteryTable_Attacker, 'FrozenScythe');
			if mastery_FrozenScythe then
				local lostHPRatio = (Attacker.MaxHP - Attacker.HP) / Attacker.MaxHP;
				local stepCount = math.floor(lostHPRatio * 100 / mastery_FrozenScythe.ApplyAmount);	-- ApplyAmount 당
				if stepCount > 0 then
					local multiplier_FrozenScythe = stepCount * mastery_FrozenScythe.ApplyAmount;	-- ApplyAmount 만큼 증가
					multiplier = multiplier + multiplier_FrozenScythe;
					table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_FrozenScythe.name, multiplier_FrozenScythe));
				end
			end
		end
	end
	-- 두번째 충격. SecondImpact
	local buff_SecondImpact = GetBuff(Attacker, 'SecondImpact');
	if buff_SecondImpact then
		add = add + buff_SecondImpact.Lv;
		table.insert(info, { Type = buff_SecondImpact.name, Value = buff_SecondImpact.Lv, ValueType = 'Buff'});
	end
	-- 특성 분노 폭발
	local mastery_RageBurst = GetMasteryMastered(masteryTable_Attacker, 'RageBurst');
	if mastery_RageBurst and Attacker.CostType.name == 'Rage' then
		local stepCount = math.floor(Attacker.Cost / mastery_RageBurst.ApplyAmount);	-- ApplyAmount 당
		if stepCount > 0 then
			local multiplier_RageBurst = stepCount * mastery_RageBurst.ApplyAmount2;	-- ApplyAmount2 만큼 증가
			multiplier = multiplier + multiplier_RageBurst;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_RageBurst.name, multiplier_RageBurst));
		end
	end
	
	-- 특성 악전고투
	local mastery_HardFight = GetMasteryMastered(masteryTable_Attacker, 'HardFight');
	if mastery_HardFight and Ability.Type == 'Attack' and Attacker.HP < Attacker.MaxHP then
		local lostHPRatio = (Attacker.MaxHP - Attacker.HP) / Attacker.MaxHP;
		local stepCount = math.floor(lostHPRatio * 100 / mastery_HardFight.ApplyAmount);	-- ApplyAmount 당
		if stepCount > 0 then
			local multiplier_HardFight = stepCount * mastery_HardFight.ApplyAmount2;		-- ApplyAmount2 만큼 증가
			multiplier = multiplier + multiplier_HardFight;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_HardFight.name, multiplier_HardFight));
		end
	end
	
	-- 특성 분산 처리 (공격 시)
	if Ability.Type == 'Attack' then
		local mastery_DistributedProcessing = GetMasteryMastered(masteryTable_Attacker, 'DistributedProcessing');
		if mastery_DistributedProcessing then
			local enableUseCount = 0;
			for _, ability in ipairs(GetEnableProtocolAbilityList(Attacker, Ability)) do
				if ability.IsUseCount then
					enableUseCount = enableUseCount + ability.UseCount;
				end
			end
			local stepCount = math.floor(enableUseCount / mastery_DistributedProcessing.ApplyAmount);				-- ApplyAmount 당
			if stepCount > 0 then
				local multiplier_DistributedProcessing = stepCount * mastery_DistributedProcessing.ApplyAmount2;	-- ApplyAmount2 만큼 증가
				multiplier = multiplier + multiplier_DistributedProcessing;
				table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_DistributedProcessing.name, multiplier_DistributedProcessing));
			end
		end
	end
	
	-- 호환성
	for _, masteryType in ipairs({'OuterDevice_FlameThrower', 'OuterDevice_IceLaser'}) do
		local mastery = GetMasteryMastered(masteryTable_Attacker, masteryType);
		if mastery and mastery.CustomCacheData[Ability.name] then
			multiplier = multiplier + mastery.ApplyAmount;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery.name, mastery.ApplyAmount));
		end
	end
	
	-- 특성 급습
	local mastery_SneakAttack = GetMasteryMastered(masteryTable_Attacker, 'SneakAttack');
	if mastery_SneakAttack then
		if HasBuff(Attacker, mastery_SneakAttack.Buff.name) then
			local multiplier_SneakAttack = mastery_SneakAttack.ApplyAmount;
			multiplier = multiplier + multiplier_SneakAttack;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_SneakAttack.name, multiplier_SneakAttack));
		end
	end	
	
	-- 얼어붙은 마지막 생명의 불꽃
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'FrozenLastLifeFlame', info_Multiplier, function(mastery)
		if Ability.Type == 'Attack' then
			local testBuff = GetBuff(Attacker, mastery.SubBuff.name);
			if testBuff and testBuff.Lv > 0 then
				return math.floor(testBuff.Lv / mastery.ApplyAmount) * mastery.ApplyAmount2;
			end
		end
	end);
	
	-- 진귀한 돌연변이 (공격 시)
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'RareMutation', info_Multiplier, function(mastery)
		if Ability.Type == 'Attack' then
			local debuffList = GetBuffType(Attacker, 'Debuff');
			return math.floor(#debuffList / mastery.ApplyAmount) * mastery.ApplyAmount2;
		end
	end);
	
	if not Defender then
		return multiplier, add;
	end
	-- 대상이 인간일 때,
	if Defender.Race.name == 'Human' then
		-- 특성 인간사냥꾼
		local mastery_HumanHunter = GetMasteryMastered(masteryTable_Attacker, 'HumanHunter');
		if mastery_HumanHunter then
			local multiplier_HumanHunter = mastery_HumanHunter.ApplyAmount;
			multiplier = multiplier + multiplier_HumanHunter;
			table.insert(info_Multiplier, { Type = mastery_HumanHunter.name, Value = multiplier_HumanHunter, ValueType = 'Mastery'});
		end
	end
	
	-- 대상이 야수일 때,
	if Defender.Race.name == 'Beast' then
		-- 특성 야수사냥꾼
		local mastery_BeastHunter = GetMasteryMastered(masteryTable_Attacker, 'BeastHunter');
		if mastery_BeastHunter then
			local multiplier_BeastHunter = mastery_BeastHunter.ApplyAmount;
			multiplier = multiplier + multiplier_BeastHunter;
			table.insert(info_Multiplier, { Type = mastery_BeastHunter.name, Value = multiplier_BeastHunter, ValueType = 'Mastery'});
		end
		
		-- 특성 무두질 칼
		local mastery_Amulet_Tanner_Set = GetMasteryMastered(masteryTable_Attacker, 'Amulet_Tanner_Set');
		if mastery_Amulet_Tanner_Set then
			local multiplier_Amulet_Tanner_Set = mastery_Amulet_Tanner_Set.ApplyAmount;
			multiplier = multiplier + multiplier_Amulet_Tanner_Set;
			table.insert(info_Multiplier, { Type = mastery_Amulet_Tanner_Set.name, Value = multiplier_Amulet_Tanner_Set, ValueType = 'Mastery'});
		end
		
		-- 특성 동족혐오
		local mastery_SameRaceHatred = GetMasteryMastered(masteryTable_Attacker, 'SameRaceHatred');
		if mastery_SameRaceHatred then
			local multiplier_SameRaceHatred = mastery_SameRaceHatred.ApplyAmount;
			multiplier = multiplier + multiplier_SameRaceHatred;
			table.insert(info_Multiplier, { Type = mastery_SameRaceHatred.name, Value = multiplier_SameRaceHatred, ValueType = 'Mastery'});
		end
	end
	
	-- 대상이 기계일 때,
	if Defender.Race.name == 'Machine' then
		-- 특성 기계 사냥꾼
		local mastery_MachineHunter = GetMasteryMastered(masteryTable_Attacker, 'MachineHunter');
		if mastery_MachineHunter then
			local multiplier_MachineHunter = mastery_MachineHunter.ApplyAmount;
			multiplier = multiplier + multiplier_MachineHunter;
			table.insert(info_Multiplier, { Type = mastery_MachineHunter.name, Value = multiplier_MachineHunter, ValueType = 'Mastery'});
		end
	end
	-- 특성 거인사냥꾼
	local mastery_GiantKiller = GetMasteryMastered(masteryTable_Attacker, 'GiantKiller');
	if mastery_GiantKiller then
		if Defender.MaxHP >= Attacker.MaxHP * mastery_GiantKiller.ApplyAmount then
			local multiplier_GiantKiller = mastery_GiantKiller.ApplyAmount2;
			multiplier = multiplier + multiplier_GiantKiller;
			table.insert(info_Multiplier, { Type = mastery_GiantKiller.name, Value = multiplier_GiantKiller, ValueType = 'Mastery'});
		end
	end
	-- 특성 전설사냥꾼
	local mastery_LegendHunter = GetMasteryMastered(masteryTable_Attacker, 'LegendHunter');
	if mastery_LegendHunter then
		local legendGrade = GetClassList('MonsterGrade')['Legend'];
		if Defender.Grade.Weight >= legendGrade.Weight then
			local multiplier_LegendHunter = mastery_LegendHunter.ApplyAmount;
			multiplier = multiplier + multiplier_LegendHunter;
			table.insert(info_Multiplier, { Type = mastery_LegendHunter.name, Value = multiplier_LegendHunter, ValueType = 'Mastery'});
		end
	end
	-- 특성 몰이.
	local mastery_Mobbing = GetMasteryMastered(masteryTable_Attacker, 'Mobbing');
	if mastery_Mobbing then
		local targetList = GetTargetInRangeSightReposition(SafeIndex(Ability, 'AbilityWithMove'), Attacker, 'Sight', 'Team', true);
		if #targetList > 0 then
			local multiplier_Mobbing = #targetList / mastery_Mobbing.ApplyAmount * mastery_Mobbing.ApplyAmount2;
			multiplier = multiplier + multiplier_Mobbing;
			table.insert(info_Multiplier, { Type = mastery_Mobbing.name, Value = multiplier_Mobbing, ValueType = 'Mastery'});
		end
	end	
	if Defender.Affiliation.name then
		if Defender.Affiliation.Type == 'Public' then
			-- 특성 반항
			local mastery_Rebellion = GetMasteryMastered(masteryTable_Attacker, 'Rebellion');
			if mastery_Rebellion then
				local multiplier_Rebellion = mastery_Rebellion.ApplyAmount;
				multiplier = multiplier + multiplier_Rebellion;
				table.insert(info_Multiplier, { Type = mastery_Rebellion.name, Value = multiplier_Rebellion, ValueType = 'Mastery'});
			end
			-- 특성 지명수배자.
			local mastery_WantedMan = GetMasteryMastered(masteryTable_Attacker, 'WantedMan');
			if mastery_WantedMan then
				local multiplier_WantedMan = mastery_WantedMan.ApplyAmount;
				multiplier = multiplier + multiplier_WantedMan;
				table.insert(info_Multiplier, { Type = mastery_WantedMan.name, Value = multiplier_WantedMan, ValueType = 'Mastery'});
			end
		elseif Defender.Affiliation.Type == 'Crime' then
			-- 특성 법의 수호자.
			local mastery_GuardianOfTheLaw = GetMasteryMastered(masteryTable_Attacker, 'GuardianOfTheLaw');
			if mastery_GuardianOfTheLaw then
				local multiplier_GuardianOfTheLaw = mastery_GuardianOfTheLaw.ApplyAmount;
				multiplier = multiplier + multiplier_GuardianOfTheLaw;
				table.insert(info_Multiplier, { Type = mastery_GuardianOfTheLaw.name, Value = multiplier_GuardianOfTheLaw, ValueType = 'Mastery'});
			end
			-- 특성 정의감
			local mastery_SenseOfJustice = GetMasteryMastered(masteryTable_Attacker, 'SenseOfJustice');
			if mastery_SenseOfJustice then
				local multiplier_SenseOfJustice = mastery_SenseOfJustice.ApplyAmount;
				multiplier = multiplier + multiplier_SenseOfJustice;
				table.insert(info_Multiplier, { Type = mastery_SenseOfJustice.name, Value = multiplier_SenseOfJustice, ValueType = 'Mastery'});
			end
			-- 특성 정의를 위한 승리의 검
			local mastery_VictorySword = GetMasteryMastered(masteryTable_Attacker, 'VictorySword');
			if mastery_VictorySword then
				local multVal = mastery_VictorySword.ApplyAmount;
				multiplier = multiplier + multVal;
				table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_VictorySword.name, multVal));
			end
		end
	end
	if Attacker.Affiliation.name then
		if Attacker.Affiliation.Type == 'Crime' then
			-- 특성 성검
			local mastery_HolySword = GetMasteryMastered(masteryTable_Defender, 'HolySword');
			if mastery_HolySword then
				local multiplier_HolySword = -1 * mastery_HolySword.ApplyAmount;
				multiplier = multiplier + multiplier_HolySword;
				table.insert(info_Multiplier, { Type = mastery_HolySword.name, Value = multiplier_HolySword, ValueType = 'Mastery'});
			end
		end
	end	
	
	-- 특성 도전자.
	if Defender.Lv > Attacker.Lv then
		local mastery_Challenger = GetMasteryMastered(masteryTable_Attacker, 'Challenger');
		if mastery_Challenger then
			local multiplier_Challenger = mastery_Challenger.ApplyAmount;
			local mastery_DualBlades = GetMasteryMastered(masteryTable_Attacker, 'DualBlades');
			if mastery_DualBlades then
				multiplier_Challenger = multiplier_Challenger + mastery_DualBlades.ApplyAmount2;
			end
			multiplier = multiplier + multiplier_Challenger;
			table.insert(info_Multiplier, { Type = mastery_Challenger.name, Value = multiplier_Challenger, ValueType = 'Mastery'});
		end
	end	
	-- 특성 우월감.
	if Defender.Lv < Attacker.Lv then
		local mastery_Superiority = GetMasteryMastered(masteryTable_Attacker, 'Superiority');
		if mastery_Superiority then
			local multiplier_Superiority = mastery_Superiority.ApplyAmount;
			multiplier = multiplier + multiplier_Superiority;
			table.insert(info_Multiplier, { Type = mastery_Superiority.name, Value = multiplier_Superiority, ValueType = 'Mastery'});
		end
	end	
	
	-- 특정 버프.
	-- 특성 과다 출혈(검객)
	local mastery_Hemorrhage = GetMasteryMastered(masteryTable_Attacker, 'Hemorrhage');
	if mastery_Hemorrhage then
		if HasBuffType(Defender, nil, nil, 'Bleeding') then
			local multiplier_Hemorrhage = mastery_Hemorrhage.ApplyAmount;
			multiplier = multiplier + multiplier_Hemorrhage;
			table.insert(info_Multiplier, { Type = mastery_Hemorrhage.name, Value = multiplier_Hemorrhage, ValueType = 'Mastery'});
		end
	end
	-- 특정 버프.
	-- 특성 격통(번개)
	local mastery_AcutePain = GetMasteryMastered(masteryTable_Attacker, 'AcutePain');
	if mastery_AcutePain then
		local debuff_Lightning_List = GetBuffType(Defender, 'Debuff', nil, 'Lightning');
		if #debuff_Lightning_List > 0 then
			local multiplier_Debuff_Lightning = mastery_AcutePain.ApplyAmount;
			multiplier = multiplier + multiplier_Debuff_Lightning;
			table.insert(info_Multiplier, { Type = mastery_AcutePain.name, Value = multiplier_Debuff_Lightning, ValueType = 'Mastery'});
		end
	end
	-- 특정 버프.
	-- 특성 불꽃 충돌(화염)
	local mastery_FlameCrash = GetMasteryMastered(masteryTable_Attacker, 'FlameCrash');
	if mastery_FlameCrash then
		local debuff_Fire_List = GetBuffType(Defender, 'Debuff', nil, 'Fire');
		if #debuff_Fire_List > 0 then
			local multiplier_Debuff_Fire = mastery_FlameCrash.ApplyAmount;
			local mastery_DancingFlame = GetMasteryMastered(masteryTable_Attacker, 'DancingFlame');
			if mastery_DancingFlame then
				multiplier_Debuff_Fire = multiplier_Debuff_Fire + mastery_DancingFlame.ApplyAmount;
			end
			multiplier = multiplier + multiplier_Debuff_Fire;
			table.insert(info_Multiplier, { Type = mastery_FlameCrash.name, Value = multiplier_Debuff_Fire, ValueType = 'Mastery'});
		end
	end
	-- 특성 세찬 바람(바람)
	local mastery_GustWind = GetMasteryMastered(masteryTable_Attacker, 'GustWind');
	if mastery_GustWind then
		local debuff_Faint_List = GetBuffType(Defender, 'Debuff', nil, 'Faint');
		if #debuff_Faint_List > 0 then
			local multiplier_Debuff_Faint = mastery_GustWind.ApplyAmount;
			multiplier = multiplier + multiplier_Debuff_Faint;
			table.insert(info_Multiplier, { Type = mastery_GustWind.name, Value = multiplier_Debuff_Faint, ValueType = 'Mastery'});
		end
	end
	-- 특정 버프.
	-- 특성 산산조각(얼음)
	local mastery_Shatter = GetMasteryMastered(masteryTable_Attacker, 'Shatter');
	if mastery_Shatter then
		local debuff_Ice_List = GetBuffType(Defender, 'Debuff', nil, 'Ice');
		if #debuff_Ice_List > 0 then
			local multiplier_Debuff_Ice = mastery_Shatter.ApplyAmount;
			-- 얼어붙은 검
			local mastery_FrozenSword = GetMasteryMastered(masteryTable_Attacker, 'FrozenSword');
			if mastery_FrozenSword then
				multiplier_Debuff_Ice = multiplier_Debuff_Ice + mastery_FrozenSword.ApplyAmount;
			end
			-- 눈보라
			local mastery_Blizzard = GetMasteryMastered(masteryTable_Attacker, 'Blizzard');
			if mastery_Blizzard then
				multiplier_Debuff_Ice = multiplier_Debuff_Ice + mastery_Blizzard.ApplyAmount2;
			end
			multiplier = multiplier + multiplier_Debuff_Ice;
			table.insert(info_Multiplier, { Type = mastery_Shatter.name, Value = multiplier_Debuff_Ice, ValueType = 'Mastery'});
		end
	end
	-- 특성 유성
	local mastery_ShootingStar = GetMasteryMastered(masteryTable_Attacker, 'ShootingStar');
	if mastery_ShootingStar then
		local debuff_Light_List = GetBuffType(Defender, 'Debuff', nil, 'Light');
		if #debuff_Light_List > 0 then
			local multiplier_Debuff_Light = mastery_ShootingStar.ApplyAmount;
			multiplier = multiplier + multiplier_Debuff_Light;
			table.insert(info_Multiplier, { Type = mastery_ShootingStar.name, Value = multiplier_Debuff_Light, ValueType = 'Mastery'});
		end
	end	
	
	-- 노익장
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'LegendVeteran', info_Multiplier, function(mastery)
		if Ability.Type == 'Attack' and Attacker.Lv > Defender.Lv and GetRelation(Attacker, Defender) == 'Enemy' then
			return mastery.ApplyAmount3;
		end
	end);
	
	-- 분홍 도깨비
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'PinkGoblin', info_Multiplier, function(mastery)
		if Ability.Type == 'Attack' and (GetInstantProperty(Attacker, mastery.name) or {})[GetObjKey(Defender)] then
			return mastery.ApplyAmount;
		end
	end);
	
	-- 억눌린 분노
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'PentUpRage', info_Multiplier, function(mastery)
		if Ability.Type == 'Attack' and (SafeIndex(damageFlag, 'ReactionAbility') or SafeIndex(damageFlag, 'Counter')) then
			return mastery.ApplyAmount;
		end
	end);

	-- 악랄함
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'Viciousness', info_Multiplier, function(mastery)
		if Ability.Type == 'Attack' and #GetBuffType(Defender, 'Debuff', 'Mental') > 0 then
			return mastery.ApplyAmount;
		end
	end);
	
	-- 2. 방어자 특성	
	-- 생존의지 WillToSurvive
	local mastery_WillToSurvive = GetMasteryMastered(masteryTable_Defender, 'WillToSurvive');
	if mastery_WillToSurvive then
		if Defender.HP <= Defender.MaxHP * mastery_WillToSurvive.ApplyAmount/100 then
			local multiplier_WillToSurvive = -1 * mastery_WillToSurvive.ApplyAmount2;
			multiplier = multiplier + multiplier_WillToSurvive;
			table.insert(info_Multiplier, { Type = mastery_WillToSurvive.name, Value = multiplier_WillToSurvive, ValueType = 'Mastery'});
		end
	end		
	-- 생존의지 WillToSurvive
	local mastery_IndomitableWill = GetMasteryMastered(masteryTable_Defender, 'IndomitableWill');
	if mastery_IndomitableWill then
		if Defender.HP <= Defender.MaxHP * mastery_IndomitableWill.ApplyAmount/100 then
			local multiplier_IndomitableWill = -1 * mastery_IndomitableWill.ApplyAmount2;
			multiplier = multiplier + multiplier_IndomitableWill;
			table.insert(info_Multiplier, { Type = mastery_IndomitableWill.name, Value = multiplier_IndomitableWill, ValueType = 'Mastery'});
		end
	end
	-- 얼음 방패 IceShield
	if Ability.Type == 'Attack' then
		local mastery_IceShield = GetMasteryMastered(masteryTable_Defender, 'IceShield');
		if mastery_IceShield then
			local multiplier_IceShield = -1 * mastery_IceShield.ApplyAmount;
			multiplier = multiplier + multiplier_IceShield;
			table.insert(info_Multiplier, { Type = mastery_IceShield.name, Value = multiplier_IceShield, ValueType = 'Mastery'});
		end
	end
	-- 왜곡장
	if Ability.Type == 'Attack' then
		local mastery_DistortionField = GetMasteryMastered(masteryTable_Defender, 'DistortionField');
		if mastery_DistortionField then
			local multiplier_DistortionField = -1 * mastery_DistortionField.ApplyAmount;
			multiplier = multiplier + multiplier_DistortionField;
			table.insert(info_Multiplier, { Type = mastery_DistortionField.name, Value = multiplier_DistortionField, ValueType = 'Mastery'});
		end
	end
	-- 에너지 수트 EnergySuit
	if Ability.Type == 'Attack' and IsGetAbilitySubType(Ability, 'ESP') then
		local mastery_EnergySuit = GetMasteryMastered(masteryTable_Defender, 'EnergySuit');
		if mastery_EnergySuit then
			local multiplier_EnergySuit = -1 * mastery_EnergySuit.ApplyAmount;
			multiplier = multiplier + multiplier_EnergySuit;
			table.insert(info_Multiplier, { Type = mastery_EnergySuit.name, Value = multiplier_EnergySuit, ValueType = 'Mastery'});
		end
	end
	-- 강화 수트 EnhancedSuit
	-- 물리 내성 I PhysicalResistance1
	-- 물리 내성 II PhysicalResistance2
	-- 물리 내성 III PhysicalResistance3

	if Ability.Type == 'Attack' and IsGetAbilitySubType(Ability, 'Physical') then
		-- 강화 수트
		local mastery_EnhancedSuit = GetMasteryMastered(masteryTable_Defender, 'EnhancedSuit');
		if mastery_EnhancedSuit then
			local multiplier_EnhancedSuit = -1 * mastery_EnhancedSuit.ApplyAmount;
			multiplier = multiplier + multiplier_EnhancedSuit;
			table.insert(info_Multiplier, { Type = mastery_EnhancedSuit.name, Value = multiplier_EnhancedSuit, ValueType = 'Mastery'});
		end
		-- 물리 내성 I
		local mastery_PhysicalResistance1 = GetMasteryMastered(masteryTable_Defender, 'PhysicalResistance1');
		if mastery_PhysicalResistance1 then
			local multiplier_PhysicalResistance1 = -1 * mastery_PhysicalResistance1.ApplyAmount;
			multiplier = multiplier + multiplier_PhysicalResistance1;
			table.insert(info_Multiplier, { Type = mastery_PhysicalResistance1.name, Value = multiplier_PhysicalResistance1, ValueType = 'Mastery'});
		end		
		-- 물리 내성 II
		local mastery_PhysicalResistance2 = GetMasteryMastered(masteryTable_Defender, 'PhysicalResistance2');
		if mastery_PhysicalResistance2 then
			local multiplier_PhysicalResistance2 = -1 * mastery_PhysicalResistance2.ApplyAmount;
			multiplier = multiplier + multiplier_PhysicalResistance2;
			table.insert(info_Multiplier, { Type = mastery_PhysicalResistance2.name, Value = multiplier_PhysicalResistance2, ValueType = 'Mastery'});
		end
		-- 물리 내성 III
		local mastery_PhysicalResistance3 = GetMasteryMastered(masteryTable_Defender, 'PhysicalResistance3');
		if mastery_PhysicalResistance3 then
			local multiplier_PhysicalResistance3 = -1 * mastery_PhysicalResistance3.ApplyAmount;
			multiplier = multiplier + multiplier_PhysicalResistance3
			table.insert(info_Multiplier, { Type = mastery_PhysicalResistance3.name, Value = multiplier_PhysicalResistance3, ValueType = 'Mastery'});
		end
	end
	-- 바람장벽 WindWall
	if Ability.Type == 'Attack' and ( Ability.HitRateType == 'Force' or Ability.HitRateType == 'Fall' or Ability.HitRateType == 'Throw' ) then
		local mastery_WindWall = GetMasteryMastered(masteryTable_Defender, 'WindWall');
		if mastery_WindWall then
			local multiplier_WindWall = -1 * mastery_WindWall.ApplyAmount;
			local mastery_SecondWind = GetMasteryMastered(masteryTable_Defender, 'SecondWind');
			if mastery_SecondWind then
				multiplier_WindWall = multiplier_WindWall + ( -1 * mastery_SecondWind.ApplyAmount);
			end
			multiplier = multiplier + multiplier_WindWall;
			table.insert(info_Multiplier, { Type = mastery_WindWall.name, Value = multiplier_WindWall, ValueType = 'Mastery'});
		end
	end
	-- 아지랑이 Haze
	if Ability.Type == 'Attack' and Ability.HitRateType == 'Melee' then
		local mastery_Haze = GetMasteryMastered(masteryTable_Defender, 'Haze');
		if mastery_Haze then
			local multiplier_Haze = -1 * mastery_Haze.ApplyAmount;
			local mastery_SecondWind = GetMasteryMastered(masteryTable_Defender, 'SecondWind');
			if mastery_SecondWind then
				multiplier_Haze = multiplier_Haze + ( -1 * mastery_SecondWind.ApplyAmount);
			end
			multiplier = multiplier + multiplier_Haze;
			table.insert(info_Multiplier, { Type = mastery_Haze.name, Value = multiplier_Haze, ValueType = 'Mastery'});
		end
	end
	-- 칼날 흘리기
	if Ability.Type == 'Attack' and Ability.HitRateType == 'Melee' then
		local mastery_BladeEvasion = GetMasteryMastered(masteryTable_Defender, 'BladeEvasion');
		if mastery_BladeEvasion then
			local multiplier_BladeEvasion = -1 * mastery_BladeEvasion.ApplyAmount;	
			local mastery_GuardianSword = GetMasteryMastered(masteryTable_Defender, 'GuardianSword');
			if mastery_GuardianSword then
				multiplier_BladeEvasion = multiplier_BladeEvasion - mastery_GuardianSword.ApplyAmount2;				
			end
			multiplier = multiplier + multiplier_BladeEvasion;
			table.insert(info_Multiplier, { Type = mastery_BladeEvasion.name, Value = multiplier_BladeEvasion, ValueType = 'Mastery'});
		end
	end
	-- 특성 근접 격투술(감소 부분)
	if Ability.Type == 'Attack' then
		local mastery_CloseCombatant = GetMasteryMastered(masteryTable_Defender, 'CloseCombatant');
		if mastery_CloseCombatant then
			local checkDist = 1.4;
			local mastery_Mountain = GetMasteryMastered(masteryTable_Defender, 'Mountain');
			if mastery_Mountain then
				checkDist = mastery_Mountain.ApplyAmount;
			end
			if IsMeleeDistanceAbility(Attacker, Defender, checkDist) then
				local multiplier_CloseCombatant = -1 * mastery_CloseCombatant.ApplyAmount;
				multiplier = multiplier + multiplier_CloseCombatant;
				table.insert(info_Multiplier, { Type = mastery_CloseCombatant.name, Value = multiplier_CloseCombatant, ValueType = 'Mastery'});
			end
		end
	end
	-- 특성 백병전(감소 부분)
	if Ability.Type == 'Attack' then
		local mastery_HandToHandCombat = GetMasteryMastered(masteryTable_Defender, 'HandToHandCombat');
		if mastery_HandToHandCombat then
			local targetList = GetTargetInRangeSightReposition(SafeIndex(Ability, 'AbilityWithMove'), Attacker, mastery_HandToHandCombat.Range, 'All', true);
			if #targetList > 0 then
				for i = 1, #targetList do
					local target = targetList[i];
					if target == Defender then
						local multiplier_HandToHandCombat = -1 * mastery_HandToHandCombat.ApplyAmount;
						multiplier = multiplier + multiplier_HandToHandCombat;
						table.insert(info_Multiplier, { Type = mastery_HandToHandCombat.name, Value = multiplier_HandToHandCombat, ValueType = 'Mastery'});
						break;
					end
				end				
			end
		end
	end
	-- 특성 용맹(증가 부분)
	if Ability.Type == 'Attack' then
		local mastery_Bravery = GetMasteryMastered(masteryTable_Attacker, 'Bravery');
		if mastery_Bravery then
			if Attacker.HP < Defender.HP then
				local multiplier_Bravery = mastery_Bravery.ApplyAmount;
				multiplier = multiplier + multiplier_Bravery;
				table.insert(info_Multiplier, { Type = mastery_Bravery.name, Value = multiplier_Bravery, ValueType = 'Mastery'});	
			end
		end
	end
	-- 특성 용맹(감소 부분)
	if Ability.Type == 'Attack' then
		local mastery_Bravery = GetMasteryMastered(masteryTable_Defender, 'Bravery');
		if mastery_Bravery then
			if Defender.HP < Attacker.HP then
				local multiplier_Bravery = -1 * mastery_Bravery.ApplyAmount2;
				multiplier = multiplier + multiplier_Bravery;
				table.insert(info_Multiplier, { Type = mastery_Bravery.name, Value = multiplier_Bravery, ValueType = 'Mastery'});	
			end
		end
	end
			
	if Ability.HitRateType ~= 'Explosion' then	
		-- 정조준
		if Ability.Target == 'Ground' and Defender ~= nil then
			local fineSight = GetMasteryMastered(masteryTable_Attacker, 'FineSight');
			if fineSight and usingPos and IsSamePosition(GetPosition(Defender), usingPos) then
				local multiplier_FineSight = fineSight.ApplyAmount;
				multiplier = multiplier + multiplier_FineSight;
				table.insert(info_Multiplier, MakeMasteryStatInfo(fineSight.name, multiplier_FineSight));
			end
		end
	end
	-- 오색 주머니
	if IsGetAbilitySubType(Ability, 'ESP') then
		local mastery_FiveColorSac = GetMasteryMastered(masteryTable_Defender, 'FiveColorSac');
		if mastery_FiveColorSac then
			local multiplier_FiveColorSac = -1 * mastery_FiveColorSac.ApplyAmount;
			multiplier = multiplier + multiplier_FiveColorSac;
			table.insert(info_Multiplier, { Type = mastery_FiveColorSac.name, Value = multiplier_FiveColorSac, ValueType = 'Mastery'});
		end
	end
	-- 어빌리티 CostBurnRatio, CostBurnDamage
	if Ability.CostBurnRatio > 0 and Ability.CostBurnDamage > 0 and IsValidCostType(Defender, Ability.ApplyCostType) then
		local costBurn = math.floor(Defender.Cost * Ability.CostBurnRatio / 100);
		if costBurn > 0 then
			local add_CostBurn = math.floor(costBurn * Ability.CostBurnDamage);
			if add_CostBurn then
				add = add + add_CostBurn;
				table.insert(info, { Type = 'Ability_CostBurn', Ability = Ability.name, Value = add_CostBurn, ValueType = 'Formula'});
			end
		end
	end
	-- 특성 보이지 않는 검
	if Ability.Type == 'Attack' and IsLongDistanceAttack(Ability.HitRateType) then	
		local mastery_InvisibleSword = GetMasteryMastered(masteryTable_Attacker, 'InvisibleSword');
		if mastery_InvisibleSword then
			local targetKey = GetObjKey(Defender);
			local prevTargets = GetInstantProperty(Attacker, 'InvisibleSword') or {};
			if not prevTargets[targetKey] then
				local multiplier_InvisibleSword = mastery_InvisibleSword.ApplyAmount;
				multiplier = multiplier + multiplier_InvisibleSword;
				table.insert(info_Multiplier, { Type = mastery_InvisibleSword.name, Value = multiplier_InvisibleSword, ValueType = 'Mastery'});
			end
		end
	end
	-- 특성 마법의 서고
	if Ability.Type == 'Attack' then
		local mastery_SpellLibrary = GetMasteryMastered(masteryTable_Defender, 'SpellLibrary');
		if mastery_SpellLibrary then
			local matchedAllMasteryCount = table.count(masteryTable_Defender, function(mastery)
				if mastery.Lv <= 0 then
					return false;
				end
				return mastery.Type.name == 'All';
			end);
			if matchedAllMasteryCount > 0 then
				local applyAmount = mastery_SpellLibrary.ApplyAmount;
				local mastery_ForbiddenBook = GetMasteryMastered(masteryTable_Defender, 'ForbiddenBook');
				if mastery_ForbiddenBook then
					applyAmount = applyAmount + mastery_ForbiddenBook.ApplyAmount2;
				end			
				local multiplier_SpellLibrary = -1 * matchedAllMasteryCount * applyAmount;
				multiplier = multiplier + multiplier_SpellLibrary;
				table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_SpellLibrary.name, multiplier_SpellLibrary));
			end
		end
	end	
	-- 버프 성스러운 방패
	if Ability.Type == 'Attack' then
		local buff_HolyShield = GetBuff(Defender, 'HolyShield');
		if buff_HolyShield then
			local multiplier_HolyShield = -1 * buff_HolyShield.ApplyAmount;
			multiplier = multiplier + multiplier_HolyShield;
			table.insert(info_Multiplier, { Type = buff_HolyShield.name, Value = multiplier_HolyShield, ValueType = 'Buff'});
		end
	end
	-- 버프 방어진
	if Ability.Type == 'Attack' then
		local buff_DefenseCordon = GetBuff(Defender, 'DefenseCordon');
		if buff_DefenseCordon then
			local multiplier_DefenseCordon = -1* buff_DefenseCordon.ApplyAmount;
			multiplier = multiplier + multiplier_DefenseCordon;
			table.insert(info_Multiplier, { Type = buff_DefenseCordon.name, Value = multiplier_DefenseCordon, ValueType = 'Buff'});
		end
	end
	-- 버프 산성독
	if Ability.Type == 'Attack' then
		local buff_AcidicPoison = GetBuff(Defender, 'AcidicPoison');
		if buff_AcidicPoison then
			local multiplier_AcidicPoison = buff_AcidicPoison.ApplyAmount;
			multiplier = multiplier + multiplier_AcidicPoison;
			table.insert(info_Multiplier, { Type = buff_AcidicPoison.name, Value = multiplier_AcidicPoison, ValueType = 'Buff'});
		end
	end
	
	-- 특성 동일한 표적
	if Ability.Type == 'Attack' then	
		local mastery_SameTarget = GetMasteryMastered(masteryTable_Attacker, 'SameTarget');
		if mastery_SameTarget then
			local targetKey = GetObjKey(Defender);
			local prevTargets = GetInstantProperty(Attacker, 'SameTarget') or {};
			if prevTargets[targetKey] then
				local addValue = mastery_SameTarget.ApplyAmount2;
				multiplier = multiplier + addValue;
				table.insert(info_Multiplier, { Type = mastery_SameTarget.name, Value = addValue, ValueType = 'Mastery'});
			end
		end
	end
	
	-- 특성 스며드는 독
	if Ability.Type == 'Attack' then	
		local mastery_VenomAbsorb = GetMasteryMastered(masteryTable_Attacker, 'VenomAbsorb');
		if mastery_VenomAbsorb then
			local debuffPoisonList = GetBuffType(Defender, 'Debuff', nil, 'Poison');
			if #debuffPoisonList > 0 then
				local addValue = mastery_VenomAbsorb.ApplyAmount;
				multiplier = multiplier + addValue;
				table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_VenomAbsorb.name, addValue));
			end
		end
	end
	
	-- 특성 쇄도하는 독
	if Ability.Type == 'Attack' then	
		local mastery_VenomRush = GetMasteryMastered(masteryTable_Attacker, 'VenomRush');
		if mastery_VenomRush then
			local debuffPoisonList = GetBuffType(Defender, 'Debuff', nil, 'Poison');
			if #debuffPoisonList > 0 then
				local addValue = mastery_VenomRush.ApplyAmount;
				multiplier = multiplier + addValue;
				table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_VenomRush.name, addValue));
			end
		end
	end
	
	-- 특성 잊혀진 고통
	if Ability.Type == 'Attack' then	
		local mastery_ForgottenPain = GetMasteryMastered(masteryTable_Defender, 'ForgottenPain');
		if mastery_ForgottenPain then
			local buffRageList = GetBuffType(Defender, 'Buff', nil, 'Rage');
			if #buffRageList > 0 then
				local lostHPRatio = 1 - Defender.HP / Defender.MaxHP;
				local stepCount = math.floor(lostHPRatio * 100 / mastery_ForgottenPain.ApplyAmount);	-- ApplyAmount 당
				if stepCount > 0 then
					local addValue = -1 * stepCount * mastery_ForgottenPain.ApplyAmount;					-- ApplyAmount 만큼 증가
					multiplier = multiplier + addValue;
					table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_ForgottenPain.name, addValue));
				end
			end
		end
	end
	
	-- 특성 구름 속의 그림자
	if Ability.Type == 'Attack' then
		local mastery_ShadowInCloud = GetMasteryMastered(masteryTable_Defender, 'ShadowInCloud');
		if mastery_ShadowInCloud and HasBuff(Defender, mastery_ShadowInCloud.Buff.name) then
			local addValue = -1 * mastery_ShadowInCloud.ApplyAmount;
			multiplier = multiplier + addValue;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_ShadowInCloud.name, addValue));
		end
	end
	
	-- 꼭꼭 숨어라
	if Ability.Type == 'Attack' and (GetBuff(Defender, 'Conceal') or GetBuff(Defender, 'Conceal_For_Aura')) then
		local mastery_HideHide = GetMasteryMastered(masteryTable_Defender, 'HideHide');
		if mastery_HideHide then
			local applyAmount = mastery_HideHide.ApplyAmount2;
			-- 완벽한 잠복
			local mastery_PerfectCover = GetMasteryMastered(masteryTable_Defender, 'PerfectCover');
			if mastery_PerfectCover then
				applyAmount = applyAmount + mastery_PerfectCover.ApplyAmount3;
			end
			local addValue = -1 * applyAmount;
			multiplier = multiplier + addValue;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_HideHide.name, addValue));
		end
	end

	-- 아이템 반짝이는 충격 보호대
	local mastery_Amulet_AniDamage = GetMasteryMastered(masteryTable_Defender, 'Amulet_AniDamage');
	if mastery_Amulet_AniDamage then
		local addValue = -1 * mastery_Amulet_AniDamage.ApplyAmount;
		multiplier = multiplier + addValue;
		table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_Amulet_AniDamage.name, addValue));
	end

	-- 특성 교활함
	local mastery_Foxy = GetMasteryMastered(masteryTable_Attacker, 'Foxy');
	if mastery_Foxy then
		local multiplier_Foxy = 0;
		if Attacker.Lv > Defender.Lv then
			multiplier = multiplier + mastery_Foxy.ApplyAmount;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_Foxy.name, mastery_Foxy.ApplyAmount));
		end
	end
	
	-- 혹한
	local mastery_SevereCold = GetMasteryMastered(masteryTable_Defender, 'SevereCold');
	if mastery_SevereCold then
		local addMul = - mastery_SevereCold.CustomCacheData * mastery_SevereCold.ApplyAmount2 / mastery_SevereCold.ApplyAmount;
		multiplier = multiplier + addMul;
		table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_SevereCold.name, addMul));
	end	

	-- 야수 충성심
	if Ability.Type == 'Attack' then
		local buff_BeastLoyaltyGood = GetBuff(Attacker, 'BeastLoyaltyGood');
		local buff_BeastLoyaltyNormal = GetBuff(Attacker, 'BeastLoyaltyNormal');
		local buff_BeastLoyalty = buff_BeastLoyaltyGood or buff_BeastLoyaltyNormal;
		if buff_BeastLoyalty then
			local targetKey = GetObjKey(Defender);
			local targets = GetInstantProperty(Attacker, 'BeastRoyaltyTarget') or {};
			if targets[targetKey] then
				local addValue = buff_BeastLoyalty.ApplyAmount;
				multiplier = multiplier + addValue;
				table.insert(info_Multiplier, { Type = buff_BeastLoyalty.name, Value = addValue, ValueType = 'Buff'});
			end
		end
	end
	
	-- 바위 주먹
	if Ability.Type == 'Attack' and IsGetAbilitySubType(Ability, 'Physical') then
		local mastery_StonePunch = GetMasteryMastered(masteryTable_Attacker, 'StonePunch');
		if mastery_StonePunch then
			local addValue = Attacker.Armor * (mastery_StonePunch.ApplyAmount / 100);
			add = add + addValue;
			table.insert(info, MakeMasteryStatInfo(mastery_StonePunch.name, addValue));
		end
	end
	
	-- 특성 합선 / 달빛 칼날
	if Ability.Type == 'Attack' then
		local targetDatas = {{'Lightning', 'LightningResistance', 'ShortCircuit'}, 
							{'Earth', 'EarthResistance', 'MoonBlade'}};
		for _, data in pairs(targetDatas) do
			local damageType = data[1];
			local ratioProp = data[2];
			local testMasteryName = data[3];
			if IsGetAbilitySubType(Ability, damageType) then
				local targetMastery = GetMasteryMastered(masteryTable_Attacker, testMasteryName);
				if targetMastery then
					local addValue = Attacker[ratioProp] * targetMastery.ApplyAmount / 100;
					add = add + addValue;
					table.insert(info, MakeMasteryStatInfo(targetMastery.name, addValue));
				end
			end
		end
	end
	
	-- 넘치는 기백
	if Ability.Type == 'Attack' then
		local mastery_OverfloorSpirit = GetMasteryMastered(masteryTable_Defender, 'OverfloorSpirit');
		if mastery_OverfloorSpirit and Defender.Overcharge > 0 then
			local addValue = -1 * mastery_OverfloorSpirit.ApplyAmount;
			multiplier = multiplier + addValue;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_OverfloorSpirit.name, addValue));
		end
	end
	
	-- 질투
	if Ability.Type == 'Attack' then
		local mastery_Jealousy = GetMasteryMastered(masteryTable_Attacker, 'Jealousy');
		if mastery_Jealousy then
			local buffList = GetBuffType(Defender, 'Buff');
			local stepCount = math.floor(#buffList / mastery_Jealousy.ApplyAmount);	-- ApplyAmount 당
			if stepCount > 0 then
				local addValue = stepCount * mastery_Jealousy.ApplyAmount2;			-- ApplyAmount2 만큼 증가
				multiplier = multiplier + addValue;
				table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_Jealousy.name, addValue));
			end
		end
	end
	
	-- 최상의 상태
	if Ability.Type == 'Attack' then
		local mastery_BestCondition = GetMasteryMastered(masteryTable_Defender, 'BestCondition');
		if mastery_BestCondition and Defender.HP >= Defender.MaxHP then
			local addValue = -1 * mastery_BestCondition.ApplyAmount2;
			multiplier = multiplier + addValue;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_BestCondition.name, addValue));
		end
	end
	-- 저항 의지
	if Ability.Type == 'Attack' and Attacker.Lv > Defender.Lv then
		local mastery_ResistWill = GetMasteryMastered(masteryTable_Defender, 'ResistWill');
		if mastery_ResistWill then
			multiplier = multiplier - mastery_ResistWill.ApplyAmount;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_ResistWill.name, -mastery_ResistWill.ApplyAmount));
		end
	end
	
	-- 번개를 부르는 자 - 3 세트
	if Ability.Type == 'Attack' then
		IfHaveMastery(masteryTable_Defender, 'LightningNeguriSet3', function(mastery)
			multiplier = multiplier - mastery.ApplyAmount;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery.name, - mastery.ApplyAmount));
		end);
	end
	
	-- 특성 안전제일 - 회사용
	local mastery_SafetyFirst = GetMasteryMastered(masteryTable_Defender, 'SafetyFirst');
	if mastery_SafetyFirst and Ability.Type == 'Attack' and Defender.HP < Defender.MaxHP then
		local lostHPRatio = (Defender.MaxHP - Defender.HP) / Defender.MaxHP;
		local stepCount = math.floor(lostHPRatio * 100 / mastery_SafetyFirst.ApplyAmount);		-- ApplyAmount 당
		if stepCount > 0 then
			local multiplier_SafetyFirst = -1 * stepCount * mastery_SafetyFirst.ApplyAmount2;	-- ApplyAmount2 만큼 감소
			multiplier = multiplier + multiplier_SafetyFirst;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_SafetyFirst.name, multiplier_SafetyFirst));
		end
	end
	-- 특성 안전제일2 - 조직용
	local mastery_SafetyFirst2 = GetMasteryMastered(masteryTable_Defender, 'SafetyFirst2');
	if mastery_SafetyFirst2 and Ability.Type == 'Attack' and Defender.HP < Defender.MaxHP then
		local lostHPRatio = (Defender.MaxHP - Defender.HP) / Defender.MaxHP;
		local stepCount = math.floor(lostHPRatio * 100 / mastery_SafetyFirst2.ApplyAmount);		-- ApplyAmount 당
		if stepCount > 0 then
			local multiplier_SafetyFirst = -1 * stepCount * mastery_SafetyFirst2.ApplyAmount2;	-- ApplyAmount2 만큼 감소
			multiplier = multiplier + multiplier_SafetyFirst;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_SafetyFirst2.name, multiplier_SafetyFirst));
		end
	end
	
	-- 기계공학도
	if Defender.Race.name == 'Machine' then
		local mastery_BaseOfMechanicalEngineering = GetMasteryMastered(masteryTable_Attacker, 'BaseOfMechanicalEngineering') or GetMasteryMastered(masteryTable_Attacker, 'BaseOfMechanicalEngineering_Machine');
		if mastery_BaseOfMechanicalEngineering then
			local addAmount = mastery_BaseOfMechanicalEngineering.ApplyAmount;
			multiplier = multiplier + addAmount;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_BaseOfMechanicalEngineering.name, addAmount));
		end
	end
	
	-- 호버링
	if Ability.Type == 'Attack' and ( Ability.HitRateType == 'Force' or Ability.HitRateType == 'Fall' or Ability.HitRateType == 'Throw' ) then
		local mastery_Hovering = GetMasteryMastered(masteryTable_Defender, 'Hovering');
		if mastery_Hovering then
			local multiplier_Hovering = -1 * mastery_Hovering.ApplyAmount;
			multiplier = multiplier + multiplier_Hovering;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_Hovering.name, multiplier_Hovering));
		end
	end
	
	-- 버프 굳건한 티마 / 계승자
	if Ability.Type == 'Attack' then
		local buff_Tima_DefenceMode = GetBuff(Defender, 'Tima_DefenceMode') or GetBuff(Defender, 'Tima_DefenceMode2');
		if buff_Tima_DefenceMode and GetRelation(Defender, Attacker) == 'Enemy' then
			local multiplier_Tima_DefenceMode = -1 * buff_Tima_DefenceMode.ApplyAmount;
			multiplier = multiplier + multiplier_Tima_DefenceMode;
			table.insert(info_Multiplier, { Type = buff_Tima_DefenceMode.name, Value = multiplier_Tima_DefenceMode, ValueType = 'Buff' });
		end
	end
	
	-- 피해 최적화 분석
	if Ability.Type == 'Attack' then
		local mastery_Module_DefenceOptimaztion = GetMasteryMastered(masteryTable_Defender, 'Module_DefenceOptimaztion');
		if mastery_Module_DefenceOptimaztion then
			local prevSubType = GetInstantProperty(Defender, 'Module_DefenceOptimaztion');
			if prevSubType == Ability.SubType then
				local multiplier_Module_DefenceOptimaztion = -1 * mastery_Module_DefenceOptimaztion.ApplyAmount;
				multiplier = multiplier + multiplier_Module_DefenceOptimaztion;
				table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_Module_DefenceOptimaztion.name, multiplier_Module_DefenceOptimaztion));
			end
		end
	end
	
	-- 특성 마검 장막
	if IsGetAbilitySubType(Ability, 'ESP') then
		local mastery_MagicianSwordWall = GetMasteryMastered(masteryTable_Defender, 'MagicianSwordWall');
		if mastery_MagicianSwordWall then
			local multiplier_MagicianSwordWall = math.floor(mastery_MagicianSwordWall.CustomCacheData / mastery_MagicianSwordWall.ApplyAmount) * mastery_MagicianSwordWall.ApplyAmount2;
			if multiplier_MagicianSwordWall ~= 0 then
				multiplier = multiplier + multiplier_MagicianSwordWall;
				table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_MagicianSwordWall.name, multiplier_MagicianSwordWall));
			end
		end
	end
	
	-- 나는 포기하지 않는다. (재소탕 대상)
	local mastery_IDontGiveUp = GetMasteryMastered(masteryTable_Attacker, 'IDontGiveUp');
	if mastery_IDontGiveUp then
		if SafeIndex(GetInstantProperty(Attacker, 'IDontGiveUp_SweepTarget'), GetObjKey(Defender)) then
			multiplier = multiplier + mastery_IDontGiveUp.ApplyAmount3;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_IDontGiveUp.name, mastery_IDontGiveUp.ApplyAmount3));
		end
	end
	
	-- 질풍경초
	local mastery_NeverYields = GetMasteryMastered(masteryTable_Defender, 'NeverYields');
	if mastery_NeverYields then
		if Ability.Type == 'Attack' and GetRelation(Attacker, Defender) == 'Enemy' and IsMeleeDistanceAbility(Attacker, Defender) then
			local multiplier_NeverYields = -1 * mastery_NeverYields.ApplyAmount;
			multiplier = multiplier + multiplier_NeverYields;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_NeverYields.name, multiplier_NeverYields));
		end
	end
	
	-- 피의 저항
	local mastery_BloodResistance = GetMasteryMastered(masteryTable_Defender, 'BloodResistance');
	if mastery_BloodResistance then
		if Ability.Type == 'Attack' and GetRelation(Attacker, Defender) == 'Enemy' and (HasBuffType(Attacker, nil, nil, mastery_BloodResistance.BuffGroup.name) or HasBuffType(Defender, nil, nil, mastery_BloodResistance.BuffGroup.name)) then
			local lostHPRatio = (Defender.MaxHP - Defender.HP) / Defender.MaxHP;
			local multiplier_BloodResistance = -1  * math.floor(lostHPRatio * 100 / mastery_BloodResistance.ApplyAmount) * mastery_BloodResistance.ApplyAmount;
			if multiplier_BloodResistance ~= 0 then
				multiplier = multiplier + multiplier_BloodResistance;
				table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_BloodResistance.name, multiplier_BloodResistance));
			end
		end
	end
	
	-- 진귀한 돌연변이 (피격 시)
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'RareMutation', info_Multiplier, function(mastery)
		if Ability.Type == 'Attack' then
			local buffList = GetBuffType(Defender, 'Buff');
			return -1 * math.floor(#buffList / mastery.ApplyAmount) * mastery.ApplyAmount2;
		end
	end);
	
	-- 물러서지 않는 자 - 5 세트
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'DrakyGuardianSet5', info_Multiplier, function(mastery)
		if Ability.Type == 'Attack' and Ability.SubType == GetInstantProperty(Defender, mastery.name) then
			return -1 * mastery.ApplyAmount;
		end
	end);
	
	-- 드라키의 이상한 비늘
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'Amulet_Draky_Set', info_Multiplier, function(mastery)
		if Ability.Type == 'Attack' then
			local debuffList = GetBuffType(Defender, 'Debuff');
			return -1 * math.floor(#debuffList / mastery.ApplyAmount) * mastery.ApplyAmount2;
		end
	end);
	
	-- 버프 움츠러든 비늘
	if Ability.Type == 'Attack' then
		local buff_ShrinkScale = GetBuff(Defender, 'ShrinkScale');
		if buff_ShrinkScale and buff_ShrinkScale.DuplicateApplyChecker == 0 then
			local multiplier_ShrinkScale = -1 * buff_ShrinkScale.ApplyAmount;
			multiplier = multiplier + multiplier_ShrinkScale;
			table.insert(info_Multiplier, { Type = buff_ShrinkScale.name, Value = multiplier_ShrinkScale, ValueType = 'Buff' });
		end
	end
	
	-- 무두장이 손목 보호대
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'Wrist_Tanner_Set', info_Multiplier, function(mastery)
		if Ability.Type == 'Attack' and SafeIndex(Attacker, 'Race', 'name') == 'Beast' then
			return -1 * mastery.ApplyAmount;
		end
	end);
	
	-- 광기 어린 짐승
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'CrazyBeast', info_Multiplier, function(mastery)
		if Ability.Type == 'Attack' and HasBuffType(Defender, nil, nil, mastery.BuffGroup.name) then
			return -1 * mastery.ApplyAmount3;
		end
	end);
	
	-- 야생의 분노
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'Tima', info_Multiplier, function(mastery)
		if Ability.Type == 'Attack' and HasBuffType(Defender, nil, nil, mastery.BuffGroup.name) then
			return -1 * mastery.ApplyAmount2;
		end
	end);
	
	-- 만독
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'AllPoison', info_Multiplier, function(mastery)
		if Ability.Type == 'Attack' then
			local debuffList = GetBuffType(Defender, 'Debuff', nil, mastery.BuffGroup.name);
			if #debuffList > 0 then
				return math.floor(#debuffList / mastery.ApplyAmount) * mastery.ApplyAmount2;
			end
		end
	end);
	
	-- 흑철 가죽 활동복
	local mastery_Tracksuit_BlackIronEnhanced = GetMasteryMastered(masteryTable_Defender, 'Tracksuit_BlackIronEnhanced')
		or GetMasteryMastered(masteryTable_Defender, 'Tracksuit_BlackIronEnhanced_Rare')
		or GetMasteryMastered(masteryTable_Defender, 'Tracksuit_BlackIronEnhanced_Ice_Epic')
		or GetMasteryMastered(masteryTable_Defender, 'Tracksuit_BlackIronEnhanced_Fire_Epic')
		or GetMasteryMastered(masteryTable_Defender, 'Tracksuit_BlackIronEnhanced_Lightning_Epic');
	if mastery_Tracksuit_BlackIronEnhanced then
		if Ability.Type == 'Attack' and GetRelation(Attacker, Defender) == 'Enemy' and IsMeleeDistanceAbility(Attacker, Defender) then
			local multiplier_Tracksuit_BlackIronEnhanced = -1 * mastery_Tracksuit_BlackIronEnhanced.ApplyAmount;
			multiplier = multiplier + multiplier_Tracksuit_BlackIronEnhanced;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_Tracksuit_BlackIronEnhanced.name, multiplier_Tracksuit_BlackIronEnhanced));
		end
	end
	-- 흑철 가죽 자켓
	local mastery_Jacket_BlackIronEnhanced = GetMasteryMastered(masteryTable_Defender, 'Jacket_BlackIronEnhanced')
		or GetMasteryMastered(masteryTable_Defender, 'Jacket_BlackIronEnhanced_Rare')
		or GetMasteryMastered(masteryTable_Defender, 'Jacket_BlackIronEnhanced_Ice_Epic')
		or GetMasteryMastered(masteryTable_Defender, 'Jacket_BlackIronEnhanced_Fire_Epic')
		or GetMasteryMastered(masteryTable_Defender, 'Jacket_BlackIronEnhanced_Lightning_Epic');
	if mastery_Jacket_BlackIronEnhanced then
		if Ability.Type == 'Attack' and GetRelation(Attacker, Defender) == 'Enemy' and table.find({'Force', 'Fall', 'Throw'}, Ability.HitRateType) then
			local multiplier_Jacket_BlackIronEnhanced = -1 * mastery_Jacket_BlackIronEnhanced.ApplyAmount;
			multiplier = multiplier + multiplier_Jacket_BlackIronEnhanced;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_Jacket_BlackIronEnhanced.name, multiplier_Jacket_BlackIronEnhanced));
		end
	end
	
	-- 맹독 괴수
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'PoisonMonster', info_Multiplier, function(mastery)
		if Ability.Type == 'Attack' and HasBuffType(Attacker, 'Debuff', nil, mastery.BuffGroup.name) then
			return -1 * mastery.ApplyAmount;
		end
	end);
	
	-- 버프 정보 변조
	multiplier = multiplier + GetBuffValueByCustomFuncWithInfo(Defender, 'InformationFalsification', info_Multiplier, function(buff)
		if Ability.Type == 'Attack' and Ability.SubType == GetInstantProperty(Defender, buff.name) then
			return -1 * buff.ApplyAmount2;
		end
	end);
	
	-- 백수왕 (공격 시)
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'BeastKing', info_Multiplier, function(mastery)
		if Ability.Type == 'Attack' and Attacker.Grade.Weight > Defender.Grade.Weight and GetRelation(Attacker, Defender) == 'Enemy' then
			return math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
		end
	end);
	-- 백수왕 (방어 시)
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'BeastKing', info_Multiplier, function(mastery)
		if Ability.Type == 'Attack' and Attacker.Grade.Weight < Defender.Grade.Weight and GetRelation(Defender, Attacker) == 'Enemy' then
			return -1 * math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
		end
	end);
	
	-- 권토중래
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'MakeStageComeback', info_Multiplier, function(mastery)
		if Ability.Type == 'Attack' and GetBuff(Defender, mastery.Buff.name) then
			return -mastery.ApplyAmount;
		end
	end);
	
	-- 삶의 무게 (공격 시)
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'WeightOfLife', info_Multiplier, function(mastery)
		local targetList = GetTargetInRangeSightReposition(SafeIndex(Ability, 'AbilityWithMove'), Attacker, 'Sight', 'Enemy', true);
		return math.floor(#targetList / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);
	-- 삶의 무게 (방어 시)
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'WeightOfLife', info_Multiplier, function(mastery)
		local targetList = GetTargetInRangeSightReposition(SafeIndex(Ability, 'AbilityWithMove'), Defender, 'Sight', 'Team', true);
		return -1 * math.floor(#targetList / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end);

	return multiplier, add;
end
----------------------------------------------------------------------------------------
-- 대상과의 위치에 기반하여 얻어지는 Multiplier
----------------------------------------------------------------------------------------
function GetModifyAbilityDamageFromEvent_Position(info, info_Multiplier, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender)
	local multiplier = 0;
	local add = 0;
	local distance = GetDistanceFromObjectToObjectAbility(Ability, Attacker, Defender);
	
	
	if IsStableAttack(Attacker) then
		-- 촌경
		local mastery_OneInchPunch = GetMasteryMastered(masteryTable_Attacker, 'OneInchPunch');
		if mastery_OneInchPunch and Ability.Type == 'Attack' and Ability.HitRateType == 'Melee' then
			multiplier = multiplier + mastery_OneInchPunch.ApplyAmount;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_OneInchPunch.name, mastery_OneInchPunch.ApplyAmount));
		end
	end
	
	-- 거리에 의한 효과.
	if Ability.DistanceAttackApplyAmountRatio > 0 then
		local multiplier_DistanceAttackApplyAmountRatio = math.floor(distance) * Ability.DistanceAttackApplyAmountRatio;
		multiplier = multiplier + multiplier_DistanceAttackApplyAmountRatio;
		table.insert(info_Multiplier, { Type = 'Ability_Distance', Ability = Ability.name, Value = multiplier_DistanceAttackApplyAmountRatio, ValueType = 'Formula'});
	end
	
	-- 무방비 노출 추가 데미지
	if Ability.NoCoverAttackApplyAmountRatio > 0 and IsUnprotectedExposureState(Defender) then
		local multVal = Ability.NoCoverAttackApplyAmountRatio;
		multiplier = multiplier + multVal;
		table.insert(info_Multiplier, { Type = 'Ability_NoCover', Ability = Ability.name, Value = multVal, ValueType = 'Formula'});
	end
	
	-- 특성 가깝고도 먼, 마그넷 코팅, 공격적 선택
	local ApplyDistanceDamage = function(masteryList, getDominatorFunc, getMultiplierFunc)
		for _, masteryType in ipairs(masteryList) do
			local mastery = GetMasteryMastered(masteryTable_Attacker, masteryType);
			if mastery then		
				local dominator = getDominatorFunc(mastery);
				local multiplierVal = math.floor(distance / dominator) * getMultiplierFunc(mastery);
				multiplier = multiplier + multiplierVal;
				table.insert(info_Multiplier, { Type = mastery.name, Value = multiplierVal, ValueType = 'Mastery'});
			end
		end
	end
	ApplyDistanceDamage({'SoCloseYetFar'}, function (m) return 1; end, function (m) 
		local ret = m.ApplyAmount;
		local mastery_OffenceChoice = GetMasteryMastered(masteryTable_Attacker, 'OffenceChoice');
		if mastery_OffenceChoice then
			ret = ret + mastery_OffenceChoice.ApplyAmount3;
		end
		return ret;
	end);
	ApplyDistanceDamage({'SubArmorDevice_SubArmorMagnet', 'SubArmorDevice_SubArmorMagnet_Rare', 'SubArmorDevice_SubArmorMagnet_Epic'}, function (m) return m.ApplyAmount; end, function(m) return m.ApplyAmount2 end);

	-- 맞바람 HeadWind
	if Ability.Type == 'Attack' then
		local mastery_HeadWind = GetMasteryMastered(masteryTable_Defender, 'HeadWind');
		if mastery_HeadWind then
			local multiplier_HeadWind = -1 * math.floor(distance) * mastery_HeadWind.ApplyAmount;
			multiplier = multiplier + multiplier_HeadWind;
			table.insert(info_Multiplier, { Type = mastery_HeadWind.name, Value = multiplier_HeadWind, ValueType = 'Mastery'});
		end
	end
	
	-- 마력 침식
	local mastery_SpellErosion = GetMasteryMastered(masteryTable_Attacker, 'SpellErosion');
	if Ability.HitRateType == 'Melee' and mastery_SpellErosion then
		local debuffCount = table.count(GetBuffList(Defender), function(b) return b.Type == 'Debuff' end);
		if debuffCount ~= 0 then
			local damMultiplier = debuffCount * mastery_SpellErosion.ApplyAmount;
			multiplier = multiplier + damMultiplier;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_SpellErosion.name, damMultiplier));
		end
	end
	
	-- 상처 베기
	local mastery_SlashInjury = GetMasteryMastered(masteryTable_Attacker, 'SlashInjury');
	if mastery_SlashInjury and (HasBuffType(Defender, nil, nil, 'Bleeding') or HasBuffType(Defender, nil, nil, 'Bruise')) then
		multiplier = multiplier + mastery_SlashInjury.ApplyAmount;
		table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_SlashInjury.name, mastery_SlashInjury.ApplyAmount));
	end
	
	-- 특성 상처 태우기
	local mastery_BurnInjury = GetMasteryMastered(masteryTable_Attacker, 'BurnInjury');
	if Ability.Type == 'Attack' and mastery_BurnInjury and IsGetAbilitySubType(Ability, 'Fire') and (HasBuffType(Defender, nil, nil, mastery_BurnInjury.BuffGroup.name) or HasBuffType(Defender, nil, nil, mastery_BurnInjury.SubBuffGroup.name)) then
		multiplier = multiplier + mastery_BurnInjury.ApplyAmount;
		table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_BurnInjury.name, mastery_BurnInjury.ApplyAmount));
	end
	
	-- 마력 공명
	local mastery_MagicResonance = GetMasteryMastered(masteryTable_Attacker, 'MagicResonance');
	if mastery_MagicResonance and IsGetAbilitySubType(Ability, 'ESP') then
		local targetRange = mastery_MagicResonance.Range;
		-- 마도의 길
		local mastery_TheWayOfMage = GetMasteryMastered(masteryTable_Attacker, 'TheWayOfMage');
		if mastery_TheWayOfMage then
			targetRange = mastery_TheWayOfMage.Range;
		end	
		local targetList = GetTargetInRangeSightReposition(SafeIndex(Ability, 'AbilityWithMove'), Attacker, targetRange, 'All', true);
		targetList = table.filter(targetList, function (target)
			return target.ESP and target.ESP.name and target.ESP.name ~= 'None' and target.ESP.name ~= 'Spirit';
		end);
		if #targetList > 1 then
			local multiplier_MagicResonance = #targetList * mastery_MagicResonance.ApplyAmount;
			multiplier = multiplier + multiplier_MagicResonance;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_MagicResonance.name, multiplier_MagicResonance));
		end
	end
	
	-- 외로운 싸움꾼
	local mastery_LonelyFighter = GetMasteryMastered(masteryTable_Defender, 'LonelyFighter');
	if mastery_LonelyFighter then
		local allyList = GetTargetInRangeSightReposition(false, Defender, mastery_LonelyFighter.Range, 'Team', true);
		if #allyList == 0 then	-- 혼자 남았구나..
			local addValue = -mastery_LonelyFighter.ApplyAmount2;
			multiplier = multiplier + addValue;
			table.insert(info_Multiplier, { Type = mastery_LonelyFighter.name, Value = addValue, ValueType = 'Mastery'});
		end
	end
	
	-- 내가 여기 있다.
	local mastery_ImHere = GetMasteryMastered(masteryTable_Attacker, 'ImHere');
	if mastery_ImHere and GetCoverState(Attacker, GetPosition(Defender), Defender) ~= 'None' then
		local addValue = mastery_ImHere.ApplyAmount;
		multiplier = multiplier + addValue;
		table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_ImHere.name, addValue));
	end
	
	-- 하얀 모래바람
	local mastery_WhiteSandstorm = GetMasteryMastered(masteryTable_Attacker, 'WhiteSandstorm');
	if mastery_WhiteSandstorm then
		if Ability.Type == 'Attack' and Ability.SubType == 'Earth' and distance <= mastery_WhiteSandstorm.ApplyAmount + 0.4 then
			local lostHPRatio = (Defender.MaxHP - Defender.HP) / Defender.MaxHP;
			local stepCount = math.floor(lostHPRatio * 100 / mastery_WhiteSandstorm.ApplyAmount2);	-- ApplyAmount2 당
			if stepCount > 0 then
				local multiplier_WhiteSandstorm = stepCount * mastery_WhiteSandstorm.ApplyAmount2;	-- ApplyAmount2 만큼 증가
				multiplier = multiplier + multiplier_WhiteSandstorm;
				table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_WhiteSandstorm.name, multiplier_WhiteSandstorm));
			end
		end
	end
	
	-- 대화재 (공격 시)
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'Conflagration', info_Multiplier, function(mastery)
		if Ability.Type == 'Attack' and GetRelation(Attacker, Defender) == 'Enemy' then
			local curRange = mastery.Range;
			local mastery_SeaOfFire = GetMasteryMastered(masteryTable_Attacker, 'SeaOfFire');
			if mastery_SeaOfFire then
				curRange = mastery_SeaOfFire.Range;
			end
			local fieldEffectCount = GetFieldEffectCountInRangeReposition(true, Attacker, curRange, mastery.FieldEffect.name);
			return math.floor(fieldEffectCount / mastery.ApplyAmount) * mastery.ApplyAmount2;
		end
	end);
	-- 대화재 (피격 시)
	multiplier = multiplier + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'Conflagration', info_Multiplier, function(mastery)
		if Ability.Type == 'Attack' and GetRelation(Attacker, Defender) == 'Enemy' then
			local curRange = mastery.Range;
			local mastery_SeaOfFire = GetMasteryMastered(masteryTable_Attacker, 'SeaOfFire');
			if mastery_SeaOfFire then
				curRange = mastery_SeaOfFire.Range;
			end
			local fieldEffectCount = GetFieldEffectCountInRangeReposition(false, Defender, curRange, mastery.FieldEffect.name);
			return -1 * math.floor(fieldEffectCount / mastery.ApplyAmount) * mastery.ApplyAmount2;
		end
	end);
	
	return multiplier, add;
end
----------------------------------------------------------------------------------------
-- 특정 상황에서 얻어지는 Multiplier : 힐
----------------------------------------------------------------------------------------
function GetModifyAbilityDamageFromEvent_Normal_Heal(info, info_Multiplier, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender)
	local multiplier = 0;
	local add = 0;
	-- 1. 공격자 특성
	-- 특성 기도자.
	local mastery_Prayer = GetMasteryMastered(masteryTable_Attacker, 'Prayer');
	if mastery_Prayer then
		local multiplier_Prayer = mastery_Prayer.ApplyAmount;
		multiplier = multiplier + multiplier_Prayer;
		table.insert(info_Multiplier, { Type = mastery_Prayer.name, Value = multiplier_Prayer, ValueType = 'Mastery'});
	end
	
	-- 특성 기적
	local mastery_Miracle = GetMasteryMastered(masteryTable_Attacker, 'Miracle');
	if mastery_Miracle then
		if GetInstantProperty(Attacker, 'Miracle') then
			local multiplier_Miracle = mastery_Miracle.ApplyAmount2;
			multiplier = multiplier + multiplier_Miracle;
			table.insert(info_Multiplier, MakeMasteryStatInfo(mastery_Miracle.name, multiplier_Miracle));
		end
	end
	
	-- 버프 산성독
	if Defender ~= nil then
		local buff_AcidicPoison = GetBuff(Defender, 'AcidicPoison');
		if buff_AcidicPoison then
			local multiplier_AcidicPoison = -1 * buff_AcidicPoison.ApplyAmount2;
			multiplier = multiplier + multiplier_AcidicPoison;
			table.insert(info_Multiplier, { Type = buff_AcidicPoison.name, Value = multiplier_AcidicPoison, ValueType = 'Buff'});
		end
	end

	return multiplier, add;
end
function GetModifyAbilityDamageFromEvent_Normal_Heal_Final(info, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender)
	local multiplier = 0;
	-- 버프 생기
	if Defender ~= nil then
		local buff_LifeStream = GetBuff(Defender, 'LifeStream');
		if buff_LifeStream then
			local multiplier_LifeStream = 50;
			multiplier = multiplier + multiplier_LifeStream;
			table.insert(info, { Type = buff_LifeStream.name, Value = multiplier_LifeStream, ValueType = 'Buff'});
		end
	end
	
	-- 생존 본능
	local mastery_InstinctForSurvival = GetMasteryMastered(masteryTable_Defender, 'InstinctForSurvival');
	if mastery_InstinctForSurvival then
		multiplier = multiplier + mastery_InstinctForSurvival.ApplyAmount;
		table.insert(info, MakeMasteryStatInfo(mastery_InstinctForSurvival.name, mastery_InstinctForSurvival.ApplyAmount));
	end
	return multiplier;
end
----------------------------------------------------------------------------------------
-- 특정 상황에서 얻어지는 Multiplier : 바람
-----------------------------------------------------------------------------
-- 공격자
function GetModifyAbilityDamageFromEvent_Wind_Attacker(info, info_Multiplier, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender)
	local multiplier = 0;
	local add = 0;
	local mastery_SoCloseYetFar = GetMasteryMastered(masteryTable_Attacker, 'SoCloseYetFar');
	if mastery_SoCloseYetFar and Defender ~= nil then		
		local distance = GetDistanceFromObjectToObjectAbility(Ability, Attacker, Defender);
		local multiplier_SoCloseYetFar = math.floor(distance) * mastery_SoCloseYetFar.ApplyAmount;
		multiplier = multiplier + multiplier_SoCloseYetFar;
		table.insert(info_Multiplier, { Type = mastery_SoCloseYetFar.name, Value = multiplier_SoCloseYetFar, ValueType = 'Mastery'});
	end
	return multiplier, add;
end
----------------------------------------------------------------------------------------
-- C2. 1) 방어/저항력에 의한 방어량
----------------------------------------------------------------------------------------
local _DefenceTypeSetArmor = nil;
local _DefenceTypeSetRegistance = nil;
function GetDefenceRatio(Attacker, Defender, Ability, masteryTable_Attacker, masteryTable_Defender, perfChecker)
	perfChecker:Dive();
	perfChecker:StartRoutine('Begin');
	if _DefenceTypeSetArmor == nil or _DefenceTypeSetRegistance == nil then
		_DefenceTypeSetArmor = Set.new({'Slashing', 'Piercing', 'Blunt'});
		_DefenceTypeSetRegistance = Set.new({'Fire', 'Ice', 'Lightning', 'Wind', 'Earth', 'Water'});
	end
	local defVal = GetWithoutError(Defender, Ability.SubType .. 'Resistance');
	if _DefenceTypeSetArmor[Ability.SubType] then
		perfChecker:StartRoutine('GetDefenderArmor');
		defVal = defVal + GetDefenderArmor(Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender);
	elseif _DefenceTypeSetRegistance[Ability.SubType] then
		perfChecker:StartRoutine('GetDefenderResistance');
		defVal = defVal + GetDefenderResistance(Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender);
	else
		return 0;
	end
	perfChecker:StartRoutine('GetDefenceCalculateRatio');
	if defVal == nil then
		return 0;
	end
	local ret = GetDefenceCalculateRatio(defVal, Attacker.Lv);
	perfChecker:Rise();
	return ret;
end
-- 방어율 감소 식.
function GetDefenceCalculateRatio(totalStatus, attackerLevel)
	return math.max(0, totalStatus / ( totalStatus + 100 + 10 * attackerLevel));
end
function IsMachineOrHeavyArmor(obj)
	local race = SafeIndex(obj, 'Race', 'name');
	local armorType = SafeIndex(obj, 'Body', 'Type', 'ItemUpgradeType');
	return race == 'Machine' or armorType == 'Metal';
end
function GetDefenderArmor(Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender)
	local multiplier = 100;
	-- 특성 무력화, 거포
	for _, masteryType in ipairs({'Neutralization', 'GreatCannon'}) do
		local mastery = GetMasteryMastered(masteryTable_Attacker, masteryType);
		if mastery then
			if IsGetAbilitySubType(Ability, 'Physical') then
				multiplier = multiplier - mastery.ApplyAmount;
			end
		end
	end
	
	-- 특성 틈새 공격
	local mastery_AttackBreakpoint = GetMasteryMastered(masteryTable_Attacker, 'AttackBreakpoint');
	if mastery_AttackBreakpoint then
		multiplier = multiplier - mastery_AttackBreakpoint.ApplyAmount;
	end
	
	if Ability.Type == 'Attack' and IsMachineOrHeavyArmor(Defender) then
		if IsGetAbilitySubType(Ability, 'Slashing') then
			-- 엘리게이터 블레이드
			local mastery_Sword_Sever = GetMasteryMastered(masteryTable_Attacker, 'Sword_Sever')
				or GetMasteryMastered(masteryTable_Attacker, 'Sword_Sever_Rare')
				or GetMasteryMastered(masteryTable_Attacker, 'Sword_Sever_Epic');
			if mastery_Sword_Sever then
				multiplier = multiplier - mastery_Sword_Sever.ApplyAmount;
			end
		elseif IsGetAbilitySubType(Ability, 'Piercing') then
			-- 듀나메스 MPIB
			local mastery_MachinePistol_DynamesMPIBC = GetMasteryMastered(masteryTable_Attacker, 'MachinePistol_DynamesMPIBC_Uncommon')
				or GetMasteryMastered(masteryTable_Attacker, 'MachinePistol_DynamesMPIBR_Rare')
				or GetMasteryMastered(masteryTable_Attacker, 'MachinePistol_DynamesMPIBE_Epic');
			if mastery_MachinePistol_DynamesMPIBC then
				multiplier = multiplier - mastery_MachinePistol_DynamesMPIBC.ApplyAmount;
			end
			-- 듀나메스 저격총 IB
			local mastery_SniperRifle_DynamesIB = GetMasteryMastered(masteryTable_Attacker, 'SniperRifle_DynamesIB_Uncommon')
				or GetMasteryMastered(masteryTable_Attacker, 'SniperRifle_DynamesIBA_Rare')
				or GetMasteryMastered(masteryTable_Attacker, 'SniperRifle_DynamesIBS_Epic');
			if mastery_SniperRifle_DynamesIB then
				multiplier = multiplier - mastery_SniperRifle_DynamesIB.ApplyAmount;
			end
		end
	end	
	
	return math.max(Defender.Armor * multiplier / 100, 0);
end
function GetDefenderResistance(Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender)
	local multiplier = 100;
	-- 특성 무력화, 거포
	for _, masteryType in ipairs({'Neutralization', 'GreatCannon'}) do
		local mastery = GetMasteryMastered(masteryTable_Attacker, masteryType);
		if mastery then
			if IsGetAbilitySubType(Ability, 'ESP') then
				multiplier = multiplier - mastery.ApplyAmount;
			end
		end
	end
	-- 특성 마력 관통
	local mastery_SpellPiercing = GetMasteryMastered(masteryTable_Attacker, 'SpellPiercing');
	if mastery_SpellPiercing then
		if Ability.Type == 'Attack' and IsGetAbilitySubType(Ability, 'ESP') then
			multiplier = multiplier - mastery_SpellPiercing.ApplyAmount;
		end
	end
	-- 특성 원자 분해
	local mastery_AtomDecomposition = GetMasteryMastered(masteryTable_Attacker, 'AtomDecomposition');
	if mastery_AtomDecomposition then
		if Ability.Type == 'Attack' and GetRelation(Attacker, Defender) == 'Enemy' then
			local stepCount = math.floor(mastery_AtomDecomposition.CustomCacheData / mastery_AtomDecomposition.ApplyAmount);
			if stepCount > 0 then
				multiplier = multiplier - stepCount * mastery_AtomDecomposition.ApplyAmount2;
			end
			local mastery_BigThunderBolt = GetMasteryMastered(masteryTable_Attacker, 'BigThunderBolt');
			if mastery_BigThunderBolt then
				local stepCount = math.floor(mastery_AtomDecomposition.CustomCacheData / mastery_BigThunderBolt.ApplyAmount);
				if stepCount > 0 then
					multiplier = multiplier - stepCount * mastery_BigThunderBolt.ApplyAmount3;
				end
			end
		end
	end
	
	if Ability.Type == 'Attack' and IsGetAbilitySubType(Ability, 'ESP') and IsMachineOrHeavyArmor(Defender) then
		-- 유니콘 블레이드
		local mastery_Sword_Unicorn = GetMasteryMastered(masteryTable_Attacker, 'Sword_Unicorn')
			or GetMasteryMastered(masteryTable_Attacker, 'Sword_Unicorn_Rare')
			or GetMasteryMastered(masteryTable_Attacker, 'Sword_Unicorn_Epic');
		if mastery_Sword_Unicorn then
			multiplier = multiplier - mastery_Sword_Unicorn.ApplyAmount;
		end
		-- 검은 가시 팔찌
		local mastery_Bangle_Thorn = GetMasteryMastered(masteryTable_Attacker, 'Bangle_Thorn')
			or GetMasteryMastered(masteryTable_Attacker, 'Bangle_Thorn_Rare')
			or GetMasteryMastered(masteryTable_Attacker, 'Bangle_Thorn_Epic');
		if mastery_Bangle_Thorn then
			multiplier = multiplier - mastery_Bangle_Thorn.ApplyAmount;
		end
	end
	
	return math.max(Defender.Resistance * multiplier / 100, 0);
end
------------------------------------------------------------------------------------------------
-------------------------------------- 치명타 적중률 계산 공식 ----------------------------------
------------------------------------------------------------------------------------------------
function GetCriticalStrikeChanceCalculator(Attacker, Defender, Ability, weather, missionTime, isCovered, resultModifier, abilityDetailInfo, damageFlag, perfChecker)
	if perfChecker == nil then
		perfChecker = MockPerfChecker;
	end
	perfChecker:StartRoutine('Initialize');
	local masteryTable_Attacker = GetMastery(Attacker);
	local masteryTable_Defender = GetMastery(Defender);
	
	local totalCriticalStrikeChance = 0;
	local maxCriticalStrikeChance = 0;
	local defenderBlock = 0;

	local info = {};

	if Ability.Type == 'Heal' and (Ability.ItemAbility or Ability.SubType == 'None') then
		-- 회복약 관련 추가 구문은 이 안에 선언
		return totalCriticalStrikeChance, info, maxCriticalStrikeChance;
	end
	if Ability.DamageType == 'Explosion' then
		return totalCriticalStrikeChance, info, maxCriticalStrikeChance;	
	end	
	
	-- 1. 공격자 치명타 적중률.
	perfChecker:StartRoutine('GetCurrentCriticalStrikeChance');
	local abilityCriticalStrikeChance = GetCurrentCriticalStrikeChance(info, Ability, Attacker);

	-- 2. 스탯으로 인한 상승하는 공격자 치명타 적중률
	perfChecker:StartRoutine('GetModifyAbilityCriticalStrikeChanceFromStatus');
	local passiveCriticalStrikeChance = GetModifyAbilityCriticalStrikeChanceFromStatus(info, Ability, Attacker);
	-- 3. 특정 상황에서만 발생하는 치명타 적중률
	perfChecker:StartRoutine('GetModifyAbilityCriticalStrikeChanceFromEvent');
	local addCriticalStrikeChance = GetModifyAbilityCriticalStrikeChanceFromEvent(
		info, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, isCovered, weather, missionTime, resultModifier, abilityDetailInfo
	);

	
	-- 5. 방어자가 있어야 계산 되는 부분.
	perfChecker:StartRoutine('DefenderPart');
	if Defender ~= nil then
		if Ability.Type ~= 'Heal' then
			local curblock, blockInfos = GetBlockRateCalculator(Attacker, Defender, Ability, missionTime, abilityDetailInfo, damageFlag);
			defenderBlock = curblock;
			for index, blockInfo in ipairs (blockInfos) do
				blockInfo.Value = -1 * blockInfo.Value;
				table.insert(info, blockInfo);
			end
		end
	end
	-- 4. 적의 회피율과 엊어맞을 확률을 계산한다.
	perfChecker:StartRoutine('Other');
	totalCriticalStrikeChance = abilityCriticalStrikeChance + passiveCriticalStrikeChance + addCriticalStrikeChance - defenderBlock; 
	maxCriticalStrikeChance = math.floor(totalCriticalStrikeChance*100)/100;
	local resultCriticalStrikeChance = math.max(0, math.min(maxCriticalStrikeChance, 100));
	
	-- info 정보 넣기.
	table.sort(info, function (a, b)
		return a.Value > b.Value;
	end);
	
	local infoValue = 0;
	for index, value in ipairs (info) do
		infoValue = infoValue + value.Value;
	end
	local basicValue = math.floor((maxCriticalStrikeChance - infoValue) * 100) / 100;
	if basicValue ~= 0 then
		table.insert(info, 1, { Type = 'CriticalStrikeChance', Value = basicValue, ValueType = 'Formula'});
	end
	return resultCriticalStrikeChance, info, maxCriticalStrikeChance;
end
------------------------------------------------------------------------------
-- 기본 치명타 적중률 수치 얻어오기.
------------------------------------------------------------------------------
function GetCurrentCriticalStrikeChance(info, Ability, Attacker)
	local arg = 'CriticalStrikeChance';
	local result = Attacker.CriticalStrikeChance + Ability.CriticalStrikeChance;	
	if Ability.CriticalStrikeChance ~= 0 then
		table.insert(info, { Type = Ability.name, Value = Ability.CriticalStrikeChance, ValueType = 'Ability'});
	end
	tableAppend(info, GetStatusInfo(Attacker, 'CriticalStrikeChance'));
	return result;
end
function StatusInfoAdder(info, obj, stat)
	local status = obj[stat];
	if status and status ~= 0 then
		GetStatusInfo(obj, stat, nil, nil, nil, info);
		return status;
	end
	return 0;
end
function GetModifyAbilityCriticalStrikeChanceFromStatus(info, Ability, Attacker)
	-- 2. 서브 타입 특성에 의한 증감.
	local result = 0;
	if Ability.SubType ~= 'None' then
		local superType = GetAbilitySuperType(Ability);
		if superType ~= nil then
			result = result + StatusInfoAdder(info, Attacker, 'IncreaseCriticalStrikeChance_'..superType);
		end
		result = result + StatusInfoAdder(info, Attacker, 'IncreaseCriticalStrikeChance_'..Ability.SubType);
	end
	if Ability.HitRateType ~= 'None' then
		result = result + StatusInfoAdder(info, Attacker, 'IncreaseCriticalStrikeChance_'..Ability.HitRateType);
	end
	return result;
end
function GetModifyAbilityCriticalStrikeChanceFromEvent(info, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, isCovered, weather, missionTime, resultModifier, abilityDetailInfo)
	local result = 0;
	if not IsMission() then
		return result;
	end
	
	local calcOption = {};
	calcOption.UsePrevAbilityPosition = SafeIndex(Ability, 'AbilityWithMove');
	calcOption.MasteryTable = masteryTable_Attacker;
	calcOption.MissionTime = missionTime;
	if resultModifier then
		local reactionAbility = SafeIndex(resultModifier, 'ReactionAbility') and true or false;
		local counterAttack = SafeIndex(resultModifier, 'Counter') and true or false;
		calcOption.NotStableAttack = reactionAbility or counterAttack;
	end
	
	-- 0. 조건부 수치
	result = result + GetConditionalStatus(Attacker, 'CriticalStrikeChance', info, calcOption);
		
	-- 1. 측면 목표
	if Ability.Type ~= 'Heal' then
		result = result + GetCriticalRateByCoverState(info, Attacker, Defender, Ability, masteryTable_Attacker, masteryTable_Defender);
	else
		result = result + GetCriticalRateByDistance(info, Attacker, Defender, Ability, masteryTable_Attacker, masteryTable_Defender);
	end	
	-- 2. 날씨 특성
	result = result + GetCriticalRateByWeather(info, Attacker, Defender, Ability, masteryTable_Attacker, masteryTable_Defender, weather);
	
	-- 3. 트러블메이커 보정.
	result = result + GetCriticalRateByTroublemaker(info, Attacker, Defender);
	
	-- 4. 일반 특성
	-- 특성 호전성
	local mastery_Aggression = GetMasteryMastered(masteryTable_Attacker, 'Aggression');
	if mastery_Aggression then
		local targetList = GetTargetInRangeSightReposition(SafeIndex(Ability, 'AbilityWithMove'), Attacker, 'Sight', 'Enemy', true);
		if #targetList > 0 then
			local addCriticalStrikeChance = #targetList * mastery_Aggression.ApplyAmount;
			
			-- 공격적 선택
			local mastery_OffenceChoice = GetMasteryMastered(masteryTable_Attacker, 'OffenceChoice');
			if mastery_OffenceChoice then
				addCriticalStrikeChance = addCriticalStrikeChance + math.floor(#targetList / mastery_OffenceChoice.ApplyAmount) * mastery_OffenceChoice.ApplyAmount2;
			end
			
			result = result + addCriticalStrikeChance;
			table.insert(info, { Type = mastery_Aggression.name, Value = addCriticalStrikeChance, ValueType = 'Mastery'});
			
		end
	end	
	-- 초능력 어빌리티 사용시.
	if IsGetAbilitySubType(Ability, 'ESP') then
		-- 특성 마법회로 : 최대 기력수 x 치명타 0.2 상승.
		if Ability.Type == 'Attack' then
			local mastery_MagicCircuit = GetMasteryMastered(masteryTable_Attacker, 'MagicCircuit');
			if mastery_MagicCircuit then
				local addCriticalStrikeChance = Attacker.Cost * mastery_MagicCircuit.ApplyAmount;
				result = result + addCriticalStrikeChance;
				table.insert(info, { Type = mastery_MagicCircuit.name, Value = addCriticalStrikeChance, ValueType = 'Mastery'});		
			end
		end
		-- 특성 인과율 : 현재 기력량 x 치명타 적중률 0.2 감소.
		local mastery_PrincipleOfCausality = GetMasteryMastered(masteryTable_Attacker, 'PrincipleOfCausality');
		if mastery_PrincipleOfCausality and Ability.Type == 'Attack' then
			local addCriticalStrikeChance = -1 * Attacker.Cost * mastery_PrincipleOfCausality.ApplyAmount;
			result = result + addCriticalStrikeChance;
			table.insert(info, { Type = mastery_PrincipleOfCausality.name, Value = addCriticalStrikeChance, ValueType = 'Mastery'});		
		end
		-- 특성 사술 : 현재 기력량 x 치명타 적중률 0.3 증가.
		local mastery_Witchcraft = GetMasteryMastered(masteryTable_Attacker, 'Witchcraft');
		if mastery_Witchcraft and Ability.Type == 'Attack' then
			local addCriticalStrikeChance = Attacker.Cost * mastery_Witchcraft.ApplyAmount;
			result = result + addCriticalStrikeChance;
			table.insert(info, { Type = mastery_Witchcraft.name, Value = addCriticalStrikeChance, ValueType = 'Mastery'});		
		end
	end

	-- 특성 상처입은 늑대.	
	local mastery_InjuredWolf = GetMasteryMastered(masteryTable_Attacker, 'InjuredWolf');
	if mastery_InjuredWolf then
		if Attacker.HP < Attacker.MaxHP * mastery_InjuredWolf.ApplyAmount then
			local addCriticalStrikeChance = mastery_InjuredWolf.ApplyAmount2;
			result = result + addCriticalStrikeChance;
			table.insert(info, { Type = mastery_InjuredWolf.name, Value = addCriticalStrikeChance, ValueType = 'Mastery'});		
		end		
	end
	-- 특성 흑호
	local mastery_BlackTiger = GetMasteryMastered(masteryTable_Attacker, 'BlackTiger');
	if mastery_BlackTiger then
		if Defender.HP < Attacker.HP then
			local addCriticalStrikeChance = mastery_BlackTiger.ApplyAmount;
			result = result + addCriticalStrikeChance;
			table.insert(info, { Type = mastery_BlackTiger.name, Value = addCriticalStrikeChance, ValueType = 'Mastery'});
		end
	end
	
	-- 특성 나는 이미 알고 있다.
	if SafeIndex(resultModifier, 'ReactionAbility') and Ability.HitRateType ~= 'Melee' then
		local mastery_aik = GetMasteryMastered(masteryTable_Attacker, 'AlreadyIknow');
		if mastery_aik then
			result = result + mastery_aik.ApplyAmount;
			table.insert(info, { Type = mastery_aik.name, Value = mastery_aik.ApplyAmount, ValueType = 'Mastery'});
		end
	end
	
	-- 약점 공격
	local mastery_AttackWeakpoint = GetMasteryMastered(masteryTable_Attacker, 'AttackWeakpoint');
	if mastery_AttackWeakpoint then
		if table.exist(GetBuffList(Defender), function(b) return b.Type == 'Debuff' and b.SubType == 'Physical' end) then
			result = result + mastery_AttackWeakpoint.ApplyAmount;
			table.insert(info, MakeMasteryStatInfo(mastery_AttackWeakpoint.name, mastery_AttackWeakpoint.ApplyAmount));
		end
	end
	
	-- 특성 배후 습격
	local mastery_RearAttack = GetMasteryMastered(masteryTable_Attacker, 'RearAttack');
	if mastery_RearAttack then
		if IsUnprotectedExposureState(Defender) then
			result = result + mastery_RearAttack.ApplyAmount;
			table.insert(info, MakeMasteryStatInfo(mastery_RearAttack.name, mastery_RearAttack.ApplyAmount));
		end
	end
	
	-- 균열 예측 AI
	local mastery_PredictionCrackingAI = GetMasteryMastered(masteryTable_Defender, 'PredictionCrackingAI');
	if mastery_PredictionCrackingAI and GetRelation(Attacker, Defender) == 'Enemy' then
		result = result - mastery_PredictionCrackingAI.ApplyAmount;
		table.insert(info, MakeMasteryStatInfo(mastery_PredictionCrackingAI.name, -mastery_PredictionCrackingAI.ApplyAmount));
	end
	
	-- 정밀한 저격
	if Ability.AbilitySubMenu == 'DetailedSnipe' then
		local snipeTypeList = GetClassList('SnipeType');
		local snipeTypeName = SafeIndex(abilityDetailInfo, 'SnipeType') or 'Head';
		local snipeType = SafeIndex(snipeTypeList, snipeTypeName);
		local applyRatio = 100;
		local mastery_Infallibility = GetMasteryMastered(masteryTable_Attacker, 'Infallibility');
		if mastery_Infallibility then
			applyRatio = applyRatio + mastery_Infallibility.ApplyAmount;
		end
		if snipeType and snipeType.CriticalStrikeChance ~= 0 then
			local addCrit = snipeType.CriticalStrikeChance * applyRatio / 100;
			result = result + addCrit;
			table.insert(info, {Type = 'DetailedSnipe', Value = addCrit, ValueType = 'Formula', SnipeType = snipeType.name});
		end
	end	
	
	-- 전황 정보 분석
	if Ability.Type == 'Attack' then	
		for _, testMasteryType in ipairs({'Module_TacticalSupplementation'}) do
			result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, testMasteryType, info, function(mastery)
				local targetKey = GetObjKey(Defender);
				local prevTargets = GetInstantProperty(Attacker, mastery.name) or {};
				if prevTargets[targetKey] then
					return mastery.ApplyAmount;
				end
			end);
		end
	end
	
	-- 대인 살상 훈련
	local mastery_HumanKillTraining = GetMasteryMastered(masteryTable_Attacker, 'HumanKillTraining');
	if mastery_HumanKillTraining then
		if Ability.Type == 'Attack' and SafeIndex(Defender, 'Race', 'name') == 'Human' and GetRelation(Attacker, Defender) == 'Enemy' then
			local addCriticalStrikeChance = mastery_HumanKillTraining.ApplyAmount;
			result = result + addCriticalStrikeChance;
			table.insert(info, MakeMasteryStatInfo(mastery_HumanKillTraining.name, addCriticalStrikeChance));
		end
	end
	
	-- 숨결주머니
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'BreathSac', info, function(mastery)
		if Ability.Type == 'Attack' and Ability.HitRateType == 'Force' then
			return math.floor(mastery.CustomCacheData['Draky'] / mastery.ApplyAmount) * mastery.ApplyAmount2;
		end
	end);
	
	-- 포식자의 후각
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'PredatorSmell', info, function(mastery)
		if Ability.Type == 'Attack' and Attacker.HP > Defender.HP then
			if not HasBuff(Defender, mastery.Buff.name) and not HasBuff(Defender, mastery.SubBuff.name) then
				return mastery.ApplyAmount;
			end
		end
	end);
	
	-- 돌연변이의 후각
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'MutationSmell', info, function(mastery)
		if Ability.Type == 'Attack' and Attacker.HP < Defender.HP then
			if not HasBuff(Defender, mastery.Buff.name) and not HasBuff(Defender, mastery.SubBuff.name) then
				return mastery.ApplyAmount;
			end
		end
	end);
	
	-- 두터운 가죽
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'FatSkin', info, function(mastery)
		if Ability.Type == 'Attack' and GetRelation(Defender, Attacker) == 'Enemy' then
			return -1 * mastery.ApplyAmount;
		end
	end);
	-- 백호의 눈
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'Ring_WhiteTiger_Legend', info, function(mastery)
		if Ability.Type == 'Attack' and GetRelation(Defender, Attacker) == 'Enemy' then
			return -1 * mastery.ApplyAmount;
		end
	end);
	-- 목표 확인
	local buff_TargetChecking = GetBuff(Attacker, 'TargetChecking');
	if buff_TargetChecking and GetObjKey(Defender) == buff_TargetChecking.ReferenceTarget then
		local addCriticalStrikeChance = buff_TargetChecking.ApplyAmount2;
		result = result + addCriticalStrikeChance;
		table.insert(info, { Type = buff_TargetChecking.name, Value = addCriticalStrikeChance, ValueType = 'Buff'});
	end	
	
	-- 강철 투구
	local mastery_IronHelmet = GetMasteryMastered(masteryTable_Defender, 'IronHelmet');
	if mastery_IronHelmet then
		-- 강철의 전투법사
		local mastery_IronBattleMage = GetMasteryMastered(masteryTable_Defender, 'IronBattleMage');
		if mastery_IronBattleMage then
			local addCriticalStrikeChance = -1 * mastery_IronBattleMage.ApplyAmount2;
			result = result + addCriticalStrikeChance;
			table.insert(info, MakeMasteryStatInfo(mastery_IronHelmet.name, addCriticalStrikeChance));
		end
	end
	
	-- 버프 정보 공유
	result = result + GetBuffValueByCustomFuncWithInfo(Attacker, 'InformationSharing', info, function(buff)
		local targetKey = GetObjKey(Defender);
		local prevTargets = GetInstantProperty(Attacker, buff.name) or {};
		if Ability.Type == 'Attack' and prevTargets[targetKey] then
			return buff.ApplyAmount;
		end
	end);
	
	-- 왕의 후각
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'KingSmell', info, function(mastery)
		if Ability.Type == 'Attack' and Attacker.Grade.Weight > Defender.Grade.Weight and GetRelation(Attacker, Defender) == 'Enemy' then
			if not HasBuff(Defender, mastery.Buff.name) and not HasBuff(Defender, mastery.SubBuff.name) then
				return mastery.ApplyAmount;
			end
		end
	end);
	
	-- 선혈의 괴수
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'BloodyMonster', info, function(mastery)
		if Ability.Type == 'Attack' and HasBuffType(Defender, nil, nil, mastery.BuffGroup.name) and GetRelation(Attacker, Defender) == 'Enemy' then
			return mastery.ApplyAmount2;
		end
	end);
	
	-- 무모함
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'Recklessness', info, function(mastery)
		if Ability.Type == 'Attack' and HasBuffType(Attacker, nil, nil, mastery.BuffGroup.name) then
			return mastery.ApplyAmount;
		end
	end);

	return result;
end
------------------------------------------------------------------------
-- 엄폐에 따른 치명타 보정
------------------------------------------------------------------------
function GetCoverStateForCritical(Defender, masteryTable_Defender, testPosition, Attacker)
	if not Defender.Coverable then
		return 'None';
	end
	return GetCoverState(Defender, testPosition, Attacker);
end
function GetCriticalRateByCoverState(info, Attacker, Defender, Ability, masteryTable_Attacker, masteryTable_Defender)
	local result = 0;
	local criticalRate = 0;
	local isFlankingTarget = false;
	
	local myPosition = GetPosition(Attacker);
	if IsClient() and Ability.AbilityWithMove then
		myPosition = GetSession().current_using_pos;
	end
	local coverState = GetCoverStateForCritical(Defender, masteryTable_Defender, myPosition, Attacker);
	if coverState == 'None' then
		criticalRate = 50;
		table.insert(info, { Type = 'CoverState_'..coverState, Value = criticalRate, ValueType = 'Formula'});
		-- 예민한 감각, 드라키의 완벽한 비늘
		local mastery_AcuteSense = GetMasteryMasteredList(masteryTable_Defender, {'AcuteSense', 'Amulet_Draky_Scale3'});
		if mastery_AcuteSense then
			table.insert(info, MakeMasteryStatInfo(mastery_AcuteSense.name, -criticalRate));
			criticalRate = 0;
		end
	end

	result = criticalRate;
	return result;
end
------------------------------------------------------------------------
-- 거리에 따른 치명타 보정 - 힐.
------------------------------------------------------------------------
function GetCriticalRateByDistance(info, Attacker, Defender, Ability, masteryTable_Attacker, masteryTable_Defender)
	local distance, height = GetDistanceFromObjectToObjectAbility(Ability, Attacker, Defender);
	
	-- 거리에 따른 치명타율 패널티
	local distancePenalty = 0;
	if distance > 2 then
		distancePenalty = -1 * math.floor( 5 * distance * 100 )/100;
	end
	if distancePenalty ~= 0 then
		table.insert(info, { Type = 'Distance', Value = distancePenalty, ValueType = 'Formula'});
	end
	return distancePenalty;	
end
------------------------------------------------------------------------
-- 날씨 따른 치명타 보정
------------------------------------------------------------------------
function GetCriticalRateByWeather(info, Attacker, Defender, Ability, masteryTable_Attacker, masteryTable_Defender, weather)
	local criticalRate = 0;
	local weatherList = GetClassList('MissionWeather');
	local weatherCls = weatherList[weather];
	if weather == 'Clear' then
		if IsGetAbilitySubType(Ability, 'Fire') then
			criticalRate = weatherCls.ApplyAmount;
		elseif IsGetAbilitySubType(Ability, 'Earth') then
			criticalRate = weatherCls.ApplyAmount2;
		elseif IsGetAbilitySubType(Ability, 'Ice') then
			criticalRate = -weatherCls.ApplyAmount3;
		end
	elseif weather == 'Cloud' then
		if IsGetAbilitySubType(Ability, 'Fire') then
			criticalRate = weatherCls.ApplyAmount;
		elseif IsGetAbilitySubType(Ability, 'Earth') then
			criticalRate = -weatherCls.ApplyAmount2;
		end
	elseif weather == 'Windy' then
		if IsGetAbilitySubType(Ability, 'Wind') then
			criticalRate = weatherCls.ApplyAmount;
		elseif IsGetAbilitySubType(Ability, 'Fire') then
			criticalRate = weatherCls.ApplyAmount2;
		elseif IsGetAbilitySubType(Ability, 'Earth') then
			criticalRate = weatherCls.ApplyAmount3;
		end
	elseif weather == 'Rain' then
		if IsGetAbilitySubType(Ability, 'Lightning') then
			criticalRate = weatherCls.ApplyAmount;
		elseif IsGetAbilitySubType(Ability, 'Water') then
			criticalRate = weatherCls.ApplyAmount2;
		elseif IsGetAbilitySubType(Ability, 'Earth') then
			criticalRate = -weatherCls.ApplyAmount3;
		elseif IsGetAbilitySubType(Ability, 'Fire') then
			criticalRate = -weatherCls.ApplyAmount4;
		end
	elseif weather == 'Snow' then
		if IsGetAbilitySubType(Ability, 'Ice') then
			criticalRate = weatherCls.ApplyAmount;
		elseif IsGetAbilitySubType(Ability, 'Water') then
			criticalRate = weatherCls.ApplyAmount2;
		elseif IsGetAbilitySubType(Ability, 'Earth') then
			criticalRate = -weatherCls.ApplyAmount3;
		elseif IsGetAbilitySubType(Ability, 'Fire') then
			criticalRate = -weatherCls.ApplyAmount4;
		end
	elseif weather == 'Fog' then
		if IsGetAbilitySubType(Ability, 'Water') then
			criticalRate = weatherCls.ApplyAmount;
		end
	end
	
	if criticalRate ~= 0 then
		table.insert(info, { Type = 'Weather', Value = criticalRate, ValueType = 'Formula', Weather = weather});
	end
	
	-- 야생 생활 / 환경 적응
	if criticalRate < 0 then
		local immuneMastery = GetMasteryMasteredImmuneWeather(masteryTable_Attacker);
		-- 혹한의 야수(눈)
		if not immuneMastery and weather == 'Snow' then
			immuneMastery = GetMasteryMastered(masteryTable_Attacker, 'ColdBeast');
		end
		-- 빗속의 야수(비)
		if not immuneMastery and weather == 'Rain' then
			immuneMastery = GetMasteryMastered(masteryTable_Attacker, 'RainBeast');
		end
		if immuneMastery then
			local addAmount = -criticalRate;
			criticalRate = 0;
			table.insert(info, MakeMasteryStatInfo(immuneMastery.name, addAmount));
		end	
	elseif criticalRate > 0 then
		local mastery_EnvironmentalAdaptation = GetMasteryMastered(masteryTable_Attacker, 'EnvironmentalAdaptation');
		if mastery_EnvironmentalAdaptation then
			local addAmount = criticalRate * mastery_EnvironmentalAdaptation.ApplyAmount / 100;
			criticalRate = criticalRate + addAmount;
			table.insert(info, MakeMasteryStatInfo(mastery_EnvironmentalAdaptation.name, addAmount));
		end
	end
	return criticalRate;
end
------------------------------------------------------------------------------------------------
-------------------------------------- 적 방어 확률 계산 공식 ----------------------------------
------------------------------------------------------------------------------------------------
BlockComposer = nil;
function GetBlockRateCalculator(Attacker, Defender, Ability, missionTime, abilityDetailInfo, damageFlag)
	local masteryTable_Attacker = GetMastery(Attacker);
	local masteryTable_Defender = GetMastery(Defender);	
	local info = {};

	-- 1. 막기는 방어자가 있어야만 한다.
	-- 2. 힐은 막는게 없다.
	if not Defender or Ability.Type == 'Heal' then
		return 0, info, 0;
	end
	
	if Ability.IgnoreBlock then
		return 0, info, 0;
	end
	
	-- 3. 의식불명 상태에서는 방어 불가
	if GetBuffStatus(Defender, 'Unconscious', 'Or') then
		return 0, info, 0;
	end
	-- 4. 대기중에는 막지 못한다.
	if GetBuff(Defender, 'Stand') then
		return 0, info, 0;
	end
	-- 5. 은신 공격은 막지 못한다.
	if GetBuff(Attacker, 'Stealth') then
		return 0, info, 0;
	end
	
	if BlockComposer == nil then
		BlockComposer = BattleFormulaComposer.new('math.max((Base - Reduce) * (1 - ProportionalReduce / 100), 0)', {'Base', 'Reduce', 'ProportionalReduce'});
	end
	local blockComposer = BlockComposer:Clone();
	
	-- 1. 방어자 기본 막기 확률
	local abilityBlock = GetCurrentBlock(info, Ability, Attacker, Defender);
	blockComposer:AddDecompData('Base', abilityBlock, info);
	-- 2. 특정 상황에서만 발생하는 방어율
	local eventInfoAdd = {};
	local eventInfoMinus = {};
	local addBlock, minusBlock = GetModifyAbilityBlockFromEvent(eventInfoAdd, eventInfoMinus, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, missionTime, abilityDetailInfo);
	blockComposer:AddDecompData('Base', addBlock, eventInfoAdd);
	blockComposer:AddDecompData('Reduce', minusBlock, eventInfoMinus);
	
	-- 3. 직업
	if Defender.KnownJobs[Attacker.Job.name] then
		local block = 0.25 * Defender.JobLv;
		if Defender.Job.name == Attacker.Job.name then
			block = block * 2;
		end
		if block ~= 0 then
			blockComposer:AddDecompData('Base', block, {{Type = 'Job', Value = block, ValueType = 'Formula', Job = Attacker.Job.name}});
		end
	end
	
	-- 특성 돌파구
	local mastery_Breakthrough = GetMasteryMastered(masteryTable_Attacker, 'Breakthrough');
	if mastery_Breakthrough then
		blockComposer:AddDecompData('ProportionalReduce', mastery_Breakthrough.ApplyAmount, {{ Type = mastery_Breakthrough.name, Value = mastery_Breakthrough.ApplyAmount, ValueType = 'Mastery' }});
	end
	
	-- 하늘을 뚫어라
	local mastery_DrillSky = GetMasteryMastered(masteryTable_Attacker, 'DrillSky');
	if mastery_DrillSky then
		local distance = GetDistanceFromObjectToObjectAbility(Ability, Attacker, Defender);
		local reduceBlock = mastery_DrillSky.ApplyAmount * distance;
		blockComposer:AddDecompData('Reduce', reduceBlock, {MakeMasteryStatInfo(mastery_DrillSky.name, reduceBlock)});
	end
	
	-- 예측 사격
	local mastery_PredictedFire = GetMasteryMastered(masteryTable_Attacker, 'PredictedFire');
	if mastery_PredictedFire and Ability.HitRateType == 'Force' and IsGetAbilitySubType(Ability, 'Piercing') then
		local reduceBlock = mastery_PredictedFire.ApplyAmount2;
		blockComposer:AddDecompData('Reduce', reduceBlock, {MakeMasteryStatInfo(mastery_PredictedFire.name, reduceBlock)});
	end
	
	-- 나는 전설이다.
	local mastery_ImLegend = GetMasteryMastered(masteryTable_Attacker, 'ImLegend');
	if mastery_ImLegend and SafeIndex(damageFlag, 'CloseCheckFire') then
		local reduce = mastery_ImLegend.ApplyAmount2;
		blockComposer:AddDecompData('Reduce', reduce, {MakeMasteryStatInfo(mastery_ImLegend.name, reduce)});
	end
	
	-- 청경 (방어율)
	local mastery_ListeningEnergy = GetMasteryMastered(masteryTable_Attacker, 'ListeningEnergy');
	if mastery_ListeningEnergy and SafeIndex(damageFlag, 'ReactionAbility') then
		blockComposer:AddDecompData('Reduce', mastery_ListeningEnergy.ApplyAmount2, {MakeMasteryStatInfo(mastery_ListeningEnergy.name, mastery_ListeningEnergy.ApplyAmount2)});
	end
	
	-- 시간차 투척
	local mastery_DelayedThrow = GetMasteryMastered(masteryTable_Attacker, 'DelayedThrow');
	if mastery_DelayedThrow and Ability.HitRateType == 'Throw' then
		blockComposer:AddDecompData('Reduce', mastery_DelayedThrow.ApplyAmount, {MakeMasteryStatInfo(mastery_DelayedThrow.name, mastery_DelayedThrow.ApplyAmount)});
	end
	
	-- 예측 불허
	local mastery_Unpredictability = GetMasteryMastered(masteryTable_Attacker, 'Unpredictability');
	if mastery_Unpredictability and table.exist({'Retribution', 'Devastate', 'Forestallment', 'Counter'}, function(flag) return SafeIndex(damageFlag, flag) ~= nil; end) then
		blockComposer:AddDecompData('Reduce', mastery_Unpredictability.ApplyAmount2, {MakeMasteryStatInfo(mastery_Unpredictability.name, mastery_Unpredictability.ApplyAmount2)});
	end
	
	-- 듀나메스 저격총 IBL - HK
	local mastery_SniperRifle_DynamesIBS_Legend = GetMasteryMastered(masteryTable_Attacker, 'SniperRifle_DynamesIBS_Legend');
	if mastery_SniperRifle_DynamesIBS_Legend and Defender.Race.name == 'Human' and IsGetAbilitySubType(Ability, 'Piercing') and Ability.HitRateType == 'Force' then
		blockComposer:AddDecompData('Reduce', mastery_SniperRifle_DynamesIBS_Legend.ApplyAmount, {MakeMasteryStatInfo(mastery_SniperRifle_DynamesIBS_Legend.name, mastery_SniperRifle_DynamesIBS_Legend.ApplyAmount)});
	end
	
	-- 엘리게이터 블레이드 SS
	local mastery_Sword_Sever_Legend = GetMasteryMastered(masteryTable_Attacker, 'Sword_Sever_Legend');
	if mastery_Sword_Sever_Legend and Defender.Race.name == 'Human' and IsGetAbilitySubType(Ability, 'Slashing') then
		blockComposer:AddDecompData('Reduce', mastery_Sword_Sever_Legend.ApplyAmount, {MakeMasteryStatInfo(mastery_Sword_Sever_Legend.name, mastery_Sword_Sever_Legend.ApplyAmount)});
	end
		
	local resultBlock = blockComposer:ComposeFormula();
	local info = blockComposer:ComposeInfoTable();
	
	-- info 정보 넣기.
	table.sort(info, function (a, b)
		return a.Value > b.Value;
	end);
	info = table.filter(info, function (i) return i.Value ~= 0; end);
	
	local infoValue = 0;
	for index, value in ipairs (info) do
		infoValue = infoValue + value.Value;
	end
	local basicValue = resultBlock - infoValue;
	if basicValue ~= 0 then
		table.insert(info, 1, { Type = 'Block', Value = basicValue, ValueType = 'Formula'});
	end
	return resultBlock, info;
end
--------------------------------------------------------------------------------------------------
-- 기본 방어율. 방어자의 값을 알아와야 한다.
--------------------------------------------------------------------------------------------------
function GetCurrentBlock(info, Ability, Attacker, Defender)
	local arg = 'Block';
	local result = Defender.Block;	
	if result > 0 then
		local statusInfo = GetStatusInfo(Defender, arg);
		local plusInfo, minusInfo = table.split(statusInfo, function(info) return info.Value > 0 end);
		tableAppend(info, plusInfo);
		tableAppend(info, minusInfo);
	end
	return result;
end
--------------------------------------------------------------------------------------------------
-- 특성 등으로 인한 방어율 증가.
--------------------------------------------------------------------------------------------------
function GetModifyAbilityBlockFromEvent(info, infoMinus, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, missionTime, abilityDetailInfo)
	local calcOption = {};
	calcOption.UsePrevAbilityPosition = SafeIndex(Ability, 'AbilityWithMove');
	calcOption.MissionTime = missionTime;
	calcOption.MasteryTable = masteryTable_Defender;
	local result = GetConditionalStatus(Defender, 'Block', info, calcOption);
	local resultMinus = 0;
	
	local myPosition = GetPosition(Attacker);
	if IsClient() and Ability.AbilityWithMove then
		myPosition = GetSession().current_using_pos;
	end

	if Ability.Type ~= 'Heal' then		
		local coverState = GetCoverStateForCritical(Defender, masteryTable_Defender, myPosition, Attacker);
		if coverState ~= 'None' then
			local abilityHitRateTypeList = GetClassList('AbilityHitRateType');
			local curHitRateType = SafeIndex(abilityHitRateTypeList, Ability.HitRateType);
			if curHitRateType and curHitRateType.CoverRatio <= 0 then
				coverState = 'None';
			end
		end
		if coverState ~= 'None' then
			-- 잠복 적용.
			local buff_Conceal = GetBuff(Defender, 'Conceal') or GetBuff(Defender, 'Conceal_For_Aura');
			if buff_Conceal then
				local blockRate_Conceal = 50;
				result = result + blockRate_Conceal;
				table.insert(info, { Type = buff_Conceal.name, Value = blockRate_Conceal, ValueType = 'Buff'});
			end
			
			-- 낮은 엄폐 자세
			local mastery_LowPosition = GetMasteryMastered(masteryTable_Defender, 'LowPosition');
			if mastery_LowPosition then
				local addBlock;
				if coverState == 'Full' then
					addBlock = mastery_LowPosition.ApplyAmount;
				elseif coverState == 'Half' then
					addBlock = mastery_LowPosition.ApplyAmount2;
				end
				result = result + addBlock;
				table.insert(info, MakeMasteryStatInfo(mastery_LowPosition.name, addBlock));
			end
			
			-- 고지대 엄폐
			local mastery_HighPositionCover = GetMasteryMastered(masteryTable_Defender, 'HighPositionCover');
			if mastery_HighPositionCover then
				local attackerHigh, attackerLow = IsAttakerHighPosition(GetHeight(myPosition, GetPosition(Defender)), Attacker, Defender, masteryTable_Attacker, masteryTable_Defender);
				if attackerLow then
					local addBlock;
					if coverState == 'Full' then
						addBlock = mastery_HighPositionCover.ApplyAmount;
					elseif coverState == 'Half' then
						addBlock = mastery_HighPositionCover.ApplyAmount2;
					end
					result = result + addBlock;
					table.insert(info, MakeMasteryStatInfo(mastery_HighPositionCover.name, addBlock));
				end
			end
		end
	end
	
	-- 근접한 적 판단.
	if IsMeleeDistance(GetAbilityUsingPosition(Attacker), GetAbilityUsingPosition(Defender)) then
		-- 검의 영역(공격자)
		local mastery_SwordsmanArea = GetMasteryMastered(masteryTable_Attacker, 'SwordsmanArea');
		if mastery_SwordsmanArea then
			resultMinus = resultMinus + mastery_SwordsmanArea.ApplyAmount2;
			table.insert(infoMinus, MakeMasteryStatInfo(mastery_SwordsmanArea.name, mastery_SwordsmanArea.ApplyAmount2));
		end
		-- 눈부신 칼날.(방어자)
		local mastery_GlaringBlade = GetMasteryMastered(masteryTable_Defender, 'GlaringBlade');
		if mastery_GlaringBlade then
			if Ability.HitRateType == 'Melee' then
				result = result + mastery_GlaringBlade.ApplyAmount2;
				table.insert(info, MakeMasteryStatInfo(mastery_GlaringBlade.name, mastery_GlaringBlade.ApplyAmount2));
			end
		end
	end
	-- 맞잡고 싸우기
	if Ability.Type == 'Attack' then
		local mastery_Grappling = GetMasteryMastered(masteryTable_Defender, 'Grappling');
		if mastery_Grappling then
			local addBlock = mastery_Grappling.ApplyAmount;
			local checkDist = 1.4;
			-- 산
			local mastery_Mountain = GetMasteryMastered(masteryTable_Defender, 'Mountain');
			if mastery_Mountain then
				checkDist = mastery_Mountain.ApplyAmount;
			end
			-- 질풍경초
			local mastery_NeverYields = GetMasteryMastered(masteryTable_Defender, 'NeverYields');
			if mastery_NeverYields then
				addBlock = addBlock + mastery_NeverYields.ApplyAmount;
			end
			if IsMeleeDistanceAbility(Attacker, Defender, checkDist) then
				result = result + addBlock;
				table.insert(info, MakeMasteryStatInfo(mastery_Grappling.name, addBlock));
			end
		end
	end
	
	-- 근접 공격
	if Ability.HitRateType == 'Melee' then
		-- 무도
		local mastery_MartialArt = GetMasteryMastered(masteryTable_Defender, 'MartialArt');
		if mastery_MartialArt then
			result = result + mastery_MartialArt.ApplyAmount;
			table.insert(info, MakeMasteryStatInfo(mastery_MartialArt.name, mastery_MartialArt.ApplyAmount));
		end
		-- 화경.
		local mastery_NeutralizingEnergy = GetMasteryMastered(masteryTable_Defender, 'NeutralizingEnergy');
		if mastery_NeutralizingEnergy then
			result = result + mastery_NeutralizingEnergy.ApplyAmount;
			table.insert(info, MakeMasteryStatInfo(mastery_NeutralizingEnergy.name, mastery_NeutralizingEnergy.ApplyAmount));
		end
		-- 칼날 쳐내기
		local mastery_BladeParry = GetMasteryMastered(masteryTable_Defender, 'BladeParry');
		if mastery_BladeParry then
			result = result + mastery_BladeParry.ApplyAmount;
			table.insert(info, MakeMasteryStatInfo(mastery_BladeParry.name, mastery_BladeParry.ApplyAmount));
		end
		-- 보이지 않는 검
		local mastery_InvisibleSword = GetMasteryMastered(masteryTable_Defender, 'InvisibleSword');
		if mastery_InvisibleSword then
			local targetKey = GetObjKey(Attacker);
			local prevTargets = GetInstantProperty(Defender, 'InvisibleSword') or {};
			if not prevTargets[targetKey] then
				result = result + mastery_InvisibleSword.ApplyAmount;
				table.insert(info, MakeMasteryStatInfo(mastery_InvisibleSword.name, mastery_InvisibleSword.ApplyAmount));
			end
		end
	end
	
	-- 상처 베기
	if Ability.Type == 'Attack' then
		local mastery_SlashInjury = GetMasteryMastered(masteryTable_Attacker, 'SlashInjury');
		if mastery_SlashInjury and (HasBuffType(Defender, nil, nil, 'Bleeding') or HasBuffType(Defender, nil, nil, 'Bruise')) then
			local minusBlock = 0;
			-- 잔인한 검
			local mastery_CruelSword = GetMasteryMastered(masteryTable_Attacker, 'CruelSword');
			if mastery_CruelSword then
				minusBlock = minusBlock + mastery_CruelSword.ApplyAmount2;
			end
			-- 검귀
			local mastery_GhostSword = GetMasteryMastered(masteryTable_Attacker, 'GhostSword');
			if mastery_GhostSword then
				minusBlock = minusBlock + mastery_GhostSword.ApplyAmount;
			end
			if minusBlock ~= 0 then
				resultMinus = resultMinus + minusBlock;
				table.insert(infoMinus, MakeMasteryStatInfo(mastery_SlashInjury.name, minusBlock));
			end
		end
	end
	-- 정밀한 저격
	if Ability.AbilitySubMenu == 'DetailedSnipe' then
		local snipeTypeList = GetClassList('SnipeType');
		local snipeTypeName = SafeIndex(abilityDetailInfo, 'SnipeType') or 'Head';
		local snipeType = SafeIndex(snipeTypeList, snipeTypeName);
		local applyRatio = 100;
		local mastery_Infallibility = GetMasteryMastered(masteryTable_Attacker, 'Infallibility');
		if mastery_Infallibility then
			applyRatio = applyRatio + mastery_Infallibility.ApplyAmount;
		end
		if snipeType and snipeType.EnemyBlock ~= 0 then
			local addBlock = snipeType.EnemyBlock * applyRatio / 100;
			result = result + addBlock;
			table.insert(info, {Type = 'DetailedSnipe', Value = addBlock, ValueType = 'Formula', SnipeType = snipeType.name});
		end
	end
	-- 압도하는 기백
	if Ability.Type == 'Attack' then
		local mastery_HeavyPressure = GetMasteryMastered(masteryTable_Attacker, 'HeavyPressure');
		if mastery_HeavyPressure and Attacker.Lv > Defender.Lv then
			local minusBlock = mastery_HeavyPressure.ApplyAmount;
			-- 영웅의 기백
			local mastery_HeroSpirit = GetMasteryMastered(masteryTable_Attacker, 'HeroSpirit');
			if mastery_HeroSpirit then
				minusBlock = minusBlock + math.floor(GetCurrentSP(Attacker) / mastery_HeroSpirit.ApplyAmount) * mastery_HeroSpirit.ApplyAmount2;
			end
			resultMinus = resultMinus + minusBlock;
			table.insert(infoMinus, MakeMasteryStatInfo(mastery_HeavyPressure.name, minusBlock));
		end
	end
	-- 기계 공학
	if Defender.Race.name == 'Machine' then
		local mastery_MechanicalEngineering = GetMasteryMastered(masteryTable_Attacker, 'MechanicalEngineering') or GetMasteryMastered(masteryTable_Attacker, 'MechanicalEngineering_Machine');
		if mastery_MechanicalEngineering then
			local minusBlock = mastery_MechanicalEngineering.ApplyAmount2;
			resultMinus = resultMinus + minusBlock;
			table.insert(infoMinus, MakeMasteryStatInfo(mastery_MechanicalEngineering.name, minusBlock));
		end
	end
	if Attacker.Race.name == 'Machine' then
		local mastery_MechanicalEngineering = GetMasteryMastered(masteryTable_Defender, 'MechanicalEngineering') or GetMasteryMastered(masteryTable_Defender, 'MechanicalEngineering_Machine');
		if mastery_MechanicalEngineering then
			local addBlock = mastery_MechanicalEngineering.ApplyAmount2;
			result = result + addBlock;
			table.insert(info, MakeMasteryStatInfo(mastery_MechanicalEngineering.name, addBlock));
		end
	end
	-- 대인 살상 훈련
	local mastery_HumanKillTraining = GetMasteryMastered(masteryTable_Defender, 'HumanKillTraining');
	if mastery_HumanKillTraining then
		if Ability.Type == 'Attack' and SafeIndex(Attacker, 'Race', 'name') == 'Human' and GetRelation(Defender, Attacker) == 'Enemy' then
			local addBlock = mastery_HumanKillTraining.ApplyAmount2;
			result = result + addBlock;
			table.insert(info, MakeMasteryStatInfo(mastery_HumanKillTraining.name, addBlock));
		end
	end
	-- 굴하지 않는 기백
	local mastery_UndefeatedSpirit = GetMasteryMastered(masteryTable_Defender, 'UndefeatedSpirit');
	if mastery_UndefeatedSpirit then
		if Ability.Type == 'Attack' and Attacker.Lv > Defender.Lv then
			local addBlock = mastery_UndefeatedSpirit.ApplyAmount;
			-- 영웅의 기백
			local mastery_HeroSpirit = GetMasteryMastered(masteryTable_Defender, 'HeroSpirit');
			if mastery_HeroSpirit then
				addBlock = addBlock + math.floor(GetCurrentSP(Defender) / mastery_HeroSpirit.ApplyAmount) * mastery_HeroSpirit.ApplyAmount2;
			end
			result = result + addBlock;
			table.insert(info, MakeMasteryStatInfo(mastery_UndefeatedSpirit.name, addBlock));
		end
	end
	
	local distance, height = GetDistanceFromObjectToObjectAbility(Ability, Attacker, Defender);
	-- 병렬 처리
	local mastery_ParallelProcessing = GetMasteryMastered(masteryTable_Defender, 'ParallelProcessing');
	if mastery_ParallelProcessing then
		local enableUseCount = 0;
		for _, ability in ipairs(GetEnableProtocolAbilityList(Defender, nil)) do
			if ability.IsUseCount then
				enableUseCount = enableUseCount + ability.UseCount;
			end
		end
		local applyRatio = mastery_ParallelProcessing.ApplyAmount2;
		local mastery_InformationSpecialist = GetMasteryMastered(masteryTable_Defender, 'InformationSpecialist');
		if mastery_InformationSpecialist and distance <= mastery_InformationSpecialist.ApplyAmount2 + 0.4 then
			applyRatio = applyRatio * (1 + mastery_InformationSpecialist.ApplyAmount / 100);
		end
		
		local stepCount = math.floor(enableUseCount / mastery_ParallelProcessing.ApplyAmount);				-- ApplyAmount 당
		if stepCount > 0 then
			local multiplier_ParallelProcessing = stepCount * applyRatio;	-- ApplyAmount2 만큼 증가
			result = result + multiplier_ParallelProcessing;
			table.insert(info, MakeMasteryStatInfo(mastery_ParallelProcessing.name, multiplier_ParallelProcessing));
		end
	end
	
	-- 날카로운 기백
	local mastery_AcuteSpirit = GetMasteryMastered(masteryTable_Attacker, 'AcuteSpirit');
	if mastery_AcuteSpirit and Ability.Type == 'Attack' then
		local minusBlock = math.floor(GetCurrentSP(Attacker) / mastery_AcuteSpirit.ApplyAmount) * mastery_AcuteSpirit.ApplyAmount2;
		if minusBlock ~= 0 then
			resultMinus = resultMinus + minusBlock;
			table.insert(infoMinus, MakeMasteryStatInfo(mastery_AcuteSpirit.name, minusBlock));
		end
	end
	
	-- 투석
	resultMinus = resultMinus + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'ThrowStone', infoMinus, function(mastery)
		if Attacker.ESP and Attacker.ESP.name == 'Earth' then
			local curBlock = GetCurrentBattleValue_SP(Attacker);
			if curBlock then
				return curBlock;
			end
		end
	end);
	
	-- 절망의 불꽃
	resultMinus = resultMinus + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'DespairFlame', infoMinus, function(mastery)
		if Ability.Type == 'Attack' and HasBuffType(Defender, 'Debuff', nil, mastery.BuffGroup.name) and GetRelation(Attacker, Defender) == 'Enemy' then
			local applyAmount = mastery.ApplyAmount;
			-- 초열
			local mastery_Gehenna = GetMasteryMastered(masteryTable_Attacker, 'Gehenna');
			if mastery_Gehenna then
				applyAmount = applyAmount + mastery_Gehenna.ApplyAmount;
			end
			return applyAmount;
		end
	end);
	
	-- 꿰뚫는 일격
	resultMinus = resultMinus + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'PiercingStrikes', infoMinus, function(mastery)
		if Ability.Type == 'Attack' and GetRelation(Attacker, Defender) == 'Enemy' then
			return mastery.ApplyAmount;
		end
	end);
	
	-- 무풍지대
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'CalmZone', info, function(mastery)
		if table.find({'Force', 'Fall', 'Throw'}, Ability.HitRateType) then
			return mastery.ApplyAmount;
		end
	end);
	
	-- 탄환 베기
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'SlashingBullet', info, function(mastery)
		if IsLongDistanceAttack(Ability) then
			return math.floor(GetDistanceFromObjectToObjectAbility(Ability, Attacker, Defender) / mastery.ApplyAmount) * mastery.ApplyAmount2;
		end
	end);
	
	-- 부러지지 않는 검
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'UnbreakableSword', info, function(mastery)
		if Ability.Type == 'Attack' and IsGetAbilitySubType(Ability, 'Slashing') and Ability.HitRateType == 'Melee' then
			return mastery.ApplyAmount;
		end
	end);
	
	-- 해골복/해골 자켓/해골 코트/해골 활동복
	if IsDarkTime(missionTime) and (Ability.HitRateType == 'Force' or Ability.HitRateType == 'Throw' or Ability.HitRateType == 'Fall') then
		local mastery_ScullArmor = GetMasteryMasteredList(masteryTable_Defender, {'Jacket_Skull', 'Jacket_Skull_Legend', 'Coat_Skull_Legend', 'Tracksuit_Skull_Legend'});
		if mastery_ScullArmor then
			result = result + mastery_ScullArmor.ApplyAmount;
			table.insert(info, MakeMasteryStatInfo(mastery_ScullArmor.name, mastery_ScullArmor.ApplyAmount));
		end
	end
	
	-- 황금 어금니 부적
	resultMinus = resultMinus + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'Amulet_Neguri_GoldAttack_Set', infoMinus, function(mastery)
		if Ability.Type == 'Attack' and Ability.HitRateType == 'Melee' and GetRelation(Attacker, Defender) == 'Enemy' and HasBuffType(Defender, 'Debuff', 'Physical') then
			return mastery.ApplyAmount;
		end
	end);
	
	-- 무도의 빛 - 3 세트
	resultMinus = resultMinus + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'GoldNeguriAttackSet3', infoMinus, function(mastery)
		if Ability.Type == 'Attack' and Ability.HitRateType == 'Melee' and GetRelation(Attacker, Defender) == 'Enemy' then
			return mastery.ApplyAmount;
		end
	end);
	
	-- 황금 송곳니
	resultMinus = resultMinus + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'Amulet_Tima_Gold', infoMinus, function(mastery)
		if Ability.Type == 'Attack' and Ability.HitRateType == 'Melee' and GetRelation(Attacker, Defender) == 'Enemy' then
			return mastery.ApplyAmount;
		end
	end);
	
	-- 플람베
	resultMinus = resultMinus + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'Flambee', infoMinus, function(mastery)
		if Ability.Type == 'Attack' and IsGetAbilitySubType(Ability, 'Fire') and IsObjectOnFieldEffect(Defender, 'Fire') then
			return mastery.ApplyAmount;
		end
	end);
	
	-- 유리한 저격 위치
	resultMinus = resultMinus + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'PositionOfAdvantageOnSnipe', infoMinus, function(mastery)
		local attackerHigh, attackerLow = IsAttakerHighPosition(GetHeight(myPosition, GetPosition(Defender)), Attacker, Defender, masteryTable_Attacker, masteryTable_Defender);
		if attackerHigh or IsStableAttack(Attacker) then
			return mastery.ApplyAmount;
		end
	end);

	-- 살수의 길
	resultMinus = resultMinus + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'RoadOfKiller', infoMinus, function(mastery)
		if Defender.Race.name == 'Human' then
			return mastery.ApplyAmount;
		end
	end);
	
	-- 감춰진 살의
	resultMinus = resultMinus + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'HiddenMurderousIntent', infoMinus, function(mastery)
		if Ability.Type == 'Attack' and Ability.HitRateType == 'Melee' and GetRelation(Attacker, Defender) == 'Enemy' then
			local targetKey = GetObjKey(Defender);
			local prevTargets = GetInstantProperty(Attacker, mastery.name) or {};
			if not prevTargets[targetKey] then
				return mastery.ApplyAmount;
			end
		end
	end);
	
	-- 무모함
	resultMinus = resultMinus + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'Recklessness', infoMinus, function(mastery)
		if Ability.Type == 'Attack' and HasBuffType(Defender, nil, nil, mastery.BuffGroup.name) then
			return mastery.ApplyAmount2;
		end
	end);
	
	result = result + GetBlockByTroublemaker(info, Attacker, Defender);
	return result, resultMinus;
end
------------------------------------------------------------------------------------------------
-------------------------------------- 치명타 피해량 계산 공식 ----------------------------------
------------------------------------------------------------------------------------------------
function GetCriticalStrikeDealCalculator(Attacker, Defender, Ability, abilityDetailInfo)
	local masteryTable_Attacker = GetMastery(Attacker);
	local masteryTable_Defender = GetMastery(Defender);
	
	local info = {};
	local totalCriticalStrikeDeal = 0;
	if Ability.Type == 'Heal' and (Ability.ItemAbility or Ability.SubType == 'None') then
		return totalCriticalStrikeDeal, info;
	end
	if Ability.DamageType == 'Explosion' then
		return totalCriticalStrikeDeal, info;	
	end	
	-- 1. 공격자 치명타 피해량.
	local abilityCriticalStrikeDeal = GetCurrentCriticalStrikeDeal(info, Ability, Attacker);
	-- 2. 스탯으로 인한 상승하는 공격자 치명타 피해량
	local passiveCriticalStrikeDeal = GetModifyAbilityCriticalStrikeDealFromStatus(info, Ability, Attacker);
	totalCriticalStrikeDeal = abilityCriticalStrikeDeal + passiveCriticalStrikeDeal;
	-- 3. 특정 상황에서만 발생하는 치명타 피해량
	local addCriticalStrikeDeal = GetModifyAbilityCriticalStrikeDealFromEvent(info, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, abilityDetailInfo);
	totalCriticalStrikeDeal = totalCriticalStrikeDeal + addCriticalStrikeDeal;
	
	-- 4. 최종 치명타 피해랑 변경
	if totalCriticalStrikeDeal > 0 then
		-- 특성 탄성
		local mastery_Module_Elasticity = GetMasteryMastered(masteryTable_Defender, 'Module_Elasticity');
		if mastery_Module_Elasticity then
			local addCriticalStrikeDeal = -1 * math.floor(totalCriticalStrikeDeal * mastery_Module_Elasticity.ApplyAmount) / 100;
			totalCriticalStrikeDeal = totalCriticalStrikeDeal + addCriticalStrikeDeal;
			table.insert(info, MakeMasteryStatInfo(mastery_Module_Elasticity.name, addCriticalStrikeDeal));
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
	local basicValue = totalCriticalStrikeDeal - infoValue;
	if basicValue ~= 0 then
		table.insert(info, 1, { Type = 'CriticalStrikeDeal', Value = basicValue, ValueType = 'Formula'});
	end
	return math.max(totalCriticalStrikeDeal, 0), info;
end
------------------------------------------------------------------------------
-- 기본 치명타 피해량 수치 얻어오기.
------------------------------------------------------------------------------
function GetCurrentCriticalStrikeDeal(info, Ability, Attacker)
	local arg = 'CriticalStrikeDeal';
	local result = Attacker.CriticalStrikeDeal + Ability.CriticalStrikeDeal;
	if Ability.CriticalStrikeDeal ~= 0 then
		table.insert(info, { Type = Ability.name, Value = Ability.CriticalStrikeDeal, ValueType = 'Ability'});
	end
	tableAppend(info, GetStatusInfo(Attacker, arg));
	result = result + GetConditionalStatus(Attacker, 'CriticalStrikeDeal', info, {});
	return result;
end
function GetModifyAbilityCriticalStrikeDealFromEvent(info, Ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender, abilityDetailInfo)
	local result = 0;
	if not IsMission() then
		return result;
	end
	
	-- 특성 마검
	if IsGetAbilitySubType(Ability, 'ESP') then
		local mastery_MagicalSword = GetMasteryMastered(masteryTable_Attacker, 'MagicalSword');
		if mastery_MagicalSword then
			local addCriticalStrikeDeal = math.floor(Attacker.AttackPower * mastery_MagicalSword.ApplyAmount2 / 100);
			result = result + addCriticalStrikeDeal;
			table.insert(info, MakeMasteryStatInfo(mastery_MagicalSword.name, addCriticalStrikeDeal));
		end
	end
	
	-- 강철 갑옷
	local mastery_IronArmor = GetMasteryMastered(masteryTable_Defender, 'IronArmor');
	if mastery_IronArmor then
		local applyAmount = mastery_IronArmor.ApplyAmount;
		-- 강철의 전투법사
		local mastery_IronBattleMage = GetMasteryMastered(masteryTable_Defender, 'IronBattleMage');
		if mastery_IronBattleMage then
			applyAmount = applyAmount + mastery_IronBattleMage.ApplyAmount;
		end
		result = result - applyAmount;
		table.insert(info, MakeMasteryStatInfo(mastery_IronArmor.name, -applyAmount));
	end	
		
	-- 균열 예측 AI
	local mastery_PredictionCrackingAI = GetMasteryMastered(masteryTable_Defender, 'PredictionCrackingAI');
	if mastery_PredictionCrackingAI and GetRelation(Attacker, Defender) == 'Enemy' then
		result = result - mastery_PredictionCrackingAI.ApplyAmount2;
		table.insert(info, MakeMasteryStatInfo(mastery_PredictionCrackingAI.name, -mastery_PredictionCrackingAI.ApplyAmount2));
	end
	
	-- 대인 살상 훈련
	local mastery_HumanKillTraining = GetMasteryMastered(masteryTable_Attacker, 'HumanKillTraining');
	if mastery_HumanKillTraining then
		if Ability.Type == 'Attack' and SafeIndex(Defender, 'Race', 'name') == 'Human' and GetRelation(Attacker, Defender) == 'Enemy' then
			local addCriticalStrikeDeal = mastery_HumanKillTraining.ApplyAmount2;
			result = result + addCriticalStrikeDeal;
			table.insert(info, MakeMasteryStatInfo(mastery_HumanKillTraining.name, addCriticalStrikeDeal));
		end
	end
	
	-- 보조 제어 프로그램
	local mastery_Module_SubControl = GetMasteryMastered(masteryTable_Defender, 'Module_SubControl');
	if mastery_Module_SubControl then
		local addCriticalStrikeDeal = -1 * math.floor(mastery_Module_SubControl.CustomCacheData / mastery_Module_SubControl.ApplyAmount) * mastery_Module_SubControl.ApplyAmount2;
		if addCriticalStrikeDeal ~= 0 then
			result = result + addCriticalStrikeDeal;
			table.insert(info, MakeMasteryStatInfo(mastery_Module_SubControl.name, addCriticalStrikeDeal));
		end
	end
	
	-- 고급 반동 제어 프로그램
	local mastery_Module_HighControlReactor = GetMasteryMastered(masteryTable_Attacker, 'Module_HighControlReactor');
	if mastery_Module_HighControlReactor and Ability.Type == 'Attack' and not Attacker.TurnState.Moved then
		local addCriticalStrikeDeal = math.floor(Attacker.Load / mastery_Module_HighControlReactor.ApplyAmount3) * mastery_Module_HighControlReactor.ApplyAmount2;
		if addCriticalStrikeDeal > 0 then
			result = result + addCriticalStrikeDeal;
			table.insert(info, MakeMasteryStatInfo(mastery_Module_HighControlReactor.name, addCriticalStrikeDeal));
		end
	end
	
	-- 나는 할 수 있다.
	local mastery_ICanDoIt = GetMasteryMastered(masteryTable_Attacker, 'ICanDoIt');
	if mastery_ICanDoIt then
		if Ability.HitRateType == 'Force' then
			local race = SafeIndex(Defender, 'Race', 'name');
			local armorType = SafeIndex(Defender, 'Body', 'Type', 'ItemUpgradeType');
			if race == 'Machine' or armorType == 'Metal' then
				local addAmount = mastery_ICanDoIt.ApplyAmount;
				result = result + addAmount;
				table.insert(info, MakeMasteryStatInfo(mastery_ICanDoIt.name, addAmount));
			end
		end
	end
	
	-- 숨결주머니
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Attacker, 'BreathSac', info, function(mastery)
		if Ability.Type == 'Attack' and Ability.HitRateType == 'Force' then
			return math.floor(mastery.CustomCacheData['ESP'] / mastery.ApplyAmount) * mastery.ApplyAmount3;
		end
	end);
		
	-- 물러서지 않는 자 - 2 세트
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'DrakyGuardianSet2', info, function(mastery)
		return -1 * mastery.ApplyAmount;
	end);
	
	-- 드라키의 완벽한 비늘
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'Amulet_Draky_Scale3', info, function(mastery)
		return -1 * mastery.ApplyAmount;
	end);
	
	-- 물렁살
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'TenderSkin', info, function(mastery)
		return -1 * mastery.ApplyAmount;
	end);
	
	return result;
end
function GetModifyAbilityCriticalStrikeDealFromStatus(info, Ability, Attacker)
	-- 2. 서브 타입 특성에 의한 증감.
	local result = 0;
	local InfoAdder = function(stat)
		local status = Attacker[stat];
		if status and status ~= 0 then
			result = result + status;
			tableAppend(info, GetStatusInfo(Attacker, stat));
		end
	end
	if Ability.Type == 'Attack' then
		if Ability.SubType ~= 'None' then
			local superType = GetAbilitySuperType(Ability);
			if superType ~= nil then
				InfoAdder('IncreaseCriticalStrikeDeal_'..superType);
			end
			InfoAdder('IncreaseCriticalStrikeDeal_'..Ability.SubType);
		end
		if Ability.HitRateType ~= 'None' then
			InfoAdder('IncreaseCriticalStrikeDeal_'..Ability.HitRateType);
		end
	end
	return result;
end
------------------------------------------------------------------------------------------------
-------------------------------------- 헤드샷 확률 계산 공식 ----------------------------------
------------------------------------------------------------------------------------------------
function IsEnableHeadshot(Attacker, Ability, abilityDetailInfo)
	-- 정밀한 저격
	local snipeType = nil;
	if Ability.AbilitySubMenu == 'DetailedSnipe' then
		local snipeTypeList = GetClassList('SnipeType');
		local snipeTypeName = SafeIndex(abilityDetailInfo, 'SnipeType');
		if snipeTypeName then
			snipeType = SafeIndex(snipeTypeList, snipeTypeName);
		end
	end
	if snipeType then
		return snipeType.HeadShotRatio > 0;
	end
	-- 특성 헤드샷
	local masteryTable_Attacker = GetMastery(Attacker);
	local mastery_HeadShot = GetMasteryMastered(masteryTable_Attacker, 'HeadShot');
	if mastery_HeadShot then
		return true;
	end
end
function IsHeadshotImmuned(Defender)
	local isImmuned = false;
	local reason = {};
	
	-- 버프 연막
	local buff_SmokeScreen = GetBuff(Defender, 'SmokeScreen');
	if buff_SmokeScreen then
		isImmuned = true;
		table.insert(reason, 'Buff_'..buff_SmokeScreen.name);
	end
	local masteryTable_Defender = GetMastery(Defender);
	-- 특성 강철 투구
	local mastery_IronHelmet = GetMasteryMastered(masteryTable_Defender, 'IronHelmet');
	if mastery_IronHelmet then
		isImmuned = true;
		table.insert(reason, 'Mastery_'..mastery_IronHelmet.name);
	end
	-- 특성(아이템) 물러서지 않는 자 - 2 세트
	local mastery_DrakyGuardianSet2 = GetMasteryMastered(masteryTable_Defender, 'DrakyGuardianSet2');
	if mastery_DrakyGuardianSet2 then
		isImmuned = true;
		table.insert(reason, 'Mastery_'..mastery_DrakyGuardianSet2.name);
	end

	return isImmuned, reason;
end
function GetHeadshotRateCalculator(Attacker, Defender, Ability, abilityDetailInfo)
	local masteryTable_Attacker = GetMastery(Attacker);
	
	local totalHeadshotRate = 0;
	local maxHeadshotRate = 0;

	local info = {};
	-- 헤드샷 가능 유무
	if not IsEnableHeadshot(Attacker, Ability, abilityDetailInfo) then
		return totalHeadshotRate, info, maxHeadshotRate;
	end
	
	-- 특성 헤드샷
	local mastery_HeadShot = GetMasteryMastered(masteryTable_Attacker, 'HeadShot');
	if mastery_HeadShot then
		local prop = mastery_HeadShot.ApplyAmount;
		-- 특성 넌 이미 죽어 있다.
		local mastery_AlreadyYoudie = GetMasteryMastered(masteryTable_Attacker, 'AlreadyYoudie');
		if mastery_AlreadyYoudie then
			prop = prop + mastery_AlreadyYoudie.ApplyAmount;
		end
		totalHeadshotRate = totalHeadshotRate + prop;
		table.insert(info, MakeMasteryStatInfo(mastery_HeadShot.name, prop));
	end
	
	-- 버프 목표 확인
	local buff_TargetChecking = GetBuff(Attacker, 'TargetChecking');
	if buff_TargetChecking and buff_TargetChecking.ReferenceTarget == GetObjKey(Defender) then
		local prop = buff_TargetChecking.ApplyAmount3;
		totalHeadshotRate = totalHeadshotRate + prop;
		table.insert(info, { Type = buff_TargetChecking.name, Value = prop, ValueType = 'Buff' });
	end
	
	-- 정밀한 저격 (헤드샷 확률 추가)
	local snipeType = nil;
	if Ability.AbilitySubMenu == 'DetailedSnipe' then
		local snipeTypeList = GetClassList('SnipeType');
		local snipeTypeName = SafeIndex(abilityDetailInfo, 'SnipeType');
		if snipeTypeName then
			snipeType = SafeIndex(snipeTypeList, snipeTypeName);
		end
	end
	if snipeType and snipeType.HeadShotRatio > 0 then
		local ratio = 100;
		-- 특성 백발백중
		local mastery_Infallibility = GetMasteryMastered(masteryTable_Attacker, 'Infallibility');
		if mastery_Infallibility then
			ratio = ratio + mastery_Infallibility.ApplyAmount;
		end
		local prop = snipeType.HeadShotRatio * ratio / 100;
		totalHeadshotRate = totalHeadshotRate + prop;
		table.insert(info, { Type = 'DetailedSnipe', Value = prop, ValueType = 'Formula', SnipeType = snipeType.name });
	end
	
	maxHeadshotRate = math.floor(totalHeadshotRate*100)/100;
	local resultHeadshotRate = math.max(0, math.min(maxHeadshotRate, 100));
	
	-- info 정보 넣기.
	table.sort(info, function (a, b)
		return a.Value > b.Value;
	end);
	local infoValue = 0;
	for index, value in ipairs (info) do
		infoValue = infoValue + value.Value;
	end
	local basicValue = math.floor((maxHeadshotRate - infoValue) * 100) / 100;
	if basicValue ~= 0 then
		table.insert(info, 1, { Type = 'Headshot', Value = basicValue, ValueType = 'Formula'});
	end
	
	return resultHeadshotRate, info, maxHeadshotRate;
end
------------------------------------------------------------------------------
-- 대상의 Cost 타입이 적용 대상인지
------------------------------------------------------------------------------
function IsValidCostType(target, applyCostType)
	-- 기본값으로 모든 Cost 타입을 허용
	if #applyCostType == 0 then
		return true;
	end
	for _, costType in ipairs(applyCostType) do
		if target.CostType.name == costType.name then
			return true;
		end
	end
	return false;
end
------------------------------------------------------------------------------
-- 어빌리티 피격에 의한 Cost 변화량 계산
------------------------------------------------------------------------------
function GetAbilityApplyCost(Ability, Attacker, Defender)
	local applyCost = Ability.ApplyCost;
	if not IsValidCostType(Defender, Ability.ApplyCostType) then
		return 0;
	end
	if Ability.CostBurnRatio > 0 then
		local costBurn = math.floor(Defender.Cost * Ability.CostBurnRatio / 100);
		if costBurn > 0 then
			applyCost = applyCost - costBurn;
		end
	end
	return applyCost;
end

--------------------------------------------------------------------
-- 어빌리티 피격에 의한 SP변화량 계산 (SP에 영향을 주는 어빌리티만 넣어야 함)
--------------------------------------------------------------------
function GetAbilityApplySP(Ability, Attacker, Defender)
	local reasons = {};
	local addSP = Ability.ApplyAmount;
	if Ability.name == 'Charging' then
		local masteryTable = GetMastery(Attacker);
		local mastery_Awakening = GetMasteryMastered(masteryTable, 'Awakening');
		if mastery_Awakening then
			addSP = Defender.MaxSP - Defender.SP;
			if addSP > 0 then
				table.insert(reasons, { Type = mastery_Awakening.name, ValueType = 'Mastery' });
			end
		end
	elseif Ability.RestoreMaxSP then
		addSP = Defender.MaxSP - Defender.SP;
	end
	return addSP, reasons;
end
------------------------------------------------------------------------------------------------
-------------------------------------- 범위안의 적 구하는 함수  ----------------------------------
------------------------------------------------------------------------------------------------
function GetTargetInRange(obj, ability)
	local range = ability.TargetRange;
	local abilityTarget = ability.Target;
	local applyTarget = ability.ApplyTarget;
	local curMission = GetMission(obj);
	local range = CalculateRange(obj, range, GetPosition(obj));
	local loseIff = ObjectLoseIFF(obj);
	local ret = {};
	for i, pos in ipairs(range) do
		local target = GetObjectByPosition(curMission, pos);
		if target ~= nil and ((loseIff and obj ~= target) or GetRelation(obj, target) == applyTarget) and not target.Untargetable then
			table.insert(ret, target);
		end
	end	
	return ret;
end
------------------------------------------------------------------------------------------------
-- 자신의 시야 내 들어오는 일정 범위 내 적 구하는 함수  
------------------------------------------------------------------------------------------------
-- range 는 레인지 테이블 범위, 
-- relation Team, Enemy, Ally, None, All
-- isMySight true : 오브젝트 시야, false : 팀시야.
function GetTargetInRangeSightReposition(usePrevPos, obj, range, relation, isMySight, allowSelf)
	if IsMissionServer() and usePrevPos then
		local curPos = GetPosition(obj);
		local prevPos = GetInstantProperty(obj, 'AbilityPrevPosition') or GetPosition(obj);
		SetPosition(obj, prevPos);
		local ret = GetTargetInRangeSight(obj, range, relation, isMySight, allowSelf);
		SetPosition(obj, curPos);
		return ret;
	else
		return GetTargetInRangeSight(obj, range, relation, isMySight, allowSelf);
	end
end
function GetTargetInRangeSight(obj, range, relation, isMySight, allowSelf)
	if isMySight == nil then
		isMySight = false;
	end
	local relationSet = Set.new(string.split(relation, '|'));
	local range = CalculateRange(obj, range, GetPosition(obj));
	local list = {};
	for i, pos in ipairs(range) do
		local target = nil;
		if IsClient() then	-- 클라이언트 미션 모드
			target = GetObjectByPosition(pos);
		else	-- 미션 서버
			local mission = GetMission(obj);
			target = GetObjectByPosition(mission, pos);
		end
		
		if target then
			if IsInSight(obj, pos, isMySight) then
				if (allowSelf or obj ~= target) and (not target.Untargetable) then
					if relation == 'All' then
						table.insert(list, target);
					elseif relationSet[GetRelation(obj, target)] then
						table.insert(list, target);
					end
				end
			end
		end
	end
	return list;	
end
------------------------------------------------------------------------------------------------
-- 일정 범위 내 지형효과 개수 구하는 함수  
------------------------------------------------------------------------------------------------
function GetFieldEffectCountInRangeReposition(usePrevPos, obj, range, fieldEffectType)
	if IsMissionServer() and usePrevPos then
		local curPos = GetPosition(obj);
		local prevPos = GetInstantProperty(obj, 'AbilityPrevPosition') or GetPosition(obj);
		SetPosition(obj, prevPos);
		local ret = GetFieldEffectCountInRange(obj, range, fieldEffectType);
		SetPosition(obj, curPos);
		return ret;
	else
		return GetFieldEffectCountInRange(obj, range, fieldEffectType);
	end
end
function GetFieldEffectCountInRange(obj, range, fieldEffectType)
	local targetCount = 0;
	local targetRange = CalculateRange(obj, range, GetPosition(obj));
	for _, pos in ipairs(targetRange) do
		local instances = nil;
		if IsClient() then	-- 클라이언트 미션 모드
			instances = GetFieldEffectByPosition(pos);
		else	-- 미션 서버
			local mission = GetMission(obj);
			instances = GetFieldEffectByPosition(mission, pos);
		end
		if instances then
			for _, instance in ipairs(instances) do
				if instance.Owner.name == fieldEffectType then
					targetCount = targetCount + 1;
					break;
				end
			end
		end
	end	
	return targetCount;	
end
------------------------------------------------------------------------------------------------
-- 타겟들 소트 함수.
------------------------------------------------------------------------------------------------
-- condition Min, Max
function GetTargetByDistance(obj, targetList, condition)
	local list = {};
	for index, target in ipairs (targetList) do
		local distance, height = GetDistanceFromObjectToObject(obj, target);
		table.insert(list, { Target = target, Distance = distance});
	end
	table.sort(list, function (a, b)
		return a.Distance < b.Distance;
	end);
	return list;
end
-------------------------------------------------------------------------------
----------------------------------------------------------------
-- 패시브 정보 받아오기.
----------------------------------------------------------------
--------------------------------------------------------------------------------
function GetStatusInfo(obj, arg, inverse, includeEquipment, masteryList, info)
	info = info or {};
	
	local spStat = _G['CalculatedProperty_SpecialCase_' .. arg];
	if spStat then
		local _, spInfo = spStat(obj, arg, nil);
		if spInfo then
			table.append(info, spInfo);
		end
	end
	--[[
	-- 직업 스탯 값은 Info를 리턴하면 안됨.. 기본 스탯을 계산할때 위 값을 따로 계산해서 넣기 때문에 중복으로 등장할 수 있음.
	local jobStat = _G['CalculatedProperty_JobStatus_' .. arg];
	if jobStat then
		local _, jobInfo = jobStat(obj.Job, arg, obj.Lv)
		if jobInfo then
			table.append(info, jobInfo);
		end
	end
	]]
	-- 미션이 아니면 버프 그런 거 없다.
	if IsMission() then
		local buffList = GetBuffList(obj);
		for index, buff in ipairs (buffList) do
			local curStatus = GetWithoutError(buff, arg);
			if curStatus and curStatus ~= 0 then
				if inverse then
					curStatus = -1 * curStatus;
				end
				table.insert(info, { Type = buff.name, Value = curStatus, ValueType = 'Buff'});
			end
		end
	end
	if masteryList == nil then
		masteryList = GetMastery(obj);
	end
	for key, mastery in pairs (masteryList) do
		if mastery.Lv > 0 then
			local curStatus = GetWithoutError(mastery, arg);
			if curStatus and curStatus ~= 0 then
				if inverse then
					curStatus = -1 * curStatus;
				end
				if mastery.Type.name ~= 'EquipmentSet' then
					table.insert(info, { Type = mastery.name, Value = curStatus, ValueType = 'Mastery'});
				else
					table.insert(info, { Type = mastery.name, Value = curStatus, ValueType = 'EquipmentSet'});
				end
			end
		end
	end
	if includeEquipment then
		local itemSlotList = GetItemSlotList();
		for _, itemSlot in ipairs(itemSlotList) do
			local curEquip = GetWithoutError(obj, itemSlot);
			if curEquip ~= nil then
				local curStatus = GetWithoutError(curEquip, arg);
				if curStatus and curStatus ~= 0 then
					if inverse then
						curStatus = -1 * curStatus;
					end
					table.insert(info, { Type = itemSlot, Value = curStatus, ValueType = 'EquipmentPosition'});
				end
			end
		end
	end
	
	local script = _G['CalculatedProperty_SpecialCase_Mastery_'..arg];
	if script ~= nil then
		local addStat, newInfo = script(obj, arg, data);
		table.append(info, newInfo);
	end
	
	-- 공연 효과
	if obj.PerformanceType ~= 'None' then
		local addStat, newInfo = CalculatedProperty_Status_PerformanceEffect(obj, arg, data);
		table.append(info, newInfo);
	end
	
	return info;
end
-------------------------------------------------------------------------------
----------------------------------------------------------------
-- 곱하기 연산자 정보 풀기.
----------------------------------------------------------------
--------------------------------------------------------------------------------
function AppendMultiplierTable(t, multiplierTable, baseValue)
	for index, multiplier in ipairs (multiplierTable) do
		multiplier.Value = math.floor(multiplier.Value * baseValue/100);
		table.insert(t, multiplier);
	end		
end
----------------------------------------------------------------
-- 확률 판단기 : 이게 바뀌면 버그 쩜.
----------------------------------------------------------------
--------------------------------------------------------------------------------
function RandomTest(value)
	if value <= 0 then
		return false;
	end
	if value >= 100 then
		return true;
	end
	return (value > math.random() * 100);
end
----------------------------------------------------------------
-- 기절 판단기 : 이게 바뀌면 버그 쩜. DoNothingAI
----------------------------------------------------------------
--------------------------------------------------------------------------------
function HasActionControllerTest(obj, aiTypeList)
	local buffList = GetBuffList(obj);
	for i = 1, #buffList do
		local curBuff = buffList[i];
		if curBuff.UseActionController then
			if table.find(aiTypeList, curBuff.ActionController) then
				return true;
			end
		end
	end	
	return false;
end
function DoNothingAITest(obj)
	return HasActionControllerTest(obj, { 'DoNothingAI' });
end
----------------------------------------------------------------
-- 어빌리티 조건 판단.
----------------------------------------------------------------
function IsESPType(type)
	return type == 'Fire' or type == 'Ice' or type == 'Lightning' or type == 'Wind' or type == 'Earth' or type == 'Water';
end
function IsPhysicalType(type)
	return type == 'Slashing' or type == 'Piercing' or type == 'Blunt';
end
function IsGetAbilitySubType(ability, arg)
	-- 기본 SubType과 같은면 true;
	if ability.SubType == arg then
		return true;
	end	
	if arg == 'ESP' then
		if IsESPType(ability.SubType) then
			return true;
		end
	elseif arg == 'Physical' then
		if IsPhysicalType(ability.SubType) then
			return true;
		end		
	end
	return false;
end
function GetAbilitySuperType(ability)
	-- 기본 SubType과 같은면 true;
	if IsESPType(ability.SubType) then
		return 'ESP';
	elseif IsPhysicalType(ability.SubType) then
		return 'Physical';
	else
		return nil;
	end
end
----------------------------------------------------------------
-- 어빌리티 사용 시점의 Cost 받아가는 함수.
----------------------------------------------------------------
function GetCurrentCost(target)
	return target.Cost + (GetInstantProperty(target, 'InstantCost') or 0);
end
----------------------------------------------------------------
-- SP로 상시 증감하는 값 받아가는 함수.
----------------------------------------------------------------
function GetCurrentSP(target)
	return target.SP + (GetInstantProperty(target, 'InstantSP') or 0);
end
function GetCurrentBattleValue_SP(target)
	if not target.ESP or not target.ESP.name then
		return nil;
	end
	local stepCount = math.floor(GetCurrentSP(target) / target.ESP.ApplySPStep);
	local result = GetApplyESPValue(target) * stepCount;
	return result;
end
function GetApplyESPValue(target)
	if not target.ESP or not target.ESP.name then
		return 0;
	end
	local result = target.ESP.ApplySPValue;
	if target.ESP.name == 'Fire' then
		local masteryTable = GetMastery(target);
		-- 심연의 불꽃
		local mastery_FlameAbyss = GetMasteryMastered(masteryTable, 'FlameAbyss');
		if mastery_FlameAbyss then
			result = result * mastery_FlameAbyss.ApplyAmount;
		end
	elseif target.ESP.name == 'Ice' then
		local masteryTable = GetMastery(target);
		-- 절망의 한기
		local mastery_FrostDespair = GetMasteryMastered(masteryTable, 'FrostDespair');
		if mastery_FrostDespair then
			result = result * mastery_FrostDespair.ApplyAmount;
		end
	elseif target.ESP.name == 'Earth' then
		local masteryTable = GetMastery(target);
		-- 풍요의 여신
		local mastery_EarthMother = GetMasteryMastered(masteryTable, 'EarthMother');
		if mastery_EarthMother then
			result = result * mastery_EarthMother.ApplyAmount;
		end
	elseif target.ESP.name == 'Wind' then
		local masteryTable = GetMastery(target);
		-- 폭풍의 검
		local mastery_WindstormSword = GetMasteryMastered(masteryTable, 'WindstormSword');
		if mastery_WindstormSword then
			result = result * mastery_WindstormSword.ApplyAmount;
		end
	elseif target.ESP.name == 'Lightning' then
		local masteryTable = GetMastery(target);
		-- 분노의 벼락
		local mastery_RageLightning = GetMasteryMastered(masteryTable, 'RageLightning');
		if mastery_RageLightning then
			result = result * mastery_RageLightning.ApplyAmount;
		end
	elseif target.ESP.name == 'Water' then
		local masteryTable = GetMastery(target);
		-- 폭우
		local mastery_HeavyRain = GetMasteryMastered(masteryTable, 'HeavyRain');
		if mastery_HeavyRain then
			result = result * mastery_HeavyRain.ApplyAmount;
		end
	elseif target.ESP.name == 'Spirit' then
		local masteryTable = GetMastery(target);
		-- 극의
		local mastery_ExtremeSpirit = GetMasteryMastered(masteryTable, 'ExtremeSpirit');
		if mastery_ExtremeSpirit then
			result = result * mastery_ExtremeSpirit.ApplyAmount;
		end
	end
	return result;
end
----------------------------------------------------------------
-- 트러블메이커 정보 보정 함수.
----------------------------------------------------------------
function GetModifyAbilityAccuracyFromEvent_Troublemaker(info, Attacker, Defender)
	local result = 0;
	local tmGrade = Defender.TroublemakerGradeMap[GetTeam(Attacker)];
	if tmGrade and tmGrade >= 1 then
		local addAccuracy = 3;
		local increaseAmount = 0;
		local masteryTable = GetMastery(Attacker);
		-- 특성 사전 정보
		local mastery_PriorInformation = GetMasteryMastered(masteryTable, 'PriorInformation');
		if mastery_PriorInformation then
			increaseAmount = increaseAmount + mastery_PriorInformation.ApplyAmount;
			local mastery_EarlyBird = GetMasteryMastered(masteryTable, 'EarlyBird');
			if tmGrade == 7 and mastery_EarlyBird then
				increaseAmount = increaseAmount + mastery_EarlyBird.ApplyAmount2;
			end
		end
		-- 특성 적 정보 분석
		local mastery_Module_PriorInformation = GetMasteryMastered(masteryTable, 'Module_PriorInformation');
		if mastery_Module_PriorInformation then
			increaseAmount = increaseAmount + mastery_Module_PriorInformation.ApplyAmount;
			-- 특성 정보 제어 프로그램
			local mastery_Module_InformationControl = GetMasteryMastered(masteryTable, 'Module_InformationControl');
			if mastery_Module_InformationControl then
				increaseAmount = increaseAmount + mastery_Module_InformationControl.ApplyAmount2;
			end
		end
		addAccuracy = addAccuracy * (1 + increaseAmount/100);
		result = result + addAccuracy;
		table.insert(info, { Type = 'TMGrade', Value = addAccuracy, ValueType = 'Formula' });
	end
	return result;
end
function GetCurrentDodge_Troublemaker(info, Attacker, Defender)
	local result = 0;
	local tmGrade = Attacker.TroublemakerGradeMap[GetTeam(Defender)];
	if tmGrade and tmGrade >= 2 then
		local addDodge = 3;
		local increaseAmount = 0;
		local masteryTable = GetMastery(Defender);
		-- 특성 사전 정보
		local mastery_PriorInformation = GetMasteryMastered(masteryTable, 'PriorInformation');
		if mastery_PriorInformation then
			increaseAmount = increaseAmount + mastery_PriorInformation.ApplyAmount;
			local mastery_EarlyBird = GetMasteryMastered(masteryTable, 'EarlyBird');
			if tmGrade == 7 and mastery_EarlyBird then
				increaseAmount = increaseAmount + mastery_EarlyBird.ApplyAmount2;
			end
		end
		-- 특성 적 정보 분석
		local mastery_Module_PriorInformation = GetMasteryMastered(masteryTable, 'Module_PriorInformation');
		if mastery_Module_PriorInformation then
			increaseAmount = increaseAmount + mastery_Module_PriorInformation.ApplyAmount;
			-- 특성 정보 제어 프로그램
			local mastery_Module_InformationControl = GetMasteryMastered(masteryTable, 'Module_InformationControl');
			if mastery_Module_InformationControl then
				increaseAmount = increaseAmount + mastery_Module_InformationControl.ApplyAmount2;
			end
		end
		addDodge = addDodge * (1 + increaseAmount/100);
		result = result + addDodge;
		table.insert(info, { Type = 'TMGrade', Value = addDodge, ValueType = 'Formula' });
	end
	return result;
end
function GetCriticalRateByTroublemaker(info, Attacker, Defender)
	local result = 0;
	if Defender == nil then
		return 0;
	end
	local tmGrade = Defender.TroublemakerGradeMap[GetTeam(Attacker)];
	if tmGrade and tmGrade >= 3 then
		local addCriticalRate = 5;
		local increaseAmount = 0;
		local masteryTable = GetMastery(Attacker);
		-- 특성 사전 정보
		local mastery_PriorInformation = GetMasteryMastered(masteryTable, 'PriorInformation');
		if mastery_PriorInformation then
			increaseAmount = increaseAmount + mastery_PriorInformation.ApplyAmount;
			local mastery_EarlyBird = GetMasteryMastered(masteryTable, 'EarlyBird');
			if tmGrade == 7 and mastery_EarlyBird then
				increaseAmount = increaseAmount + mastery_EarlyBird.ApplyAmount2;
			end
		end
		-- 특성 적 정보 분석
		local mastery_Module_PriorInformation = GetMasteryMastered(masteryTable, 'Module_PriorInformation');
		if mastery_Module_PriorInformation then
			increaseAmount = increaseAmount + mastery_Module_PriorInformation.ApplyAmount;
			-- 특성 정보 제어 프로그램
			local mastery_Module_InformationControl = GetMasteryMastered(masteryTable, 'Module_InformationControl');
			if mastery_Module_InformationControl then
				increaseAmount = increaseAmount + mastery_Module_InformationControl.ApplyAmount2;
			end
		end
		addCriticalRate = addCriticalRate * (1 + increaseAmount/100);
		result = result + addCriticalRate;
		table.insert(info, { Type = 'TMGrade', Value = addCriticalRate, ValueType = 'Formula' });
	end
	return result;
end
function GetBlockByTroublemaker(info, Attacker, Defender)
	local result = 0;
	local tmGrade = Attacker.TroublemakerGradeMap[GetTeam(Defender)];
	if tmGrade and tmGrade >= 4 then
		local addBlock = 5;
		local increaseAmount = 0;
		local masteryTable = GetMastery(Defender);
		-- 특성 사전 정보
		local mastery_PriorInformation = GetMasteryMastered(masteryTable, 'PriorInformation');
		if mastery_PriorInformation then
			increaseAmount = increaseAmount + mastery_PriorInformation.ApplyAmount;
			local mastery_EarlyBird = GetMasteryMastered(masteryTable, 'EarlyBird');
			if tmGrade == 7 and mastery_EarlyBird then
				increaseAmount = increaseAmount + mastery_EarlyBird.ApplyAmount2;
			end
		end
		-- 특성 적 정보 분석
		local mastery_Module_PriorInformation = GetMasteryMastered(masteryTable, 'Module_PriorInformation');
		if mastery_Module_PriorInformation then
			increaseAmount = increaseAmount + mastery_Module_PriorInformation.ApplyAmount;
			-- 특성 정보 제어 프로그램
			local mastery_Module_InformationControl = GetMasteryMastered(masteryTable, 'Module_InformationControl');
			if mastery_Module_InformationControl then
				increaseAmount = increaseAmount + mastery_Module_InformationControl.ApplyAmount2;
			end
		end
		addBlock = addBlock * (1 + increaseAmount/100);
		result = result + addBlock;
		table.insert(info, { Type = 'TMGrade', Value = addBlock, ValueType = 'Formula' });
	end
	return result;
end
function GetModifyAbilityDamageFromEvent_Troublemaker(info, info_Multiplier, Attacker, Defender)
	local multiplier = 0;
	local add = 0;
	if Defender == nil then
		return multiplier, add;
	end
	local tmGrade = Defender.TroublemakerGradeMap[GetTeam(Attacker)];
	if tmGrade and tmGrade >= 5 then
		local multiplier_TMGrade = 5;
		local increaseAmount = 0;
		local masteryTable = GetMastery(Attacker);
		-- 특성 사전 정보
		local mastery_PriorInformation = GetMasteryMastered(masteryTable, 'PriorInformation');
		if mastery_PriorInformation then
			increaseAmount = increaseAmount + mastery_PriorInformation.ApplyAmount;
			local mastery_EarlyBird = GetMasteryMastered(masteryTable, 'EarlyBird');
			if tmGrade == 7 and mastery_EarlyBird then
				increaseAmount = increaseAmount + mastery_EarlyBird.ApplyAmount2;
			end
		end
		-- 특성 적 정보 분석
		local mastery_Module_PriorInformation = GetMasteryMastered(masteryTable, 'Module_PriorInformation');
		if mastery_Module_PriorInformation then
			increaseAmount = increaseAmount + mastery_Module_PriorInformation.ApplyAmount;
			-- 특성 정보 제어 프로그램
			local mastery_Module_InformationControl = GetMasteryMastered(masteryTable, 'Module_InformationControl');
			if mastery_Module_InformationControl then
				increaseAmount = increaseAmount + mastery_Module_InformationControl.ApplyAmount2;
			end
		end
		multiplier_TMGrade = multiplier_TMGrade * (1 + increaseAmount/100);
		multiplier = multiplier + multiplier_TMGrade;
		table.insert(info_Multiplier, { Type = 'TMGrade', Value = multiplier_TMGrade, ValueType = 'Formula' });
	end	
	return multiplier, add;
end
function GetDefenceRatio_Troublemaker(Attacker, Defender)
	local result = 0;
	local tmGrade = Attacker.TroublemakerGradeMap[GetTeam(Defender)];
	if tmGrade and tmGrade >= 6 then
		local multiplier_TMGrade = 5;
		local increaseAmount = 0;
		local masteryTable = GetMastery(Defender);
		-- 특성 사전 정보
		local mastery_PriorInformation = GetMasteryMastered(masteryTable, 'PriorInformation');
		if mastery_PriorInformation then
			increaseAmount = increaseAmount + mastery_PriorInformation.ApplyAmount;
			local mastery_EarlyBird = GetMasteryMastered(masteryTable, 'EarlyBird');
			if tmGrade == 7 and mastery_EarlyBird then
				increaseAmount = increaseAmount + mastery_EarlyBird.ApplyAmount2;
			end
		end
		-- 특성 적 정보 분석
		local mastery_Module_PriorInformation = GetMasteryMastered(masteryTable, 'Module_PriorInformation');
		if mastery_Module_PriorInformation then
			increaseAmount = increaseAmount + mastery_Module_PriorInformation.ApplyAmount;
			-- 특성 정보 제어 프로그램
			local mastery_Module_InformationControl = GetMasteryMastered(masteryTable, 'Module_InformationControl');
			if mastery_Module_InformationControl then
				increaseAmount = increaseAmount + mastery_Module_InformationControl.ApplyAmount2;
			end
		end
		multiplier_TMGrade = multiplier_TMGrade * (1 + increaseAmount/100);
		result = result + multiplier_TMGrade;
	end
	return result;
end