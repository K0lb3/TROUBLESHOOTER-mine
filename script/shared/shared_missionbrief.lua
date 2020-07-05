-- 소스에서 호출됩니다. 함부로 인자를 바꾸지 말아주세요
-- 미션을 정상적으로 시작할지 판단하는 함수 입니다.
function IsAvailableStartMission(company, missionCls, lineups, missionAttribute)
	local questType = SafeIndex(missionAttribute, 'QuestType');
	local eventGenType = SafeIndex(missionAttribute, 'EventGenType');
	
	local eventCls = nil;
	if questType then
		eventCls = GetClassList('Quest')[questType];
	elseif eventGenType then
		eventCls = GetClassList('ZoneEventGen')[eventGenType];
	end
	local isScenario = SafeIndex(eventCls, 'Group') == 'Scenario';
	for i, roster in ipairs(lineups) do
		if not IsEnableParticipateInMission(missionCls, roster, isScenario) then
			return false, "Roster Not Allowed to Enter Mission";
		end
	end
	return true;
end
-- 소스에서 호출됩니다. 함부로 인자를 바꾸지 말아주세요
function GetMissionLineupMaxCount(missionCls, company)
	local maxCount = company.MaxMemberCount;
	if 	missionCls.name == 'Tutorial_TrainingRoomAfter' or	
		missionCls.name == 'Tutorial_WhiteTigerBase'	then
		maxCount = 9;
	end
	local missionLimit = missionCls.FreeMemberCount + #missionCls.FixedMember;
	return math.min(maxCount, missionLimit);
end
function IsEnableParticipateInMission(missionCls, roster, isScenario)
	-- 금지 멤버
	local banMemberSet = {};
	for i, member in ipairs(missionCls.BanMember) do
		if roster.name == member then
			return false;
		end
	end
	
	if isScenario then
		for i, member in ipairs(missionCls.FixedMember) do
			if roster.name == member then
				return true;
			end
		end
	end
	
	-- 상태가 휴식 상태면 안됨
	if roster.ConditionState == 'Rest' then
		return false;
	end
	return true;
end