-- 툴팁 키맵 함수 등록.
-- $Target$
function GetAbilityTargetText(ability)
	return GetWord(ability.ApplyTarget);
end
-- $BaseDamage$
function GetAbilityApplyAmount(ability)
	return ability.ApplyAmount;
end
-- $Attacker$
function GetAbilityAttackerText(target)
	if target == nil then
		return GetWord('AttackTarget');
	else
		return  target.Info.Title;
	end
end
-- $AttackSubType$
function GetAbilityAttackSubTypeText(mastery)
	local abilitySubTypeList = GetClassList('AbilitySubType');
	local curSubType = abilitySubTypeList[mastery.SubType];
	return '$White$'..curSubType.Title..'$Blue_ON$';	
end
-- $CoolValue$
function GetAbilityStatusText(ability, property)
	local statusList = GetClassList('Status');
	local curStatus = statusList[property];
	local curStatusValue = ability[property];
	if curStatus.Format == 'Percent' then
		curStatusValue = curStatusValue..'%';
	end
	return '$White$'..curStatusValue..'$Blue_ON$';
end
-- $CoolValue$
function GetAbilityCoolValueText(ability)
	return '$White$'..ability.Cool..'$Blue_ON$';
end
-- $DamageAmount$
function GetDamageAmountText(ability, target)
	local result = '$BaseDamage$';
	local statusList = GetClassList('Status');
	local espList = GetClassList('ESP');
	local spColor = 'White';
	if target and target.ESP and target.ESP.name then
		spcolor = espList[target.ESP.name].FronBarColor;
	end
	local list = {};
	-- 기본 맵핑.
	for key, value in pairs (statusList) do
		if target and key ~= 'MaxCost' and key ~= 'RegenCost' then
			table.insert(list, { Type = key, Title = value.Title_HPChangeFunctionArg, Color = value.DamageColor});
		end
	end
	-- SP 특수 맵핑.
	if target and target.ESP and target.ESP.name then
		table.insert(list, { Type = 'SP', Title = statusList['Max' ..target.ESP.name .. 'Point'].Title, Color = spColor});
	end
	-- HP 특수 맵핑.
	table.insert(list, { Type = 'HP', Title = statusList['MaxHP'].Title, Color = statusList['MaxHP'].DamageColor});
	-- 대상 HP 비례 특수 맵핑
	table.insert(list, { Type = 'EnemyHP', Title = GetWord('Enemy') .. ' ' .. statusList['MaxHP'].Title, Color = statusList['MaxHP'].DamageColor});
	-- Cost 특수 맵핑.
	if target and target.CostType and target.CostType.name and target.CostType.name ~= 'None' then
		local maxCostKey = 'Max'..target.CostType.name;
		local regenCostKey = 'Regen'..target.CostType.name;
		table.insert(list, { Type = 'Cost', Title = statusList[maxCostKey].Title, Color = target.CostType.Color});
		table.insert(list, { Type = 'MaxCost', Title = statusList[maxCostKey].Title_HPChangeFunctionArg, Color = target.CostType.Color});
		table.insert(list, { Type = 'RegenCost', Title = statusList[regenCostKey].Title_HPChangeFunctionArg, Color = target.CostType.Color});
	end
	-- Lv 특수 맵핑.
	table.insert(list, { Type = 'Lv', Title = GetWord('Level'), Color = 'White' });
	if ability.ApplyAmount == 0 then
		result = '';
	end
	local additional = '';
	for index, value in ipairs(list) do
		if value.Type ~= 'EnemyHP' and target and IsMissionMode() then
			local status = GetAbilityAdditionalApplyAmount(ability, target, value.Type);
			if status > 0 then
				if result == '' and additional == '' then
					additional = '$'..value.Color..'$'..status;
				else
					additional = additional..'$'..value.Color..'$'..'(+'..status..')';
				end
			end
		else
			local status = GetAbilityAdditionalApplyRatio(ability, value.Type);
			if status > 0 then
				if value.Type == 'SP' then
					value.Type = target
				end
				if result == '' and additional == '' then
					additional = '$'..value.Color..'$'..status..'% '..value.Title;
				else
					additional = additional..'$'..value.Color..'$'..'(+'..status..'% '..value.Title..')';
				end
			end
		end
	end
	if additional ~= '' then
		if result ~= '' then
			result = result..' ';
		end
		result = result..additional;
	else
		result = '$White$'..result;
	end
	
	result = result..'$Blue_ON$';
	return result;
end
-- $DamageType$
function GetAbilityDamageTypeText(ability)
	local result = ''
	if ability.SubType ~= 'None' then
		local abilitySubTypeList = GetClassList('AbilitySubType');
		local curSubType = abilitySubTypeList[ability.SubType];
		local title = GetWithoutError(curSubType, 'Title');
		if title and title ~= 'None' then
			result = title;
		end
		result = result..'$Blue_ON$';
	end					
	return result;
end
-- $ApplyBuffChance$
function GetAbilityApplyBuffChanceText(ability)
	return '$White$'..ability.ApplyTargetBuffChance..'%$Blue_ON$';
end
-- $ApplyBuffLv$
function GetAbilityApplyBuffLvText(ability)
	return ability.ApplyTargetBuffLv;
end
-- $ApplySubBuffChance$
function GetAbilityApplySubBuffChanceText(ability)
	return '$White$'..ability.ApplyTargetSubBuffChance..'%$Blue_ON$';
end
-- $ApplySubBuffLv$
function GetAbilityApplySubBuffLvText(ability)
	return ability.ApplyTargetSubBuffLv;
end
-- $ApplyBuff$
function GetAbilityApplyBuffText(ability)
	local result = '';
	local buff = ability.ApplyTargetBuff;
	result = GetBuffText(buff);
	return result;
end
-- $CancelBuff$
function GetAbilityCancelBuffText(ability)
	local result = '';
	local buff = ability.CancelTargetBuff;
	result = GetBuffText(buff);
	return result;
end
-- $ApplySubBuff$
function GetAbilityApplySubBuffText(ability)
	local result = '';
	local buff = ability.ApplyTargetSubBuff;
	result = GetBuffText(buff);
	return result;
end
-- $ApplyBuffColor$
function GetAbilityApplyBuffColorText(ability)
	local result = '';
	local buff = ability.ApplyTargetBuff;
	if buff then
		result = '$'..GetBuffTitleColor(buff)..'$';
	end
	return result;
end
-- $ApplyBuffConvertLv$
function GetAbilityApplyBuffConvertLvText(ability)
	return '$White$'..ability.ConvertBuffLv..'$Blue_ON$';
end
-- $RequireBuff$
function GetAbilityRequireBuffText(ability)
	local result = '';
	local buff = ability.RequireBuff;
	result = GetBuffText(buff);
	return result;
end
-- $RemoveBuff$
function GetAbilityRemoveBuffText(ability)
	local result = '';
	local buff = ability.RemoveBuff;
	result = GetBuffText(buff);
	return result;
end
-- $AbilityBuff$
function GetAbilityBuffToolTip(ability)
	local result = '';
	local buff = ability.ApplyTargetBuff;
	result = GetBuffToolTip(buff, ability.ApplyTargetBuffLv);
	return result;
end
-- $AbilitySubBuff$
function GetAbilitySubBuffToolTip(ability)
	local result = '';
	local buff = ability.ApplyTargetSubBuff;
	result = GetBuffToolTip(buff, ability.ApplyTargetSubBuffLv);
	return result;
end
-- $HitRateType$
function GetAbilityHitRateTypeText(ability)
	local result = 'Error';
	local abilityHitRateTypeList = GetClassList('AbilityHitRateType');
	local title = GetWithoutError(abilityHitRateTypeList[ability.HitRateType], 'Title');
	if title then
		result = title;
	end
	return result;
end
-- $TargetType$
function GetAbilityTargetTypeText(ability)
	local result = 'Error';
	local abilityApplyTargetTypeList = GetClassList('AbilityApplyTargetType');
	local title = GetWithoutError(abilityApplyTargetTypeList[ability.TargetType], 'Title');
	if title then
		result = title;
	end
	return result;
end
-- $UseCount$
function GetAbilityUseCountText(ability, target)
	local result = 'Error';
	if ability.IsUseCount then
		if not IsMission() then
			result = '$White$'..ability.MaxUseCount;
		else
			result = '$White$'..ability.UseCount;
		end
	end
	result = result..'$Blue_ON$';
	return result;
end
-- $RangeDistance$
function GetAbilityRangeDistanceText(ability)
	local result = '$White$'..ability.RangeDistance;
	result = result..'$Blue_ON$';
	return result;
end
-- $RangeRadius$
function GetAbilityRangeRadiusText(ability)
	local result = '$White$'..ability.RangeRadius;
	result = result..'$Blue_ON$';
	return result;
end
local AppendMessage = function(fullMessage, addMessage)
	if fullMessage == '' then
		return '$Blue_ON$'..fullMessage..addMessage;
	else
		return fullMessage..' '..addMessage;
	end
end
-- $AbilityDescMessage$
function GetAbilityDescMessageText(ability)
	local result = '';
	local rangeList = GetClassList('Range');
	
	-- 체인 공격.
	local curRange = rangeList[ability.ApplyRange];
	if curRange.Type == 'Chain' then
		result = AppendMessage(result, '$ChainAttackMessage$');
	end	
	if ability.Type == 'Attack' or ability.Type == 'Trap' or ability.Type == 'Heal' then
		-- 넉백 파워 + 어빌리티 지연 시간
		if ability.KnockbackPower > 0 and ability.ApplyAct > 0 then
			result = AppendMessage(result, '$KnockbackPowerApplyActMessage$');
		else
			if ability.KnockbackPower ~= 0 then
				result = AppendMessage(result, '$KnockbackPowerMessage$');
			end
			-- 어빌리티 지연 시간
			if ability.ApplyAct ~= 0 then
				result = AppendMessage(result, '$ApplyActMessage$');
			end
		end
		
		-- 피격시 적용 버프만 적용
		local buffName = GetWithoutError(ability.ApplyTargetBuff, 'name');
		if buffName and buffName ~= 'None' and ability.ApplyTargetBuffChance > 0 then		
			result = AppendMessage(result, '$ApplyBuffMessage$');
		end
		-- 피격시 적용 버프만 적용
		local subBuffName = GetWithoutError(ability.ApplyTargetSubBuff, 'name');
		if subBuffName and subBuffName ~= 'None' and ability.ApplyTargetSubBuffChance > 0 then		
			result = AppendMessage(result, '$ApplySubBuffMessage$');
		end
	end

	-- 안정된 자세 적용.
	if ability.NotMoveAttackApplyAmountRatio > 0 then
		result = AppendMessage(result, '$NotMoveAttackApplyMessage$');
	end
	
	-- 거리 피해량 적용.
	if ability.DistanceAttackApplyAmountRatio > 0 then
		result = AppendMessage(result, '$DistanceAttackApplyMessage$');
	end
	
	if ability.NoCoverAttackApplyAmountRatio > 0 then
		result = AppendMessage(result, '$NoCoverAttackApplyMessage$');
	end
	
	if ability.CostBurnRatio > 0 and ability.CostBurnDamage > 0 then
		result = AppendMessage(result, '$CostBurnMessage$');
	end
	
	if ability.RelocatorMoveType then
		if ability.RelocatorMoveType == 'Flash' then
			result = AppendMessage(result, '$RelocatorMoveTypeFlashMessage$');
		end
	end
	
	if ability.SurpriseMove then
		if GetWithoutError(ability, 'MoveTarget') == nil then
			result = AppendMessage(result, GuideMessage('AbilityToolTip_SurpriseMove'));
		else
			result = AppendMessage(result, FormatMessage(GuideMessage('AbilityToolTip_SurpriseMoveTarget'), {MoveTarget = ability.MoveTarget}));
		end
	elseif ability.SilentMove then
		if GetWithoutError(ability, 'MoveTarget') == nil then
			result = AppendMessage(result, GuideMessage('AbilityToolTip_SilentMove'));
		else
			result = AppendMessage(result, FormatMessage(GuideMessage('AbilityToolTip_SilentMoveTarget'), {MoveTarget = ability.MoveTarget}));
		end
	end
	
	-- 필드 이펙트 적용.
	-- 25% 확률로 해당 지형에 전기장이 발생합니다.
	if ability.ApplyFieldEffects then
		result = AppendMessage(result, '$ApplyFieldEffectsMessage$');
	end
	
	-- Status 적용
	if ability.IsAutoStatusTooltip and IsStatusValue(ability) then
		result = AppendMessage(result, '$StatusMessage$');
	end
	
	local immuneRace = table.filter(ability.ImmuneRace, function(raceName) return raceName ~= 'Object' end);
	if ability.AutoImmuneRaceTooltip and #immuneRace > 0 then
		result = AppendMessage(result, '\n'..'$ImmuneRaceMessage$');
	end

	-- 공격 피해량에 따른 체력 회복
	if ability.HPDrainRatio > 0 and ability.HPDrainType.name ~= 'None' then
		result = AppendMessage(result, '\n\n$Yellow$'..GetWord('AbilitySubEffect')..': $White$'..ability.HPDrainType.Title..'$Blue_ON$\n'..'$HPDrainRatioMessage$');
	end	
	return result;
