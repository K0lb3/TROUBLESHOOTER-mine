function GetConditionalStatus(self, arg, info, calcOption)
	local scp = _G['GetConditionalStatus_' .. arg];
	if scp then
		return scp(self, arg, info, calcOption)
	else
		return 0;
	end
end

function GetConditionalStatus_Block(self, arg, info, calcOption)
	local result = 0;
	
	local cache = {};
	
	-- 대지 SP
	if self.ESP and self.ESP.name == 'Earth' then
		local curblock = GetCurrentBattleValue_SP(self);
		if not curblock then
			curblock = 0;
		elseif curblock ~= 0 then
			table.insert(info, MakeESPStatInfo(self.ESP.name, curblock, 'Defender'));
		end
		result = result + curblock;
	end
	-- 정보 SP
	if self.ESP and self.ESP.name == 'Info' then
		local curblock = GetCurrentBattleValue_SP(self);
		if not curblock then
			curblock = 0;
		elseif curblock ~= 0 then
			table.insert(info, MakeESPStatInfo(self.ESP.name, curblock, 'Defender'));
		end
		result = result + curblock;
	end	

	local usePrevPos = calcOption.UsePrevAbilityPosition;
	local masteryTable_Defender = calcOption.MasteryTable or GetMastery(self);
	-- 특성 파수꾼
	local mastery_Sentinel = GetMasteryMastered(masteryTable_Defender, 'Sentinel');
	if mastery_Sentinel then
		local targetList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Enemy', true);
		if #targetList > 0 then
			local addAmount = mastery_Sentinel.ApplyAmount;
			local gatekeeper = GetMasteryMastered(masteryTable_Defender, 'Gatekeeper');
			if gatekeeper then
				addAmount = addAmount + gatekeeper.ApplyAmount;
			end
			local addBlock = #targetList * addAmount;
			result = result + addBlock;
			table.insert(info, { Type = mastery_Sentinel.name, Value = addBlock, ValueType = 'Mastery'});
		end
	end
	-- 특성 전술적 감각
	local mastery_TacticalSense = GetMasteryMastered(masteryTable_Defender, 'TacticalSense');
	if mastery_TacticalSense then
		local allyList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Team', true);
		local enemyList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Enemy', true);
		if #enemyList > #allyList then
			local addBlock = mastery_TacticalSense.ApplyAmount;
			local mastery_TopChoice = GetMasteryMastered(masteryTable_Defender, 'TopChoice');
			if mastery_TopChoice then
				addBlock = addBlock + mastery_TopChoice.ApplyAmount;
			end
			result = result + addBlock;
			table.insert(info, { Type = mastery_TacticalSense.name, Value = addBlock, ValueType = 'Mastery'});
		end
	end
	-- 특성 야행성
	local mastery_Nocturnality = GetMasteryMastered(masteryTable_Defender, 'Nocturnality');
	if mastery_Nocturnality then
		if IsDarkTime(calcOption.MissionTime) then
			local addBlock = mastery_Nocturnality.ApplyAmount;
			local mastery_NightGuardian = GetMasteryMastered(masteryTable_Defender, 'NightGuardian');
			if mastery_NightGuardian then
				addBlock = addBlock + mastery_NightGuardian.ApplyAmount;
			end
			result = result + addBlock;
			table.insert(info, { Type = mastery_Nocturnality.name, Value = addBlock, ValueType = 'Mastery'});
		end
	end
	-- 어둠의 야수
	local mastery_NocturnalBeast = GetMasteryMastered(masteryTable_Defender, 'NocturnalBeast');
	if mastery_NocturnalBeast then
		if IsDarkTime(calcOption.MissionTime) then
			local addBlock = mastery_NocturnalBeast.ApplyAmount;
			result = result + addBlock;
			table.insert(info, { Type = mastery_NocturnalBeast.name, Value = addBlock, ValueType = 'Mastery'});
		end
	end
	-- 특성 홀로 남은 자
	local mastery_Solo = GetMasteryMastered(masteryTable_Defender, 'Solo');
	if mastery_Solo then
		local allyList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sphere6', 'Team', true);
		LogAndPrint(#allyList, allyList);
		if #allyList == 0 then	-- 혼자 남았구나..
			local addBlock = mastery_Solo.ApplyAmount;
			result = result + addBlock;
			table.insert(info, { Type = mastery_Solo.name, Value = addBlock, ValueType = 'Mastery'});
		end
	end
	-- 특성 강행돌파
	local allyList = nil;
	local enemyList = nil;
	local FillAllyList = function()
		if allyList == nil then
			allyList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Team', true);
		end
	end
	local FillEnemyList = function()
		if enemyList == nil then
			enemyList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Enemy', true);
		end
	end
	local mastery_FastWork = GetMasteryMastered(masteryTable_Defender, 'FastWork');
	if mastery_FastWork then
		FillAllyList();
		FillEnemyList();
		local stepCount = #enemyList - #allyList;
		if stepCount > 0 then
			local addBlock = stepCount * mastery_FastWork.ApplyAmount;
			result = result + addBlock;
			table.insert(info, { Type = mastery_FastWork.name, Value = addBlock, ValueType = 'Mastery'});
		end
	end
	
	-- 홀로서기
	local mastery_StandAlone = GetMasteryMastered(masteryTable_Defender, 'StandAlone');
	if mastery_StandAlone then
		FillAllyList();
		if #allyList == 0 then
			local addBlock = math.floor(mastery_StandAlone.CustomCacheData / mastery_StandAlone.ApplyAmount) * mastery_StandAlone.ApplyAmount2;
			result = result + addBlock;
			table.insert(info, MakeMasteryStatInfo(mastery_StandAlone.name, addBlock));
		end
	end
	
	-- 혼전
	local mastery_IntenseBattle = GetMasteryMastered(masteryTable_Defender, 'IntenseBattle');
	if mastery_IntenseBattle then
		local allyList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Team', true);
		local enemyList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Enemy', true);
		if #allyList >= mastery_IntenseBattle.ApplyAmount and #enemyList >= mastery_IntenseBattle.ApplyAmount then
			local addVal = mastery_IntenseBattle.ApplyAmount2;
			result = result + addVal;
			table.insert(info, MakeMasteryStatInfo(mastery_IntenseBattle.name, addVal));
		end
	end

	return result;
end

function GetConditionalStatus_Accuracy(self, arg, info, calcOption)
	local result = 0;
	result = result + GetConditionalStatus_Accuracy_Base(self, arg, info, calcOption);
	result = result + GetConditionalStatus_Accuracy_Environment(self, arg, info, calcOption);
	result = result + GetConditionalStatus_Accuracy_RangeAttacker(self, arg, info, calcOption);
	return result;
end
function GetConditionalStatus_Accuracy_Base(self, arg, info, calcOption)
	local usePrevPos = calcOption.UsePrevAbilityPosition;
	local masteryTable_Attacker = calcOption.MasteryTable or GetMastery(self);
	local result = 0;
	
	-- 안정된 자세
	if IsStableAttack(self) and not calcOption.NotStableAttack then
		local stableStateAccuracyBase = 20;
		local stableStateAccuracy = stableStateAccuracyBase;
		local mastery_PositionOfAdvantage = GetMasteryMastered(masteryTable_Attacker, 'PositionOfAdvantage');
		if mastery_PositionOfAdvantage then 
			stableStateAccuracy = stableStateAccuracy + mastery_PositionOfAdvantage.ApplyAmount;
		end
		-- 호환성 증가 - 안정된 자세s
		local mastery_MachineUnique_StablePosture = GetMasteryMastered(masteryTable_Attacker, 'MachineUnique_StablePosture');
		if mastery_MachineUnique_StablePosture then 
			stableStateAccuracy = stableStateAccuracy + stableStateAccuracyBase * (mastery_MachineUnique_StablePosture.ApplyAmount / 100);
		end
		result = result + stableStateAccuracy;	
		table.insert(info, {Type = 'StableAttack', Value = stableStateAccuracy, ValueType = 'Formula'});
	elseif GetInstantProperty(self, 'WandererActive') then
		local mastery_Wanderer = GetMasteryMastered(masteryTable_Attacker, 'Wanderer');
		if mastery_Wanderer then	-- 사실 이 체크는 의미가 없어야한다.
			result = result + mastery_Wanderer.ApplyAmount;
			table.insert(info, {Type = mastery_Wanderer.name, Value = mastery_Wanderer.ApplyAmount, ValueType = 'Mastery'});
		end
	end
	
	if IsStableAttack(self) or calcOption.NotStableAttack then
		local mastery_PerfectPosition = GetMasteryMastered(masteryTable_Attacker, 'PerfectPosition');
		if mastery_PerfectPosition then
			result = result + mastery_PerfectPosition.ApplyAmount;
			table.insert(info, MakeMasteryStatInfo(mastery_PerfectPosition.name, mastery_PerfectPosition.ApplyAmount));
		end
	end
	
	-- 기백 SP
	if self.ESP and self.ESP.name == 'Spirit' then
		local curAdditionalAccuracy = GetCurrentBattleValue_SP(self);
		if not curAdditionalAccuracy then
			curAdditionalAccuracy = 0;
		elseif curAdditionalAccuracy ~= 0 then
			table.insert(info, MakeESPStatInfo(self.ESP.name, curAdditionalAccuracy, 'Attacker'));
		end
		result = result + curAdditionalAccuracy;
	end
	-- 정보 SP
	if self.ESP and self.ESP.name == 'Info' then
		local curAdditionalAccuracy = GetCurrentBattleValue_SP(self);
		if not curAdditionalAccuracy then
			curAdditionalAccuracy = 0;
		elseif curAdditionalAccuracy ~= 0 then
			table.insert(info, MakeESPStatInfo(self.ESP.name, curAdditionalAccuracy, 'Attacker'));
		end
		result = result + curAdditionalAccuracy;
	end	
	
	-- 특성 흐르는 피
	local mastery_FlowOfBlood = GetMasteryMastered(masteryTable_Attacker, 'FlowOfBlood');
	if mastery_FlowOfBlood then
		local lostHPRatio = (self.MaxHP - self.HP) / self.MaxHP;
		local stepCount = math.floor(lostHPRatio * 100 / mastery_FlowOfBlood.ApplyAmount);	-- ApplyAmount 당
		if stepCount > 0 then
			local curAdditionalAccuracy = stepCount * mastery_FlowOfBlood.ApplyAmount2;		-- ApplyAmount2 만큼 증가
			result = result + curAdditionalAccuracy;
			table.insert(info, MakeMasteryStatInfo(mastery_FlowOfBlood.name, curAdditionalAccuracy));
		end
	end

	return result;
end
function GetConditionalStatus_Accuracy_Environment(self, arg, info, calcOption)
	local result = 0;
	local masteryTable_Attacker = calcOption.MasteryTable or GetMastery(self);
	
	-- 특성 야행성
	local mastery_Nocturnality = GetMasteryMastered(masteryTable_Attacker, 'Nocturnality');
	if mastery_Nocturnality then
		if IsDarkTime(calcOption.MissionTime) then
			local curAdditionalAccuracy = mastery_Nocturnality.ApplyAmount;
			local mastery_NightGuardian = GetMasteryMastered(masteryTable_Attacker, 'NightGuardian');
			if mastery_NightGuardian then
				curAdditionalAccuracy = curAdditionalAccuracy + mastery_NightGuardian.ApplyAmount;
			end
			result = result + curAdditionalAccuracy;
			table.insert(info, { Type = mastery_Nocturnality.name, Value = curAdditionalAccuracy, ValueType = 'Mastery'});
		end
	end
	-- 아이템 특성 야간 투시경
	local mastery_Goggle_NightVision = GetMasteryMastered(masteryTable_Attacker, 'Goggle_NightVision');
	if mastery_Goggle_NightVision then
		if IsDarkTime(calcOption.MissionTime) then
			local curAdditionalAccuracy = mastery_Goggle_NightVision.ApplyAmount;
			result = result + curAdditionalAccuracy;
			table.insert(info, { Type = mastery_Goggle_NightVision.name, Value = curAdditionalAccuracy, ValueType = 'Mastery'});
		end
	end
	-- 아이템 특성 듀나메스 저격총 L 헌정판 - 제프
	local mastery_SniperRifle_Dynames_Legend = GetMasteryMastered(masteryTable_Attacker, 'SniperRifle_Dynames_Legend');
	if mastery_SniperRifle_Dynames_Legend then
		if IsDarkTime(calcOption.MissionTime) then
			local curAdditionalAccuracy = mastery_SniperRifle_Dynames_Legend.ApplyAmount;
			result = result + curAdditionalAccuracy;
			table.insert(info, { Type = mastery_SniperRifle_Dynames_Legend.name, Value = curAdditionalAccuracy, ValueType = 'Mastery'});
		end
	end
	-- 어둠의 야수
	local mastery_NocturnalBeast = GetMasteryMastered(masteryTable_Attacker, 'NocturnalBeast');
	if mastery_NocturnalBeast then
		if IsDarkTime(calcOption.MissionTime) then
			local curAdditionalAccuracy = mastery_NocturnalBeast.ApplyAmount;
			result = result + curAdditionalAccuracy;
			table.insert(info, { Type = mastery_NocturnalBeast.name, Value = curAdditionalAccuracy, ValueType = 'Mastery'});
		end
	end
	
	-- 날씨: 비
	local value_Weather = 0;
	if calcOption.MissionWeather == 'Rain' then
		value_Weather = -10;
	end
	if value_Weather ~= 0 then
		result = result + value_Weather;
		table.insert(info, {Type = 'Weather', Value = value_Weather, ValueType = 'Formula', Weather = calcOption.MissionWeather});
	end
	-- 특성 야생 생활 / 환경 적응
	if value_Weather < 0 then
		local immuneMastery = GetMasteryMasteredImmuneWeather(masteryTable_Attacker);
		-- 빗속의 야수(비)
		if not immuneMastery and calcOption.MissionWeather == 'Rain' then
			immuneMastery = GetMasteryMastered(masteryTable_Attacker, 'RainBeast');
		end
		if immuneMastery then
			result = result - value_Weather;
			table.insert(info, MakeMasteryStatInfo(immuneMastery.name, -1 * value_Weather));
		end
	end
	
	return result;
end
function GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, obj, range, relation, isMySight, allowSelf)
	for _, cc in ipairs(cache) do
		local key = cc[1];
		if key.usePrevPos == usePrevPos
			and key.obj == obj
			and key.range == range
			and key.relation == relation
			and key.isMySight == isMySight
			and key.allowSelf == allowSelf then
			return cc[2];
		end
	end
	local newCC = {{usePrevPos = usePrevPos, obj = obj, range = range, relation = relation, isMySight = isMySight, allowSelf = allowSelf}, GetTargetInRangeSightReposition(usePrevPos, obj, range, relation, isMySight, allowSelf)};
	table.insert(cache, newCC);
	return newCC[2];
