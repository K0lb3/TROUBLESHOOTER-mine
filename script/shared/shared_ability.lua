--- 어빌리티 타입 여부-------------------------------------------------------------------------------------
function GetAbilityUseType(ability)
	local abilityUseType = '';
	if ability == nil then Traceback(); end
	if ability.Type == 'Attack' then
		local applyRange = GetClassList('Range')[ability.ApplyRange];
		if applyRange.Type == 'Dot' then
			abilityUseType = 'Attack_Target';
		elseif ability.Type == 'Chain' then
			abilityUseType = 'Attack_Target';
		elseif ability.Target == 'Enemy' or ability.Target == 'Ally' or ability.Target == 'PureEnemy' then
			abilityUseType = 'Attack_Target';
		else
			abilityUseType = 'Attack_Range';
		end
	elseif ability.Type == 'Move' then
	
	elseif ability.Type == 'Heal' then
		local applyRange = GetClassList('Range')[ability.ApplyRange];
		if applyRange.Type == 'Dot' then
			abilityUseType = 'Heal_Target';
		elseif ability.Type == 'Chain' then
			abilityUseType = 'Heal_Target';
		elseif ability.Target == 'Enemy' or ability.Target == 'Ally' or ability.Target == 'PureEnemy' then
			abilityUseType = 'Heal_Target';
		else
			abilityUseType = 'Heal_Range';
		end
	elseif ability.Type == 'Buff' then
	
	elseif ability.Type == 'DeBuff' then
	
	elseif ability.Type == 'StateChange' then
		
	elseif ability.Type == 'Summon' then
		
	elseif ability.Type == 'Assist' then
		local applyRange = GetClassList('Range')[ability.ApplyRange];
		if applyRange.Type == 'Dot' then
			abilityUseType = 'Assist_Target';
		elseif ability.Target == 'Enemy' or ability.Target == 'Ally' or ability.Target == 'PureEnemy' then
			abilityUseType = 'Assist_Target';
		else
			abilityUseType = 'Assist_Range';
		end
	end	
	return abilityUseType;
end

function IsMoveTypeAbility(ability)
	return (SafeIndex(ability, 'Type') == 'Move');
end

function AbilitySplashMethod_One(ability, distanceFromUsingPos, chainIndex)
	return 1;
end

function AbilitySplashMethod_BinaryStepHalf(ability, distanceFromUsingPos, chainIndex)
	if distanceFromUsingPos == 0 then
		return 1;
	else
		return 0.5;
	end
end

function AbilitySplashMethod_ChainIncrease25(ability, distanceFromUsingPos, chainIndex)
	return 0.75 + chainIndex * 0.25;
end

function GetEnableProtocolAbilityList(self, curAbility)
	local abilityList = GetAllAbility(self);
	local ret = table.filter(abilityList, function(ability)
		if not IsProtocolAbility(ability) then
			return false;
		end
		-- 사용 횟수 체크
		if ability.IsUseCount and ability.UseCount == 0 then
			return false;
		end		
		-- 궁극기 사용 가능 체크
		if ability.SPFullAbility and self.SP < self.MaxSP then
			return false;
		end
		-- Cost 체크
		if self.Overcharge == 0 and ability.Cost > self.Cost then
			return false;
		end
		-- 쿨다운 체크
		local useAbilityPreCool = false;
		if curAbility ~= nil and ability.Cool > 0 and ability.name == curAbility.name and ability.Cool == ability.CoolTime + 1 then
			-- 현재 어빌리티 사용으로 바로 쿨다운 되는 상황은 쿨이 아직 없는 걸로 간주한다.
			useAbilityPreCool = true;
		end
		if ability.Cool > 0 and not useAbilityPreCool then
			return false;
		end
		-- 이동 불가능 버프
		if IsMoveTypeAbility(ability) and not self.Movable then
			return false;
		end
		-- 공격 불가능 버프
		if ability.Type == 'Attack' and not GetBuffStatus(self, 'Attackable', 'And') then
			return false;
		end
		if ability.Type == 'Assist' and not GetBuffStatus(self, 'Assistable', 'And') then
			return false;
		end
		if ability.Type == 'Heal' and not GetBuffStatus(self, 'Healable', 'And') then
			return false;
		end
		-- 초능력 불가능 버프
		if IsESPType(ability.SubType) and HasBuff(self, 'Silence') then
			return false;
		end
		return true;
	end);
	return ret;
end

function GetAbilityPresetData(pcInfo, presetSlot, presetIndex)
	local presetRedirect = {};
	if pcInfo.RosterType == 'Pc' then
		for job, enableJob in pairs(pcInfo.EnableJobs) do
			presetRedirect[GetHostClass(enableJob).AbilityPresetIndex] = job;
		end
	end
	
	local abilityList = {};
	if pcInfo.RosterType == 'Pc' then
		if presetSlot.ActiveAbility.MaxCount > 0 then
			for i = 1, presetSlot.ActiveAbility.MaxCount do
				abilityList[i] = presetSlot.ActiveAbility[i];
			end
		elseif presetRedirect[presetIndex] ~= nil then
			local redirectJob = GetWithoutError(pcInfo.EnableJobs, presetRedirect[presetIndex]);
			abilityList = Linq.new(redirectJob.ActiveAbility)
				:where(function(d) return StringToBool(d[2]); end)
				:select(function(d) return d[1] end)
				:toList();
		end
	elseif pcInfo.RosterType == 'Beast' then
		if presetSlot.ActiveAbility.MaxCount > 0 then
			for i = 1, presetSlot.ActiveAbility.MaxCount do
				activeAbilitySet[i] = presetSlot.ActiveAbility[i];
			end
		elseif presetIndex == 1 then
			abilityList = Linq.new(pcInfo.ActiveAbility)
				:where(function(d) return d[2]; end)
				:select(function(d) return d[1] end)
				:toList();
		end
	end
	return abilityList;
end
---- AbilitySlotManager
AbilitySlotManager = {}
function AbilitySlotManager.new(pcInfo, presetIndex, job, autoFill)
	local ret = {Target = pcInfo};
	local testJob = job and GetClassList('Job')[job] or pcInfo.Object.Job;
	for _, slot in ipairs({'Basic', 'Normal', 'Ultimate'}) do
		ret[slot] = {Active = {}, Candidates = {}, ActiveLimit = testJob[slot]};
	end
	
	-- 사용 가능한 어빌리티 세트 구성
	local availableSet = {};
	local currentJobAbilitySet = {};
	local presetRedirect = {};
	if pcInfo.RosterType == 'Pc' then
		for job, enableJob in pairs(pcInfo.EnableJobs) do
			if IsSatisfiedChangeClass(pcInfo, job) and (enableJob.Lv > 1 or enableJob.LastLv > 0) then
				for __, abilitySlot in ipairs(enableJob.Abilities) do
					if abilitySlot.RequireLv <= enableJob.Lv then
						availableSet[abilitySlot.Name] = true;
					end
					if job == pcInfo.Object.Job.name then	
						currentJobAbilitySet[abilitySlot.Name] = true;
					end
				end
			end
			presetRedirect[GetHostClass(enableJob).AbilityPresetIndex] = job;
		end
	elseif pcInfo.RosterType == 'Beast' then
		local beastType = pcInfo.BeastType;
		for __, abilitySlot in ipairs(beastType.Abilities) do
			if abilitySlot.RequireLv <= pcInfo.JobLv then
				availableSet[abilitySlot.Name] = true;
			end
			currentJobAbilitySet[abilitySlot.Name] = true;
		end
	end
	local activeAbilitySet = {};
	if pcInfo.RosterType == 'Pc' then
		if presetIndex == nil then
			local currentJob = GetWithoutError(pcInfo.EnableJobs, pcInfo.Object.Job.name);
			if currentJob then
				activeAbilitySet = table.map(currentJob.ActiveAbility, function (v) return StringToBool(v); end);
			end
		else
			local preset = pcInfo.AbilityPreset.Preset[presetIndex];
			if preset.ActiveAbility.MaxCount > 0 then
				for i = 1, preset.ActiveAbility.MaxCount do
					activeAbilitySet[preset.ActiveAbility[i]] = true;
				end
			elseif presetRedirect[presetIndex] ~= nil then
				activeAbilitySet = table.map(GetWithoutError(pcInfo.EnableJobs, presetRedirect[presetIndex]).ActiveAbility, function (v) return StringToBool(v); end);
			elseif autoFill then
				local currentJob = GetWithoutError(pcInfo.EnableJobs, pcInfo.Object.Job.name);
				if currentJob then
					activeAbilitySet = table.map(currentJob.ActiveAbility, function (v) return StringToBool(v); end);
				end
			end
		end
	elseif pcInfo.RosterType == 'Beast' then
		if presetIndex == nil then
			activeAbilitySet = table.map(pcInfo.ActiveAbility, function (v) return v; end);
		else
			local preset = pcInfo.AbilityPreset.Preset[presetIndex];
			if preset.ActiveAbility.MaxCount > 0 then
				for i = 1, preset.ActiveAbility.MaxCount do
					activeAbilitySet[preset.ActiveAbility[i]] = true;
				end
			elseif presetIndex == 1 then
				activeAbilitySet = table.map(pcInfo.ActiveAbility, function (v) return v; end);
			end
		end
	end
	local abilityList = GetClassList('Ability');
	for index, ability in ipairs(pcInfo.Object.Ability) do 
	(function()
		local abilityCls = abilityList[ability.name];
		if not availableSet[abilityCls.name] and not currentJobAbilitySet[abilityCls.name] then
			return;
		end
		local slotData = ret[abilityCls.SlotType];
		if slotData == nil then
			LogAndPrint('slotData is nil - ability:', abilityCls.name, ', SlotType:', abilityCls.SlotType);
			return;
		end
		local insertData = {Ability = abilityCls, Index = index, Available = availableSet[abilityCls.name]};
		if StringToBool(activeAbilitySet[abilityCls.name]) then
			table.bininsert(slotData.Active, insertData, AbilitySlotManager.SlotCmpFunc);
		end
		slotData.Candidates[abilityCls.name] = insertData;
	end)();
	end
	ret.OriginalData = table.deepcopy(ret);
	setmetatable(ret, {__index = AbilitySlotManager});
	return ret;
end
function AbilitySlotManager.SlotCmpFunc(slotData, index)
	return slotData.Index;
end	
-- 아래 두 함수는 UI의 setUserData가 메타테이블 정보를 가지고 갈 수 없는 문제 때문에 수동으로 복원을 하기 위한 로직임
-- 추후 우리 시스템이 온전히 lua table객체를 가져갈 수 있으면 필요없어짐
function AbilitySlotManager.restore(data)
	setmetatable(data, {__index = AbilitySlotManager});
	return data;
end
function AbilitySlotManager.export(self)
	return {Basic = self.Basic, Normal = self.Normal, Ultimate = self.Ultimate, OriginalData = self.OriginalData, Target = self.Target};
end
function AbilitySlotManager.MoveSlot(self, fromSlot, toSlot, slotData)
	
	table.bininsert(toSlot, slotData, self.SlotCmpFunc);
end
function AbilitySlotManager.IsActive(self, abilityName)
	for _, slotType in ipairs({'Basic', 'Normal', 'Ultimate'}) do
		local slotData = self[slotType];
		local found = table.findif(slotData.Active, function(data)
			return data.Ability.name == abilityName;
		end);
		if found then
			return true;
		end
	end
	return false;
end
function AbilitySlotManager.Activate(self, ability)
	-- limit check
	if self[ability.SlotType].ActiveLimit <= #self[ability.SlotType].Active then
		return false;
	end
	local slotData = self[ability.SlotType];
	local candidate = slotData.Candidates[ability.name];
	if candidate == nil or not candidate.Available then
		return false;
	end
	-- 마스터 어빌리티 체크
	if ability.MasterAbility ~= 'None' and not self:IsActive(ability.MasterAbility) then
		return false;
	end	
	-- 이미 들어가 있음
	if table.binsearch(slotData.Active, candidate, self.SlotCmpFunc) then
		return false;
	end	
	table.bininsert(slotData.Active, candidate, self.SlotCmpFunc);
	return true;
end
function AbilitySlotManager.Deactivate(self, ability)
	local slotData = self[ability.SlotType];
	local isRemoved = false;
	for index, data in ipairs(slotData.Active) do
		if data.Ability.name == ability.name then
			table.remove(slotData.Active, index);
			isRemoved = true;
			break;
		end
	end
	-- 종속 어빌리티 해제
	if isRemoved then
		for _, slotType in pairs({'Basic', 'Normal', 'Ultimate'}) do
			local slotData = self[slotType];
			slotData.Active = table.filter(slotData.Active, function(data)
				return data.Ability.MasterAbility ~= ability.name;
			end);
		end
	end
	return isRemoved;
end
-- function GetCurrentState
-- @return ActiveAbilities(list of class(:Ability)), CandidateAbilities(list of class(:Ability))
function AbilitySlotManager.GetCurrentState(self, slot)
	local enlistedCandiates = {}
	for name, data in pairs(self[slot].Candidates) do
		table.bininsert(enlistedCandiates, data, self.SlotCmpFunc);
	end
	return unpack(table.map({self[slot].Active, enlistedCandiates}, function (slotDatas) 
		return table.map(slotDatas, function(data) 
			return data.Ability; 
		end);
	end));
end
function AbilitySlotManager.IsValid(self)
	for _, slotType in pairs({'Basic', 'Normal', 'Ultimate'}) do
		if self[slotType].ActiveLimit < #self[slotType].Active then
			return false;
		end
	end
	return true;