end
function AppendBuffTooltip(ability)
	local result = '';
	-- 버프 툴팁.
	if ability.IsBuffTooltip then
		local buffName = GetWithoutError(ability.ApplyTargetBuff, 'name');
		if buffName and buffName ~= 'None' then
			result = result..'\n\n'..'$ApplyBuffToolTip$'..'$Blue_ON$';
		end
		
		local subBuffName = GetWithoutError(ability.ApplyTargetSubBuff, 'name');
		if subBuffName and subBuffName ~= 'None' then
			result = result..'\n\n'..'$ApplySubBuffToolTip$'..'$Blue_ON$';
		end
		
		local requireBuffName = GetWithoutError(ability.RequireBuff, 'name');
		if requireBuffName and requireBuffName ~='None' then
			result = result..'\n\n'..GuideMessage('Ability_RequireBuff')..'$Blue_ON$';
		end
		
		local cancelBuffName = GetWithoutError(ability.CancelTargetBuff, 'name');
		if cancelBuffName and cancelBuffName ~='None' then
			result = result..'\n\n'..'$CancelBuffTooltip$'..'$Blue_ON$';
		end
		
		local removeBuffName = GetWithoutError(ability.RemoveBuff, 'name');
		if removeBuffName and removeBuffName ~='None' then
			result = result..'\n\n'..'$RemoveBuffTooltip$'..'$Blue_ON$';
		end
	end
	return result;
end
-- $AbilitySystemMessage$
function GetAbilitySystemMessageText(ability, target)
	local result = ''
	-- 종속 어빌리티
	if target and target.name then
		local abilitySet = {};
		local abilityAllList = GetAllAbility(target);
		for _, ability in ipairs(abilityAllList) do
			abilitySet[ability.name] = ability;
			for _, abilityName in ipairs(ability.AutoActiveAbility) do
				local ability = GetAbilityObject(target, abilityName);
				if not ability then
					ability = GetClassList('Ability')[abilityName];
				end
				abilitySet[abilityName] = ability;
			end
		end
		local list = table.map(table.filter(ability.ServantAbility, function(abilityName)
			return abilitySet[abilityName] ~= nil;
		end), function(abilityName)
			return abilitySet[abilityName];
		end);
		list = SortAbilityList(target, list);
		if #list > 0 then
			result = result..'\n';
			for _, servantAbility in ipairs(list) do
				result = result..'\n'..'$Yellow$'..servantAbility.Title;
				-- 어빌리티 Desc
				if servantAbility.Desc_Base ~= '' then
					local formatTable = {};
					for key, cls in pairs(GetClassList('Color')) do
						formatTable[key] = string.format("[colour='%s']", cls.ARGB);
					end
					setmetatable(formatTable, {__index = function(t, key)
						local customTable = GetAbilityKeywordTable();
						if not customTable then
							return servantAbility[key];
						end
						local keywordMapper = customTable[key];
						if keywordMapper == nil then
							return servantAbility[key];
						else
							return keywordMapper(servantAbility);
						end
					end});
					local desc = FormatMessage(servantAbility.Desc_Base, formatTable);
					result = result..': $Blue_ON$'..desc;
				end
			end
		end
	end	
	-- 마스터 어빌리티
	if ability.MasterAbility ~= 'None' then
		local masterAbility = GetClassList('Ability')[ability.MasterAbility];
		result = result..'\n\n'..FormatMessage(GuideMessage('AbilityToolTip_MasterAbility'), { AbilityName = EncloseTextWithColorKey('Yellow', masterAbility.Title, 'Blue_ON') });
	end
	
	-- 버프 툴팁.
	result = result .. AppendBuffTooltip(ability);
	
	-- 턴 소모 내용.
	if ability.TurnPlayType == 'Free' then
		result = result..'\n\n'..'$DarkWhiteYellow$'..GuideMessage('Ability_Turn_Free')..'$Blue_ON$';
	elseif ability.TurnPlayType == 'Half' then
		result = result..'\n\n'..'$DarkWhiteYellow$'..GuideMessage('Ability_Turn_Half')..'$Blue_ON$';
	elseif ability.TurnPlayType == 'Main' then
		result = result..'\n\n'..'$DarkWhiteYellow$'..GuideMessage('Ability_Turn_Main')..'$Blue_ON$';
	end
	-- 이동 공격 여부.
	if ability.AbilityWithMove then
		result = result..'\n'..'$Yellow$'..GuideMessage('Ability_AbilityWithMove')..'$Blue_ON$';
	end
	-- 견제기 여부.
	if ability.Containment then
		result = result..'\n'..'$Yellow$'..GuideMessage('Ability_Containment')..'$Blue_ON$';
	end
	if ability.AbilitySubMenu == 'DetailedSnipe' then
		result = result..'\n'..'$Yellow$'..GuideMessage('Ability_EnableDetailedSnipe')..'$Blue_ON$';
	end
	-- 시야 제한 없음
	if ability.NoSightLimit then
		result = result..'\n'..'$Yellow$'..GuideMessage('Ability_NoSightLimit')..'$Blue_ON$';
	end
	-- 회피 불능 여부.
	if ability.IgnoreDodge then
		result = result..'\n'..'$Yellow$'..GuideMessage('Ability_IgnoreDodge')..'$Blue_ON$';
	end
	-- 가능 불능 여부.
	if ability.IgnoreBlock then
		result = result..'\n'..'$Yellow$'..GuideMessage('Ability_IgnoreBlock')..'$Blue_ON$';
	end
	if ability.RandomPickCount > 0 then
		result = result..'\n'..'$Yellow$'..FormatMessage(GuideMessage('Ability_MultipleHit'), {Count = EncloseTextWithColorKey('White', ability.RandomPickCount, 'Yellow')})..'$Blue_ON$';
	end
	
	-- 적 근접 사용불가 여부.
	if ability.NeedNoNearEnemy then
		local hasNearEnemy = false;
		if target and IsMission() then
			hasNearEnemy = table.exist(GetNearObject(target, 1.8), function(o)
				return target ~= o and GetRelation(target, o) == 'Enemy';
			end);
		end
		if hasNearEnemy then
			result = result..'\n\n'..'$Tomato$'..GuideMessage('AbilityToolTip_NeedNoNearEnemy_Disable');
		else
			result = result..'\n\n'..'$Corn$'..GuideMessage('AbilityToolTip_NeedNoNearEnemy_Enable');
		end
	end	
	
	-- 어빌리티 강화 특성 목록
	if target then
		local list = GetAbilityModifyMasteryList(ability, target);
		if #list > 0 then
			result = result..'\n\n'..'$Corn$'..GuideMessage('Ability_ModifyMastery')..'$Blue_ON$';
			for _, mastery in ipairs(list) do
				result = result..'\n'..'$White$'..mastery.Title..'$Blue_ON$';
			end
		end
	end	
	-- 어빌리티 강화 버프 목록
	if target then
		local list = GetAbilityModifyBuffList(ability, target);
		if #list > 0 then
			result = result..'\n\n'..'$Corn$'..GuideMessage('Ability_ModifyBuff')..'$Blue_ON$';
			for _, buff in ipairs(list) do
				result = result..'\n'..'$White$'..buff.Title..'$Blue_ON$';
			end
		end
	end	
	
	return result;
end
-- $ProtocolCommandMessage$
function GetAbilityProtocolCommandMessageText(ability, target)
	local result = ''
	if ability.AbilitySubMenu == '' then
		return result;
	end
	local detailClsList = GetClassList(ability.AbilitySubMenu);
	if not detailClsList then
		return result;
	end
	local sortedList = {};
	for _, detailCls in pairs(detailClsList) do
		table.insert(sortedList, detailCls);
	end
	table.sort(sortedList, function(a, b) return a.Order < b.Order end);
	if #sortedList == 0 then
		return result;
	end
	
	for _, detailCls in ipairs(sortedList) do
		if result ~= '' then
			result = result..'\n\n';
		end
		local subAbility = detailCls.Ability;
		if target then
			local targetAbility = GetAbilityObject(target, subAbility.name);
			if targetAbility then
				subAbility = targetAbility;
			end
		end
		
		result = result..'$Perano$'..subAbility.Title..'$Blue_ON$';
		-- 어빌리티 Desc
		local desc = AbilityTooltip_CommonShared(subAbility, target, true);
		result = result..'\n'..desc;
	end
	return result;
end
-- $ApplyCost$
function GetAbilityApplyCostText(ability)
	return '$White$'..math.abs(ability.ApplyCost)..'$Blue_ON$';
end
-- $ApplyBuffDuration$
function GetApplyBuffDurationText(ability)
	return '$White$'..math.abs(ability.ApplyTargetBuffDuration)..'$Blue_ON$';
end
-- $NotMoveAttackApplyAmountRatio$
function GetNotMoveAttackApplyAmountRatioText(ability)
	return '$White$'..ability.NotMoveAttackApplyAmountRatio..'%'..'$Blue_ON$';
end
-- $DistanceAttackApplyAmountRatio$
function GetDistanceAttackApplyAmountRatioText(ability)
	return '$White$'..ability.DistanceAttackApplyAmountRatio..'%'..'$Blue_ON$';
