function OnUpdateWorldProperty_Mission(keys, commitType)
	if commitType == 'SafetyFeverStart' then
		if IsSingleplayMode() then
			return;
		end
		local worldProperty = GetWorldProperty();
		local allMissions = GetAllMission();
		for _, key in ipairs(keys) do
			local zone = string.match(key, '^ZoneState/([%d%s%w]+)/SafetyFever$');
			if zone then
				local feverTime = SafeIndex(worldProperty, 'ZoneState', zone, 'FeverTime');
				for _, mission in ipairs(allMissions) do
					local siteCls = GetMissionSiteClass(mission);
					if siteCls and siteCls.Zone == zone then
						BroadcastSystemNotice(mission, 'SafetyFeverStart', {ZoneName=zone, OffsetTime = feverTime + GetSystemConstant('ZONE_SAFETY_FEVER_DURATION'), SafetyFeverHour = GetSystemConstant('ZONE_SAFETY_FEVER_DURATION') / 3600, LeftMissionCount = 0});
					end
				end
			end
		end
	elseif commitType == 'SafetyFeverEnd' then
		if IsSingleplayMode() then
			return;
		end
		local allMissions = GetAllMission();
		for _, key in ipairs(keys) do
			local zone = string.match(key, '^ZoneState/([%d%s%w]+)/SafetyFever$');
			if zone then
				for _, mission in ipairs(allMissions) do
					local siteCls = GetMissionSiteClass(mission);
					if siteCls and siteCls.Zone == zone then
						BroadcastSystemNotice(mission, 'SafetyFeverEnd', {ZoneName=zone});
					end
				end
			end
		end
	end
end

function MissionMemberSystemNoticeCheck(company)
	local mission = GetMission(company);
	local worldProperty = GetWorldProperty();
	
	-- 치안도 피버
	local noticeType = 'SafetyFeverNow';
	local zoneState = worldProperty.ZoneState;
	if IsSingleplayMode() then
		noticeType = 'SafetyFeverNow_Single';
		zoneState = company.ZoneState;
	end
	local missionSite = GetMissionSiteClass(mission);
	if missionSite then
		if zoneState[missionSite.Zone].SafetyFever then
			local feverTime = zoneState[missionSite.Zone].FeverTime;
			SendSystemNotice(company, noticeType, {ZoneName=missionSite.Zone, OffsetTime = feverTime + GetSystemConstant('ZONE_SAFETY_FEVER_DURATION'), LeftMissionCount = company.ActivityReportDuration - company.ActivityReportCounter});
		end
	end
end