end
function AbilitySlotManager.IsValidAndChanged(self)
	local changed = false;
	for _, slotType in pairs({'Basic', 'Normal', 'Ultimate'}) do
		-- Active만 비교해 보면 됨
		local originalData = self.OriginalData[slotType].Active;
		local currentData = self[slotType].Active;
		local availableData = {};
		for key, data in pairs(self[slotType].Candidates) do
			if data.Available then
				availableData[key] = data;
			end
		end
		if #currentData == 0 and not table.empty(availableData) then
			-- 최소 한개는 차고 있어야 한다.
			return false;
		end
		
		if #originalData ~= #currentData then
			changed = true;
		else
			for i = 1, #originalData do
				if originalData[i].Ability.name ~= currentData[i].Ability.name then
					changed = true;
					break;
				end
			end
		end
	end
	return changed;
end
function AbilitySlotManager.IsFullfilled(self)
	for _, slotType in pairs({'Basic', 'Normal', 'Ultimate'}) do
		local slotData = self[slotType];
		local currentData = slotData.Active;
		local availableCount = table.count(slotData.Candidates, function(value)
			return value.Available;
		end);
		if #currentData < math.min(slotData.ActiveLimit, availableCount) then
			-- 최소 한개는 차고 있어야 한다.
			return false;
		end
	end
	return true;
end
function AbilitySlotManager.AggregateChanges(self, testJob)
	local aggregatedActiveSet = Set.new(table.flatten(table.map({'Basic', 'Normal', 'Ultimate'}, function (slot) 
		return table.map(self[slot].Active, function(slotData) 
			return slotData.Ability.name;
		end);
	end)));
	testJob = testJob or self.Target.Object.Job.name;
	local changeData = {};
	local activeAbilitySet = {};
	if self.Target.RosterType == 'Pc' then
		activeAbilitySet = table.map(self.Target.EnableJobs[testJob].ActiveAbility, function(v) return StringToBool(v); end);
	else
		activeAbilitySet = table.map(self.Target.ActiveAbility, function(v) return v; end);
	end
	for ability, active in pairs(activeAbilitySet) do
		if active ~= (aggregatedActiveSet[ability] ~= nil) then	-- 현 세팅과 다름
			table.insert(changeData, {Ability = ability, Active = aggregatedActiveSet[ability] == true});
		end
	end
	return changeData;
end
function AbilitySlotManager.GetTruncatedAbilities(self)
	return table.flatten(table.map({'Basic', 'Normal', 'Ultimate'}, function (slot)
		local ret = {};
		for i = self[slot].ActiveLimit + 1, #self[slot].Active do
			table.insert(ret, self[slot].Active[i].Ability.name);
		end
		return ret;
	end));
end
function AbilitySlotManager.GetActiveAbilities(self)
	return table.flatten(table.map({'Basic', 'Normal', 'Ultimate'}, function (slot)
		return table.map(self[slot].Active, function(abl) return abl.Ability.name end);
	end));
end
------------------------------------------------------
-- 어빌리티 요구 레벨.
------------------------------------------------------
function GetAbilityRequireLevel(pcInfo, curAbility, jobName)
	local level = 1;
	local abilities = pcInfo.EnableJobs[jobName].Abilities;
	for index, ability in ipairs (abilities) do
		if ability.Name == curAbility.name then
			level = ability.RequireLv;
			break;
		end
	end
	return level;
end
------------------------------------------------------
-- 어빌리티 특성에 의한 변화 적용되는 함수.
------------------------------------------------------
function Shared_InitializeUnitAbility(ability, owner)
	if ability.Initialized then
		return;
	end
	
	Shared_ApplyAbilityModifier(ability, owner);
	
	-- 사용 가능 횟수 갱신
	if ability.IsUseCount then
		ability.UseCount = ability.MaxUseCount;
	end
	
	-- 초기화 완료
	ability.Initialized = true;
end
function Shared_ApplyAbilityModifier(ability, owner)
	-- Item Ability Modifier
	ModifyAbilityByItem(ability, owner);

	-- mastery의 ModifyAbilityType이 None이 아닌 것을 모두 처리합니다.
	ModifyAbilityByMastery(ability, owner);
	
	-- 버프 모디파이어
	ModifyAbilityByBuff(ability, owner);
end
----------------------------------------------------------------
-- 어빌리티 강화가 적용되는지 체크 함수
----------------------------------------------------------------
function ModifyAbilityChecker(mastery, ability, owner)
	if mastery.ModifyAbility == 'None' then
		return false;
	elseif mastery.ModifyAbility == 'Custom' then
		local checkFunc = _G['ModifyAbilityChecker_'..mastery.name];
		if checkFunc and checkFunc(mastery, ability, owner) then
			return true;
		end
		return false;
	else
		return (mastery.ModifyAbility == ability.name);
	end
end
function ModifyAbilityChecker_Buff(buff, ability, owner)
	if buff.ModifyAbility == 'None' then
		return false;
	elseif buff.ModifyAbility == 'Custom' then
		local checkFunc = _G['ModifyAbilityChecker_Buff_'..buff.name];
		if checkFunc and checkFunc(buff, ability, owner) then
			return true;
		end
		return false;
	else
		return (buff.ModifyAbility == ability.name);
	end
end
----------------------------------------------------------------
-- 어빌리티를 강화시킨 특성 목록
----------------------------------------------------------------
function GetAbilityModifyMasteryList(ability, owner, masteryTable)
	if not masteryTable then
		masteryTable = GetMastery(owner);
	end
	
	-- 야매지만, ModifyMasteryList 프로퍼티에 기록된 문자열로 리스트를 복원한다.
	local appliedList = {};
	if ability.ModifyMasteryList ~= '' then
		appliedList = UnpackTableFromString(ability.ModifyMasteryList);
	end

	local list = {};
	for _, masteryName in ipairs(appliedList) do
		local mastery = masteryTable[masteryName];
		if mastery and mastery.Lv > 0 then
			table.insert(list, mastery);
		end
	end
	return list;
end
function GetAbilityModifyBuffList(ability, owner)
	-- 야매지만, ModifyMasteryList 프로퍼티에 기록된 문자열로 리스트를 복원한다.
	local appliedList = {};
	if ability.ModifyBuffList ~= '' then
		appliedList = UnpackTableFromString(ability.ModifyBuffList);
	end
	return Linq.new(appliedList)
		:select(function(buffName) return GetBuff(owner, buffName) end)
		:where(function(buff) return buff ~= nil; end)
		:toList();
end
----------------------------------------------------------------
-- 어빌리티 강화에 적용되는 로직 분기 함수.
----------------------------------------------------------------
function ModifyAbilityByMastery(ability, owner, masteryTable)
	if ability.name == nil then
		LogAndPrint('ModifyAbilityByBuff', owner.name, 'A ability is nil');
		return;
	end
	if not masteryTable then
		masteryTable = GetMastery(owner);
	end

	-- Custom 타입은 어빌리티의 프로퍼티를 기반으로 조건을 판단하므로, 일반 타입들이 다 적용된 후 조건 체크를 해야한다.
	local candidate = {};
	for key, mastery in pairs(masteryTable) do
		if mastery.Lv > 0 and mastery.ModifyAbilityType ~= 'None' then
			table.bininsert(candidate, mastery, function(mastery) return mastery.ModifyAbilityOrder; end);
		end	
	end
	
	-- 순서대로 하나씩 조건을 테스트하면서 적용한다. (적용으로 조건 만족 유무가 변경될 수 있으므로)
	local appliedList = {};
	for _, mastery in ipairs(candidate) do
		if ModifyAbilityChecker(mastery, ability, owner) then
			local customFunc = _G['ModifyAbilityByMastery_'..mastery.ModifyAbilityType];
			if customFunc then
				local associatedMastery = {customFunc(ability, owner, mastery)};
				table.insert(appliedList, mastery);
				table.append(appliedList, associatedMastery);
			end
		end
	end
	
	-- 야매지만, 리스트를 ModifyMasteryList 프로퍼티에 문자열로 기록한다.
	local appliedStr = '';
	if #appliedList > 0 then
		appliedStr = PackTableToString(table.map(appliedList, function (mastery) return mastery.name end));
	end
	ability.ModifyMasteryList = appliedStr;
		
	for _, mastery in ipairs(appliedList) do
		local finalizer = GetWithoutError(mastery, 'ModifyAbilityFinalizer');
		if finalizer then
			local func = _G['ModifyAbilityFinalizerByMastery_' .. finalizer];
			if func then
				func(ability, owner, mastery, appliedList);
			end
		end
	end
end
function ModifyAbilityByBuff(ability, owner)
	if ability.name == nil then
		LogAndPrint('ModifyAbilityByBuff', owner.name, 'A ability is nil');
		return;
	end
	-- Custom 타입은 어빌리티의 프로퍼티를 기반으로 조건을 판단하므로, 일반 타입들이 다 적용된 후 조건 체크를 해야한다.
	local candidate = {};
	for _, buff in pairs(GetBuffList(owner)) do
		if buff.Lv > 0 and buff.ModifyAbilityType ~= 'None' then
			table.bininsert(candidate, buff, function(buff) return buff.ModifyAbilityOrder; end);
		end	
	end
	
	-- 순서대로 하나씩 조건을 테스트하면서 적용한다. (적용으로 조건 만족 유무가 변경될 수 있으므로)
	local appliedList = {};
	for _, buff in ipairs(candidate) do
		if ModifyAbilityChecker_Buff(buff, ability, owner) then
			local customFunc = _G['ModifyAbilityByBuff_'..buff.ModifyAbilityType];
			if customFunc then
				local associatedBuff = {customFunc(ability, owner, buff)};
				table.insert(appliedList, buff);
				table.append(appliedList, associatedBuff);
			end
		end
	end
	
	-- 야매지만, 리스트를 ModifyBuffList 프로퍼티에 문자열로 기록한다.
	local appliedStr = '';
	if #appliedList > 0 then
		appliedStr = PackTableToString(table.map(appliedList, function (buff) return buff.name end));
	end
	ability.ModifyBuffList = appliedStr;	
end
---------------------------------------------------------------
-- 특수 마스터리
---------------------------------------------------------------
---------------------------------------------------------------
-- 버프 확률
---------------------------------------------------------------
-- 1. 버프이름 / 버프 확률 추가 - AddApplyTargetBuff
function ModifyAbilityByMastery_AddApplyTargetBuff(ability, owner, mastery)
		
	local abilityBuffName = GetWithoutError(ability.ApplyTargetBuff, 'name');
	if not abilityBuffName then
		ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
	end
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + mastery.ApplyAmount, 100);
	ability.ApplyTargetBuffLv = 1;	
end
---------------------------------------------------------------
-- 피해량
---------------------------------------------------------------
-- 강철 / 기본 피해량 증가. - ApplyAmountChangeStep
function ModifyAbilityByMastery_AddBaseDamage(ability, owner, mastery)
	ability.ApplyAmountChangeStep[1] = ability.ApplyAmountChangeStep[1] + mastery.ApplyAmount;
end
-- 질풍 / 거리에 따른 피해량 증가 - DistanceAttackApplyAmountRatio
function ModifyAbilityByMastery_DistanceAttack(ability, owner, mastery)
	ability.DistanceAttackApplyAmountRatio = ability.DistanceAttackApplyAmountRatio + mastery.ApplyAmount;
end
-- 응징 / 무방비 노출 피해량 증가 - NoCoverAttackApplyAmountRatio
function ModifyAbilityByMastery_NoCoverAttack(ability, owner, mastery)
	ability.NoCoverAttackApplyAmountRatio = ability.NoCoverAttackApplyAmountRatio + mastery.ApplyAmount;
end
-- 필살 / 안정된 자세 피해량 증가 - NotMoveAttackApplyAmountRatio
function ModifyAbilityByMastery_NotMoveAttack(ability, owner, mastery)
	ability.NotMoveAttackApplyAmountRatio = ability.NotMoveAttackApplyAmountRatio + mastery.ApplyAmount;
end
---------------------------------------------------------------
-- 범위
---------------------------------------------------------------
-- 도전 / 사거리 증가 - TargetRange
function ModifyAbilityByMastery_TargetRange(ability, owner, mastery)
	ability.TargetRange = mastery.Range;
end
-- 확장 / 피해 범위 증가 - ApplyRange + GuideRange + PickingRange
function ModifyAbilityByMastery_ApplyRange(ability, owner, mastery)
	ability.ApplyRange = mastery.Range;
	ability.GuideRange = mastery.SubRange1;
	ability.PickingRange = mastery.SubRange2;
end
-- 연쇄 / 체인카운트 증가  - ApplyRange
function ModifyAbilityByMastery_ChainCount(ability, owner, mastery)
	ability.ApplyRange = mastery.Range;
end
---------------------------------------------------------------
-- 스탯
---------------------------------------------------------------
-- 집중 / 명중률 증가 - Accuracy
function ModifyAbilityByMastery_Accuracy(ability, owner, mastery)
	ability.Accuracy = ability.Accuracy + mastery.ApplyAmount;
end
-- 행운 / 치명타 적중률 증가 - CriticalStrikeChance
function ModifyAbilityByMastery_CriticalStrikeChance(ability, owner, mastery)
	ability.CriticalStrikeChance = ability.CriticalStrikeChance + mastery.ApplyAmount;
end
-- 폭발 / 치명타 피해량 증가 - CriticalStrikeDeal
function ModifyAbilityByMastery_CriticalStrikeDeal(ability, owner, mastery)
	ability.CriticalStrikeDeal = ability.CriticalStrikeDeal + mastery.ApplyAmount;
end
---------------------------------------------------------------
-- 턴 대기시간
---------------------------------------------------------------
-- 견제 / 턴 대기 시간 증가 + 견제 - ApplyAct + Containment
function ModifyAbilityByMastery_Containment(ability, owner, mastery)
	ability.ApplyAct = ability.ApplyAct + mastery.ApplyAmount;
	ability.Containment = true;
end
-- 충돌 / 넉백 파워 + 턴 대기 시간 증가 / KnockbackPower + ApplyAct
function ModifyAbilityByMastery_KnockbackPower(ability, owner, mastery)
	ability.KnockbackPower = ability.KnockbackPower + mastery.ApplyAmount;
	ability.ApplyAct = ability.ApplyAct + mastery.ApplyAmount2;
