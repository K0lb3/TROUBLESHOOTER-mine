------------------------------------------------------------------------------------------------
-------------------------------------- 전투 계산 공식 ----------------------------------------
------------------------------------------------------------------------------------------------
-- Attacker, Defender 는 Object(Object.xml)의 Object 값
-- ability는  Ability(Ability.xml)의 Object 의 값 
-- phase = Primary
------------------------------------------------------------------------------------------------
function Battle(Attacker, Defender, ability, actions, phase, resultModifier, usingPos, chainIndex, detailInfo, perfChecker)
	if perfChecker == nil then
		perfChecker = MockPerfChecker;
	end
	perfChecker:StartRoutine('Initialize');
	local masteryTable_Attacker = GetMastery(Attacker);
	local masteryTable_Defender = nil;
	if Defender ~= nil then
		masteryTable_Defender = GetMastery(Defender);
	end
	
	local damageFlag = BuildDamageFlagFromResultModifier(resultModifier);
	
	local weather = 'Clear';
	local missionTime = 'Day';
	local temperature = 'Normal';
	local isCovered = false;
	
	perfChecker:StartRoutine('ConfigureEnviornment');
	if IsMissionServer() then
		local mission = GetMission(Attacker);
		weather = mission.Weather.name;
		missionTime = mission.MissionTime.name;
		temperature = mission.Temperature.name;
		isCovered = IsCoveredPosition(mission, GetPosition(Defender));
	end
	
	phase = phase or 'Primary';
	local defenderState = 'Hit';
	local attackerState = 'Normal';
	local knockbackPower = ability.KnockbackPower;
	
	-- C1. 피해량을 계산 합니다
	perfChecker:StartRoutine('DamageCalculation');
	perfChecker:Dive();
	local damage = GetDamageCalculator(Attacker, Defender, ability, weather, temperature, usingPos, chainIndex, nil, SafeIndex(resultModifier, 'DamagePuff_Add'), abilityDetailInfo, perfChecker);
	perfChecker:Rise();
	if SafeIndex(resultModifier, 'DamagePuff') then
		damage = damage * (100 + SafeIndex(resultModifier, 'DamagePuff')) / 100;
	end
	-- C2. 명중률을 계산 합니다 
	perfChecker:StartRoutine('HitRateCalculation');
	local hitRate, hitRateReason = ability.GetHitRateCalculator(Attacker, Defender, ability, usingPos, weather, missionTime, temperature, resultModifier, nil--[[aiFlag]], detailInfo);
	
	-- C3. 치명타 적중률을 계산 합니다 
	perfChecker:StartRoutine('CSCCalculation');
	perfChecker:Dive();
	local criticalStrikeChance = GetCriticalStrikeChanceCalculator(Attacker, Defender, ability, weather, missionTime, isCovered, resultModifier, detailInfo, damageFlag, perfChecker);
	perfChecker:Rise();
	-- C4. 적 방어 확률을 계산 합니다 
	perfChecker:StartRoutine('BlockCalculation');
	local blockRate = GetBlockRateCalculator(Attacker, Defender, ability, missionTime, detailInfo, damageFlag);
	-- C5. 극대화 비율을 계산 합니다.
	perfChecker:StartRoutine('CSDCalculation');
	local criticalDeal = GetCriticalStrikeDealCalculator(Attacker, Defender, ability, detailInfo);
	
	-- 1. Select Attacker State --
	perfChecker:StartRoutine('DecideAttackerState');
	local resultModifierAttackerState = SafeIndex(resultModifier, 'AttackerState');
	local isEnableCriticalStrikeChance = IsEnableCriticalStrikeChance(criticalStrikeChance, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender);
	if resultModifierAttackerState and resultModifierAttackerState ~= 'NotUsed' then
		attackerState = resultModifierAttackerState;
	elseif isEnableCriticalStrikeChance then
		attackerState = 'Critical';
	end
		
	-- 2. Select Defender State --	
	perfChecker:StartRoutine('DecideDodge');
	local reactionAbility = SafeIndex(resultModifier, 'ReactionAbility') and true or false;	-- 반응 공격 여부
	local resultModifierDefenderState = SafeIndex(resultModifier, 'DefenderState');
	local isEnableDodge = IsEnableDodge(actions, hitRate, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, reactionAbility, missionTime, damageFlag, damage);
	perfChecker:StartRoutine('DecideBlock');
	local isEnableBlock = IsEnableBlock(blockRate, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, damage);
	
	if resultModifierDefenderState and resultModifierDefenderState ~= 'NotUsed' then
		defenderState = resultModifierDefenderState;
	elseif ability.Type == 'Heal' then
		defenderState = 'Heal';
	elseif isEnableDodge then
		defenderState = 'Dodge';
	elseif isEnableBlock then
		defenderState = 'Block';
	end
	perfChecker:StartRoutine('Miscellaneous');
	-- attackerState와 defenderState의 변경 또는 데미지 증가가 필요한 것들을 미리 처리한다.
	if ability.Type ~= 'Heal' and Defender then
		damage, attackerState, defenderState, knockbackPower = GetModifyResultActions_PreState(actions, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, damage, attackerState, defenderState, knockbackPower, damageFlag, detailInfo);
	end
	
	if defenderState == 'Block' then
		attackerState = 'Normal';
	end
	
	-- Calculated Damaged --
	if attackerState == 'Critical' then
		damage = damage + damage * criticalDeal/100;
	end	
	
	perfChecker:StartRoutine('CalculateMinDamage');
	local minDamage = CalculateAbilityMinDamage(ability, phase, Attacker, Defender);
	
	perfChecker:StartRoutine('FinalizeDamage');
	if defenderState == 'Dodge' then
		damage = 0;
	elseif defenderState == 'Heal' then
		damage = -1 * damage;
	elseif defenderState == 'Block' then
		local damagePreBlocked = damage;
		local damageReduce = GetDamageReduceOnBlockCalculator(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender, resultModifier);		
		damage = math.max(minDamage, damage * (1 - damageReduce));
		damageBlocked = math.floor(math.max(damagePreBlocked - damage, 0));
	else
		damage = math.max(minDamage, damage);
	end
	
	-- 5. 확정된 state 에 따른 피해량 Modify
	perfChecker:StartRoutine('ApplyResultModifier');
	if SafeIndex(resultModifier, 'DamageAdjust') == 'Use' and defenderState ~= 'Dodge' then
		damage = ResultModifier_Damage(damage, resultModifier);
	else
		damage, attackerState, defenderState, knockbackPower = GetModifyResultActions_Final(actions, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, damage, attackerState, defenderState, knockbackPower, damageFlag);
	end
	damage = math.floor(damage);
	
	if knockbackPower > 0 and SafeIndex(resultModifier, 'Moving') then
		knockbackPower = 0;
		table.insert(actions, Result_FireWorldEvent('MovingKnockbackIgnored', {Attacker=Attacker, Defender=Defender}, nil, true));
	end
	
	perfChecker:StartRoutine('ProcessAfterEvent');
	-- 5. 공격에 따른 이벤트.
	-- 대미지, 공격상태를 변경하지 않는다.
	-- 공격자와 피격자의 결과값이 더 이상 변하지 않고 해당 결과 값에 따라 변하는 특성들을 처리한다. 후처리 부.
	-- 사망 유무에 따라 버프 적용 유무가 달라질 수 있으므로, 더미 데미지 액션으로 데미지 테스트를 해서 사망 유무를 알아냄
	local realDamage = damage;
	if IsMissionServer() then
		local damageInfo = Result_Damage(damage, attackerState, defenderState, Attacker, Defender, 'Ability', ability.SubType, ability, resultModifier and resultModifier.NoReward or nil, damageBlocked);
		realDamage = ApplyDamageTest(Defender, damage, damageInfo);
	end
	local isDead = (Defender.HP <= realDamage);
	local buffApplied = AddBattleResultEventAction(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender, resultModifier, isDead, realDamage);
	if IsMissionServer() then
		LogAndPrint(string.format('[%s]>>== Battle ==: [%s] use [%s] Ability to [%s]', GetMissionGID(Attacker), Attacker.name, ability.name, SafeIndex(Defender, 'name')));
		LogAndPrintDev('Damage: ', damage, 'State: ', attackerState..'/'..defenderState, 'KB:', knockbackPower);
		LogAndPrintDev('==============================================================');
	end
	return damage, attackerState, defenderState, knockbackPower, damageBlocked, buffApplied, damageFlag;
end
----------------------------------------------------------------
-- 방어시 피해량 결정 함수.
-----------------------------------------------------------------
function GetDamageReduceOnBlockCalculator(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender, resultModifier)
	local damageReduce = 0.5;
	-- 성문 파괴.
	if IsGetAbilitySubType(ability, 'Slashing') then
		local mastery_BreakCastleGate = GetMasteryMastered(masteryTable_Attacker, 'BreakCastleGate');
		if mastery_BreakCastleGate then
			damageReduce = damageReduce - damageReduce * mastery_BreakCastleGate.ApplyAmount / 100;
			AddMasteryInvokedEvent(Attacker, mastery_BreakCastleGate.name, 'FirstHit');
		end
	end
	-- 화경
	if ability.HitRateType == 'Melee' then
		local mastery_NeutralizingEnergy = GetMasteryMastered(masteryTable_Defender, 'NeutralizingEnergy');
		if mastery_NeutralizingEnergy then
			-- 정중동
			local mastery_MartialArtStaticMonement = GetMasteryMastered(masteryTable_Defender, 'MartialArtStaticMonement');
			if mastery_MartialArtStaticMonement then
				damageReduce = damageReduce + mastery_MartialArtStaticMonement.ApplyAmount / 100;
				AddMasteryInvokedEvent(Defender, mastery_NeutralizingEnergy.name, 'FirstHit');
				AddMasteryInvokedEvent(Defender, mastery_MartialArtStaticMonement.name, 'FirstHit');
			end
		end
	end
	return damageReduce;
end
----------------------------------------------------------------
-- 측면 목표 판단 함수
-----------------------------------------------------------------
function IsCoverStateNone(Attacker, Defender, masteryTable_Attcker, masteryTable_Defender)
	local coverState = GetCoverStateForCritical(Defender, masteryTable_Defender, GetPosition(Attacker), Attacker);
	if coverState ~= 'None' then
		return false;
	end
	-- 예민한 감각, 드라키의 완벽한 비늘
	local mastery_AcuteSense = GetMasteryMasteredList(masteryTable_Defender, {'AcuteSense', 'Amulet_Draky_Scale3'});
	if mastery_AcuteSense then
		return false;
	end
	return true;
