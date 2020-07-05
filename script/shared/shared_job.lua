--------------------------------------------------
-- 전직 가능한가.
--------------------------------------------------
function IsSatisfiedChangeClass(pcInfo, jobName)
	
	local isEnable = true;
	local reason  = {};
	
	local enableJobs = GetWithoutError(SafeIndex(pcInfo, 'EnableJobs'), jobName);
	local requireLv = SafeIndex(enableJobs, 'RequireLv');	
	
	-- 0. 데이터 유효성 검사.
	if not enableJobs then
		table.insert(reason, 'NotExistEnableJobs');
		return isEnable, reason;
	end
	if not requireLv then
		table.insert(reason, 'NotExistRequireLv');
		return isEnable, reason;	
	end
	
	local jobList = GetClassList('Job');
	local curJob = jobList[jobName];
	if not curJob then
		table.insert(reason, 'NotExistJob');
		return isEnable, reason;	
	end	
	
	-- 1. PC 레벨	
	if requireLv > pcInfo.Lv then
		isEnable = false;
		table.insert(reason, 'NotEnoughPcLevel');
	end
	-- 2. 각 직업 레벨
	local requireChangeClassList = curJob.RequireClassLv;
	-- 클래스 요구 레벨 존재할때.
	if requireChangeClassList and #requireChangeClassList > 0 then
		-- 조건이 여러개 일 수 있으므로 다 판단해야 한다. or 조건.
		local isRequireClassLv = false;
		for _, rcLvCls in ipairs(requireChangeClassList) do
			-- rcLvList 안의 모든 조건이 만족해야 isRequireClassLv 가 true 다.
			local isRequireConditions = true;
			for className, requireLv in pairs (rcLvCls.RequireConditions) do
				local curClassLv = GetPcEnableJobValue(pcInfo, className, 'Lv');
				if requireLv > curClassLv then
					isRequireConditions = false;
					break;
				end			
			end
			-- 조건을 하나 돌았는데 true 일 경우, 전직 가능하다는 것.
			if isRequireConditions then
				isRequireClassLv = true;
				break;
			end
		end	
		if not isRequireClassLv then
			isEnable = false;
			table.insert(reason, 'NotEnoughJobLevel');
		end
	end
	-- 3. 각 직업 필요 무기.
	local isSatisfiedChangeClassByUsableWeapon = IsSatisfiedChangeClassByUsableWeapon(pcInfo, curJob);
	if not isSatisfiedChangeClassByUsableWeapon then
		isEnable = false;
		table.insert(reason, 'NotExistEnableEqipWeapon');	
	end
	-- 4. 초능력 필요 여부
	local isEnableUseESP = IsSatisfiedChangeClassByESP(pcInfo, curJob);
	if not isEnableUseESP then
		isEnable = false;
		table.insert(reason, 'NotExistRequiredESP');	
	end
	-- 5. 성별 필요 여부
	local isEnableGender = IsSatisfiedChangeClassByGender(pcInfo, curJob);
	if not isEnableGender then
		isEnable = false;
		table.insert(reason, 'NotExistRequiredGender');	
	end
	-- 6. 소속 필요 여부
	local isEnableUseOrganization = IsSatisfiedChangeClassByOrganization(pcInfo, curJob);
	if not isEnableUseOrganization then
		isEnable = false;
		table.insert(reason, 'NotExistRequiredOrganization');	
	end
	-- table.print(reason);
	return isEnable, reason;