end
-- $NoCoverAttackApplyAmountRatio$
function GetNoCoverAttackApplyAmountRatioText(ability)
	return '$White$'..ability.NoCoverAttackApplyAmountRatio..'%'..'$Blue_ON$';
end
-- $ChainAttackMessage$
function GetChainAttackMessage(ability)
	local result = '';
	local rangeList = GetClassList('Range');
	local curRange = rangeList[ability.ApplyRange];
	local message = GuideMessage('AbilityToolTip_ChainAttack');
	local colorList = GetClassList('Color');
	local distanceValue =  GetStringFontColorChangeTag(colorList['White'].ARGB, curRange.Distance, colorList['Blue_ON'].ARGB);
	local chainCountValue =  GetStringFontColorChangeTag(colorList['White'].ARGB, curRange.ChainCount, colorList['Blue_ON'].ARGB);
	result = FormatMessage(message, { Distance = distanceValue , ChainCount = chainCountValue });	
	return result;
end
-- $CostBurnRatio$
function GetCostBurnRatioText(ability)
	return '$White$'..ability.CostBurnRatio..'%'..'$Blue_ON$';
end
-- $CostBurnDamage$
function GetCostBurnDamageText(ability)
	return '$White$'..string.format('( %s * %d )', GetWord('CostBurnAmount'), ability.CostBurnDamage)..'$Blue_ON$';
end
-- $HPDrainRatio$
function GetHPDrainRatioText(ability)
	return '$White$'..ability.HPDrainRatio..'%'..'$Blue_ON$';
end
-- $KnockbackPowerApplyActMessage$
function GetKnockbackPowerApplyActMessage(obj)
	local result = '';
	local message = '';
	if not obj.KnockbackInverse then
		message = GuideMessage('AbilityToolTip_KnockbackPowerApplyActMessage');
	else
		message = GuideMessage('AbilityToolTip_KnockbackPowerApplyActMessage_Inverse');
	end
	local colorList = GetClassList('Color');
	local knockbackPowerValue =  GetStringFontColorChangeTag(colorList['White'].ARGB, obj.KnockbackPower, colorList['Blue_ON'].ARGB);
	local applyActValue =  GetStringFontColorChangeTag(colorList['White'].ARGB, obj.ApplyAct, colorList['Blue_ON'].ARGB);
	result = FormatMessage(message, { KnockbackPower = knockbackPowerValue, ApplyAct = applyActValue });	
	return result;
end
-- $KnockbackPowerMessage$
function GetKnockbackPowerMessage(obj)
	local result = '';
	local color = '';
	local message = '';
	local colorList = GetClassList('Color');
	local finalValue =  obj.KnockbackPower;
	if obj.KnockbackPower > 0 and not obj.KnockbackInverse then
		color = 'Blue_ON';
		message =  GuideMessage('AbilityToolTip_KnockbackPowerMessage_Increase');
	elseif obj.KnockbackPower > 0 and obj.KnockbackInverse then
		color = 'Blue_ON';
		message =  GuideMessage('AbilityToolTip_KnockbackPowerMessage_Decrease');
	end
	finalValue = GetStringFontColorChangeTag(colorList['White'].ARGB, finalValue, colorList[color].ARGB);
	result = FormatMessage(message, { Value = finalValue });	
	return result;
end
-- $ApplyActMessage$
function GetApplyActMessage(obj)
	local result = '';
	local message = '';
	local colorList = GetClassList('Color');
	local finalValue =  obj.ApplyAct;
	if obj.ApplyAct > 0 then
		message =  GuideMessage('AbilityToolTip_ApplyActMessage_Increase');
	elseif obj.ApplyAct < 0 then
		finalValue = -1 * finalValue;
		message =  GuideMessage('AbilityToolTip_ApplyActMessage_Decrease');
	end
	finalValue = GetStringFontColorChangeTag(colorList['White'].ARGB, finalValue, colorList['Blue_ON'].ARGB);
	result = FormatMessage(message, { Value = finalValue });	
	return result;
end
-- $ApplyBuffMessage$
function GetApplyBuffMessage(obj)
	local result = '';
	if obj.ApplyTargetBuffChance == 100 then
		if obj.Type == 'Attack' or obj.Type == 'Trap' then
			result = GuideMessage('AbilityToolTip_ApplyBuffMessage_Perfect');
		else
			result = GuideMessage('AbilityToolTip_GeneralApplyBuffMessage_Perfect');
		end
	elseif obj.ApplyTargetBuffChance < 100 then
		if obj.Type == 'Attack' or obj.Type == 'Trap' then
			result =  GuideMessage('AbilityToolTip_ApplyBuffMessage');
		else
			result =  GuideMessage('AbilityToolTip_GeneralApplyBuffMessage');
		end
	end
	return result;
end
-- $ApplySubBuffMessage$
function GetApplySubBuffMessage(obj)
	local result = '';
	if obj.ApplyTargetSubBuffChance == 100 then
		if obj.Type == 'Attack' or obj.Type == 'Trap' then
			result = GuideMessage('AbilityToolTip_ApplySubBuffMessage_Perfect');
		else
			result = GuideMessage('AbilityToolTip_GeneralApplySubBuffMessage_Perfect');
		end
	elseif obj.ApplyTargetSubBuffChance < 100 then
		if obj.Type == 'Attack' or obj.Type == 'Trap' then
			result = GuideMessage('AbilityToolTip_ApplySubBuffMessage');
		else
			result = GuideMessage('AbilityToolTip_GeneralApplySubBuffMessage');
		end
	end
	return result;
end
-- $NotMoveAttackApplyMessage$
function GetNotMoveAttackApplyMessage(obj)
	local result = GuideMessage('AbilityToolTip_NotMoveAttackApplyAmountRatio');
	return result;
end
-- $DistanceAttackApplyMessage$
function GetDistanceAttackApplyMessage(obj)
	local result = GuideMessage('AbilityToolTip_DistanceAttackApplyAmountRatio');
	return result;
end
-- $NoCoverAttackApplyMessage$
function GetNoCoverAttackApplyMessage(obj)
	return GuideMessage('AbilityToolTip_NoCoverAttackApplyAmountRatio')
end
--$RelocatorMoveTypeFlashMessage$
function GetRelocatorMoveTypeFlashMessage(obj)
	return GuideMessage('AbilityToolTip_GetRelocatorMoveTypeFlash')
end
-- $CostBurnMessage$
function GetCostBurnMessage(obj)
	return GuideMessage('AbilityToolTip_CostBurnMessage');
end
-- $HPDrainRatioMessage$
function GetHPDrainRatioMessage(obj)
	return GuideMessage('AbilityToolTip_HPDrainRatioMessage');
end
-- $ImmuneRace$
function GetAbilityImmuneRaceText(obj)
	local result = '';
	local immuneRace = table.filter(obj.ImmuneRace, function(raceName) return raceName ~= 'Object' end);
	if #immuneRace > 0 then
		local raceList = GetClassList('Race');
		for index, raceName in ipairs (immuneRace) do
			local curRaceTitle = GetWithoutError(raceList[raceName], 'Title');
			if curRaceTitle and curRaceTitle ~= 'None' then
				if result ~= '' then
					result = result.. '$Blue_ON$'..', ';
				end
				result = result..'$White$'..curRaceTitle;
			end
		end
	end
	result = result..'$Blue_ON$';
	return result;
end
-- $ImmuneRaceMessage$
function GetAbilityImmuneRaceMessageText(obj)
	local result = '';
	local immuneRace = table.filter(obj.ImmuneRace, function(raceName) return raceName ~= 'Object' end);
	if #immuneRace > 0 then
		result = '$Blue_ON$'..GuideMessage('Ability_ImmuneRace');
		result = result..'$Blue_ON$';
	end	
	return result;
end
-- $ApplyFieldEffectsMessage$
function GetApplyFieldEffectsMessage(obj)

	local result = '';
	local removelist = {};
	local addlist = {};
	local formatTable = {};
	local rangeList = GetClassList('Range');
	local fieldEffectList = GetClassList('FieldEffect');
	local colorList = GetClassList('Color');	
	for key, cls in pairs(GetClassList('Color')) do
		formatTable[key] = string.format("[colour='%s']", cls.ARGB);
	end	
	-- 0. 배분.
	for _index, value in ipairs (obj.ApplyFieldEffects) do
		if value.Method == 'Remove' then
			table.insert(removelist, value)
		elseif value.Method == 'Add' then
			table.insert(addlist, value)
		end	
	end
	-- 1. AddList부터
	if #addlist > 0 then
		local fieldEffectAddText = '';
		local textKey = nil;
		for i, addEffect in ipairs (addlist) do
			(function()
			local fieldEffectMaxCountText = '';
			local fieldEffectProbText = '';		
			local curFieldEffect = fieldEffectList[addEffect.Type];
			local curRange = rangeList[addEffect.Range];
			-- 1. 전체 범위판정. 1칸인지 아닌지.
			if curRange.Type == 'Dot' or addEffect.NumMax == 0 then
				textKey = 'AbilityToolTip_AddFieldEffect_AllArea';
			else
				textKey = 'AbilityToolTip_AddFieldEffect_PartArea';
				fieldEffectMaxCountText = '$White$'..addEffect.NumMax..'$Blue_ON$';
			end
			-- 2. 확률 판정. 100% 인지 아닌지.
			if addEffect.Prob == 100 then
				textKey = textKey..'_Perfect';
			elseif addEffect.Prob > 0 then
				fieldEffectProbText = '$White$'..addEffect.Prob..'%'..'$Blue_ON$';
			else
				-- 확률이 0 이면 안찍음
				return;
			end
			-- 3. 속성이 뭔지.
			local guideMsg = GuideMessage(textKey..'_'..curFieldEffect.name);
			if guideMsg == textKey..'_'..curFieldEffect.name then
				guideMsg = GuideMessage(textKey..'_Common');
			end
			formatTable.FieldEffectName = '$White$'..curFieldEffect.Title..'$Blue_ON$';
			formatTable.FieldEffectProb = fieldEffectProbText;
			formatTable.FieldEffectMaxCount = fieldEffectMaxCountText;
			if textKey then
				fieldEffectAddText = KoreanPostpositionProcessCpp(FormatMessage(guideMsg, formatTable));
			end
			if result == '' then
				result = fieldEffectAddText;
			else
				result = result..'\n\n'..fieldEffectAddText;
			end
			end)();
		end
	end
	-- 2. removeList부터
	if #removelist > 0 then
		local fieldEffectRemoveText = '';
		local fieldEffectListText = '';
		for i, addEffect in ipairs (removelist) do
			if addEffect.Prob > 0 then
				local curFieldEffect = fieldEffectList[addEffect.Type];
				if fieldEffectListText == '' then
					fieldEffectListText = '$White$'..curFieldEffect.Title..'$Blue_ON$';
				else
					fieldEffectListText = fieldEffectListText..', '..'$White$'..curFieldEffect.Title..'$Blue_ON$';
				end
			end
		end
		formatTable.FieldEffectList = fieldEffectListText;
		fieldEffectRemoveText = FormatMessage(GuideMessage('AbilityToolTip_AddFieldEffect_Remove'), formatTable);
		if result == '' then
			result = fieldEffectRemoveText;
		else
			result = result..'\n\n'..fieldEffectRemoveText;
		end
	end
	return result;