end
----------------------------------------------------------------
-- 각 상황 판단 함수. 회피/ 방어/ 크리티컬
-----------------------------------------------------------------
function IsEnableDodge(actions, hitRate, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, reactionAbility, missionTime, damageFlag, damage)
	-- 회복 어빌리티 & 어빌리티 회피 불가
	if ability.Type == 'Heal' or ability.IgnoreDodge then
		return false, 'Heal';
	end
	-- 행운 / 공격자
	local buff_Luck_Attacker = GetBuff(Attacker, 'Luck');
	if buff_Luck_Attacker then
		AddBattleEvent(Attacker, 'BuffRevealedFromAbility', {Buff = buff_Luck_Attacker.name, EventType = 'FirstHit'});
		return false, buff_Luck_Attacker.name;
	end
	-- 행운 / 피격자
	local buff_Luck_Defender = GetBuff(Defender, 'Luck');
	-- 무조건 명중이지만 행운으로 피해지는 것들
	if not buff_Luck_Defender then
		-- 결정타
		if ability.Type == 'Attack' then
			local mastery_FinalBlow = GetMasteryMastered(masteryTable_Attacker, 'FinalBlow');
			if mastery_FinalBlow then
				if Defender.HP < Defender.MaxHP * mastery_FinalBlow.ApplyAmount2/100 then
					damageFlag.FinalBlow = true;
					return false, mastery_FinalBlow.name;
				end
			end
		end
		-- 특성 발동으로 인한 무조건 명중 어빌리티 사용 (ex. 연격, 살을 주고 뼈를 취한다.)
		if damageFlag.Inevitable then
			return false, 'Inevitable';
		end
		-- 특성 기습 & 어둠사냥꾼
		if Defender ~= nil and IsDarkTime(missionTime) then
			local mastery_Ambush = GetMasteryMastered(masteryTable_Attacker, 'Ambush');
			local mastery_DarkHunter = GetMasteryMastered(masteryTable_Attacker, 'DarkHunter');
			if mastery_Ambush and mastery_DarkHunter and not HasBuff(Attacker, 'ExposurePosition') then
				local group_Sleep_List = GetBuffType(Defender, nil, nil, mastery_DarkHunter.BuffGroup.name);
				if #group_Sleep_List > 0 or Defender.PreBattleState then
					return false, mastery_Ambush.name;
				end
			end
		end	
	end
	
	-- 반응 공격 회피
	if reactionAbility then
		-- 전광석화
		if GetMasteryMastered(masteryTable_Defender, 'LightningReflexes') and not GetBuffStatus(Defender, 'Unconscious', 'Or') then
			-- 전광석화는 반응 사격만 회피 가능
			local isEnableDodgeAbility = ability.HitRateType ~= 'Melee';
			local alreadyApplied = GetInstantProperty(Defender, 'LightningReflexesUsed');
			if IsDarkTime(missionTime) then
				local mastery_DarkHunter = GetMasteryMastered(masteryTable_Defender, 'DarkHunter');
				if mastery_DarkHunter and not HasBuff(Defender, 'ExposurePosition') then
					alreadyApplied = false; -- 최초 1회 뿐만 아니라 계속 피한다.
					AddMasteryInvokedEvent(Defender, mastery_DarkHunter.name, 'FirstHit');
					-- 어둠사냥꾼은 반응 공격 모두 회피 가능
					isEnableDodgeAbility = true;
				end
			end
			if not alreadyApplied and isEnableDodgeAbility then
				SetInstantProperty(Defender, 'LightningReflexesUsed', true);	-- 해당 프로퍼티의 초기화는 이벤트 핸들러에서 맡는다
				AddMasteryInvokedEvent(Defender, 'LightningReflexes', 'FirstHit');
				-- 일기당천
				local mastery_MatchlessWarrior = GetMasteryMastered(masteryTable_Defender, 'MatchlessWarrior');
				if mastery_MatchlessWarrior then
					AddSPPropertyActionsObject(actions, Defender, mastery_MatchlessWarrior.ApplyAmount);
					AddMasteryInvokedEvent(Defender, mastery_MatchlessWarrior.name, 'FirstHit');
				end
				-- 날렵한 발놀림
				local mastery_NimbleFootwork = GetMasteryMastered(masteryTable_Defender, 'NimbleFootwork');
				if mastery_NimbleFootwork then
					local applyAct = -1 * mastery_NimbleFootwork.ApplyAmount;
					local added, reasons = AddActionApplyAct(actions, Defender, Defender, applyAct, 'Friendly');
					if added then
						AddBattleEvent(Defender, 'AddWait', { Time = applyAct });
					end
					ReasonToAddBattleEventMulti(Defender, reasons, 'FirstHit');
					AddMasteryInvokedEvent(Defender, mastery_NimbleFootwork.name, 'FirstHit');
				end
				-- 거리의 싸움꾼
				local mastery_StreetFighter = GetMasteryMastered(masteryTable_Defender, 'StreetFighter');
				if mastery_StreetFighter then
					InsertBuffActions(actions, Defender, Defender, mastery_StreetFighter.Buff.name, 1, true);
					AddMasteryInvokedEvent(Defender, mastery_StreetFighter.name, 'FirstHit');
				end
				-- 전장을 뚫어라
				local mastery_DrillBattleField = GetMasteryMastered(masteryTable_Defender, 'DrillBattleField');
				if mastery_DrillBattleField then
					InsertBuffActions(actions, Defender, Defender, mastery_DrillBattleField.Buff.name, 1, true);
					AddMasteryInvokedEvent(Defender, mastery_DrillBattleField.name, 'FirstHit');
				end
				-- 빗나간 죽음
				local mastery_LuckyCheatDeath = GetMasteryMastered(masteryTable_Defender, 'LuckyCheatDeath');
				if mastery_LuckyCheatDeath then
					local adjustValue = GetInstantProperty(Defender, mastery_LuckyCheatDeath.name) or 0;
					adjustValue = adjustValue + mastery_LuckyCheatDeath.ApplyAmount3;
					SetInstantProperty(Defender, mastery_LuckyCheatDeath.name, adjustValue);
				end
				-- 달빛의 괴수
				local mastery_MoonMonster = GetMasteryMastered(masteryTable_Defender, 'MoonMonster');
				if mastery_MoonMonster then
					local applyAct = -1 * mastery_MoonMonster.ApplyAmount;
					local added, reasons = AddActionApplyAct(actions, Defender, Defender, applyAct, 'Friendly');
					if added then
						AddBattleEvent(Defender, 'AddWait', { Time = applyAct });
					end
					ReasonToAddBattleEventMulti(Defender, reasons, 'FirstHit');
					AddMasteryInvokedEvent(Defender, mastery_MoonMonster.name, 'FirstHit');
				end
				return true, 'LightningReflexes'
			end
		end
		-- 질풍신뢰는 반응 공격 모두 회피 가능
		if HasBuff(Defender, 'FlashAura') and not GetBuffStatus(Defender, 'Unconscious', 'Or') then
			AddBattleEvent(Defender, 'BuffRevealedFromAbility', {Buff = 'FlashAura', EventType = 'FirstHit'});
			return true, 'FlashAura';
		end
		-- 고속 호버링
		local mastery_Module_HighSpeedHovering = GetMasteryMastered(masteryTable_Defender, 'Module_HighSpeedHovering');
		if mastery_Module_HighSpeedHovering and mastery_Module_HighSpeedHovering.DuplicateApplyChecker > 0 then
			AddMasteryInvokedEvent(Defender, mastery_Module_HighSpeedHovering.name, 'FirstHit');
			return true, mastery_Module_HighSpeedHovering.name;
		end
		-- 자동 회피 반응
		local mastery_Module_LightningReflexes = GetMasteryMastered(masteryTable_Defender, 'Module_LightningReflexes');
		if mastery_Module_LightningReflexes and not GetBuffStatus(Defender, 'Unconscious', 'Or') then
			local needCost = (mastery_Module_LightningReflexes.DuplicateApplyChecker + 1) * mastery_Module_LightningReflexes.ApplyAmount;
			if needCost <= Defender.Cost then
				mastery_Module_LightningReflexes.DuplicateApplyChecker = mastery_Module_LightningReflexes.DuplicateApplyChecker + 1;
				AddMasteryInvokedEvent(Defender, mastery_Module_LightningReflexes.name, 'FirstHit');
				damageFlag.Module_LightningReflexes = true;
				return true, 'Module_LightningReflexes';
			end
		end
		-- 드라키의 완벽한 비늘
		local mastery_Amulet_Draky_Scale3 = GetMasteryMastered(masteryTable_Defender, 'Amulet_Draky_Scale3');
		if mastery_Amulet_Draky_Scale3 and not GetBuffStatus(Defender, 'Unconscious', 'Or') then
			if mastery_Amulet_Draky_Scale3.DuplicateApplyChecker <= 0 then
				mastery_Amulet_Draky_Scale3.DuplicateApplyChecker = 1;
				AddMasteryInvokedEvent(Defender, mastery_Amulet_Draky_Scale3.name, 'FirstHit');
				return true, mastery_Amulet_Draky_Scale3.name;
			end
		end
	end

	-- 엄폐 이동
	if IsLongDistanceAttack(ability) and Defender.Coverable then
		local mastery_MoveWithCover = GetMasteryMastered(masteryTable_Defender, 'MoveWithCover');
		if mastery_MoveWithCover 
			and (GetBuff(Defender, 'Conceal') or GetBuff(Defender, 'Conceal_For_Aura')) 
			and GetCoverState(Defender, GetPosition(Attacker)) ~= 'None' then
			AddMasteryInvokedEvent(Defender, mastery_MoveWithCover.name, 'FirstHit');
			return true, mastery_MoveWithCover.name;
		end
	end
	
	-- 행운으로 인한 회피는 위의 로직들로 못 피했을 때만 발동
	if buff_Luck_Defender then
		AddBattleEvent(Defender, 'BuffRevealedFromAbility', {Buff = buff_Luck_Defender.name, EventType = 'FirstHit'});
		buff_Luck_Defender.DuplicateApplyChecker = 1;
		return true, buff_Luck_Defender.name;
	end		

	return not AbilityHitRateTest(Attacker, Defender, hitRate, damage);
end
function IsEnableBlock(blockRate, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, damage)
	if ability.Type == 'Heal' or ability.IgnoreBlock then
		return false, 'Heal';
	end
	-- 행운 / 공격자, 피격자.
	local buff_Luck = GetBuff(Attacker, 'Luck');
	if buff_Luck then
		return false, buff_Luck.name;
	end
	if ability.Type == 'Attack' then	
		-- 결정타
		local mastery_FinalBlow = GetMasteryMastered(masteryTable_Attacker, 'FinalBlow');
		if mastery_FinalBlow then
			if Defender.HP < Defender.MaxHP * mastery_FinalBlow.ApplyAmount2/100 then
				return false, mastery_FinalBlow.name;
			end
		end
	end
	return AbilityBlockRateTest(Attacker, Defender, blockRate, damage);
