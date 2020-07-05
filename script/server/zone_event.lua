-- 비어 있는 이벤트 슬롯이 있으면 호풀되는 함수. 
function InvalidateSingleEventSlot(zoneCls, zoneProperty, slotKey, candidates)
	if #candidates > 0 then
		return candidates[math.random(1, #candidates)];
	else
		return nil;
	end
end

function GetZoneEventSlotCompany(company, zoneType)
	local slotInfos = {};
	local key = company.Progress.Zone.EventType;
	local fixed = true;
	--LogAndPrint('\ncompany.Progress.Zone.EventType :: key =>', key);
	
	if key == 'None' or key == 'Zone00' or key == 'Zone01' then
		local checkedList = {};
		local eventGenList = GetClassList('ZoneEventGen');
		for key, eventGen in pairs(eventGenList) do
			local checkFunc = _G['CheckZoneEvent_'..key];
			if checkFunc and checkFunc(company) then
				local order = eventGen.Lv;
				if eventGen.Group == 'Scenario' then
					order = order + 10000;
				end
				table.insert(checkedList, {name = eventGen.name, order = order, slot = eventGen.Slot});
			end
		end
		-- Slot이 겹쳤을 때 처리를 위해, 우선순위가 높은 순으로 정렬 
		table.sort(checkedList, function(a, b)
			return a.order > b.order;
		end);
		-- 우선순위 높은 순으로 각 슬롯에 배치 
		for _, checked in ipairs(checkedList) do
			local slot = checked.slot;
			if not slotInfos[slot] then
				slotInfos[slot] = checked.name;
			end
		end
	else
		slotInfos = GetZoneEventSlotState(zoneType);
		local filtered = {};
		for slotType, eventType in pairs(slotInfos) do
			local eventGenCls = GetClassList('ZoneEventGen')[eventType];
			if eventType ~= '' and eventGenCls.Type == 'Normal' then
				if math.abs(company.Grade.Lv - eventGenCls.Grade.Lv) <= 1 then
					filtered[slotType] = eventType;
				end
			else
				filtered[slotType] = eventType;
			end
		end
		
		slotInfos = filtered;
		fixed = false;		
	end
	return slotInfos, fixed;
end

function GetZoneSlotEventType(company, zoneType, slotType)
	local slotInfo = GetZoneEventSlotCompany(company, zoneType);
	return slotInfo[slotType];
end

function FilterAvailableZoneEventSlot(company, zoneType, slotInfos)
	local availableSlotInfos, fixed = GetZoneEventSlotCompany(company, zoneType);

	if fixed then
		return availableSlotInfos;
	end
	
	local filtered = {};
	for slotType, eventType in pairs(slotInfos) do
		if eventType == '' or eventType == availableSlotInfos[slotType] then
			filtered[slotType] = eventType;
		end
	end
	return filtered;
end


