function TargetAbilityUseableCheck(self, ability, target)
	-- 여러가지 조건에 의해서 대상에 대해 어빌리티의 사용자체가 불가능한 경우 여기서 처리
	local reason = {};
	local able = 'Able';
	
	-- 1) 무력화 버프(NutralizeBuff) 보유여부 체크
	for i, neutralizeBuff in ipairs(ability.NeutralizeBuff) do
		if GetBuff(target, neutralizeBuff.name) then
			able = 'Hide';
			table.insert(reason, {Type= 'BlockByNeutralizeBuff', Buff = neutralizeBuff.Title});	-- 클라에서는 번역이 잘 될테니까
		end
	end
	-- 2) 제외 종족 체크
	for i, immuneRace in ipairs(ability.ImmuneRace) do
		if target.Race.name == immuneRace then
			able = 'Hide';
			table.insert(reason, {Type='BlockByImmuneRace', Race=target.Race});
		end
	end
	-- 3) 장애물 체크
	if (ability.Type == 'Assist' or ability.Type == 'Heal') and (target.name ~= 'Utility_TrapInstance' or (ability.name ~= 'EMPGrenade' and ability.name ~= 'SearchProtocol')) and target.Obstacle then
		able = 'Hide';
		table.insert(reason, {Type='BlockByObstacle', Race=target.name});
	end
	
	if ability.Type == 'Heal' then
		-- 4) 힐 어빌리티인 경우, 대상이 만피인 경우 Able 이지만 이유를 넘겨주자.
		if ability.SubType2 == 'HP' then
			if target.HP == target.MaxHP then
				table.insert(reason, {Type='NotUseHealByMaxHP'});
			end
		end	
		-- 5) 기력 회복 어빌리티인 경우, 대상이 MaxCost이면 사용 불가능
		if ability.SubType2 == 'Cost' then
			if target.Cost == target.MaxCost then
				able = 'Hide';
				if target.CostType.name ~= 'None' then
					table.insert(reason, {Type='NotUseCostByMaxCost'});
				end
			end
		end	
		-- 6) SP 회복 어빌리티인 경우, 대상이 무능력자 이거나 Overcharge 상태면 사용 불가능
		if ability.SubType2 == 'SP' then
			if target.Overcharge > 0 then
				able = 'Hide';
				table.insert(reason, {Type = 'NotUseAlreadyOvercharge'});
			elseif target.ESP.name == nil then
				able = 'Hide';
			end
		end
	end

	-- 7) 어빌리티 커스터마이징 테스트
	if ability.TargetUseableChecker ~= 'None' then
		local checkFunc = _G[ability.TargetUseableChecker];
		if checkFunc then
			local ret = checkFunc(self, ability, target, reason);
			if ret then
				able = ret;
			end
		end
	end	
	
	return able, reason;
end

function TargetAbilityUseableCheck_UnsummonMachine(self, ability, target, reason)
	if not HasBuff(target, 'SummonMachine') then
		return 'Hide';
	end