end
function IsEnableCriticalStrikeChance(criticalStrikeChance, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, damage)
	if ability.DamageType == 'Explosion' then
		return false, 'Explosion';
	end
	local buff_Luck = GetBuff(Attacker, 'Luck');
	if buff_Luck then
		return true, buff_Luck.name;
	end
	if ability.Type == 'Attack' then
		-- 결정타
		local mastery_FinalBlow = GetMasteryMastered(masteryTable_Attacker, 'FinalBlow');
		if mastery_FinalBlow then
			if Defender.HP < Defender.MaxHP * mastery_FinalBlow.ApplyAmount2/100 then
				AddMasteryInvokedEvent(Attacker, mastery_FinalBlow.name, 'FirstHit');
				return true, mastery_FinalBlow.name;
			end
		end
	end
	return AbilityCriticalStrikeChanceTest(Attacker, Defender, criticalStrikeChance, damage);
end
------------------------------------------------------------------------------------------------------------------------
-- 전투 상황으로 인한 이벤트 처리
-------------------------------------------------------------------------------------------------------------------------
function AddBattleResultEventAction(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender, resultModifier, isDead, realDamage)
	local buffApplied = false;
	local isHit = defenderState ~= 'Dodge' and (damage <= 0 or (Defender and GetBuff(Defender, 'StarShield') == nil));
	
	-- 1. 기본 어빌리티 컬럼 로직.
	-- 어빌리티에 RemoveBuff 로직
	local remove_Buff = ability.RemoveBuff;
	local remove_BuffName = GetWithoutError(remove_Buff, 'name');
	if remove_BuffName and remove_BuffName ~= 'None' then
		InsertBuffActions(actions, Attacker, Attacker, remove_Buff.name, -1 * remove_Buff:MaxStack(Attacker), false, nil, true);
	end
	-- 어빌리티 ApplyTargetBuff 로직.
	-- 피격 해야만 걸리는 버프.
	if Defender then
		if isHit then
			local buffName = ability.ApplyTargetBuff.name;
			if buffName then
				local resultModifier_ApplyBuff = SafeIndex(resultModifier, 'ApplyBuff');
				if ( resultModifier_ApplyBuff and resultModifier_ApplyBuff == 'Use' ) or
					( not resultModifier_ApplyBuff and RandomTest(ability.ApplyTargetBuffChance) )
				then
					InsertBuffActions(actions, Attacker, Defender, buffName, ability.ApplyTargetBuffLv, true, nil, true, nil, isDead);
					buffApplied = true;
				end
			end
		end
	end
	-- 피격 해야만 걸리는 ApplyAct값
	if Defender then
		if isHit or ability.Containment then
			local applyRatio = isHit and 1.0 or 0.5;
			if ability.ApplyAct ~= 0 then
				local added, reasons = AddActionApplyAct(actions, Attacker, Defender, ability.ApplyAct * applyRatio, 'Hostile');
				if added then
					AddBattleEvent(Defender, 'AddWait', { Time = ability.ApplyAct * applyRatio });
				end
				ReasonToAddBattleEventMulti(Defender, reasons, 'FirstHit');
			end
		end
	end	
	
	-- 피격 해야만 걸리는 ApplyCost값 (CostBurnRatio 포함)
	if Defender and isHit and IsValidCostType(Defender, ability.ApplyCostType) then
		local applyCost = GetAbilityApplyCost(ability, Attacker, Defender);
		if applyCost ~= 0 and ability.name ~= 'StarArrow' then -- StarArrow 어빌리티는 ABL_STAR_ARROW 함수에서 따로 처리하므로 무시
			local _, reasons = AddActionCost(actions, Defender, applyCost, true);
			AddBattleEvent(Defender, 'AddCostCustomEvent', { CostType = Defender.CostType.name, Count = applyCost, EventType = 'FinalHit' });
			ReasonToAddBattleEventMulti(Defender, reasons, 'FinalHit');
		end	
	end

	-- 3. 일반 특성 이벤트
	-- 1) 피격 시 이벤트
	AddBattleResultEventAction_Normal_Hitable(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender, realDamage);	
	-- 2) 회피 시 이벤트
	AddBattleResultEventAction_Normal_Dodge(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender);	
	-- 3) 사망 시 이벤트
	if isDead then
		AddBattleResultEventAction_Normal_Dead(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender, isDead);
	end
	return buffApplied;