end
function IsEnableChangeClass(company, pcInfo, jobName, itemCounter)
	local isEnable = false;
	local reason = {};
	-- 1. 전직 가능한 클래스가 Open 되었는가.
	if IsSatisfiedChangeClass(pcInfo, jobName) then
		isEnable = true;
	else
		table.insert(reason, 'JobIsNotOpened');
	end
	-- 2. 전직에 필요한 아이템이 존재하는가.
	local jobList = GetClassList('Job');
	local changeTargetJob = jobList[jobName];
	local jobInfo = GetWithoutError(pcInfo.EnableJobs, jobName);
	local needItem = changeTargetJob.ClassChangeItem;
	local needCount = changeTargetJob.ClassChangeItemCount;
	-- 3. 전직한 적이 있으면 비용 공짜
	if isEnable and jobInfo and (jobInfo.Lv > 1 or jobInfo.LastLv > 0) then
		needCount = 0;
	end
	local extractItemCount = itemCounter(needItem);
	if extractItemCount < needCount then
		isEnable = false;
		table.insert(reason, 'NotEnoughExtractItem');	
	end	
	return isEnable, needItem, needCount, reason;
end
function IsEnableChangeClassOpened(pcInfo, jobName)
	local isEnable = false;
	local reason = {};
	-- 1. 전직 가능한 클래스가 Open 되었는가.
	if IsSatisfiedChangeClass(pcInfo, jobName) then
		isEnable = true;
	else
		table.insert(reason, 'JobIsNotOpened');
	end
	-- 2. 전직한 적이 있는가.
	local jobInfo = GetWithoutError(pcInfo.EnableJobs, jobName);
	if jobInfo and (jobInfo.Lv > 1 or jobInfo.LastLv > 0) then
		
	else
		isEnable = false;
		table.insert(reason, 'JobIsNotOpened');
	end
	return isEnable, reason;
end
--------------------------------------------------
-- 상위 직업 체크
--------------------------------------------------
function IsEnableChangeClassThanCurrentJob(pcInfo)
	local isEnable = false;
	local jobList = GetClassList('Job');
	for key, value in pairs (pcInfo.EnableJobs) do
		if IsSatisfiedChangeClass(pcInfo, key) and jobList[key].Grade > pcInfo.Object.Job.Grade then
			isEnable = true;
			break;
		end
	end
	return isEnable;
end
--------------------------------------------------
-- 클래스 전직 레벨이 안되었을 때
--------------------------------------------------
function IsEnableChangeAnyClass(pcInfo)
	local isEnable = false;
	for key, value in pairs (pcInfo.EnableJobs) do
		if IsSatisfiedChangeClass(pcInfo, key) and value.Order > 1 then
			isEnable = true;
			break;
		end
	end
	return isEnable;
end
--------------------------------------------------
-- CP - 
--------------------------------------------------
function CalculatedProperty_Job_MaxAbilitySlotCount(self, arg)
	return self.Basic + self.Normal + self.Ultimate;
end
--------------------------------------------------
-- 현재 PC의 잡 레벨 받아오기.
--------------------------------------------------
function GetPcEnableJobValue(pcInfo, jobName, valueType)
	if pcInfo.RosterType == 'Pc' then
		local curEnableJobs = GetWithoutError(pcInfo, 'EnableJobs');
		if not curEnableJobs then
			return 0;
		end
		local curJob = GetWithoutError(curEnableJobs, jobName);
		if not curJob then
			return 0;
		end
		local curValue = curJob[valueType];
		if not curValue then
			return 0;
		end	
		return curValue;
	elseif pcInfo.RosterType == 'Beast' or pcInfo.RosterType == 'Machine' then
		if valueType == 'Lv' then
			return pcInfo.JobLv;
		elseif valueType == 'Exp' then
			return pcInfo.JobExp;
		else
			return 0;
		end
	else
		return 0;
	end
end
--------------------------------------------------
-- 클래스 변경에서 무기 조건이 맞는 지 여부
--------------------------------------------------
function IsSatisfiedChangeClassByUsableWeapon(pcInfo, curJob)
	local isEquipableWeapon = true;
	if #curJob.RequiredWeapon > 0 then
		isEquipableWeapon = false;
		for _, weapon in ipairs (curJob.RequiredWeapon) do
			for _, enableEquipWeapon in ipairs (pcInfo.Object.EnableEquipWeapon) do
				if weapon == enableEquipWeapon then
					isEquipableWeapon = true;
					break;
				end
			end
		end
	end
	return isEquipableWeapon;