end
-- 지연 / 턴 대기 시간 증가 / ApplyAct
function ModifyAbilityByMastery_ApplyAct(ability, owner, mastery)
	ability.ApplyAct = ability.ApplyAct + mastery.ApplyAmount;
end
---------------------------------------------------------------
-- 시전 시간 , 쿨타임.
---------------------------------------------------------------
-- 신속 / 시전 시간 - CastDelay
function ModifyAbilityByMastery_CastDelay(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount / 100));
end
-- 재정비 / 쿨 다운 - CoolTime
function ModifyAbilityByMastery_CoolTime(ability, owner, mastery, propName)
	local applyAmount = GetWithoutError(mastery, propName or 'ApplyAmount') or 0;
	if ability.CoolTime > 0 and applyAmount > 0 then
		ability.CoolTime = math.max(0, ability.CoolTime - applyAmount);
	end
end
-- 융화 / 코스트 - Cost
function ModifyAbilityByMastery_Cost(ability, owner, mastery)
	ability.Cost = math.floor( ability.Cost * mastery.ApplyAmount/100);
end
---------------------------------------------------------------
-- 턴 플레이 타입
---------------------------------------------------------------
-- 몰입 / 턴플레이 타입(행동력) - TurnPlayTypeReduce
function ModifyAbilityByMastery_TurnPlayTypeReduce(ability, owner, mastery)
	if ability.TurnPlayType == 'Main' then
		ability.TurnPlayType = 'Half';
	elseif ability.TurnPlayType == 'Half' then
		ability.TurnPlayType = 'Free';
	end	
end
---------------------------------------------------------------
-- 판정 무시. 회피, 방어
---------------------------------------------------------------
-- 돌파 / 턴플레이 타입(행동력) - IgnoreBlock
function ModifyAbilityByMastery_IgnoreBlock(ability, owner, mastery)
	ability.IgnoreBlock = true;
end
-- 예측 / 턴플레이 타입(행동력) - IgnoreDodge
function ModifyAbilityByMastery_IgnoreDodge(ability, owner, mastery)
	ability.IgnoreDodge = true;
end
---------------------------------------------------------------
-- 사용 속성 변환
---------------------------------------------------------------
-- (속성이름) / 속성 - SubType
function ModifyAbilityByMastery_SubType(ability, owner, mastery)
	ability.SubType = mastery.SubType;
end
---------------------------------------------------------------
-- 사용 횟수 증가.
---------------------------------------------------------------
-- 달인 / 속성 - MaxUseCount
function ModifyAbilityByMastery_MaxUseCount(ability, owner, mastery)
	ability.MaxUseCount = ability.MaxUseCount + mastery.ApplyAmount;
end
function ModifyAbilityByMastery_MaxUseCount2(ability, owner, mastery)
	ability.MaxUseCount = ability.MaxUseCount + mastery.ApplyAmount2;
end
---------------------------------------------------------------
-- 개별 마스터리 적용.
---------------------------------------------------------------
-- 생활의 달인
function ModifyAbilityChecker_Expert(mastery, ability)
	local abilityCls = GetClassList('Ability')[ability.name];
	return ability.ItemAbility and ((abilityCls.TurnPlayType == 'Main' or abilityCls.TurnPlayType == 'Half') or abilityCls.IsUseCount);
end
function ModifyAbilityByMastery_Expert(ability, owner, mastery)
	if ability.TurnPlayType == 'Main' then
		ability.TurnPlayType = 'Half';
	elseif ability.TurnPlayType == 'Half' then
		ability.TurnPlayType = 'Free';
	end
	if ability.IsUseCount then
		ability.MaxUseCount = ability.MaxUseCount + mastery.ApplyAmount2;
	end
end
-- 빠른 줄타기.
function ModifyAbilityChecker_FastClimbWeb(mastery, ability)
	return ability.name == 'ClimbWeb';
end
function ModifyAbilityByMastery_FastClimbWeb(ability, owner, mastery)
	if ability.TurnPlayType == 'Main' then
		ability.TurnPlayType = 'Half';
	elseif ability.TurnPlayType == 'Half' then
		ability.TurnPlayType = 'Free';
	end
end
-- 즐거운 노래.
function ModifyAbilityChecker_HappySong(mastery, ability)
	return (ability.Type == 'Assist' or ability.Type == 'Heal');
end
function ModifyAbilityByMastery_HappySong(ability, owner, mastery)
	local mastery_ListenToMySong = GetMasteryMastered(GetMastery(owner), 'ListenToMySong');
	if mastery_ListenToMySong then
		ability.TurnPlayType = 'Free';
	else
	if ability.TurnPlayType == 'Main' then
		ability.TurnPlayType = 'Half';
	elseif ability.TurnPlayType == 'Half' then
		ability.TurnPlayType = 'Free';
	end
end
end
-- 마력 융합로
function ModifyAbilityChecker_MagicReactor(mastery, ability)
	return IsGetAbilitySubType(ability, 'ESP') and ability.CoolTime > 0;
end
function ModifyAbilityByMastery_MagicReactor(ability, owner, mastery)
	ModifyAbilityByMastery_CoolTime(ability, owner, mastery, 'ApplyAmount');
end
-- 보조 마력 회로
function ModifyAbilityChecker_SubMagicCircuit(mastery, ability)
	return ability.Type == 'Attack' and GetWithoutError(ability.AdditionalApplyAmount, 'ESPPower') ~= nil and GetWithoutError(ability.AdditionalApplyAmount, 'AttackPower') ~= nil;
end
function ModifyAbilityByMastery_SubMagicCircuit(ability, owner, mastery)
	-- 1. 두 수치가 동일한 경우.
	if ability.AdditionalApplyAmount.ESPPower == ability.AdditionalApplyAmount.AttackPower then
		ability.AdditionalApplyAmount.ESPPower = ability.AdditionalApplyAmount.ESPPower + mastery.ApplyAmount;
		ability.AdditionalApplyAmount.AttackPower = ability.AdditionalApplyAmount.AttackPower + mastery.ApplyAmount;
	else
		-- 2. 두 수치가 다른 경우.
		local maxValue = math.max(ability.AdditionalApplyAmount.ESPPower, ability.AdditionalApplyAmount.AttackPower);
		ability.AdditionalApplyAmount.ESPPower = maxValue;
		ability.AdditionalApplyAmount.AttackPower = maxValue;
	end
end
-- 백만번의 단련	왜 백만번인데 Training100인가 Training1000000아님? 축약이지. 100 모브 모름?
function ModifyAbilityChecker_Training100(mastery, ability)
	return Set.new({'FlameKick', 'FlameShoot', 'FlameDance', 'FlameCarriage', 'FlameJumpKick', 'FlameBackJumpKick', 'FlameStampKick', 'ResentmentOfRedLesserPanda', 'LesserDeepBreath'})[ability.name];
end
function ModifyAbilityByMastery_Training100(ability, owner, mastery)

	if ability.name == 'LesserDeepBreath' then
		ability.TurnPlayType = 'Free';
	elseif ability.name == 'FlameKick'then
		ability.ApplyTargetBuffChance = math.min(100, ability.ApplyTargetBuffChance + mastery.ApplyAmount);
		ability.ApplyTargetBuffLv = 1;
	elseif ability.name == 'FlameShoot'then
		ability.ApplyTargetBuffChance = math.min(100, ability.ApplyTargetBuffChance + mastery.ApplyAmount);
		ability.ApplyTargetBuffLv = 1;
	elseif ability.name == 'FlameDance'then
		ability.ApplyAct = ability.ApplyAct + math.floor( ability.ApplyAct * mastery.ApplyAmount2/100);
	elseif ability.name == 'FlameCarriage'then
		ability.DistanceAttackApplyAmountRatio = ability.DistanceAttackApplyAmountRatio * (1 + mastery.ApplyAmount2 / 100);
	elseif ability.name == 'FlameJumpKick'then
		ability.NoCoverAttackApplyAmountRatio = ability.NoCoverAttackApplyAmountRatio + mastery.ApplyAmount2;
	elseif ability.name == 'FlameBackJumpKick'then		
		ability.NotMoveAttackApplyAmountRatio = ability.NotMoveAttackApplyAmountRatio + mastery.ApplyAmount2;
	elseif ability.name == 'FlameStampKick'then
		ability.Cost = ability.Cost - math.floor( ability.Cost * mastery.ApplyAmount2/100);
	elseif ability.name == 'ResentmentOfRedLesserPanda' then
		ability.IgnoreDodge = true;
	end	
end
-- 끊임없는 단련
function ModifyAbilityChecker_Training100_Leton(mastery, ability)
	return Set.new({'WarmUp', 'Tumbling', 'Provocation', 'BodyBlow', 'IceArrow', 'IceSpear', 'Twister', 'FrostSpinkick', 'FrostDropkick', 'FrostFinalKick', 'Frostmill'})[ability.name];
end
function ModifyAbilityByMastery_Training100_Leton(ability, owner, mastery)
	if ability.name == 'WarmUp' or ability.name == 'Tumbling' or ability.name == 'Provocation' then
		ability.TurnPlayType = 'Free';
	elseif ability.name == 'BodyBlow' then
		ability.ApplyTargetBuffChance = math.min(100, ability.ApplyTargetBuffChance + mastery.ApplyAmount);
		ability.ApplyTargetBuffLv = 1;
	elseif ability.name == 'IceArrow' or ability.name == 'IceSpear' then
		ability.ApplyTargetBuffChance = math.min(100, ability.ApplyTargetBuffChance + mastery.ApplyAmount);
		ability.ApplyTargetBuffLv = 1;
	elseif ability.name == 'Twister' then
		ability.NotMoveAttackApplyAmountRatio = ability.NotMoveAttackApplyAmountRatio + mastery.ApplyAmount2;
	elseif ability.name == 'FrostSpinkick' then
		ability.NoCoverAttackApplyAmountRatio = ability.NoCoverAttackApplyAmountRatio + mastery.ApplyAmount2;
	elseif ability.name == 'FrostDropkick' or ability.name == 'FrostFinalKick' or ability.name == 'Frostmill' then
		ability.IgnoreDodge = true;
	end
end
-- 분할 정복 알고리즘
local DivideAndConquerAlgorithmTargetAbilities = {'AttackProtocol', 'AssistProtocol', 'HackingProtocol', 'MoveProtocol', 'SearchProtocol', 'DerangementProtocol', 'AttackProtocol_Piercing', 'AttackProtocol_Fire', 'AttackProtocol_Ice', 'AttackProtocol_Lightning', 'RestoreCommand', 'RepairCommand', 'AwakenCommand', 'EnhancedCommand', 'CognitiveDistractionCommand', 'ShutdownCommand', 'ControlTakeoverCommand'};
function ModifyAbilityChecker_DivideAndConquerAlgorithm(mastery, ability)
	return Set.new(DivideAndConquerAlgorithmTargetAbilities)[ability.name];
end
--[[
$Perano$공격 프로토콜$Blue_ON$
해당 어빌리티의 상태 이상 발생 확률이 $ApplyAmountValue$ 증가합니다.
$Perano$지원 프로토콜$Blue_ON$
어빌리티 적용 대상은 $MasterySubBuff$ 상태가 됩니다.
$Perano$해킹 프로토콜$Blue_ON$
해킹 성공률이 $ApplyAmountValue$ 증가합니다
$Perano$이동 프로토콜$Blue_ON$
해당 어빌리티 사용 시, $MasteryBuff$ 상태가 됩니다.
$Perano$수색 프로토콜$Blue_ON$
시야 내 수색 대상은 $MasteryThirdBuff$ 상태가 됩니다.
$Perano$교란 프로토콜$Blue_ON$
교란용 오브젝트에게 추가로 $MasteryMastery$ 특성을 부여합니다.
]]
function ModifyAbilityByMastery_DivideAndConquerAlgorithm(ability, owner, mastery)
	if Set.new({'AttackProtocol_Piercing', 'AttackProtocol_Fire', 'AttackProtocol_Ice', 'AttackProtocol_Lightning'})[ability.name] then
		ability.ApplyTargetBuffChance = ability.ApplyTargetBuffChance + mastery.ApplyAmount;
	elseif Set.new({'RestoreCommand', 'RepairCommand', 'AwakenCommand'})[ability.name] then
		ability.ApplyTargetBuffChance = 100;
		ability.ApplyTargetBuffLv = 1;
		ability.ApplyTargetBuff = GetClassList('Buff')[mastery.SubBuff.name];
	elseif ability.name == 'EnhancedCommand' then
		ability.ApplyTargetSubBuffLv = 1;
		ability.ApplyTargetSubBuff = GetClassList('Buff')[mastery.SubBuff.name];
	elseif ability.name == 'MoveProtocol' then
		ability.ApplyTargetBuffChance = 100;
		ability.ApplyTargetBuffLv = 1;
		ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
	elseif ability.name == 'SearchProtocol' then
		ability.CancelTargetBuffLv = 1;
		ability.CancelTargetBuff = GetClassList('Buff')[mastery.ThirdBuff.name];
	end
end
-- 총기 개조
function ModifyAbilityChecker_GunRemodeling(mastery, ability)
	return ability.HitRateType == 'Force' and ability.CoolTime > 0;
end
function ModifyAbilityByMastery_GunRemodeling(ability, owner, mastery)
	ModifyAbilityByMastery_CoolTime(ability, owner, mastery, 'ApplyAmount');
end
-- 응용 지식
function ModifyAbilityChecker_ApplicationKnowledge(mastery, ability)
	return ability.CoolTime > 0;
end
function ModifyAbilityByMastery_ApplicationKnowledge(ability, owner, mastery)
	ModifyAbilityByMastery_CoolTime(ability, owner, mastery, 'ApplyAmount');