end
------------------------------------------------------------------------------------------------------------------------
-- 어빌리티에 의한 모든 이벤트 처리.
-------------------------------------------------------------------------------------------------------------------------
-- 피격 시.
------------------------------------------------
function AddBattleResultEventAction_Normal_Hitable(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender, realDamage)
	-- 방어자가 있어야 하는 로직 구분자.
	if not Defender then
		return;
	end
	
	-- 회피 하면 동작하지 않는다.
	if defenderState == 'Dodge' or (damage > 0 and GetBuff(Defender, 'StarShield') ~= nil) then
		return;
	end
		
	-- 1.공격 타입
	if ability.Type == 'Attack' and ability.HitRateType == 'Melee' then
		-- 특성. 분쇄
		local mastery_Rend = GetMasteryMastered(masteryTable_Attacker, 'Rend');
		if mastery_Rend then
			local successRate = mastery_Rend.ApplyAmount;
			local addBuffLv = 1;
			-- 전심전력
			local mastery_GreatApplication = GetMasteryMastered(masteryTable_Attacker, 'GreatApplication');
			if mastery_GreatApplication then
				successRate = 100;
			end
			-- 사석위호
			local mastery_StuckArrowheadInStone = GetMasteryMastered(masteryTable_Attacker, 'StuckArrowheadInStone');
			if mastery_StuckArrowheadInStone then
				addBuffLv = addBuffLv + mastery_StuckArrowheadInStone.ApplyAmount2;
			end
			if RandomTest(successRate) then
				InsertBuffActions(actions, Attacker, Defender, mastery_Rend.Buff.name, addBuffLv, true, nil, true);
				AddMasteryInvokedEvent(Attacker, mastery_Rend.name, 'Ending');
				if mastery_GreatApplication then
					AddMasteryInvokedEvent(Attacker, mastery_GreatApplication.name, 'Ending');
				end
				if mastery_StuckArrowheadInStone then
					AddMasteryInvokedEvent(Attacker, mastery_StuckArrowheadInStone.name, 'Ending');
				end
			end
		end
		-- 특성. 촌경
		local mastery_OneInchPunch = GetMasteryMastered(masteryTable_Attacker, 'OneInchPunch');
		if mastery_OneInchPunch and IsStableAttack(Attacker) then
			-- 절차탁마
			local mastery_Polishing = GetMasteryMastered(masteryTable_Attacker, 'Polishing');
			if mastery_Polishing then
				AddMasteryInvokedEvent(Attacker, mastery_Polishing.name, 'Ending');
				local applyAct = mastery_Polishing.ApplyAmount;
				local added, reasons = AddActionApplyAct(actions, Attacker, Defender, applyAct, 'Hostile');
				if added then
					AddBattleEvent(Defender, 'AddWait', { Time = applyAct });
				end
				ReasonToAddBattleEventMulti(Defender, reasons, 'Ending');
			end
		end
		
		-- 난폭한 트롤 장갑
		local mastery_BattleGlove_Skull = GetMasteryMastered(masteryTable_Attacker, 'BattleGlove_Skull');
		if mastery_BattleGlove_Skull then
			AddMasteryInvokedEvent(Attacker, mastery_BattleGlove_Skull.name, 'Ending');
			local added, reasons = AddActionApplyAct(actions, Attacker, Defender, mastery_BattleGlove_Skull.ApplyAmount, 'Hostile');
			if added then
				AddBattleEvent(Defender, 'AddWait', { Time = mastery_BattleGlove_Skull.ApplyAmount});
			end
			ReasonToAddBattleEventMulti(Attacker, reasons, 'Ending');
		end
	end
	
	-- 2.속성 타입
	-- 1) 물리 속성 공격 일때
	if ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Physical') then
	
		-- (1) 공통 
		-- BoneBreaker
		local mastery_BoneBreaker = GetMasteryMastered(masteryTable_Attacker, 'BoneBreaker');
		if mastery_BoneBreaker then
			local applyAmount = mastery_BoneBreaker.ApplyAmount;
			if RandomTest(applyAmount) then
				InsertBuffActions(actions, Attacker, Defender, mastery_BoneBreaker.Buff.name, 1, true, nil, true);
				AddMasteryInvokedEvent(Attacker, mastery_BoneBreaker.name, 'Ending');
			end
		end
		
		-- (2) 타격 속성 공격 일때
		if ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Blunt')  then
			--
		end	
		-- (3). 참격 속성 공격 일때
		if ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Slashing') then
			-- 특성. 방어구 가르기
			local mastery_BreakArmor = GetMasteryMastered(masteryTable_Attacker, 'BreakArmor');
			if mastery_BreakArmor then
				local applyAmount = mastery_BreakArmor.ApplyAmount;
				-- 특성. 파괴의 검
				local mastery_DestroySword = GetMasteryMastered(masteryTable_Attacker, 'DestroySword');
				if mastery_DestroySword then
					applyAmount = 100;
				end
				if RandomTest(applyAmount) then
					InsertBuffActions(actions, Attacker, Defender, mastery_BreakArmor.Buff.name, 1, true, nil, true);
					AddMasteryInvokedEvent(Attacker, mastery_BreakArmor.name, 'Ending');
				end
			end
		end
		-- (4). 관통 속성 공격 일때
		if ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Piercing') then
			-- 특성. 무기 무력화
			local mastery_BreakWeapon = GetMasteryMastered(masteryTable_Attacker, 'BreakWeapon');
			if mastery_BreakWeapon then
				local applyAmount = mastery_BreakWeapon.ApplyAmount;
				-- 특성. 나는 전설이다
				local mastery_ImLegend = GetMasteryMastered(masteryTable_Attacker, 'ImLegend');
				if mastery_ImLegend then
					applyAmount = 100;
				end
				if RandomTest(applyAmount) then
					InsertBuffActions(actions, Attacker, Defender, mastery_BreakWeapon.Buff.name, 1, true, nil, true);
					AddMasteryInvokedEvent(Attacker, mastery_BreakWeapon.name, 'Ending');
				end
			end
		end
	end
	
	-- 4). 화염 초능력 공격 시.	
	if ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Fire') then
		if attackerState == 'Critical' then
			-- 1) 방화광 : 어빌리티 1 감소.
			local mastery_Pyromaniac = GetMasteryMastered(masteryTable_Attacker, 'Pyromaniac');
			if mastery_Pyromaniac then
				AddAbilityCoolActions(actions, Attacker, -mastery_Pyromaniac.ApplyAmount, function(curAbility)
					return curAbility.SubType == 'Fire';
				end);
				AddBattleEvent(Attacker, 'Pyromaniac');
				-- 불꽃놀이
				local mastery_Firework = GetMasteryMastered(masteryTable_Attacker, 'Firework');
				if mastery_Firework then
					AddSPPropertyActionsObject(actions, Attacker, mastery_Firework.ApplyAmount);
					AddMasteryInvokedEvent(Attacker, mastery_Firework.name, 'FirstHit');
				end
			end
		end
		-- 특성. 타오르는 숨결
		local mastery_BurningBreath = GetMasteryMastered(masteryTable_Attacker, 'BurningBreath');
		if mastery_BurningBreath then
			local applyAmount = mastery_BurningBreath.ApplyAmount
			-- 특성. 업화
			local mastery_Hellfire = GetMasteryMastered(masteryTable_Attacker, 'Hellfire');
			if mastery_Hellfire then
				applyAmount = 100;
			end
			if RandomTest(applyAmount) then
				InsertBuffActions(actions, Attacker, Defender, mastery_BurningBreath.Buff.name, 1, true, nil, true);
				AddMasteryInvokedEvent(Attacker, mastery_BurningBreath.name, 'Ending');
			end
		end
	end	
	
	-- 5). 얼음 초능력 공격 시.
	if ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Ice') then
		-- 특성. 얼어붙은 숨결
		local mastery_FrozenBreath = GetMasteryMastered(masteryTable_Attacker, 'FrozenBreath');
		if mastery_FrozenBreath then
			local applyAmount = mastery_FrozenBreath.ApplyAmount;
			local addBuffLv = 1;
			-- 얼어붙은 대지
			local mastery_FrozenGround = GetMasteryMastered(masteryTable_Attacker, 'FrozenGround');
			if mastery_FrozenGround then
				applyAmount = 100;
			end
			-- 얼어붙은 마지막 생명의 불꽃
			local mastery_FrozenLastLifeFlame = GetMasteryMastered(masteryTable_Attacker, 'FrozenLastLifeFlame');
			if mastery_FrozenLastLifeFlame then
				addBuffLv = addBuffLv + mastery_FrozenLastLifeFlame.ApplyAmount;
			end
			if RandomTest(applyAmount) then
				InsertBuffActions(actions, Attacker, Defender, mastery_FrozenBreath.Buff.name, addBuffLv, true, nil, true);
				AddMasteryInvokedEvent(Attacker, mastery_FrozenBreath.name, 'Ending');
			end
		end
	end
	
	-- 6) 번개 초능력 공격시 
	if ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Lightning') then
		-- 특성 벼락
		local mastery_ThunderBolt = GetMasteryMastered(masteryTable_Attacker, 'ThunderBolt');
		if mastery_ThunderBolt then
			local applyAmount = mastery_ThunderBolt.ApplyAmount;
			-- 특성. 거대한 벼락
			local mastery_BigThunderBolt = GetMasteryMastered(masteryTable_Attacker, 'BigThunderBolt');
			if mastery_BigThunderBolt then
				applyAmount = applyAmount + math.floor(GetCurrentSP(Attacker) / mastery_BigThunderBolt.ApplyAmount) * mastery_BigThunderBolt.ApplyAmount2;
			end
			if RandomTest(applyAmount) then
				InsertBuffActions(actions, Attacker, Defender, mastery_ThunderBolt.Buff.name, 1, true, nil, true);
				AddMasteryInvokedEvent(Attacker, mastery_ThunderBolt.name, 'Ending');
			end
		end
	end
	
	-- 특성. 얼음 파편
	if ability.Type == 'Attack' then
		local mastery_IceFraction = GetMasteryMastered(masteryTable_Attacker, 'IceFraction');
		if mastery_IceFraction and HasBuffType(Defender, nil, nil, mastery_IceFraction.BuffGroup.name) then
			local addBuff = mastery_IceFraction.Buff.name;
			-- 얼어붙은 검
			local mastery_FrozenSword = GetMasteryMastered(masteryTable_Attacker, 'FrozenSword');
			if mastery_FrozenSword then
				addBuff = mastery_FrozenSword.Buff.name;
			end
			InsertBuffActions(actions, Attacker, Defender, addBuff, 1, true, nil, true);
			AddMasteryInvokedEvent(Attacker, mastery_IceFraction.name, 'Ending');
		end
	end
	
	-- 흑철 파괴 장갑
	if ability.Type == 'Attack' and ability.HitRateType == 'Melee' then
		-- 확률 디버프
		local mastery_BattleGlove_YellowIronFist = GetMasteryMasteredList(masteryTable_Attacker,
		{
			'BattleGlove_YellowIronFist',
			'BattleGlove_YellowIronFist_Rare',
		});
		if mastery_BattleGlove_YellowIronFist and RandomTest(mastery_BattleGlove_YellowIronFist.ApplyAmount) then
			InsertBuffActions(actions, Attacker, Defender, mastery_BattleGlove_YellowIronFist.Buff.name, 1, true, nil, true);
			AddMasteryInvokedEvent(Attacker, mastery_BattleGlove_YellowIronFist.name, 'Ending');
		end
		-- 100% 디버프
		local mastery_BattleGlove_YellowIronFist_Epic = GetMasteryMasteredList(masteryTable_Attacker,
		{
			'BattleGlove_YellowIronFist_Ice_Epic',
			'BattleGlove_YellowIronFist_Fire_Epic',
			'BattleGlove_YellowIronFist_Lightning_Epic',
		});
		if mastery_BattleGlove_YellowIronFist_Epic then
			InsertBuffActions(actions, Attacker, Defender, mastery_BattleGlove_YellowIronFist_Epic.Buff.name, 1, true, nil, true);
			AddMasteryInvokedEvent(Attacker, mastery_BattleGlove_YellowIronFist_Epic.name, 'Ending');
		end
	end
	
	-- 선혈의 야수
	if ability.Type == 'Attack' then
		local mastery_BloodyBeast = GetMasteryMastered(masteryTable_Attacker, 'BloodyBeast');
		if mastery_BloodyBeast and realDamage > 0 and HasBuffType(Defender, nil, nil, mastery_BloodyBeast.BuffGroup.name) then
			mastery_BloodyBeast.CountChecker = 1;
		end
	end
	
	local ConditionalMasteryBuffApplier = function(masteryTable, masteryType, conditionFunc, doFunc)
		local mastery = GetMasteryMastered(masteryTable, masteryType);
		if mastery and conditionFunc(mastery) then
			InsertBuffActions(actions, Attacker, Defender, mastery.Buff.name, 1, nil, nil, true);
			AddMasteryInvokedEvent(Attacker, mastery.name, 'Ending');
			if doFunc then
				doFunc(mastery);
			end
		end
	end
	
	if ability.Type == 'Attack' then
		-- 특성. 신경독
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'Neurotoxin', function(m) return attackerState == 'Critical' end);
		-- 특성. 마비독
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'ParalysisPoison', function(m) return attackerState == 'Critical' end);
		-- 특성. 산성독
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'AcidPoison', function(m) return attackerState == 'Critical' end);
		-- 특성. 부식독
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'CorrosionPoison', function(m) return attackerState == 'Critical' end);
		-- 특성. 수면독
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'SleepPoison', function(m) return attackerState == 'Critical' end);
		-- 특성 독 바르기.
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'Envenoming', function(m) return attackerState == 'Critical' end);
		-- 특성 독니
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'VenomFang', function(m) return attackerState == 'Critical' end);
		-- 특성 산성 점액
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'AcidMucus', function(m) return attackerState == 'Critical' end, function(m)
			-- 점액 분비
			local mastery_SecretionOfMucus = GetMasteryMastered(masteryTable_Attacker, 'SecretionOfMucus');
			if mastery_SecretionOfMucus then
				AddMasteryInvokedEvent(Attacker, mastery_SecretionOfMucus.name, 'Ending');
				local applyAct = -1 * mastery_SecretionOfMucus.ApplyAmount;
				local added, reasons = AddActionApplyAct(actions, Attacker, Attacker, applyAct, 'Friendly');
				if added then
					AddBattleEvent(Attacker, 'AddWait', { Time = applyAct });
				end
				ReasonToAddBattleEventMulti(Attacker, reasons, 'Ending');
			end
		end);
		-- 특성 강력한 주포
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'StrongCannon', function(m) return attackerState == 'Critical' end);
		-- 특성 커다란 이빨
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'BigFang', function(m) return ability.HitRateType == 'Melee' end);
		-- 특성 더러운 숨결
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'DirtyBreath', function(m) return ability.HitRateType == 'Force' end);
		-- 특성 맹독 괴수
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'PoisonMonster', function(m) return attackerState == 'Critical' and HasBuffType(Defender, 'Debuff', nil, m.BuffGroup.name) end);
	end
end
-------------------------------------------------------------------------------------------------------------------------
-- 회피 시.
------------------------------------------------
function AddBattleResultEventAction_Normal_Dodge(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender)
	-- 방어자가 있어야 하는 로직 구분자.
	if not Defender then
		return;
	end
	
	-- 회피 안하면 동작하지 않는다.
	if defenderState ~= 'Dodge' then
		return;
	end
	
	-- 0). 일반 공격.
	-- 1). 타격 속성 공격 일때
	-- 2). 참격 속성 공격 일때
	-- 3). 관통 속성 공격 일때
	if ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Piercing') and ability.HitRateType == 'Force' then
		-- 특성. 우연한 적중
		local mastery_LuckyShot = GetMasteryMastered(masteryTable_Attacker, 'LuckyShot');
		if mastery_LuckyShot then
			if RandomTest(mastery_LuckyShot.ApplyAmount) then
				InsertBuffActions(actions, Attacker, Defender, mastery_LuckyShot.Buff.name, 1, true, nil, true);
				AddMasteryInvokedEvent(Attacker, mastery_LuckyShot.name, 'Ending');
			end
		end	
	end