end
--------------------------------------------------
-- 클래스 변경에서 초능력 조건이 맞는 지 여부
--------------------------------------------------
function IsSatisfiedChangeClassByESP(pcInfo, curJob)
	local isEnableUseESP = true;
	if #curJob.RequiredESP > 0 then
		isEnableUseESP = false;
		for _, esp in ipairs (curJob.RequiredESP) do
			if esp == pcInfo.Object.ESP.name then
				isEnableUseESP = true;
				break;
			end	
		end
	end
	return isEnableUseESP;
end
--------------------------------------------------
-- 클래스 변경에서 성별이 조건이 맞는 지 여부
--------------------------------------------------
function IsSatisfiedChangeClassByGender(pcInfo, curJob)
	
	local isEnableUseGender = false;
	if #curJob.RequiredGender > 0 then
		for _, gender in ipairs (curJob.RequiredGender) do
			if gender == pcInfo.Object.Gender then
				isEnableUseGender = true;
				break;
			end	
		end
	else
		isEnableUseGender = true;
	end
	return isEnableUseGender;
end
--------------------------------------------------
-- 클래스 변경에서 소속 조건이 맞는 지 여부
--------------------------------------------------
function IsSatisfiedChangeClassByOrganization(pcInfo, curJob)
	
	local isEnableUseOrganization = false;
	if #curJob.RequiredOrganization > 0 then
		for _, organization in ipairs (curJob.RequiredGender) do
			if organization == pcInfo.Object.Affiliation.name then
				isEnableUseOrganization = true;
				break;
			end	
		end
	else
		isEnableUseOrganization = true;
	end
	return isEnableUseOrganization;
end
--------------------------------------------------
-- 특정 직업에서 전직 가능한 직업 받아오기. (캐릭터 레벨을 제외한 요소.)
--------------------------------------------------
function GetEnableChangeClassOnCurrentJob(pcInfo, jobName)
	local list = {};
	local jobList = GetClassList('Job');
	local curJob = jobList[jobName];	
	for key, job in pairs (jobList) do
		if curJob.Grade + 1 == job.Grade then
			local enableJobs = GetEnableJobMastery(job);
			local isEnable = SafeIndex(enableJobs, jobName);
			if isEnable 
				and IsSatisfiedChangeClassByUsableWeapon(pcInfo, job) 
				and IsSatisfiedChangeClassByESP(pcInfo, job) 
				and IsSatisfiedChangeClassByGender(pcInfo, job)
			then
				table.insert(list, job);
			end
		end
	end
	return list;
end
-----------------------------------------------------
-- 직업 레벨에 따른 어빌리티 특성 보상
-----------------------------------------------------
function GetRewardMasteriesByJobLevel(company, pcInfo, jobName, jobLvStart, jobLvEnd, includeOpened)
	local masteryList = GetClassList('Mastery');

	local enableJob = GetWithoutError(pcInfo.EnableJobs, jobName);
	if not enableJob then
		return {};
	end	
	local rewardMasteries = GetWithoutError(enableJob, 'Masteries');
	if not rewardMasteries then
		return {};
	end
	
	local rewards = {};
	for _, info in ipairs(rewardMasteries) do
		if jobLvStart <= info.RequireLv and info.RequireLv <= jobLvEnd then
			local mastery = masteryList[info.Name];
			if mastery then
				local techName = mastery.name;
				local tech = GetWithoutError(company.Technique, techName);
				if not tech then
					LogAndPrint('[DataError] GetRewardMasteriesByJobLevel - technique not exists', techName);
				end
				if tech and (not tech.Opened or includeOpened) then
					table.insert(rewards, mastery);
				end
			else
				LogAndPrint('[DataError] GetRewardMasteriesByJobLevel - mastery not exists', info.Name);
			end
		end
	end
	
	local basicMasteries = GetWithoutError(enableJob, 'BasicMasteries');
	if basicMasteries then
		for _, info in ipairs(basicMasteries) do
			local mastery = masteryList[info.Name];
			if mastery then
				local techName = mastery.name;
				local tech = GetWithoutError(company.Technique, techName);
				if not tech then
					LogAndPrint('[DataError] GetRewardMasteriesByJobLevel - technique not exists', techName);
				end
				if tech and not tech.Opened then
					table.insert(rewards, mastery);
				end
			else
				LogAndPrint('[DataError] GetRewardMasteriesByJobLevel - mastery not exists', info.Name);
			end
		end
	end

	return rewards;