end
function TargetAbilityUseableCheck_Tame(self, ability, target, reason)
	-- 어빌리티 면역 대상은 대상 목록에서 안 나오게 한다.
	for _, info in ipairs(reason) do
		if info.Type == 'BlockByImmuneRace' then
			return 'Hide';
		end
	end
	
	-- 도발에 걸려있으면 제외
	if HasBuff(target, 'Provocation') then
		local curReason = { Type = 'BlockByNeutralizeBuff', Buff = GetClassList('Buff')['Provocation'].Title };	-- 클라에서는 번역이 잘 될테니까
		table.insert(reason, curReason);
		return 'Disable';
	end
	
	local limit = 'Epic';
	if GetMasteryMastered(GetMastery(self), 'MonsterTame') then
		limit = 'Legend';
	end
	
	local epicGradeCls = GetClassList('MonsterGrade')[limit];
	if target.Grade.Weight > epicGradeCls.Weight then
		return 'Hide';
	end
	
	-- 드라키 알은 제외
	if string.find(target.name, 'Mon_Beast_Dragon_Egg') then
		return 'Hide';
	end
	-- 고결한 자아
	if GetMasteryMastered(GetMastery(target), 'Draky') then
		local beastTypeCls = GetBeastTypeClassFromObject(target);
		if not beastTypeCls or beastTypeCls.EvolutionType.name ~= 'EggStart' or beastTypeCls.EvolutionStage > 1 then
			return 'Hide';
		end
	end	
	
	-- 최대 야수 개수 체크 (전체 개수 제한과 종류별 개수 제한이 같으면, 굳이 종류별 개수 체크를 하지 않음)
	local company = GetCompany_Shared(self);
	if company and company.MaxBeastCountPerType < company.MaxBeastCountTotal then
		local summonBeastList = GetSummonBeastList(self);
		local typeCount = table.count(summonBeastList, function(info)
			return info.Object.Job.name == target.Job.name;
		end);
		if typeCount >= company.MaxBeastCountPerType then
			local curReason = { Type = 'NotUseByMaxBeastCountType', Value = company.MaxBeastCountPerType, JobName = target.Job.name };
			table.insert(reason, curReason);
			return 'Disable';
		end
	end
end
function TargetAbilityUseableCheck_UnsummonBeast(self, ability, target, reason)
	if not HasBuff(target, 'SummonBeast') then
		return 'Hide';
	end
end
function TargetAbilityUseableCheck_PreyFishing(self, ability, target, reason)
	if target.Race.name == 'Object' then
		return 'Hide';
	end
	local isDisableKnockbackMastery = nil;
	local masteryTable = GetMastery(target);
	for key, mastery in pairs(masteryTable) do
		if mastery.DisableKnockback then
			isDisableKnockbackMastery = mastery;
			break;
		end
	end
	if isDisableKnockbackMastery then
		table.insert(reason, {Type = 'NotUseByHavingThisMastery', Mastery = isDisableKnockbackMastery.name});
		return 'Disable';
	end
end
function TargetAbilityUseableCheck_Machine(self, ability, target, reason)
	if target.Race.name ~= 'Machine' then
		return 'Hide';
	end
end
function TargetAbilityUseableCheck_SearchProtocol(self, ability, target, reason)
	-- 미니맵에 안 보이면 무시
	if not target.ShowMinimap then
		return 'Hide';
	end
	-- 상호 작용이 가능하면 적용
	if IsTeamInteractable(GetTeam(self), target, 'Any') then
		return 'Able';
	end
	-- 상호 작용이 불가능한 Untargetable 오브젝트는 무시
	if target.Untargetable and target.name ~= 'Utility_TrapInstance' then
		return 'Hide';
	end
	-- 오브젝트도 아니고, 적도 아니면 무시 (자기 자신은 제외. 셀프 타겟팅 어빌리티라서 자기 자신도 무시하면 어빌리티를 못 씀...)
	if target.Race.name ~= 'Object' and GetRelation(self, target) ~= 'Enemy' and self ~= target then
		return 'Hide';
	end
end
function TargetAbilityUseableCheck_AssistProtocol(self, ability, target, reason)
	-- 사용 가능한 프로토콜 커맨드가 하나도 없으면 대상에서 제외
	local enableProtocol = false;
	local protocolClsList = GetClassList(ability.AbilitySubMenu);
	for _, protocolCls in pairs(protocolClsList) do
		if protocolCls.IsEnableTest(self, target, protocolCls) then
			enableProtocol = true;
			break;
		end
	end
	if not enableProtocol then
		return 'Hide';
	end
end
function TargetAbilityUseableCheck_AwakenCommand(self, ability, target, reason)
	-- 자신은 제외
	if self == target then
		return 'Hide';
	end