end
---------------------------------------------
-- 사망 시
---------------------------------------------
function AddBattleResultEventAction_Normal_Dead(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender)
	-- 명군사
	local mastery_GreatMilitaryAffairs = GetMasteryMastered(masteryTable_Attacker, 'GreatMilitaryAffairs');
	if mastery_GreatMilitaryAffairs then
		local group_debuff_List = GetBuffType(Defender, nil, nil, mastery_GreatMilitaryAffairs.BuffGroup.name);
		if #group_debuff_List > 0 or Defender.PreBattleState then
			mastery_GreatMilitaryAffairs.CountChecker = 1;
		end
	end
	-- 연계된 화공, 연계된 뇌공
	for _, testMasteryName in ipairs({ 'ChainFireTactics', 'ChainLightningTactics' }) do
		local testMastery = GetMasteryMastered(masteryTable_Attacker, testMasteryName);
		if testMastery and HasBuff(Defender, testMastery.Buff.name) then
			testMastery.CountChecker = 1;
		end
	end
	-- 달빛 사냥꾼
	local mastery_MoonHunter = GetMasteryMastered(masteryTable_Attacker, 'MoonHunter');
	if mastery_MoonHunter and IsDarkTime(GetMission(Attacker).MissionTime.name) then
		local group_debuff_List = GetBuffType(Defender, nil, nil, mastery_MoonHunter.BuffGroup.name);
		if #group_debuff_List > 0 or Defender.PreBattleState then
			mastery_MoonHunter.CountChecker = 1;
		end
	end
	-- 기습 훈련
	local mastery_AmbushTraining = GetMasteryMastered(masteryTable_Attacker, 'AmbushTraining');
	if mastery_AmbushTraining then
		local group_debuff_List = GetBuffType(Defender, nil, nil, mastery_AmbushTraining.BuffGroup.name);
		if #group_debuff_List > 0 or Defender.PreBattleState then
			mastery_AmbushTraining.CountChecker = 1;
			local ambushingKillList = GetInstantProperty(Attacker, 'AmbushingKillList') or {};
			table.insert(ambushingKillList, Defender);
			SetInstantProperty(Attacker, 'AmbushingKillList', ambushingKillList);
		end
	end

	-- 이중 극독
	local mastery_VenomExplosion = GetMasteryMastered(masteryTable_Attacker, 'VenomExplosion');
	if mastery_VenomExplosion then
		local debuffList = GetBuffType(Defender, 'Debuff', nil, mastery_VenomExplosion.BuffGroup.name);
		if #debuffList > 0 then
			mastery_VenomExplosion.CountChecker = 1;
			local killList = GetInstantProperty(Attacker, 'VenomExplosionKillList') or {};
			table.insert(killList, Defender);
			SetInstantProperty(Attacker, 'VenomExplosionKillList', killList);
			SetInstantProperty(Defender, 'VenomExplosionPoisonList', table.map(debuffList, function(b) return b.name end));
		end
	end
	-- 선혈의 미치광이
	local mastery_BloodSwordBerserker = GetMasteryMastered(masteryTable_Attacker, 'BloodSwordBerserker');
	if mastery_BloodSwordBerserker and HasBuffType(Defender, 'Debuff', nil, mastery_BloodSwordBerserker.BuffGroup.name) then
		mastery_BloodSwordBerserker.CountChecker = 1;
	end
	-- 만독
	local mastery_AllPoison = GetMasteryMastered(masteryTable_Attacker, 'AllPoison');
	if mastery_AllPoison and HasBuffType(Defender, 'Debuff', nil, mastery_AllPoison.BuffGroup.name) then
		mastery_AllPoison.CountChecker = 1;
	end
	-- 선혈의 괴수
	local mastery_BloodyMonster = GetMasteryMastered(masteryTable_Attacker, 'BloodyMonster');
	if mastery_BloodyMonster and HasBuffType(Defender, 'Debuff', nil, mastery_BloodyMonster.BuffGroup.name) then
		mastery_BloodyMonster.CountChecker = 1;
	end
	-- 지배자
	local mastery_Overlord = GetMasteryMastered(masteryTable_Attacker, 'Overlord');
	if mastery_Overlord and IsEnemy(Attacker, Defender) then
		local allyList = GetTargetInRangeSight(Attacker, 'Sight', 'Team', true);
		local enemyList = GetTargetInRangeSight(Attacker, 'Sight', 'Enemy', true);
		if #enemyList > #allyList then
			mastery_Overlord.CountChecker = 1;
		end
	end
	
	-- 얼어붙은 영혼 수확자
	local mastery_FrozenReaper = GetMasteryMastered(masteryTable_Attacker, 'FrozenReaper');
	if mastery_FrozenReaper then
		if IsEnemy(Attacker, Defender) and HasBuff(Defender, mastery_FrozenReaper.Buff.name) then
			mastery_FrozenReaper.CountChecker = 1;
		end
	end
	
	-- 붉은 송곳니
	local mastery_Amulet_Dorori_Fang_Red = GetMasteryMastered(masteryTable_Attacker, 'Amulet_Dorori_Fang_Red');
	if mastery_Amulet_Dorori_Fang_Red and HasBuffType(Defender, nil, nil, mastery_Amulet_Dorori_Fang_Red.BuffGroup.name) then
		mastery_Amulet_Dorori_Fang_Red.CountChecker = 1;
	end
end
-------------------------------------------------------------------------------------------------------
-- 전투 결과값 Battle Damage modify.  피해량 변화.
-------------------------------------------------------------------------------------------------------
function GetModifyResultActions_PreState(actions, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, damage, attackerState, defenderState, knockbackPower, damageFlag, abilityDetailInfo)
	----------------------------------------------------------------------------
	-- 모든 공격 방어 처리.
	----------------------------------------------------------------------------	
	if defenderState ~= 'Block' and defenderState ~= 'Dodge' then
		local mastery_LastStand = GetMasteryMastered(masteryTable_Defender, 'LastStand');
		if mastery_LastStand and Defender.HP / Defender.MaxHP * 100 <= mastery_LastStand.ApplyAmount then
			defenderState = 'Block';
			AddBattleEvent(Defender, 'LastStand');
		end
	end
	local damAdd = 0;
	local damMul = 0;
	----------------------------------------------------------------------------
	-- 피해량 조정부 : 해당 구문 이후 피해량 조정부를 뒤로 붙이지 말자. 계산 값이 달라진다.
	----------------------------------------------------------------------------	
	if defenderState ~= 'Dodge' then
		-- 특성. 헤드샷 HeadShot
		local headshotRatio = GetHeadshotRateCalculator(Attacker, Defender, ability, abilityDetailInfo);
		if headshotRatio > 0 then
			if DoNothingAITest(Defender) then
				headshotRatio = 100;
			end
			if RandomTest(headshotRatio) then
				AddBattleEvent(Attacker, 'HeadShot');
				local isImmuned, reason = IsHeadshotImmuned(Defender);
				if not isImmuned then
					damMul = damMul + (GetClassList('Mastery').HeadShot.ApplyAmount2 - 1) * 100;
				else
					AddBattleEvent(Defender, 'HeadShotImmuned', { Reason = reason[1] });
				end
			end
		end

		-- 특성 마력 폭발
		local mastery_SpellExplosion = GetMasteryMastered(masteryTable_Attacker, 'SpellExplosion');
		if mastery_SpellExplosion then
			local spellPower = GetBuff(Attacker, mastery_SpellExplosion.Buff.name);
			if spellPower then
				local activeChance = spellPower.Lv * mastery_SpellExplosion.ApplyAmount;
				if RandomTest(activeChance) then
					damMul = damMul + mastery_SpellExplosion.ApplyAmount2;
					spellPower.DuplicateApplyChecker = 1;
					AddMasteryInvokedEvent(Attacker, mastery_SpellExplosion.name, 'FirstHit');
				end
			end
		end
	end
	damage = damage * (1 + damMul / 100) + damAdd;
	
	if attackerState == 'Critical' and defenderState ~= 'Dodge' and ability.SubType == 'Lightning'
		and IsObjectOnFieldEffectBuffAffector(Defender, {'Water', 'ContaminatedWater'}) and Set.new({'Human', 'Beast'})[Defender.Race.name] then
		AddBattleEvent(Defender, 'BigTextCustomEvent', {Text = WordText('ChainEvent_Faint'), Font = 'NotoSansBlack-28', AnimKey = 'KnockbackStun',Color = 'FFFF5943', EventType = 'FinalHit'});
		InsertBuffActions(actions, Attacker, Defender, 'Stun', 1, true, nil, true, {Type = 'Faint'});
		table.insert(actions, Result_FireWorldEvent('ChainEffectOccured', {Unit = Defender, Trigger = Attacker, ChainType = 'Faint'}));
	end
	
	if attackerState == 'Critical' and defenderState ~= 'Dodge' and ability.SubType == 'Ice'
		and IsObjectOnFieldEffectBuffAffector(Defender, {'Lava'}) then
		AddBattleEvent(Defender, 'BigTextCustomEvent', {Text = WordText('ChainEvent_Fracture'), Font = 'NotoSansBlack-28', AnimKey = 'KnockbackStun',Color = 'FFFF5943', EventType = 'FinalHit'});
		InsertBuffActions(actions, Attacker, Defender, 'Stun', 1, true, nil, true, {Type = 'Fracture'});
		table.insert(actions, Result_FireWorldEvent('ChainEffectOccured', {Unit = Defender, Trigger = Attacker, ChainType = 'Fracture'}));
	end
	return damage, attackerState, defenderState, knockbackPower;
