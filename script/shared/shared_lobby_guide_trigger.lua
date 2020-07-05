
function LobbyGuideTriggerChecker_Empty(eventType, eventArg, company, guideTrigger)
	return false;
end

function LobbyGuideTriggerChecker_EnableQuest(eventType, eventArg, company, guideTrigger)
	if eventArg.LobbyType ~= 'ShooterStreet' then
		return false;
	end
--	return true;
	return false;
end

function LobbyGuideTriggerChecker_QuestWorldMap(eventType, eventArg, company, guideTrigger)
	if not eventArg.NpcName then
		return false;
	end
	local zoneType = nil;
	if IsClient() then
		local areaCls = GetCurrentZoneClass();
		zoneType = areaCls.name;
	else
		local location = GetUserLocation(company);
		local lobbyDef = GetClassList('LobbyWorldDefinition')[location];	
		zoneType = SafeIndex(lobbyDef, 'Zone', 'name');
	end
	local questInfos = GetQuestEventSlotCompany(company, zoneType);
	return not table.empty(questInfos);
end

function GetEnableLobbyGuideTrigger(company, eventType, eventArg)
	local list = {};
	for _, guideTrigger in pairs(company.LobbyGuideTrigger) do
		if not guideTrigger.Pass and table.find(guideTrigger.EventType, eventType) then
			local ok, output = guideTrigger.Checker(eventType, eventArg, company, guideTrigger);
			if ok then
				table.insert(list, guideTrigger.name);
			end
		end	
	end
	return list;
end