end
-- $StatusMessage$
function GetStatusMessage(obj)
	local result = '';
	local list = {};
	local idSpace = GetIdspace(obj);
	local statusList = GetClassList('Status');
	local colorList = GetClassList('Color');
	for key, value in pairs (statusList) do
		local status =  GetWithoutError(obj, key);
		if status and status ~= 0 and status ~= 'None' then
			local ignored = false;
			if idSpace ~= 'Item' and key == 'HPDrain' then
				ignored = true;
			end
			if idSpace == 'Object' and key == 'OverchargeDuration' then
				ignored = true;
			end
			if not ignored then
				table.insert(list, { Type = key, Priority = value.Priority, Value = value, Stauts = status});
			end
		end
	end
	table.sort(list, function (a, b)
		return a.Priority < b.Priority;
	end);
	
	for index, obj in ipairs (list) do
		if result ~= '' then
			result = result..'\n';
		end
		local message = '';
		local finalValue =  obj.Stauts;
		local color = '';
		if obj.Stauts > 0 then
			color = 'Blue_ON';
			message = obj.Value.Desc_Increase;
		elseif obj.Stauts < 0 then
			color = 'Blue_ON';
			finalValue = -1 * finalValue;
			message = obj.Value.Desc_Decrease;
		end
		if obj.Value.Format == 'Percent' then
			finalValue = finalValue..'%';
		end
		finalValue = GetStringFontColorChangeTag(colorList['White'].ARGB, finalValue, colorList[color].ARGB);
		
		if idSpace == 'Item' then
			result = result..'$'..color..'$'..'$Title$'..' '..finalValue;
		else
			result = result..'$'..color..'$'..KoreanPostpositionProcessCpp(FormatMessage(message, { Status = obj.Value.Title, Value = finalValue}));
		end
	end	
	if result ~= '' then
		result = result..'$Blue_ON$';
	end
	return result;
end
-- $StatusMessageByLevel$
function GetStatusMessageByLevel(obj)
	local result = '';
	local list = {};
	local idSpace = GetIdspace(obj);
	local statusList = GetClassList('Status');
	local colorList = GetClassList('Color');
	local prevLv = obj.Lv;
	if IsMission() and IsObject(obj) then
		obj.Lv = 1;
		InvalidateObject(obj);
	end
	for key, value in pairs (statusList) do
		local status =  GetWithoutError(obj, key);
		if status and status ~= 0 and status ~= 'None' then
			if key ~= 'HPDrain' or idSpace == 'Item' then
				table.insert(list, { Type = key, Priority = value.Priority, Value = value, Stauts = status});
			end
		end
	end
	if IsMission() and IsObject(obj) then
		obj.Lv = prevLv;
		InvalidateObject(obj);
	end
	table.sort(list, function (a, b)
		return a.Priority < b.Priority;
	end);
	
	for index, obj in ipairs (list) do
		if result ~= '' then
			result = result..'\n';
		end
		local finalValue =  obj.Stauts;
		local color = '';
		if obj.Stauts > 0 then
			color = 'Blue_ON';
			message = obj.Value.Desc_IncreaseByLevel;
		elseif obj.Stauts < 0 then
			color = 'Blue_ON';
			finalValue = -1 * finalValue;
			message = obj.Value.Desc_DecreaseByLevel;
		end
		if obj.Value.Format == 'Percent' then
			finalValue = finalValue..'%';
		end
		finalValue = GetStringFontColorChangeTag(colorList['White'].ARGB, finalValue, colorList[color].ARGB);
		result = result..'$'..color..'$'..FormatMessage(message, { Status = obj.Value.Title, Value = finalValue});
	end	
	if result ~= '' then
		result = result..'$Blue_ON$';
	end
	return result;
end
-- $Dead$ 
function GetDeadText(useColorEnd)
	return '$YellowOrange$'..GetWord('Dead')..(useColorEnd and '$ColorEnd$' or '$Blue_ON$');
end
-- $ImmortalMessag$
function GetBuffImmortalMessageText(buff)
	local result = '';
	if buff.Immortal then
		result = GuideMessage('Buff_Immortal')..'$Blue_ON$';
	end
	return result;
end
-- $ImmuneRace$
function GetBuffImmuneRaceText(buff)
	local result = '';
	if #buff.ImmuneRace > 0 then
		local raceList = GetClassList('Race');
		for index, raceName in ipairs (buff.ImmuneRace) do
			local curRaceTitle = GetWithoutError(raceList[raceName], 'Title');
			if curRaceTitle and curRaceTitle ~= 'None' then
				if result ~= '' then
					result = result.. ', ';
				end
				result = result..curRaceTitle;
			end
		end
	end
	result = result..'$Blue_ON$';
	return result;
end
-- $ImmuneRaceMessage$
function GetBuffImmuneRaceMessageText(buff)
	local result = '';
	if #buff.ImmuneRace > 0 then
		result = '$Perano$'..GuideMessage('Buff_ImmuneRace');
		result = result..'$Blue_ON$';
	end	
	return result;
end
-- $BreakTypeMessage$ 
function GetBuffBreakTypeMessageText(buff)
	local result = '';
	local statusList = GetClassList('Status');
	if buff.BreakType and buff.BreakType ~= 'None' then
		result = '$Orange$'..GuideMessage('Buff_BreakType')..' '..statusList[buff.BreakType].Title;
		result = result..'$Blue_ON$';
	end
	return result;
end
-- $GroupTypeMessage$
function GetBuffGroupTypeMessageText(buff)
	local result = '';
	local buffGroupList = GetClassList('BuffGroup');
	result = '$SunsetOranage$'..GuideMessage('Buff_GroupType')..' '..buffGroupList[buff.Group].Title;
	result = result..'$Blue_ON$';
	return result;
end
-- $TurnMessage$
function GetBuffTurnMessageText(buff)
	local result = '';
	if buff.IsTurnShow then
		result = '$BrightGreen$'..GuideMessage('Buff_Turn')..'$Blue_ON$';
	end
	return result;
end
-- $HPModifyTiming$
function GetBuffHPModifyTimingText(buff)
	local result = '';
	if buff.UseHPModifier then
		result = GetTimingText(buff.HPModifyTiming)
	end
	return result;
end
-- $HPChange$
function GetBuffHPChangeText(buff)
	local result = '$White$';
	if buff.UseHPModifier then
		local hpChangeValue = buff.HPChangeValue;
		if hpChangeValue > 0 then
			result = result..hpChangeValue;
		elseif hpChangeValue < 0 then
			result = result..(-1 * hpChangeValue);
		end
		if buff.HPChangeFunctionArg ~= 'None' then
			result = result..'%';
		end
		result = result..'$Blue_ON$';
	end
	return result;
end
-- $HPChangeType$
function GetBuffHPChangeTypeText(buff)
	local result = '';
	if buff.UseHPModifier then
		if buff.HPChangeFunctionArg ~= 'None' then
			local statusList = GetClassList('Status');
			local statusName = GetWithoutError(statusList[buff.HPChangeFunctionArg], 'Title_HPChangeFunctionArg');
			if statusName and statusName ~= 'None' then
				result = statusName;
			end
		end
		result = result..'$Blue_ON$';
	end
	return result;
end
-- $HPModifier$
function GetBuffHPModifierText(buff)
	local result = '';
	if buff.UseHPModifier then
		local msg = nil;
		if buff.HPChangeFunctionType == 'Owner' then
			if buff.HPChangeValue > 0 then
				msg = 'Buff_HPModifier_HealPercent';
			else
				msg = 'Buff_HPModifier_DamagePercent';
			end
		elseif buff.HPChangeFunctionType == 'Lv' then
			if buff.HPChangeValue > 0 then
				msg = 'Buff_HPModifier_HealLv';
			else
				msg = 'Buff_HPModifier_DamageLv';
			end
		else
			if buff.HPChangeValue > 0 then
				msg = 'Buff_HPModifier_Heal';
			else
				msg = 'Buff_HPModifier_Damage';
			end
		end
		if msg then
			result = GuideMessage(msg);
		end
	end
	return result;
end
-- $DischargeOnAttack$
function GetBuffDischargeOnAttackText(buff)
	local result = '';
	if buff.DischargeOnAttack then
		result = result..GuideMessage('Buff_DischargeOnAttack');
	end			
	return result;
end
-- $DischargeOnHit$
function GetBuffDischargeOnHitText(buff)
	local result = '';
	if buff.DischargeOnHit then
		if buff.DischargeOnHitDamageType == 'None' then
			result = result..GuideMessage('Buff_DischargeOnHit');
		else
			result = result..GuideMessage('Buff_DischargeOnHitDamageType');
		end
	end			
	return result;
end
-- $DischargeDamageType$
function GetBuffDischargeDamageTypeText(buff)
	local result = '';
	if buff.DischargeOnHitDamageType ~= 'None' then
		result = GetClassList('AbilitySubType')[buff.DischargeOnHitDamageType].Title;
	end			
	return result;
end
-- $ActionController$
function GetBuffActionControllerText(buff)
	local result = '';
	if buff.UseActionController then
		local aiList = GetClassList('AI');
		if buff.ActionController then
			local curAIDesc = GetWithoutError(aiList[buff.ActionController], 'BuffActionControllerDesc');
			if curAIDesc and curAIDesc ~= 'None' then
				if curAIDesc ~= 'None' then
					result = curAIDesc;
				end
			end
		end				
	end			
	return result;
end
-- $HPDrainValue$
function GetBuffHPDrainValueText(buff)
	local result = '';
	if buff.HPDrain > 0 then
		result = '$White$'..'$HPDrain$'..'%'..'$Blue_ON$';
	end
	return result;
end
-- $HPDrainMessage$
function GetBuffHPDrainMessageText(buff)
	local result = '';
	if buff.HPDrain > 0 then
		result = GuideMessage('Buff_HPDrain');
	end
	return result;
end
-- $Explosion$
function GetBuffExplosionText(buff)
	local result = '';
	if buff.ExplosionType ~= 'None' then
		local abilityList = GetClassList('Ability');
		local curAbility = abilityList[buff.ExplosionType];
		result = '$White$'..curAbility.Title..'$Blue_ON$';
	end
	return result;
end
-- $NonCoverableMessage$
function GetNonCoverableMessage(buff)
	if buff.Coverable then
		return '';
	end
	return '$Perano$' .. GuideMessage('Buff_NonCoverable') .. '$Blue_ON$';