end
function GetModifyResultActions_Final(actions, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, damage, attackerState, defenderState, knockbackPower, damageFlag)
	-- 공격받으면 무조건 사망 피해를 입습니다. DeadSign
	local buff_DeadSign = GetBuff(Defender, 'DeadSign');
	if buff_DeadSign then
		attackerState = 'Critical';
		defenderState = 'Hit';
		knockbackPower = 0;
		if damage < Defender.HP then
			damage = Defender.HP;
		end
		return damage, attackerState, defenderState, knockbackPower;
	end

	-- 최종 결과를 바꾸는 것이기에 특성 체크보단 일단 원하는 결과 상태 체크부터 하자.	
	local initDamage = damage;
	if ability.Type == 'Heal' then
		return damage, attackerState, defenderState, knockbackPower;
	end	
	if not Defender then
		return damage, attackerState, defenderState, knockbackPower;
	end

	----------------------------------------------------------------------------
	-- 피해량 조정부 : 해당 구문 이후 피해량 조정부를 뒤로 붙이지 말자. 계산 값이 달라진다.
	----------------------------------------------------------------------------		
	-- 순서에 따라 결과가 달라지니 고려할 것이기에

	if defenderState ~= 'Dodge' then
		-- 특성 불살. DoNotKill
		local mastery_DoNotKill = GetMasteryMastered(masteryTable_Attcker, 'DoNotKill');
		if mastery_DoNotKill then
			if Defender.HP > mastery_DoNotKill.ApplyAmount then
				local curHP = Defender.HP - damage;
				if curHP < mastery_DoNotKill.ApplyAmount  then
					damage = Defender.HP - mastery_DoNotKill.ApplyAmount;
				end
				AddBattleEvent(Attacker, 'DoNotKill');
			end			
		end
		----------------------------------------------------------------------------
		-- 아래부터 방어자 피해량 증감, 공격자 피해량 증감 다처리하고 칩시다. 
		----------------------------------------------------------------------------
		-- 특성 얼음가죽. IceSkin
		local mastery_IceSkin = GetMasteryMastered(masteryTable_Defender, 'IceSkin');
		if mastery_IceSkin then
			local stateChange = false;
			if ability.Type == 'Attack' and ability.SubType == 'Ice' then
				damage = damage * mastery_IceSkin.ApplyAmount/100;
				stateChange = true;
			elseif ability.Type == 'Attack' and ability.SubType == 'Fire' then
				local ratio = mastery_IceSkin.ApplyAmount2/100;
				if damage < ratio * Defender.MaxHP then
					damage = 0;
				end
				stateChange = true;
			end
			if stateChange then
				defenderState = 'Block';
				AddBattleEvent(Defender, 'IceSkin');
				-- 혹한의 괴수
				local mastery_ColdMonster = GetMasteryMastered(masteryTable_Defender, 'ColdMonster');
				if mastery_ColdMonster then
					mastery_ColdMonster.CountChecker = 1;
				end
			end
		end	
		-- 특성 용암 가죽. LavaSkin
		local mastery_LavaSkin = GetMasteryMastered(masteryTable_Defender, 'LavaSkin');
		if mastery_LavaSkin then
			local stateChange = false;
			if ability.Type == 'Attack' and ability.SubType == 'Fire' then
				damage = damage * mastery_LavaSkin.ApplyAmount/100;
				stateChange = true;
			elseif ability.Type == 'Attack' and ability.SubType == 'Ice' then
				local ratio = mastery_LavaSkin.ApplyAmount2/100;
				if damage < ratio * Defender.MaxHP then
					damage = 0;
				end
				stateChange = true;
			end
			if stateChange then
				defenderState = 'Block';
				AddBattleEvent(Defender, 'LavaSkin');
				-- 폭염의 괴수
				local mastery_HotMonster = GetMasteryMastered(masteryTable_Defender, 'HotMonster');
				if mastery_HotMonster then
					mastery_HotMonster.CountChecker = 1;
				end
			end
		end		
		-- 특성 번개 가죽. LightningSkin
		local mastery_LightningSkin = GetMasteryMastered(masteryTable_Defender, 'LightningSkin');
		if mastery_LightningSkin then
			local stateChange = false;
			if ability.Type == 'Attack' and ability.SubType == 'Lightning' then
				damage = damage * mastery_LightningSkin.ApplyAmount/100;
				stateChange = true;
			elseif ability.Type == 'Attack' and ability.SubType == 'Earth' then
				local ratio = mastery_LightningSkin.ApplyAmount2/100;
				if damage < ratio * Defender.MaxHP then
					damage = 0;
				end
				stateChange = true;
			end
			if stateChange then
				defenderState = 'Block';
				AddBattleEvent(Defender, 'LightningSkin');
				-- 빗속의 괴수
				local mastery_RainMonster = GetMasteryMastered(masteryTable_Defender, 'RainMonster');
				if mastery_RainMonster then
					mastery_RainMonster.CountChecker = 1;
				end
			end
		end
		-- 특성 달빛 가죽. MoonSkin
		local mastery_MoonSkin = GetMasteryMastered(masteryTable_Defender, 'MoonSkin');
		if mastery_MoonSkin then
			local stateChange = false;
			if ability.Type == 'Attack' and ability.SubType == 'Earth' then
				damage = damage * mastery_MoonSkin.ApplyAmount/100;
				stateChange = true;
			elseif ability.Type == 'Attack' and ability.SubType == 'Lightning' then
				local ratio = mastery_MoonSkin.ApplyAmount2/100;
				if damage < ratio * Defender.MaxHP then
					damage = 0;
				end
				stateChange = true;
			end
			if stateChange then
				defenderState = 'Block';
				AddMasteryInvokedEvent(Defender, mastery_MoonSkin.name, 'FirstHit');
				-- 달빛의 괴수
				local mastery_MoonMonster = GetMasteryMastered(masteryTable_Defender, 'MoonMonster');
				if mastery_MoonMonster then
					mastery_MoonMonster.CountChecker = 1;
				end
			end
		end
		-- 특성 내화성. Module_FireResistance
		local mastery_Module_FireResistance = GetMasteryMastered(masteryTable_Defender, 'Module_FireResistance');
		if mastery_Module_FireResistance then
			if ability.Type == 'Attack' and ability.SubType == 'Fire' then
				damage = damage * ( 100 - mastery_Module_FireResistance.ApplyAmount)/100;
				AddBattleEvent(Defender, 'Module_FireResistance');
			end
		end
		-- 특성 내한성. Module_FireResistance
		local mastery_Module_IceResistance = GetMasteryMastered(masteryTable_Defender, 'Module_IceResistance');
		if mastery_Module_IceResistance then
			if ability.Type == 'Attack' and ability.SubType == 'Ice' then
				damage = damage * ( 100 - mastery_Module_IceResistance.ApplyAmount)/100;
				AddBattleEvent(Defender, 'Module_IceResistance');
			end
		end
		-- 특성 절연성. Module_Insulation
		local mastery_Module_Insulation = GetMasteryMastered(masteryTable_Defender, 'Module_Insulation');
		if mastery_Module_Insulation then
			if ability.Type == 'Attack' and ability.SubType == 'Lighting' then
				damage = damage * ( 100 - mastery_Module_Insulation.ApplyAmount)/100;
				AddBattleEvent(Defender, 'Module_Insulation');
			end
		end
		-- 특성 내수성. Module_WaterResistance
		local mastery_Module_WaterResistance = GetMasteryMastered(masteryTable_Defender, 'Module_WaterResistance');
		if mastery_Module_WaterResistance then
			if ability.Type == 'Attack' and ability.SubType == 'Water' then
				damage = damage * ( 100 - mastery_Module_WaterResistance.ApplyAmount)/100;
				AddBattleEvent(Defender, 'Module_WaterResistance');
			end
		end
		-- 특성 내풍성. Module_WaterResistance
		local mastery_Module_WindResistance = GetMasteryMastered(masteryTable_Defender, 'Module_WindResistance');
		if mastery_Module_WindResistance then
			if ability.Type == 'Attack' and ability.SubType == 'Wind' then
				damage = damage * ( 100 - mastery_Module_WindResistance.ApplyAmount)/100;
				AddMasteryInvokedEvent(Defender, mastery_Module_WindResistance.name, 'FirstHit');
			end
		end
		-- 특성 중장비. HeavyEquipment
		local mastery_HeavyEquipment = GetMasteryMastered(masteryTable_Defender, 'HeavyEquipment');
		if mastery_HeavyEquipment then
			if ability.Type == 'Attack' and ability.SubType == 'Wind' then
				damage = damage * ( 100 - mastery_HeavyEquipment.ApplyAmount)/100;
				if knockbackPower == 0 then
					AddBattleEvent(Defender, 'HeavyEquipment');
				end
			end
		end
		------------------------------------------------------------------------
		-- 피해량 보정의 경우, 충격장이 제일 마지막에 있어야한다.
		-- 순서를 고려하시오. 앞에꺼 실행됨으로 인해 뒤에꺼 적용안되는 걸 피하세요.
		-- 현재 순서 : 충격장 -> 충격흡수 -> 마력장 -> 강철 심장
		------------------------------------------------------------------------
		-- 특성 무기 받아치기. WeaponParry
		local mastery_WeaponParry = GetMasteryMastered(masteryTable_Defender, 'WeaponParry');
		if mastery_WeaponParry then
			if IsMeleeDistanceAbility(Attacker, Defender) and damage < Defender.AttackPower then
				damage = math.ceil(damage * (1 - mastery_WeaponParry.ApplyAmount/100));
				damageFlag.WeaponParry = true;
				AddMasteryInvokedEvent(Defender, mastery_WeaponParry.name, 'FirstHit');
				-- 백병전의 달인
				local mastery_MeleeBattleMaster = GetMasteryMastered(masteryTable_Defender, 'MeleeBattleMaster');
				if mastery_MeleeBattleMaster then
					mastery_MeleeBattleMaster.CountChecker = 1;
				end
			end
		end
		-- 장비 반짝이는 충격 보호대. Amulet_AniDamage 
		local mastery_Amulet_AniDamage = GetMasteryMastered(masteryTable_Defender, 'Amulet_AniDamage');
		if mastery_Amulet_AniDamage then
			local limitedHP = math.ceil(Defender.MaxHP * mastery_Amulet_AniDamage.ApplyAmount/100);
			if damage > limitedHP and Defender.HP > limitedHP and mastery_Amulet_AniDamage.DuplicateApplyChecker < mastery_Amulet_AniDamage.ApplyAmount2 then
				damage = limitedHP;
				damageFlag.Amulet_AniDamage = true;
				mastery_Amulet_AniDamage.DuplicateApplyChecker = mastery_Amulet_AniDamage.DuplicateApplyChecker + 1;
				AddMasteryInvokedEvent(Defender, mastery_Amulet_AniDamage.name, 'FirstHit');
			end
		end
		-- 특성 충격장. ImpulseFields 
		local mastery_ImpulseFields = GetMasteryMastered(masteryTable_Defender, 'ImpulseFields');
		if mastery_ImpulseFields then
			local limitedHP = math.ceil(Defender.MaxHP * mastery_ImpulseFields.ApplyAmount/100);
			if damage > limitedHP and Defender.HP > limitedHP then
				damage = limitedHP;
				damageFlag.ImpulseFields = true;
				AddMasteryInvokedEvent(Defender, mastery_ImpulseFields.name, 'FirstHit');
			end
		end
		-- 특성 지원 모듈 - 충격흡수. Module_ShockAbsorber 
		local mastery_Module_ShockAbsorber = GetMasteryMastered(masteryTable_Defender, 'Module_ShockAbsorber');
		if mastery_Module_ShockAbsorber then
			local limitedHP = math.ceil(Defender.MaxHP * mastery_Module_ShockAbsorber.ApplyAmount/100);
			if damage > limitedHP and Defender.Cost >= mastery_Module_ShockAbsorber.ApplyAmount2 then
				damage = limitedHP;
				damageFlag.Module_ShockAbsorber = true;
				AddMasteryInvokedEvent(Defender, mastery_Module_ShockAbsorber.name, 'FirstHit');
			end
		end
		-- 특성 마력장. MagicField
		local mastery_MagicField = GetMasteryMastered(masteryTable_Defender, 'MagicField');
		if mastery_MagicField and IsGetAbilitySubType(ability, 'ESP') and damage < Defender.ESPPower then
			damage = damage * mastery_MagicField.ApplyAmount / 100;
			damageFlag.MagicField = true;
			AddMasteryInvokedEvent(Defender, mastery_MagicField.name, 'FirstHit');
		end
		-- 특성 바위성. RockCastle
		local mastery_RockCastle = GetMasteryMastered(masteryTable_Defender, 'RockCastle');
		if mastery_RockCastle and IsGetAbilitySubType(ability, 'Physical') and damage < Defender.Armor then
			damage = damage * mastery_RockCastle.ApplyAmount / 100;
			damageFlag.RockCastle = true;
			AddMasteryInvokedEvent(Defender, mastery_RockCastle.name, 'FirstHit');
		end
		-- 특성 얼음성. IceCastle
		local mastery_IceCastle = GetMasteryMastered(masteryTable_Defender, 'IceCastle');
		if mastery_IceCastle and IsGetAbilitySubType(ability, 'ESP') and damage < Defender.Resistance then
			damage = damage * mastery_IceCastle.ApplyAmount / 100;
			damageFlag.IceCastle = true;
			AddMasteryInvokedEvent(Defender, mastery_IceCastle.name, 'FirstHit');
		end
		-- 특성 강철 심장. IronHeart
		local mastery_IronHeart = GetMasteryMastered(masteryTable_Defender, 'IronHeart');
		if mastery_IronHeart then
			local limitedHP = Defender.MaxHP * mastery_IronHeart.ApplyAmount/100;
			if damage <= limitedHP then
				damage = damage * mastery_IronHeart.ApplyAmount2/100;
				damageFlag.IronHeart = true;
				AddMasteryInvokedEvent(Defender, mastery_IronHeart.name, 'FirstHit');
			end
		end
	end
	----------------------------------------------------------------------------
	-- 넉백 처리
	----------------------------------------------------------------------------
	-- 특성. 바람 망치
	if IsGetAbilitySubType(ability, 'Wind') and defenderState ~= 'Dodge' then
		local mastery_WindHammer = GetMasteryMastered(masteryTable_Attacker, 'WindHammer');
		if mastery_WindHammer then			
			knockbackPower = knockbackPower + 1;
			AddBattleEvent(Attacker, 'WindHammer');
		end
	end		
	-- 특성. 꽉쥔 주먹
	if ability.Type == 'Attack' and ability.HitRateType == 'Melee' and defenderState ~= 'Dodge' then
		local mastery_ClenchedFist = GetMasteryMastered(masteryTable_Attacker, 'ClenchedFist');
		if mastery_ClenchedFist then
			knockbackPower = knockbackPower + 1;
			AddMasteryInvokedEvent(Attacker, mastery_ClenchedFist.name, 'FinalHit');
		end
	end
	-- 버프(지형효과). 빙판
	if defenderState ~= 'Dodge' and knockbackPower > 0 then
		local buff_Ice = GetBuff(Defender, 'Ice');
		if buff_Ice then
			knockbackPower = knockbackPower + buff_Ice.ApplyAmount;
			AddBattleEvent(Defender, 'BuffInvokedFromAbility', { Buff = buff_Ice.name, EventType = 'FinalHit', NoEffect = true});
		end
	end
	-- 특성. 육중함
	if defenderState ~= 'Dodge' and knockbackPower > 0 then
		local mastery_Heaviness = GetMasteryMastered(masteryTable_Defender, 'Heaviness');
		if mastery_Heaviness then
			knockbackPower = 0;
			AddMasteryInvokedEvent(Defender, mastery_Heaviness.name, 'FinalHit');
			local mastery_Mountain = GetMasteryMastered(masteryTable_Defender, 'Mountain');
			if mastery_Mountain then
				AddMasteryInvokedEvent(Defender, mastery_Mountain.name, 'FinalHit');
				InsertBuffActions(actions, Attacker, Defender, mastery_Mountain.Buff.name, 1, true);
			end
		end
	end
	-- 특성. 중장비
	if defenderState ~= 'Dodge' and knockbackPower > 0 then
		local mastery_HeavyEquipment = GetMasteryMastered(masteryTable_Defender, 'HeavyEquipment');
		if mastery_HeavyEquipment then
			knockbackPower = 0;
			AddMasteryInvokedEvent(Defender, mastery_HeavyEquipment.name, 'FinalHit');
		end
	end
	-- 버프. 고치
	if defenderState ~= 'Dodge' and knockbackPower > 0 then
		local buff_CocoonWeb = GetBuff(Defender, 'CocoonWeb');
		if buff_CocoonWeb then
			knockbackPower = 0;
			AddBattleEvent(Defender, 'BuffInvokedFromAbility', { Buff = buff_CocoonWeb.name, EventType = 'FinalHit', NoEffect = true});
		end
	end
	return damage, attackerState, defenderState, knockbackPower;
