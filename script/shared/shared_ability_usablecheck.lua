function TargetAbilityUseableCheck(self, ability, target)
	-- �������� ���ǿ� ���ؼ� ��� ���� �����Ƽ�� �����ü�� �Ұ����� ��� ���⼭ ó��
	local reason = {};
	local able = 'Able';
	
	-- 1) ����ȭ ����(NutralizeBuff) �������� üũ
	for i, neutralizeBuff in ipairs(ability.NeutralizeBuff) do
		if GetBuff(target, neutralizeBuff.name) then
			able = 'Hide';
			table.insert(reason, {Type= 'BlockByNeutralizeBuff', Buff = neutralizeBuff.Title});	-- Ŭ�󿡼��� ������ �� ���״ϱ�
		end
	end
	-- 2) ���� ���� üũ
	for i, immuneRace in ipairs(ability.ImmuneRace) do
		if target.Race.name == immuneRace then
			able = 'Hide';
			table.insert(reason, {Type='BlockByImmuneRace', Race=target.Race});
		end
	end
	-- 3) ��ֹ� üũ
	if (ability.Type == 'Assist' or ability.Type == 'Heal') and (target.name ~= 'Utility_TrapInstance' or (ability.name ~= 'EMPGrenade' and ability.name ~= 'SearchProtocol')) and target.Obstacle then
		able = 'Hide';
		table.insert(reason, {Type='BlockByObstacle', Race=target.name});
	end
	
	if ability.Type == 'Heal' then
		-- 4) �� �����Ƽ�� ���, ����� ������ ��� Able ������ ������ �Ѱ�����.
		if ability.SubType2 == 'HP' then
			if target.HP == target.MaxHP then
				table.insert(reason, {Type='NotUseHealByMaxHP'});
			end
		end	
		-- 5) ��� ȸ�� �����Ƽ�� ���, ����� MaxCost�̸� ��� �Ұ���
		if ability.SubType2 == 'Cost' then
			if target.Cost == target.MaxCost then
				able = 'Hide';
				if target.CostType.name ~= 'None' then
					table.insert(reason, {Type='NotUseCostByMaxCost'});
				end
			end
		end	
		-- 6) SP ȸ�� �����Ƽ�� ���, ����� ���ɷ��� �̰ų� Overcharge ���¸� ��� �Ұ���
		if ability.SubType2 == 'SP' then
			if target.Overcharge > 0 then
				able = 'Hide';
				table.insert(reason, {Type = 'NotUseAlreadyOvercharge'});
			elseif target.ESP.name == nil then
				able = 'Hide';
			end
		end
	end

	-- 7) �����Ƽ Ŀ���͸���¡ �׽�Ʈ
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
	-- �����Ƽ �鿪 ����� ��� ��Ͽ��� �� ������ �Ѵ�.
	for _, info in ipairs(reason) do
		if info.Type == 'BlockByImmuneRace' then
			return 'Hide';
		end
	end
	
	-- ���߿� �ɷ������� ����
	if HasBuff(target, 'Provocation') then
		local curReason = { Type = 'BlockByNeutralizeBuff', Buff = GetClassList('Buff')['Provocation'].Title };	-- Ŭ�󿡼��� ������ �� ���״ϱ�
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
	
	-- ���Ű ���� ����
	if string.find(target.name, 'Mon_Beast_Dragon_Egg') then
		return 'Hide';
	end
	-- ����� �ھ�
	if GetMasteryMastered(GetMastery(target), 'Draky') then
		local beastTypeCls = GetBeastTypeClassFromObject(target);
		if not beastTypeCls or beastTypeCls.EvolutionType.name ~= 'EggStart' or beastTypeCls.EvolutionStage > 1 then
			return 'Hide';
		end
	end	
	
	-- �ִ� �߼� ���� üũ (��ü ���� ���Ѱ� ������ ���� ������ ������, ���� ������ ���� üũ�� ���� ����)
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
	-- �̴ϸʿ� �� ���̸� ����
	if not target.ShowMinimap then
		return 'Hide';
	end
	-- ��ȣ �ۿ��� �����ϸ� ����
	if IsTeamInteractable(GetTeam(self), target, 'Any') then
		return 'Able';
	end
	-- ��ȣ �ۿ��� �Ұ����� Untargetable ������Ʈ�� ����
	if target.Untargetable and target.name ~= 'Utility_TrapInstance' then
		return 'Hide';
	end
	-- ������Ʈ�� �ƴϰ�, ���� �ƴϸ� ���� (�ڱ� �ڽ��� ����. ���� Ÿ���� �����Ƽ�� �ڱ� �ڽŵ� �����ϸ� �����Ƽ�� �� ��...)
	if target.Race.name ~= 'Object' and GetRelation(self, target) ~= 'Enemy' and self ~= target then
		return 'Hide';
	end
end
function TargetAbilityUseableCheck_AssistProtocol(self, ability, target, reason)
	-- ��� ������ �������� Ŀ�ǵ尡 �ϳ��� ������ ��󿡼� ����
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
	-- �ڽ��� ����
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