end
-- 마녀의 장난
function ModifyAbilityChecker_WitchTrick(mastery, ability)
	return IsGetAbilitySubType(ability, 'ESP') and ability.ApplyTargetBuff.name == nil and (ability.Type == 'Attack' or ability.Type == 'Assist' or ability.Type == 'Heal');
end
function ModifyAbilityByMastery_WitchTrick(ability, owner, mastery)
	local abilityBuffName = (ability.Type == 'Attack') and 'WitchCurse' or 'WitchBless';
	ability.ApplyTargetBuff = GetClassList('Buff')[abilityBuffName];
	ability.ApplyTargetBuffChance = 100;
	ability.ApplyTargetBuffLv = 1;	
end
-- 아발론
function ModifyAbilityChecker_Avalon(mastery, ability)
	return ability.Cost > 0;
end
function ModifyAbilityByMastery_Avalon(ability, owner, mastery)
	local reduceRatio = mastery.ApplyAmount;
	local additiveEffect = {};
	local mastery_PromisedLand = GetMasteryMastered(GetMastery(owner), 'PromisedLand');
	if mastery_PromisedLand then
		reduceRatio = reduceRatio + mastery_PromisedLand.ApplyAmount;
		table.insert(additiveEffect, mastery_PromisedLand);
	end
	
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.Cost = math.max(0, ability.Cost - math.floor( host.Cost * reduceRatio /100));
	
	return unpack(additiveEffect);
end
-- 저전력
function ModifyAbilityChecker_MachineUnique_LowEnergy(mastery, ability)
	return ability.Cost > 0;
end
function ModifyAbilityByMastery_MachineUnique_LowEnergy(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.Cost = math.max(0, ability.Cost - math.floor( host.Cost * mastery.ApplyAmount /100));
end
-- 호환성 증가 - 시전 지연 시간
function ModifyAbilityChecker_MachineUnique_DealyCast(mastery, ability)
	return ability.CastDelay > 0;
end
function ModifyAbilityByMastery_MachineUnique_DealyCast(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount / 100));
end
-- 재빠른 손놀림
function ModifyAbilityChecker_NimbleFinger(mastery, ability)
	return ability.Type == 'Attack' and ability.HitRateType == 'Force' and (ability.Cost > 0 or ability.CastDelay > 0);
end
function ModifyAbilityByMastery_NimbleFinger(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.Cost = math.max(0, ability.Cost - math.floor( host.Cost * mastery.ApplyAmount /100));
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount / 100));
end
-- 구원의 빛
function ModifyAbilityChecker_LightOfSalvation(mastery, ability)
	return (ability.Type == 'Assist' or ability.Type == 'Heal') and (ability.Cost > 0 or ability.CastDelay > 0);
end
function ModifyAbilityByMastery_LightOfSalvation(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.Cost = math.max(0, ability.Cost - math.floor( host.Cost * mastery.ApplyAmount /100));
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount / 100));
end
-- 예리한 발톱.
function ModifyAbilityChecker_AcuteClaw(mastery, ability)
	-- ApplyTargetBuff가 없거나 다른 버프에서 출혈로 바뀐 경우에는 적용되지 않음
	local abilityCls = GetClassList('Ability')[ability.name];
	return ability.Type == 'Attack' and ability.SubType == 'Slashing' and abilityCls.ApplyTargetBuff.name == mastery.SubBuff.name and ability.ApplyTargetBuffLv > 0;
end
function ModifyAbilityByMastery_AcuteClaw(ability, owner, mastery)
	ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
end
-- 더러운 이빨
function ModifyAbilityChecker_DirtyTeeth(mastery, ability)
	-- ApplyTargetBuff가 없거나 다른 버프에서 출혈로 바뀐 경우에는 적용되지 않음
	local abilityCls = GetClassList('Ability')[ability.name];
	return ability.Type == 'Attack' and ability.SubType == 'Slashing' and abilityCls.ApplyTargetBuff.name == mastery.SubBuff.name and ability.ApplyTargetBuffLv > 0;
end
function ModifyAbilityByMastery_DirtyTeeth(ability, owner, mastery)
	ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
end
-- 강력한 돌진.
function ModifyAbilityChecker_StrongRush(mastery, ability)
	-- ApplyTargetBuff가 없거나 다른 버프에서 출혈로 바뀐 경우에는 적용되지 않음
	local abilityCls = GetClassList('Ability')[ability.name];
	return ability.Type == 'Attack' and ability.SubType == 'Blunt' and abilityCls.ApplyTargetBuff.name == mastery.SubBuff.name and ability.ApplyTargetBuffLv > 0;
end
function ModifyAbilityByMastery_StrongRush(ability, owner, mastery)
	ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
end
-- 찍어 누르기
function ModifyAbilityChecker_PushDown(mastery, ability)
	-- 물리 속성 낙하 공격
	return IsGetAbilitySubType(ability, 'Physical') and ability.HitRateType == 'Fall' and ability.Type == 'Attack';
end
function ModifyAbilityByMastery_PushDown(ability, owner, mastery)
	ability.NoCoverAttackApplyAmountRatio = ability.NoCoverAttackApplyAmountRatio + mastery.ApplyAmount;
end
-- 붉은 가시 점
function ModifyAbilityChecker_RedThornSword(mastery, ability)
	-- ApplyTargetBuff가 없거나 다른 버프에서 출혈로 바뀐 경우에는 적용되지 않음
	local abilityCls = GetClassList('Ability')[ability.name];
	return ability.Type == 'Attack' and ability.SubType == 'Slashing' and abilityCls.ApplyTargetBuff.name == mastery.SubBuff.name and ability.ApplyTargetBuffLv > 0;
end
function ModifyAbilityByMastery_RedThornSword(ability, owner, mastery)
	ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + mastery.ApplyAmount, 100);
end
-- 유혈
function ModifyAbilityChecker_Bloodlet(mastery, ability)
	-- ApplyTargetBuff가 없다가 출혈로 바뀐 경우, ApplyTargetBuff가 출혈이었다가 심한 출혈로 바뀐 경우, 총 2가지에 모두 동작하록 ability, abilityCls 2중 체크를 함
	local abilityCls = GetClassList('Ability')[ability.name];
	return ability.Type == 'Attack' and ability.SubType == 'Slashing' and ability.ApplyTargetBuff.Group == 'Bleeding';
end
function ModifyAbilityByMastery_Bloodlet(ability, owner, mastery)
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + mastery.ApplyAmount, 100);
end
-- 타박상
function ModifyAbilityChecker_Bruise(mastery, ability)
	return ability.Type == 'Attack' and ability.HitRateType == 'Melee' and ( ability.ApplyTargetBuff.name == nil or ability.ApplyTargetBuff.Group == 'Bruise');
end
function ModifyAbilityByMastery_Bruise(ability, owner, mastery)
	ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + mastery.ApplyAmount, 100);
	ability.ApplyTargetBuffLv = 1;
end
-- 얼어붙은 손길
function ModifyAbilityChecker_FrozenTouch(mastery, ability)
	return ability.Type == 'Attack' and ability.HitRateType == 'Melee' and ability.ApplyTargetBuff.name == nil;
end
function ModifyAbilityByMastery_FrozenTouch(ability, owner, mastery)
	ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + mastery.ApplyAmount, 100);
	ability.ApplyTargetBuffLv = 1;
end
-- 독 바르기
function ModifyAbilityChecker_Envenoming(mastery, ability)
	return ability.Type == 'Attack' and ability.HitRateType == 'Melee' and ( ability.ApplyTargetBuff.name == nil or ability.ApplyTargetBuff.Group == 'Poison');
end
function ModifyAbilityByMastery_Envenoming(ability, owner, mastery)
	ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + mastery.ApplyAmount, 100);
	ability.ApplyTargetBuffLv = 1;
end
-- 산성독 바르기
function ModifyAbilityChecker_Envenoming_Acid(mastery, ability)
	return ability.Type == 'Attack' and ability.HitRateType == 'Melee' and ability.ApplyTargetBuff.name == mastery.SubBuff.name and ability.ApplyTargetBuffLv > 0;
end
function ModifyAbilityByMastery_Envenoming_Acid(ability, owner, mastery)
	ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + mastery.ApplyAmount, 100);
end
-- 무쇠 주먹
function ModifyAbilityChecker_IronFist(mastery, ability)
	return ability.Type == 'Attack' and ability.HitRateType == 'Melee' and ability.ApplyTargetBuff.name == mastery.SubBuff.name and ability.ApplyTargetBuffLv > 0;
end
function ModifyAbilityByMastery_IronFist(ability, owner, mastery)
	ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + mastery.ApplyAmount, 100);
end
-- 감전
function ModifyAbilityChecker_ElectricShock(mastery, ability)
	return ability.Type == 'Attack' and ability.SubType == 'Lightning' and ability.ApplyTargetBuff.name == mastery.Buff.name and ability.ApplyTargetBuffLv > 0;
end
function ModifyAbilityByMastery_ElectricShock(ability, owner, mastery)
	local masteryTable = GetMastery(owner);
	local additiveEffect = {};
	local mastery_Generator = GetMasteryMastered(masteryTable, 'Generator');
	local electricShockRate = 0;
	if mastery_Generator then
		electricShockRate = mastery_Generator.ApplyAmount;
		table.insert(additiveEffect, mastery_Generator);
	end
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + mastery.ApplyAmount + electricShockRate, 100);
	return unpack(additiveEffect);
end
-- 고압 감전
function ModifyAbilityChecker_ElectricShockHeavy(mastery, ability)
	local abilityCls = GetClassList('Ability')[ability.name];
	return ability.Type == 'Attack' and ability.SubType == 'Lightning' and ability.ApplyTargetBuff.name == mastery.SubBuff.name and ability.ApplyTargetBuffLv > 0;
end
function ModifyAbilityByMastery_ElectricShockHeavy(ability, owner, mastery)
	ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
end
-- 울부짖는 불길
function ModifyAbilityChecker_RoaringBlaze(mastery, ability)
	local abilityCls = GetClassList('Ability')[ability.name];
	return ability.Type == 'Attack' and abilityCls.ApplyTargetBuff.name == mastery.Buff.name and ability.ApplyTargetBuffLv > 0;
end
function ModifyAbilityByMastery_RoaringBlaze(ability, owner, mastery)
	local masteryTable = GetMastery(owner);
	local additiveEffect = {};
	local mastery_DancingFlame = GetMasteryMastered(masteryTable, 'DancingFlame');
	local burnRate = 0;
	if mastery_DancingFlame then
		burnRate = mastery_DancingFlame.ApplyAmount;
		table.insert(additiveEffect, mastery_DancingFlame);
	end
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + mastery.ApplyAmount + burnRate, 100);
	return unpack(additiveEffect);
end
-- 절규하는 불길
function ModifyAbilityChecker_ScreamyBlaze(mastery, ability)
	return ability.Type == 'Attack' and ability.SubType == 'Fire' and ability.ApplyTargetBuff.name == mastery.SubBuff.name and ability.ApplyTargetBuffLv > 0;
end
function ModifyAbilityByMastery_ScreamyBlaze(ability, owner, mastery)
	ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
end
-- 서리검
function ModifyAbilityChecker_FrostSword(mastery, ability)
	return ability.Type == 'Attack' and ability.ApplyTargetBuff.name == mastery.Buff.name and ability.ApplyTargetBuffLv > 0;
end
function ModifyAbilityByMastery_FrostSword(ability, owner, mastery)
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + mastery.ApplyAmount, 100);
end
-- 절대 영도
function ModifyAbilityChecker_AbsoluteZero(mastery, ability)
	return ability.Type == 'Attack' and ability.SubType == 'Ice' and ability.ApplyTargetBuff.name == mastery.SubBuff.name and ability.ApplyTargetBuffLv > 0;
end
function ModifyAbilityByMastery_AbsoluteZero(ability, owner, mastery)
	ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
end
-- 재장전
function ModifyAbilityChecker_Reload(mastery, ability)
	return ability.Type == 'Attack' and ability.HitRateType == 'Force' and ability.CastDelay > 0;
end
function ModifyAbilityByMastery_Reload(ability, owner, mastery)
	local additiveEffect = {};
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	local applyAmount = mastery.ApplyAmount;
	-- 속사
	local mastery_QuickShot = GetMasteryMastered(GetMastery(owner), 'QuickShot');
	if mastery_QuickShot then
		applyAmount = applyAmount + mastery_QuickShot.ApplyAmount2;
		table.insert(additiveEffect, mastery_QuickShot);
	end
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * applyAmount / 100));
	return unpack(additiveEffect);
end
-- 마법 이론
function ModifyAbilityChecker_MagicTheory(mastery, ability)
	local abilityCls = GetClassList('Ability')[ability.name];
	return IsGetAbilitySubType(ability, 'ESP') and not ability.ItemAbility and ability.ApplyTargetBuff.name ~= nil and ability.ApplyTargetBuff.Type == 'Debuff' and ability.ApplyTargetBuffLv > 0 and abilityCls.ApplyTargetBuffChance < 100;
end
function ModifyAbilityByMastery_MagicTheory(ability, owner, mastery)
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + mastery.ApplyAmount, 100);
end
-- 마력 가속기
function ModifyAbilityChecker_SpellAccelerator(mastery, ability)
	return IsGetAbilitySubType(ability, 'ESP') and not ability.ItemAbility and ability.CastDelay > 0;
end
function ModifyAbilityByMastery_SpellAccelerator(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount / 100));
end
-- 대마녀
function ModifyAbilityChecker_ArchWitch(mastery, ability)
	return IsGetAbilitySubType(ability, 'ESP') and not ability.ItemAbility and ability.CastDelay > 0;
end
function ModifyAbilityByMastery_ArchWitch(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount2 / 100));
end
-- 날카로운 이빨
function ModifyAbilityChecker_SharpTeeth(mastery, ability)
	local abilityCls = GetClassList('Ability')[ability.name];
	return IsGetAbilitySubType(ability, 'Slashing') and not ability.ItemAbility and ability.ApplyTargetBuff.name ~= nil and ability.ApplyTargetBuff.Type == 'Debuff' and ability.ApplyTargetBuffLv > 0 and abilityCls.ApplyTargetBuffChance < 100;
