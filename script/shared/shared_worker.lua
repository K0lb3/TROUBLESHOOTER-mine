--------------------------------------------------------
-- 담당자 교체 가능 여부 판단 함수 
--------------------------------------------------------
function IsEnableChangeWorker(company, roster, workplace)
	-- 리턴 형식은 possible(bool), info, fail_reason(table) 으로 세개
	local isEnable = true;
	local reason = {};
	local info = {
		WorkSlot = 'Empty'
	};
	-- 0. 해당 작업장에 배치될 여유 공간이 존재하는가?
	local isEmptySlot = false;
	for key, value in pairs	(company[workplace]) do
		if StringToBool(value.Opened) then
			if value.Target == 'None' then
				isEmptySlot = true;
				info.WorkSlot = key;
				break;
			end		
		end	
	end
	if not isEmptySlot then
		isEnable = false;
		table.insert(reason, 'FullSlot');
	end
	
	-- 1. 교체 할 수 있는 컨디션 상태인가?
	if roster.ConditionState == 'Rest' then
		isEnable = false;
		table.insert(reason, 'ConditionStateRest');
	end
	
	-- 2. 해당 작업장에서 해제 할 수 있는 상태인가?
	local isEnableClear, clearInfo, clearReason = IsEnableClearWorker(company, roster, workplace);
	if not isEnableClear then
		isEnable = false;
		for key, value in pairs (clearReason) do
			table.insert(reason, value);
		end
	end
	return isEnable, info, reason;
end
--------------------------------------------------------
-- 담당자 해제 가능 여부 판단 함수 
--------------------------------------------------------
function IsEnableClearWorker(company, roster, workplace)
	-- 리턴 형식은 possible(bool), info, fail_reason(table) 으로 세개
	local isEnable = true;
	local reason = {};
	local info = {};
	
	if workplace == 'Workshop' then
		-- 추가해야함.	
	else
		isEnable = false;
		table.insert(reason, 'NotAvailableWorkplace');
	end
	return isEnable, info, reason;
end
--------------------------------------------------------
-- 담당자 업무 배치 해제 함수
--------------------------------------------------------
function ClearCurrentWork(dc, company, rosterName, workPlaceList)
	local curWork, curWorkLine = GetCurrentWorkByName(company, rosterName, workPlaceList);
	if curWork ~= 'None' then
		local prevWorkLine = curWork..'/'..curWorkLine;
		dc:UpdateCompanyProperty(company, prevWorkLine .. '/Target', 'None');
	end
end
function GetCurrentWorkByName(company, rosterName, workPlaceList)
	local curWork = 'None';
	local curWorkLine = '';
	for key, value in pairs (workPlaceList) do
		for key2, workValue in pairs (company[key]) do
			if StringToBool(workValue.Opened) then
				if workValue.Target == rosterName then
					curWork = key;
					curWorkLine = key2;
					break;
				end
			end
		end
		if curWork ~= 'None' then
			break;
		end
	end
	return curWork, curWorkLine;
end