end
-- $BuffSystemMessage$
function GetBuffSystemMessageText(buff)
	
	local costTypeTitle = '';
	local colorList = GetClassList('Color');

	local result = '';	
	-- 주기적 피해
	if buff.UseHPModifier then
		result = ConnentTextToText(result, '\n', '$HPModifier$');
		-- Nokill
		if buff.NoKill then
			result = ConnentTextToText(result, '\n', GuideMessage('BuffNoKillMessage'));
		end
	end
	if buff.UseActionController then
		result = ConnentTextToText(result, '\n', '$ActionController$');
	end
	-- 흡혈 여부
	if buff.HPDrain > 0 then
		result = ConnentTextToText(result, '\n', '$HPDrainMessage$');
	end
	-- 피해량 반사
	if buff.UseReflectDamage then
	-- 근접한 적에게 받은 피해량의 %s만큼 해당 적에게 %s 속성 고정 피해를 입힙니다. 해당 대상이 %s 계열 상태 이상일 경우 피해량이 %s 증가합니다.
		
		local abilitySubTypeList = GetClassList('AbilitySubType');
		local buffGroupList = GetClassList('BuffGroup');
		local curDamageType = abilitySubTypeList[buff.ReflectDamageType];
		local curBuffGroup = buffGroupList[buff.ReflectDamageAdditionalBuffGroup];
		local useReflectDamageText = string.format(GuideMessage('UseReflectDamageMessage'),
			'$White$'..buff.ReflectDamageRatio..'%$Blue_ON$',
			'$White$'..curDamageType.Title..'$Blue_ON$',
			'$White$'..curBuffGroup.Title..'$Blue_ON$',
			'$White$'..buff.ReflectDamageAdditionalRatio ..'$Blue_ON$'		
		);
		result = ConnentTextToText(result, '\n', useReflectDamageText);
	end
	-- AuraBuff 
	if buff.AuraBuff ~= 'None' then
		local buffList = GetClassList('Buff');
		local auraBuff = SafeIndex(buffList, buff.AuraBuff);
		if auraBuff then
			-- 반경 @ 칸 내에 @@이 접근하면 @@ 상태가 발생합니다.
			-- AuraBuffMessage
			local auraText = '';
			if buff.IsCoverableObject then
				auraText = FormatMessage(GuideMessage('AuraBuffMessage_Conceal_For_Aura'), { Buff = GetBuffText(auraBuff) });
			else
				local rangeList = GetClassList('Range');
				local auraRangedistance = 0;
				local curAuraRange = SafeIndex(rangeList, buff.AuraRange);
				local targetTypeList = GetClassList('TargetType');
				local auraRelation = targetTypeList[buff.AuraRelation];
				if buff.AuraRange == 'Sight' then
					auraText = FormatMessage(GuideMessage('AuraBuffMessage_Sight'), {
						Relation = auraRelation.Title,
						Buff = GetBuffText(auraBuff)
					});
				elseif buff.AuraRange == 'Sphere1_ExSelf' then
					local distance = curAuraRange.Radius or curAuraRange.Distance;			
					auraText = FormatMessage(GuideMessage('AuraBuffMessage_Near'), {
						Relation = auraRelation.Title,
						Buff = GetBuffText(auraBuff)
					});					
				elseif curAuraRange then
					local distance = curAuraRange.Radius or curAuraRange.Distance;			
					auraText = FormatMessage(GuideMessage('AuraBuffMessage'), {
						Dist = '$White$'..distance..'$Blue_ON$',
						Relation = auraRelation.Title,
						Buff = GetBuffText(auraBuff)
					});
				end
			end
			if auraText ~= '' then
				result = ConnentTextToText(result, '\n', auraText);
			end
		end
	end
	-- UseTurnStartCostEater
	if buff.UseTurnStartCostEater then
		local costTypeList = GetClassList('CostType');
		costTypeTitle = table.concat(table.map(buff.UseTurnStartCostEaterType, function(costType)
			return costTypeList[costType].Title;
		end), '/');
		local guideKey = 'UseTurnStartCostEaterAmountAddMessage';
		local useTurnStartCostAmount = buff.UseTurnStartCostAmount;
		if buff.UseTurnStartCostAmount < 0 then
			useTurnStartCostAmount = -1 * useTurnStartCostAmount;
			guideKey = 'UseTurnStartCostEaterAmountMessage';
		end
		local useTurnStartCostEaterAmountText = string.format(GuideMessage(guideKey), 
			costTypeTitle, 
			'$White$'..useTurnStartCostAmount..'$Blue_ON$'
		);
		result = ConnentTextToText(result, '\n', KoreanPostpositionProcess(useTurnStartCostEaterAmountText));
	end
	-- UseTurnStartSPEater
	if buff.UseTurnStartSPEater then
		local guideKey = 'UseTurnStartSPEaterAmountAddMessage';
		local useTurnStartSPAmount = buff.UseTurnStartSPAmount;
		if buff.UseTurnStartSPAmount < 0 then
			useTurnStartSPAmount = -1 * useTurnStartSPAmount;
			guideKey = 'UseTurnStartSPEaterAmountMessage';
		end
		local useTurnStartSPEaterAmountText = string.format(GuideMessage(guideKey), 
			'$White$'..useTurnStartSPAmount..'$Blue_ON$'
		);
		result = ConnentTextToText(result, '\n', KoreanPostpositionProcess(useTurnStartSPEaterAmountText));
	end
	
	-- 	Unconscious 효과
	if buff.Unconscious then
		result = ConnentTextToText(result, '\n', GuideMessage('Unconscious'));
	end
	if not buff.UseActionController or buff.ActionController ~= 'DoNothingAI' then 
		-- 이동, 공격, 지원, 회복 어빌리티 사용 여부.
		local buffUnableType = GetClassList('BuffUnableType');
		local buffUnableTypeList = {};
		for key, ableType in pairs(buffUnableType) do
			if not buff[key] then
				table.insert(buffUnableTypeList, ableType);
			end
		end
		if #buffUnableTypeList > 0 then
			table.scoresort(buffUnableTypeList, function(ableType) return ableType.Order; end);
			local ableTextList = table.map(buffUnableTypeList, function(ableType) return '$'..ableType.TitleColor..'$'..ableType.Title; end);
			local ableText = table.concat(ableTextList, '$Blue_ON$, ');
			ableText = string.format(GuideMessage('UnableAbilityMessage'), ableText);
			result = ConnentTextToText(result, '\n', ableText);
		end
	end
	-- 안정된 자세
	if not buff.Stable then
		result = ConnentTextToText(result, '\n', GuideMessage('NotStableBuffMessage'));
	end
	-- 타겟터블.
	if buff.Untargetable then
		result = ConnentTextToText(result, '\n', GuideMessage('UntargetableMessge'));
	end
	-- 스탯 변화량.
	if buff.IsAutoStatusTooltip then
		if IsStatusValue(buff) then
			local curStatusMsg = '$StatusMessage$';
			if not IsMission() then
				if buff.IsStatusPerLevelTooltip then
					curStatusMsg = '$StatusMessageByLevel$';
				end
			end
			result = ConnentTextToText(result, '\n', curStatusMsg);
		end
	end	
	-- 존오브컨트롤 해제 여부
	if not buff.ScentOfPresence then
		result = ConnentTextToText(result, '\n', GuideMessage('ScentOfPresence'));
	end	
	
	-- 이 위까지 능력치 부분
	-- 추가로 소모 코스트로 상태 해제 로직 경고문.
	if buff.IsRemoveBuffByCostEater then
		local useTurnStartCostEaterText = '$Perano$'..string.format(GuideMessage('Warning_UseTurnStartCostEater'), costTypeTitle)..'$Blue_ON$';
		result = ConnentTextToText(result, '\n', useTurnStartCostEaterText);
	end
	if buff.IsRemoveBuffBySPEater then
		local useTurnStartSPEaterText = '$Perano$'..GuideMessage('Warning_UseTurnStartSPEater')..'\n'..GuideMessage('Warning_UseTurnStartSPEaterOvercharge')..'$Blue_ON$';
		result = ConnentTextToText(result, '\n', useTurnStartSPEaterText);
	end
	
	-- Buff ExplosionType
	if buff.ExplosionType ~= 'None' then
		abilityList = GetClassList('Ability');
		cueExplosionAbility = abilityList[buff.ExplosionType];
		local guideKey = 'UseTurnStartCostEaterAmountAddMessage';
		local cueExplosionAbilityTitle = cueExplosionAbility.Title;
		local cueExplosionAbilityDesc = cueExplosionAbility.Desc;

		local useExplosionAbilityText = "$Yellow$"..cueExplosionAbilityTitle..'\n$Blue_ON$'..cueExplosionAbilityDesc;
		result = ConnentTextToText(result, '\n\n', KoreanPostpositionProcess(useExplosionAbilityText))..'\n';
	end
	
	-- 추가 기능 메시지. FinalDesc
	if buff.FinalDesc and buff.FinalDesc ~= '' then
		result = ConnentTextToText(result, '\n', buff.FinalDesc);
	end
	-- 추가 기능 메시지2. FinalDesc
	if buff.FinalDesc2 and buff.FinalDesc2 ~= '' then
		result = ConnentTextToText(result, '\n', buff.FinalDesc2);
	end
	-- 스택 가능.
	if buff.Stack then
		local buffMaxStack = buff:MaxStack();
		if buffMaxStack and buffMaxStack > 1 and buffMaxStack < 99999 then
			local buffLevelText = string.format(GuideMessage('BuffMaxLevel'), buffMaxStack);
			result = ConnentTextToText(result, '\n', buffLevelText);
		end
	end				
	-- 공격하면 꺠어나는 메세지.
	if buff.DischargeOnAttack then
		result = ConnentTextToText(result, '\n', '$DischargeOnAttack$');
	end
	-- 떄리면 꺠어나는 메세지.
	if buff.DischargeOnHit then
		result = ConnentTextToText(result, '\n', '$DischargeOnHit$');
	end
	-- 불사 메세지.
	if buff.Immortal then
		result = ConnentTextToText(result, '\n', '$ImmortalMessage$');
	end
	-- 상태 속성
	if buff.Group ~= 'None' then
		local buffGroupList = GetClassList('BuffGroup');
		local curGroup = SafeIndex(buffGroupList, buff.Group);
		if curGroup then
			result = ConnentTextToText(result, '\n', '$GroupTypeMessage$');
		end	
	end
	-- 저항 속성 / 디버프만 보여준다.
	if buff.Type == 'Debuff' then
		if buff.BreakType and buff.BreakType ~= 'None' then
			result = ConnentTextToText(result, '\n', '$BreakTypeMessage$');
		end						
	end
	-- 면역 대상
	if #buff.ImmuneRace > 0 then
		result = ConnentTextToText(result, '\n', '$ImmuneRaceMessage$');
	end
	-- 엄폐불가
	if buff.Coverable == false then
		result = ConnentTextToText(result, '\n', '$NonCoverableMessage$');
	end
	-- 버프 인스턴스에는 표시하지 않을 정보
	if not IsBuffInstance(buff) then
		-- 턴 보여준다. 맨마지막			
		if buff.IsTurnShow then
			result = ConnentTextToText(result, '\n', '$TurnMessage$');
		end
	else -- 버프 인스턴스에만 표시할 정보
		-- 버프 시전자
		if next(buff.Givers) then
			local addMessage = GetWord('BuffGiver') .. ': ' .. table.concat(Linq.new(buff.Givers)
																				:select(function(d) return GetUnit(d[1]) end)
																				:where(function(unit) return unit end)
																				:select(function(unit) return unit.Info.Title end)
																				:toList(), ', ');
			result = ConnentTextToText(result, '\n', addMessage);
		end
		-- 참조 대상
		if buff.ReferenceTarget ~= '' then
			local refTarget = GetUnit(buff.ReferenceTarget);
			LogAndPrint('GetBuffSystemMessageText', buff.name, buff.ReferenceTarget, refTarget);
			if refTarget then
				result = ConnentTextToText(result, '\n', GetWord('BuffReferenceTarget') .. ': ' .. refTarget.Info.Title);
			end
		end
	end
	return result;