end
function TargetAbilityUseableCheck_EMPGrenade(self, ability, target, reason)
	if target.name ~= 'Utility_TrapInstance' and target.Race.name == 'Object' then
		return 'Hide';
	end
end
function TargetAbilityUseableCheck_Howl_Obedience(self, ability, target, reason)
	if target.Lv > self.Lv then
		return 'Hide';
	end
end
function TargetAbilityUseableCheck_Howl_Hatch(self, ability, target, reason)
	if string.find(target.name, 'Mon_Beast_Dragon_Egg') == nil or HasBuff(target, ability.ApplyTargetBuff.name) then
		return 'Hide';
	end
end
function TargetAbilityUseableCheck_RemoveBuffHide(self, ability, target, reason)
	local buffName = GetWithoutError(ability.RemoveBuff, 'name');
	if buffName and buffName ~= 'None' then
		if not HasBuff(target, buffName) then
			return 'Hide';
		end
	end
end
function TargetAbilityUseableCheck_FlypaperBig_Move(self, ability, target, reason)
	if target.Race.name == 'Object' then
		return 'Hide';
	end
	
	local isEnable = true;
	
	local isDisableKnockbackMastery = nil;
	local masteryTable = GetMastery(target);
	for key, mastery in pairs(masteryTable) do
		if mastery.DisableKnockback then
			isDisableKnockbackMastery = mastery;
			break;
		end
	end
	if isDisableKnockbackMastery then
		isEnable = false;
		table.insert(reason, {Type = 'NotUseByHavingThisMastery', Mastery = isDisableKnockbackMastery.name});
	end
	
	local fromPos = GetPosition(self);
	local targetPos = GetPosition(target);
	local targetDist = GetDistance2D(targetPos, fromPos);
	local knockbackPower = math.min(math.floor(targetDist), ability.KnockbackPower);
	local knockbackPos = GetKnockbackPosition(target, fromPos, knockbackPower, true);
	if IsSamePosition(knockbackPos, targetPos) then
		isEnable = false;
		table.insert(reason, {Type = 'AfterPositionNoSpace'});
	end
	
	if not isEnable then
		return 'Disable';
	end
end

function HackingProtocolEnableTest_True(self, target, protocolCls)
	return true;
end
function HackingProtocolEnableTest_ControlTakeover(self, target, protocolCls)
	local ability = protocolCls.Ability;
	if target then
		ability = GetAbilityObject(self, ability.name) or ability;
	end
	if ability.UseCount > 0 then
		return true;
	else
		return false, 'NoMoreMachineControllable';
	end
end
function AbilityProtocolEnableTest_TargetUseable(self, target, protocolCls)
	local ability = protocolCls.Ability;
	if self then
		ability = GetAbilityObject(self, ability.name) or ability;
	end
	return TargetAbilityUseableCheck(self, ability, target) ~= 'Hide';
end
function AbilitySubMenuImageFromAbility(self, arg)
	return self.Ability.Image;
end
function InvestigateLockEnableTest_HasKeyItem(self, target, subCommand)
	local ability = GetAbilityObject(self, subCommand.Ability.name);
	if not ability or ability.UseCount <= 0 then
		return false;
	end
	
	local keyItem = nil;
	local investigationInfo = GetInstantProperty(target, 'InvestigationInfo');
	local lockType = SafeIndex(investigationInfo, 'LockType');
	if lockType then
		local lockTypeCls = GetClassList('LockType')[lockType];
		if lockTypeCls and lockTypeCls.name then
			keyItem = SafeIndex(lockTypeCls, 'KeyItem', 'name');
		end
	end
	local isEnable = false;
	local reason = nil;
	if keyItem then
		local equipItem = GetWithoutError(self, 'Inventory2');
		if equipItem and equipItem.name == keyItem then
			isEnable = true;
			reason = FormatMessageText(GuideMessageText('AbilityToolTip_LockHasKey'), {KeyName = ClassDataText('Item', keyItem, 'Title')});
		end
	end
	return isEnable, reason;
end