end
function GetConditionalStatus_Accuracy_RangeAttacker(self, arg, info, calcOption)
	local usePrevPos = calcOption.UsePrevAbilityPosition;
	local masteryTable_Attacker = calcOption.MasteryTable or GetMastery(self);
	local result = 0;
	
	local cache = {};
	
	-- 특성 외토리늑대. 6칸 안에 아군 유닛이 없으면 명중률이 상승
	local mastery_LonelyWolf = GetMasteryMastered(masteryTable_Attacker, 'LonelyWolf');
	if mastery_LonelyWolf then 
		local targetList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, mastery_LonelyWolf.Range, 'Team', true);
		if #targetList == 0 then
			local curAdditionalAccuracy = mastery_LonelyWolf.ApplyAmount;
			result = result + curAdditionalAccuracy;
			table.insert(info, { Type = mastery_LonelyWolf.name, Value = curAdditionalAccuracy, ValueType = 'Mastery'});
		end
	end
	-- 특성 팀 플레이어
	local mastery_TeamPlayer = GetMasteryMastered(masteryTable_Attacker, 'TeamPlayer');
	if mastery_TeamPlayer then 
		local targetList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, mastery_TeamPlayer.Range, 'Team', true);
		if #targetList > 0 then
			local curAdditionalAccuracy = mastery_TeamPlayer.ApplyAmount;
			result = result + curAdditionalAccuracy;
			table.insert(info, { Type = mastery_TeamPlayer.name, Value = curAdditionalAccuracy, ValueType = 'Mastery'});
		end
	end
	-- 특성 동료 의식. 시야 내 아군 유닛 수만큼 명중률이 상승
	local mastery_Fellowship = GetMasteryMastered(masteryTable_Attacker, 'Fellowship');
	if mastery_Fellowship then
		local targetList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Team', true);
		if #targetList > 0 then
			local curAdditionalAccuracy = #targetList * mastery_Fellowship.ApplyAmount;
			result = result + curAdditionalAccuracy;
			table.insert(info, { Type = mastery_Fellowship.name, Value = curAdditionalAccuracy, ValueType = 'Mastery'});
		end	
	end
	-- 특성 전술적 포위. 시야 내 아군 수가 적군 수보다 많으면 명중률이 상승
	local mastery_TacticalEnvelopment = GetMasteryMastered(masteryTable_Attacker, 'TacticalEnvelopment');
	if mastery_TacticalEnvelopment then
		local allyList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Team', true);
		local enemyList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Enemy', true);
		if #allyList > #enemyList then
			local curAdditionalAccuracy = mastery_TacticalEnvelopment.ApplyAmount;
			local mastery_TopChoice = GetMasteryMastered(masteryTable_Attacker, 'TopChoice');
			if mastery_TopChoice then
				curAdditionalAccuracy = curAdditionalAccuracy + mastery_TopChoice.ApplyAmount2;
			end			
			result = result + curAdditionalAccuracy;
			table.insert(info, { Type = mastery_TacticalEnvelopment.name, Value = curAdditionalAccuracy, ValueType = 'Mastery'});
		end	
	end
	-- 특성 사명감. 시야 내 적군 수가 아군 수보다 많으면 유닛 수만큼 명중률이 상승
	local mastery_SenseOfDuty = GetMasteryMastered(masteryTable_Attacker, 'SenseOfDuty');
	if mastery_SenseOfDuty then
		local allyList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Team', true);
		local enemyList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Enemy', true);
		if #allyList < #enemyList then
			local curAdditionalAccuracy = mastery_SenseOfDuty.ApplyAmount;
			result = result + curAdditionalAccuracy;
			table.insert(info, { Type = mastery_SenseOfDuty.name, Value = curAdditionalAccuracy, ValueType = 'Mastery'});
		end	
	end
	-- 특성 하나씩
	local mastery_OneByOne = GetMasteryMastered(masteryTable_Attacker, 'OneByOne');
	if mastery_OneByOne then
		local targetList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Enemy', true);
		if #targetList == 1 then
			local curAdditionalAccuracy = mastery_OneByOne.ApplyAmount;
			result = result + curAdditionalAccuracy;
			table.insert(info, { Type = mastery_OneByOne.name, Value = curAdditionalAccuracy, ValueType = 'Mastery'});
		end
	end
	-- 혼전
	local mastery_IntenseBattle = GetMasteryMastered(masteryTable_Attacker, 'IntenseBattle');
	if mastery_IntenseBattle then
		local allyList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Team', true);
		local enemyList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Enemy', true);
		if #allyList >= mastery_IntenseBattle.ApplyAmount and #enemyList >= mastery_IntenseBattle.ApplyAmount then
			local addVal = mastery_IntenseBattle.ApplyAmount2;
			result = result + addVal;
			table.insert(info, MakeMasteryStatInfo(mastery_IntenseBattle.name, addVal));
		end
	end
	
	return result;