end
-- $MasteryBuff$
function GetMasteryBuffText(buff)
	local result = GetBuffText(buff, true);
	return result;
end
-- $MasteryBuffGroup$
function GetMasteryBuffGroupText(buffGroup)
	if buffGroup.name == nil or buffGroup.name == 'None' then
		return '$Red$ERROR_BUFF_GROUP$ColorEnd$';
	end
	local result = '$White$'..buffGroup.Title..'$ColorEnd$';
	return result;
end
function GetMasteryWeatherText(weatherName)
	local weatherList = GetClassList('MissionWeather');
	local weather = GetWithoutError(weatherList, weatherName);
	if not weather then
		return '$Red$ERROR_WEATHER$ColorEnd$';
	end
	local result = weather.Title;
	result = '$White$'..result..'$ColorEnd$';
	return result;
end
-- $MasteryStat$ --
function GetMasteryStatText(statName, dataType)
	local statusList = GetClassList('Status');
	local stat = GetWithoutError(statusList, statName);
	if not stat then
		return '$Red$ERROR_STAT$ColorEnd$';
	end
	local result = '';
	if dataType == 'Normal' then
		result = stat.Title;
	elseif dataType == 'Max' then
		result = stat.Title_HPChangeFunctionArg;
	end
	result = result;
	return result;
end
-- $MasteryAbilityType$
function GetMasteryAbilityTypeText(abilityTypeName)
	local abilitySubTypeList = GetClassList('MasteryAbilityType');
	local abilitySubType = GetWithoutError(abilitySubTypeList, abilityTypeName);
	if not abilitySubType then
		return '$Red$ERROR_ABILITY_TYPE$ColorEnd$';
	end
	local result = abilitySubType.Title;
	return result;
end
-- $MasteryName$
function GetMasteryAbilityTypeText(masteryName)
	local masteryList = GetClassList('Mastery');
	local masteryCls = GetWithoutError(masteryList, masteryName);
	if not masteryCls then
		return '$Red$ERROR_MASTERY_NAME$ColorEnd$';
	end
	local result = masteryCls.Title;
	return result;
end
-- $MasteryOrganizationType$
function GetMasteryOrganizationTypeText(organizationTypeName)
	local organizationTypeList = GetClassList('OrganizationType');
	local organizationType = GetWithoutError(organizationTypeList, organizationTypeName);
	if not organizationType then
		return '$Red$ERROR_ORGANIZATION_TYPE$ColorEnd$';
	end
	local result = '$White$'..organizationType.Title..'$ColorEnd$';
	return result;
end
-- $FieldEffect$
function GetMasteryFieldEffectText(fieldEffect)
	if fieldEffect.name == nil or fieldEffect.name == 'None' then
		return '$Red$ERROR_FIELDEFFECT$ColorEnd$';
	end
	local result = '$White$'..fieldEffect.Title..'$ColorEnd$';
	return result;
end
function MasteryApplyAmountValue(valueType, applyAmountType, useColorEnd)
	local result = '$White$'..'$'..applyAmountType..'$';
	if valueType == 'Percent' then
		result = result..'%';
	end
	result = result..(useColorEnd and '$ColorEnd$' or '$Blue_ON$');
	return result;
end
-- $MasteryExclusiveToolTip$
function GetMasteryExclusiveText(mastery)
	local masteryList = GetClassList('Mastery');
	local exclusiveMasteryStr = table.concat(table.map(mastery.ExclusiveMastery, function(m) return masteryList[m].Title end), ', ');		
	exclusiveMasteryStr = '$White$'..exclusiveMasteryStr..'$ColorEnd$';
	local result = '$Orange$'..string.format(GuideMessage('Mastery_ExclusiveMastery'), exclusiveMasteryStr)..'$ColorEnd$';
	return result;
end
-- $MasteryNeedCostToolTip$
function GetMasteryNeedCostText(mastery)
	local costType = GetClassList('CostType')[mastery.NeedCostTooltipType];
	if costType == nil then
		return '';
	end
	local result = '$Orange$'..KoreanPostpositionProcessCpp(string.format(GuideMessage('Mastery_NeedCostType'), costType.Title))..'$ColorEnd$';
	return result;
end
-- $MasterySystemMessage$
function GetMasterySystemMessageText(mastery)
	local isEmpty = true;
	local tb = TooltipBuilder.new();
	tb:SetBaseColor('Blue_ON');
	if #mastery.Desc_Base > 0 then
		tb:AddLine('$MasteryDescBase$');
		isEmpty = false;
	end
	
	-- 디버프 계열 면역 표시
	if mastery.ImmuneDebuff_BuffGroup then
		local buffGroup = SafeIndex(mastery, 'BuffGroup', 'name');
		local subBuffGroup = SafeIndex(mastery, 'SubBuffGroup', 'name');
		if subBuffGroup and subBuffGroup ~= 'None' then
			tb:AddLine(GuideMessage('Mastery_ImmuneDebuff_BuffGroup2'));
		elseif buffGroup and buffGroup ~= 'None' then
			tb:AddLine(GuideMessage('Mastery_ImmuneDebuff_BuffGroup'));
		end
		isEmpty = false;
	end
	
	if #mastery.NeutralizeFieldEffect > 0 then
		local fieldEffectNames = table.concat(table.map(mastery.NeutralizeFieldEffect, function(fieldEffect) return fieldEffect.Title end), ', ');
		tb:AddLine(FormatMessage(GuideMessage('NeutralizeFieldEffect'), {FieldEffectList = string.format('$White$%s$Blue_ON$',fieldEffectNames)}, nil, true));
		isEmpty = false;
	end
	
	-- 필요한 Cost가 있어야만 발동하는지 (None은 필요 없음, Desc는 필요하지만 Desc_Base의 내용에 직접 포함됨)
	if mastery.NeedCostTooltipType ~= 'None' and mastery.NeedCostTooltipType ~= 'Desc' then
		tb:AddEmptyLine(true);
		tb:AddLine('$MasteryNeedCostToolTip$');
		isEmpty = false;
	end

	-- 스탯.
	if IsStatusValue(mastery) then
		tb:AddEmptyLine(true);
		if not isEmpty then
			tb:AddLine(string.format('$LimeGold$%s', GetWord('AdditionalEffect')));
		end
		tb:AddLine('$StatusMessage$');
	end
	
	-- 마스터리 어빌리티
	local ability = GetMasteryAbility(mastery, 'Ability');
	if ability then
		local masteryAblityText = GuideMessage('Mastery_UnlockAbility')..'\n\n'..'$MasteryAbilityToolTip$';
		if not isEmpty then
			masteryAblityText = '\n'..masteryAblityText;
		end
		tb:AddLine(masteryAblityText);
	end
	
	-- 기능용 체인 어빌리티
	local chainAbility = GetMasteryAbility(mastery, 'ChainAbility');
	if chainAbility then
		tb:AddLine('$MasteryChainAbilityToolTip$');
	end	
	
	if mastery.UseBuffTooltip then
		local buffTooltip = GetMasteryBuffMessageText(mastery);
		if buffTooltip ~= '' then
			tb:AddEmptyLine(true);
			tb:AddLine(buffTooltip);
		end
	end
	
	local linkMastery = GetWithoutError(mastery.Mastery, 'name');
	if linkMastery and linkMastery ~= 'None' and mastery.UseSubMasteryTooltip then
		tb:AddEmptyLine(true);
		tb:AddLine('$MasteryMasteryToolTip$');
	end
	
	if IsObject(mastery) then
		local owner = GetMasteryOwner(mastery);
		if owner then
			local ownerStartJobMastery = GetWithoutError(owner.StartJob, 'name');
			if ownerStartJobMastery and ownerStartJobMastery ~= 'None' and mastery.UseSubJobMasteryTooltip then
				tb:AddEmptyLine(true);
				tb:AddLine('$MasteryStartJobMasteyToolTip$');
			end
		end
	end
	
	if #mastery.ExclusiveMastery > 0 then
		tb:AddEmptyLine(true);
		tb:AddLine('$MasteryExclusiveToolTip$');
	end
	-- 이뮨 대상 표시.
	if mastery.Life or mastery.Edible then
		tb:AddEmptyLine(true);
		tb:AddLine('$MasteryImmuneMachine$', 'Perano');
	end	
	
	return tb:Build();
end
-- $MasteryPerformanceMessage$
function GetMasteryPerformanceMessageText(mastery)
	local result = '';
	local performanceCls = GetClassList('Performance')[mastery.PerformanceType];
	if performanceCls then
		result = performanceCls.Desc;
	end
	return result;
end
-- $MasteryPerformanceEffectList$
function GetMasteryPerformanceEffectListText(mastery)
	local result = '';
	local performanceCls = GetClassList('Performance')[mastery.PerformanceType];
	if performanceCls then
		local effectList = GetClassList('PerformanceEffect');
		-- 공연 효과 속성 목록
		local effectStrList = {};
		for _, info in ipairs(performanceCls.Effect) do
			local effectCls = effectList[info.Type];
			if effectCls then
				table.insert(effectStrList, '$White$'..effectCls.Title..'$Blue_ON$');
			end
		end
		result = table.concat(effectStrList, ', ');
	end
	return result;
end
-- $MasteryBuffMessage$
function GetMasteryBuffMessageText(mastery)
	local result = '';
	
	local buffName = GetWithoutError(mastery.Buff, 'name');
	if buffName and buffName ~= 'None' then
		if result == '' then
			result = '$Blue_ON$'..result..'$MasteryBuffToolTip$';
		else
			result = result..'\n\n'..'$MasteryBuffToolTip$';
		end
	end

	local subBuffName = GetWithoutError(mastery.SubBuff, 'name');
	if subBuffName and subBuffName ~= 'None' then
		if result == '' then
			result = '$Blue_ON$'..result..'$MasterySubBuffToolTip$';
		else
			result = result..'\n\n'..'$MasterySubBuffToolTip$';
		end
	end
	
	local thirdBuffName = GetWithoutError(mastery.ThirdBuff, 'name');
	if thirdBuffName and thirdBuffName ~= 'None' then
		if result == '' then
			result = '$Blue_ON$'..result..'$MasteryThirdBuffToolTip$';
		else
			result = result..'\n\n'..'$MasteryThirdBuffToolTip$';
		end
	end

	local forthBuffName = GetWithoutError(mastery.ForthBuff, 'name');
	if forthBuffName and forthBuffName ~= 'None' then
		if result == '' then
			result = '$Blue_ON$'..result..'$MasteryForthBuffToolTip$';
		else
			result = result..'\n\n'..'$MasteryForthBuffToolTip$';
		end
	end

	return result;
