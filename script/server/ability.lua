-- Precheck Ability Usable
function CheckPass(self, ability)
	return true;
end

function CheckUsableByTurnState(self, ability)
	local moved = self.TurnState.Moved;
	local usedMainAbility = self.TurnState.UsedMainAbility;
	local turnPlayType = ability.TurnPlayType;
	
	if self.TurnState.SpecialChecker ~= 'None' then
		local specialCheckScript = _G[self.TurnState.SpecialChecker];
		if specialCheckScript then
			return specialCheckScript(self, ability);
		end
	end

	if usedMainAbility then
		if self.TurnState.ExtraMovable then
			if ability.name == 'ExtraMove' or (ability.Type == 'StateChange' and turnPlayType == 'Terminate') then
				return true;
			elseif ability.name == 'SecondMove' then
				return false;
			end
		end

		if self.TurnState.ExtraAttackable then
			if (ability.Type == 'Attack' or ability.Type == 'StateChange') and (turnPlayType == 'Main' or turnPlayType == 'Terminate') then
				return true;
			end
		end

		if self.TurnState.ExtraActable then
			if turnPlayType == 'Move' or turnPlayType == 'BeforeMove' then
				return false;
			else
				return true;
			end
		end

		return false;
	end
	
	if turnPlayType == 'AfterMain' then
		return false;
	end	

	if moved and (turnPlayType == 'Move' or turnPlayType == 'BeforeMove') then
		return false;
	end

	if (not moved) and turnPlayType == 'AfterMove' then
		return false;
	end
	
	return true;
end
-- SpecialState
function CheckUsableByTurnState_HavingPrey(self, ability)
	local prey = nil;
	if not (function()
		local havingPrey = GetBuff(self, 'HavingPrey');
		if not havingPrey then
			return false;
		end
		prey = GetUnit(self, havingPrey.ReferenceTarget);
		if not prey then
			return false;
		end
		return true;
	end)() then
		self.TurnState.SpecialChecker = 'None';
		return CheckUsableByTurnState(self, ability);
	end
	
	if IsEnemy(self, prey) then
		return ability.name == 'PreyThrow';
	else
		return ability.name == 'PreyDown';
	end
end
---------------------------------------------------------------------------
-- 리턴방법 설명
-- 사용가능 : "Able"
-- 사용불가능 : "Disable", reason(string, table, number)
-- 숨김 : "Hide"
---------------------------------------------------------------------------
function AbilityUseableCheck(self, ability, usingPosList, ignoreTurnPlayType, ignorePositionLimit, leaveLog)
	--leaveLog = true;
	local usingPos = usingPosList[#usingPosList];
	------------------------- -1. Active 처리 ---------------------
	if not ability.Active then
		local enableNotActive = false;
		if IsProtocolAbility(ability) and HasBuff(self, 'ManagerAuthority') then
			enableNotActive = true;
		end
		if not enableNotActive then	
			if leaveLog then
				LogAndPrint(ability.name, 'Unable by Not Active');
			end
			return 'Hide';
		end
	end
	------------------------- 0. TurnPlayType 처리 ---------------------
	if not ignoreTurnPlayType then
		local isUsable = CheckUsableByTurnState(self, ability);
		if not isUsable then
			if leaveLog then
				LogAndPrint(ability.name, 'Unable by TurnState');
			end
			return 'Hide';
		end
	end
	------------------------- 1. Hide 처리 --------------------------
	local isHidable = CheckHidableAbility(self, ability, usingPos, ignorePositionLimit, leaveLog);
	if isHidable then
		if leaveLog then
			LogAndPrint(ability.name, 'Unable by Hidable');
		end
		return 'Hide';
	end
	------------------------- 2. Disable 처리 --------------------------
	-- 조건 추가할때 Tooltip_Ability 에 내용추가해줘야함 --
	local isDisable = false;
	local reason = {};
	-- 1) 소모성 아이템 스킬 카운트 있으면 보내준다.
	if ability.IsUseCount then
		local freeUseCount = false;
		if IsProtocolAbility(ability) and HasBuff(self, 'ManagerAuthority') then
			freeUseCount = true;
		end
		local curUseCount = { Type = 'UseCount', Value = ability.UseCount};
		if ability.UseCount == 0 and not freeUseCount then
			isDisable = true;
			if leaveLog then
				LogAndPrint(ability.name, 'Unable by UseCount');
			end
			curUseCount.Type = 'UseCountLimit';
		else
			curUseCount.EnableOnlyUseable = true;
		end
		table.insert(reason, curUseCount);
	end
	isDisable = SubAbilityUseableCheck_Cost(self, ability, leaveLog, reason, isDisable);
	isDisable = SubAbilityUseableCheck_Cool(self, ability, leaveLog, reason, isDisable);
	-- 4) 자체 힐 어빌리티 일 경우에 만피인 경우 Able 이지만 이유를 넘겨주자.
	if ability.Target == 'Self' and ability.Type == 'Heal' and ability.SubType2 == 'HP' then
		if self.HP == self.MaxHP then
			local curReason = { Type = 'NotUseHealByMaxHP', Value = ''};
			table.insert(reason, curReason);
		end
	end
	-- 5) 특정 버프가 있어야 하는 어빌리티
	local buffName = GetWithoutError(ability.RequireBuff, 'name');
	if buffName and buffName ~= 'None' then
		local requireBuff = GetBuff(self, buffName);
		if not requireBuff then
			isDisable = true;
			if leaveLog then
				LogAndPrint(ability.name, 'Unable by RequireBuff');
			end
			local curReason = { Type = 'NotRequireBuff', Value = buffName };
			table.insert(reason, curReason);		
		end
	end
	-- 6) 이동 불가능 버프가 있는지 유무
	if IsMoveTypeAbility(ability) then
		local buffMovable = self.Movable;
		if not buffMovable then
			isDisable = true;
			if leaveLog then
				LogAndPrint(ability.name, 'Unable by Immovable');
			end
			local curReason = { Type = 'NotMovable', Value = ''};
			table.insert(reason, curReason);	
		end
	end
	-- 7) 공격 불가능 버프가 있는지 유무
	if ability.Type == 'Attack' then
		local buffAttackable = GetBuffStatus(self, 'Attackable', 'And');
		if not buffAttackable then
			isDisable = true;
			if leaveLog then
				LogAndPrint(ability.name, 'Unable by Not Attackable');
			end
			local curReason = { Type = 'NotAttackable', Value = ''};
			table.insert(reason, curReason);	
		end
	elseif ability.Type == 'Assist' then
		local buffAssistable = GetBuffStatus(self, 'Assistable', 'And');
		if not buffAssistable then
			isDisable = true;
			if leaveLog then
				LogAndPrint(ability.name, 'Unable by Not Assistable');
			end
			table.insert(reason, { Type = 'NotAssistable', Value = '' });
		end
	elseif ability.Type == 'Heal' then
		local buffHealable = GetBuffStatus(self, 'Healable', 'And');
		if not buffHealable then
			isDisable = true;
			if leaveLog then
				LogAndPrint(ability.name, 'Unable by Not Healable');
			end
			table.insert(reason, { Type = 'NotHealable', Value = '' });
		end
	end
	-- 8) 초능력 불가능 버프 체크
	if IsESPType(ability.SubType) then
		local buff_Silence = GetBuff(self, 'Silence');
		if buff_Silence then
			isDisable = true;
			if leaveLog then
				LogAndPrint(ability.name, 'Unable by Not Useable ESP');
			end
			table.insert(reason, { Type = 'NotUseableESP', Value = '' });
		end
	end
	-- 9) 상호작용 어빌리티 테스트
	if ability.Target == 'Interaction' then
		local interactionType = ability.ApplyTargetDetail;
		local interactionCls = GetClassList('Interaction')[interactionType];
		local pass = false;
		local range = CalculateRange(self, ability.TargetRange, GetPosition(self));
		for _, pos in ipairs(range) do
			local obj = GetObjectByPosition(GetMission(self), pos);
			if obj and IsInteractable(self, obj, interactionType) then
				pass = true;
				break;
			end
		end
		if not ignorePositionLimit and not pass then
			if leaveLog then
				LogAndPrint(ability.name, 'Unable by Interaction is not available');
			end
			if interactionCls.AlwaysVisible then
				table.insert(reason, { Type = 'NotUseReport', Value = ''});
				return 'Disable', reason;
			else
				return 'Hide';
			end
		end
	elseif ability.Target == 'InteractionArea' then
		local interactionType = ability.ApplyTargetDetail;
		if not ignorePositionLimit and not IsInteractablePosition(self, GetPosition(self), interactionType) then
			if leaveLog then
				LogAndPrint(ability.name, 'Unable by Interaction is not available');
			end
			return 'Hide';
		end
	end
	-- 10) 어빌리티 커스터마이징 테스트
	if ability.UseableChecker ~= 'None' then
		local checkFunc = _G[ability.UseableChecker];
		if checkFunc then
			local ret = checkFunc(self, ability, usingPos, ignorePositionLimit, reason);
			if ret then
				if ret == 'Hide' and leaveLog then
					LogAndPrint(ability.name, 'Unable by Custom Checker');
				end
				return ret, reason;
			end
		end
	end	
	-- 11) SP 어빌리티
	if ability.SPAbility then
		-- 2) SPFullAbility SP가 MAX가 아니면 숨기자.
		if ability.SPFullAbility then
			if self.SP < self.MaxSP then
				isDisable = true;
				table.insert(reason, {Type = 'SPNotEnough', Value = ''});
			end
		end
	end
	-- 12) 적 근접 시 사용불가능
	if ability.NeedNoNearEnemy and not ignorePositionLimit then
		local hasNearEnemy = table.exist(GetNearObject(self, 1.8), function(o)
			return self ~= o and IsEnemy(self, o);
		end);
		if hasNearEnemy then
			isDisable = true;
			table.insert(reason, {Type = 'NotUseByNearEnemy', Value = ''});
			if leaveLog then
				LogAndPrint(ability.name, 'Unable by NearEnemy', ignorePositionLimit);
			end
		end		
	end
	
	if isDisable then
		if leaveLog then
			LogAndPrint(ability.name, reason);
		end
		return 'Disable', reason;
	end
	------------------------- 3. Able 처리 --------------------------
	------------------------ 4. 위치 사용 가능성 -----------------------
	if usingPos then	-- 실제 사용 위치까지 넘어옴. 이 위치에 써도 되는지 테스트
		-- 1) 돌진형 스킬 사용 후 위치가 비어있는지 테스트
		local afterPosition = CalculateAbilityAfterPosition(self, ability, usingPos);
		local alreadyObj = GetObjectByPosition(GetMission(self), afterPosition);
		if alreadyObj and alreadyObj ~= self then
			if leaveLog then
				LogAndPrint(ability.name, 'Unable by AfterPosition');
			end
			return 'Disable', {}; -- 어차피 서버에서만 쓰고 있으니 이유는 굳이 안채울거임; 클라에서도 쓰게되면 채워넣어야..
		end
		
		-- 2) 타겟형 스킬을 시야에 보이지 않는 대상에게 쓰는지 테스트
		local targetType = ability.Target;
		local inSight = IsInSight(self, usingPos);
		if (targetType == 'Enemy' or targetType == 'Any') and not inSight then
			if leaveLog then
				LogAndPrint(ability.name, 'Unable by None Sight');
			end
			return 'Disable', {};
		end
		
		if targetType ~= 'Ground' and GetClassList('Range')[ability.ApplyRange].Type == 'Dot' then
			-- 타겟형 광역기에 대해서는 나도 모름.. 체크 안해 귀찮아
			local target = GetObjectByPosition(GetMission(self), usingPos);
			if target then
				-- 3) 타겟형 스킬을 은신인 대상에게 쓰는지 테스트
				if target.Cloaking and not IsTeamOrAlly(self, target) then
					if leaveLog then
						LogAndPrint(ability.name, 'Unable by Cloaking Target', GetObjKey(target), target.name);
					end
					return 'Disable', {};
				end
				return TargetAbilityUseableCheck(self, ability, target);
			end
		end
	end
	if leaveLog then
		LogAndPrint(ability.name, 'Able');
	end
	return 'Able', reason;
end
function AbilityUseableCheck_SpinWeb(self, ability, usingPos, ignorePositionLimit, reason)
	local mission = GetMission(self);
	local selfPos = GetPosition(self);
	local isDisable = false;
	
	if not ignorePositionLimit then
		local fieldEffects = GetFieldEffectByPosition(mission, selfPos);
		for _, instance in ipairs(fieldEffects) do
			local type = instance.Owner.name;
			if type == 'Fire' or type == 'Spark' or type == 'PoisonGas' or type == 'Web' then
				isDisable = true;
				break;
			end
		end
	
		local tileType = GetTileType(mission, selfPos);
		if tileType == 'Splash' or tileType == 'Swamp' then
			isDisable = true;
		end
	end
	
	if isDisable then
		table.insert(reason, { Type = 'NotUseOnThisTile', Value = '' });
		return 'Disable';
	end
end
function AbilityUseableCheck_ClimbWeb(self, ability, usingPos, ignorePositionLimit, reason)
	local buffName = GetWithoutError(ability.ApplyTargetBuff, 'name');
	if buffName and buffName ~= 'None' then
		if HasBuff(self, buffName) then
			table.clear(reason);
			return 'Hide';
		end
	end

	local mission = GetMission(self);
	local selfPos = GetPosition(self);
	local isDisable = true;
	
	local fieldEffects = GetFieldEffectByPosition(mission, selfPos);
	for _, instance in ipairs(fieldEffects) do
		local type = instance.Owner.name;
		if type == 'Web' then
			isDisable = false;
			break;
		end
	end

	if isDisable then
		table.insert(reason, { Type = 'NotUseOnThisTile', Value = '' });
		return 'Disable';
	end
end
function AbilityUseableCheck_ClimbWeb_Disable(self, ability, usingPos, ignorePositionLimit, reason)
	local buffName = GetWithoutError(ability.RemoveBuff, 'name');
	if buffName and buffName ~= 'None' then
		if not HasBuff(self, buffName) then
			table.clear(reason);
			return 'Hide';
		end
	end
	
	-- 1) 자리 점유 체크
	local mission = GetMission(self);
	local selfPos = GetPosition(self);
	local alreadyObj = GetObjectByPosition(mission, selfPos);
	if alreadyObj and alreadyObj ~= self then
		table.clear(reason);
		table.insert(reason, { Type = 'NotUseAlreadyObject' });
		return 'Disable';
	end
	
	-- 2) 나머지는 다 무시함
	table.clear(reason);
	return 'Able';
end
function AbilityUseableCheck_FallWeb(self, ability, usingPos, ignorePositionLimit, reason)
	local isDisable = false;
	
	-- 1) 특정 버프가 있어야 하는 어빌리티
	local buffName = GetWithoutError(ability.RequireBuff, 'name');
	if buffName and buffName ~= 'None' then
		local requireBuff = GetBuff(self, buffName);
		if not requireBuff then
			-- 이유는 기본 로직에서 채워짐
			isDisable = true;
		end
	end
	-- 2) SP 어빌리티
	if ability.SPAbility then
		-- 2) SPFullAbility SP가 MAX가 아니면 숨기자.
		if ability.SPFullAbility then
			if self.SP < self.MaxSP then
				isDisable = true;
				table.insert(reason, {Type = 'SPNotEnough', Value = ''});
			end
		end
	end
	if isDisable then
		return 'Disable';
	end
	
	-- 2) 나머지는 다 무시함
	table.clear(reason);
	return 'Able';
end
function SubAbilityUseableCheck_Cost(self, ability, leaveLog, reason, isDisable)
	-- 2) 어빌리티와 사용자의 코스트 양 비교
	if self.Overcharge == 0 and ability.Cost >  self.Cost then
		isDisable = true;
		if leaveLog then
			LogAndPrint(ability.name, 'Unable by Cost');
		end
		local curReason = { Type = 'NotEnoughCost', Value = (ability.Cost - self.Cost)};
		table.insert(reason, curReason);
	end
	return isDisable;
end
function SubAbilityUseableCheck_Cool(self, ability, leaveLog, reason, isDisable)
	-- 3) 어빌리티의 쿨다운 여부
	if ability.Cool >  0  then
		isDisable = true;
		if leaveLog then
			LogAndPrint(ability.name, 'Unable by Cooldown');
		end
		local curReason = { Type = 'NotEnoughCoolTime', Value = ability.Cool};
		table.insert(reason, curReason);
	end
	return isDisable;
end
-- 먹잇감 낚시
function AbilityUseableCheck_PreyFishing(self, ability, usingPos, ignorePositionLimit, reason)
	local requireBuff = GetBuff(self, 'ClimbWeb');
	if not requireBuff then
		return 'Hide';
	end
	
	table.clear(reason);
	-- 먹잇감이 이미 있으면 안됨
	local alreadyBuff = GetBuff(self, 'HavingPrey');
	if alreadyBuff then
		table.insert(reason, {Type = 'AlreadyBuff', Buff = 'HavingPrey'});
		return 'Disable';
	end

	local isDisable = SubAbilityUseableCheck_Cost(self, ability, false, reason, false);
	isDisable = SubAbilityUseableCheck_Cool(self, ability, false, reason, isDisable);

	if isDisable then
		return 'Disable';
	end
	
	return 'Able';
end
-- 먹잇감 내려놓기
function AbilityUseableCheck_HavingPrey(self, ability, usingPos, ignorePositionLimit, reason)	
	-- 먹잇감이 이미 있으면 안됨
	local alreadyBuff = GetBuff(self, 'HavingPrey');
	if not alreadyBuff then
		return 'Hide';
	end
	
	-- 2) 나머지는 다 무시함
	table.clear(reason);
	return 'Able';
end
function AbilityUseableCheck_FullShaking(self, ability, usingPos, ignorePositionLimit, reason)
	local buff_Shaking = GetBuff(self, 'Shaking');
	local masteryTable = GetMastery(self);
	local thresholdLevel = (SafeIndex(GetMasteryMastered(masteryTable, 'Shaking'), 'ApplyAmount') or 4) - 1;
	local mastery_ShakeShake = GetMasteryMastered(GetMastery(self), 'ShakeShake');
	if mastery_ShakeShake then
		thresholdLevel = mastery_ShakeShake.ApplyAmount - 1;
	end
	if buff_Shaking == nil or buff_Shaking.Lv < thresholdLevel then
		return 'Hide';
	end
	table.insert(reason, {Special = true});
end
function AbilityUseableCheck_Shaking(self, ability, usingPos, ignorePositionLimit, reason)
	local buff_Shaking = GetBuff(self, 'Shaking');
	local masteryTable = GetMastery(self);
	local thresholdLevel = (SafeIndex(GetMasteryMastered(masteryTable, 'Shaking'), 'ApplyAmount') or 4) - 1;
	local mastery_ShakeShake = GetMasteryMastered(GetMastery(self), 'ShakeShake');
	if mastery_ShakeShake then
		thresholdLevel = mastery_ShakeShake.ApplyAmount - 1;
	end
	if buff_Shaking and buff_Shaking.Lv >= thresholdLevel then
		return 'Hide';
	end