end

function GetConditionalStatus_CriticalStrikeChance(self, arg, info, calcOption)
	local usePrevPos = calcOption.UsePrevAbilityPosition;
	local masteryTable_Attacker = calcOption.MasteryTable or GetMastery(self);
	local result = 0;
	
	local cache = {};
	
	-- 번개 SP
	if self.ESP and self.ESP.name == 'Lightning' then
		local curCriticalRate = GetCurrentBattleValue_SP(self);
		if not curCriticalRate then
			curCriticalRate = 0;
		elseif curCriticalRate ~= 0 then
			table.insert(info, MakeESPStatInfo(self.ESP.name, curCriticalRate, 'Attacker'));
		end
		result = result + curCriticalRate;
	end
	-- 정보 SP
	if self.ESP and self.ESP.name == 'Info' then
		local curCriticalRate = GetCurrentBattleValue_SP(self);
		if not curCriticalRate then
			curCriticalRate = 0;
		elseif curCriticalRate ~= 0 then
			table.insert(info, MakeESPStatInfo(self.ESP.name, curCriticalRate, 'Attacker'));
		end
		result = result + curCriticalRate;
	end	
	
	-- 특성 야행성
	local mastery_Nocturnality = GetMasteryMastered(masteryTable_Attacker, 'Nocturnality');
	if mastery_Nocturnality then
		if IsDarkTime(calcOption.MissionTime) then
			local addCriticalStrikeChance = mastery_Nocturnality.ApplyAmount;
			local mastery_NightGuardian = GetMasteryMastered(masteryTable_Attacker, 'NightGuardian');
			if mastery_NightGuardian then
				addCriticalStrikeChance = addCriticalStrikeChance + mastery_NightGuardian.ApplyAmount;
			end
			result = result + addCriticalStrikeChance;
			table.insert(info, { Type = mastery_Nocturnality.name, Value = addCriticalStrikeChance, ValueType = 'Mastery'});
		end
	end
	-- 어둠의 야수
	local mastery_NocturnalBeast = GetMasteryMastered(masteryTable_Attacker, 'NocturnalBeast');
	if mastery_NocturnalBeast then
		if IsDarkTime(calcOption.MissionTime) then
			local addCriticalStrikeChance = mastery_NocturnalBeast.ApplyAmount;
			result = result + addCriticalStrikeChance;
			table.insert(info, { Type = mastery_NocturnalBeast.name, Value = addCriticalStrikeChance, ValueType = 'Mastery'});
		end
	end
	
	if IsStableAttack(self) and not calcOption.NotStableAttack then
		local mastery_SnipingTraining = GetMasteryMastered(masteryTable_Attacker, 'SnipingTraining');
		if mastery_SnipingTraining then
			result = result + mastery_SnipingTraining.ApplyAmount;
			table.insert(info, MakeMasteryStatInfo(mastery_SnipingTraining.name, mastery_SnipingTraining.ApplyAmount));
		end
	end
	
	-- 아이템 특성 야간 투시경
	local mastery_Goggle_NightVision = GetMasteryMastered(masteryTable_Attacker, 'Goggle_NightVision');
	if mastery_Goggle_NightVision then
		if IsDarkTime(calcOption.MissionTime) then
			local addCriticalStrikeChance = mastery_Goggle_NightVision.ApplyAmount;
			result = result + addCriticalStrikeChance;
			table.insert(info, { Type = mastery_Goggle_NightVision.name, Value = addCriticalStrikeChance, ValueType = 'Mastery'});
		end
	end
	-- 아이템 특성 듀나메스 저격총 L 헌정판 - 제프
	local mastery_SniperRifle_Dynames_Legend = GetMasteryMastered(masteryTable_Attacker, 'SniperRifle_Dynames_Legend');
	if mastery_SniperRifle_Dynames_Legend then
		if IsDarkTime(calcOption.MissionTime) then
			local addCriticalStrikeChance = mastery_SniperRifle_Dynames_Legend.ApplyAmount;
			result = result + addCriticalStrikeChance;
			table.insert(info, { Type = mastery_SniperRifle_Dynames_Legend.name, Value = addCriticalStrikeChance, ValueType = 'Mastery'});
		end
	end
	
	-- 특성 흐르는 피
	local mastery_FlowOfBlood = GetMasteryMastered(masteryTable_Attacker, 'FlowOfBlood');
	if mastery_FlowOfBlood then
		local lostHPRatio = (self.MaxHP - self.HP) / self.MaxHP;
		local stepCount = math.floor(lostHPRatio * 100 / mastery_FlowOfBlood.ApplyAmount);	-- ApplyAmount 당
		if stepCount > 0 then
			local addCriticalStrikeChance = stepCount * mastery_FlowOfBlood.ApplyAmount3;	-- ApplyAmount3 만큼 증가
			result = result + addCriticalStrikeChance;
			table.insert(info, MakeMasteryStatInfo(mastery_FlowOfBlood.name, addCriticalStrikeChance));
		end
	end
	
	-- 혼전
	local mastery_IntenseBattle = GetMasteryMastered(masteryTable_Attacker, 'IntenseBattle');
	if mastery_IntenseBattle then
		local allyList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Team', true);
		local enemyList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Enemy', true);
		if #allyList >= mastery_IntenseBattle.ApplyAmount and #enemyList >= mastery_IntenseBattle.ApplyAmount then
			local addVal = mastery_IntenseBattle.ApplyAmount2;
			result = result + addVal;
			table.insert(info, MakeMasteryStatInfo(mastery_IntenseBattle.name, addVal));
		end
	end
	
	return result;