end
function GetRewardMasteriesByJobLevel_Beast(company, pcInfo, jobLvStart, jobLvEnd, includeOpened)
	local masteryList = GetClassList('Mastery');

	if pcInfo.RosterType ~= 'Beast' then
		return {};
	end
	local rewardMasteries = GetWithoutError(pcInfo.BeastType, 'Masteries');
	if not rewardMasteries then
		return {};
	end
	
	local rewards = {};
	for _, info in ipairs(rewardMasteries) do
		if jobLvStart <= info.RequireLv and info.RequireLv <= jobLvEnd then
			local mastery = masteryList[info.Name];
			if mastery then
				local techName = mastery.name;
				local tech = GetWithoutError(company.Technique, techName);
				if not tech then
					LogAndPrint('[DataError] GetRewardMasteriesByJobLevel_Beast - technique not exists', techName);
				end
				if tech and (not tech.Opened or includeOpened) then
					table.insert(rewards, mastery);
				end
			else
				LogAndPrint('[DataError] GetRewardMasteriesByJobLevel_Beast - mastery not exists', info.Name);
			end
		end
	end

	return rewards;
end
function GetRewardMasteriesByJobLevel_Machine(company, pcInfo, jobLvStart, jobLvEnd, upgradeStage, includeOpened)
	local masteryList = GetClassList('Mastery');

	if pcInfo.RosterType ~= 'Machine' then
		return {};
	end
	local rewardMasteries = nil;
	local enableUpgrade = GetWithoutError(pcInfo.MachineType, 'Masteries');
	if enableUpgrade then
		rewardMasteries = GetWithoutError(enableUpgrade, upgradeStage or pcInfo.AIUpgradeStage);
	end
	if not rewardMasteries then
		return {};
	end
	
	local rewards = {};
	for _, info in ipairs(rewardMasteries) do
		if jobLvStart <= info.RequireLv and info.RequireLv <= jobLvEnd then
			local mastery = masteryList[info.Name];
			if mastery then
				local techName = mastery.name;
				local tech = GetWithoutError(company.Technique, techName);
				if not tech then
					LogAndPrint('[DataError] GetRewardMasteriesByJobLevel_Machine - technique not exists', techName);
				end
				if tech and (not tech.Opened or includeOpened) then
					table.insert(rewards, mastery);
				end
			else
				LogAndPrint('[DataError] GetRewardMasteriesByJobLevel_Machine - mastery not exists', info.Name);
			end
		end
	end

	return rewards;
end
-----------------------------------------------------
-- 직업에 따라 사용가능한 직업 전용 특성 키 값받아오기.
-----------------------------------------------------
function GetEnableJobMastery(job)
	local list = {};
	-- 1. 자신을 넣는다.
	list[job.name] = true;
	-- 2. 전직에 요구되는 값을 넣는다.
	local requireChangeClassList = job.RequireClassLv;
	if requireChangeClassList and #requireChangeClassList > 0 then
		for _, rcLvCls in ipairs(requireChangeClassList) do
			for className, requireLv in pairs (rcLvCls.RequireConditions) do
				if not list[className] then
					list[className] = true;
				end
			end
		end
	end
	return list;
end