end
function AbilityUseableCheck_TriggerBuffOn(self, ability, usingPos, ignorePositionLimit, reason)
	local buffName = GetWithoutError(ability.ApplyTargetBuff, 'name');
	if buffName and buffName ~= 'None' then
		if HasBuff(self, buffName) then
			table.clear(reason);
			return 'Hide';
		end
	end
end
function AbilityUseableCheck_TriggerBuffOff(self, ability, usingPos, ignorePositionLimit, reason)
	local buffName = GetWithoutError(ability.RemoveBuff, 'name');
	if buffName and buffName ~= 'None' then
		if not HasBuff(self, buffName) then
			table.clear(reason);
			return 'Hide';
		end
	end
end
function AbilityUseableCheck_TriggerBuffOn2(self, ability, usingPos, ignorePositionLimit, reason)
	for _, key in ipairs({'ApplyTargetBuff', 'ApplyTargetSubBuff'}) do
		local buffName = GetWithoutError(ability[key], 'name');
		if buffName and buffName ~= 'None' then
			if HasBuff(self, buffName) then
				table.clear(reason);
				return 'Hide';
			end
		end
	end
end
function AbilityUseableCheck_SummonMachine(self, ability, usingPos, ignorePositionLimit, reason)
	-- 기계 소환 중
	local summonMachines = GetInstantProperty(self, 'SummonMachines') or {};
	
	-- 소환중인 기계의 수와 보유중인 기계의 수가 같다면
	local summonMachineList = GetSummonMachineList(self);
	if #summonMachineList == #summonMachines then
		local curReason = { Type = 'NotUseByNoMachine', Value = ability.Cool };
		table.insert(reason, curReason);
		return 'Disable';
	end
	
	if ability.IsUseCount and ability.UseCount <= 0 then
		table.clear(reason);
		table.insert(reason, { Type = 'NoMoreMachineControllable' });
		return 'Disable';
	end
end
function AbilityUseableCheck_UnsummonMachine(self, ability, usingPos, ignorePositionLimit, reason)
	if #(GetInstantProperty(self, 'SummonMachines') or {}) == 0 then
		return 'Hide';
	end
end
function AbilityUseableCheck_ControlGiveBack(self, ability, usingPos, ignorePositionLimit, reason)
	if GetBuff(self, 'ControlTakeover') == nil then
		return 'Hide';
	end
end
function AbilityUseableCheck_Tame(self, ability, usingPos, ignorePositionLimit, reason)
	-- 야수 소환 중
	if GetInstantProperty(self, 'SummonBeast') ~= nil then
		return 'Hide';
	end
	-- 최대 야수 개수 체크
	local company = GetCompany_Shared(self);
	if company then
		local summonBeastList = GetSummonBeastList(self);
		if #summonBeastList >= company.MaxBeastCountTotal then
			local curReason = { Type = 'NotUseByMaxBeastCount', Value = company.MaxBeastCountTotal };
			table.insert(reason, curReason);
			return 'Disable';
		end
	end
end
function AbilityUseableCheck_SummonBeast(self, ability, usingPos, ignorePositionLimit, reason)
	-- 야수 소환 중 or 테이밍 중 (테이밍 도중에 어빌리티를 쓸 수 없지만...)
	if GetInstantProperty(self, 'SummonBeast') ~= nil or GetInstantProperty(self, 'TamingTarget') ~= nil then
		return 'Hide';
	end
	-- 야수가 하나도 없으면 (하나라도 있으면 소환이 불가능해도 보여주자)
	local summonBeastList = GetSummonBeastList(self);
	if #summonBeastList == 0 then
		local curReason = { Type = 'NotUseByNoBeast', Value = ability.Cool };
		table.insert(reason, curReason);
		return 'Disable';
	end
end
function AbilityUseableCheck_UnsummonBeast(self, ability, usingPos, ignorePositionLimit, reason)
	if GetInstantProperty(self, 'SummonBeast') == nil then
		return 'Hide';
	end
end
function AbilityUseableCheck_Hidden(self, ability, usingPos, ignorePositionLimit, reason)
	return 'Hide';
end
function AbilityUseableCheck_AlreadyBuff(self, ability, usingPos, ignorePositionLimit, reason)
	local buffName = GetWithoutError(ability.ApplyTargetBuff, 'name');
	if buffName and buffName ~= 'None' then
		if HasBuff(self, buffName) then
			table.insert(reason, { Type = 'AlreadyBuff', Buff = buffName });
			return 'Disable';
		end
	end
end
function AbilityUseableCheck_Deactivate_Light(self, ability, usingPos, ignorePositionLimit, reason)
	local company = GetCompany(self);
	if company and not company.Progress.Tutorial.LightOff then
		table.insert(reason, { Type = 'Guide' });
	end
end
function AbilityUseableCheck_ShowClose(self, ability, usingPos, ignorePositionLimit, reason)
	if self.PerformanceGreatLv <= 0 then
		return 'Hide';
	end
end
function AbilityUseableCheck_BuffImmunityTest(self, ability, usingPos, ignorePositionLimit, reason)
	local immune, reason2 = BuffImmunityTest(ability.ApplyTargetBuff, self);
	if immune then
		table.insert(reason, {Type = 'NotUseByBuffImmuned', Buff = ability.ApplyTargetBuff.name, Reason = reason2});
		return 'Disable';
	end
end
function AbilityUseableCheck_NoTargetHide(self, ability, usingPos, ignorePositionLimit, reason)
	local pass = false;
	local mission = GetMission(self);
	local range = CalculateRange(self, ability.TargetRange, GetPosition(self));
	for _, pos in ipairs(range) do
		local obj = GetObjectByPosition(mission, pos);
		if obj and GetRelation(self, obj) ~= 'Enemy' and HasBuff(obj, ability.RemoveBuff.name) then
			pass = true;
			break;
		end
	end
	if not pass then
		return 'Hide';
	end
end
function AbilityUseableCheck_Conceal(self, ability, usingPos, ignorePositionLimit, reason)
	local alreadyBuff = GetBuff(self, 'Conceal_For_Aura');
	if alreadyBuff then
		table.insert(reason, {Type = 'AlreadyBuff', Buff = 'Conceal_For_Aura'});
		return 'Disable';
	end
end
------------------------------------------------------------------------------------------------------------
---------------------------------------- 숨겨야 하는 스킬 목록 정리 ----------------------------------------
------------------------------------------------------------------------------------------------------------
function CheckHidableAbility(self, ability, usingPos, ignorePositionLimit, leaveLog)
	local mission = GetMission(self);
	-- 1) 엄폐 불가능한 자리면 숨기자.
	if ability.name == 'Conceal' then
		if not self.Coverable then
			return true;
		end
		if ignorePositionLimit then
			return false;
		end		
		local position = GetPosition(self);
		if not IsCoveredPosition(mission, position) then
			return true;
		end
	end
	
	-- 2) SP 어빌리티
	if ability.SPAbility then
		-- 3) SP가 모자라면 숨기자.
		if self.SP < ability.SP then
			return true;
		end
	end
	
	-- 4) 사용횟수 처리. UseCount가 -1인경우 무제한. 0이면 다 쓴거
	if ability.IsUseCount then
		local freeUseCount = false;
		if IsProtocolAbility(ability) and HasBuff(self, 'ManagerAuthority') then
			freeUseCount = true;
		end
		if ability.UseCount == 0 and not ability.IgnoreNoCount and not freeUseCount then
			if leaveLog then
				LogAndPrint('No Use Count', ability.name);
			end
			return true;
		end
	end
	-- 5) 기력 회복
	if ability.name == 'Rest' and self.Cost == self.MaxCost then
		return true;
	end
	return false;
end
---------------------------------------------------------------------------------------------------
-- 어빌리티 사용 함수
---------------------------------------------------------------------------------------------------
function AbilityUseMaster(abilityScp, self, ability, arg, userInfoArgs, targetInfoArgs, resultModifier, detailInfo, perfChecker)
	if perfChecker == nil then
		perfChecker = MockPerfChecker;
	end
	
	perfChecker:StartRoutine('BattleEvents');
	-- 어빌리티 사용 마스터 함수
	-- BattleEvents 처리는 어빌리티 사용 시 1번만 되어야 한다. (AbilityPrevMaster로 옮겨야겠지만, 임시 패치가 필요해서 인덱스로 처리함)
	if targetInfoArgs.ChainID == 1 then
		local battleEvents = SafeIndex(resultModifier, 'BattleEvents') or {};
		for i, eventInfo in ipairs(battleEvents) do
			AddBattleEvent(eventInfo.Object, eventInfo.EventType, eventInfo.Args);
		end
	end
	
	perfChecker:StartRoutine(abilityScp);
	perfChecker:Dive();
	local applies = {_G[abilityScp](self, ability, arg, userInfoArgs, targetInfoArgs, resultModifier, detailInfo, nil, perfChecker)};
	perfChecker:Rise();
	-- 쿨다운 갱신 이번턴이 종료 될 때에도 쿨이 1 줄어드니까 1 더한 값으로
	-- 어빌리티 쿨은 0이 최하 값.
	
	perfChecker:StartRoutine('RestoreMaxCost');
	-- 기력 완전 회복
	if ability.RestoreMaxCost and GetIdspace(arg) == 'Object' then
		local retCost, reasons = AddActionCost(applies, arg, arg.MaxCost, true, false);
		targetInfoArgs.ShowDamage = arg.MaxCost;
		targetInfoArgs.MainDamage = arg.Cost - retCost; -- 기력 회복은 연출은 마이너스 수치로
		if arg.Cost < arg.MaxCost then
			AddBattleEvent(arg, 'AddCost', { CostType = arg.CostType.name, Count = arg.MaxCost - arg.Cost });
		end
		ReasonToAddBattleEventMulti(arg, reasons, 'Ending');
	end	
	
	return unpack(applies);
end

function ResetExtraTurnState(applies, self)
	if self.TurnState.ExtraMovable then
		table.insert(applies, Result_PropertyUpdated('TurnState/ExtraMovable', false, self));
	end
	if self.TurnState.ExtraAttackable then
		table.insert(applies, Result_PropertyUpdated('TurnState/ExtraAttackable', false, self));
	end
	if self.TurnState.ExtraActable then
		table.insert(applies, Result_PropertyUpdated('TurnState/ExtraActable', false, self));
	end	
end

function GetInitializeTurnActions(self, noStable)
	local applies = {};

	if not noStable then
		table.insert(applies, Result_PropertyUpdated('TurnState/Stable', true, self));
	end
	table.insert(applies, Result_PropertyUpdated('TurnState/Moved', false, self));
	table.insert(applies, Result_PropertyUpdated('TurnState/UsedMainAbility', false, self));
	table.insert(applies, Result_PropertyUpdated('TurnState/TurnEnded', false, self, true));
	
	ResetExtraTurnState(applies, self);

	return unpack(applies);
end

function TurnPlayProcessor_Move(self, ability, userInfoArgs, applies)
	if userInfoArgs == nil then
		table.insert(applies, Result_PropertyUpdated('TurnState/UsedMainAbility', true, self, true));
		return;
	end
	
	if not userInfoArgs.IsDash then
		table.insert(applies, Result_PropertyUpdated('TurnState/Moved', true, self, true));
	else
		table.insert(applies, Result_PropertyUpdated('TurnState/Moved', true, self, true));
		table.insert(applies, Result_PropertyUpdated('TurnState/UsedMainAbility', true, self, true));
	end
end

function GetTurnPlayActions(self, ability, turnPlayType, userInfoArgs)
	if userInfoArgs and userInfoArgs.name == nil then
		userInfoArgs = nil;
	end
	
	if (turnPlayType ~= 'Free' and turnPlayType ~= 'Terminate') and GetBuff(self, 'ChangingMind') then
		return Result_RemoveBuff(self, 'ChangingMind');
	end
	
	local applies = {};
	if self.TurnState.Stable and turnPlayType ~= 'Free' then
		table.insert(applies, Result_PropertyUpdated('TurnState/Stable', false, self, false));
	end
	
	if ability.CustomTurnPlayProcessor then
		ability.CustomTurnPlayProcessor(self, ability, userInfoArgs, applies);
	else
		-- TrunPlayType에 의한 기본 턴 상태 변경. 클라이언트의 스테이터스를 갱신한다.
		if turnPlayType == 'Move' then
			table.insert(applies, Result_PropertyUpdated('TurnState/Moved', true, self, true));
		elseif turnPlayType == 'Main' or turnPlayType == 'AfterMove' or turnPlayType == 'Terminate' then
			table.insert(applies, Result_PropertyUpdated('TurnState/UsedMainAbility', true, self, true));
		elseif turnPlayType == 'Half' then
			if self.TurnState.Moved then
				table.insert(applies, Result_PropertyUpdated('TurnState/UsedMainAbility', true, self, true));
			else
				table.insert(applies, Result_PropertyUpdated('TurnState/Moved', true, self, true));
			end
		end
	end
	
	-- 추가 행동의 초기화. 클라이언트의 스테이터스를 따로 갱신하지 않는다. (추가 행동을 했거나, 턴을 종료시키는 어빌리티를 썼거나) 
	if (turnPlayType ~= 'Free' and self.TurnState.UsedMainAbility) or turnPlayType == 'Terminate' then
		ResetExtraTurnState(applies, self);
	end
	
	return unpack(applies);
end

function GetAbilityConsumeCost(self, ability)
	local consumeCost = ability.Cost;
	
	-- 특성 기적
	local masteryTable = GetMastery(self);
	local mastery_Miracle = GetMasteryMastered(masteryTable, 'Miracle');
	if mastery_Miracle and ability.Type == 'Assist' then
		if GetInstantProperty(self, 'Miracle') then
			consumeCost = 0;
		end
	end
	
	return consumeCost;
end

function AbilityPrevMaster(self, ability, isFreeAction, userInfoArgs, subPositions, detailInfo)
	local applies = {};
	if not isFreeAction then
		if not (self.Overcharge > 0 and ability.Type ~= 'Interaction') then
			if not ability.SPAbility then
				-- 어빌리티 코스트 소모
				local consumeCost = GetAbilityConsumeCost(self, ability);
				if consumeCost ~= 0 then
					SetInstantProperty(self, 'InstantCost', consumeCost);
					table.insert(applies, Result_ConsumeCost(self, consumeCost));
				end
			else
				-- 어빌리티 SP 소모
				SetInstantProperty(self, 'InstantSP', ability.SP);
				AddSPPropertyActions(applies, self, self.ESP.name, -1 * ability.SP, true, nil);
			end
		end
		if ability.SPFullAbility then
			-- SP 전부 소모
			SetInstantProperty(self, 'InstantSP', self.SP);
			AddSPPropertyActions(applies, self, self.ESP.name, -1 * self.SP, true, nil);
		end
		
		-- 쿨다운
		local coolTime = ability.CoolTime + 1;
		UpdateAbilityPropertyActions(applies, self, ability.name, 'Cool', math.max(coolTime, 0));
	end
	
	if ability.AbilityWithMove then
		SetInstantProperty(self, 'MovingForAbility', nil);
		userInfoArgs.DirectPrepare = GetInstantProperty(self, 'DirectPrepare') == true;
		SetInstantProperty(self, 'DirectPrepare', nil);
	end
	
	if ability.Relocator ~= 'None' then
		SetInstantProperty(self, 'BeforePos', GetPosition(self));
	else
		SetInstantProperty(self, 'BeforePos', nil);
	end
	
	if GetBuffStatus(self, 'ReverseRelation', 'Or') then
		SetInstantProperty(self, 'ReverseRelation_PrevLoseIFF', ObjectLoseIFF(self));
		SetObjectLoseIFF(self, true);
	end
	
	if IsCommandAbilityProtocolAbility(ability) then
		if SafeIndex(detailInfo, 'ProtocolDetail') ~= nil then
			local protocolCls = GetClassList(ability.AbilitySubMenu)[detailInfo.ProtocolDetail];
			local commandAbility = GetAbilityObject(self, protocolCls.Ability.name) or protocolCls.Ability;
			-- 현재 사용할 커맨드 어빌리티의 Type, SubType으로 교체한다.
			ability.Type = commandAbility.Type;
			ability.SubType = commandAbility.SubType;
		end
		table.insert(applies, Result_DirectingScript(function(mid, ds, args)
			local abilityCls = GetClassList('Ability')[ability.name];
			ability.Type = abilityCls.Type;
			ability.SubType = abilityCls.SubType;
		end, nil, true, true));
	end
	
	return unpack(applies);
end

function ApplyKnockbackAction(applies, self, target, ability, targetInfo, knockbackPos, prevKnockbackPos, inverse)
	--LogAndPrint('ApplyKnockbackAction', knockbackPos, prevKnockbackPos);
	if IsSamePosition(knockbackPos, prevKnockbackPos) then
		if ability.Type == 'Attack' then
			AddBattleEvent(target, 'BigTextCustomEvent', {Text = WordText('ChainEvent_KnockbackStunOccured'), Font = 'NotoSansBlack-28', AnimKey = 'KnockbackStun',Color = 'FFFF5943', EventType = 'FinalHit'});
			InsertBuffActions(applies, self, target, 'Stun', 1, true, nil, true, {Type = 'Knockback'});
			table.insert(applies, Result_FireWorldEvent('ChainEffectOccured', {Unit = target, Trigger = self, ChainType = 'Crash'}))
		end
	else
		-- Slide 액션 추가
		local slideAction = Result_Slide(target, knockbackPos, {Type = 'Ability', Value = ability.name, Unit = self});
		table.insert(applies, slideAction);
		
		-- targetInfo 갱신
		targetInfo.SlideType = 'Knockback';
		targetInfo.AfterPosition = knockbackPos;
		targetInfo.KnockbackSpeed = ability.KnockbackSpeed;
		targetInfo.KnockbackInverse = inverse;
		
		-- 다음 넉백 대상 계산 시에 반영되도록 일단 위치를 바로 바꿔준다
		SetPosition(target, knockbackPos);
		
		if table.exist(GetFieldEffectByPosition(self, prevKnockbackPos), function(fe) return fe.Owner.name == 'Swamp' or fe.Owner.name == 'SwampBush'; end) then
			AddBattleEvent(target, 'BigTextCustomEvent', {Text = WordText('ChainEvent_MudCaked'), Font = 'NotoSansBlack-28', AnimKey = 'KnockbackStun',Color = 'FFFF5943', EventType = 'FinalHit'});
			InsertBuffActions(applies, self, target, 'Slow', 1);
			table.insert(applies, Result_FireWorldEvent('ChainEffectOccured', {Unit = target, Trigger = self, ChainType = 'MudCaked'}));
		end
		if targetInfo.KnockbackPower >= 3 and table.exist(GetFieldEffectByPosition(self, prevKnockbackPos), function(fe) return fe.Owner.name == 'Ice'; end) then
			AddBattleEvent(target, 'BigTextCustomEvent', {Text = WordText('ChainEvent_Slip'), Font = 'NotoSansBlack-28', AnimKey = 'KnockbackStun',Color = 'FFFF5943', EventType = 'FinalHit'});
			InsertBuffActions(applies, self, target, 'Slow', 1);
			table.insert(applies, Result_FireWorldEvent('ChainEffectOccured', {Unit = target, Trigger = self, ChainType = 'Slip'}));
		end
	end