end

function GetConditionalStatus_Dodge(self, arg, info, calcOption)
	local result = 0;
	local masteryTable_Defender = calcOption.MasteryTable or GetMastery(self);
	
	local cache = {};
	
	-- 물 SP
	if self.ESP and self.ESP.name == 'Water' then
		local curAdditionalDodge = GetCurrentBattleValue_SP(self);
		if not curAdditionalDodge then
			curAdditionalDodge = 0;
		elseif curAdditionalDodge ~= 0 then
			table.insert(info, MakeESPStatInfo(self.ESP.name, curAdditionalDodge, 'Defender'));
		end
		result = result + curAdditionalDodge;
	end
	-- 정보 SP
	if self.ESP and self.ESP.name == 'Info' then
		local curAdditionalDodge = GetCurrentBattleValue_SP(self);
		if not curAdditionalDodge then
			curAdditionalDodge = 0;
		elseif curAdditionalDodge ~= 0 then
			table.insert(info, MakeESPStatInfo(self.ESP.name, curAdditionalDodge, 'Defender'));
		end
		result = result + curAdditionalDodge;
	end	
	
	-- 특성 수풀을 걷는 자
	local mastery_bushWalker = GetMasteryMastered(masteryTable_Defender, 'BushWalker');
	if mastery_bushWalker and IsObjectOnFieldEffectBuffAffector(self, mastery_bushWalker.Buff.name) then
		table.insert(info, {Type = mastery_bushWalker.name, Value = mastery_bushWalker.ApplyAmount, ValueType = 'Mastery'});
		result = result + mastery_bushWalker.ApplyAmount;
	end
	
	-- 특성 물 위를 걷는 자
	local mastery_WaterWalker = GetMasteryMastered(masteryTable_Defender, 'WaterWalker');
	if mastery_WaterWalker and IsObjectOnFieldEffectBuffAffector(self, { mastery_WaterWalker.Buff.name, mastery_WaterWalker.SubBuff.name } ) then
		local curAdditionalDodge = mastery_WaterWalker.ApplyAmount;
		result = result + curAdditionalDodge;
		table.insert(info, MakeMasteryStatInfo(mastery_WaterWalker.name, curAdditionalDodge));
	end
	
	-- 특성 안개 속을 걷는 자
	result = result + GetMasteryValueByCustomFuncWithInfo(masteryTable_Defender, 'SmokeWalker', info, function(mastery)
		if IsObjectOnFieldEffectBuffAffector(self, mastery.Buff.name) then
			return mastery.ApplyAmount;
		end
	end);
	
	-- 특성 거미줄 곡예
	local mastery_WebCircus = GetMasteryMastered(masteryTable_Defender, 'WebCircus');
	if mastery_WebCircus and IsObjectOnFieldEffect(self, mastery_WebCircus.Buff.name) then
		local curAdditionalDodge = mastery_WebCircus.ApplyAmount;
		result = result + curAdditionalDodge;
		table.insert(info, {Type = mastery_WebCircus.name, Value = curAdditionalDodge, ValueType = 'Mastery'});
	end
	
	-- 특성 야행성
	local mastery_Nocturnality = GetMasteryMastered(masteryTable_Defender, 'Nocturnality');
	if mastery_Nocturnality then
		if IsDarkTime(calcOption.MissionTime) then
			local curAdditionalDodge = mastery_Nocturnality.ApplyAmount;
			local mastery_NightGuardian = GetMasteryMastered(masteryTable_Defender, 'NightGuardian');
			if mastery_NightGuardian then
				curAdditionalDodge = curAdditionalDodge + mastery_NightGuardian.ApplyAmount;
			end
			result = result + curAdditionalDodge;
			table.insert(info, { Type = mastery_Nocturnality.name, Value = curAdditionalDodge, ValueType = 'Mastery'});
		end
	end	
	-- 어둠의 야수
	local mastery_NocturnalBeast = GetMasteryMastered(masteryTable_Defender, 'NocturnalBeast');
	if mastery_NocturnalBeast then
		if IsDarkTime(calcOption.MissionTime) then
			local curAdditionalDodge = mastery_NocturnalBeast.ApplyAmount;
			result = result + curAdditionalDodge;
			table.insert(info, { Type = mastery_NocturnalBeast.name, Value = curAdditionalDodge, ValueType = 'Mastery'});
		end
	end
	-- 특성 강행돌파
	local mastery_FastWork = GetMasteryMastered(masteryTable_Defender, 'FastWork');
	if mastery_FastWork then
		local allyList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Team', true);
		local enemyList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Enemy', true);
		local stepCount = #enemyList - #allyList;
		if stepCount > 0 then
			local curAdditionalDodge = stepCount * mastery_FastWork.ApplyAmount;
			result = result + curAdditionalDodge;
			table.insert(info, { Type = mastery_FastWork.name, Value = curAdditionalDodge, ValueType = 'Mastery'});
		end
	end
	
	-- 혼전
	local mastery_IntenseBattle = GetMasteryMastered(masteryTable_Defender, 'IntenseBattle');
	if mastery_IntenseBattle then
		local allyList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Team', true);
		local enemyList = GetTargetInRangeSightRepositionWithCache(cache, usePrevPos, self, 'Sight', 'Enemy', true);
		if #allyList >= mastery_IntenseBattle.ApplyAmount and #enemyList >= mastery_IntenseBattle.ApplyAmount then
			local addVal = mastery_IntenseBattle.ApplyAmount2;
			result = result + addVal;
			table.insert(info, MakeMasteryStatInfo(mastery_IntenseBattle.name, addVal));
		end
	end
	
	-- 온도 추움, 한파
	local value_Temperature = 0;
	if calcOption.MissionTemperature == 'Cold' then
		value_Temperature = -5;
	elseif calcOption.MissionTemperature == 'Freezing' then
		value_Temperature = -10;
	end
	if value_Temperature ~= 0 then
		result = result + value_Temperature;
		table.insert(info, {Type = 'Temperature', Value = value_Temperature, ValueType = 'Formula', Temperature = calcOption.MissionTemperature});
	end
	-- 특성 야생 생활 / 환경 적응
	if value_Temperature < 0 then
		local immuneMastery = GetMasteryMasteredImmuneTemperature(masteryTable_Defender);
		-- 혹한의 야수(추움, 한파)
		if not immuneMastery and (calcOption.MissionTemperature == 'Cold' or calcOption.MissionTemperature == 'Freezing') then
			immuneMastery = GetMasteryMastered(masteryTable_Defender, 'ColdBeast');
		end
		if immuneMastery then
			result = result - value_Temperature;
			table.insert(info, {Type = immuneMastery.name, Value = -1 * value_Temperature, ValueType = 'Mastery'});
		end
	end
	
	return result;