end
function ModifyAbilityByMastery_SharpTeeth(ability, owner, mastery)
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + mastery.ApplyAmount, 100);
end
-- 묵직한 몸통.
function ModifyAbilityChecker_HeavyBody(mastery, ability)
	local abilityCls = GetClassList('Ability')[ability.name];
	return IsGetAbilitySubType(ability, 'Blunt') and not ability.ItemAbility and ability.ApplyTargetBuff.name ~= nil and ability.ApplyTargetBuff.Type == 'Debuff' and ability.ApplyTargetBuffLv > 0 and abilityCls.ApplyTargetBuffChance < 100;
end
function ModifyAbilityByMastery_HeavyBody(ability, owner, mastery)
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + mastery.ApplyAmount, 100);
end
-- 냉정한 야수
function ModifyAbilityChecker_CoolBeast(mastery, ability)
	return ability.Type == 'Attack' and ability.Cost > 0;
end
function ModifyAbilityByMastery_CoolBeast(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.Cost = math.max(0, ability.Cost - math.floor( host.Cost * mastery.ApplyAmount /100));
end
-- 멀리 던지기
function ModifyAbilityChecker_Outthrow(mastery, ability)
	return ability.Type == 'Attack' and ability.HitRateType == 'Throw';
end
function ModifyAbilityByMastery_Outthrow(ability, owner, mastery)
	local rangeCls = GetClassList('Range')[ability.TargetRange];
	ability.TargetRange = rangeCls.ExpandedRange or ability.TargetRange;
end
-- 총열 강화.
function ModifyAbilityChecker_GunbarrelEnhancement(mastery, ability)
	return ability.Type == 'Attack' and ability.HitRateType == 'Force';
end
function ModifyAbilityByMastery_GunbarrelEnhancement(ability, owner, mastery)
	local GetExpandRange = function(rangeType)
		local rangeCls = GetClassList('Range')[rangeType];
		return rangeCls.ExpandedRange or rangeType;
	end
	ability.TargetRange = GetExpandRange(ability.TargetRange);
	if ability.Target == 'Self' or ability.Target == 'Ground' or ability.Target == 'EmptyGround' then
		ability.ApplyRange = GetExpandRange(ability.ApplyRange);
		ability.GuideRange = GetExpandRange(ability.GuideRange);
	end
end
-- 빨리 던지기.
function ModifyAbilityChecker_Quickthrow(mastery, ability)
	return ability.Type == 'Attack' and ability.HitRateType == 'Throw';
end
function ModifyAbilityByMastery_Quickthrow(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.Cost = math.max(0, ability.Cost - math.floor( host.Cost * mastery.ApplyAmount /100));
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount / 100));
end
-- 지원 모듈 - 오버클러킹
function ModifyAbilityChecker_Module_Overclocking(mastery, ability)
	return ability.CastDelay > 0;
end
function ModifyAbilityByMastery_Module_Overclocking(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.Cost = ability.Cost + math.floor( host.Cost * mastery.ApplyAmount /100);
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount2 / 100));
end
-- 관통 사격
function ModifyAbilityChecker_PiercingShot(mastery, ability)
	return ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Piercing') and ( ability.ApplyTargetBuff.name == nil or ability.ApplyTargetBuff.Group == 'Bleeding');
end
function ModifyAbilityByMastery_PiercingShot(ability, owner, mastery)
	if not ability.ApplyTargetBuff.name then
		ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
	end
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + mastery.ApplyAmount, 100);
	ability.ApplyTargetBuffLv = 1;
end
-- 핏빛 탄환
function ModifyAbilityChecker_BloodBullet(mastery, ability)
	return ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Piercing') and ability.ApplyTargetBuff.name == mastery.SubBuff.name and ability.ApplyTargetBuffLv > 0;
end
function ModifyAbilityByMastery_BloodBullet(ability, owner, mastery)
	ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + mastery.ApplyAmount, 100);
end
-- 물약 강화
function ModifyAbilityChecker_EnhancedPotion(mastery, ability)
	return ability.Type == 'Heal' and ability.ItemAbility;
end
function ModifyAbilityByMastery_EnhancedPotion(ability, owner, mastery)
	local additiveEffect = {};
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.ApplyAmountChangeStep[1] = ability.ApplyAmountChangeStep[1] + math.floor(host.ApplyAmountChangeStep[1] * mastery.ApplyAmount / 100);
	ability.MaxUseCount = ability.MaxUseCount + mastery.ApplyAmount2;
	local mastery_GoodPotion = GetMasteryMastered(GetMastery(owner), 'GoodPotion');
	
	if mastery_GoodPotion then
		ability.MaxUseCount = ability.MaxUseCount + mastery_GoodPotion.ApplyAmount;
		table.insert(additiveEffect, mastery_GoodPotion);
	end
	
	return unpack(additiveEffect);
end
-- 강화 수류탄
function ModifyAbilityChecker_EnhancedGrenade(mastery, ability)
	return (ability.Type == 'Attack' or ability.Type == 'Assist') and ability.ItemAbility and ability.ItemType == 'Grenade';
end
function ModifyAbilityByMastery_EnhancedGrenade(ability, owner, mastery)
	if ability.Type == 'Attack' then
		local abilityCls = GetClassList('Ability')[ability.name];
		ability.ApplyAmountChangeStep[1] = ability.ApplyAmountChangeStep[1] + math.floor(abilityCls.ApplyAmountChangeStep[1] * mastery.ApplyAmount / 100);
	elseif ability.Type == 'Assist' then
		local GetExpandRange = function(rangeType)
			local rangeCls = GetClassList('Range')[rangeType];
			return rangeCls.ExpandedRange or rangeType;
		end
		ability.ApplyRange = GetExpandRange(ability.ApplyRange);
		ability.GuideRange = GetExpandRange(ability.GuideRange);
		ability.PickingRange = GetExpandRange(ability.PickingRange);
		for _, info in ipairs(ability.ApplyFieldEffects) do
			info.Range = GetExpandRange(info.Range);
		end
	end
	ability.MaxUseCount = ability.MaxUseCount + mastery.ApplyAmount2;
end
-- 이능력 유전자
function ModifyAbilityChecker_ElementalGene(mastery, ability)
	return ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'ESP');
end
function ModifyAbilityByMastery_ElementalGene(ability, owner, mastery)
	local abilityCls = GetClassList('Ability')[ability.name];
	ability.ApplyAmountChangeStep[1] = ability.ApplyAmountChangeStep[1] + math.floor(abilityCls.ApplyAmountChangeStep[1] * mastery.ApplyAmount / 100);
end
-- 능숙한 지원
function ModifyAbilityChecker_SupportExpert(mastery, ability)
	return ability.Type == 'Assist' or ability.Type == 'Heal';
end
function ModifyAbilityByMastery_SupportExpert(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.Cost = math.max(0, ability.Cost - math.floor( host.Cost * mastery.ApplyAmount /100));
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount / 100));
end
-- 충격파
function ModifyAbilityChecker_Shockwave(mastery, ability)
	return ability.Type == 'Attack' and ability.HitRateType == 'Throw';
end
-- 높이 던지기
function ModifyAbilityChecker_ThrowHigh(mastery, ability)
	return ability.Type == 'Attack' and ability.HitRateType == 'Throw';
end
-- 아이템 슬롯 체크
function GetAbilityItemSlot(ability, owner)
	local itemSlotList = GetItemSlotList();
	for _, itemSlot in ipairs(itemSlotList) do
		if owner[itemSlot].Ability == ability then
			return itemSlot;
		end
	end
	return nil;
end
-- 넓은 상의 주머니
function ModifyAbilityChecker_LargeTopPocket(mastery, ability, owner)
	return GetAbilityItemSlot(ability, owner) == 'Inventory1';
end
-- 넓은 하의 주머니
function ModifyAbilityChecker_LargeBottomPocket(mastery, ability, owner)
	return GetAbilityItemSlot(ability, owner) == 'Inventory2';
end
-- 군용 주머니
function ModifyAbilityChecker_MilitaryBag(mastery, ability, owner)
	return GetAbilityItemSlot(ability, owner) == 'Inventory1' or GetAbilityItemSlot(ability, owner) == 'Inventory2';
end
-- 황금에 대한 열정
function ModifyAbilityChecker_PassionForGold(mastery, ability, owner)
	return GetAbilityItemSlot(ability, owner) == 'AlchemyBag';
end
-- 완벽주의자
function ModifyAbilityChecker_Perfectionist(mastery, ability, owner)
	return GetAbilityItemSlot(ability, owner) == 'GrenadeBag';
end
-- 확장팩
function ModifyAbilityChecker_ExpansionPack(mastery, ability, owner)
	local targets = { 'SprayHeal', 'SprayVigor', 'SprayCharging' };
	return table.find(targets, ability.name) ~= nil;
end
-- 영웅 FHD 스트레이 
function ModifyAbilityChecker_Brush_Boom_FHD_Epic(mastery, ability, owner)
	local targets = { 'SprayHeal', 'SprayVigor', 'SprayCharging' };
	return table.find(targets, ability.name) ~= nil;
end
function ModifyAbilityChecker_Brush_Red_FHD_Epic(mastery, ability, owner)
	local targets = { 'SprayHeal', 'SprayVigor', 'SprayCharging' };
	return table.find(targets, ability.name) ~= nil;
end
function ModifyAbilityChecker_Brush_White_FHD_Epic(mastery, ability, owner)
	local targets = { 'SprayHeal', 'SprayVigor', 'SprayCharging' };
	return table.find(targets, ability.name) ~= nil;
end
-- 영웅 QHD 스트레이 
function ModifyAbilityChecker_Brush_Boom_QHD_Epic(mastery, ability, owner)
	return ability.Type == 'Attack' and ability.CastDelay > 0;
end
function ModifyAbilityChecker_Brush_Green_QHD_Epic(mastery, ability, owner)
	return ability.Type == 'Attack' and ability.CastDelay > 0;
end
-- 흑철 가죽 구두
function ModifyAbilityChecker_DressShoes_BlackIronEnhanced(mastery, ability, owner)
	return ability.Type == 'Attack' and ability.CastDelay > 0;
end
function ModifyAbilityChecker_DressShoes_BlackIronEnhanced_Rare(mastery, ability, owner)
	return ability.Type == 'Attack' and ability.CastDelay > 0;
end
function ModifyAbilityChecker_DressShoes_BlackIronEnhanced_Epic(mastery, ability, owner)
	return ability.Type == 'Attack' and ability.CastDelay > 0;
end
-- 모노앤비비
function ModifyAbilityChecker_Drone_MonoAndVivi_V2(mastery, ability, owner)
	return ability.Type == 'Attack' and IsProtocolAbility(ability);
end
function ModifyAbilityChecker_Drone_MonoAndVivi_V3(mastery, ability, owner)
	return ability.Type == 'Attack' and IsProtocolAbility(ability);
end
function ModifyAbilityChecker_Drone_MonoAndVivi_V4(mastery, ability, owner)
	return ability.Type == 'Attack' and IsProtocolAbility(ability);
end
function ModifyAbilityChecker_Drone_MonoAndVivi_V5(mastery, ability, owner)
	return ability.Type == 'Attack' and IsProtocolAbility(ability);
end
function ModifyAbilityChecker_Drone_MonoAndVivi_M2(mastery, ability, owner)
	return ability.Type == 'Assist' and IsProtocolAbility(ability);
end
function ModifyAbilityChecker_Drone_MonoAndVivi_M3(mastery, ability, owner)
	return ability.Type == 'Assist' and IsProtocolAbility(ability);
end
function ModifyAbilityChecker_Drone_MonoAndVivi_M4(mastery, ability, owner)
	return ability.Type == 'Assist' and IsProtocolAbility(ability);
end
function ModifyAbilityChecker_Drone_MonoAndVivi_M5(mastery, ability, owner)
	return ability.Type == 'Assist' and IsProtocolAbility(ability);
end
-- 흑철 가죽 구두
function ModifyAbilityChecker_DressShoes_BlackIronEnhanced(mastery, ability, owner)
	return ability.Type == 'Attack' and ability.CastDelay > 0;
end
function ModifyAbilityChecker_DressShoes_BlackIronEnhanced_Rare(mastery, ability, owner)
	return ability.Type == 'Attack' and ability.CastDelay > 0;
end
function ModifyAbilityChecker_DressShoes_BlackIronEnhanced_Epic(mastery, ability, owner)
	return ability.Type == 'Attack' and ability.CastDelay > 0;
end
-- 흑철 가죽 코트
function ModifyAbilityChecker_Coat_BlackIronEnhanced(mastery, ability, owner)
	return ability.CastDelay > 0;
end
function ModifyAbilityChecker_Coat_BlackIronEnhanced_Rare(mastery, ability, owner)
	return ability.CastDelay > 0;
end
function ModifyAbilityChecker_Coat_BlackIronEnhanced_Ice_Epic(mastery, ability, owner)
	return ability.CastDelay > 0;
end
function ModifyAbilityChecker_Coat_BlackIronEnhanced_Fire_Epic(mastery, ability, owner)
	return ability.CastDelay > 0;
end
function ModifyAbilityChecker_Coat_BlackIronEnhanced_Lightning_Epic(mastery, ability, owner)
	return ability.CastDelay > 0;
end
-- 바람 마녀
function ModifyAbilityChecker_WindWitch(mastery, ability, owner)
	-- ModifyAbility가 Custom이 아니면 퉅팁에 자동으로 들어가버린다. 일단 기존 어빌리티 툴팁 유지를 위해 Custom으로....
	return ability.name == 'WindChain';
end
-- 백열
function ModifyAbilityChecker_WhiteHeat(mastery, ability)
	return ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Earth') and ability.ApplyTargetBuff.name == nil;