end

function FindIfInTargets(primaryTargetInfoArgs, secondaryTargetInfoArgs, ifFunc)
	if table.findif(primaryTargetInfoArgs, ifFunc) then
		return true;
	end
	if table.findif(secondaryTargetInfoArgs, ifFunc) then
		return true;
	end		
	return false;
end

-- 타겟 리스트에서 조건에 맞는 것이 있는지 찾는 함수
function ForeachIfInTargets(primaryTargetInfoArgs, secondaryTargetInfoArgs, ifFunc, doFunc)
	table.foreach(primaryTargetInfoArgs, function(k, v)
		if ifFunc(v) then
			doFunc(v);
		end
	end);
	table.foreach(secondaryTargetInfoArgs, function(k, v)
		if ifFunc(v) then
			doFunc(v);
		end
	end);
end	

function AbilityPostMaster(self, ability, isFreeAction, userInfoArgs, primaryTargetInfoArgs, secondaryTargetInfoArgs, perfChecker)
	if perfChecker == nil then
		perfChecker = MockPerfChecker;
	end
	local applies = {};
	perfChecker:StartRoutine('Begin');
	userInfoArgs.InstantSP = GetInstantProperty(self, 'InstantSP') or 0;
	userInfoArgs.InstantCost = GetInstantProperty(self, 'InstantCost') or 0;
	
	SetInstantProperty(self, 'InstantSP', 0);
	SetInstantProperty(self, 'InstantCost', 0);
	local masteryTable = GetMastery(self);
	
	-- -1. 턴 플레이 변경
	perfChecker:StartRoutine('TurnPlayUpdate');
	if not isFreeAction then
		local turnPlayActions = { GetTurnPlayActions(self, ability, ability.TurnPlayType, userInfoArgs) };
		for _, action in ipairs(turnPlayActions) do
			table.insert(applies, action);
		end
	end
	
	local knockbackTargets = {};
		
	local fromPos = GetPosition(self);
	if ability.KnockbackBasePos == 'UsingPos' then
		fromPos = PositionPropertyToTable(userInfoArgs.UsingPos);
	elseif ability.KnockbackBasePos == 'BeforePos' then
		fromPos = GetInstantProperty(self, 'BeforePos') or fromPos;
	end
	
	local highestAddCost = 0;
	
	perfChecker:StartRoutine('ProcessPerTargetInfo');
	-- 피격 대상별 처리
	for _, targetInfos in ipairs { primaryTargetInfoArgs, secondaryTargetInfoArgs } do
		for _, targetInfo in ipairs(targetInfos) do
		
			-- 0. 넉백 처리. 넉백 대상들을 필요한 정보들만 가지고 추출
			if targetInfo.KnockbackPower > 0 then
				local knockbackInfo = {};
				knockbackInfo.targetInfo = targetInfo;
				knockbackInfo.currentPos = GetPosition(targetInfo.Target);
				knockbackInfo.distance = GetDistance3D(fromPos, knockbackInfo.currentPos);
				
				local targetKey = GetObjKey(targetInfo.Target);
				knockbackTargets[targetKey] = knockbackInfo;
			end
			
			-- 1. 분노 획득
			if self.CostType.name == 'Rage' then
				if targetInfo.MainDamage > 0 then
					if targetInfo.IsDead then
						highestAddCost = math.max(highestAddCost, math.floor(math.max(1, self.RegenRage * 2)) );
					elseif targetInfo.DefenderState == 'Block' then
						highestAddCost = math.max(highestAddCost, math.floor(math.max(1, self.RegenRage * 0.5)));
					elseif targetInfo.AttackerState == 'Critical' then
						highestAddCost = math.max(highestAddCost, math.floor(math.max(1, self.RegenRage * 1.5)));
					else
						highestAddCost = math.max(highestAddCost, math.floor(math.max(1, self.RegenRage * 1)));
					end
				end
			end
			
			if IsMissionServer() then
				-- 2. AI Session처리
				if targetInfo.Target.name ~= nil and IsEnemy(targetInfo.Target, self) then
					local aiSession = GetAISession(GetMission(targetInfo.Target), GetTeam(targetInfo.Target));
					aiSession:AddTemporalSightObject(self);
				end
			end
		end
	end
		
		
	perfChecker:StartRoutine('ProcessKnockback');
	-- 0. 넉백 처리
	do
		local knockbackTargetList = {};
		for _, knockbackInfo in pairs(knockbackTargets) do
			table.insert(knockbackTargetList, knockbackInfo);
		end
	
		local inverse = ability.KnockbackInverse;
		if not inverse then
			-- 거리가 먼 쪽부터 접근되도록 정렬
			table.sort(knockbackTargetList, function (a,b) return a.distance > b.distance end);
		else
			-- 거리가 가까운 쪽부터 접근되도록 정렬
			table.sort(knockbackTargetList, function (a,b) return a.distance < b.distance end);
		end
		
		-- 넉백 계산 시에 사용자의 어빌리티 사용 후 위치를 반영시킨다.
		local selfPos = GetPosition(self);
		local afterPos = CalculateAbilityAfterPosition(self, ability, userInfoArgs.UsingPos);
		
		-- 거리가 먼 대상부터 넉백에 의한 위치 변경을 반영시키면서 넉백 위치를 계산한다.
		for i, knockbackInfo in ipairs(knockbackTargetList) do
			local targetInfo = knockbackInfo.targetInfo;
			local target = targetInfo.Target;
			
			local knockbackPower = targetInfo.KnockbackPower;
			if inverse then
				local targetPos = GetPosition(target);
				local targetDist = GetDistance2D(targetPos, fromPos);
				knockbackPower = math.min(math.floor(targetDist), knockbackPower);
			end
			local knockbackPos = GetKnockbackPosition(target, fromPos, knockbackPower, inverse);
			if target ~= self and knockbackPos and afterPos and IsSamePosition(knockbackPos, afterPos) then
				-- afterPos는 어빌리티 사용자가 도착할 위치이므로, 다른 오브젝트가 그 위치로 넉백이 되면 안 된다.
				SetPosition(self, afterPos);
				knockbackPos = GetKnockbackPosition(target, fromPos, targetInfo.KnockbackPower);
			end
			
			ApplyKnockbackAction(applies, self, target, ability, targetInfo, knockbackPos, knockbackInfo.currentPos, inverse);
		end
		
		-- 모든 넉백 대상들을 원래 위치로 되돌려준다.
		for i, knockbackInfo in ipairs(knockbackTargetList) do
			local targetInfo = knockbackInfo.targetInfo;
			local target = targetInfo.Target;
		
			SetPosition(target, knockbackInfo.currentPos);
		end
		
		-- 사용자의 위치도 되돌려준다.
		if afterPos then
			SetPosition(self, selfPos);
		end
	end
	
	perfChecker:StartRoutine('SomethingBlabla');
	-- 1. 분노 획득
	if highestAddCost > 0 then
		local retCost, reasons = AddActionCost(applies, self, highestAddCost, true);
		local realAddValue = retCost - self.Cost;
		if realAddValue ~= 0 then
			AddBattleEvent(self, 'AddCost', { CostType = self.CostType.name, Count = realAddValue});
		end
		ReasonToAddBattleEventMulti(self, reasons, 'Ending');
	end
	
	-- 1.5. 어빌리티에 등록된 버프 지워주기.
	if ability.RemoveBuffType == 'Self' then
		local remove_BuffName = GetWithoutError(ability.RemoveBuff, 'name');
		if remove_BuffName and remove_BuffName ~= 'None' then
			InsertBuffActions(applies, self, self, remove_BuffName, -1 * ability.RemoveBuff:MaxStack(self), false, nil, true);
		end	
	end
	
	-- 2. FieldEffect 추가
	if IsMissionServer() and GetWithoutError(ability.ApplyFieldEffects, 'Fake') == nil then
		for i, v in ipairs(ability.ApplyFieldEffects) do
			local method = v.Method;
			local fieldEffect = GetClassList('FieldEffect')[v.Type];
			local applyRange = v.Range;
			local applyNumMin = v.NumMin;
			local applyNumMax = v.NumMax;
			local applyProb = v.Prob;
			local applyPos = v.ApplyPos;
			
			local positionList = {};
			
			if applyPos == nil or applyPos == 'UsingPos' then
				local usingPos = PositionPropertyToTable(userInfoArgs.UsingPos);
				positionList = CalculateRange(self, applyRange, usingPos);
			elseif applyPos == 'TargetPos' then
				for _, info in ipairs(primaryTargetInfoArgs) do
					local targetPos = GetPosition(info.Target);
					local subPosList = CalculateRange(self, applyRange, targetPos);
					for _, pos in ipairs(subPosList) do
						table.insert(positionList, pos);
					end
				end
				for _, info in ipairs(secondaryTargetInfoArgs) do
					local targetPos = GetPosition(info.Target);
					local subPosList = CalculateRange(self, applyRange, targetPos);
					for _, pos in ipairs(subPosList) do
						table.insert(positionList, pos);
					end
				end
			end

			local mission = GetMission(self);
			positionList = table.filter(positionList, function(pos)
				local validPos = GetValidPosition(mission, pos);
				if not validPos then
					return false;
				end
				if method == 'Add' and not fieldEffect:IsEffectivePosition(validPos, mission) then
					return false;
				end
				return true;
			end);
			
			if applyNumMin ~= 0 or applyNumMax ~= 0 then
				local applyNum = math.random(applyNumMin, applyNumMax);
				local shuffled = table.shuffle(positionList);
				
				positionList = {};
				for i = 1, math.min(applyNum, #shuffled) do
					table.insert(positionList, shuffled[i]);
				end
			end
			
			if applyProb then
				positionList = table.filter(positionList, function(pos) return RandomTest(applyProb); end);
			end
		
			if #positionList > 0 then
				local action = nil;
				if method == 'Add' then
					action = Result_AddFieldEffect(fieldEffect.name, positionList, self, 'Ability');
				elseif method == 'Remove' then
					action = Result_RemoveFieldEffect(fieldEffect.name, positionList, self, 'Ability');
				end
				
				if action then
					action.sequential = true;
					table.insert(applies, action);
				end
			end
		end
	end
	
	-- 3. CastDelay 적용
	if ability.CastDelay and ability.CastDelay ~= 0 then
		if ability.CastDelay > 0 then
			InsertBuffActions(applies, self, self, 'Delay', ability.CastDelay, true, nil, true);
		else
			InsertBuffActions(applies, self, self, 'Haste', -ability.CastDelay, true, nil, true);
		end
	end
	
	-- 6. 쿨다운 리셋
	if ability.CoolReset then
		local abilityList = GetAllAbility(self, false, true);
		for index, curAbility in ipairs (abilityList) do
			if not ability.CoolResetCheck or ability:CoolResetCheck(self, curAbility) then
				if curAbility.name ~= ability.name and curAbility.Cool > 0 then
					UpdateAbilityPropertyActions(applies, self, curAbility.name, 'Cool', 0);
				end
			end
		end
	end
	
	-- 9. 사용 횟수
	local freeUseCount = false;
	if IsProtocolAbility(ability) then
		local buff_ManagerAuthority = GetBuff(self, 'ManagerAuthority');
		if buff_ManagerAuthority and BuffIsActivated(buff_ManagerAuthority) then
			freeUseCount = true;
		end
	end
	if ability.IsUseCount and ability.UseCount > 0 and ability.AutoUseCount and not freeUseCount then
		UpdateAbilityPropertyActions(applies, self, ability.name, 'UseCount', ability.UseCount - 1);
	end	
	
	-- 10. 버프 '치고 빠지기'
	if not self.TurnState.TurnEnded then		-- 턴중에만 발동
		local buff_HitAndRun = GetBuff(self, 'HitAndRun');
		if buff_HitAndRun and ability.Type == 'Attack' then
			table.insert(applies, Result_PropertyUpdated('TurnState/ExtraMovable', true, self));
			table.insert(applies, Result_RemoveBuff(self, 'HitAndRun'));
			AddMasteryInvokedEvent(self, 'HitAndRun', 'Ending');
			-- 특성 완벽주의자 (연출만)
			local mastery_Perfectionist = GetMasteryMastered(masteryTable, 'Perfectionist');
			if mastery_Perfectionist then
				AddMasteryInvokedEvent(self, mastery_Perfectionist.name, 'Ending');
			end
		end
	end
		
	-- 11. 버프 '연쇄 사격'
	if not self.TurnState.TurnEnded then		-- 턴중에만 발동
		local buff_SerialShot = GetBuff(self, 'SerialShot');
		if buff_SerialShot and ability.Type == 'Attack' then
			table.insert(applies, Result_PropertyUpdated('TurnState/ExtraAttackable', true, self));
			table.insert(applies, Result_RemoveBuff(self, 'SerialShot'));
			AddBattleEvent(self, 'SerialShot');
		end
	end
	
	-- 타겟 리스트에서 조건에 맞는 것이 있는지 찾는 함수

	perfChecker:StartRoutine('CustomizedProcess');
	-- 12. 버프 '피범벅'
	if not self.TurnState.TurnEnded then		-- 턴중에만 발동
		local buff_Bloodbath = GetBuff(self, 'Bloodbath');
		if buff_Bloodbath then
			local isDead = FindIfInTargets(primaryTargetInfoArgs, secondaryTargetInfoArgs, function (targetInfo)
				return targetInfo.IsDead;
			end);
			if isDead then
				table.insert(applies, Result_PropertyUpdated('TurnState/ExtraActable', true, self));
				table.insert(applies, Result_FireWorldEvent('ActionPointRestored', {Unit = self}, self));
				AddBattleEvent(self, 'Bloodbath');
			end
		end
	end
	
	-- 13. 어빌리티 HPDrain 처리
	if ability.Type == 'Attack' and ability.HPDrainRatio > 0 then
		local totalDamage = 0;
		-- 대상 데미지 총합
		ForeachIfInTargets(primaryTargetInfoArgs, secondaryTargetInfoArgs, function (targetInfo)
			local raceName = SafeIndex(targetInfo.Target, 'Race', 'name');				
			return (raceName == 'Human' or raceName == 'Beast') and targetInfo.MainDamage > 0 and targetInfo.DefenderState ~= 'Dodge';
		end, function (targetInfo)
			totalDamage = totalDamage + targetInfo.MainDamage;
		end);
		local addHP = math.floor(totalDamage * ability.HPDrainRatio / 100);
		if addHP > 0 then
			local damage = -addHP;
			local nextHP = math.min(self.HP + addHP, self.MaxHP);
			AddBattleEvent(self, 'DirectDamageByType', { DirectDamageType = ability.HPDrainType.name, Damage = damage, NextHP = nextHP, IsDead = false });
			table.insert(applies, Result_Damage(damage, 'Normal', 'Hit', self, self, 'Ability', ability.SubType, ability));
		end
	end
	
	-- 15. 마스터리 'XX 쐐기'
	local remainHPMap = {};
	local boltMasteryList = {
		{ Mastery = 'FireBolt', DirectType = 'FireBolt', DamageType = 'Fire' },
		{ Mastery = 'IceBolt', DirectType = 'IceBolt', DamageType = 'Ice' },
		{ Mastery = 'LightningBolt', DirectType = 'LightningBolt', DamageType = 'Lightning' }
	};
	for _, info in ipairs(boltMasteryList) do
		local mastery = GetMasteryMastered(masteryTable, info.Mastery);
		if mastery and ability.Type == 'Attack' and not ability.ItemAbility then
			local targetInfoMap = {};
			-- 타겟별 마지막 피격 찾기
			ForeachIfInTargets(primaryTargetInfoArgs, secondaryTargetInfoArgs, function (targetInfo)
				return IsEnemy(self, targetInfo.Target) and targetInfo.MainDamage > 0 and targetInfo.DefenderState ~= 'Dodge';
			end, function (targetInfo)
				local target = targetInfo.Target;
				local targetKey = GetObjKey(target);
				if targetInfo.RemainHP > 0 then
					targetInfoMap[targetKey] = targetInfo;
				else
					targetInfoMap[targetKey] = nil;
				end
			end);
			-- 데미지 처리
			for _, targetInfo in pairs(targetInfoMap) do
				local target = targetInfo.Target;
				local targetKey = GetObjKey(target);
				local remainHP = remainHPMap[targetKey];
				if not remainHP then
					remainHP = targetInfo.RemainHP;
				end
				local damageBase = mastery.ApplyAmount;
				local damageMultiplier = 100;
				if mastery.name == 'FireBolt' then
					local mastery_BigFlame = GetMasteryMastered(masteryTable, 'BigFlame');
					if mastery_BigFlame then
						damageBase = damageBase + mastery_BigFlame.ApplyAmount;
					end
					local mastery_FlameBolt = GetMasteryMastered(masteryTable, 'FlameBolt');
					if mastery_FlameBolt and HasBuffType(target, nil, nil, mastery_FlameBolt.BuffGroup.name) then
						damageMultiplier = damageMultiplier + mastery_FlameBolt.ApplyAmount;
					end
				end
				local damage = damageBase * damageMultiplier / 100;
				local prevDamage = targetInfo.RemainHP - remainHP;
				local realDamage, reasons = ApplyDamageTest(targetInfo.Target, damage + prevDamage, 'Ability') - prevDamage;
				local nextHP = math.max(remainHP - realDamage, 0);
				local isDead = false;
				if nextHP <= 0 then
					isDead = true;
				end
				ReasonToAddBattleEventMulti(target, reasons, 'FirstHit');
				AddBattleEvent(target, 'DirectDamageByType', { DirectDamageType = info.DirectType, Damage = damage, NextHP = nextHP, IsDead = isDead });
				table.insert(applies, Result_FireWorldEvent('BoltInvoked', {Mastery=info.Mastery, Unit=self, Target=target, Damage=realDamage}, self));
				local damageAction = Result_Damage(damage, 'Normal', 'Hit', self, target, 'Mastery', info.DamageType, mastery);
				damageAction.Flag = { [mastery.name] = true };
				table.insert(applies, damageAction);
				remainHPMap[targetKey] = nextHP;
			end
		end
	end

	-- 16. AbilitlyPrevPosition 초기화
	SetInstantProperty(self, 'AbilityPrevPosition', nil);
	
	-- 17. 어그로 증가처리
	perfChecker:StartRoutine('RaiseHate');
	if IsMissionServer() and ability.HateAmount ~= 0 and ability.Type ~= 'Move' then
		RaiseHate(self, ability);
	end
	
	perfChecker:StartRoutine('AbilityPostProcess');
	-- 18. 어빌리티 별 후처리
	if IsMissionServer() and ability.PostScript ~= 'None' then
		local postScp = _G[ability.PostScript];
		if postScp then
			table.append(applies, { postScp(self, ability, isFreeAction, userInfoArgs, primaryTargetInfoArgs, secondaryTargetInfoArgs) });
		end
	end
	
	-- 19. 특성 깜짝 공연
	-- 깜짝 공연
	local mastery_SurprisingStage = GetMasteryMastered(masteryTable, 'SurprisingStage');
	if mastery_SurprisingStage and ability.Type == 'Attack' then
		local applyTargets = {};
		-- 기습 적용 대상 찾기
		ForeachIfInTargets(primaryTargetInfoArgs, secondaryTargetInfoArgs, function (targetInfo)
			local target = targetInfo.Target;
			return IsEnemy(self, target) and (target.PreBattleState or HasBuffType(target, nil, nil, mastery_SurprisingStage.BuffGroup.name));
		end, function (targetInfo)
			local target = targetInfo.Target;
			applyTargets[GetObjKey(target)] = target;
		end);
		-- 각 대상 주위의 적에게 버프 걸기
		local subTargets = {};
		local applyDist = mastery_SurprisingStage.ApplyAmount;
		for _, target in pairs(applyTargets) do
			local targetObjects = Linq.new(GetNearObject(target, applyDist + 0.4))
				:where(function(o) return IsEnemy(self, o) end)
				:toList();
			for _, subTarget in ipairs(targetObjects) do
				subTargets[GetObjKey(subTarget)] = subTarget;
			end
		end
		if not table.empty(subTargets) then
			AddMasteryInvokedEvent(self, mastery_SurprisingStage.name, 'Ending');
		end
		for _, target in pairs(subTargets) do
			InsertBuffActions(applies, self, target, mastery_SurprisingStage.SubBuff.name, 1, true);
		end
	end
	
	-- 인식 방해
	if GetBuffStatus(self, 'ReverseRelation', 'Or') then
		SetObjectLoseIFF(self, GetInstantProperty(self, 'ReverseRelation_PrevLoseIFF'));
		SetInstantProperty(self, 'ReverseRelation_PrevLoseIFF', nil);
	end
	
	perfChecker:StartRoutine('BattleStatistics');
	-- 20. 전투 통계
	local objStatMap = {};
	-- 20-1. 유틸리티 함수
	local AddStat = function(obj, statName, value)
		local objStat = objStatMap[obj];
		if objStat == nil then
			objStat = {};
			objStatMap[obj] = objStat;
		end
		objStat[statName] = (objStat[statName] or 0) + value;
	end;
	local ForeachTargetInfos = function(doFunc)
		for _, targetInfos in ipairs { primaryTargetInfoArgs, secondaryTargetInfoArgs } do
			for _, targetInfo in ipairs(targetInfos) do
				doFunc(targetInfo.Target, targetInfo)
			end
		end
	end	
	-- 20-2. 통계 수집
	if ability.Type == 'Attack' then
		ForeachTargetInfos(function(target, targetInfo)
			AddStat(self, 'Attack', 1);
			AddStat(target, 'Defence', 1);
			if targetInfo.DefenderState ~= 'Dodge' then
				AddStat(self, 'AttackDamage', targetInfo.MainDamage);
				AddStat(target, 'DefenceDamage', targetInfo.MainDamage);
				AddStat(self, 'AttackHit', 1);
				if targetInfo.AttackerState == 'Critical' then
					AddStat(self, 'AttackCritical', 1);
				end
				if targetInfo.DefenderState == 'Block' then
					AddStat(target, 'DefenceBlock', 1);
				end
			else
				AddStat(target, 'DefenceDodge', 1);
			end
		end);
	elseif ability.Type == 'Heal' then
		ForeachTargetInfos(function(target, targetInfo)
			if targetInfo.DefenderState == 'Heal' then
				AddStat(self, 'Heal', -1 * targetInfo.MainDamage);
			end
		end);
	end	
	-- 20-3. 통계 반영
	for obj, objStat in pairs(objStatMap) do
		for k, v in pairs(objStat) do
			AddUnitStats(obj, k, v);
		end
	end	

	return unpack(applies);
end
-- Ability Result Helper
function Result_Damage(damage, attackerState, defenderState, user, target, damageType, damageSubType, damageInvoker, noReward, damageBlocked)
	return {type='Damage', damage=damage, AttackerState=attackerState, DefenderState=defenderState, user=user, target=target, damage_type = damageType or 'Etc', damage_sub_type = damageSubType or 'Etc', damage_invoker = damageInvoker, no_reward = noReward or false, DamageBlocked = damageBlocked or 0};
end
function Result_Move(pos, user, maxDist, priorDist, moveInvoker)
	return {type='Move', pos_list={pos}, user=user, max_dist = maxDist or 0, prior_dist = priorDist or 0, move_invoker = moveInvoker};
end
function Result_MoveList(posList, user, maxDist, priorDist, moveInvoker)
	return {type='Move', pos_list=posList, user=user, max_dist = maxDist or 0, prior_dist = priorDist or 0, move_invoker=moveInvoker};
end
function Result_RemoveBuff(obj, buffName, sequential)
	return {type='RemoveBuff', target = obj, buff_name=buffName, sequential = sequential or false};
end
function Result_PropertyUpdated(propType, value, target, updateStatus, sequential)
	return {type='PropertyUpdated', property_key=propType, property_value=tostring(value), target=target, update_status = updateStatus or false, sequential = sequential or false};
end
function Result_PropertyAdded(propType, value, target, minLimit, maxLimit, updateStatus, sequential)
	return {type='PropertyAdded', property_key=propType, property_value=value, target=target, update_status = updateStatus or false, sequential = sequential or false, min_limit = minLimit, max_limit = maxLimit};
end
function Result_BuffPropertyUpdated(propType, value, target, buffName, updateStatus, sequential, invalidateOwner, invalidate)
	return {type='BuffPropertyUpdated', property_key=propType, property_value=value, target=target, buff_name = buffName, update_status = updateStatus or false, sequential = sequential or false, invalidate_owner = invalidateOwner, invalidate = invalidate};
end
function Result_AbilityPropertyUpdated(propType, value, target, abilityName, sequential)
	return {type = 'AbilityPropertyUpdated', property_key=propType, property_value=value, target=target, ability_name=abilityName, sequential=sequential};
end
function Result_UpdateDashboard(dashboardKey, dashboardProp)
	return {type='UpdateDashboard', dashboard_key=dashboardKey, dashboard_type=dashboardProp.name, dashboard_prop=dashboardProp, sequential = true};
end
function Result_UseAbility(user, abilityType, pos, resultModifier, noUseCheck, directingConfig, subAction, noTeamCheck, noUseSkip)	-- user에 nil이 오면 상황에 따른 기본 인자를 따라갈 것임
	return {
		type='UseAbility',
		user=user,
		ability_name=abilityType,
		pos_list={pos},
		free_action = false,
		result_modifier=resultModifier,
		no_use_check = noUseCheck or false,
		directing_config = directingConfig or {},
		sub_action = subAction or false,
		no_team_check = noTeamCheck or false,
		no_use_skip = noUseSkip or false
	};
end
function Result_UseAbilityTarget(user, abilityType, target, resultModifier, noUseCheck, directingConfig, deadPosition)
	return {type='UseAbilityTarget', user=user, target=target, ability_name=abilityType, free_action = false, result_modifier=resultModifier, no_use_check = noUseCheck or false, directing_config = directingConfig or {}};
end
function Result_ConsumeCost(user, cost)
	return {type='ConsumeCost', user=user, cost=cost};
end
function Result_AddBuff(giver, obj, buffName, buffLevel, modifier, sequential, isAbilityBuff, noHide, invoker)
	return {type='AddBuff', user=giver, target = obj, buff_name = buffName, buff_level = buffLevel, modifier=modifier, sequential = sequential or false, ability_buff = isAbilityBuff or false, no_hide = noHide or false, invoker = invoker};
end
function Result_TurnEnd(obj, updateBuffCooldown)
	return {type='TurnEnd', user = obj, update_buff_cooldown = updateBuffCooldown};
end
function Result_AddExp(target, exp, jobExp, reason)
	reason = reason or 'MonsterKill';
	return {type='AddExp', target=target, exp=exp, job_exp = jobExp, reason=reason, exp_limit = GetUnitExpLimit(target)};
end
function Result_GiveItem(user, itemType, amount, itemProps, giveItemArgs)
	return {type='GiveItem', user=user, item_type=itemType, amount = amount, item_properties = itemProps, give_item_args = giveItemArgs};
end
function Result_DirectingScript(script, args, sequential, reserve)
	return {type='DirectingScript', script=script, args = args, sequential = sequential, reserve = reserve};
end
function Result_Slide(user, pos, moveInvoker)
	return {type='Slide', user=user, pos=pos, move_invoker = moveInvoker};
end
function Result_SetPosition(user, pos, mute, rejectFunc, dir)
	return {type='SetPosition', user=user, pos=pos, mute=mute, reject_func=rejectFunc, dir = dir};
end
function Result_ChangeTileEnterable(from, to, enterable)
	return {type='ChangeTileEnterable', mode='Area', pos=from, pos2=to, enterable=enterable, sequential = true};
end
function Result_ChangeTileEnterableList(posList, enterable)
	return {type='ChangeTileEnterable', mode='List', pos_list = posList, enterable = enterable, sequential = true};
end
function Result_ChangeTileLink(from, to, link, visible, throwing)
	return {type='ChangeTileLink', mode='Area', pos=from, pos2=to, link=link, visible=visible, throwing=throwing, sequential = true};
end
function Result_ChangeTileLinkList(posList, link, visible, throwing)
	return {type='ChangeTileLink', mode='List', pos_list = posList, link=link, visible=visible, throwing=throwing, sequential = true};
end
function Result_CreateObject(objKey, objName, pos, team, initScp, initScpArgs, aiType, aiArg, noAsync, dir)
	local action = {}

	action.type = 'CreateObject';
	action.object_key = objKey;
	action.object_name = objName;
	action.pos = pos;
	action.pos2 = dir;
	action.team = team;
	action.init_scp = initScp;
	action.init_scp_args = initScpArgs;
	if aiType ~= nil then
		action.ai = aiType;
		action.aiargs = aiArg;
	else
		action.ai = '';
	end
	action.no_async = noAsync;

	return action;
end
function Result_CreateMonster(objKey, monType, pos, team, initScp, initScpArgs, aiType, aiArg, noAsync, dir)
	local ret = Result_CreateObject(objKey, nil, pos, team, initScp, initScpArgs, aiType, aiArg, noAsync, dir);
	ret.monster_type = monType;
	ret.type = 'CreateMonster';
	return ret;
end
function Result_DestroyObject(target, invokeDeadEvent, sequential)
	if invokeDeadEvent == nil then
		invokeDeadEvent = true;
	end
	return {type='DestroyObject', target=target, event = invokeDeadEvent, sequential = sequential};
end
function Result_UpdateStageVariable(variableKey, value, method)
	return {type='UpdateStageVariable', variable_key=variableKey, value=value, method = method or 'Update'};
end
function Result_SightSharing(target, team, visible, sequential)
	return {type='SightSharing', target=target, team = team, visible=visible, sequential = sequential};
end
function Result_SightSharingCustom(target, team, visible, range, sequential)
	return {type='SightSharingCustom', target=target, team = team, visible=visible, range = range, sequential = sequential};
end
function Result_ActionDelimiter()
	return {type='ActionDelimiter'};
end
function Result_EndMission(team)
	return {type='EndMission', winner=team, sequential = true};
end
function Result_Resurrect(target, mode, resetSP, invoker)
	if resetSP == nil then
		resetSP = true;
	end
	return  {type='Resurrect', target=target, sequential = true, mode = mode, reset_sp = resetSP, invoker = invoker};
end
function Result_ChangeTeam(user, team, temporary)
	return {type='ChangeTeam', user = user, team=team, sequential = true, temporary = temporary};
end
function Result_ChangeCoverInfo(user, coverInfo)
	return {type='ChangeCoverInfo', user = user, cover_info = coverInfo, sequential = true};
end
function Result_Interaction(user, target, interactionType, ability)
	return {type='Interaction', user=user, target=target, interaction_type=interactionType, ability = ability};
end
function Result_UpdateInteraction(target, interactionType, enable)
	return {type='UpdateInteraction', target=target, interaction_type=interactionType, enable=enable};
end
function Result_InteractionArea(user, pos, interactionType, ability)
	return {type='InteractionArea', user=user, pos=pos, interaction_type = interactionType, ability = ability};
end
function Result_EnableInteractionArea(key, from, to, interactionType, assetKey)
	return {type='EnableInteractionArea', key = key, pos = from, pos2 = to, interaction_type = interactionType, asset_key = assetKey};
end
function Result_DisableInteractionArea(key)
	return {type='DisableInteractionArea', key = key}
end
function Result_FireWorldEvent(eventType, eventArg, target, reserved)
	return {type='FireWorldEvent', event_type=eventType, fire_target=target, args=eventArg, reserved=reserved};
end
function Result_AddFieldEffect(fieldEffectType, positionList, giver, invokeType)
	return {type='AddFieldEffect', field_effect_type = fieldEffectType, position_list = positionList, user = giver, invoke_type = invokeType};
end
function Result_RemoveFieldEffect(fieldEffectType, positionList, giver, invokeType)
	return {type='RemoveFieldEffect', field_effect_type = fieldEffectType, position_list = positionList, user = giver, invoke_type = invokeType};
end
function Result_ClearFieldEffect(fieldEffectType)
	return {type='ClearFieldEffect', field_effect_type = fieldEffectType};
end
function Result_GiveItemByItemIndicator(target, itemIndicator, conditionOutput)
	if itemIndicator == nil then
		return;
	end
	if itemIndicator.Type == 'Simple' then
		if itemIndicator.Count <= 0 or itemIndicator.ItemType == 'None' then
			return;
		end
		
		return Result_GiveItem(target, itemIndicator.ItemType, itemIndicator.Count);
	elseif itemIndicator.Type == 'ConditionOuput' then
		return conditionOutput[itemIndicator.Key];
	else
		-- 미구현
		return;
	end
end
function Result_UpdateMastery(target, mastery, level)
	return {type='UpdateMastery', target=target, mastery=mastery, level=level};
end
function Result_ToggleTrigger(triggerName, enable, isGroup)
	return {type='ToggleTrigger', trigger_target=triggerName, enable=enable, is_group=isGroup};
end
function Result_UpdateUserMember(target, team, enable)
	return {type='UpdateUserMember', target=target, team=team, enable=enable};
end
function Result_GiveAbility(target, abilityType)
	return {type='GiveAbility', target=target, ability_name=abilityType};
end
function Result_EquipItem(target, itemType, itemProperties, equipPos)
	return {type='EquipItem', target=target, item_type=itemType, item_properties = itemProperties, equip_pos = equipPos};
end
function Result_UnEquipItem(target, itemType, equipPos)
	return {type='UnEquipItem', target=target, item_type=itemType, equip_pos = equipPos};
end
function Result_ClearDyingObjects()
	return {type='ClearDyingObjects'};
end
function Result_ClearDyingObject(target)
	return {type='ClearDyingObject', target = target};
end
function Result_BuffGiverChanged(giver, obj, buffName)
	return {type='BuffGiverChanged', user=giver, target=obj, buff_name=buffName};
end
function Result_TimeElapsed(elapsedTime, nextTurnPlayTeam)
	return {type="TimeElapsed", elapsed_time=elapsedTime, next_turn_play_team=(nextTurnPlayTeam or 'player')};
end
function Result_UpdateInstantProperty(target, key, value, sequential)
	return {type='UpdateInstantProperty', target=target, property_key=key, property_value=value, sequential = sequential};
end
function Result_ChangeObjectKey(target, objKey)
	return {type='ChangeObjectKey', target=target, object_key=objKey, sequential=true};
end
function Result_StopMove(target)
	return {type='StopMove', target=target};
end
function Result_SynchronizeAbility(target, abilityName)
	return {type='SynchronizeAbility', target=target, ability_name=abilityName};
end
function Result_InvalidateObject(target)
	return {type='InvalidateObject', target=target};
end

function GetMaxPriotyBuff(obj, buffGroup)
	local priority = 0;
	local buffList = GetBuffList(obj);
	local buff = nil;
	for i = 1, #buffList do
		local curBuff = buffList[i];
		if curBuff.Group == buffGroup then
			if curBuff.GroupPriority > priority then
				priority = curBuff.GroupPriority;
				buff = curBuff;
			end
		end
	end
	return buff;
end
function Direct_BuffLifeAddedByGroup(mid, ds, args)
	local owner = args.Owner;
	local objKey = GetObjKey(owner);

	local chainID = ds:PlayUIEffect(objKey, '', 'BigText', 0, 0, PackTableToString({Text = WordText('ChainEvent_BuffGroup'), Font = 'NotoSansBlack-22', AnimKey = 'BuffGroup', Color = 'FFA335EE'}));
	ds:SetCommandLayer(chainID, game.DirectingCommand.CM_SECONDARY);
	ds:SetContinueOnNormalEmpty(chainID);
	
	local battleEventID = ds:UpdateBattleEvent(objKey, 'BuffRemainTurn_Added', { Buff = args.BuffName, Remain = args.LifeAdded });
	ds:SetCommandLayer(battleEventID, game.DirectingCommand.CM_SECONDARY);
	ds:SetContinueOnNormalEmpty(battleEventID);
end
function InsertBuffActions(actions, giver, obj, buffName, buffLevel, sequential, modifier, isAbilityBuff, invoker, isDead)
	if buffName == nil then
		return;
	end
	local buffList = GetClassList('Buff');
	local curBuffName = SafeIndex(buffList, buffName, 'name');
	if not curBuffName then
		return;
	end
	
	local curBuffLv = 0;
	local curBuff = GetBuff(obj, buffName);
	-- 1. 현재 버프레벨 정하기	
	if curBuff then
		curBuffLv = curBuff.Lv;
	else
		curBuffLv = 0;
		curBuff = buffList[buffName];
	end
	
	-- 2. 감산할 버프레벨 정하기
	local addBuffLv = 1;
	if buffLevel then
		addBuffLv = buffLevel;
	end	
	
	-- 죽는 녀석은 새로 버프가 걸리지 않을 뿐만 아니라, 일반 버프들은 다 죽으면 사라지니까 Group에 따른 처리는 생략한다.
	-- 생략 안하면 하위 버프는 사라지고 상위 버프는 안 걸린 상태로, 각종 이벤트 핸들러에서 버프 체크를 해버림
	if curBuff.Group ~= 'None' and curBuff.Type == 'Debuff' and not isDead then
		local groupBuffList = GetBuffType(obj, 'Debuff', nil, curBuff.Group);
		local groupPriority = curBuff.GroupPriority;
		local lowerBuffList = table.filter(groupBuffList, function (buff) return buff.GroupPriority < groupPriority end);
		if #lowerBuffList > 0 then
			for _, lowerBuff in ipairs(lowerBuffList) do
				table.insert(actions, Result_RemoveBuff(obj, lowerBuff.name, sequential));
			end
		end
		local higherBuffList = table.filter(groupBuffList, function (buff) return buff.GroupPriority > groupPriority end);
		if #higherBuffList > 0 then
			for _, higherBuff in ipairs(higherBuffList) do
				local addLife = higherBuff.Turn - higherBuff.Life;
				if addLife > 0 then
					table.insert(actions, Result_BuffPropertyUpdated('Life', higherBuff.Turn, obj, higherBuff.name, true, sequential));
					table.insert(actions, Result_BuffGiverChanged(giver, obj, higherBuff.name));
					table.insert(actions, Result_DirectingScript('Direct_BuffLifeAddedByGroup', {Owner = obj, GroupName = curBuff.Group, BuffName = higherBuff.name, LifeAdded = addLife}));
					table.insert(actions, Result_FireWorldEvent('BuffLifeAddedByGroup', {Unit = obj, GroupName = curBuff.Group, BuffName = higherBuff.name, BuffGiver = giver}, nil, true));
					table.insert(actions, Result_FireWorldEvent('ChainEffectOccured', {Trigger = giver, Unit = obj, ChainType = 'BuffEscalate'}));
				end
			end
			-- 우선순위가 더 높은 버프가 있으면, 자기 자신은 안 걸린다. (혹시나 이미 걸려있으면 지워주자)
			if curBuffLv > 0 then
				table.insert(actions, Result_RemoveBuff(obj, curBuff.name, sequential));
			end
			return;
		end
	end
	
	if curBuff.Stack then
		local maxStack = curBuff:MaxStack(obj);
		
		-- 2.5. 현재 버프레벨 보정
		for _, action in ipairs(actions) do
			if action.buff_name == buffName and action.target == obj then
				if action.type == 'AddBuff' then
					curBuffLv = action.buff_level;
				elseif action.type == 'RemoveBuff' then
					curBuffLv = 0;
				elseif action.type == 'BuffPropertyUpdated' and action.property_key == 'Lv' then
					curBuffLv = action.property_value;
				end
			end
		end
	
		-- 3. 최종 버프레벨 정하기
		local totalLv = curBuffLv + addBuffLv;	
		if totalLv > maxStack then
			totalLv = maxStack;
		end

		if totalLv <= 0 then
			if curBuffLv > 0 then 
				table.insert(actions, Result_RemoveBuff(obj, buffName, sequential));
			end
		else
			if curBuffLv == 0 then
				table.insert(actions, Result_AddBuff(giver, obj, buffName, totalLv, modifier, sequential, isAbilityBuff, nil, invoker));
			elseif curBuffLv > 0 then
				table.insert(actions, Result_BuffPropertyUpdated('Lv', totalLv, obj, buffName, false, sequential, true, true));
				table.insert(actions, Result_BuffPropertyUpdated('Life', curBuff.Turn, obj, buffName, true, sequential));
				table.insert(actions, Result_BuffGiverChanged(giver, obj, buffName));
			end
		end
	else
		local totalLv = addBuffLv;
		if totalLv > 0 then
			table.insert(actions, Result_AddBuff(giver, obj, buffName, totalLv, modifier, sequential, isAbilityBuff, nil, invoker));
		elseif totalLv <= 0 and curBuffLv > 0 then	
			table.insert(actions, Result_RemoveBuff(obj, buffName, sequential));
		end
	end
end
function InsertBuffActionsMultiGiver(actions, giver, obj, buffName, add, sequential, modifier, isAbilityBuff, invoker)
	local b = GetBuff(obj, buffName);
	local giverKey = GetObjKey(giver);
	local givers = {};
	local addBuffLevel = add and 1 or -1;
	if b then
		givers = b.Givers;
		if givers[giverKey] then
			if add then
				return;
			else
				givers[giverKey] = nil;
			end
		else
			if not add then
				return;
			else
				givers[giverKey] = true;
			end
		end
	elseif not add then
		return;
	else
		givers = {[GetObjKey(giver)] = true};
	end
	
	InsertBuffActions(actions, giver, obj, buffName, addBuffLevel, seqential, modifier, isAbilityBuff, invoker);
	if next(givers) == nil then
		-- givers table이 비었다는건 버프가 레벨 0이 되어 빠진다는 의미
		return;
	end
	table.insert(actions, Result_BuffPropertyUpdated('Givers', givers, obj, buffName, false, sequential));
end
function InsertBuffActionsModifier(actions, giver, obj, buffName, buffLevel, turn, sequential, modifier, isAbilityBuff, invoker, isDead)
	-- 위 기능은 매우 제한적인 상황에 대한 처리를 수행하기 위한 유틸용 함수이다. 작업상의 편의를 위해서 이 기능을 이용하는 버프에 대하여는 다음과 같은 조건을 가정한다.
	--  적용되는 버프는 무조건 Not Stackable.
	--  적용되는 버프의 레벨은 무조건 1이다. 정확히는 입력된 값을 그대로 반영할 뿐 기존 버프의 레벨과 현 버프의 레벨차에 따른 오류는 신경쓰지 않는다.
	
	-- 아래의 상황에 대해서 처리할 필요가 있다.
	-- 요구되는 액션이 1. 유한 버프 추가 / 2. 무한 버프 추가 / 3. 유한 버프 제거 / 4. 무한 버프 제거
	-- 기존 버프가 A. 없음 / B. 유한 상태 / C. 무한 상태
	
	local prevBuff = GetBuff(obj, buffName);
	--LogAndPrint('InsertBuffActionsModifier', buffName, buffLevel, turn);
	
	-- (3. 유한 버프제거 / 4. 무한 버프제거) & (A. 기존 버프 없음)
	-- 이 경우는 아무일도 없음.
	if prevBuff == nil and buffLevel < 0 then
		return;
	end
	
	-- (A. 기존 버프 없음)
	-- 기존 버프가 없다면 그냥 Turn Modifier만 잘 적용해서 처리한다.
	if prevBuff == nil then	
		InsertBuffActions(actions, giver, obj, buffName, buffLevel, sequential, modifier, isAbilityBuff, invoker, isDead);
		table.insert(actions, Result_BuffPropertyUpdated('Life', turn, obj, buffName, false, sequential));
		table.insert(actions, Result_BuffPropertyUpdated('Turn', turn, obj, buffName, false, sequential));
		if turn < 1000 then
			table.insert(actions, Result_BuffPropertyUpdated('LifeSpan', turn, obj, buffName, false, sequential));
		end
		table.insert(actions, Result_BuffPropertyUpdated('IsTurnShow', turn < 1000, obj, buffName, true, sequential));
		return;
	end
	
	local thisMortal = turn < 1000;
	local prevMortal = prevBuff.Life < 1000;
	
	if buffLevel > 0 then
		-- (1. 유한 버프 추가) & (B. 기존 버프 유한)
		-- 유한 상태에 유한 상태를 갱신하는것도 그냥 TurnModifier만 잘 적용해서 처리한다.
		if thisMortal and prevMortal then
			InsertBuffActions(actions, giver, obj, buffName, buffLevel, sequential, modifier, isAbilityBuff, invoker, isDead);
			table.insert(actions, Result_BuffPropertyUpdated('Life', turn, obj, buffName, false, sequential));
			table.insert(actions, Result_BuffPropertyUpdated('Turn', turn, obj, buffName, false, sequential));
			table.insert(actions, Result_BuffPropertyUpdated('LifeSpan', turn, obj, buffName, false, sequential));
			table.insert(actions, Result_BuffPropertyUpdated('IsTurnShow', turn < 1000, obj, buffName, true, sequential));
			return;		
		end
	
		-- (1. 유한 버프 추가) & (C. 기존 버프 무한)
		-- 기존 버프가 무한 상태라면 유한 Turn값을 Age + turn으로 갱신해주고 추가적인 처리를 진행하지 않는다.
		if thisMortal and not prevMortal then
			table.insert(actions, Result_BuffPropertyUpdated('LifeSpan', prevBuff.Age + turn, obj, buffName, false, sequential));
			table.insert(actions, Result_BuffPropertyUpdated('Turn', turn, obj, buffName, true, sequential));
			return;
		end
		
		-- (2. 무한 버프 추가) & (B. 기존 버프 유한)
		-- 버프의 라이프를 무한으로 변경해주면 끝.
		if not thisMortal and prevMortal then
			table.insert(actions, Result_BuffPropertyUpdated('Life', turn, obj, buffName, false, sequential));
			table.insert(actions, Result_BuffPropertyUpdated('IsTurnShow', turn < 1000, obj, buffName, true, sequential));
			return;
		end
		
		-- (2. 무한 버프 추가) & (C. 기존 버프 무한)
		-- 굳이 별 작업을 안해도 상관없겠지만 갱신용으로 쓸 수도 있으니 새로 걸어주자. 대신 유한 버프 정보에 해당하는 Turn값은 다시 갱신해줘야함.
		if not thisMortal and not prevMortal then
			InsertBuffActions(actions, giver, obj, buffName, buffLevel, sequential, modifier, isAbilityBuff, invoker, isDead);
			table.insert(actions, Result_BuffPropertyUpdated('Life', turn, obj, buffName, false, sequential));
			table.insert(actions, Result_BuffPropertyUpdated('LifeSpan', prevBuff.LifeSpan, obj, buffName, false, sequential));
			table.insert(actions, Result_BuffPropertyUpdated('Turn', prevBuff.LifeSpan, obj, buffName, false, sequential));
			table.insert(actions, Result_BuffPropertyUpdated('IsTurnShow', turn < 1000, obj, buffName, true, sequential));
			return;
		end
	else
		-- (3. 유한 버프 제거) & (B. 기존 버프 유한)
		-- 그냥 지우면됨
		if thisMortal and prevMortal then
			InsertBuffActions(actions, giver, obj, buffName, buffLevel, sequential, modifier, isAbilityBuff, invoker, isDead);
			return;
		end
		-- (3. 유한 버프 제거) & (C. 기존 버프 무한)
		-- 유한 정보를 제거하고 버프 자체는 그대로 둠.
		if thisMortal and not prevMortal then
			table.insert(actions, Result_BuffPropertyUpdated('LifeSpan', 0, obj, buffName, true, sequential));
			return;
		end
		-- (4. 무한 버프 제거) & (B. 기존 버프 유한)
		-- 이런 상황은 에러... 기존 버프가 유한한데 무한 버프를 지우겠다고?.. 그냥 무시
		if not thisMortal and prevMortal then
			return;
		end
		-- (4. 무한 버프 제거) & (C. 기존 버프 무한)
		-- 유한 정보가 있다면 유한 버프로 돌리고 없다면 버프 제거 (정상처리)
		if not thisMortal and not prevMortal then
			local remainLife = prevBuff.LifeSpan - prevBuff.Age;
			if remainLife > 0 then
				table.insert(actions, Result_BuffPropertyUpdated('Life', remainLife, obj, buffName, false, sequential));
				table.insert(actions, Result_BuffPropertyUpdated('IsTurnShow', true, obj, buffName, true, sequential));
				return;
			else
				InsertBuffActions(actions, giver, obj, buffName, buffLevel, sequential, modifier, isAbilityBuff, invoker, isDead);
				return;
			end
		end
	end
	-- 이곳에는 도달하면 안됨..
	LogAndPrint('InsertBuffActionsModifier', 'ErrorState', buffName, buffLevel, turn, prevMortal, thisMortal);
end
function ABL_EXPLOSION(self, ability, target, userInfoArgs, targetInfoArgs)
	local damReturn = Result_Damage(400, 'Normal', 'Hit', self, target, 'Ability');
	return damReturn;
end
------------------------------------------------------------------------------------------------------
--- Ability
--------------------------------------------------------------------------------------------------------
function ABL_ATTACK(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo, _, perfChecker)
	if perfChecker == nil then
		perfChecker = MockPerfChecker;
	end
	perfChecker:StartRoutine('Battle');
	local abilityActions = {};
	local subActions = {};
	local phase = targetInfoArgs.name == 'PrimaryTargetInfo' and 'Primary' or 'Secondary';
	
	local usingPos = {x = userInfoArgs.UsingPos.x, y = userInfoArgs.UsingPos.y, z = userInfoArgs.UsingPos.z};
	
	perfChecker:Dive();
	local damage, attackerState, defenderState, knockbackPower, damageBlocked, buffApplied, damageFlag = Battle(self, target, ability, subActions, phase, resultModifier, usingPos, targetInfoArgs.ChainID, detailInfo, perfChecker);
	perfChecker:Rise();
	
	perfChecker:StartRoutine('Etc');
	-- 넉백 처리
	if knockbackPower > 0 and target.Base_Movable and defenderState ~= 'Dodge' and (damage <= 0 or GetBuff(target, 'StarShield') == nil) then
		targetInfoArgs.KnockbackPower = knockbackPower;
	end
	-- 어빌리티의 버프 걸렸는지 유무
	if buffApplied then
		targetInfoArgs.BuffApplied = true;
	end
	
	if SafeIndex(detailInfo, 'SnipeType') then
		targetInfoArgs.SnipeType = detailInfo.SnipeType;
	end
	
	-- 피해량 계산
	local damReturn = Result_Damage(damage, attackerState, defenderState, self, target, 'Ability', ability.SubType, ability, resultModifier and resultModifier.NoReward or nil, damageBlocked);
	damReturn.Flag = damageFlag;
	table.insert(abilityActions, damReturn);
	-- 2. 서브 액션 적용.
	-- 전투 공식 내에서 해야 되었던 일들 정리.
	for index, value in ipairs (subActions) do
		table.insert(abilityActions, value);
	end
	-- 어빌리티에 등록된 버프 지워주기.
	if ability.RemoveBuffType == 'Target' then
		local remove_BuffName = GetWithoutError(ability.RemoveBuff, 'name');
		if remove_BuffName and remove_BuffName ~= 'None' then
			InsertBuffActions(abilityActions, self, target, remove_BuffName, -1 * ability.RemoveBuff:MaxStack(target), false, nil, true);
		end
	end
	-- 현재 결과 오브젝트에 기록하기.
	if defenderState == 'Dodge' then
		self.SuccessHitCount = 0;
		target.SuccessDodgeCount = target.SuccessDodgeCount + 1;
	else
		self.SuccessHitCount = self.SuccessHitCount + 1;
		target.SuccessDodgeCount = 0;
	end	
	return unpack(abilityActions);
end
-----------------------------------------------------------------------------------
-- Heal
-------------------------------------------------------------------------------------
function ABL_HEAL(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier)
	-- ABL_ATTACK에 통합됨. 정확히는 애초에 ABL_ATTACK과 다른 처리가 없었다 (...)
	return ABL_ATTACK(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier);
end
-----------------------------------------------------------------------------------
-- Cost
-------------------------------------------------------------------------------------
function ABL_COST(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier)
	local actions = {};
	
	local applyCost = GetAbilityApplyCost(ability, self, target);
	local nextCost = math.clamp(target.Cost + applyCost, 0, target.MaxCost);
	local realApplyCost = nextCost - target.Cost;
	
	local retCost, reasons = AddActionCost(actions, target, realApplyCost, nil, false);
	AddBattleEvent(target, 'AddCost', { CostType = target.CostType.name, Count = realApplyCost });
	ReasonToAddBattleEventMulti(target, reasons, 'Ending');
	
	return unpack(actions);
end
-----------------------------------------------------------------------------------
-- BUFF
-------------------------------------------------------------------------------------
function ABL_BUFF(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo, customHitRate)
	local abilityActions = {};
	
	local weather = 'Clear';
	local missionTime = 'Day';
	local temperature = 'Normal';
	if IsMissionServer() then
		local mission = GetMission(self);
		weather = mission.Weather.name;
		missionTime = mission.MissionTime.name;
		temperature = mission.Temperature.name;
	end
	
	local usingPos = table.map(userInfoArgs.UsingPos, function(v) return v; end);
	local hitRate = customHitRate == nil and ability.GetHitRateCalculator(self, target, ability, usingPos, weather, missionTime, temperature) or customHitRate;
	if RandomTest(hitRate) then
		for _, buffTarget in ipairs({'Buff', 'SubBuff'}) do
			local buff = GetWithoutError(ability, 'ApplyTarget' .. buffTarget);
			local addLv = GetWithoutError(ability, 'ApplyTarget' .. buffTarget .. 'Lv');
			local turn = GetWithoutError(ability, 'ApplyTarget' .. buffTarget .. 'Duration');
			if buff and buff.name ~= nil then
				if buff.Stack and not ability['IsAddTarget' .. buffTarget] then
					local curBuffLv = 0;
					local curBuff = GetBuff(target, buff.name);
					if curBuff then
						curBuffLv = curBuff.Lv;
					end
					addLv = addLv - curBuffLv;
				end
				if turn and turn > 0 then
					InsertBuffActionsModifier(abilityActions, self, target, buff.name, addLv, turn, true, nil, true);
				else
					InsertBuffActions(abilityActions, self, target, buff.name, addLv, true, nil, true);
				end
			end
		end
		-- 어빌리티의 버프 걸렸는지 유무
		targetInfoArgs.BuffApplied = true;
		-- ApplyAct 적용
		if ability.ApplyAct ~= 0 then
			local added, reasons = AddActionApplyAct(abilityActions, self, target, ability.ApplyAct, ability.ApplyAct > 0 and 'Hostile' or 'Friendly');
			if added then
				AddBattleEvent(target, 'AddWait', { Time = ability.ApplyAct });
			end
			ReasonToAddBattleEventMulti(target, reasons, 'FirstHit');
		end
	else
		local cancel_BuffName = GetWithoutError(ability.CancelTargetBuff, 'name');
		if cancel_BuffName then
			local buff = ability.CancelTargetBuff;
			local addLv = ability.CancelTargetBuffLv;
			InsertBuffActions(abilityActions, self, target, buff.name, addLv, true, nil, true);
		end
	end

	-- 어빌리티에 등록된 버프 지워주기.
	if ability.RemoveBuffType == 'Target' then
		local remove_BuffName = GetWithoutError(ability.RemoveBuff, 'name');
		if remove_BuffName and remove_BuffName ~= 'None' then
			InsertBuffActions(abilityActions, self, target, remove_BuffName, -1 * ability.RemoveBuff:MaxStack(target), false, nil, true);
		end
	end

	return unpack(abilityActions);
end
function ABL_FLOW(self, ability, target, userInfoArgs, targetInfoArgs)
	local usingPos = {x = userInfoArgs.UsingPos.x, y = userInfoArgs.UsingPos.y, z = userInfoArgs.UsingPos.z};
	local watchingRange = CalculateRange(self, ability.GuideRange, usingPos);
	SetInstantProperty(self, 'FlowWatchingArea', watchingRange);
	return ABL_BUFF(self, ability, target, userInfoArgs, targetInfoArgs);
end
-----------------------------------------------------------------------------------
-- ABL_BUFFCOPY RequireBuff의 상태를 대상에게 복사합니다. 
-- RequireBuff -> ApplyTargetBuff 레벨 이전 / RemoveBuff 기존 버프 지우냐 마냐
-------------------------------------------------------------------------------------
function ABL_BUFFCOPY(self, ability, target, userInfoArgs, targetInfoArgs)
	local abilityActions = {};
	local buff = GetBuff(self, ability.RequireBuff.name);
	if buff then
		InsertBuffActions(abilityActions, self, target, ability.ApplyTargetBuff.name, buff.Lv, false, nil, true);
	end	
	return unpack(abilityActions);
end
-----------------------------------------------------------------------------------
-- ABL_MENTALBREAK
-------------------------------------------------------------------------------------
function ABL_MENTALBREAK(self, ability, target, userInfoArgs, targetInfoArgs)
	local abilityActions = {};
	
	local resultBuff = { 'Confusion', 'Fear'};
	local buff = ability.ApplyTargetBuff;
	local chance = 50;
	local buff_Confusion = GetBuff(target, 'Confusion');
	local buff_Fear = GetBuff(target, 'Fear');
	
	local buff = buff_Fear.name;
	if buff_Fear then
		buff = buff_Fear.name;
	elseif buff_Confusion then
		buff = buff_Confusion.name;
	end
	InsertBuffActions(abilityActions, self, target, buff, 1, false, nil, true);	
	return unpack(abilityActions);
end
-----------------------------------------------------------------------------------
-- ABL_SLEEP
-------------------------------------------------------------------------------------
function ABL_SLEEP(self, ability, target, userInfoArgs, targetInfoArgs)
	local abilityActions = {};
	local mission = GetMission(self);
	local buffChance = 0;
	if mission.MissionTime.name == 'Morning' then
		buffChance = 75;
	elseif mission.MissionTime.name == 'Daytime' then
		buffChance = 50;
	elseif mission.MissionTime.name == 'Evening' then
		buffChance = 75;
	elseif mission.MissionTime.name == 'Night' then
		buffChance = 100;
	end
	local buff_Patrol = GetBuff(target, 'Patrol');
	if buff_Patrol then
		buffChance = 100;
	end
	if RandomTest(buffChance) then
		InsertBuffActions(abilityActions, self, target, 'Sleep', 1, false, nil, true);	
	end
	return unpack(abilityActions);
end
-----------------------------------------------------------------------------------
-- ABL_STEALBUFF
-------------------------------------------------------------------------------------
function ABL_STEALBUFF(self, ability, target, userInfoArgs, targetInfoArgs)
	local abilityActions = {};
	
	local targetBuffList = GetBuffType(target, 'Buff');
	if #targetBuffList > 0 then
		local selectBuff = targetBuffList[math.random(1, #targetBuffList)];
		InsertBuffActions(abilityActions, self, self, selectBuff.name, selectBuff.Lv, false, nil, true);
		InsertBuffActions(abilityActions, target, target, selectBuff.name, -1 * selectBuff.Lv, false, nil, true);
	end
	return unpack(abilityActions);
end
-----------------------------------------------------------------------------------
-- ABL_RESTORECOST
-------------------------------------------------------------------------------------
function ABL_ASSIST(self, ability, target, userInfoArgs, targetInfoArgs)
	local abilityActions = {};
	return unpack(abilityActions);
end
------------------------------------------------------------------------------
--- Extra Ability -----
function ABL_RELOAD(self, ability, usingPos, userInfoArgs, targetInfoArgs)
	local capacityProp = {};
	return capacityProp;	
end
function ABL_SEARCH(self, ability, target, userInfoArgs, targetInfoArgs)
	local actions = {};
	if self ~= target then
		InsertBuffActions(actions, self, target, 'Searched', 1, true, nil, true);
		if target.Speed == 0 then
			-- Speed가 0이면 턴이 사실상 안 돌아오므로 무한 턴 상태로 간주하고, 남은 턴 표시가 안 나오게 하자
			table.insert(actions, Result_BuffPropertyUpdated('IsTurnShow', false, target, 'Searched', false, true));
			table.insert(actions, Result_BuffPropertyUpdated('Turn', 99999, target, 'Searched', false, true));
			table.insert(actions, Result_BuffPropertyUpdated('Life', 99999, target, 'Searched', true, true));
		end
		if ability.CancelTargetBuff.name and IsInSight(self, target) and IsEnemy(self, target) then
			InsertBuffActionsModifier(actions, owner, target, ability.CancelTargetBuff.name, 1, GetClassList('Buff').Searched.Turn, true);
		end
	end
	return unpack(actions);
end
function ABL_MOVE(self, ability, usingPosList, userInfoArgs, targetInfoArgs)
	local maxDist;
	local priorDist;
	if ability.name == 'Move' then
		maxDist = self.MoveDist * (1 + self.SecondaryMoveRatio);
		priorDist = self.MoveDist;
	elseif ability.name == 'SecondMove' or ability.name == 'ExtraMove' then
		maxDist = self.MoveDist * self.SecondaryMoveRatio;
		priorDist = maxDist;
	end
	userInfoArgs.MaxMoveDist = maxDist;
	userInfoArgs.PriorMoveDist = priorDist;
	--table.print(usingPosList);
	return Result_MoveList(usingPosList, self, maxDist, priorDist, {Type = 'Ability', Value = ability.name, Unit = self});
end
function ABL_KNOCKBACK(self, ability, target, userInfoArgs, targetInfoArgs)
	-- ABL_ATTACK에 통합됨. Battle 함수의 knockbackPower 리턴 값이 0보다 크면 자동으로 Knockback 효과가 적용된다.
	return ABL_ATTACK(self, ability, target, userInfoArgs, targetInfoArgs);
end
function ABL_ALERTSHOT(self, ability, target, userInfoArgs, targetInfoArgs)
	SetInstantProperty(target, 'SupportTarget', self);
	return Result_RemoveBuff(target, 'Patrol'), Result_AddBuff(self, target, 'Support', 1, nil, false, true);
end

function ABL_OVERWATCH(self, ability, usingPos, userInfoArgs, targetInfoArgs)
	return Result_AddBuff(self, self, 'Overwatching', 1, nil, false, true);
end
function ABL_STARTEXPLOSION(self, ability, usingPos, userInfoArgs, targetInfoArgs)
	GiveAbility(self, 'Explosion');
	return Result_AddBuff(self, self, 'CautionExplosionRisk', 1, nil, false, true);
end

function ABL_DELAYATTACK(self, ability, target, userInfoArgs, targetInfoArgs)
	userInfoArgs.Prepared = ability.Prepared;
	local prepared = ability.Prepared;
	ability.Prepared = not prepared;
	if prepared then
		return ABL_ATTACK(self, ability, target, userInfoArgs, targetInfoArgs);
	else
		local abilityName = ability.name;
		local targetKey = GetObjKey(target);
		return Result_AddBuff(self, self, 'ActionController', 1, function(buff)
			LogAndPrint('Buff has been Modified');
			buff.AutoUseAbility = abilityName;
			buff.AutoUseAbilityTarget = targetKey;
		end, false, true);
	end
end
function ABL_ROLLINGSHOT(self, ability, target, userInfoArgs, targetInfoArgs)
	if targetInfoArgs.Target.name then
		return ABL_ATTACK(self, ability, targetInfoArgs.Target, userInfoArgs, targetInfoArgs);
	end
end
function ABL_STANDBY(self, ability, target, userInfoArgs, targetInfoArgs)
	local actions = {};
	
	local hasteAct = 0;
	local delay = 0.5;
	if self.TurnState.Moved then
		delay = 0.75;
	end
	
	local nextAct = math.max(36, math.floor(self.Wait * delay));
	hasteAct = self.Wait - nextAct;
	
	if hasteAct > 0 then
		InsertBuffActions(actions, self, self, 'Haste', hasteAct, true, nil, true);
	end
	
	local mission = GetMission(self);
	local company = GetCompanyByTeam(mission, GetTeam(self));
	if company then
		AddCompanyStats(company, 'UseAbilityStandBy', 1);
	end
	
	return unpack(actions);
end
function ABL_CONCEAL(self, ability, target, userInfoArgs, targetInfoArgs)
	local mission = GetMission(self);
	local company = GetCompanyByTeam(mission, GetTeam(self));
	if company then
		AddCompanyStats(company, 'UseAbilityConceal', 1);
	end
	return ABL_BUFF(self, ability, target, userInfoArgs, targetInfoArgs);
end
function ABL_SETCOMMAND(self, ability, target, userInfoArgs, targetInfoArgs)
	local applyAct = -(target.Act + 1);
	if applyAct >= 0 then	-- Act 값이 늘어날 상황이면 아무것도 하지 않음
		return;
	end
	
	local actions = {};
	local added, reasons = AddActionApplyAct(actions, self, target, applyAct, 'System');
	-- System 타입의 Act 처리에 reason이 있을수는 없음..
	--[[
	ReasonToUpdateBattleEventMulti(target, ds, reasons, cam, 0.5);
	]]
	InsertBuffActions(actions, self, target, 'Delay', -applyAct, true, nil, true);

	return unpack(actions);
end
function ABL_AWAKEN_PROTOCOL(self, ability, target, userInfoArgs, targetInfoArgs)
	local actions = {};
	-- Act를 적당히 조정하자
	table.insert(actions, Result_PropertyUpdated('Act', -100));

	-- 더미 ABL_BUFF를 넣어줌
	table.append(actions, {ABL_BUFF(self, ability, target, userInfoArgs, targetInfoArgs, nil, {}, GetHitRateCalculator_Buff(self, target, ability))});
	return unpack(actions);	
end
function ABL_STAR_ARROW(self, ability, target, userInfoArgs, targetInfoArgs)
	local actions = {ABL_ATTACK(self, ability, target, userInfoArgs, targetInfoArgs)};
	
	local damAction = actions[1];
	local isHit = damAction.DefenderState ~= 'Dodge' and (damAction.damage <= 0 or (target and GetBuff(target, 'StarShield') == nil));
	
	if isHit and IsValidCostType(target, ability.ApplyCostType) then
		local applyCost = GetAbilityApplyCost(ability, self, target);
		if target.Cost > 0 then
			local retCost, reasons = AddActionCost(actions, target, applyCost, true);
			AddBattleEvent(target, 'AddCostCustomEvent', { CostType = target.CostType.name, Count = applyCost, EventType = 'OnGive' });
			ReasonToAddBattleEventMulti(target, reasons, 'OnGive');
		end
		local retCost, reasons = AddActionCost(actions, self, -applyCost, true);
		AddBattleEvent(self, 'AddCostCustomEvent', { CostType = self.CostType.name, Count = -applyCost, EventType = 'OnTake' });
		ReasonToAddBattleEventMulti(self, reasons, 'OnTake');
	end
	
	return unpack(actions);
end
function ABL_STAR_CALL(self, ability, target, userInfoArgs, targetInfoArgs)
	local actions = {};
	local debuffList = GetBuffType(target, 'Debuff');
	if #debuffList > 0 then
		for index, debuff in ipairs (debuffList) do
			table.insert(actions, Result_RemoveBuff(target, debuff.name, true));
			AddBattleEvent(target, 'BuffDischarged', { Buff = debuff.name, EventType = 'Ending' });	
		end
		targetInfoArgs.BuffRemoved = true;
	end
			
	local weather = 'Clear';
	local missionTime = 'Day';
	if IsMissionServer() then
		local mission = GetMission(self);
		weather = mission.Weather.name;
		missionTime = mission.MissionTime.name;
	end
	
	table.append(actions, {ABL_BUFF(self, ability, target, userInfoArgs, targetInfoArgs, nil, {}, GetHitRateCalculator_Buff(self, target, ability))});
	return unpack(actions);
end
function ABL_REST(self, ability, target, userInfoArgs, targetInfoArgs)
	local abilityList = GetAllAbility(self);
	for index, curAbility in ipairs (abilityList) do
		curAbility.PriorityDecay = 0;
	end
end
function ABL_LESSER_PANDA(self, ability, target, userInfoArgs, targetInfoArgs)
	local actions = {ABL_ATTACK(self, ability, target, userInfoArgs, targetInfoArgs)};
	InsertBuffActions(actions, self, self, 'LesserArtChain', 1, false, nil, true);
	return unpack(actions);
end
function ABL_CHARGING(self, ability, target, userInfoArgs, targetInfoArgs)
	local addSpAmount, reasons = GetAbilityApplySP(ability, self, target);
	local actions = {};
	local turnPlayActions = {GetTurnPlayActions(self, ability, ability.TurnPlayType, userInfoArgs)};
	local prevUsedMain = self.TurnState.UsedMainAbility;
	-- 가라로 턴 플레이 스테이트 중 UsedMainAbility 만 뽑아서 적용해준다.
	self.TurnState.UsedMainAbility = prevUsedMain or (table.count(turnPlayActions, function(action)
			return action.type == 'PropertyUpdated' 
				and action.property_key == 'TurnState/UsedMainAbility' 
				and action.property_value == 'true';
		end) > 0);
	AddSPPropertyActionsObject(actions, target, addSpAmount);
	self.TurnState.UsedMainAbility = prevUsedMain;
	ReasonToAddBattleEventMulti(self, reasons, 'Ending');
	targetInfoArgs.MainDamage = -addSpAmount;
	return unpack(actions);
end
function ABL_TRANCE(self, ability, target, userInfoArgs, targetInfoArgs)
	local actions = {};
	table.append(actions, { ABL_CHARGING(self, ability, target, userInfoArgs, targetInfoArgs) });
	table.append(actions, { ABL_BUFF(self, ability, target, userInfoArgs, targetInfoArgs) });
	return unpack(actions);
end
function ABL_IRONWALL(self, ability, target, userInfoArgs, targetInfoArgs)
	if HasBuff(target, ability.ApplyTargetBuff.name) then
		return;
	end
	local actions = {};

	local buff = ability.ApplyTargetBuff;
	local addLv = ability.ApplyTargetBuffLv;
	InsertBuffActions(actions, self, target, buff.name, addLv, true, nil, true);
	
	-- 철의 요새
	local masteryTable = GetMastery(self);
	local mastery_FortressOfIron = GetMasteryMastered(masteryTable, 'FortressOfIron');
	if mastery_FortressOfIron then
		InsertBuffActions(actions, self, target, 'FortressOfIron', 1, true, nil, true);
	end

	return unpack(actions);
end
-- 서리 요새
function ABL_FROSTWALL(self, ability, target, userInfoArgs, targetInfoArgs)
	local actions = {};

	local buff = ability.ApplyTargetBuff;
	local addLv = ability.ApplyTargetBuffLv;
	InsertBuffActions(actions, self, target, buff.name, addLv, true, nil, true);
	
	-- 서리 요새
	local masteryTable = GetMastery(self);
	local mastery_FortressOfFrost = GetMasteryMastered(masteryTable, 'FortressOfFrost');
	if mastery_FortressOfFrost then
		InsertBuffActions(actions, self, target, 'FortressOfFrost', 1, true, nil, true);
	end

	return unpack(actions);
end
function ABL_MAGICOUTERARMOR(self, ability, target, userInfoArgs, targetInfoArgs)
	local actions = {};

	local buff = ability.ApplyTargetBuff;
	local addLv = ability.ApplyTargetBuffLv;
	InsertBuffActions(actions, self, target, buff.name, addLv, true, nil, true);
	
	-- 움직이는 성
	local masteryTable = GetMastery(self);
	local mastery_MovingCastle = GetMasteryMastered(masteryTable, 'MovingCastle');
	if mastery_MovingCastle then
		InsertBuffActions(actions, self, target, 'MovingCastle', 1, true, nil, true);
	end

	return unpack(actions);
end
function ABL_FULL_SHAKING(self, ability, target, userInfoArgs, targetInfoArgs)
	return Result_RemoveBuff(self, 'Shaking'), ABL_ATTACK(self, ability, target, userInfoArgs, targetInfoArgs);
end
function ABL_TAME(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local selfBuff = GetClassList('Buff')['Taming'];
	local targetBuff = GetClassList('Buff')['Provocation'];
	
	if HasBuff(self, selfBuff.name) or BuffImmunityTest(selfBuff, self) then
		return;
	end
	if HasBuff(target, targetBuff.name) or BuffImmunityTest(targetBuff, target) then
		return;
	end
	
	local actions = {};
	InsertBuffActions(actions, self, self, selfBuff.name, 1, true, nil, true);
	InsertBuffActions(actions, self, target, targetBuff.name, 1, true, function(buff)
		buff.ReferenceTarget = GetObjKey(self)
	end, true);
	-- 어빌리티로 걸리는 도발은 무한 턴 (실패 시 걸리는 건 기본인 3턴)
	table.insert(actions, Result_BuffPropertyUpdated('IsTurnShow', false, owner, targetBuff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Turn', 99999, owner, targetBuff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Life', 99999, owner, targetBuff.name, true, true));
	
	local tamingTime = GetTamingTimeCalculator(self, target, ability, detailInfo or {});
	SetInstantProperty(self, 'TamingTarget', GetObjKey(target));
	SetInstantProperty(self, 'TamingTime', tamingTime);
	table.insert(actions, Result_UpdateInstantProperty(target, 'TamingUnit', GetObjKey(self)));
	
	-- 턴 종료 없이 Act만 뒤로 미룸
	table.insert(actions, Result_PropertyUpdated('Act', tamingTime, self, true, true));
	
	return unpack(actions);
end
function ABL_PREY_FISHING(self, ability, target, userInfoArgs, targetInfoArgs)
	local actions = {};
	InsertBuffActions(actions, self, self, 'HavingPrey', 1, true, function(buff)
		buff.ReferenceTarget = GetObjKey(target);
	end);
	InsertBuffActions(actions, self, target, 'BeingFished', 1, true);
	
	return unpack(actions);
end
function ABL_PREY_DOWN(self, ability, usingPosList, userInfoArgs, targetInfoArgs)
	local actions = {};
	
	local buff_HavingPrey = GetBuff(self, 'HavingPrey');
	
	local target = GetUnit(GetMission(self), buff_HavingPrey.ReferenceTarget);
	userInfoArgs.Target = target;
	userInfoArgs.MainTargetHandle = GetHandle(target);
	
	IncreaseSurprizeMoveCounter(self);
	IncreaseSurprizeMoveCounter(target);
	
	SubscribeWorldEvent(self, 'AbilityUsed', function(eventArg, ds, subscriptionID)
		if eventArg.Unit ~= self then
			return;
		end
		DecreaseSurprizeMoveCounter(self);
		DecreaseSurprizeMoveCounter(target);
		UnsubscribeWorldEvent(self, subscriptionID);
	end);
	
	table.insert(actions, Result_SetPosition(target, usingPosList[1]));
	table.insert(actions, Result_RemoveBuff(self, 'HavingPrey'));
	table.insert(actions, Result_DirectingScript(function()
		return Result_RemoveBuff(target, 'BeingFished', true);
	end, nil, true, true));
	return unpack(actions);
end
function ABL_DERANGEMENT_PROTOCOL(self, ability, usingPosList, userInfoArgs, targetInfoArgs)

	local appliedList = {};
	if ability.ModifyMasteryList ~= '' then
		appliedList = UnpackTableFromString(ability.ModifyMasteryList);
	end	


	local actions = {};
	local usingPos = usingPosList[1];
	usingPos.offset = nil;
	local dir = table.map2(usingPos, GetPosition(self), __op_sub);
	local create = Result_CreateMonster(GenerateUnnamedObjKey(self), 'Mon_Kylie_Hologram', usingPos, GetTeam(self), function(unit, arg)
		unit.Obstacle = true;
		UNIT_INITIALIZER(unit, GetTeam(unit));
		RaiseHateCustom(unit, 'Taunt', 9999, false);
		unit.ReflectingTarget = GetObjKey(self);
		
		local appliedMasteriesSet = Set.new(appliedList);
		if appliedMasteriesSet['DivideAndConquerAlgorithm'] then
			UpdateTemporaryMastery(unit, GetClassList('Mastery')['DivideAndConquerAlgorithm'].Mastery.name, 1);
		end
		if appliedMasteriesSet['InformationControl'] then
			UpdateTemporaryMastery(unit, GetClassList('Mastery')['InformationControl'].Mastery.name, 1);
		end
	end, {}, 'DoNothingAI', nil, true, dir);
	create.sequential = true;
	table.insert(actions, create);
	return unpack(actions);
end
function ABL_BOOSTS_SPEED(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local success = RandomTest(95);
	if SafeIndex(resultModifier, 'DefenderState') then
		success = SafeIndex(resultModifier, 'DefenderState') ~= 'Dodge';
	end

	local actions = {};
	

	if not success then
		-- targetInfoArgs 갱신
		local myPos = GetPosition(target);
		local nearestEnemyPos = Linq.new(GetAllUnitInSight(target, true))
			:where(function (o) return IsEnemy(target, o) end)
			:select(function (o) return GetPosition(o) end)
			:min(function(p) return GetDistance3D(p, myPos) end);
		if nearestEnemyPos == nil or IsSamePosition(myPos, nearestEnemyPos) then
			nearestEnemyPos = myPos;
			nearestEnemyPos.x = nearestEnemyPos.x + math.random(-6, 6);
			nearestEnemyPos.y = nearestEnemyPos.y + math.random(-6, 6);
		end
		
		local knockbackPos = GetKnockbackPosition(target, nearestEnemyPos, 6, true);
		
		AddBattleEvent(target, 'Malfunction');
		userInfoArgs.DefenderState = 'Dodge';
		targetInfoArgs.DefenderState = 'Dodge';
		
		ApplyKnockbackAction(actions, self, target, ability, targetInfoArgs, knockbackPos, GetPosition(target), false);
		return unpack(actions);
	end
	
	targetInfoArgs.DefenderState = 'Hit';
	userInfoArgs.DefenderState = 'Hit';
	InsertBuffActions(actions, self, target, ability.ApplyTargetBuff.name, math.random(1, 5), true, function (buff)
		buff.Life = math.random(2, 5);
	end);
	return unpack(actions);
end
function ABL_GENERATOR_SMOKE(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local success = RandomTest(95);
	if SafeIndex(resultModifier, 'DefenderState') then
		success = SafeIndex(resultModifier, 'DefenderState') ~= 'Dodge';
	end
	
	if success then
		userInfoArgs.DefenderState = 'Hit';
		targetInfoArgs.DefenderState = 'Hit';
		return ABL_BUFF(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo);
	end
	
	AddBattleEvent(target, 'Malfunction');
	userInfoArgs.DefenderState = 'Dodge';
	targetInfoArgs.DefenderState = 'Dodge';
	local actions = {};
	UpdateAbilityPropertyActions(actions, target, ability.name, 'UseCount', 0);
	return unpack(actions);
end
-- 재생의 물약
function ABL_POTION_REGENERATION(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local success = RandomTest(95);
	if SafeIndex(resultModifier, 'DefenderState') then
		success = SafeIndex(resultModifier, 'DefenderState') ~= 'Dodge';
	end
	
	if success then
		userInfoArgs.DefenderState = 'Hit';
		targetInfoArgs.DefenderState = 'Hit';
		return ABL_BUFF(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo);
	end
	
	AddBattleEvent(target, 'Malfunction');
	userInfoArgs.DefenderState = 'Dodge';
	targetInfoArgs.DefenderState = 'Dodge';
	local actions = {};
	-- HP 최대 회복
	local addHP = target.MaxHP;
	local reasons = AddActionRestoreHP(actions, self, target, addHP);
	ReasonToAddBattleEventMulti(target, reasons, 'Ending');
	if target.HP < target.MaxHP then
		AddBattleEvent(target, 'DirectDamageByType', { DirectDamageType = 'HPRestore', Damage = -1 * addHP, NextHP = math.min(target.HP + addHP, target.MaxHP) });
	end
	return unpack(actions);
end
-- 광분의 물약
function ABL_POTION_BERSERKER(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local success = RandomTest(95);
	if SafeIndex(resultModifier, 'DefenderState') then
		success = SafeIndex(resultModifier, 'DefenderState') ~= 'Dodge';
	end
	
	if success then
		userInfoArgs.DefenderState = 'Hit';
		targetInfoArgs.DefenderState = 'Hit';
		return ABL_BUFF(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo);
	end
	
	AddBattleEvent(target, 'Malfunction');
	userInfoArgs.DefenderState = 'Dodge';
	targetInfoArgs.DefenderState = 'Dodge';
	-- 광폭화 버프
	local actions = {};
	InsertBuffActions(actions, self, target, 'Frenzy', 1, true, nil, true);
	return unpack(actions);
end
-- 격앙의 물약
function ABL_POTION_EXCITEMENT(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local success = RandomTest(95);
	if SafeIndex(resultModifier, 'DefenderState') then
		success = SafeIndex(resultModifier, 'DefenderState') ~= 'Dodge';
	end
	
	if success then
		userInfoArgs.DefenderState = 'Hit';
		targetInfoArgs.DefenderState = 'Hit';
		return ABL_BUFF(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo);
	end
	
	AddBattleEvent(target, 'Malfunction');
	userInfoArgs.DefenderState = 'Dodge';
	targetInfoArgs.DefenderState = 'Dodge';
	-- 과충전(SP 최대 회복)
	local actions = {};
	local addSP = target.MaxSP - target.SP;
	AddSPPropertyActionsObject(actions, target, addSP);
	return unpack(actions);
end
-- 거인의 물약
function ABL_POTION_GIANT(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local success = RandomTest(95);
	if SafeIndex(resultModifier, 'DefenderState') then
		success = SafeIndex(resultModifier, 'DefenderState') ~= 'Dodge';
	end
	
	if success then
		userInfoArgs.DefenderState = 'Hit';
		targetInfoArgs.DefenderState = 'Hit';
		return ABL_BUFF(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo);
	end
	
	AddBattleEvent(target, 'Malfunction');
	userInfoArgs.DefenderState = 'Dodge';
	targetInfoArgs.DefenderState = 'Dodge';
	-- 거대화 부작용 버프
	local actions = {};
	InsertBuffActions(actions, self, target, 'Giant_SideEffect', 1, true, nil, true);
	return unpack(actions);
end
-- 강력한 수면제
function ABL_POTION_SLEEP(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local success = RandomTest(95);
	if SafeIndex(resultModifier, 'DefenderState') then
		success = SafeIndex(resultModifier, 'DefenderState') ~= 'Dodge';
	end
	
	if success then
		userInfoArgs.DefenderState = 'Hit';
		targetInfoArgs.DefenderState = 'Hit';
		return ABL_BUFF(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo);
	end
	
	AddBattleEvent(target, 'Malfunction');
	userInfoArgs.DefenderState = 'Dodge';
	targetInfoArgs.DefenderState = 'Dodge';
	-- 겨울잠, 기절 버프
	local actions = {};
	if RandomTest(70) then
		InsertBuffActions(actions, self, target, 'Hibernation', 1, true, nil, true);
	else
		InsertBuffActions(actions, self, target, 'Stun', 1, true, nil, true);
	end
	return unpack(actions);
end
-- 죽음의 물약
function ABL_POTION_DEATH(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local actions = {};
	-- 최대 HP 데미지
	local damage = target.MaxHP;
	local realDamage, reasons = ApplyDamageTest(target, damage, 'Ability');
	local nextHP = math.max(target.HP - realDamage, 0);
	local isDead = false;
	if nextHP <= 0 then
		isDead = true;
	end
	ReasonToAddBattleEventMulti(target, reasons, 'Ending');
	table.insert(actions, Result_DirectingScript(function(mid, ds, args)
		DirectDamageByType(ds, target, 'Death', damage, nextHP, true, isDead);
	end, nil, true, true));
	table.insert(actions, Result_Damage(damage, 'Normal', 'Hit', self, target, 'Ability', 'None', ability));
	return unpack(actions);
end
--------
function InitUnitNextTurn(unit, args)
	UNIT_INITIALIZER(unit, unit.Team);
	unit.Act = 0;
end

function CreateShadowAvatar(mid, ds, args)
	local userObj = GetUnit(mid, args.userKey)
	if userObj == nil then
		return
	end

	local mission = GetMission(userObj)
	local userPos = GetPosition(userObj)

	local candidatePosList = {};
	
	-- Find candidate positions
	local targetRange = CalculateRange(userObj, 'Diamond4', userPos)
	for i = 1, #targetRange do
		local targetPos = targetRange[i]
		if IsValidPosition(mission, targetPos) and GetObjectByPosition(mission, targetPos) == nil then
			targetPos.dist = GetDistance3D(userPos, targetPos)
			table.insert(candidatePosList, targetPos)
		end
	end
	
	-- Shuffle candidate positions
	for i = 1, #candidatePosList do
		local j = math.random(1, #candidatePosList)
		-- Swap
		candidatePosList[i], candidatePosList[j] = candidatePosList[j], candidatePosList[i]
	end
	
	-- n
	local unitCount = 4
	
	-- Select n positions from candidate positions
	local targetPosList = {}
	for i = 1, unitCount do
		table.insert(targetPosList, candidatePosList[i])
	end

	-- Sort n positions into descending order of distance
	table.sort(targetPosList, function (a, b) return a.dist > b.dist end)
	
	local baseCmd = ds:UpdateBalloonChat(GetObjKey(userObj), 'Copy!')
	
	-- Create n Marco and move to target position
	local targetCount = #targetPosList
	for i = 1, targetCount do
		local targetPos = targetPosList[i]
		
		local newObjKey = GenerateUnnamedObjKey(mid)
		
--		local action = Result_CreateObject(newObjKey, userObj.name, userPos, GetTeam(userObj), 'InitUnitNextTurn', args, 'Aggressive')
--		local cloneCmd = ds:WorldAction(action, true)
		local cloneCmd = ds:CreateObject(newObjKey, userObj.name, userPos, GetTeam(userObj), 'InitUnitNextTurn', args, 'Aggressive', {});
		
		local moveCmd = ds:Move(newObjKey, targetPos)
		ds:Connect(cloneCmd, baseCmd, i * 0.1)
		ds:Connect(moveCmd, cloneCmd)
	end
end

function ABL_SHADOWAVATAR(self, ability, usingPos, userInfoArgs, targetInfoArgs)
	return Result_DirectingScript('CreateShadowAvatar', { userKey = GetObjKey(self) });
end

function CreateObjectHelper(mid, ds, args)
	local userKey = args.userKey
	local usingPos = args.usingPos
	local objName = args.ObjectName
	local directingScript = args.DirectingScript
	local ai = args.AI
	local aiArg = args.AIArgs
	if ai == nil then
		ai = ''
	end
	if aiArg == nil then
		aiArg = {}
	end

	local userObj = GetUnit(mid, userKey)
	if userObj == nil then
		return
	end

	local newObjKey = GenerateUnnamedObjKey(mid)
	
	local baseCmd = ds:Sleep(0.0)
	local createCmd = ds:CreateObject(newObjKey, objName, usingPos, GetTeam(userObj), 'CreateObjectInitializer', args, ai, aiArg);
	ds:Connect(createCmd, baseCmd)
	
	local newObj = GetUnit(mid, newObjKey)
	SetInstantProperty(newObj, 'CreatePosOffset', usingPos.offset)
	
	if args.InitBuff ~= nil then
		local buffAction = Result_AddBuff(newObj, newObj, args.InitBuff, 1, nil, false, false)
		local buffCmd = ds:WorldAction(buffAction, true)
		ds:Connect(buffCmd, createCmd)
	end
	
	if directingScript ~= nil then
		_G[directingScript](mid, ds, newObjKey, createCmd, args)
	end
end

function CreateObjectInitializer(unit, args)
	UNIT_INITIALIZER_NON_BATTLE(unit, unit.Team)
	
	if args.WaitTurn == 'false' then
		unit.Act = 0
	end
	
	if args.Untargetable ~= nil then
		unit.Base_Untargetable = (args.Untargetable == 'true')
	end
end
function ABL_CREATEOBJECT(self, ability, usingPos, userInfoArgs, targetInfoArgs)
	local args = {}
	
	local argsProp = ability.CreateObjectArgs
	for k, v in pairs(argsProp) do
		args[k] = v
	end
	
	args.userKey = GetObjKey(self)
	args.usingPos = usingPos
	
	if args.UsingOffset ~= 'true' then
		args.usingPos.offset = { x = 0, y = 0 }
	end

	return Result_DirectingScript('CreateObjectHelper', args);
end

function FindMoveAbility(object)
	local findFunc = function (ability)
		return IsMoveTypeAbility(ability);
	end;

	return FindAbilityIf(object, findFunc);
end

function FindMoveAbilityInList(abilityList)
	for _, ability in ipairs(abilityList) do
		if IsMoveTypeAbility(ability) then
			return ability;
		end
	end
end

function ABL_INTERACTION(self, ability, target, userInfoArgs, targetInfoArgs)
	return Result_Interaction(self, targetInfoArgs.Target, ability.ApplyTargetDetail, ability);
end
function ABL_INTERACTION_AREA(self, ability, target, userInfoArgs, targetInfoArgs)
	return Result_InteractionArea(self, GetPosition(self), ability.ApplyTargetDetail, ability);
end
function ABL_REPAIR(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local selfBuff = GetClassList('Buff')['RepairInteraction'];
	if HasBuff(self, selfBuff.name) or BuffImmunityTest(selfBuff, self) then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, self, self, selfBuff.name, 1, true, nil, true);
	
	local repairTime = GetRepairTimeCalculator(self, target, ability, detailInfo or {});
	SetInstantProperty(self, 'RepairTarget', GetObjKey(target));
	SetInstantProperty(self, 'RepairTime', repairTime);	
	
	-- 턴 종료 없이 Act만 뒤로 미룸
	table.insert(actions, Result_PropertyUpdated('Act', repairTime, self, true, true));
	return unpack(actions);
end
function ABL_SUMMON_MACHINE(self, ability, targetPosList, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local summonMachineList = GetSummonMachineList(self);
	if #summonMachineList == 0 then
		return;
	end
	local targetInfos = table.filter(summonMachineList, function(info)
		return GetObjKey(info.Object) == detailInfo.ObjKey;
	end);
	if #targetInfos == 0 then
		return;
	end
	local targetInfo = targetInfos[1];
	local target = targetInfo.Object;
	local beastType = targetInfo.BeastType;
	if not IsEnableSummonMachine(targetInfo.Pc, target, beastType) then
		return;
	end
	local actions = {};
	ApplySummonMachineActions(actions, self, target, targetPosList[1]);
	userInfoArgs.MainTargetHandle = GetHandle(target);
	return unpack(actions);
end
function ABL_UNSUMMON_MACHINE(self, ability, target, userInfoArgs, targetInfoArgs)
	if GetObjKey(self) ~= GetInstantProperty(target, 'SummonMaster') then
		return;
	end
	local actions = {};
	ApplyUnsummonMachineActions(actions, self, target);
	return unpack(actions);
end
function ABL_SUMMON_BEAST(self, ability, targetPosList, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local summonBeastList = GetEnableSummonBeastList(self);
	if #summonBeastList == 0 then
		return;
	end
	local targetInfo = nil;
	if SafeIndex(detailInfo, 'ObjKey') then
		local targetInfos = table.filter(summonBeastList, function(info)
			return GetObjKey(info.Object) == detailInfo.ObjKey;
		end);
		if #targetInfos == 0 then
			return;
		end
		targetInfo = targetInfos[1];
	else
		local picker = RandomPicker.new();
		for _, info in ipairs(summonBeastList) do
			local prob = GetInstantProperty(info.Object, 'SummonProb') or 100;
			picker:addChoice(prob, info);
		end
		targetInfo = picker:pick();
	end
	if targetInfo == nil then
		return;
	end
	local target = targetInfo.Object;
	local beastType = targetInfo.BeastType;
	if not IsEnableSummonBeast(target, beastType, self, targetInfo.Pc) then
		return;
	end
	local actions = {};
	userInfoArgs.MainTargetHandle = GetHandle(target);
	ApplySummonBeastActions(actions, self, target, targetPosList[1]);
	return unpack(actions);
end
function ABL_UNSUMMON_BEAST(self, ability, target, userInfoArgs, targetInfoArgs)
	if GetObjKey(self) ~= GetInstantProperty(target, 'SummonMaster') then
		return;
	end
	local actions = {};
	ApplyUnsummonBeastActions(actions, self, target);
	return unpack(actions);
end
function ABL_CONTROL_GIVE_BACK(self, ability, target, userInfoArgs, targetInfoArgs)
	return Result_RemoveBuff(target, 'ControlTakeover'), Result_AddBuff(target, target, 'Firewall', 1, nil, nil, true);
end
function ABL_RESCUE_SIGNAL(self, ability, usingPosList, userInfoArgs, targetInfoArgs)
	local mission = GetMission(self);
	local usingPos = usingPosList[#usingPosList];
	usingPos.offset = nil;	-- 오프셋 정보는 필요없고 괜히 있으면 에러남
	local from = table.deepcopy(usingPos);
	from.x = from.x - 1;
	from.y = from.y - 1;
	local to = table.deepcopy(usingPos);
	to.x = to.x + 1;
	to.y = to.y + 1;
	table.print(from);
	table.print(to);
	local escapeAreaDecl = {Type='EscapeArea', Area = {{From = {from}, To = {to}}}};
	local key = GenerateUnnamedDashboardKey(mission);
	local dashboardInst = RegisterMissionDashboard(mission, key, escapeAreaDecl);
	dashboardInst:Initializer(key, mission, nil, escapeAreaDecl);
	
	local objList = table.filter(table.map(GetPositionListInArea(from, to), function (p) 
		return GetObjectByPosition(mission, p);
	end), function(obj)
		return obj ~= nil;
	end);
	
	local actions = {Result_UpdateDashboard(key, dashboardInst)};
	for i, inObj in ipairs(objList) do
		table.insert(actions, Result_FireWorldEvent('UnitArrivedEscapeArea', {Unit=inObj, Dashboard=dashboardInst}))
	end
	
	return unpack(actions);
end

function ABL_AIMING(self, ability, usingPosList, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local actions = {};
	InsertBuffActions(actions, self, self, ability.ApplyTargetBuff.name, ability.ApplyTargetBuffLv, true, true);
	table.insert(actions, Result_BuffPropertyUpdated('ReferenceTarget', GetObjKey(targetInfoArgs.Target), self, ability.ApplyTargetBuff.name, nil, true));
	return unpack(actions);
end

function ABL_FLARE(self, ability, usingPosList, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local newObjKey = GenerateUnnamedObjKey(self) .. '_flare';
	local pos = usingPosList[1];
	pos.offset = nil;
	return Result_CreateObject(newObjKey, 'Object_SightObjectHidable', pos, GetTeam(self), function(obj, arg)
		obj.Obstacle = true;
		obj.Base_SightRange = 8;
		obj.Base_EyeOffset = 100;
		UNIT_INITIALIZER_NON_BATTLE(obj, nil);
		SetInstantProperty(obj, 'NoExpTaker', true);
		obj.Act = 240;
	end, nil, 'DoNothingAI', nil, true), Result_DirectingScript(function(mid, ds, args)
		local obj = GetUnit(mid, newObjKey);
		return Result_AddBuff(self, obj, 'Flare', 1, function(b)
			b.Life = 1;
		end, true);
	end, nil, false);
end

function ABL_WIND_WALKER(self, ability, usingPosList, userInfoArgs, targetInfoArgs)
	if ability.SurpriseMove then
		IncreaseSurprizeMoveCounter(self);
		
		SubscribeWorldEvent(self, 'AbilityUsed', function(eventArg, ds, subscriptionID)
			if eventArg.Unit ~= self then
				return;
			end
			DecreaseSurprizeMoveCounter(self);
			UnsubscribeWorldEvent(self, subscriptionID);
		end);
	end
end

function ABL_MOVE_PROTOCOL(self, ability, usingPosList, userInfoArgs, targetInfoArgs)
	IncreaseSurprizeMoveCounter(self);
	
	SubscribeWorldEvent(self, 'AbilityUsed', function(eventArg, ds, subscriptionID)
		if eventArg.Unit ~= self then
			return;
		end
		DecreaseSurprizeMoveCounter(self);
		UnsubscribeWorldEvent(self, subscriptionID);
	end);
	return ABL_BUFF(self, ability, self, userInfoArgs, targetInfoArgs, nil, {}, GetHitRateCalculator_Buff(self, self, ability));
end

function ABL_MADNESS_DANCE_CLEAR(self, ability, target, userInfoArgs, targetInfoArgs)
	local actions = {};
	local buffList = GetBuffType(target, 'Buff');
	if #buffList > 0 then
		for index, buff in ipairs (buffList) do
			table.insert(actions, Result_RemoveBuff(target, buff.name, true));
			AddBattleEvent(target, 'BuffDischarged', { Buff = buff.name, EventType = 'Ending' });	
		end
	end
	
	local weather = 'Clear';
	local missionTime = 'Day';
	if IsMissionServer() then
		local mission = GetMission(self);
		weather = mission.Weather.name;
		missionTime = mission.MissionTime.name;
	end
	
	table.append(actions, {ABL_BUFF(self, ability, target, userInfoArgs, targetInfoArgs, nil, {}, GetHitRateCalculator_Buff(self, target, ability))});
	return unpack(actions);
end

function ABL_TRAP(self, ability, usingPosList, userInfoArgs, targetInfoArgs)
	local actions = {};
	-- 트랩 보여주기용
	local newTrapKey = GenerateUnnamedObjKey(self);
	local usingPos = usingPosList[1];
	
	local trapLimit = 3;
	-- 달빛사냥꾼
	local mastery_MoonHunter = GetMasteryMastered(GetMastery(self), 'MoonHunter');
	if mastery_MoonHunter and IsDarkTime(GetMission(self).MissionTime.name) then
		trapLimit = trapLimit + mastery_MoonHunter.ApplyAmount;
	end
	local trapQueue = GetInstantProperty(self, 'TrapQueue') or {};
	if #trapQueue >= trapLimit then
		for i = trapLimit, #trapQueue do
			local oldestTrap = GetUnit(self, table.remove(trapQueue, 1));
			if oldestTrap then
				table.insert(actions, Result_DestroyObject(oldestTrap, true));
			else
				LogAndPrint('ABL_TRAP', '이전 트랩 못찾음');
			end
		end
	end
	usingPos.offset = nil;
	local dir = table.map2(GetPosition(self), usingPos, __op_sub);
	table.insert(trapQueue, newTrapKey);
	table.insert(actions, Result_UpdateInstantProperty(self, 'TrapQueue', trapQueue));
	local create  = Result_CreateMonster(newTrapKey, 'Utility_TrapInstance', usingPos, GetTeam(self), function(obj, arg)
		UNIT_INITIALIZER(obj, GetTeam(obj));
		obj.Obstacle = true;
		SetExpTaker(obj, self);
		obj.Shape = GetClassList('ObjectShape')['Object_Installed_' .. ability.name];
		-- 덫 능력치 반영
		obj.Base_AttackPower = self.AttackPower;
		obj.Base_ESPPower = self.ESPPower;
		
		SetInstantProperty(obj, 'TrapAbility', ability.ApplyTargetDetail);
		SetInstantProperty(obj, 'NoExpTaker', true);
		SetInstantProperty(obj, 'NoTeamUnitCounter', true);
		AddBuff(obj, 'UnderControl', 1, self);
	end, {}, 'DoNothingAI', {}, false, dir);
	create.sequential = true;
	table.insert(actions, create);
	
	local company = GetCompany_Shared(self);
	if company then
		AddCompanyStats(company, 'TrapUseCount', 1);
	end
	
	return unpack(actions);
end

function ABL_TRAP_ATTACK(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local actions = {ABL_ATTACK(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)};
	
	local damAction = actions[1];
	local isHit = damAction.DefenderState ~= 'Dodge' and (damAction.damage <= 0 or (target and GetBuff(target, 'StarShield') == nil));
	
	if isHit then
		-- 소환자 특성
		local trapHost = GetExpTaker(self);
		if trapHost then
			local masteryTable = GetMastery(trapHost);
			-- 강력한 덫
			local mastery_PowerfulTrap = GetMasteryMastered(masteryTable, 'PowerfulTrap');
			if mastery_PowerfulTrap then
				local isApplyTarget = false;
				if ability.name == 'FireTrapActivate' then
					-- 화염 계열
					if HasBuffType(target, 'Debuff', nil, mastery_PowerfulTrap.BuffGroup.name) then
						isApplyTarget = true;
					end
				elseif ability.name == 'IceTrapActivate' then
					-- 얼음 계열
					if HasBuffType(target, 'Debuff', nil, mastery_PowerfulTrap.SubBuffGroup.name) then
						isApplyTarget= true;
					end
				elseif ability.name == 'LightningTrapActivate' then
					-- 번개 계열
					if HasBuffType(target, 'Debuff', nil, mastery_PowerfulTrap.ThirdBuffGroup.name) then
						isApplyTarget = true;
					end
				elseif ability.name == 'PoisonTrapActivate' then
					-- 중독 계열
					if HasBuffType(target, 'Debuff', nil, mastery_PowerfulTrap.ForthBuffGroup.name) then
						isApplyTarget = true;
					end
				elseif ability.name == 'LightTrapActivate' then
					-- 섬광 계열
					if HasBuffType(target, 'Debuff', nil, mastery_PowerfulTrap.FifthBuffGroup.name) then
						isApplyTarget = true;
					end
				end
				if isApplyTarget then
					local targets = GetInstantProperty(self, 'PowerfulTrap') or {};
					targets[GetObjKey(target)] = true;
					SetInstantProperty(self, 'PowerfulTrap', targets);
				end
			end
		end
		-- 연쇄 효과 : 휘말림
		if SafeIndex(resultModifier, 'Engaging') then
			local trigger = SafeIndex(resultModifier, 'EngagingInvoker') or self;
			InsertBuffActions(actions, self, target, 'Confusion', 1, true);
			AddBattleEvent(target, 'BigTextCustomEvent', {Text = WordText('ChainEvent_Engaging'), Font = 'NotoSansBlack-28', AnimKey = 'KnockbackStun', Color = 'FFFF5943', EventType = 'FinalHit'});
			table.insert(actions, Result_FireWorldEvent('ChainEffectOccured', {Unit = target, Trigger = trigger, ChainType = 'Engaging'}, nil, true));
		end
	end
	
	return unpack(actions);
end

function ABL_RESTART(self, ability, target, userInfoArgs, targetInfoArgs)
	local actions = {};

	local abilityList = GetAllAbility(self);
	abilityList = table.filter(abilityList, function(ability)
		return IsProtocolAbility(ability) and ability.IsUseCount and ability.AutoUseCount;
	end);

	for _, ability in ipairs(abilityList) do
		if ability.UseCount < ability.MaxUseCount then
			UpdateAbilityPropertyActions(actions, self, ability.name, 'UseCount', ability.MaxUseCount);
		end
	end
	
	return unpack(actions);
end

function ABL_HACKING_PROTOCOL(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local weather = 'Clear';
	local missionTime = 'Day';
	local temperature = 'Normal';
	if IsMissionServer() then
		local mission = GetMission(self);
		weather = mission.Weather.name;
		missionTime = mission.MissionTime.name;
		temperature = mission.Temperature.name;
	end
	
	local protocolDetail = SafeIndex(detailInfo, 'ProtocolDetail');
	if protocolDetail == nil then
		protocolDetail = table.randompick({'CognitiveDistraction', 'Shutdown', 'ControlTakeover'});
		return;
	end
	
	local actions = {};
	local usingPos = table.map(userInfoArgs.UsingPos, function(v) return v; end);
	local hitRate = ability.GetHitRateCalculator(self, target, ability, usingPos, weather, missionTime, temperature, resultModifier, nil, detailInfo);
	local success = RandomTest(hitRate);
	targetInfoArgs.DefenderState = success and 'Hit' or 'Dodge'
	targetInfoArgs.AttackerState = 'Normal';
	userInfoArgs.ProtocolDetail = protocolDetail;
	local protocolCls = nil;
	if protocolDetail == nil then
		local _, cls = next(GetClassList(ability.AbilitySubMenu))
		protocolCls = cls;
	else
		protocolCls = GetClassList('HackingProtocol')[protocolDetail];
	end
	
	if not protocolCls.IsEnableTest(self, target, protocolCls) then
		protocolCls = GetClassList('HackingProtocol').CognitiveDistraction;
	end
	if success then		
		local commandAbility = GetAbilityObject(self, protocolCls.Ability.name) or protocolCls.Ability;
		local buffCls = protocolCls.ApplyTargetBuff;
		InsertBuffActions(actions, self, target, buffCls.name, protocolCls.ApplyTargetBuffLv, nil, nil, true);
		table.insert(actions, Result_FireWorldEvent('HackingSucceeded', {Unit = self, Target = target, Ability = ability, HackingType = protocolDetail}));
		
		-- 정보 제어
		if commandAbility.ApplyTargetSubBuff.name then
			InsertBuffActions(actions, self, self, commandAbility.ApplyTargetSubBuff.name, 1, nil, nil, true);
		end
	else
		InsertBuffActions(actions, self, target, protocolCls.FailedApplyTargetBuff.name, protocolCls.FailedApplyTargetBuffLv, nil, nil, true);
		table.insert(actions, Result_FireWorldEvent('HackingFailed', {Unit = self, Target = target, Ability = ability, HackingType = protocolDetail}));
	end
	return unpack(actions);
end

function ABL_ABILITY_PROTOCOL(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local protocolDetail = SafeIndex(detailInfo, 'ProtocolDetail');
	local protocolCls = nil;
	if protocolDetail == nil then
		local _, cls = next(GetClassList(ability.AbilitySubMenu))
		protocolCls = cls;
		detailInfo = {ProtocolDetail = protocolCls.name};
		protocolDetail = protocolCls.name;
	else
		protocolCls = GetClassList(ability.AbilitySubMenu)[protocolDetail];
	end
	local commandAbility = GetAbilityObject(self, protocolCls.Ability.name) or protocolCls.Ability;
	local actions = {};
	local applyScp = _G[commandAbility.ApplyScp];
	if applyScp then
		table.append(actions, { applyScp(self, commandAbility, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo) });
	end
	userInfoArgs.ProtocolDetail = protocolDetail;	-- 여러번 값이 덮어써지겠지만, 뭐 같은 값일테니 상관없나
	return unpack(actions);
end

function ABL_REPAIR_COMMAND(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local actions = {};
	
	local debuffList = {};
	table.append(debuffList, GetBuffType(target, 'Debuff', 'Physical'));
	table.append(debuffList, GetBuffType(target, 'Debuff', 'Aura', nil, true));
	for _, debuff in ipairs(debuffList) do
		table.insert(actions, Result_RemoveBuff(target, debuff.name, true));
		AddBattleEvent(target, 'BuffDischarged', { Buff = debuff.name, EventType = 'Ending' });	
	end
	
	table.append(actions, { ABL_HEAL(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo) });
	
	return unpack(actions);
end

function ABL_EMP_GRENADE(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	if target.name == 'Utility_TrapInstance' then
		return Result_FireWorldEvent('TrapHasBeenCracked', {Cracker = self, Invoker = {Type = 'Ability', Value = ability}}, target);
	else
		return ABL_BUFF(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo);
	end
end
-- 탈피
function ABL_MOLTING(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local actions = {};
	
	-- 자신에게만 적용
	if self == target then
		local debuffList = GetBuffType(target, 'Debuff', 'Physical');
		for _, debuff in ipairs(debuffList) do
			table.insert(actions, Result_RemoveBuff(target, debuff.name, true));
			AddBattleEvent(target, 'BuffDischarged', { Buff = debuff.name, EventType = 'Ending' });	
		end
		-- 반짝이는 비늘
		local masteryTable = GetMastery(self);
		local mastery_ShiningScale = GetMasteryMastered(masteryTable, 'ShiningScale');
		if mastery_ShiningScale and #debuffList > 0 then
			AddMasteryInvokedEvent(self, mastery_ShiningScale.name, 'Ending');		
			local goodBuffList = Linq.new(GetClassList('Buff_Positive'))
				:select(function(pair) return pair[1]; end)
				:toList();
			local goodBuffPicker = RandomBuffPicker.new(self, goodBuffList);
			for i = 1, #debuffList do
				local goodBuffName = goodBuffPicker:PickBuff();
				if goodBuffName then
					InsertBuffActions(actions, self, target, goodBuffName, 1, true);
				end
			end
		end
	end
	
	table.append(actions, { ABL_HEAL(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo) });

	return unpack(actions);
end
-- 고무
function ABL_ENCOURAGE(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local actions = {};
	
	-- 자신에게만 적용
	if self == target then
		local debuffList = GetBuffType(target, 'Debuff', 'Mental');
		for _, debuff in ipairs(debuffList) do
			table.insert(actions, Result_RemoveBuff(target, debuff.name, true));
			AddBattleEvent(target, 'BuffDischarged', { Buff = debuff.name, EventType = 'Ending' });	
		end
	end
	
	table.append(actions, { ABL_BUFF(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo) });

	return unpack(actions);
end
-- 복종의 울부짖음
function ABL_HOWL_OBEDIENCE(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local raceName = SafeIndex(target, 'Race', 'name');
	if target.Lv > self.Lv or (raceName ~= 'Human' and raceName ~= 'Beast') then
		return;
	end
	local actions = {};
	local buff, addLv;
	if raceName == 'Beast' then
		buff = ability.ApplyTargetBuff;
		addLv = ability.ApplyTargetBuffLv;
	else
		buff = ability.ApplyTargetSubBuff;
		addLv = ability.ApplyTargetSubBuffLv;
	end
	InsertBuffActions(actions, self, target, buff.name, addLv, true, nil, true);
	return unpack(actions);
end
-- 하위 어빌리티 선택 (ex. 화염 부르기)
function ABL_SUBCOMMAND(self, ability, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo)
	local subCommand = SafeIndex(detailInfo, 'SubCommand');
	local subCommandCls = nil;
	if subCommand == nil then
		local _, cls = next(GetClassList(ability.AbilitySubMenu))
		subCommandCls = cls;
		detailInfo = {SubCommand = subCommandCls.name};
		subCommand = subCommandCls.name;
	else
		subCommandCls = GetClassList(ability.AbilitySubMenu)[subCommand];
	end
	local commandAbility = GetAbilityObject(self, subCommandCls.Ability.name) or subCommandCls.Ability;
	local actions = {};
	local applyScp = _G[commandAbility.ApplyScp];
	if applyScp then
		table.append(actions, { applyScp(self, commandAbility, target, userInfoArgs, targetInfoArgs, resultModifier, detailInfo) });
	end
	return unpack(actions);
end

function ABL_NONE(self, ability, usingPosList, userInfoArgs, targetInfoArgs)

end

function AbilityPreUseMaster(self, ability, posList, subPositions, directingConfig, refID, ds)
	if ability.AbilityWithMove then
		SetInstantProperty(self, 'AbilityPrevPosition', GetPosition(self));
		if subPositions and not IsInvalidPosition(subPositions[1]) then
			SetInstantProperty(self, 'MovingForAbility', true);
			-- Status의 액션 포인트가 바로 소모된 것처럼 연출한다.
			ds:Connect(ds:UpdateAttachingWindow(GetObjKey(self), 'Status', 'UpdateObjectStatus', 'AbilityWithMove'), refID, 0);
			ds:Connect(ds:RunScript('UpdatePlayerInfo', { ObjKey = GetObjKey(self) }), refID, 0);
			local rushCamEnabled = ds:GeneralMove(self, subPositions[1], SafeIndex(directingConfig, 'NoCamera'), true, refID);
			if rushCamEnabled then
				SetInstantProperty(self, 'DirectPrepare', true);
			end
		elseif not SafeIndex(directingConfig, 'NoCamera') then
			ds:ChangeCameraTarget(GetObjKey(self), '_SYSTEM_', false, true, 0.5);
		end
	end
end

function AbilityCoolResetCheck_Reload(abl, self, testAbility)
	return testAbility.Type == 'Attack' or testAbility.Type == 'Assist' or testAbility.Type == 'Trap';
end

function AbilityPost_Protocol(self, ability, isFreeAction, userInfoArgs, primaryTargetInfoArgs, secondaryTargetInfoArgs)
	local actions = {};
	local company = GetCompany_Shared(self);
	if company then
		AddCompanyStats(company, 'ProtocolUseCount', 1);
		local team = GetTeam(self);
		table.insert(actions, Result_DirectingScript(function(mid, ds, args)
			ds:AddSteamStat('ProtocolCount', 1, team);
		end));
	end
	return unpack(actions);
end

function IncreaseSurprizeMoveCounter(obj)
	local prevSurprizeMoveCounter = GetInstantProperty(obj, 'SurprizeMoveCounter') or 0;
	SetInstantProperty(obj, 'SurprizeMoveCounter', math.max(prevSurprizeMoveCounter + 1, 0));
end
function DecreaseSurprizeMoveCounter(obj)
	local prevSurprizeMoveCounter = GetInstantProperty(obj, 'SurprizeMoveCounter') or 0;
	SetInstantProperty(obj, 'SurprizeMoveCounter', math.max(prevSurprizeMoveCounter - 1, 0));
end

function ABL_GRAB(self, ability, target, userInfoArgs, targetInfoArgs)
	-- 넉백 처리
	if ability.KnockbackPower > 0 and target.Base_Movable then
		targetInfoArgs.KnockbackPower = ability.KnockbackPower;
		targetInfoArgs.DefenderState = 'Hit';
	end
end