end

function GetConditionalStatus_RegenCost(self, arg, info, calcOption)
	local result = 0;
	if self.CostType.name == 'Vigor' then
		result = GetConditionalStatus_RegenVigor(self, arg, info, calcOption);
	elseif self.CostType.name == 'Fuel' then
		result = GetConditionalStatus_RegenFuel(self, arg, info, calcOption);
	end
	return result;
end

function GetConditionalStatus_RegenVigor(self, arg, info, calcOption)
	local result = 0;
	-- 온도: 폭염
	local heatWaveRegenVigor = 0;
	if calcOption.MissionTemperature == 'ExtremelyHot' then
		heatWaveRegenVigor = -10;
	elseif calcOption.MissionTemperature == 'Hot' then
		heatWaveRegenVigor = -5;
	elseif calcOption.MissionTemperature == 'Warm' then
		heatWaveRegenVigor = 2;
	end
	if heatWaveRegenVigor ~= 0 then
		result = result + heatWaveRegenVigor;
		table.insert(info, { Type = 'Temperature', Value = heatWaveRegenVigor, ValueType = 'Formula', Temperature = calcOption.MissionTemperature});
	end
	-- 야생 생활 / 환경 적응
	if heatWaveRegenVigor < 0 then
		local masteryTable = GetMastery(self);
		local immuneMastery = GetMasteryMasteredImmuneTemperature(masteryTable);
		-- 폭염의 야수(더움, 폭염)
		if not immuneMastery and (calcOption.MissionTemperature == 'Hot' or calcOption.MissionTemperature == 'ExtremelyHot') then
			immuneMastery = GetMasteryMastered(masteryTable, 'HotBeast');
		end
		if immuneMastery then
			result = result - heatWaveRegenVigor;
			table.insert(info, MakeMasteryStatInfo(immuneMastery.name, -heatWaveRegenVigor));
		end
	elseif heatWaveRegenVigor > 0 then
		local mastery_EnvironmentalAdaptation = GetMasteryMastered(GetMastery(self), 'EnvironmentalAdaptation');
		if mastery_EnvironmentalAdaptation then
			local addAmount = math.floor(heatWaveRegenVigor * mastery_EnvironmentalAdaptation.ApplyAmount / 100);
			result = result + addAmount;
			table.insert(info, MakeMasteryStatInfo(mastery_EnvironmentalAdaptation.name, addAmount));
		end
	end
	return result;
