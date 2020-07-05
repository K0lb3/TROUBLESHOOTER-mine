function GetMissionSiteClass(mission)
	local missionAttribute = GetMissionAttribute(mission);
	if not missionAttribute then
		return nil;
	end
	local questType = missionAttribute.QuestType;
	local eventGenType = missionAttribute.EventGenType;
	local directMissionInfo = missionAttribute.DirectMissionInfo;
	local site = nil;
	if questType ~= nil then
		local questCls = GetClassList('Quest')[questType];
		site = questCls.Site;
	elseif eventGenType ~= nil then
		local eventGenCls = GetClassList('ZoneEventGen')[eventGenType];
		site = eventGenCls.Slot;
	elseif directMissionInfo ~= nil then
		site = directMissionInfo.Site;
	end
	
	if not site then
		return nil;
	end
	
	return GetClassList('Site')[site];
end
function GetScenarioProgressGrade(company)
	local grade = 0;
	local missionName = nil;
	local missionList = GetClassList('Mission');	
	for key, mission in pairs(missionList) do
		if company.MissionCleared[mission.name] and grade < mission.ProgressOrder then
			grade = mission.ProgressOrder;
			missionName = mission.name;
		end
	end
	return grade, missionName;
end