end
-----------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------
-- 턴 시작 : 전투 턴 액션 함수.
---------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------
function UpdateBattleTurnStartActions(actions, owner, ds)
	if owner.CostType.name == 'Vigor' then
		-- 자신의 코스트 회복 관련.
		local curCost = owner.RegenCost + GetConditionalStatus(owner, 'RegenCost', {}, {MissionTemperature = GetMission(owner).Temperature.name});
		local buff_SpellReflux = GetBuff(owner, 'SpellReflux');
		if buff_SpellReflux and curCost > 0 then
			curCost = 0;
		end
		if curCost ~= 0 then
			local _, reasons = AddActionCost(actions, owner, curCost, true);
			ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		end
	elseif owner.CostType.name == 'Fuel' then
		local fuelChange = -owner.RegenCost + GetConditionalStatus(owner, 'RegenCost', {}, {MissionTemperature = GetMission(owner).Temperature.name});
		local retCost, reasons = AddActionCost(actions, owner, fuelChange, true);
		local realAddValue = retCost - owner.Cost;
		if realAddValue ~= 0 then
			ds:UpdateBattleEvent(GetObjKey(owner), 'AddCost', { CostType = owner.CostType.name, Count = realAddValue });
		end
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	end
end
---------------------------------------------------------------------------------------------------
-- 피해를 입을 시 : 공용 버프(State) 이벤트 핸들러.
---------------------------------------------------------------------------------------------------
function UpdateBattleTakeDamageActions(actions, owner, ds)
	-- 자신의 코스트 회복 관련.
	if owner.CostType.name == 'Rage' then
		if owner.Cost < owner.MaxCost and owner.RegenCost > 0 then
			local curCost = owner.RegenCost;
			local _, reasons = AddActionCost(actions, owner, curCost, true);
			ds:UpdateBattleEvent(GetObjKey(owner), 'AddCost', { CostType = owner.CostType.name, Count = curCost });
			ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		end
	end
end
---------------------------------------------------------------------------------------------------
-- 피해를 줄 시 : 공용 버프(State) 이벤트 핸들러.
---------------------------------------------------------------------------------------------------
function UpdateBattleGiveDamageActions(actions, owner)
end
-------------------------------------------------------------------------------
-----------------------------------------------------------------------------------
-- 액션 정리 구문.
-------------------------------------------------------------------------------------
-- 체력 회복 구문.
function AddActionRestoreHP(actions, user, target, amount, damageType)
	local lostHP  = target.MaxHP - target.HP;
	
	local reasons = {};
	local masteryTable = GetMastery(target);
	
	-- 생존 본능
	local mastery_InstinctForSurvival = GetMasteryMastered(masteryTable, 'InstinctForSurvival');
	if mastery_InstinctForSurvival then
		amount = amount * (1 + mastery_InstinctForSurvival.ApplyAmount / 100);
		table.insert(reasons, MakeMasteryStatInfo(mastery_InstinctForSurvival.name, nil));
	end
	
	if amount > lostHP then
		amount = lostHP;
	end
	
	local damReturn = Result_Damage(-1 * math.floor(amount), 'Normal', 'Heal', user, target, damageType or 'Heal');
	damReturn.sequential = true;
	table.insert(actions, damReturn);
	return reasons;
end
function AddActionCost(actions, target, amount, sequential, updateStatus)
	local reasons = {};
	if target.CostType.name == 'Fuel' then
		local multiplier = 0;
		-- 고급 연료
		local mastery_Module_GoodEnergy = GetMasteryMastered(GetMastery(target), 'Module_GoodEnergy');
		if mastery_Module_GoodEnergy and amount < 0 then
			multiplier = multiplier - mastery_Module_GoodEnergy.ApplyAmount;
			table.insert(reasons, MakeMasteryStatInfo(mastery_Module_GoodEnergy.name, nil));
			-- 연비 강화 프로그램
			local mastery_Module_FuelEnhancement = GetMasteryMastered(GetMastery(target), 'Module_FuelEnhancement');
			if mastery_Module_FuelEnhancement then
				multiplier = multiplier - mastery_Module_FuelEnhancement.ApplyAmount;
				table.insert(reasons, MakeMasteryStatInfo(mastery_Module_FuelEnhancement.name, nil));
			end
		end
		-- 구동 호환성 - 고속
		if target.Info.name == 'Drone_Speed' and amount < 0 then
			local mastery_DrivingDevice_HoverSpeed_Epic = GetMasteryMastered(GetMastery(target), 'DrivingDevice_HoverSpeed_Epic');
			if mastery_DrivingDevice_HoverSpeed_Epic then
				multiplier = multiplier - mastery_DrivingDevice_HoverSpeed_Epic.ApplyAmount;
				table.insert(reasons, MakeMasteryStatInfo(mastery_DrivingDevice_HoverSpeed_Epic.name, nil));
			end
		end
		-- 연료 호환성 - 수송
		if target.Info.name == 'Drone_Transport' and amount < 0 then
			local mastery_Fuel_TransportList = { 'Fuel_Industrial_Middle', 'Fuel_Industrial_Big' };
			for _, value in pairs (mastery_Fuel_TransportList) do
				local mastery_Fuel_Transport = GetMasteryMastered(GetMastery(target), value);
				if mastery_Fuel_Transport then
					multiplier = multiplier - mastery_Fuel_Transport.ApplyAmount;
					table.insert(reasons, MakeMasteryStatInfo(mastery_Fuel_Transport.name, nil));
				end
			end
		end
		multiplier = math.max(-100, multiplier);
		amount = amount * (1 + multiplier / 100);
	end

	local totalAomunt = math.floor(target.Cost + amount);
	local result = math.max(0, math.min(totalAomunt, target.MaxCost));
	if target.Cost == result then
		return result;
	end
	if updateStatus == nil then
		updateStatus = true;
	end
	local prop = {};
	prop.type = 'PropertyUpdated';
	prop.target = target;
	prop.property_key = 'Cost';
	prop.property_value = tostring(result);
	prop.update_status = updateStatus;
	prop.sequential = sequential == nil and false or sequential;
	table.insert(actions, prop);
	local addAmount = result - target.Cost;
	table.insert(actions, Result_FireWorldEvent('ActionCostAdded', {Unit=target, AddAmount=addAmount}, target));
	return result, reasons;
end
function AddOvercharge(actions, target, amount, sequential)
	local totalAmount = target.Overcharge + amount;
	local result = math.max(0, totalAmount);
    local prop = Result_PropertyUpdated('Overcharge', result, target, false, sequential);
	table.insert(actions, prop);
	local prop2 = nil;
	if result > target.MaxOverchargeDuration then
		prop2 = Result_PropertyUpdated('MaxOverchargeDuration', result, target, false, sequential);
		table.insert(actions, prop2);
	elseif result <= 0 and target.MaxOverchargeDuration ~= target.OverchargeDuration then
		prop2 = Result_PropertyUpdated('MaxOverchargeDuration', target.OverchargeDuration, target, false, sequential);
		table.insert(actions, prop2);
	end
	return prop, prop2;