end
function ModifyAbilityByMastery_WhiteHeat(ability, owner, mastery)
	local additiveEffect = {};
	local applyAmount = mastery.ApplyAmount;
	local masteryTable = GetMastery(owner)
	-- 세트효과 번쩍이는 빛 
	local mastery_TwinkleLight = GetMasteryMastered(masteryTable, 'TwinkleLight');
	if mastery_TwinkleLight then
		applyAmount = applyAmount + mastery_TwinkleLight.ApplyAmount;
		table.insert(additiveEffect, mastery_TwinkleLight);
	end
	local mastery_StrongLight = GetMasteryMastered(masteryTable, 'StrongLight');
	if mastery_StrongLight then
		applyAmount = applyAmount + mastery_StrongLight.ApplyAmount;
		table.insert(additiveEffect, mastery_StrongLight);
	end
	ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + applyAmount, 100);
	ability.ApplyTargetBuffLv = 1;
	return unpack(additiveEffect);
end
-- 노련한 사냥꾼
function ModifyAbilityChecker_ExpertHunter(mastery, ability)
	local abilityCls = GetClassList('Ability')[ability.name];
	return (ability.Type == 'Assist' or ability.ItemAbility) and (abilityCls.TurnPlayType == 'Main' or abilityCls.TurnPlayType == 'Half' or abilityCls.IsUseCount);
end
function ModifyAbilityByMastery_ExpertHunter(ability, owner, mastery)
	if ability.TurnPlayType == 'Main' then
		ability.TurnPlayType = 'Half';
	elseif ability.TurnPlayType == 'Half' then
		ability.TurnPlayType = 'Free';
	end
	if ability.IsUseCount then
		ability.MaxUseCount = ability.MaxUseCount + mastery.ApplyAmount2;
	end
end
-- 정밀한 저격
function ModifyAbilityChecker_DetailedSnipe(mastery, ability)
	return ability.Type == 'Attack' and ability.HitRateType == 'Force' and ability.TargetType == 'Single' and IsGetAbilitySubType(ability, 'Piercing');
end
function ModifyAbilityByMastery_DetailedSnipe(ability, owner, mastery)
	ability.AbilitySubMenu = 'DetailedSnipe';
end
-- 거미줄 뿌리기
function ModifyAbilityChecker_SpreadFallWeb(mastery, ability)
	return ability.name == 'FallWeb' or ability.name == 'FallWeb_Strong' or ability.name == 'FallWeb_Strong_Posion' or ability.name == 'FallWeb_Strong_Acid';
end
function ModifyAbilityByMastery_SpreadFallWeb(ability, owner, mastery)
	ability.ApplyFieldEffects[1].Prob = 100;
end
-- 불타는 날갯짓
function ModifyAbilityChecker_BlazingWingStroke(mastery, ability)
	return ability.Type == 'Attack';
end
function ModifyAbilityByMastery_BlazingWingStroke(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.Cost = math.max(0, ability.Cost - math.floor( host.Cost * mastery.ApplyAmount / 100));
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount /100));
end
-- 폭풍 날갯짓
function ModifyAbilityChecker_WindWingStroke(mastery, ability)
	return ability.Type == 'Assist';
end
function ModifyAbilityByMastery_WindWingStroke(ability, owner, mastery)
	if ability.TurnPlayType == 'Main' then
		ability.TurnPlayType = 'Half';
	elseif ability.TurnPlayType == 'Half' then
		ability.TurnPlayType = 'Free';
	end
end
-- 덫 사냥꾼
function ModifyAbilityChecker_TrapHunter(mastery, ability)
	return Set.new({'FireTrap', 'IceTrap', 'LightningTrap', 'PoisonTrap', 'LightTrap'})[ability.name];
end
function ModifyAbilityByMastery_TrapHunter(ability, owner, mastery)
	-- 이건 가라고 실제 적용되는 기능은 다른곳에서 됨
	ability.ApplyAct = mastery.ApplyAmount;
	ability.ApplyTargetSubBuff = GetClassList('Buff')[mastery.Buff.name];
	ability.ApplyTargetSubBuffChance = mastery.ApplyAmount2;
	ability.ApplyTargetSubBuffLv = 1;
end
-- 코드 최적화.
function ModifyAbilityChecker_CodeOptimization(mastery, ability)
	return IsProtocolAbility(ability);
end
function ModifyAbilityByMastery_CodeOptimization(ability, owner, mastery)
	if ability.TurnPlayType == 'Main' then
		ability.TurnPlayType = 'Half';
	elseif ability.TurnPlayType == 'Half' then
		ability.TurnPlayType = 'Free';
	end
end
-- 최단 경로 알고리즘
function ModifyAbilityChecker_Algorithm(mastery, ability)
	return IsProtocolAbility(ability);
end
function ModifyAbilityByMastery_Algorithm(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	local removeDelay = math.floor(host.CastDelay * mastery.ApplyAmount2 * math.floor(mastery.CustomCacheData / mastery.ApplyAmount) / 100);
	ability.CastDelay = math.max(ability.CastDelay - removeDelay, 0);
end
-- 추가 프로토콜
function ModifyAbilityChecker_AdditionalProtocol(mastery, ability)
	return IsProtocolAbility(ability) and ability.IsUseCount;
end
function ModifyAbilityByMastery_AdditionalProtocol(ability, owner, mastery)
	ability.MaxUseCount = ability.MaxUseCount + mastery.ApplyAmount;
end
-- 확장 프로토콜
function ModifyAbilityChecker_ExpandProtocol(mastery, ability)
	return IsProtocolAbility(ability) and ability.IsUseCount;
end
function ModifyAbilityByMastery_ExpandProtocol(ability, owner, mastery)
	ability.MaxUseCount = ability.MaxUseCount + mastery.ApplyAmount;
end
-- 초유체 제어 AI
function ModifyAbilityChecker_EnhancedCoolertAI(mastery, ability)
	return ability.CastDelay > 0 or ability.CoolTime > 0;
end
function ModifyAbilityByMastery_EnhancedCoolertAI(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	
	if ability.CastDelay > 0 then
		ability.CastDelay = math.max(0, ability.CastDelay - math.floor(host.CastDelay * mastery.ApplyAmount /100));
	end
	ModifyAbilityByMastery_CoolTime(ability, owner, mastery, 'ApplyAmount2');
end
-- 열역학
function ModifyAbilityChecker_Thermodynamics(mastery, ability)
	return ability.Cost > 0;
end
function ModifyAbilityByMastery_Thermodynamics(ability, owner, mastery)
	ability.Cost = math.max(ability.Cost - mastery.ApplyAmount, 0);
end
-- 에너지 최적화 AI
function ModifyAbilityChecker_EnhancedConveterAI(mastery, ability)
	return ability.Cost > 0;
end
function ModifyAbilityByMastery_EnhancedConveterAI(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	local removeCost = math.floor(host.Cost * mastery.ApplyAmount / 100);
	ability.Cost = math.max(0, ability.Cost - removeCost);
end
-- 다중 처리 OS
function ModifyAbilityChecker_Windows(mastery, ability)
	return ability.CastDelay > 0;
end
function ModifyAbilityByMastery_Windows(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	local addCost = math.floor(host.Cost * mastery.ApplyAmount2 * math.floor(mastery.CustomCacheData / mastery.ApplyAmount) / 100);
	ability.Cost = ability.Cost + addCost;
	local removeDelay = math.floor(host.CastDelay * mastery.ApplyAmount3 * math.floor(mastery.CustomCacheData / mastery.ApplyAmount) / 100);
	ability.CastDelay = math.max(0, ability.CastDelay - removeDelay);
end
-- 개방형 OS
function ModifyAbilityChecker_Linux(mastery, ability)
	return ability.Cost > 0;
end
function ModifyAbilityByMastery_Linux(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	local addCost = -1 * math.floor(host.Cost * mastery.ApplyAmount2 * math.floor(mastery.CustomCacheData / mastery.ApplyAmount) / 100);
	ability.Cost = math.max(0, ability.Cost + addCost);
end
-- 무기 출력 강화
function ModifyAbilityChecker_Module_EnhancedWeaponPower(mastery, ability)
	return ability.Type == 'Attack';
end
function ModifyAbilityByMastery_Module_EnhancedWeaponPower(ability, owner, mastery)
	if GetWithoutError(ability.AdditionalApplyAmount, 'AttackPower') then
		ability.AdditionalApplyAmount.AttackPower = ability.AdditionalApplyAmount.AttackPower + mastery.ApplyAmount2;
	end
	if GetWithoutError(ability.AdditionalApplyAmount, 'ESPPower') then
		ability.AdditionalApplyAmount.ESPPower = ability.AdditionalApplyAmount.ESPPower + mastery.ApplyAmount2;
	end
	ability.Cost = math.floor(ability.Cost * (1 + mastery.ApplyAmount / 100));
end
-- 무기 조준 강화
function ModifyAbilityChecker_Module_EnhancedWeaponAim(mastery, ability)
	return ability.Type == 'Attack';
end
function ModifyAbilityByMastery_Module_EnhancedWeaponAim(ability, owner, mastery)
	ability.Accuracy = ability.Accuracy + mastery.ApplyAmount2;
	ability.CriticalStrikeChance = ability.CriticalStrikeChance + mastery.ApplyAmount2;
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.Cost = ability.Cost + math.floor(host.Cost * mastery.ApplyAmount / 100);
end
-- 여분의 부품
function ModifyAbilityChecker_SpareParts(mastery, ability)
	return ability.ItemAbility or IsProtocolAbility(ability);
end
function ModifyAbilityByMastery_SpareParts(ability, owner, mastery)
	ModifyAbilityByMastery_MaxUseCount(ability, owner, mastery);
end
-- 정보 제어
local InformationControlTargetAbilities = {'HackingProtocol', 'SearchProtocol', 'DerangementProtocol', 'CognitiveDistractionCommand', 'ShutdownCommand', 'ControlTakeoverCommand'};
function ModifyAbilityChecker_InformationControl(mastery, ability)
	return Set.new(InformationControlTargetAbilities)[ability.name];
end
function ModifyAbilityByMastery_InformationControl(ability, owner, mastery)
	if Set.new({'CognitiveDistractionCommand', 'ShutdownCommand', 'ControlTakeoverCommand'})[ability.name] then
		ability.ApplyTargetSubBuff = GetClassList('Buff')[mastery.SubBuff.name];
		ability.ApplyTargetSubBuffLv = 1;
	elseif ability.name == 'SearchProtocol' then
		ability.ApplyTargetSubBuff = GetClassList('Buff')[mastery.Buff.name];
	end
end
-- 무기 호환성 - 견제 사격
function ModifyAbilityChecker_AttackSupportDevice_AimAssist_Rare(mastery, ability, owner)
	return SafeIndex(owner, 'Weapon', 'Type', 'name') == 'OuterDevice_FlameThrower' and ability.name == mastery.Ability;
end
function ModifyAbilityByMastery_AttackSupportDevice_AimAssist_Rare(ability, owner, mastery)
	ability.Active = false;
end
function ModifyAbilityChecker_AttackSupportDevice_AimAssist_Epic(mastery, ability, owner)
	return SafeIndex(owner, 'Weapon', 'Type', 'name') == 'OuterDevice_FlameThrower' and ability.name == mastery.Ability;
end
function ModifyAbilityByMastery_AttackSupportDevice_AimAssist_Epic(ability, owner, mastery)
	ability.Active = false;
end
-- 리펙토링
function ModifyAbilityChecker_CodeRefactoring(mastery, ability, owner)
	return IsProtocolAbility(ability);
end
function ModifyAbilityByMastery_CodeRefactoring(ability, owner, mastery)
	ModifyAbilityByMastery_CoolTime(ability, owner, mastery);
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.Cost = math.max(0, ability.Cost - math.floor( host.Cost * mastery.ApplyAmount2 /100));
end
-- 다중 연산장치
function ModifyAbilityChecker_MultipleCalculator(mastery, ability, owner)
	return ability.name == 'ControlTakeoverCommand' or ability.name == 'SummonMachine';
end
function ModifyAbilityByMastery_MultipleCalculator(ability, owner, mastery)
	ability.MaxUseCount = ability.MaxUseCount + mastery.ApplyAmount;
	ability.IsUseCount = true;
end
-- 괴수 길들이기
function ModifyAbilityChecker_MonsterTame(mastery, ability, owner)
	return ability.name == 'Tame';
end
function ModifyAbilityByMastery_MonsterTame(ability, owner, mastery)
	ability.Grade = GetClassList('MonsterGrade').Legend;
end
-- 휘몰아치는 바람
function ModifyAbilityChecker_RagingWind(mastery, ability)
	return ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Wind') and ability.ApplyTargetBuff.name == nil;
end
function ModifyAbilityByMastery_RagingWind(ability, owner, mastery)
	local additiveEffect = {};
	local applyAmount = mastery.ApplyAmount;
	-- 돌풍
	local mastery_Squall = GetMasteryMastered(GetMastery(owner), 'Squall');
	if mastery_Squall then
		applyAmount = applyAmount + mastery_Squall.ApplyAmount2;
		table.insert(additiveEffect, mastery_Squall);
	end
	ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + applyAmount, 100);
	ability.ApplyTargetBuffLv = 1;
	return unpack(additiveEffect);
end
-- 회오리바람
function ModifyAbilityChecker_Whirlwind(mastery, ability)
	return ability.Type == 'Attack' and ability.SubType == 'Wind' and ability.ApplyTargetBuff.name == mastery.SubBuff.name and ability.ApplyTargetBuffLv > 0;
end
function ModifyAbilityByMastery_Whirlwind(ability, owner, mastery)
	ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
end
-- 보조 제어 프로그램
function ModifyAbilityChecker_Module_SubControl(mastery, ability)
	return ability.CastDelay > 0;
end
function ModifyAbilityByMastery_Module_SubControl(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	local removeDelay = math.floor(host.CastDelay * mastery.ApplyAmount2 * math.floor(mastery.CustomCacheData / mastery.ApplyAmount) / 100);
	ability.CastDelay = math.max(0, ability.CastDelay - removeDelay);
end
-- 고급 연료
function ModifyAbilityChecker_Module_GoodEnergy(mastery, ability)
	return ability.Cost > 0;
end
function ModifyAbilityByMastery_Module_GoodEnergy(ability, owner, mastery)
	local additiveEffect = {};
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	local applyAmount = mastery.ApplyAmount;
	-- 연비 강화 프로그램
	local mastery_Module_FuelEnhancement = GetMasteryMastered(GetMastery(owner), 'Module_FuelEnhancement');
	if mastery_Module_FuelEnhancement then
		applyAmount = applyAmount + mastery_Module_FuelEnhancement.ApplyAmount;
		table.insert(additiveEffect, mastery_Module_FuelEnhancement);
	end
	local addCost = -1 * math.floor(host.Cost * applyAmount / 100);
	ability.Cost = math.max(0, ability.Cost + addCost);
	return unpack(additiveEffect);
end
-- 구동 호환성 - 고속
function ModifyAbilityChecker_DrivingDevice_HoverSpeed_Epic(mastery, ability, owner)
	return owner.Info.name == 'Drone_Speed' and ability.Cost > 0;
end
function ModifyAbilityByMastery_DrivingDevice_HoverSpeed_Epic(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	local addCost = -1 * math.floor(host.Cost * mastery.ApplyAmount / 100);
	ability.Cost = math.max(0, ability.Cost + addCost);
end
-- 연료 호환성 - 수송
function ModifyAbilityChecker_Fuel_Industrial_Big(mastery, ability, owner)
	return owner.Info.name == 'Drone_Transport' and ability.Cost > 0;
end
function ModifyAbilityChecker_Fuel_Industrial_Middle(mastery, ability, owner)
	return owner.Info.name == 'Drone_Transport' and ability.Cost > 0;
end
function ModifyAbilityByMastery_Fuel_Transport(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	local addCost = -1 * math.floor(host.Cost * mastery.ApplyAmount / 100);
	ability.Cost = math.max(0, ability.Cost + addCost);
end
-- 쾌속검
function ModifyAbilityChecker_MagicSwordControl(mastery, ability)
	return ability.Type == 'Attack';
end
function ModifyAbilityByMastery_MagicSwordControl(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount / 100));
end
-- 프로 정신
function ModifyAbilityChecker_Professionalism(mastery, ability)
	return ( ability.Type == 'Attack' or ability.Type == 'Assist' ) and (ability.Cost > 0 or ability.CastDelay > 0);
end
function ModifyAbilityByMastery_Professionalism(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.Cost = math.max(0, ability.Cost - math.floor( host.Cost * mastery.ApplyAmount /100));
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount / 100));
end
-- 능숙한 신체 제어
function ModifyAbilityChecker_GoodBodyControl(mastery, ability)
	return ability.Type == 'Attack' and ability.CastDelay > 0;
end
function ModifyAbilityByMastery_GoodBodyControl(ability, owner, mastery)
	local additiveEffect = {};
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	local applyAmount = mastery.ApplyAmount;
	-- 이능 제어 훈련
	local mastery_ESPControlTraining = GetMasteryMastered(GetMastery(owner), 'ESPControlTraining');
	if mastery_ESPControlTraining then
		local cacheData = mastery_ESPControlTraining.CustomCacheData['GoodBodyControl'];
		applyAmount = applyAmount + math.floor(cacheData / mastery_ESPControlTraining.ApplyAmount2) * mastery_ESPControlTraining.ApplyAmount4;
		table.insert(additiveEffect, mastery_ESPControlTraining);
	end
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor(host.CastDelay * applyAmount / 100));
	return unpack(additiveEffect);
end
-- 서리 요새
function ModifyAbilityChecker_FortressOfFrost(mastery, ability)
	return ability.name == 'IronWall';
end
function ModifyAbilityByMastery_FortressOfFrost(ability, owner, mastery)
	ability.Active = false;
end
-- 전사의 계승자
function ModifyAbilityChecker_SuccessorOfWarrior(mastery, ability)
	return ability.name == 'Tima_AttackMode' or ability.name == 'Tima_ChaserMode';
end
function ModifyAbilityByMastery_SuccessorOfWarrior(ability, owner, mastery)
	ability.Active = false;
end
-- 수호자의 계승자
function ModifyAbilityChecker_SuccessorOfGuardian(mastery, ability)
	return ability.name == 'Tima_DefenceMode' or ability.name == 'Tima_CheckMode';
end
function ModifyAbilityByMastery_SuccessorOfGuardian(ability, owner, mastery)
	ability.Active = false;
end
-- 백병기 전문가
function ModifyAbilityChecker_WhiteWeaponMaster(mastery, ability)
	return ability.Type == 'Attack' and ability.HitRateType == 'Melee';
end
function ModifyAbilityByMastery_WhiteWeaponMaster(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.ApplyAmountChangeStep[1] = ability.ApplyAmountChangeStep[1] + math.floor(host.ApplyAmountChangeStep[1] * mastery.ApplyAmount / 100);
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount / 100));
end
-- 갈음질
function ModifyAbilityChecker_Sharpening(mastery, ability)
	return ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Slashing');
end
function ModifyAbilityByMastery_Sharpening(ability, owner, mastery)
	local abilityCls = GetClassList('Ability')[ability.name];
	ability.ApplyAmountChangeStep[1] = ability.ApplyAmountChangeStep[1] + math.floor(abilityCls.ApplyAmountChangeStep[1] * mastery.ApplyAmount / 100);
end
--  에스트로 기사단 팔찌
function ModifyAbilityChecker_Bangle_Etros_Special(mastery, ability)
	return ModifyAbilityChecker_ESPAccelerator(mastery, ability);
end
function ModifyAbilityChecker_Bangle_Etros_Special_Rare(mastery, ability)
	return ModifyAbilityChecker_ESPAccelerator(mastery, ability);
end
function ModifyAbilityChecker_Bangle_Etros_Special_Epic(mastery, ability)
	return ModifyAbilityChecker_ESPAccelerator(mastery, ability);
end
-- 보석 세공사 팔찌
function ModifyAbilityChecker_Bangle_JewelCollector_Set(mastery, ability)
	return ModifyAbilityChecker_ESPAccelerator(mastery, ability);
end
function ModifyAbilityChecker_ESPAccelerator(mastery, ability)
	return ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'ESP') and ability.CastDelay > 0;
end
function ModifyAbilityByMastery_ESPAccelerator(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount / 100));
end
-- 베이비 A
function ModifyAbilityChecker_MachinePistol_BabyA_Uncommon(mastery, ability)
	return ModifyAbilityChecker_ShootPiercingAccelerator(mastery, ability);
end
function ModifyAbilityChecker_MachinePistol_BabyA_Rare(mastery, ability)
	return ModifyAbilityChecker_ShootPiercingAccelerator(mastery, ability);
end
function ModifyAbilityChecker_MachinePistol_BabyA_Epic(mastery, ability)
	return ModifyAbilityChecker_ShootPiercingAccelerator(mastery, ability);
end
function ModifyAbilityChecker_ShootPiercingAccelerator(mastery, ability)
	return ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Piercing') and ability.HitRateType == 'Force' and ability.CastDelay > 0;
end
function ModifyAbilityByMastery_ShootPiercingAccelerator(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount / 100));
end
-- 추출업자 자켓
function ModifyAbilityChecker_Jacket_Extractor_Set(mastery, ability)
	return ModifyAbilityChecker_ExtractorUseCount(mastery, ability);