end
-- $MasteryDetailedSnipeDesc$
function GetMasteryDetailedSnipeDescText(mastery)
	local result = '';
	local snipeTypeList = GetClassList('SnipeType');	
	local snipeTable = {};
	for key, value in pairs (snipeTypeList) do
		table.insert(snipeTable,value);	
	end
	table.sort(snipeTable, function (a, b)
		return a.Order < b.Order;
	end);
	local buffTootip = '';
	local buffKeys = {};
	for index, snipeInfos in ipairs (snipeTable) do
		if result == '' then
			result = GetSnipeToolTipInfo(snipeInfos, 'MasteryTooltip');
		else
			result = result..'\n'..GetSnipeToolTipInfo(snipeInfos, 'MasteryTooltip');
		end
		if snipeInfos.ApplyTargetBuff ~= 'None' then
			if buffKeys[snipeInfos.ApplyTargetBuff] == nil then
				if buffTootip == '' then
					buffTootip = GetSnipeToolTipInfo(snipeInfos, 'BuffTooltip');
				else
					buffTootip = buffTootip..'\n\n'..GetSnipeToolTipInfo(snipeInfos, 'BuffTooltip');
				end
			end
			buffKeys[snipeInfos.ApplyTargetBuff] = true;
		end
	end
	result = result..'\n\n'..buffTootip;
	return result;
end
function GetSnipeToolTipInfo(snipe, infoType, applyRatio)
	applyRatio = (applyRatio or 100) / 100;
	local colorList = GetClassList('Color');

	local content = '';	
	if infoType == 'MasteryTooltip' then
		-- 저격 대상
		local titleText = string.format("$%s$%s - %s$%s$", snipe.TitleColor, GetWord('SnipeType'), snipe.Title, 'Blue_ON');
		if content == '' then
			content = content..titleText;
		else
			content = content..'\n'..titleText;
		end	
	end
	if infoType == 'MasteryTooltip' or infoType == 'SelectTooltip' then
		-- 명중률
		if snipe.Accuracy ~= 0 then
			local accuracyText = string.format(GuideMessage('Snipe_Accuracy'), snipe.Accuracy * applyRatio);
			if content == '' then
				content = content..accuracyText;
			else
				content = content..'\n'..accuracyText;
			end
		end
		-- 치명타 적중률
		if snipe.CriticalStrikeChance ~= 0 then
			local criticalStrikeChanceText = string.format(GuideMessage('Snipe_CriticalStrikeChance'), snipe.CriticalStrikeChance * applyRatio);
			if content == '' then
				content = content..criticalStrikeChanceText;
			else
				content = content..'\n'..criticalStrikeChanceText;
			end
		end
		-- 적 방어율 감소
		if snipe.EnemyBlock ~= 0 then
			local enemyBlockText = string.format(GuideMessage('Snipe_EnemyBlock'), -1 * snipe.EnemyBlock * applyRatio);
			if content == '' then
				content = content..enemyBlockText;
			else
				content = content..'\n'..enemyBlockText;
			end
		end
		if snipe.ApplyAct ~= 0 then
			local applyActText = string.format(GuideMessage('Snipe_ApplyAct'), snipe.ApplyAct * applyRatio);
			if content == '' then
				content = content..applyActText;
			else
				content = content..'\n'..applyActText;
			end
		end
		-- 피격 시 버프
		if snipe.ApplyTargetBuff ~= 'None' then
			-- ApplyTargetBuffLv
			local buffList = GetClassList('Buff');
			local buff = buffList[snipe.ApplyTargetBuff];
			if buff and buff.name then
				local applyBuffText = string.format(GuideMessage('Snipe_ApplyTargetBuff'), 
					string.format("[colour='%s']%s[colour='%s']", colorList[GetBuffTitleColor(buff)].ARGB, buff.Title, colorList['Blue_ON'].ARGB)
				);
				if content == '' then
					content = content..applyBuffText;
				else
					content = content..'\n'..applyBuffText;
				end
			end
		end
		-- 헤드샷 
		if snipe.HeadShotRatio ~= 0 then
			local headShotRatioText = string.format(GuideMessage('Snipe_HeadShotRatio'), snipe.HeadShotRatio * applyRatio);
			if infoType == 'SelectTooltip' then
				headShotRatioText = headShotRatioText..'\n'..GuideMessage('Snipe_HeadShotUsable');
			elseif infoType == 'MasteryTooltip' then
				headShotRatioText = headShotRatioText..'\n$Perano$'..GuideMessage('Snipe_MasteryAlert')..'$Blue_ON$';
			end
			if content == '' then
				content = content..headShotRatioText;
			else
				content = content..'\n'..headShotRatioText;
			end
		else
			if infoType == 'SelectTooltip'  then
				local headShotDisableText = GuideMessage('Snipe_HeadShotDisable');
				if content == '' then
					content = content..headShotDisableText;
				else
					content = content..'\n'..headShotDisableText;
				end
			end
		end
	end
	if infoType == 'SelectTooltip' or  infoType == 'BuffTooltip' then
		if snipe.ApplyTargetBuff ~= 'None' then
			-- ApplyTargetBuffLv
			local buffList = GetClassList('Buff');
			local buff = buffList[snipe.ApplyTargetBuff];
			if buff and buff.name then
				local buffText = string.format("[colour='%s']", colorList[GetBuffTitleColor(buff)].ARGB)..buff.Title..'\n'..buff.Desc;
				if content == '' then
					content = content..buffText;
				else
					content = content..'\n\n'..buffText;
				end
			end
		end
	end
	return content;
end
TooltipBuilder = {};
TooltipBuilder.__index = TooltipBuilder;
function TooltipBuilder.new()
	local ret = {Lines = {}, CurrentLine = nil, BaseColor = 'White', CurrentColor = 'White'};
	setmetatable(ret, TooltipBuilder);
	return ret;
end
function TooltipBuilder.SetBaseColor(self, colorKey)
	self.BaseColor = colorKey;
end
function TooltipBuilder.SetLineColor(self, colorKey)
	self.CurrentColor = colorKey;
end
function TooltipBuilder.AddLine(self, line, colorKey)
	if self.CurrentLine ~= nil then
		table.insert(self.Lines, {self.CurrentLine, self.CurrentColor});
	end
	self.CurrentLine = line;
	if colorKey then
		self.CurrentColor = colorKey;
	else
		self.CurrentColor = self.BaseColor;
	end
end
function TooltipBuilder.AddEmptyLine(self, ignoreWhenEmpty)
	if ignoreWhenEmpty and (self.CurrentLine == '' or self.CurrentLine == nil) and #self.Lines == 0 then
		return;
	end
	self:AddLine('');
end
function TooltipBuilder.AppendText(self, text)
	if self.CurrentLine == nil then
		self.CurrentLine = text;
	else
		self.CurrentLine = self.CurrentLine .. text;
	end
end
function TooltipBuilder.Build(self)
	if self.CurrentLine ~= nil then
		table.insert(self.Lines, {self.CurrentLine, self.CurrentColor});
		self.CurrentLine = nil;
		self.CurrentColor = self.BaseColor;
	end
	local result = '';
	if #self.Lines > 0 then
		local rLines = {};
		local prevColor = nil;
		for i = 1, #(self.Lines) do
			local lineData = self.Lines[i];
			if lineData[2] ~= prevColor then
				table.insert(rLines, EncloseTextWithColorKey(lineData[2], lineData[1]));
			else
				table.insert(rLines, lineData[1]);
			end
		end
		result = table.concat(rLines, '\n');
	end
	return result;
end
function GetHackingProtocolToolTipInfo(protocolCls, self, target)
	local ability = protocolCls.Ability;
	if self then
		ability = GetAbilityObject(self, ability.name) or ability;
	end
	local builder = TooltipBuilder.new();
	builder:AppendText(AbilityTooltip_CommonShared(ability, self, false));
	local enable, reason = protocolCls.IsEnableTest(self, target, protocolCls);
	if not enable then
		builder:AddEmptyLine();
		builder:AddLine(GuideMessage(reason), 'Tomato');
	end
	return builder:Build();
end
function GetAbilityProtocolToolTipInfo(protocolCls, target)
	local ability = protocolCls.Ability;
	if target then
		ability = GetAbilityObject(target, ability.name) or ability;
	end
	return AbilityTooltip_CommonShared(ability, target, false);
end
function GetAbilitySubCommandToolTipInfo(subCommandCls, target)
	local ability = subCommandCls.Ability;
	if target then
		ability = GetAbilityObject(target, ability.name) or ability;
	end
	return AbilityTooltip_CommonShared(ability, target, false);
end
-- $MasterySystemSPMessage$
function GetMasterySPMessageText(mastery)
	local result = '';
	if mastery.Desc_Base and #mastery.Desc_Base > 0 then
		result = '$MasteryDescBase$';
	end
	return result;
end
-- $ApplyTypeTitle$
function GetItemSystemMessageText(item)
	local result = item.Desc_Base;
	if item.Mastery and item.Mastery.name and item.Mastery.name ~= 'None' then
		if result ~= '' then
			result = result..'\n\n';
		end
		result = result..'$MasteryDesc$';
	end
	if item.Ability and item.Ability.name and item.Ability.name ~= 'None' then
		if result ~= '' then
			result = result..'\n\n';
		end
		result = result..'$Blue_ON$';
		local abilityTitleText = '$'..GetAbilityTitleColor(item.Ability)..'$'..item.Ability.Title..'$Blue_ON$';
		if item.Ability.IsUseCount then
			-- 특성에 의해 강화되지 않은 어빌리티 정보를 위해 클래스에서 받아옴
			local testAbility = GetClassList('Ability')[item.Ability.name];
			if GetWithoutError(item, 'AbilityModifier') then
				-- 아이템의 AbilityModifier가 존재하면 더미 오브젝트로 갈아치우고 적용함
				testAbility = CreateDummyProperty('Ability', item.Ability.name);
				item.AbilityModifier(item, testAbility);
			end
			local maxUseCountText = '$White$'..testAbility.MaxUseCount..'$Blue_ON$';
			result = result..string.format(GuideMessage('ItemUseAbility'), abilityTitleText, maxUseCountText);
		else
			result = result..string.format(GuideMessage('ItemUseAbilityNoCount'), abilityTitleText);
		end
		result = result..'\n\n'..'$ItemAbilityToolTip$';
	end
	return result;
end
-- $OrganizationDescMessage$
function GetOrganizationDescMessageText(organization)
	local result = '';
	local masteryList = GetClassList('Mastery');
	if organization ~= 'None' and masteryList[organization] then
		result = string.format(GuideMessage('ActivateBasicMastery'), masteryList[organization].Title);
	end
	return result;
end
-- $PerformanceDescMessage$
function GetPerformanceDescMessageText(performance)
	local result = '';
	result = GuideMessage('PerformanceTooltip_PerformanceMessage');
	return result;
end
-- $PerformanceType$
function GetPerformanceTypeText(performance)
	local result = '';
	result = performance.Title;
	return result;
