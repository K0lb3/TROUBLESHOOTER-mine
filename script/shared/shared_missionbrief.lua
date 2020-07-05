-- �ҽ����� ȣ��˴ϴ�. �Ժη� ���ڸ� �ٲ��� �����ּ���
-- �̼��� ���������� �������� �Ǵ��ϴ� �Լ� �Դϴ�.
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
-- �ҽ����� ȣ��˴ϴ�. �Ժη� ���ڸ� �ٲ��� �����ּ���
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
	-- ���� ���
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
	
	-- ���°� �޽� ���¸� �ȵ�
	if roster.ConditionState == 'Rest' then
		return false;
	end
	return true;
end