end
-- 추출업자 코트
function ModifyAbilityChecker_Coat_Extractor_Set(mastery, ability)
	return ModifyAbilityChecker_ExtractorUseCount(mastery, ability);
end
function ModifyAbilityChecker_ExtractorUseCount(mastery, ability)
	return ability.Type == 'Interaction' and ability.ApplyTargetDetail == 'InvestigatePsionicStone' and ability.IsUseCount;
end
function ModifyAbilityByMastery_ExtractorUseCount(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.MaxUseCount = ability.MaxUseCount + mastery.ApplyAmount;
end
-- 끓어오르는 독
function ModifyAbilityChecker_BoilingPoison(mastery, ability)
	return ability.Type == 'Attack' and ability.SubType == 'Water' and ability.ApplyTargetBuff.name == mastery.Buff.name and ability.ApplyTargetBuffLv > 0;
end
function ModifyAbilityByMastery_BoilingPoison(ability, owner, mastery)
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + mastery.ApplyAmount, 100);
end
-- 오래된 감염
function ModifyAbilityChecker_LongTimeinfection(mastery, ability)
	return ability.Type == 'Attack' and ability.SubType == 'Earth' and ability.ApplyTargetBuff.name == mastery.SubBuff.name and ability.ApplyTargetBuffLv > 0;
end
function ModifyAbilityByMastery_LongTimeinfection(ability, owner, mastery)
	ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
end
-- 번지는 불길
function ModifyAbilityChecker_SpreadingBlaze(mastery, ability)
	return ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Fire') and (tonumber(ability.RangeDistance) or 0) >= 2;
end
function ModifyAbilityByMastery_SpreadingBlaze(ability, owner, mastery)
	local GetExpandRange = function(rangeType)
		local rangeCls = GetClassList('Range')[rangeType];
		return rangeCls.ExpandedRange or rangeType;
	end
	ability.TargetRange = GetExpandRange(ability.TargetRange);
	-- 적용 범위 증가 (자신 주위 광역 or 부채꼴 or 직선)
	local applyRangeCls = GetClassList('Range')[ability.ApplyRange];
	if ability.Target == 'Self' or applyRangeCls.Type == 'Fan' or applyRangeCls.Type == 'StraightLine' then
		ability.ApplyRange = GetExpandRange(ability.ApplyRange);
		ability.GuideRange = GetExpandRange(ability.GuideRange);
	end
	InvalidateObject(ability);
end
-- 소나기
function ModifyAbilityChecker_RainShower(mastery, ability)
	return IsGetAbilitySubType(ability, 'Water') and ability.CastDelay > 0;
end
function ModifyAbilityByMastery_RainShower(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount / 100));
end
-- 폭식
function ModifyAbilityChecker_Gluttony(mastery, ability)
	return ability.HPDrainType.name == 'Predation';
end
function ModifyAbilityByMastery_Gluttony(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.HPDrainRatio = math.max(0, ability.HPDrainRatio + math.floor( host.HPDrainRatio * mastery.ApplyAmount / 100));
end
-- 거친 숨결
function MultiColumnModifier(obj, ref, column, modifier)
	for i = 1, #obj[column] do
		obj[column][i] = modifier(obj[column][i], ref[column][i]);
	end
end
function ModifyAbilityChecker_ToughBreath(mastery, ability)
	return ability.Type == 'Attack' and ability.HitRateType == 'Force';
end
function ModifyAbilityByMastery_ToughBreath(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	MultiColumnModifier(ability, host, 'ApplyAmountChangeStep', function(v, vHost) return v + math.floor(vHost * mastery.ApplyAmount / 100) end);
	ability.ApplyTargetBuffChance = math.min(ability.ApplyTargetBuffChance + mastery.ApplyAmount2, 100);
end
-- 숨결 고르기
function ModifyAbilityChecker_FastBreath(mastery, ability)
	return ability.Type == 'Attack' and ability.CastDelay > 0;
end
function ModifyAbilityByMastery_FastBreath(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount / 100));
end
-- 교묘한 낚시꾼
function ModifyAbilityChecker_Cleverfisherman(mastery, ability)
	return Set.new({'PreyDown', 'FallWeb_Move', 'PreyFishing'})[ability.name];
end
function ModifyAbilityByMastery_Cleverfisherman(ability, owner, mastery)
	ability.SurpriseMove = false;
	ability.SilentMove = true;
end
-- 별빛 파편
function ModifyAbilityChecker_StarlightParts(mastery, ability)
	return ability.Type == 'Attack' and (ability.CastDelay > 0 or ability.CoolTime > 0);
end
function ModifyAbilityByMastery_StarlightParts(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor(host.CastDelay * mastery.ApplyAmount / 100));
	ModifyAbilityByMastery_CoolTime(ability, owner, mastery, 'ApplyAmount2');
end
-- 전경
function ModifyAbilityChecker_ConnectionEnergy(mastery, ability)
	return ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Blunt');
end
function ModifyAbilityByMastery_ConnectionEnergy(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	MultiColumnModifier(ability, host, 'ApplyAmountChangeStep', function(v, vHost) return v + math.floor(vHost * mastery.ApplyAmount / 100) end);
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount2 / 100));
end
-- 능숙한 썰기
function ModifyAbilityChecker_GoodChopping(mastery, ability)
	return ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Slashing');