end

function GetConditionalStatus_RegenFuel(self, arg, info, calcOption)
	local result = 0;
	local masteryTable = calcOption.MasteryTable or GetMastery(self);
	
	-- 충전 SP
	if self.ESP.name == 'Charge' then
		local regenAmount = math.floor(self.SP / 5) * 1;
		result = result + regenAmount;
		table.insert(info, MakeESPStatInfo(self.ESP.name, regenAmount, 'None'));
	end
	
	return result;
end

function GetConditionalStatus_CriticalStrikeDeal(self, arg, info, calcOption)
	local result = 0;
	local masteryTable_Attacker = calcOption.MasteryTable or GetMastery(self);
	
	-- 바람 SP 
	if self.ESP and self.ESP.name == 'Wind' then
		local curCriticalStrikeDeal = GetCurrentBattleValue_SP(self);
		if not curCriticalStrikeDeal then
			curCriticalStrikeDeal = 0;
		elseif curCriticalStrikeDeal ~= 0 then
			table.insert(info, MakeESPStatInfo(self.ESP.name, curCriticalStrikeDeal, 'Attacker'));
		end
		result = result + curCriticalStrikeDeal;
	end
	
	return result;
end

function GetConditionalStatus_Speed(self, arg, info, calcOption)
	local result = 0;
	local masteryTable = calcOption.MasteryTable or GetMastery(self);
	
	local value_Temperature = 0;
	if calcOption.MissionTemperature == 'ExtremelyHot' then
		value_Temperature = -10;
	elseif calcOption.MissionTemperature == 'Hot' then
		value_Temperature = -5;
	elseif calcOption.MissionTemperature == 'Cold' then
		value_Temperature = -5;
	elseif calcOption.MissionTemperature == 'Freezing' then
		value_Temperature = -10;
	end
	if value_Temperature ~= 0 then
		result = result + value_Temperature;
		table.insert(info, {Type = 'Temperature', Value = value_Temperature, ValueType = 'Formula', Temperature = calcOption.MissionTemperature});
	end
	-- 야생 생활 / 환경 적응
	if value_Temperature < 0 then
		local immuneMastery = GetMasteryMasteredImmuneTemperature(masteryTable);
		-- 혹한의 야수(추움, 한파)
		if not immuneMastery and (calcOption.MissionTemperature == 'Cold' or calcOption.MissionTemperature == 'Freezing') then
			immuneMastery = GetMasteryMastered(masteryTable, 'ColdBeast');
		end
		-- 폭염의 야수(더움, 폭염)
		if not immuneMastery and (calcOption.MissionTemperature == 'Hot' or calcOption.MissionTemperature == 'ExtremelyHot') then
			immuneMastery = GetMasteryMastered(masteryTable, 'HotBeast');
		end
		if immuneMastery then
			result = result - value_Temperature;
			table.insert(info, {Type = immuneMastery.name, Value = -1 * value_Temperature, ValueType = 'Mastery'});
		end
	end

	-- 발열 SP
	if self.ESP and self.ESP.name == 'Heat' then
		local curAdditionalSpeed = GetCurrentBattleValue_SP(self);
		if not curAdditionalSpeed then
			curAdditionalSpeed = 0;
		elseif curAdditionalSpeed ~= 0 then
			table.insert(info, MakeESPStatInfo(self.ESP.name, curAdditionalSpeed, 'None'));
		end
		result = result + curAdditionalSpeed;
	end	
	
	-- 선잠
	local mastery_LightSleep = GetMasteryMastered(masteryTable, 'LightSleep');
	if mastery_LightSleep and #GetBuffType(self, nil, nil, mastery_LightSleep.BuffGroup.name) > 0 then
		result = result + mastery_LightSleep.ApplyAmount;
		table.insert(info, MakeMasteryStatInfo(mastery_LightSleep.name, mastery_LightSleep.ApplyAmount));
	end
	
	return result;
