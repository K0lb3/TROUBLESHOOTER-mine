function CalculatedProperty_Reputation_RewardLv(self, arg)
	local result = 0;
	result = 1 + math.max(0, math.floor(self.Lv/10));
	return math.min(result, 10);
end
--------------------------------------------------------------------
-- 정식 트러블슈터 숫자
--------------------------------------------------------------------
function GetRegisteredTroubleshooter(roster)
	local result = 0;
	for _, pcInfo in ipairs (roster) do
		if pcInfo.RosterType == 'Pc' and pcInfo.Registered then
			result = result + 1;
		end
	end
	return result;
end
--------------------------------------------------------------------
-- 관할 구역 숫자
--------------------------------------------------------------------
function GetAllowDivisionCount(reputation, sectionType, divisionType)
	local result = 0;
	local sectionSortType = 'All';
	if sectionType or divisionType then
		sectionSortType = 'Combination';
	end
	for key, section in pairs (reputation) do
		if section.Opened then
			if sectionSortType == 'All' or 
				( sectionType and not divisionType and sectionType == section.Type.name ) or
				( not sectionType and divisionType and divisionType == section.Division.name ) or
				( sectionType and divisionType and sectionType == section.Type.name and divisionType == section.Division.name )
			then
				result = result + 1;
			end
		end
	end
	return result;
end
--------------------------------------------------------------------
-- 관할 구역 목록
--------------------------------------------------------------------
function GetDivisionList(reputation, sectionType, divisionType)
	local result = {};
	local sectionSortType = 'All';
	if sectionType or divisionType then
		sectionSortType = 'Combination';
	end
	for key, section in pairs (reputation) do
		if sectionSortType == 'All' or 
			( sectionType and not divisionType and sectionType == section.Type.name ) or
			( not sectionType and divisionType and divisionType == section.Division.name ) or
			( sectionType and divisionType and sectionType == section.Type.name and divisionType == section.Division.name )
		then
			table.insert(result, section);
		end
	end
	return result;
end
--------------------------------------------------------------------
-- 관할 구역 보너스
--------------------------------------------------------------------
function GetSectionTypeBonusValue(reputation, sectionType)
	local result = 0;
	local count = GetAllowDivisionCount(reputation, sectionType);
	if count > 0 then
		local bonusList = GetClassList('ReputationSectorType')[sectionType].Bonus;
		result = bonusList[math.min(count, #bonusList)].AmountValue;
	end
	return result, count;
end
function GetDivisionTypeBonusValue(reputation, divisionType)
	local result = 0;
	local count = GetAllowDivisionCount(reputation, nil, divisionType);
	if count > 0 then
		local bonusList = GetClassList('ReputationDivisionType')[divisionType].Bonus;
		result = bonusList[math.min(count, #bonusList)].AmountValue;
	end
	return result, count;
end
--------------------------------------------------------------------
-- 관할 구역 신청 가능
--------------------------------------------------------------------
function IsEnableOpenAllowDivision(company, section)
	local isEnable = true;
	local reason = {};
	
	-- 평판 레벨
	if section.RewardLv < section.RequireLevel then
		isEnable = false;
		table.insert(reason, 'ReputationLevel');
	end
	
	-- 금액
	if company.Vill < section.Cost then
		isEnable = false;
		table.insert(reason, 'Vill');	
	end
	
	-- 미션 클리어 횟수
	if company.Stats.MissionClear < section.TotalMissionClearCount then
		isEnable = false;
		table.insert(reason, 'MissionClearCount');
	end
	
	-- 관할 구역 개수
	local roster = nil;
	if IsClient() then
		roster = GetSession().rosters;
	else
		roster = GetAllRoster(company);
	end
	local allowDivisionCount = GetAllowDivisionCount(company.Reputation);
	local registeredTroubleshooterCount = GetRegisteredTroubleshooter(roster);	
	if allowDivisionCount + 1 > registeredTroubleshooterCount + 1 then
		isEnable = false;
		table.insert(reason, 'TroubleShooterCount');
	end

	return isEnable, reason;
end
function IsEnableCloseAllowDivision(company, section)
	local isEnable = true;
	local reason = {};
	
	-- 사무실 위치
	local office = GetClassList('Office')[company.Office];
	if office.Section ~= 'None' and office.Section == section.name then
		isEnable = false;
		table.insert(reason, 'Office');
	end
	
	return isEnable, reason;
end
--------------------------------------------------------------------
-- 관할 구역 보너스 적용 유무
--------------------------------------------------------------------
function IsEnableAllowDivisionBonus(company, bonusType, curSection)
	local bonusCls = GetClassList('ReputationPolicy')[bonusType];
	if not bonusCls then
		return false;
	end
	
	if not curSection then
		local mission = GetMission_Shared(company);
		local missionSite = GetMissionSiteClass(mission);
		if not missionSite then
			return false;
		end
		curSection = company.Reputation[missionSite.Section];
	end
	
	local bonusSectionList = {};	
	for key, section in pairs(company.Reputation) do
		if section.Opened and section.Bonus[section.BonusIndex].Type == bonusType then
			table.insert(bonusSectionList, section);
		end
	end
	-- 해당 보너스가 설정된 관할 구역이 없당
	if #bonusSectionList == 0 then
		return false;
	end
	
	local isEnable = false;
	if bonusCls.EventType == 'Global' then
		-- 전부 적용
		isEnable = true;
	elseif bonusCls.EventType == 'Division' then
		-- 같은 Division에서만 적용
		bonusSectionList = table.filter(bonusSectionList, function(bonusSection)
			return bonusSection.Division.name == curSection.Division.name;
		end);
		if #bonusSectionList > 0 then
			isEnable = true;
		end
	elseif bonusCls.EventType == 'Sector' then
		-- 같은 Section에서만 적용
		bonusSectionList = table.filter(bonusSectionList, function(bonusSection)
			return bonusSection.name == curSection.name;
		end);
		if #bonusSectionList > 0 then
			isEnable = true;
		end
	end

	return isEnable, bonusCls, bonusSectionList;
end