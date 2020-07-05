function Calculated_GetDownScaleCls(self)
	local worldScaleInfoList = GetClassList('WorldScaleInfo');
	for key, cls in pairs(worldScaleInfoList) do
		if cls.UpScale == self then
			return cls;
		end
	end
	return nil;
end

function Calculated_GetAreaScaleInfo(self)
	local idspace = GetIdspace(self);
	local worldScaleInfoList = GetClassList('WorldScaleInfo');
	return SafeIndex(worldScaleInfoList, idspace);
end

function Calculated_GetSiblingArea(self)
	if self.Parent == nil then
		return {};
	end
	local ret = {};
	for i, sibling in ipairs(self.Parent.Childs) do
		if self ~= sibling then
			table.insert(ret, sibling);
		end
	end
	return ret;
end

function Calculated_GetMaxSafty(self)
	if not IsSingleplayMode() then
		return 1000;
	end
	
	local sectionCount = Linq.new(self.Division)
		:sum(function(division) return #division.Section; end);
	return sectionCount * 100;
end

function Calculated_GetChildArea(self)
	local downScaleName = SafeIndex(self.ScaleInfo, 'DownScale', 'name');
	if downScaleName == nil then
		return {};
	end
	local downScaleAreas = GetClassList(downScaleName);
	local retChilds = {};
	for key, cls in pairs(downScaleAreas) do
		table.insert(retChilds, cls);
	end
	return retChilds;
end

function Calculated_GetParentArea(self)
	local upScaleName = SafeIndex(self.ScaleInfo, 'UpScale', 'name');
	if upScaleName == nil then
		LogAndPrint('Calculated_GetParentArea', '상위 스케일이 존재하지 않습니다..', self.name, self.ScaleInfo.name);
		return nil;
	end
	return SafeIndex(GetClassList(upScaleName), self.ParentKey);
end

function Calculated_GetZoneLinkedQuest(self)
	local questClsList = GetClassList('Quest');
	local retQuests = {};
	for questType, cls in pairs(questClsList) do
		if SafeIndex(cls, 'Mission', 'Zone') == self.name then
			table.insert(retQuests, cls);
		end
	end
	return retQuests;
end

function CanEnterArea(company, areaCls)
	if GetIdspace(areaCls) == 'Zone' then
		return company.ZoneState[areaCls.name].Opened;
	end
	
	local enterableCount = table.count(areaCls.Childs, function (childAreaCls) 
		return CanEnterArea(company, childAreaCls) 
	end);
	return enterableCount >= 2;	-- 둘 이상의 하위 지역에 입장이 가능해야 열림
end

function CalculatedProperty_ZoneEventGen_EventLevel(zoneEvent)
	local eventLevelList = GetClassList('EventLevel');
	for key, eventLevel in pairs(eventLevelList) do
		if eventLevel.Min <= zoneEvent.Lv and zoneEvent.Lv <= eventLevel.Max then
			return key;
		end
	end
	-- 조건을 만족하는 걸 못 찾으면, 일단 레벨이 제일 높은 걸로...
	local maxLv = 0;
	local maxEventLevel = nil;
	for key, eventLevel in pairs(eventLevelList) do
		if maxLv < eventLevel.Max then
			maxLv = eventLevel.Max;
			maxEventLevel = key;
		end
	end
	return maxEventLevel;
end
function CalculatedProperty_Quest_EventLevel(quest)
	local eventLevelList = GetClassList('EventLevel');
	for key, eventLevel in pairs(eventLevelList) do
		if eventLevel.Min <= quest.Lv and quest.Lv <= eventLevel.Max then
			return key;
		end
	end
	-- 조건을 만족하는 걸 못 찾으면, 일단 레벨이 제일 높은 걸로...
	local maxLv = 0;
	local maxEventLevel = nil;
	for key, eventLevel in pairs(eventLevelList) do
		if maxLv < eventLevel.Max then
			maxLv = eventLevel.Max;
			maxEventLevel = key;
		end
	end
	return maxEventLevel;
end
function CalculatedProperty_ZoneEventGen_LinkedQuest(zoneEvent)
	local quests = {};
	for _, questCls in pairs(GetClassList('Quest')) do
		if questCls.LinkedMissions[zoneEvent.Mission.name] then
			table.insert(quests, questCls);
		end
	end
	return quests;
end
function CP_Preloader_ZoneEventGen_LinkedQuest(clsList, column)
	--LogAndPrint('CP_Preloader_ZoneEventGen_LinkedQuest');
	local mission2ZoneEventGen = {};
	local quests = {};
	for _, cls in pairs(clsList) do
		ForceNewInsert(mission2ZoneEventGen, cls.Mission.name, cls.name);
		quests[cls.name] = {};
	end
	for _, questCls in pairs(GetClassList('Quest')) do
		for mission, _ in pairs(questCls.LinkedMissions) do
			for _, clsName in ipairs(SafeIndex(mission2ZoneEventGen, mission) or {}) do
				SafeInsert(quests, clsName, questCls);
			end
		end
	end
	return quests;
end