end
function GetConditionalStatus_IncreaseDamage(self, arg, info, calcOption)
	local result = 0;
	local masteryTable = calcOption.MasteryTable or GetMastery(self);
	
	local mastery_Fury = GetMasteryMastered(masteryTable, 'Fury');
	if mastery_Fury then
		local lostHPRatio = 1 - self.HP / self.MaxHP;
		local stepCount = math.floor(lostHPRatio * 100 / mastery_Fury.ApplyAmount);	-- mastery_Fury.ApplyAmount 당
		if stepCount > 0 then
			local addAmount = stepCount * mastery_Fury.ApplyAmount2					-- mastery_Fury.ApplyAmount 만큼 증가
			result = result + addAmount;
			table.insert(info, MakeMasteryStatInfo(mastery_Fury.name, addAmount));
		end
	end
	return result;
end
function GetConditionalStatus_IncreaseDamage_ESP(self, arg, info, calcOption)
	local result = 0;
	local masteryTable = calcOption.MasteryTable or GetMastery(self);
	
	local mastery_WitchBook = GetMasteryMastered(masteryTable, 'WitchBook');
	if mastery_WitchBook then
		local addVal = mastery_WitchBook.ApplyAmount * mastery_WitchBook.CustomCacheData;
		local mastery_ArchWitch = GetMasteryMastered(masteryTable, 'ArchWitch');
		if mastery_ArchWitch then
			addVal = addVal + mastery_ArchWitch.ApplyAmount * mastery_ArchWitch.CustomCacheData;
		end
		result = result + addVal;
		table.insert(info, MakeMasteryStatInfo(mastery_WitchBook.name, addVal));
	end
	return result;
end
function GetConditionalStatus_DecreaseDamage(self, arg, info, calcOption)
	local result = 0;
	local masteryTable = calcOption.MasteryTable or GetMastery(self);
	
	-- 이상한 비늘
	local mastery_StrangeScale = GetMasteryMastered(masteryTable, 'StrangeScale');
	if mastery_StrangeScale then
		local addAmount = math.floor(#GetBuffType(self, 'Debuff') / mastery_StrangeScale.ApplyAmount) * mastery_StrangeScale.ApplyAmount2;
		if addAmount > 0 then
			result = result + addAmount;
			table.insert(info, MakeMasteryStatInfo(mastery_StrangeScale.name, addAmount));
		end
	end
	return result;
end