end
function AddSP(actions, target, amount, sequential)
	local totalAomunt = target.SP + amount;
	local result = math.max(0, math.min(totalAomunt, target.MaxSP));
	local prop = Result_PropertyUpdated('SP', result, target, false, sequential);
	table.insert(actions, prop);
	return prop;
end
function UpdateAbilityPropertyActions(actions, target, abilityName, propName, propValue)
	table.insert(actions, Result_AbilityPropertyUpdated(propName, propValue, target, abilityName, true));
end
function UpdateAbilityCoolActions(actions, target, value, ifFunc)
	local abilityList = GetAllAbility(target, false, true);
	for index, ability in ipairs(abilityList) do
		-- Cool 값이 다른 경우만
		if ability.Cool ~= value and (not ifFunc or ifFunc(ability)) then
			UpdateAbilityPropertyActions(actions, target, ability.name, 'Cool', value);
		end
	end
end
function AddAbilityCoolActions(actions, target, addValue, ifFunc)
	local abilityList = GetAllAbility(target, false, true);
	for index, ability in ipairs(abilityList) do
		-- Cool 증가는 무조건, Cool 감소는 현재 Cool 값이 0 보다 큰 경우만
		if (addValue > 0 or ability.Cool > 0) and (not ifFunc or ifFunc(ability)) then
			UpdateAbilityPropertyActions(actions, target, ability.name, 'Cool', ability.Cool + addValue);
		end
	end
end
function AddActionApplyAct(actions, user, target, amount, actionCategory, isAbilityBuff)
	if target == nil then
		return false, {};
	elseif amount == 0 then
		return false, {};
	end
	
	local action, reasons = GetApplyActAction(target, amount, isAbilityBuff, actionCategory);
	if action == nil then
		return false, reasons;
	end
	
	table.insert(actions, action);
	return true, reasons;
end
function AddActionRestoreActions(actions, self)
	-- 이미 행동력이 최대라서 더 회복할 게 없다.
	if not self.TurnState.Moved and not self.TurnState.UsedMainAbility then
		return;
	end
	-- 행동력이 하나도 없는 상황에서만 ExtraActable로 변경, 아니면 행동력 2개가 되도록 턴 상태 초기화
	if self.TurnState.UsedMainAbility and not self.TurnState.ExtraActable then
		table.insert(actions, Result_PropertyUpdated('TurnState/ExtraActable', true, self));
	else
		table.append(actions, {GetInitializeTurnActions(self, true)});
	end
	table.insert(actions, Result_FireWorldEvent('ActionPointRestored', {Unit = self}, self));
end
-----------------------------------------------------------------------------------
-- 최종 어빌리티 피해량, 적용량 Modify
-------------------------------------------------------------------------------------
function ResultModifier_Damage(amount, resultModifier)
	local result = amount;
	if resultModifier.DamageAdjust then
		if resultModifier.DamageAdjust == 'Use' then
			result = resultModifier.Damage;
		end
	end
	return result;
end
-----------------------------------------------------------------------------------
-- 메세지 처리 함수
-------------------------------------------------------------------------------------
function AddBattleEvent(obj, eventType, args)
	local events = GetInstantProperty(obj, 'BattleEvents') or {};
	if not args then
		table.insert(events, eventType);
	else
		local eventInst = table.deepcopy(args);
		eventInst.Type = eventType;
		table.insert(events, eventInst);
	end
	SetInstantProperty(obj, 'BattleEvents', events);
end
-----------------------------------------------------------------------------------
-- 메세지 처리 함수 유틸리티
-------------------------------------------------------------------------------------
function AddMasteryInvokedEvent(obj, masteryName, directingEvent, worldEvent)
	local events = GetInstantProperty(obj, 'BattleEvents') or {};
	local eventInst = { Type = 'MasteryInvokedCustomEvent', Mastery = masteryName, EventType = directingEvent, MissionChat = true, WorldEventType = worldEvent or '' };
	for _, event in ipairs(events) do
		if event.Type == 'MasteryInvokedCustomEvent' and event.Mastery == masteryName then
			return;
		end
	end
	table.insert(events, eventInst);
	SetInstantProperty(obj, 'BattleEvents', events);
end
----------------------------------------------------------------
-- 초능력 프로퍼티 증감하는 함수.
----------------------------------------------------------------
function AddSPPropertyActions(actions, target, properetyType, amount, isStatusUpdate, ds, sequential, noEvent)
	if not target.ESP or not target.ESP.name or target.ESP.name ~= properetyType then
		return;
	end

	local multiplier = 0;
	local masteryTable = GetMastery(target);
	local mastery_PowerDevice_EA10_Overdrive = GetMasteryMastered(masteryTable, 'PowerDevice_EA10_Overdrive');
	if mastery_PowerDevice_EA10_Overdrive and amount > 0 and target.ESP.name == 'Heat' then
		multiplier = multiplier + mastery_PowerDevice_EA10_Overdrive.ApplyAmount;
	end
	local mastery_PowerDevice_EA10_Speed = GetMasteryMastered(masteryTable, 'PowerDevice_EA10_Speed');
	if mastery_PowerDevice_EA10_Speed and amount > 0 and target.Info.name == 'Drone_Speed' then
		multiplier = multiplier + mastery_PowerDevice_EA10_Speed.ApplyAmount;
	end
	local mastery_Sensor_EnhancedInfo_Epic = GetMasteryMastered(masteryTable, 'Sensor_EnhancedInfo_Epic');
	if mastery_Sensor_EnhancedInfo_Epic and amount > 0 and target.ESP.name == 'Info' then
		multiplier = multiplier + mastery_Sensor_EnhancedInfo_Epic.ApplyAmount;
	end
	local mastery_Sensor_EnhancedSearch_Epic = GetMasteryMastered(masteryTable, 'Sensor_EnhancedSearch_Epic');
	if mastery_Sensor_EnhancedSearch_Epic and amount > 0 and target.ESP.name == 'Info' then
		multiplier = multiplier + mastery_Sensor_EnhancedSearch_Epic.ApplyAmount;
	end
	local mastery_Module_AddSP = GetMasteryMastered(masteryTable, 'Module_AddSP');
	if mastery_Module_AddSP and amount > 0 then
		multiplier = multiplier + mastery_Module_AddSP.ApplyAmount;
	end
	local mastery_Module_Overboosting = GetMasteryMastered(masteryTable, 'Module_Overboosting');
	if mastery_Module_Overboosting and amount > 0 then
		multiplier = multiplier + mastery_Module_Overboosting.ApplyAmount;
	end
	amount = math.floor(amount * (1 + multiplier / 100));
	
	local curValue = target.SP;
	local maxValue = target.MaxSP;
	local updateAmount = math.min(maxValue, math.max(0, curValue + amount));
	table.insert(actions, Result_PropertyUpdated('PrevSP', curValue, target, false, sequential));
	if updateAmount == maxValue and target.Overcharge == 0 then
		-- 과충전 상태가 되는 로직은 턴 획득 시로 옮겨감
	elseif amount < 0 and target.Overcharge > 0 then
		table.insert(actions, Result_PropertyUpdated('Overcharge', 0, target, false, sequential));
		-- UI 게이지 표시를 위한 MaxOverchargeDuration 값 초기화
		if target.MaxOverchargeDuration ~= target.OverchargeDuration then
			table.insert(actions, Result_PropertyUpdated('MaxOverchargeDuration', target.OverchargeDuration, target, false, sequential));
		end
	end
	table.insert(actions, Result_PropertyUpdated('SP', updateAmount, target, isStatusUpdate, sequential));
	-- 연출은 최소, 최대치 제한과 상관없이 보여준다.
	if amount ~= 0 and not noEvent then
		local battleEventArg = {Count = amount, SpType = target.ESP.name};
		if ds then
			ds:UpdateBattleEvent(GetObjKey(target), 'AddSp', battleEventArg);
		else
			AddBattleEvent(target, 'AddSp', battleEventArg);
		end
	end
	
	if amount < 0 and target.Overcharge > 0 and not noEvent then
		table.insert(actions, Result_FireWorldEvent('OverchargeEnded', {Unit=target}, target));
	end

	-- 특성 넘쳐 흐르는 에너지
	local mastery_AccelerationEnergy = GetMasteryMastered(masteryTable, 'AccelerationEnergy');
	if mastery_AccelerationEnergy and amount > 0 and target.Overcharge > 0 and not noEvent then
		local applyAct = -1 * amount;
		local added, reasons = AddActionApplyAct(actions, target, target, applyAct, 'Friendly');
		if ds then
			if added then
				ds:UpdateBattleEvent(GetObjKey(target), 'AddWait', { Time = applyAct });
			end
			ReasonToUpdateBattleEventMulti(target, ds, reasons);
			ds:UpdateBattleEvent(GetObjKey(target), 'MasteryInvokedCustomEvent', { Mastery = mastery_AccelerationEnergy.name, EventType = 'Ending', MissionChat = true, WorldEventType = ''  });
		else
			if added then
				AddBattleEvent(target, 'AddWait', { Time = applyAct });
			end
			ReasonToAddBattleEventMulti(target, reasons, 'Ending');
			AddMasteryInvokedEvent(target, mastery_AccelerationEnergy.name, 'Ending');
		end
		-- 보조전력
		local mastery_AuxiliaryPower = GetMasteryMastered(masteryTable, 'AuxiliaryPower');
		if mastery_AuxiliaryPower then
			InsertBuffActions(actions, target, target, mastery_AuxiliaryPower.Buff.name, amount, true, nil, ds == nil);
			if ds then
				MasteryActivatedHelper(ds, mastery_AuxiliaryPower, target, 'SPIncreased');
			else
				AddMasteryInvokedEvent(target, mastery_AuxiliaryPower.name, 'Ending');
			end
		end
		-- 강화된 신경망
		local mastery_EnhancedNeuralNetwork = GetMasteryMastered(masteryTable, 'EnhancedNeuralNetwork');
		if mastery_EnhancedNeuralNetwork then
			InsertBuffActions(actions, target, target, mastery_EnhancedNeuralNetwork.Buff.name, amount, true, nil, ds == nil);
			if ds then
				MasteryActivatedHelper(ds, mastery_EnhancedNeuralNetwork, target, 'SPIncreased');
			else
				AddMasteryInvokedEvent(target, mastery_EnhancedNeuralNetwork.name, 'Ending');
			end
		end
	end
end
function AddSPPropertyActionsObject(actions, target, amount, isStatusUpdate, ds, sequential)
	AddSPPropertyActions(actions, target, target.ESP.name, amount, isStatusUpdate, ds, sequential);
end
----------------------------------------------------------------
-- 유저 멤버 체크
----------------------------------------------------------------
function IsUserMember(unit)
	if unit.IsUserMember then
		return true;
	end
	if GetInstantProperty(unit, 'CUSTOM_USER_MEMBER') then
		return true;
	end
	return false;
end