end
-- $PerformanceGreatList$
function GetPerformanceGreatListText(performance, owner)
	local result = '';
	local greatList = GetClassList('PerformanceGreat');
	local greatStrList = {};
	for _, info in ipairs(performance.Great) do
		local greatCls = greatList[info.Type];
		if greatCls then
			local greatDesc = '';
			if owner then
				greatDesc = greatCls:DescFunc(owner);
			else
				greatDesc = greatCls.Desc;
			end
			table.insert(greatStrList, '$Perano$'..greatCls.Title..'$Blue_ON$'..': '..greatDesc);
		end
	end
	result = table.concat(greatStrList, '\n');
	return result;
end
-- $PerformanceFinishList$
function GetPerformanceFinishListText(performance, owner)
	local result = '';
	local finishList = GetClassList('PerformanceFinish');
	-- 공연 마무리 목록
	local finishStrList = {};
	for i, info in ipairs(performance.Finish) do
		local finishCls = finishList[info.Type];
		if finishCls then
			local titleMsg = 'MasteryTooltip_PerformanceFinishLv';
			if i == #performance.Finish then
				titleMsg = 'MasteryTooltip_PerformanceFinishLvFinal';
			end
			local finishTitle = string.format(GuideMessage(titleMsg), info.Lv);
			local finishDesc = '';
			if owner then
				finishDesc = finishCls:DescFunc(owner);
			else
				finishDesc = finishCls.Desc;
			end
			if owner and info.Lv <= owner.PerformanceGreatLv then
				finishTitle = '$Corn$'..finishTitle;
			end
			table.insert(finishStrList, '$Perano$'..finishTitle..'$Blue_ON$'..': '..finishDesc);
		end
	end
	result = table.concat(finishStrList, '\n');
	return result;
end
-- $QuestTypeMessage$
function GetQuestTypeMessageText(quest)
	local result = quest.Type.Title;
	return result;
end
-- $QuestSystemMessage$
function GetQuestSystemMessageText(quest, textType)
	local result = '';
	if textType == 'Objective' then
		result = quest.Objective_Base;
	elseif textType == 'Title' then
		result = quest.Title_Base;
	end
	return result;
end
--$TargetItem$ 
function GetQuestTargetItemText(quest)
	local title = 'Error';
	local clsList = GetClassList(quest.Type.Idspace);
	local cls = SafeIndex(clsList, quest.Target);
	if cls then
		title = clsList[quest.Target].Title;
		-- 아이템 특수 처리
		if quest.Type.Idspace == 'Item' then
			local colorList = GetClassList('Color');
			local curColor = colorList[cls.Rank.Color].ARGB;
			title = string.format("[tooltip type='item' key='%s' color='%s']%s[tooltip-end]", cls.name, curColor, title);
		end
	end
	return title;
end
-- $MasteryAdditionalSubContents$
function GetMasteryMasteryDescBaseText(contents, caseEndColor, highlightColor)
	local result = '';
	if #contents < 1 then
		return '';
	end
	for index, caseCls in ipairs (contents) do
		local caseLineBreak = StringToBool(GetWithoutError(caseCls, 'CaseLineBreak'), false) and '\n' or ( caseCls.Text == '' and '' or ': ');
		local lineBreak = StringToBool(GetWithoutError(caseCls, 'LineBreak'), false) and '\n' or '';
		local curCaseColorType = '$'..caseCls.CaseColor..'$';
		local curCaseEndColor = caseEndColor or '$Blue_ON$';
		local caseTitle = '';
		local concatenateText = '';
		local colorHighlight = highlightColor or '$White$';
		local colorEnd = curCaseColorType;
		-- 1) 케이스 타이틀 얻어오기.
		if caseCls.CaseType == 'Custom' then
			caseTitle = caseCls.CaseValue;
		elseif caseCls.CaseType == 'CustomText' then
			colorHighlight = '';
			caseTitle = caseCls.CaseValue;
		elseif caseCls.CaseType ~= 'None' and caseCls.CaseValueType == 'string' then
			local caseTypeList = GetClassList(caseCls.CaseType);
			local curCaseType = GetWithoutError(caseTypeList, caseCls.CaseValue);
			if not curCaseType then
				return '$Red$ERROR_CASETITLE_CASETYPE1$Blue_ON$';
			end
			caseTitle = curCaseType.Title;
		elseif caseCls.CaseType ~= 'None' and caseCls.CaseValueType == 'table' then
			caseTitle = table.concat(table.map(string.split(caseCls.CaseValue, '[, ]'), function(text)
				local caseTypeList = GetClassList(caseCls.CaseType);
				local curCaseType = GetWithoutError(caseTypeList, text);
				if not curCaseType then
					return '$Red$ERROR_CASETITLE_CASETYPE2$Blue_ON$';
				end
				return curCaseType.Title;
			end), ', ');
		end

		local formatTable = {};
		
		for _, formatData in ipairs(GetWithoutError(caseCls, 'FormatKeyword')) do
			local text = '';
			local colorHighlight = '';
			if formatData.Color ~= 'None' then
				colorHighlight = '$'..formatData.Color..'$';
			end
			if formatData.ValueType == 'text' then
				text = formatData.Value
			elseif formatData.ValueType == 'string' then
				local clsList = GetClassList(formatData.Idspace);
				local clsType = GetWithoutError(clsList, formatData.Key);
				if not clsType then
					text = '$Red$ERROR_FORMAT_TYPE$Blue_ON$';					
				else
					text = clsType[formatData.Value];
				end						
			elseif formatData.ValueType == 'table' then
				text = table.concat(table.map(string.split(formatData.Key, '[, ]'), function(text)
					local clsList = GetClassList(formatData.Idspace);
					local clsType = GetWithoutError(clsList, text);
					if not clsType then
						return '$Red$ERROR_ADDITONALSUBCONTENTS_CASETYPE$Blue_ON$';
					end
					return clsType[formatData.Value];
				end), ', ');		
			end
			text = colorHighlight..text;
			if formatData.Color ~= 'None' then
				text = text..'$ColorEnd$';
			end
			formatTable[formatData.FormatKey] = text;
		end
		
		if caseCls.CaseType ~= 'None' then
			caseTitle = FormatMessage(caseTitle, formatTable, nil, true);
			concatenateText = caseTitle..curCaseEndColor..caseLineBreak;
		end
	
		concatenateText = curCaseColorType..concatenateText..FormatMessage(caseCls.Text, formatTable, nil, true)..curCaseEndColor..lineBreak;		
		
		if index == 1 then
			result = concatenateText;
		else
			result = result..'\n'..concatenateText;
		end
	end
	return result;
end
-----------------------------------------------------------------
-- 툴팁 유틸리티 함수
-----------------------------------------------------------------
function GetAbilityTitleColor(ability) 
	local color = 'Red';	
	if ability.Type == 'Assist' then
		if ability.ApplyTarget == 'Ally' or ability.ApplyTarget == 'Self' then
			if ability.ApplyTargetBuff then
				if ability.ApplyTargetBuff.Type == 'Buff' then
					color = 'WhiteBlue';
				elseif ability.ApplyTargetBuff.Type == 'Debuff' then
					color = 'Orange';
				else
					color = 'Yellow';
				end
			end
		elseif ability.ApplyTarget == 'Enemy' or ability.ApplyTarget == 'Any' or ability.Target == 'PureEnemy' then
			color = 'Orange';
		elseif ability.ApplyTarget == 'Ground' then
			if ability.ApplyTargetBuff then
				if ability.ApplyTargetBuff.Type == 'Buff' then
					color = 'WhiteBlue';
				elseif ability.ApplyTargetBuff.Type == 'Debuff' then
					color = 'Orange';
				else
					color = 'Yellow';
				end
			end
		end
	elseif ability.Type == 'Attack' then
		color = 'Orange';
	elseif ability.Type == 'StateChange' then
		color = 'White';
	elseif ability.Type == 'Heal' then
		color = 'BrightGreen';
	elseif ability.Type == 'Summon' then
		color = 'LimeGreen';
	elseif ability.Type == 'Interaction' then
		color = 'Yellow';
	end
	return color;
end
function GetBuffTitleColor(buff)
	local color = 'Yellow';
	local buffTypeList = GetClassList('BuffType');
	if buff.Type ==	'Buff' or buff.Type == 'Debuff' or buff.Type == 'State' then
		color = buffTypeList[buff.Type].TitleColor;
	end
	return color;
end
function GetBuffText(buff, useColorEnd)
	if buff.name == nil or buff.name == 'None' then
		return '$Red$ERROR_BUFF'..(useColorEnd and '$ColorEnd$' or '$Blue_ON$');
	end
	local result = '';
	local color = GetBuffTitleColor(buff);
	if buff.Title == nil then
		LogAndPrint('buff:', buff, buff.name);
		Traceback();
	end
	result = '$'..color..'$'..buff.Title;
	result = result..(useColorEnd and '$ColorEnd$' or '$Blue_ON$');
	return result;
end
function GetBuffGroupText(buff)
	if buff.name == nil or buff.name == 'None' then
		return '$Red$ERROR_BUFF$Blue_ON$';
	end
	local result = '';
	local buffGroupList = GetClassList('BuffGroup');
	local buffGroup = buffGroupList[buff.Group];
	if buffGroup then
		result = buffGroup.Title;
	end
	return result;
end
function GetBuffToolTip(buff, lv)

	local result = '';
	local buffName = GetWithoutError(buff, 'name');
	if buffName and buffName ~= 'None' then
		local color = GetBuffTitleColor(buff);
		if lv and lv > 1 then
			result = '$'..color..'$'..GetWord('Level')..' '..lv..' '..buff.Title;
		else
			result = '$'..color..'$'..buff.Title;
		end
		result = result..'\n';
		result = result..'$Blue_ON$'..buff.Desc;
	end
	return result;
end
function GetMasteryTitleColor(mastery)
	return mastery.Category.Color;
end
function GetMasteryTitleText(mastery)
	local masteryName = GetWithoutError(mastery, 'name');
	local result = '';
	if masteryName and masteryName ~= 'None' then
		local color = GetMasteryTitleColor(mastery);
		result = '$'..color..'$'..mastery.Title;
	end
	return result .. '$ColorEnd$';
end
function GetStatusTitleText(status)
	local result = '';
	local statusName = GetWithoutError(status, 'name');
	if statusName and statusName ~= 'None' then
		result = status.Title;
	end
	return result;
end
function GetMasteryToolTip(mastery)
	local result = '';
	local masteryName = GetWithoutError(mastery, 'name');
	if masteryName and masteryName ~= 'None' then
		local color = GetMasteryTitleColor(mastery);
		result = '$'..color..'$'..mastery.Title;
		result = result..'\n';
		result = result..'$Blue_ON$'..mastery.Desc;
	end
	return result;
end
function IsStatusValue(obj)
	local result = false;
	local statusList = GetClassList('Status');
	local idSpace = GetIdspace(obj);
	for key, value in pairs (statusList) do
		local status =  GetWithoutError(obj, key);
		if status and status ~= 0 then
			if key ~= 'HPDrain' or idSpace == 'Item' then
				result = true;
				break;
			end
		end
	end
	return result;
end
function GetTimingText(timing)
	return GetWord('Timing_'..timing);
end
---------- 툴팁 붙여주는 함수
function ConnentTextToText(frontText, connector, nextText)
	if frontText == '' then
		frontText = frontText..nextText;
	else
		frontText = frontText..connector..nextText;
	end		
	return frontText;
end