end
function ModifyAbilityByMastery_GoodChopping(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	MultiColumnModifier(ability, host, 'ApplyAmountChangeStep', function(v, vHost) return v + math.floor(vHost * mastery.ApplyAmount / 100) end);
	if ability.ApplyTargetBuff.name == mastery.SubBuff.name then
		ability.ApplyTargetBuff = GetClassList('Buff')[mastery.Buff.name];
	end
end
-- 총기 호환성
function ModifyAbilityChecker_GunCompatibility(mastery, ability)
	return ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Piercing') and ability.HitRateType == 'Force';
end
function ModifyAbilityByMastery_GunCompatibility(ability, owner, mastery)
end
function ModifyAbilityFinalizerByMastery_GunCompatibility(ability, owner, mastery, appliedMasteries)
	if GetWithoutError(ability.AdditionalApplyAmount, 'AttackPower') then
		ability.AdditionalApplyAmount.AttackPower = ability.AdditionalApplyAmount.AttackPower + math.floor(#appliedMasteries / mastery.ApplyAmount) * mastery.ApplyAmount2;
	end
end
-- 단련된 공격
function ModifyAbilityChecker_DeftnessAttack(mastery, ability)
	return ability.Type == 'Attack';
end
function ModifyAbilityByMastery_DeftnessAttack(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	local cnt = math.floor(mastery.CustomCacheData / mastery.ApplyAmount);
	MultiColumnModifier(ability, host, 'ApplyAmountChangeStep', function(v, vHost) return v + math.floor(vHost * cnt * mastery.ApplyAmount2 / 100) end);
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * cnt * mastery.ApplyAmount / 100));
end
-- 능숙한 손놀림
function ModifyAbilityChecker_SkilledFinger(mastery, ability)
	return ability.Type == 'Attack';
end
function ModifyAbilityByMastery_SkilledFinger(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.Cost = math.max(0, ability.Cost - math.floor( host.Cost * mastery.ApplyAmount /100));
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount / 100));
end
-- 우렁찬 울음
function ModifyAbilityChecker_ResonantCrying(mastery, ability)
	return (ability.Type == 'Heal' or ability.Type == 'Assist') and ability.TargetType == 'Area' and (tonumber(ability.RangeRadius) or 0) > 0;
end
function ModifyAbilityByMastery_ResonantCrying(ability, owner, mastery)
	local GetExpandRange = function(rangeType)
		local rangeCls = GetClassList('Range')[rangeType];
		if not rangeCls then
			return rangeType;
		end
		return rangeCls.ExpandedRange or rangeType;
	end
	ability.ApplyRange = GetExpandRange(ability.ApplyRange);
	ability.GuideRange = GetExpandRange(ability.GuideRange);
	InvalidateObject(ability);
end
-- 끊이지 않는 노래
function ModifyAbilityChecker_EndlessSong(mastery, ability)
	return (ability.Type == 'Heal' or ability.Type == 'Assist') and ability.CastDelay > 0;
end
function ModifyAbilityByMastery_EndlessSong(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * mastery.ApplyAmount / 100));
end
-- 막 잡은 먹잇감
function ModifyAbilityChecker_FastFishing(mastery, ability)
	return ability.name == 'PreyDown' or ability.name == 'PreyThrow';
end
function ModifyAbilityByMastery_FastFishing(ability, owner, mastery)
	if ability.TurnPlayType == 'Main' then
		ability.TurnPlayType = 'Half';
	elseif ability.TurnPlayType == 'Half' then
		ability.TurnPlayType = 'Free';
	end
end
-- 노장의 기백
function ModifyAbilityChecker_VeteranSpirit(mastery, ability)
	return ability.Type == 'Attack' and ability.CastDelay > 0;
end
function ModifyAbilityByMastery_VeteranSpirit(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	local applyAmount = math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount2;
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor(host.CastDelay * applyAmount / 100));
end
-- 노익장
function ModifyAbilityChecker_LegendVeteran(mastery, ability)
	return ability.Type == 'Attack';
end
function ModifyAbilityByMastery_LegendVeteran(ability, owner, mastery)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	local applyAmount = math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount3;
	MultiColumnModifier(ability, host, 'ApplyAmountChangeStep', function(v, vHost) return v + math.floor(vHost * applyAmount / 100) end);
end
-- 정보 장악
function ModifyAbilityByMastery_InformationDomination(ability, owner, mastery)
	ability.ApplyTargetBuffDuration = math.max(0, ability.ApplyTargetBuffDuration + mastery.ApplyAmount);
	ability.ApplyTargetBuff.Turn = ability.ApplyTargetBuffDuration;
end
------------------------------------------------------
-- 버프 어빌리티 조정자
------------------------------------------------------
-- 예열
function ModifyAbilityChecker_Buff_WarmUp(buff, ability, owner)
	return ability.CastDelay > 0;
end
function ModifyAbilityByBuff_WarmUp(ability, owner, buff)
	local host = ability;
	if not IsClass(ability) then
		host = GetHostClass(ability);
	end
	ability.CastDelay = math.max(0, ability.CastDelay - math.floor( host.CastDelay * buff.ApplyAmount / 100));
end
-- XX 부르기 버프들
-- 점화
function ModifyAbilityChecker_Buff_EnchantFire(buff, ability, owner)
	return ModifyAbilityChecker_Buff_EnchantSubType(buff, ability, owner)
end
-- 냉각
function ModifyAbilityChecker_Buff_EnchantIce(buff, ability, owner)
	return ModifyAbilityChecker_Buff_EnchantSubType(buff, ability, owner)
end
-- 발전
function ModifyAbilityChecker_Buff_EnchantLightning(buff, ability, owner)
	return ModifyAbilityChecker_Buff_EnchantSubType(buff, ability, owner)
end
-- 달빛 모으기
function ModifyAbilityChecker_Buff_EnchantEarth(buff, ability, owner)
	return ModifyAbilityChecker_Buff_EnchantSubType(buff, ability, owner)
end
-- 급수
function ModifyAbilityChecker_Buff_EnchantWater(buff, ability, owner)
	return ModifyAbilityChecker_Buff_EnchantSubType(buff, ability, owner)
end
-- 송풍
function ModifyAbilityChecker_Buff_EnchantWind(buff, ability, owner)
	return ModifyAbilityChecker_Buff_EnchantSubType(buff, ability, owner)
end
-- 소화
function ModifyAbilityChecker_Buff_ReleaseFire(buff, ability, owner)
	return ModifyAbilityChecker_Buff_ReleaseSubType(buff, ability, owner)
end
-- 해동
function ModifyAbilityChecker_Buff_ReleaseIce(buff, ability, owner)
	return ModifyAbilityChecker_Buff_ReleaseSubType(buff, ability, owner)
end
-- 방전
function ModifyAbilityChecker_Buff_ReleaseLightning(buff, ability, owner)
	return ModifyAbilityChecker_Buff_ReleaseSubType(buff, ability, owner)
end
-- 달빛 흐트리기
function ModifyAbilityChecker_Buff_ReleaseEarth(buff, ability, owner)
	return ModifyAbilityChecker_Buff_ReleaseSubType(buff, ability, owner)
end
-- 배수
function ModifyAbilityChecker_Buff_ReleaseWater(buff, ability, owner)
	return ModifyAbilityChecker_Buff_ReleaseSubType(buff, ability, owner)
end
-- 무풍
function ModifyAbilityChecker_Buff_ReleaseWind(buff, ability, owner)
	return ModifyAbilityChecker_Buff_ReleaseSubType(buff, ability, owner)
end
-- 공용
function ModifyAbilityChecker_Buff_EnchantSubType(buff, ability, owner)
	return ability.SubType ~= buff.Group and ability.Type == 'Attack';
end
function ModifyAbilityByBuff_EnchantSubType(ability, owner, buff)
	ability.SubType = buff.Group;
end
function ModifyAbilityChecker_Buff_ReleaseSubType(buff, ability, owner)
	return ability.SubType == buff.Group and ability.Type == 'Attack';
end
function ModifyAbilityByBuff_ReleaseSubType(ability, owner, buff)
	ability.SubType = ability.ReleaseSubType;
end
------------------------------------------------------
-- 아이템 어빌리티 조정자
------------------------------------------------------
function ModifyAbilityByItem(ability, owner)
	for i, slot in ipairs(GetItemSlotList()) do
		local itemAbility = SafeIndex(owner, slot, 'Ability', 'name');
		if ability.name == itemAbility then	
			local modifier = GetWithoutError(owner[slot], 'AbilityModifier');
			if modifier then
				modifier(owner[slot], ability);
			end
			break;
		end
	end
end
------------------------------------------------------
-- 프로토콜 어빌리티 여부
------------------------------------------------------
function IsProtocolAbility(ability)
	local protocols = {
		AttackProtocol = true,
		MoveProtocol = true, 
		HackingProtocol = true, 
		SearchProtocol = true, 
		AssistProtocol = true, 
		AutoDefenceProtocol = true, 
		DerangementProtocol = true,
		ManagerProtocol = true,
		EnhancedAttackProtocol = true,
	};
	return protocols[ability.name] or false;
end
function IsCommandAbilityProtocolAbility(ability)
	local protocols = {
		AttackProtocol = true,
		AssistProtocol = true, 
		EnhancedAttackProtocol = true,
	};
	return protocols[ability.name] or false;
end
------------------------------------------------------
-- 어빌리티 목록 정렬
------------------------------------------------------
function SortAbilityList(target, abilityList, abilityGetter)
	if abilityGetter == nil then
		abilityGetter = function(o) return o; end
	end
	-- AutoActiveAbility에 의한 순서 판정에는 비활성화된 어빌리티도 필요하다.
	local abilityAllList = GetAllAbility(target, false, true);

	-- 기본 순서
	local baseOrderMap = {};
	for i, ability in ipairs(abilityAllList) do
		baseOrderMap[ability.name] = i;
	end
	local dummyIndex = #abilityAllList;
	
	-- 아이템 슬롯
	local itemSlotMap = {};
	local equipmentList = GetClassList('Equipment');
	local equipClsList = {};
	for key, value in pairs(equipmentList) do
		table.insert(equipClsList, value);
	end
	table.scoresort(equipClsList, function(equipCls) return equipCls.Order; end);
	for _, equipCls in ipairs(equipClsList) do
		local equipPos = equipCls.name;
		local inventorySlot = GetWithoutError(target, equipPos);
		local abilityName = SafeIndex(inventorySlot, 'Ability', 'name');
		if abilityName ~= nil then
			itemSlotMap[abilityName] = equipPos;
		end
		local upAbilityName = SafeIndex(inventorySlot, 'UpgradeAbility', 'name');
		if upAbilityName ~= nil then
			itemSlotMap[upAbilityName] = equipPos;
		end
		local subAbilityName = SafeIndex(inventorySlot, 'SubAbility', 'name');
		if subAbilityName ~= nil then
			itemSlotMap[subAbilityName] = equipPos;
		end
	end

	-- AutoActiveAbility
	local baseAbilityMap = {};
	for _, ability in ipairs(abilityAllList) do
		for i, subAbility in ipairs(ability.AutoActiveAbility) do
			baseAbilityMap[subAbility] = ability.name;
		end
	end
	table.scoresort(abilityList, function(ability)
		ability = abilityGetter(ability);
		local abilityName = ability.name;
		local baseOrder = baseOrderMap[abilityName];
		if baseOrder == nil then
			baseOrder = dummyIndex;
			dummyIndex = dummyIndex + 1;
		end
		if itemSlotMap[abilityName] == 'Weapon' then
			return 0.001 * baseOrder;
		elseif baseAbilityMap[abilityName] then
			local baseAbility = baseAbilityMap[abilityName];
			return baseOrderMap[baseAbility] + 0.001 * baseOrder;
		else
			return baseOrder;
		end
	end);
	
	return abilityList;
end

function SortAbilityInfoList(target, infoList)
	local abilityList = {};
	local infoMap = {};
	for _, info in ipairs(infoList) do
		local ability = GetAbilityObject(target, info.name);
		if ability then
			table.insert(abilityList, ability);
			infoMap[ability.name] = info;
		end
	end

	abilityList = SortAbilityList(target, abilityList);

	return table.map(abilityList, function(ability) return infoMap[ability.name] end);
end
-- 어빌리티 세부 타입 값 가져오는 부분
function SetAbilityTypeData(ability)
	local propertyList = {};
	local abilitySubTypeList = GetClassList('AbilitySubType');
	local abilityHitRateTypeList = GetClassList('AbilityHitRateType');
	-- 9. SubType 표기
	if ability.SubType ~= 'None' then
		local abilitySubType = SafeIndex(abilitySubTypeList[ability.SubType], 'Title');
		if abilitySubType == nil then
			abilitySubType = '- ErrorData -';
		end
		table.insert(propertyList, { Title = 'DamageType', Value = abilitySubType });
	end
	-- 10. HitRateType 표기
	if ability.HitRateType ~= 'None' then
		local abilityHitRateType = SafeIndex(abilityHitRateTypeList[ability.HitRateType], 'Title');
		if abilityHitRateType == nil then
			abilityHitRateType = '- ErrorData -';
		end
		table.insert(propertyList, { Title = 'AttackType', Value = abilityHitRateType });
	end
	-- 11. 적용 대상 표기
	if ability.ApplyTargetType ~= 'None' then
		table.insert(propertyList, { Title = 'AttackTarget', Value = ability.ApplyTargetType });
	end
	
	-- 12. 공연 속성 표기
	if ability.PerformanceEffect ~= 'None' then
		local performanceEffectCls = GetClassList('PerformanceEffect')[ability.PerformanceEffect];
		if performanceEffectCls then
			table.insert(propertyList, { Title = 'PerformanceEffectType', Value = performanceEffectCls.Title });
		end
	end
	
	-- 13. 사거리 표기
	if ability.RangeDistance > 0 then
		table.insert(propertyList, { Title = 'AttackRange', Value = ability.RangeDistance, Font = 'HemiHead-14' });
	end
	-- 14. 공격 범위 표기
	if ability.RangeRadius > 0 then
		table.insert(propertyList, { Title = 'AttackRadius', Value = ability.RangeRadius, Font = 'HemiHead-14' });
	end
	return propertyList;
end
-- 마스터리에 붙는 어빌리티 툴팁 완성용.
function GetAbilityTypeDataText(ability)
	local result = '$ScreaminGreen$';
	local abilityTypeList = SetAbilityTypeData(ability)
	for index, data in ipairs (abilityTypeList) do
		local curLine = '';
		local divide = '';
		if data.Value and data.Value ~= '-' then
			if index == 1 then
				curLine = data.Value;
			else
				if data.Title == 'AttackRange' or data.Title == 'AttackRadius' then
					curLine = GetWord(data.Title)..' '..data.Value;					
				else
					curLine = data.Value;
				end
				divide = ' / ';
			end
		end
		result = result ..divide..curLine;
	end
	return result;
end