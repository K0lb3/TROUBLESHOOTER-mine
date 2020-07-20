function InitializeTeamDestroy(mid, session, team, onFieldOnly)
	local remainUnit = GetTeamCount(mid, team, StringToBool(onFieldOnly), true);
	local ret = remainUnit <= 0 and (SafeIndex(GetStageVariable(mid, '_escape_cnt_'), team) or 0) == 0;
	return ret, {Team = team};
end
function CHECK_TEAM_DESTROY(mid, session, eventArg, team, onFieldOnly)
	local remainUnit = GetTeamCount(mid, team, StringToBool(onFieldOnly, false), true);
	local ret = remainUnit <= 0 and (SafeIndex(GetStageVariable(mid, '_escape_cnt_'), team) or 0) == 0;
	return ret, {Team = team};
end
function InitializeUnitArrived(mid, session, unit, area)
	local obj = GetUnitFromUnitIndicator(mid, unit);
	if obj == nil then
		return false;
	end
	local pos = GetPosition(obj);
	
	local from, to = area[1].From[1], area[1].To[1];
	local ret = PositionInArea(from, to, pos);
	return ret, {Unit = obj};
end
function InitializeUnitArrived2(mid, session, unit, areaIndicator)
	local obj = GetUnitFromUnitIndicator(mid, unit);
	if obj == nil then
		return false;
	end
	local pos = GetPosition(obj);
	local ret = PositionInAreaIndicator(mid, areaIndicator, pos, {});
	return ret, {Unit = obj};
end
function InitializeUnitNotInArea(mid, session, unit, area)
	local obj = GetUnitFromUnitIndicator(mid, unit);
	if obj == nil then
		return false;
	end
	local pos = GetPosition(obj);
	local from, to = area[1].From[1], area[1].To[1];
	local ret = PositionInArea(from, to, pos);

	return not ret, {Unit = obj};
end
function InitializeUnitNotInArea2(mid, session, unit, areaIndicator)
	local obj = GetUnitFromUnitIndicator(mid, unit);
	if obj == nil then
		return false;
	end
	local pos = GetPosition(obj);
	local ret = PositionInAreaIndicator(mid, areaIndicator, pos, {});
	return not ret, {Unit = obj};
end
function CHECK_UNIT_ARRIVED(mid, session, eventArg, unit, area)
	if eventArg.NoEvent then
		return nil;
	end
	local obj = GetUnitFromUnitIndicator(mid, unit)
	if obj == nil or eventArg.Unit ~= obj then return nil end
	
	local pos = eventArg.Position;
	local from, to = area[1].From[1], area[1].To[1];
	local ret = PositionInArea(from, to, pos);
	return ret, {Unit = obj};
end
function CHECK_UNIT_ARRIVED2(mid, session, eventArg, unit, areaIndicator)
	if eventArg.NoEvent then
		return nil;
	end
	local obj = GetUnitFromUnitIndicator(mid, unit)
	if obj == nil or eventArg.Unit ~= obj then return nil end
	
	local pos = eventArg.Position;
	local ret = PositionInAreaIndicator(mid, areaIndicator, pos, {});
	return ret, {Unit = obj};
end
function CHECK_UNIT_NOTINAREA(mid, session, eventArg, unit, area)
	if eventArg.NoEvent then
		return nil;
	end
	local obj = GetUnitFromUnitIndicator(mid, unit)
	if obj == nil or eventArg.Unit ~= obj then return nil end
	
	local pos = eventArg.Position;
	local from, to = area[1].From[1], area[1].To[1];
	local ret = PositionInArea(from, to, pos);

	return not ret, {Unit = obj};
end
function CHECK_UNIT_NOTINAREA2(mid, session, eventArg, unit, areaIndicator)
	if eventArg.NoEvent then
		return nil;
	end
	local obj = GetUnitFromUnitIndicator(mid, unit)
	if obj == nil or eventArg.Unit ~= obj then return nil end
	
	local pos = eventArg.Position;
	local ret = PositionInAreaIndicator(mid, areaIndicator, pos, {});
	return not ret, {Unit = obj};
end
function InitializeTeamArrived(mid, session, team, area)
	local teamCount = GetTeamCount(mid, team);
	for i = 1, teamCount do
		local teamMember = GetTeamUnitByIndex(mid, team, i);
		local pos = GetPosition(teamMember);
		local from, to = area[1].From[1], area[1].To[1];
		if PositionInArea(from, to, pos) then
			return true, {Unit = teamMember};
		end
	end
	return false;
end
function InitializeTeamArrived2(mid, session, team, areaIndicator)
	local teamCount = GetTeamCount(mid, team);
	for i = 1, teamCount do
		local teamMember = GetTeamUnitByIndex(mid, team, i);
		local pos = GetPosition(teamMember);
		if PositionInAreaIndicator(mid, areaIndicator, pos, {}) then	
			return true, {Unit = teamMember};
		end
	end
	return false;
end


function InitializeGroupArrived(mid, session, group, areaIndicator)
    local units = GetAllUnit(GetMission(mid));
	local count = 0;
	for i, unit in ipairs(units) do
	    local groupName = GetInstantProperty(unit, 'GroupName')
	    if groupName ~= nil then
	        groupName = string.upper(groupName)
	    end
		if groupName == string.upper(group) then
		    local pos = GetPosition(unit);
			if PositionInAreaIndicator(mid, areaIndicator, pos, {}) then
				return true, {Unit = unit};
			end
		end
	end
	
	return false;
end

function CHECK_TEAM_ARRIVED(mid, session, eventArg, team, area)
	if eventArg.EventType == 'UnitMoved' or eventArg.EventType == 'UnitPositionChanged' then
		if eventArg.NoEvent then
			return nil;
		end
		local movedUnit = eventArg.Unit;
		if GetTeam(movedUnit) ~= team or IsDead(movedUnit) then
			return nil;
		end
		local from, to = area[1].From[1], area[1].To[1];
		local curPos = eventArg.Position;
		local prevPos = eventArg.BeginPosition;
		local curInArea = PositionInArea(from, to, curPos);
		local prevInArea = PositionInArea(from, to, prevPos);
		-- 범위 바깥 이동이면 무시
		if not prevInArea and not curInArea then
			return nil;
		end
		-- 범위 안에서 나갔어도 다른 팀원이 범위 안에 있으면 성공
		if prevInArea and not curInArea then
			local teamCount = GetTeamCount(mid, team);
			for i = 1, teamCount do
				local teamMember = GetTeamUnitByIndex(mid, team, i);
				local pos = GetPosition(teamMember);
				if PositionInArea(from, to, pos) then
					return true, {Unit = teamMember};
				end
			end
			-- 이제 아무도 범위 안에 없으면 실패
			return false;
		end
		-- 범위 안으로 이동했으니 성공
		if curInArea then
			return true, {Unit = movedUnit};
		end
	elseif eventArg.EventType == 'UnitDead' then
		local deadUnit = eventArg.Unit;
		if GetTeam(deadUnit) ~= team then
			return nil;
		end
		local from, to = area[1].From[1], area[1].To[1];
		-- 범위 바깥에서 죽었으면 무시
		local pos = GetPosition(deadUnit);
		if not PositionInArea(from, to, pos) then
			return nil;
		end
		-- 범위 안에서 죽었는데 다른 팀원도 범위 안에 있으면 성공
		local teamCount = GetTeamCount(mid, team);
		for i = 1, teamCount do
			local teamMember = GetTeamUnitByIndex(mid, team, i);
			local pos = GetPosition(teamMember);
			if PositionInArea(from, to, pos) then
				return true, {Unit = teamMember};
			end
		end
		-- 범위 안에서 죽었고 이제 아무도 범위 안에 없으면 실패
		return false;
	elseif eventArg.EventType == 'UnitTeamChanged' then
		if eventArg.Team ~= team and eventArg.PrevTeam ~= team then
			return nil;
		end
		local from, to = area[1].From[1], area[1].To[1];
		local curPos = GetPosition(eventArg.Unit);
		if not PositionInArea(from, to, curPos) then
			return nil;
		end
		-- 이전에 영역 안에 있었던 경우에
		local teamCount = GetTeamCount(mid, team);
		for i = 1, teamCount do
			local teamMember = GetTeamUnitByIndex(mid, team, i);
			local pos = GetPosition(teamMember);
			if PositionInArea(from, to, pos) then
				return true, {Unit = teamMember};
			end
		end
	end
end
function CHECK_TEAM_ARRIVED2(mid, session, eventArg, team, areaIndicator)
	if eventArg.EventType == 'UnitMoved' or eventArg.EventType == 'UnitPositionChanged' then
		if eventArg.NoEvent then
			return nil;
		end
		local movedUnit = eventArg.Unit;
		if GetTeam(movedUnit) ~= team or IsDead(movedUnit) then
			return nil;
		end
		local curPos = eventArg.Position;
		local prevPos = eventArg.BeginPosition;
		local curInArea = PositionInAreaIndicator(mid, areaIndicator, curPos, {});
		local prevInArea = PositionInAreaIndicator(mid, areaIndicator, prevPos, {});
		-- 범위 바깥 이동이면 무시
		if not prevInArea and not curInArea then
			return nil;
		end
		-- 범위 안에서 나갔어도 다른 팀원이 범위 안에 있으면 성공
		if prevInArea and not curInArea then
			local teamCount = GetTeamCount(mid, team);
			for i = 1, teamCount do
				local teamMember = GetTeamUnitByIndex(mid, team, i);
				local pos = GetPosition(teamMember);
				if PositionInAreaIndicator(mid, areaIndicator, pos, {}) then
					return true, {Unit = teamMember};
				end
			end
			-- 이제 아무도 범위 안에 없으면 실패
			return false;
		end
		-- 범위 안으로 이동했으니 성공
		if curInArea then
			return true, {Unit = movedUnit};
		end
	elseif eventArg.EventType == 'UnitDead' then
		local deadUnit = eventArg.Unit;
		if GetTeam(deadUnit) ~= team then
			return nil;
		end
		-- 범위 바깥에서 죽었으면 무시
		local pos = GetPosition(deadUnit);
		if not PositionInAreaIndicator(mid, areaIndicator, pos, {}) then
			return nil;
		end
		-- 범위 안에서 죽었는데 다른 팀원도 범위 안에 있으면 성공
		local teamCount = GetTeamCount(mid, team);
		for i = 1, teamCount do
			local teamMember = GetTeamUnitByIndex(mid, team, i);
			local pos = GetPosition(teamMember);
			if PositionInAreaIndicator(mid, areaIndicator, pos, {}) then
				return true, {Unit = teamMember};
			end
		end
		-- 범위 안에서 죽었고 이제 아무도 범위 안에 없으면 실패
		return false;
	elseif eventArg.EventType == 'UnitTeamChanged' then
		if eventArg.Team ~= team and eventArg.PrevTeam ~= team then
			return nil;
		end
		local curPos = GetPosition(eventArg.Unit);
		if not PositionInAreaIndicator(mid, areaIndicator, curPos, {}) then
			return nil;
		end
		-- 이전에 영역 안에 있었던 경우에
		local teamCount = GetTeamCount(mid, team);
		for i = 1, teamCount do
			local teamMember = GetTeamUnitByIndex(mid, team, i);
			local pos = GetPosition(teamMember);
			if PositionInAreaIndicator(mid, areaIndicator, pos, {}) then
				return true, {Unit = teamMember};
			end
		end
	end
end


function CHECK_GROUP_ARRIVED(mid, session, eventArg, group, areaIndicator)
	if eventArg.EventType == 'UnitMoved' or eventArg.EventType == 'UnitPositionChanged' then
		if eventArg.NoEvent then
			return nil;
		end
		local movedUnit = eventArg.Unit;
	    local groupName = GetInstantProperty(movedUnit, 'GroupName')
	    if groupName ~= nil then
	        groupName = string.upper(groupName)
	    end
		if groupName ~= string.upper(group) then
			return nil;
		end
		local pos = eventArg.Position;
		return PositionInAreaIndicator(mid, areaIndicator, pos, {}), {Unit = movedUnit};
	elseif eventArg.EventType == 'UnitDead' then
	    local groupName = GetInstantProperty(deadUnit, 'GroupName')
	    if groupName ~= nil then
	        groupName = string.upper(groupName)
	    end
		local deadUnit = eventArg.Unit;
		if groupName ~= string.upper(group) then
			return nil;
		end
		-- 범위 바깥에서 죽었으면 무시
		local pos = GetPosition(deadUnit);
		if not PositionInAreaIndicator(mid, areaIndicator, pos, {}) then
			return nil;
		end
		-- 범위 안에서 죽었는데 다른 팀원도 범위 안에 있으면 성공
		local units = GetAllUnit(GetMission(mid));
		local count = 0;
		for i, unit in ipairs(units) do
    	    local groupName = GetInstantProperty(unit, 'GroupName')
    	    if groupName ~= nil then
    	        groupName = string.upper(groupName)
    	    end
			if groupName == string.upper(group) then
			    local pos = GetPosition(unit);
    			if PositionInAreaIndicator(mid, areaIndicator, pos, {}) then
    				return true, {Unit = unit};
    			end
			end
		end
		
		-- 범위 안에서 죽었고 이제 아무도 범위 안에 없으면 실패
		return false;
	end
end


function CHECK_TEAM_TO_ARRIVED_TO_UNIT(mid, session, eventArg, team, unit2, range)
	if eventArg.NoEvent then
		return nil;
	end
	local teamCount = GetTeamCount(mid, team);
	local target = GetUnitFromUnitIndicator(mid, unit2)
	if target == nil then
	    return nil; 
	end
	if eventArg.EventType == 'UnitTeamChanged' and target == eventArg.Unit then
		-- 대상의 팀이 변경된 경우는 상관없음.
		return nil;
	end
	local targetPos = GetPosition(target);
	for i = 1, teamCount do
		local obj = GetTeamUnitByIndex(mid, team, i);
		if obj ~= nil then
        	if eventArg.Unit == obj or eventArg.Unit == target then
        		local pos = GetPosition(obj);
            	local distance = GetDistance3D(pos, targetPos);
            	if distance <= range then
                	return true, {Unit1 = obj, Unit2 = target, Range = range};
                end
            end
        end
	end
	return nil
end
function InitializeTeamArrivedToUnit(mid, session, team, unit2, range)
	local teamCount = GetTeamCount(mid, team);
	local target = GetUnitFromUnitIndicator(mid, unit2)
	if target == nil then return nil; end
	local targetPos = GetPosition(target);
	for i = 1, teamCount do
		local obj = GetTeamUnitByIndex(mid, team, i);
		if obj ~= nil then
    		local pos = GetPosition(obj);
        	local distance = GetDistance3D(pos, targetPos);
        	if distance <= range then
            	return true, {Unit1 = obj, Unit2 = target, Range = range};
            end
        end
	end
	
	return nil
end
function InitializeTeamInSightToTeam(mid, session, team, team2)
	return InitializeTeamInSightToTeamEx(mid, session, team, nil, team2, nil);
end
function CheckTeamInSightToTeam(mid, session, eventArg, team, team2)
	return CheckTeamInSightToTeamEx(mid, session, eventArg, team, nil, team2, nil);
end
function InitializeTeamInSightToTeamEx(mid, session, team, unitFilter, team2, unitFilter2)
	local targetTeamCount = GetTeamCount(mid, team);
	local targets = {}
	for i = 1, targetTeamCount do
		local u = GetTeamUnitByIndex(mid, team, i);
		if LoadStringTest(unitFilter, {unit = u}) ~= false then
			table.insert(targets, u);
		end
	end
	local searchTeamCount = GetTeamCount(mid, team2);
	for i = 1, searchTeamCount do
		local searchUnit = GetTeamUnitByIndex(mid, team2, i);
		if LoadStringTest(unitFilter2, {unit = searchUnit}) ~= false then
			for j, targetUnit in ipairs(targets) do
				if IsInSight(searchUnit, GetPosition(targetUnit), true) then
					return true, {TargetUnit = targetUnit, SearchUnit = searchUnit};
				end
			end
		end
	end
	return false;
end
function CheckTeamInSightToTeamEx(mid, session, eventArg, team, unitFilter, team2, unitFilter2)
	if (GetTeam(eventArg.Unit) ~= team and GetTeam(eventArg.Unit) ~= team2)
		or eventArg.MovingForAbility
		or eventArg.Unit.HP <= 0 then
		return nil;
	end
	local testTeam = nil;
	local testFunc = nil;
	local outputKey = nil
	local output = nil;
	if GetTeam(eventArg.Unit) == team then
		if LoadStringTest(unitFilter, {unit = eventArg.Unit}) == false then
			return nil;
		end
		testTeam = team2;
		testFunc = function(obj) return LoadStringTest(unitFilter2, {unit = obj}) ~= false and IsInSight(obj, eventArg.Unit, true); end
		outputKey = 'SearchUnit';
		output = {TargetUnit = eventArg.Unit};
	else
		if LoadStringTest(unitFilter2, {unit = eventArg.Unit}) == false then
			return nil;
		end
		testTeam = team;
		testFunc = function(obj) return LoadStringTest(unitFilter, {unit = obj}) ~= false and IsInSight(eventArg.Unit, obj, true); end
		outputKey = 'TargetUnit';
		output = {SearchUnit = eventArg.Unit};
	end
	local teamCount = GetTeamCount(mid, testTeam);
	for i = 1, teamCount do
		local obj = GetTeamUnitByIndex(mid, testTeam, i);
		if testFunc(obj) then
			output[outputKey] = obj;
			return true, output;
		end
	end
	return false;
end

function LoadStringTest(testExpr, envTable)
	if testExpr == nil then
		return nil;
	end
	local func = loadstring('return '..tostring(testExpr));
	local env = table.deepcopy(envTable);
	setmetatable(env, {__index = _G});
	setfenv(func, env);
	return func();
end

function InitializeTeamInSightToUnit(mid, session, team, findUnitFilter, unitIndicator, checkEachOther)
	local targetTeamCount = GetTeamCount(mid, team);
	local targets = {}
	for i = 1, targetTeamCount do
		table.insert(targets, GetTeamUnitByIndex(mid, team, i));
	end
	local insightUnitKeys = {};
	local searchUnit = GetUnitFromUnitIndicator(mid, unitIndicator);
	for j, targetUnit in ipairs(targets) do
	
		local validUnit = true;
		if findUnitFilter and findUnitFilter ~= 'true' then
			validUnit = LoadStringTest(findUnitFilter, {unit = targetUnit}) ~= false;
		end
			
		if validUnit 
			and IsInSight(searchUnit, GetPosition(targetUnit), true)
			and (not StringToBool(checkEachOther) or IsInSight(targetUnit, searchUnit)) then
			insightUnitKeys[GetObjKey(targetUnit)] = true;
		end
	end
	session.InsightUnitKeySet = insightUnitKeys;
	if next(insightUnitKeys) ~= nil then
		local first = next(insightUnitKeys);
		return true, {TargetUnit = GetUnit(mid, first), SearchUnit = searchUnit};
	end
	return false;
end

function CheckTeamInSightToUnit(mid, session, eventArg, team, findUnitFilter, unitIndicator, checkEachOther)
	local searchUnit = GetUnitFromUnitIndicator(mid, unitIndicator);
	if (GetTeam(eventArg.Unit) ~= team and eventArg.Unit ~= searchUnit)
		or eventArg.Unit.HP <= 0
		or eventArg.MovingForAbility
		or session.InsightUnitKeySet == nil then		--초기화 전
		return nil;
	end
	local testTeam = nil;
	local testFunc = nil;
	local outputKey = nil
	local output = nil;
	if GetTeam(eventArg.Unit) == team then
		if findUnitFilter and findUnitFilter ~= 'true' then
			local validUnit = LoadStringTest(findUnitFilter, {unit = eventArg.Unit});
			if validUnit == false then
				return nil;
			end
		end
		
		local keySet = session.InsightUnitKeySet;
		local thisOk = false;
		if IsInSight(searchUnit, GetPosition(eventArg.Unit), true)
		and (not StringToBool(checkEachOther) or IsInSight(eventArg.Unit, searchUnit)) then
			keySet[GetObjKey(eventArg.Unit)] = true;
			thisOk = true;
		else
			keySet[GetObjKey(eventArg.Unit)] = nil;
		end
		session.InsightUnitKeySet = keySet;
		if thisOk then
			return true, {TargetUnit = eventArg.Unit, SearchUnit = searchUnit};
		end
		
		local firstKey = next(session.InsightUnitKeySet);
		if firstKey then
			return nil;
		else
			return false;
		end
	else
		local teamCount = GetTeamCount(mid, team);
		local keySet = {};
		for i = 1, teamCount do
			local obj = GetTeamUnitByIndex(mid, team, i);
			
			local validUnit = true;
			if findUnitFilter and findUnitFilter ~= 'true' then
				validUnit = LoadStringTest(findUnitFilter, {unit = obj}) ~= false;
			end
			
			-- 서치 대상이 움직인 경우이므로 풀로 서치하되 이번의 결과로 그냥 session을 갱신하면 된다.
			if validUnit 
				and IsInSight(searchUnit, GetPosition(obj), true)
				and (not StringToBool(checkEachOther) or IsInSight(obj, searchUnit, true))
				then
				keySet[GetObjKey(obj)] = true;
			end
		end
		session.InsightUnitKeySet = keySet;
		
		local firstKey = next(keySet);
		if firstKey then
			return true, {TargetUnit = GetUnit(mid, firstKey), SearchUnit = searchUnit};
		else
			return false;
		end
	end
end
function InitializeUnitArrivedToUnit(mid, session, unit, unit2, range)
	local obj = GetUnitFromUnitIndicator(mid, unit)
	if obj == nil then return nil; end
	local pos = GetPosition(obj);
	
	local target = GetUnitFromUnitIndicator(mid, unit2)
	if target == nil then return nil; end
	local targetPos = GetPosition(target);
	
	local distance = GetDistance3D(pos, targetPos);
	return distance <= range, {Unit1 = obj, Unit2 = target, Range = range};
end
function CHECK_UNIT_TO_ARRIVED_TO_UNIT(mid, session, eventArg, unit, unit2, range)
	if eventArg.MovingForAbility or eventArg.NoEvent then
		return nil;
	end
	local obj = GetUnitFromUnitIndicator(mid, unit)
	if obj == nil then return nil; end
	local pos = GetPosition(obj);
	
	local target = GetUnitFromUnitIndicator(mid, unit2)
	if target == nil then return nil; end
	local targetPos = GetPosition(target);
	
	if eventArg.Unit ~= obj and eventArg.Unit ~= target then
		return nil;
	end
	
	local distance = GetDistance3D(pos, targetPos);
	return distance <= range, {Unit1 = obj, Unit2 = target, Range = range};
end
function CHECK_MISSION_BEGIN(mid, session, eventArg)
	-- MissionBegin 이벤트만 왔다면 그냥 무조건 발동함..
	return true;
end
function CHECK_MISSION_END(mid, session, eventArg, team)
	return eventArg.Winner == team;
end
function InitializeUnitDead(mid, session, unit, checkKiller)
	local obj = GetUnitFromUnitIndicator(mid, unit, nil, true);
	local ret = IsDead(obj);
	if ret and StringToBool(checkKiller) then
		ret = false; -- 누가 죽였는지 알 수가 없다.
	end	
	return ret, {Unit = obj};
end
function CHECK_UNIT_DEAD(mid, session, eventArg, unit, checkKiller)
	local obj = GetUnitFromUnitIndicator(mid, unit, nil, true);
	if not obj or obj ~= eventArg.Unit then	return nil; end	-- 딴 애가 죽는건 신경안씀
	if eventArg.EventType == 'UnitBeingExcluded' and not eventArg.AutoPlay then	-- 오토 플레이가 아닌 제외는 무시
		return nil;
	end
	local ret = eventArg.Virtual or IsDead(obj) or eventArg.EventType == 'UnitBeingExcluded';
	if ret and StringToBool(checkKiller) then
		ret = (eventArg.Killer ~= nil and not IsDead(eventArg.Killer) and eventArg.Killer ~= obj);
	end	
	return ret, {Unit = obj, Killer = eventArg.Killer};
end
function CHECK_ANY_UNIT_DEAD(mid, session, eventArg, unit, checkKiller)
	local find = false;
	local units = GetUnitsFromAnyUnitIndicator(mid, unit, {}, true);
	for _, obj in ipairs(units) do
		if obj == eventArg.Unit then
			find = true;
			break;
		end
	end
	if not find then
		return nil;
	end
	local obj = eventArg.Unit;
	if eventArg.EventType == 'UnitBeingExcluded' and not eventArg.AutoPlay then	-- 오토 플레이가 아닌 제외는 무시
		return nil;
	end
	local ret = eventArg.Virtual or IsDead(obj) or eventArg.EventType == 'UnitBeingExcluded';
	if ret and StringToBool(checkKiller) then
		ret = (eventArg.Killer ~= nil and not IsDead(eventArg.Killer) and eventArg.Killer ~= obj);
	end
	return ret, {Unit = obj, Killer = eventArg.Killer};
end
function CHECK_UNIT_LASTKILL(mid, session, eventArg, unit)
	local obj = GetUnitFromUnitIndicator(mid, unit, nil, true);
	if not obj or obj ~= eventArg.Killer then	return false; end	-- 딴 애가 죽는건 신경안씀
	local ret = IsDead(eventArg.Unit);
	if ret then
		return ret, {Unit = obj};
	else
		return nil, {Unit = obj};
	end
end
function InitializeTeamUnitAliveCount(mid, session, team, operation, value, onFieldOnly)
    local remainUnit = GetTeamCount(mid, team, StringToBool(onFieldOnly));
    
	return CompareOperation(operation, remainUnit, value)
end
function CHECK_TeamUnitAliveCount(mid, session, eventArg, team, operation, value, onFieldOnly)
    local remainUnit = GetTeamCount(mid, team, StringToBool(onFieldOnly));
    
	return CompareOperation(operation, remainUnit, value)
end
function InitializeUnitAlive(mid, session, unit)
	local obj = GetUnitFromUnitIndicator(mid, unit, nil, true);
	if not obj or IsDead(obj) then return false; end
	return true, {Unit = obj};
end
function CHECK_UNIT_ALIVE(mid, session, eventArg, unit)
	if eventArg.EventType == 'MissionPrepare' then
      return InitializeUnitAlive(mid, session, unit);
    end
	local isAlive = nil;
	local isDead = CHECK_UNIT_DEAD(mid, session, eventArg, unit);
	if isDead == nil then
		isAlive = nil;
	else
		isAlive = not isDead;
	end
	return isAlive, {Unit = GetUnitFromUnitIndicator(mid, unit, nil, true)};
end
function CHECK_TEAM_DEAD(mid, session, eventArg, team)
	if GetTeam(eventArg.Unit) ~= team then
		return nil;
	end
	if eventArg.EventType == 'UnitBeingExcluded' and not eventArg.AutoPlay then	-- 오토 플레이가 아닌 제외는 무시
		return nil;
	end
	local ret = eventArg.Virtual or IsDead(eventArg.Unit) or eventArg.EventType == 'UnitBeingExcluded';
	return ret, {Team = team, Unit = eventArg.Unit};
end
function CHECK_GROUP_DEAD(mid, session, eventArg, group)
    local groupName = GetInstantProperty(eventArg.Unit, 'GroupName')
    if groupName ~= nil then
        groupName = string.upper(groupName)
    end
	if groupName ~= string.upper(group) then
		return nil;
	end
	if eventArg.EventType == 'UnitBeingExcluded' and not eventArg.AutoPlay then	-- 오토 플레이가 아닌 제외는 무시
		return nil;
	end
	local ret = eventArg.Virtual or IsDead(eventArg.Unit) or eventArg.EventType == 'UnitBeingExcluded';
	return ret, {Group = group, Unit = eventArg.Unit};
end
function InitializeUnitInSightToTeam(mid, session, targetUnit, team, SearchUnitFilter)
	local target = GetUnitFromUnitIndicator(mid, targetUnit);
	if target == nil then
		return false;
	end
	local pos = GetPosition(target);
	local teamMember = GetTeamUnitByIndex(mid, team, 1);
	if teamMember == nil then return false; end
	return IsInSight(teamMember, pos), {Unit = target, Team = team, Finder = nil };
end
function CHECK_UNIT_IN_SIGHT_TO_TEAM(mid, session, eventArg, targetUnit, team, searchUnitFilter)
	if GetTeam(eventArg.Unit) ~= team
		or eventArg.Unit.HP <= 0
		or eventArg.MovingForAbility
		or eventArg.NoEvent then
		return nil;
	end
	if searchUnitFilter then
		local func = loadstring('return '..tostring(searchUnitFilter));
		local env = {unit = eventArg.Unit};
		setmetatable(env, {__index = _G});
		setfenv(func, env);
		if func() == false then
			return nil;
		end
	end
	local target = GetUnitFromUnitIndicator(mid, targetUnit);
	if target == nil or target == eventArg.Unit then
		return false;
	end
	local pos = GetPosition(target);
	return IsInSight(eventArg.Unit, pos), {Unit = target, Team = team, Finder = eventArg.Unit};
end	
function InitializeNoEnemyInSightToTeam(mid, session, team)
	local myTeamCount = GetTeamCount(mid, team)
	if myTeamCount == 0 then
		return false, {};
	end
	local myObj = GetTeamUnitByIndex(mid, team, 1);	
	local allUnits = GetAllUnitInSightByTeam(mid, team);
	return not table.findif(allUnits, function(unit) return GetRelation(myObj, unit) == 'Enemy'; end), {}
end
function CHECK_NOENEMY_IN_SIGHT_TO_TEAM(mid, session, eventArg, team)
	if eventArg.MovingForAbility
		or eventArg.Unit.HP <= 0 then
		return nil;
	end
	local myTeamCount = GetTeamCount(mid, team)
	if myTeamCount == 0 then
		return false, {};
	end
	-- 적대 팀이 아닌 이벤트는 무시
	local mission = GetMission(mid);
	if eventArg.EventType ~= 'UnitTeamChanged' then
		if GetRelationByTeamName(mission, team, GetTeam(eventArg.Unit)) ~= 'Enemy' then
			return nil;
		end
	else
		if GetRelationByTeamName(mission, team, eventArg.Team) ~= 'Enemy'
			and GetRelationByTeamName(mission, team, eventArg.PrevTeam) ~= 'Enemy' then
			return nil;
		end
	end
	local myObj = GetTeamUnitByIndex(mid, team, 1);
	local allUnits = GetAllUnitInSightByTeam(mid, team);
	return not table.findif(allUnits, function(unit) return GetRelation(myObj, unit) == 'Enemy'; end), {}
end
function InitializeUnitInSightToUnit(mid, session, targetUnit, searchUnit)
	local sUnit = GetUnitFromUnitIndicator(mid, searchUnit);
	local tUnit = GetUnitFromUnitIndicator(mid, targetUnit);
	if sUnit == nil or tUnit == nil then
		return false;
	end
	
	local targetPos = GetPosition(tUnit);
	return IsInSight(sUnit, targetPos, true), {TargetUnit = tUnit, SearchUnit = sUnit};
end
function CHECK_UNIT_IN_SIGHT_TO_UNIT(mid, session, eventArg, targetUnit, searchUnit)
	local sUnit = GetUnitFromUnitIndicator(mid, searchUnit);
	local tUnit = GetUnitFromUnitIndicator(mid, targetUnit);
	if (sUnit ~= eventArg.Unit and tUnit ~= eventArg.Unit)	-- 둘 중 하나가 움직였을때
		or eventArg.Unit.HP <= 0
		or eventArg.MovingForAbility then
		return nil;
	end
	if sUnit == nil or tUnit == nil then
		return false;
	end
	
	local targetPos = GetPosition(tUnit);
	return IsInSight(sUnit, targetPos, true), {TargetUnit = tUnit, SearchUnit = sUnit};
end
function InitializeUnitInSightEachOther(mid, session, unit1, unit2)
	local uObj1 = GetUnitFromUnitIndicator(mid, unit1);
	local uObj2 = GetUnitFromUnitIndicator(mid, unit2);
	if uObj1 == nil or uObj2 == nil then
		return false;
	end
	
	local pos1 = GetPosition(uObj1);
	local pos2 = GetPosition(uObj2);
	return IsInSight(uObj1, pos2, true) and IsInSight(uObj2, pos1, true), {Unit1 = uObj1, Unit2 = uObj2};
end
function CheckUnitInSightEachOther(mid, session, eventArg, unit1, unit2)
	if eventArg.NoEvent
		or eventArg.Unit.HP <= 0 then
		return nil;
	end
	local uObj1 = GetUnitFromUnitIndicator(mid, unit1);
	local uObj2 = GetUnitFromUnitIndicator(mid, unit2);
	if (uObj1 ~= eventArg.Unit and uObj2 ~= eventArg.Unit)
		or eventArg.MovingForAbility then
		return nil;
	end
	
	if uObj1 == nil or uObj2 == nil then
		return false;
	end
	
	local pos1 = GetPosition(uObj1);
	local pos2 = GetPosition(uObj2);
	return IsInSight(uObj1, pos2, true) and IsInSight(uObj2, pos1, true), {Unit1 = uObj1, Unit2 = uObj2};
end
function InitializeAnyUnitInSightToTeam(mid, session, targetUnit, team)
	local targets = GetUnitsFromAnyUnitIndicator(mid, targetUnit);
	if table.empty(targets) then
		return false;
	end
	local teamMember = GetTeamUnitByIndex(mid, team, 1);
	if teamMember == nil then
		return false;
	end
	for _, target in ipairs(targets) do
		local pos = GetPosition(target);
		if IsInSight(teamMember, pos) then
			return true, { Unit = target, Team = team, Finder = nil };
		end
	end
	return false;
end
function CHECK_ANY_UNIT_IN_SIGHT_TO_TEAM(mid, session, eventArg, targetUnit, team)
	if GetTeam(eventArg.Unit) ~= team
		or eventArg.Unit.HP <= 0
		or eventArg.MovingForAbility then
		return nil;
	end
	local targets = GetUnitsFromAnyUnitIndicator(mid, targetUnit);
	if table.empty(targets) then
		return false;
	end
	for _, target in ipairs(targets) do
		local pos = GetPosition(target);
		if IsInSight(eventArg.Unit, pos) then
			return true, { Unit = target, Team = team, Finder = eventArg.Unit };
		end
	end
	return false;
end	
function InitializeAnyUnitInSightToUnit(mid, session, targetUnit, searchUnit)
	local sUnit = GetUnitFromUnitIndicator(mid, searchUnit);
	if sUnit == nil then
		return false;
	end
	local tUnits = GetUnitsFromAnyUnitIndicator(mid, targetUnit);
	if table.empty(tUnits) then
		return false;
	end
	for _, tUnit in ipairs(tUnits) do
		local targetPos = GetPosition(tUnit);
		if IsInSight(sUnit, targetPos, true) then
			return true, { TargetUnit = tUnit, SearchUnit = sUnit };
		end
	end
	return false;
end
function CHECK_ANY_UNIT_IN_SIGHT_TO_UNIT(mid, session, eventArg, targetUnit, searchUnit)
	local sUnit = GetUnitFromUnitIndicator(mid, searchUnit);
	if sUnit == nil then
		return false;
	end
	if eventArg.MovingForAbility
		or eventArg.Unit.HP <= 0 then
		return nil;
	end
	local tUnits = GetUnitsFromAnyUnitIndicator(mid, targetUnit);
	if table.empty(tUnits) then
		return false;
	end
	for _, tUnit in ipairs(tUnits) do
		if sUnit == eventArg.Unit or tUnit == eventArg.Unit then	-- 둘 중 하나가 움직였을때
			local targetPos = GetPosition(tUnit);
			if IsInSight(sUnit, targetPos, true) then
				return true, { TargetUnit = tUnit, SearchUnit = sUnit };
			end
		end
	end
	return false;
end

function InitializeTeamBuffState(mid, session, team, buffName, operation, value)
	local remainUnit = GetTeamCount(mid, team);
	local buffUnitCount = 0
	if remainUnit ~= nil and remainUnit ~= 0 then
		for index = 1, remainUnit do
			local u = GetTeamUnitByIndex(mid, team, index);
			if GetBuff(u,buffName) ~= nil then
				buffUnitCount = buffUnitCount + 1
			end
		end
    end
	
	return CompareOperation(operation, buffUnitCount, value);
end
function CheckTeamBuffState(mid, session, eventArg, team, buffName, operation, value)
	local remainUnit = GetTeamCount(mid, team);
	local buffUnitCount = 0
	if remainUnit ~= nil and remainUnit ~= 0 then
		for index = 1, remainUnit do
			local u = GetTeamUnitByIndex(mid, team, index);
			if GetBuff(u,buffName) ~= nil then
				buffUnitCount = buffUnitCount + 1
			end
		end
    end
    
	return CompareOperation(operation, buffUnitCount, value);
end

function CheckTeamBuffAdded(mid, session, eventArg, team, buffName)
	if GetTeam(eventArg.Unit) ~= team 
		or eventArg.BuffName ~= buffName then
		return false;
	end
	return true, {Unit = eventArg.Unit};
end

function CheckFriendshipTest(mid, session, eventArg, friendship, operation, value)
	local mission = GetMission(mid)
	local companies = GetAllCompanyInMission(mission);
	if #companies == 0 then
		return false; -- 회사가 하나도 없으면 에러지뭐
	end
	-- 모든 회사가 통과하면 성공~!
	for i, company in ipairs(companies) do
		local point = SafeIndex(company.Friendship, friendship[1].FromChar, friendship[1].ToChar);
		if not CompareOperation(operation, point, value) then
			return false;
		end
	end
	return true;
end

function CheckTeamRunIntoBattle(mid, session, eventArg, team)
	if GetTeam(eventArg.Unit) ~= team then
		return nil;
	end
	if eventArg.BuffName ~= 'Patrol' and eventArg.BuffName ~= 'Stand' then
		return false;
	end
	return true, {Unit = eventArg.Unit};
end

function TeamMemberTest(mid, team, testFunc)
	local teamCount = GetTeamCount(mid, team);
	for i = 1, teamCount do
		local teamMember = GetTeamUnitByIndex(mid, team, i);
		local ret, condOut = testFunc(teamMember, i);
		if ret then
			return true, condOut;
		end
	end
	return false;
end
function InitializeTeamAccessedToUnit(mid, session, team, unit, range)
	local targetUnit = GetUnitFromUnitIndicator(mid, unit);
	if targetUnit == nil then	-- 유닛이 없으요!
		return nil;
	end
	local tPos = GetPosition(targetUnit);
	
	return TeamMemberTest(mid, team, function (teamMember)
		return GetDistance3D(GetPosition(teamMember), tPos) <= range, {Unit = targetUnit};
	end);
end
function CheckTeamAccessedToUnit(mid, session, eventArg, team, unit, range)
	local movedUnit = eventArg.Unit;
	if GetTeam(movedUnit) ~= team then	-- 접근 대상이 나한테 다가올 수도 있으려나? 그러면 여기서 리턴하면 안될듯
		return nil;
	end
	
	local pos = eventArg.Position;
	local targetUnit = GetUnitFromUnitIndicator(mid, unit);
	if targetUnit == nil then	-- 유닛이 없으요!
		return nil;
	end
	local tPos = GetPosition(targetUnit);
	
	-- 둘 사이의 거리를 재보자
	return GetDistance3D(pos, tPos) <= range, {Unit = targetUnit};
end

function CheckUnitEnterToVisualArea(mid, session, eventArg, team, visualArea)
	local movedUnit = eventArg.Unit;
	if GetTeam(movedUnit) ~= team then
		return nil;
	end
	local dashboard = GetMissionDashboard(GetMission(mid), visualArea);
	if dashboard == nil then
		LogAndPrint('Not Exist Dashboard - ', visualArea);
		return false;
	end
	local from = dashboard.Area.From;
	local to = dashboard.Area.To;
	
	local prevIn = PositionInArea(from, to, eventArg.BeginPosition);
	local nextIn = PositionInArea(from, to, eventArg.Position);
	return (not prevIn) and nextIn, {Team = team, Unit = movedUnit, Area = dashboard.Area};
end

function CheckUnitLeaveFromVisualArea(mid, session, eventArg, team, visualArea)
	local movedUnit = eventArg.Unit;
	if GetTeam(movedUnit) ~= team then
		return nil;
	end
	local dashboard = GetMissionDashboard(GetMission(mid), visualArea);
	if dashboard == nil then
		LogAndPrint('Not Exist Dashboard - ', visualArea);
		return false;
	end
	local from = dashboard.Area.From;
	local to = dashboard.Area.To;
	local output = {Team = team, Unit = movedUnit, Area = dashboard.Area};
	if eventArg.EventType == 'UnitMoved' then
		local prevIn = PositionInArea(from, to, eventArg.BeginPosition);
		local nextIn = PositionInArea(from, to, eventArg.Position);
		return prevIn and (not nextIn), output;
	elseif eventArg.EventType == 'UnitDead' then	-- 사망시에도 나갔다고 침
		return PositionInArea(from, to, GetPosition(eventArg.Unit)), output;
	end
end

function InitializeCompanyAllEvaluator(mid, session, successExpression)
	local mission = GetMission(mid)
	local companies = GetAllCompanyInMission(mission);
	if #companies == 0 then
		return nil; -- 회사가 하나도 없으면 에러지뭐
	end
	local success = true;
	for i, company in ipairs(companies) do
		local checkFunc = loadstring('return ' .. tostring(successExpression));
		setfenv(checkFunc, {math=math, os=os, mission=mission, company=company, company_mission=GetCompanyMissionProperty(company)});
		local ret = checkFunc();
		success = success and checkFunc();
	end
	return success;
end

function CheckCompanyAllSucceeded(mid, session, eventArg, successExpression, operation, value)
	return InitializeCompanyAllEvaluator(mid, session, successExpression);
end

function InitializeCompanyCountEvaluator(mid, session, successExpression, operation, value)
	local mission = GetMission(mid)
	local companies = GetAllCompanyInMission(mission);
	if #companies == 0 then
		return nil; -- 회사가 하나도 없으면 에러지뭐
	end
	local successCount = 0;
	for i, company in ipairs(companies) do
		local checkFunc = loadstring('return ' .. tostring(successExpression));
		setfenv(checkFunc, {math=math, os=os, mission=mission, company=company, company_mission=GetCompanyMissionProperty(company)});
		if checkFunc() then
			successCount = successCount + 1;
		end
	end

	return CompareOperation(operation, successCount, value);
end

function CheckCompanyCountSucceeded(mid, session, eventArg, successExpression, operation, value)
	return InitializeCompanyCountEvaluator(mid, session, successExpression, operation, value);
end

function CheckCompanyQuestProgressTest(mid, session, eventArg, quest)
	return InitializeCompanyQuestProgressTest(mid, session, quest);
end

function InitializeCompanyQuestProgressTest(mid, session, quest)
	local companies = GetAllCompanyInMission(mid);
	if #companies == 0 then
		return false;
	end
	
	local successCount = 0;
	for _, company in ipairs(companies) do
		local stage = GetQuestState(company, quest);
		if stage == 'InProgress' then
			successCount = successCount + 1;
		end
	end
	
	return successCount > 0, {Count = successCount};
end

function InitializeDashboardEvaluator(mid, session, dashboardKey, successExpression)
	local mission = GetMission(mid)
	local dashboard = GetMissionDashboard(mission, dashboardKey);
	if dashboard == nil then
		LogAndPrint('InitializeDashboardEvaluator', 'no dashboard', dashboardKey);
		return nil;	-- 대시보드가 없으면 에러지뭐
	end
	local checkFunc = loadstring('return ' .. tostring(successExpression));
	setfenv(checkFunc, {math=math, os=os, mission=mission, dashboard=dashboard});
	return checkFunc(), {DashboardKey = dashboardKey};
end
function CheckDashboardEvaluateSucceeded(mid, session, eventArg, dashboardKey, successExpression)
	if dashboardKey ~= eventArg.Key then
		return nil;
	end
	local mission = GetMission(mid)
	local dashboard = GetMissionDashboard(mission, eventArg.Key);
	if dashboard == nil then
		return nil;	-- 대시보드가 없으면 에러지뭐
	end
	local checkFunc = loadstring('return ' .. tostring(successExpression));
	setfenv(checkFunc, {math=math, os=os, mission=mission, dashboard=dashboard});
	return checkFunc(), {DashboardKey = dashboardKey};
end

function CheckInteractionOccured(mid, session, eventArg, unit, interaction)
	if eventArg.Target ~= GetUnitFromUnitIndicator(mid, unit, nil, true)
		or eventArg.Interaction.name ~= interaction then
		return nil;
	end
	return true, {Unit = eventArg.Unit, TargetUnit = eventArg.Target};
end
function CheckUnitAttacked(mid, session, eventArg, unit, relation)
	if eventArg.Receiver ~= GetUnitFromUnitIndicator(mid, unit) then
		return nil;
	end
	if eventArg.Damage < 0 or eventArg.DefenderState == 'Heal' then
		return nil;
	end
	
	local relationText = GetRelation(eventArg.Receiver, eventArg.Giver);
	if relation == 'Enemy' and relationText ~= 'Enemy' then
		return nil;
	elseif relation == 'Ally' and (relationText ~= 'Ally' and relationText ~= 'Team') then
		return nil;
	end
	
	return true, {Unit = eventArg.Receiver, Attacker = eventArg.Giver, Damage = eventArg.Damage, AttackerState = eventArg.AttackerState, DefenderState = eventArg.DefenderState};
end
function CheckTeamTakeDamage(mid, session, eventArg, team)
    if GetTeam(eventArg.Receiver) == team then
	    return true, {Unit = eventArg.Receiver, Attacker = eventArg.Giver, Damage = eventArg.Damage, AttackerState = eventArg.AttackerState, DefenderState = eventArg.DefenderState}; 
	end
    return nil
end
function CheckTeamTakeDamageToUnit(mid, session, eventArg, team, unit)
    if GetTeam(eventArg.Receiver) == team and eventArg.Giver == GetUnitFromUnitIndicator(mid, unit) then
	    return true, {Unit = eventArg.Receiver, Attacker = eventArg.Giver, Damage = eventArg.Damage, AttackerState = eventArg.AttackerState, DefenderState = eventArg.DefenderState}; 
	end
    return nil
end
function CheckTeamTurnEnd(mid, session, eventArg, team)
    local unit = eventArg.Unit;
	if GetTeam(unit) ~= team or unit.Obstacle then
		return nil;
	end
	return true, {Unit = eventArg.Unit};
end
function CheckTeamTurnStart(mid, session, eventArg, team)
    local unit = eventArg.Unit;
	if GetTeam(unit) ~= team or unit.Obstacle then
		return nil;
	end
	return true, {Unit = eventArg.Unit};
end
function InitializeUnitHPTest(mid, session, unit, operation, value)
	local target = GetUnitFromUnitIndicator(mid, unit);
	if target == nil then
		return false;
	end
	return CompareOperation(operation, math.floor(target.HP/target.MaxHP * 100), value), {Unit = target};
end
function CheckUnitHPTest(mid, session, eventArg, unit, operation, value)
	local target = GetUnitFromUnitIndicator(mid, unit);
	if target == nil then
		return false;
	end
	if eventArg.Receiver ~= target then 
		return nil;
	end
	return CompareOperation(operation, math.floor(target.HP/target.MaxHP * 100), value), {Unit = target};
end
function InitializeUnitCostTest(mid, session, unit, operation, value)
	local target = GetUnitFromUnitIndicator(mid, unit);
	return CompareOperation(operation, math.floor(target.Cost/target.MaxCost * 100), value), {Unit = target};
end
function CheckUnitCostTest(mid, session, eventArg, unit, operation, value)
	local target = GetUnitFromUnitIndicator(mid, unit);
	if eventArg.Unit ~= target then 
		return nil;
	end
	return CompareOperation(operation, math.floor(target.Cost/target.MaxCost * 100), value), {Unit = target};
end
function CheckUnitTurnReached(mid, session, eventArg, unit, turnCount, turnState)
	if eventArg.Unit ~= GetUnitFromUnitIndicator(mid, unit) then
		return nil;
	end
	
	if eventArg.Unit.TurnPlayed + 1 ~= turnCount then
		return false;
	end
	
	if turnState == nil then		-- 구버전 호환
		turnState = 'NotMoved';
	end
	
	if turnState == 'NotMoved' and eventArg.Unit.TurnState.Moved then
		return false;
	elseif turnState == 'AfterMove' and not eventArg.Unit.TurnState.Moved then
		return false;
	end
	
	return true, {Unit = eventArg.Unit};
end

function InitializeUnitBuffState(mid, session, unit, buffName, onOff)
	local testUnit = GetUnitFromUnitIndicator(mid, unit);
	local have = GetBuff(testUnit, buffName) ~= nil;
	
	if onOff == 'On' then
		return have, {Unit = testUnit, BuffName = buffName};
	else
		return not have, {Unit = testUnit, BuffName = buffName};
	end
end
function CheckUnitBuffState(mid, session, eventArg, unit, buffName, onOff)
	local testUnit = GetUnitFromUnitIndicator(mid, unit);
	if testUnit ~= eventArg.Unit then   return nil; end
	if eventArg.BuffName ~= buffName then   return nil; end
	
	local have = eventArg.EventType == 'BuffAdded';   -- 더해진거면 true 빠진거면 false
	
	if onOff == 'On' then
		return have, {Unit = testUnit, BuffName = buffName};
	else
		return not have, {Unit = testUnit, BuffName = buffName};
	end
end

function CheckUnitTurnEnd(mid, session, eventArg, unit)
	-- 이것만 ?첫턴에 바로 발동할텐데 이대로 괜찮은가?
	if eventArg.Unit ~= GetUnitFromUnitIndicator(mid, unit) then return nil end
	
	return true, {Unit = eventArg.Unit};
end

function CheckUnitTurnStart(mid, session, eventArg, unit)
	-- 이것만 ?첫턴에 바로 발동할텐데 이대로 괜찮은가?
	if eventArg.Unit ~= GetUnitFromUnitIndicator(mid, unit) then return nil end
	
	return true, {Unit = eventArg.Unit};
end

function InitializeStageVariableTest(mid, session, variableKey, operation, value)
	return CompareOperation(operation, GetStageVariable(mid, variableKey), value), {VariableKey = variableKey};
end

function InitializeStageVariableToStageVariableTest(mid, session, variableKey1, operation, variableKey2)
    return CompareOperation(operation, GetStageVariable(mid, variableKey1), GetStageVariable(mid, variableKey2)), {VariableKey = variableKey1};
end

function CheckStageVariableTest(mid, session, eventArg, variableKey, operation, value)
	if eventArg.Key ~= variableKey then
		return nil;
	end
	
	return CompareOperation(operation, eventArg.Value, value), {VariableKey = variableKey}
end

function CheckStageVariableToStageVariableTest(mid, session, eventArg, variableKey1, operation, variableKey2)
	if eventArg.Key ~= variableKey1 and eventArg.Key ~= variableKey2 then
		return nil;
	end
	
	return CompareOperation(operation, GetStageVariable(mid, variableKey1), GetStageVariable(mid, variableKey2)), {VariableKey = variableKey1}
end

function InitializeNearUnitCountTest(mid, session, unitIndicator, range, relation, filterExpr, operation, value)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator);
	if not unit then
		return false;
	end
	
	local relationTestFunc = ({
		All = function(o1, o2) return true end,
		Enemy = IsEnemy,
		Ally = IsAlly
	})[relation];

	if relationTestFunc == nil then
		return false;
	end
	
	local relationFilteredNearObjects = table.filter(GetNearObject(unit, range), function(obj)
		return relationTestFunc(unit, obj);
	end);
	
	local nearUnitCount = table.count(relationFilteredNearObjects, function(o)
		return EvaluateExpression(tostring(filterExpr), {self = unit, target = o});
	end);
	return CompareOperation(operation, nearUnitCount, value), {Unit = unit, Count = nearUnitCount};
end

function CheckNearUnitCountTest(mid, session, eventArg, unitIndicator, range, relation, filterExpr, operation, value)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator);
	if not unit then
		return false;
	end
	
	if eventArg.MovingForAbility then
		return nil;
	end
	
	local relationTestFunc = ({
		All = function(o1, o2) return true end,
		Enemy = IsEnemy,
		Ally = IsAlly
	})[relation];
	

	if relationTestFunc == nil then
		return false;
	end
	
	local relationFilteredNearObjects = table.filter(GetNearObject(unit, range), function(obj)
		return relationTestFunc(unit, obj);
	end);
	
	local nearUnitCount = table.count(relationFilteredNearObjects, function(o)
		return EvaluateExpression(tostring(filterExpr), {self = unit, target = o});
	end);
	return CompareOperation(operation, nearUnitCount, value), {Unit = unit, Count = nearUnitCount};
end

function CheckTeamArrivedEscapeArea(mid, session, eventArg, team)
	return GetTeam(eventArg.Unit) == team, {Unit = eventArg.Unit, EscapeArea = eventArg.Dashboard.Key};
end

function InitializeTeamAllEscaped(mid, session, team)
	local remainUnit = GetTeamCount(mid, team)
	return remainUnit <= 0 and (SafeIndex(GetStageVariable(mid, '_escape_cnt_'), team) or 0) > 0;
end
function CheckTeamAllEscaped(mid, session, eventArg, team)
	if GetTeam(eventArg.Unit) ~= team then
		return nil;
	end
	
	local remainUnit = GetTeamCount(mid, team)
	return remainUnit <= 0 and (SafeIndex(GetStageVariable(mid, '_escape_cnt_'), team) or 0) > 0;
end

function CheckFieldEffectAdded(mid, session, eventArg, fieldEffectName)
	if eventArg.FieldEffectType ~= fieldEffectName then
		return nil;
	end
	return true;
end

function InitializeUnitStateTest(mid, session, unit, testExpression)
	local obj = GetUnitFromUnitIndicator(mid, unit, nil, true)
	local env = {math = math, unit = obj};
	setmetatable(env, {__index = function(t, key)
			return GetWithoutError(obj, key);
		end}
	);
	local f = loadstring('return ' .. testExpression);
	setfenv(f, env);
	return f(), {Unit = obj};
end

function CheckUnitStateTest(mid, session, eventArg, unit, testExpression)
	local obj = GetUnitFromUnitIndicator(mid, unit, nil, true)
	if eventArg.Unit ~= obj then
		return nil;
	end
	local env = {math = math, unit = obj};
	setmetatable(env, {__index = function(t, key)
			return GetWithoutError(obj, key);
		end}
	);
	local f = loadstring('return ' .. testExpression);
	setfenv(f, env);
	return f(), {Unit = obj};
end

function InitializeUnitBattleStateTest(mid, session, unit, battleState)
	local obj = GetUnitFromUnitIndicator(mid, unit, nil, true);
	if obj == nil then
		return false;
	end
	local ret = (not obj.PreBattleState == StringToBool(battleState, true));
	return ret, {Unit = obj};
end

function CheckUnitBattleStateTest(mid, session, eventArg, unit, battleState)
	local obj = GetUnitFromUnitIndicator(mid, unit, nil, true)
	if eventArg.Unit ~= obj then
		return nil;
	end
	local ret = (not obj.PreBattleState == StringToBool(battleState, true));
	return ret, {Unit = obj};
end

function CheckStageDifficultyTest(mid, session, eventArg, value)
	local mission = GetMission(mid)
	local difficultyName = mission.DifficultyGrade;
	return difficultyName == value, {};
end

function CheckStageChallengerTest(mid, session, eventArg, value)
	local mission = GetMission(mid)
	local missionAttribute = GetMissionAttribute(mission);
	local challengerMode = false;
	if missionAttribute and missionAttribute.ChallengerMode then
		challengerMode = true;
	end
	return challengerMode, {};
end

function CheckUnitArrivedEscapeArea(mid, session, eventArg, unit)
	local obj = GetUnitFromUnitIndicator(mid, unit, nil, true);
	if eventArg.Unit ~= obj then
		return nil;
	end
	return true;
end

function CheckConditionOutputFilter(conditionOutput, filterExpression)
	if filterExpression == nil or filterExpression == '' then
		return true;
	end

	local filterEnv = table.deepcopy(conditionOutput);
	filterEnv.math = math;
	filterEnv.os = os;
	filterEnv.IsUnitInSightToTeam = IsUnitInSightToTeam;
	setmetatable(filterEnv, {__index = _G});

	local checkFunc = loadstring('return ' .. tostring(filterExpression));
	if checkFunc == nil then
		LogAndPrint('[DataError] CheckConditionOutputFilter - error filterExpression: '..filterExpression);
		return true;
	end
	setfenv(checkFunc, filterEnv);
	return checkFunc();
end

function InitializeUnitArrivedEscapeArea(mid, session, unit)
	-- 애매하네..
	return false;
end

function InitializeActionDelimiter(mid, session)
	return false;
end

function CheckBeastTamed(mid, session, eventArg, tamer, beastKey)
	local tamerO = GetUnitFromUnitIndicator(mid, tamer);
	return eventArg.Tamer == tamerO and eventArg.OriginalKey == beastKey, {Tamer = eventArg.Tamer, Beast = eventArg.Beast};
end
function CheckBeastTamedAny(mid, session, eventArg, beastKey)
	return eventArg.OriginalKey == beastKey, {Tamer = eventArg.Tamer, Beast = eventArg.Beast};
end

function Action_MissionDirect(mid, ds, conditionOutput, directType, beginHide, endShow)
	PlayMissionDirect(mid, ds, conditionOutput, directType, beginHide, endShow);
end

function Action_MissionDirectInstance(mid, ds, conditionOutput, missionDirectScript, beginHide, endShow)
	-- 그냥 미션 다이렉트 재생
	PlayMissionDirect_Internal(mid, ds, conditionOutput, SafeIndex(missionDirectScript, 1), 'MissionDirectInstance', beginHide, endShow);
end

function Action_Win(mid, ds, conditionOutput, team)
	return Result_EndMission(team);
end

function Action_Lose(mid, ds, conditionOutput)
	return Result_EndMission("enemy")
end

function Action_ProgressQuest(mid, ds, conditionOutput, quest, value)
	local mission = GetMission(mid);
	local dc = GetMissionDatabaseCommiter(mission);
	local questCls = GetClassList('Quest')[quest];
	if questCls == nil then
		return;
	end
	for _, company in ipairs(GetAllCompanyInMission(mid)) do
		local questInfo = GetMissionMemberQuestInfo(company, quest);
		if questInfo and questInfo.Stage == 'InProgress' then
			local nextCount = math.min(questCls.Type.MaxCountGetter(questCls), questInfo.Progress.TargetCount + tonumber(value));
			dc:UpdateQuestProperty(company, quest, 'TargetCount', nextCount);
			questInfo.Progress.TargetCount = nextCount;	-- 디비 적용이 바로 안되기 때문에 여기서 메모리상으로 올려준다.
		end
	end
	ds:UpdateQuestProgress(quest);
end

function Action_ReplaceMonster(mid, ds, conditionOutput, unit, monType)
	local u = GetUnitFromUnitIndicator(mid, unit, conditionOutput);
	return ReplaceMonster(ds, u, monType, true);
end

-- 미션 연출 함수
function Action_DirectingScript(mid, ds, conditionOutput, script)
	_G[script](mid, ds);
end

function DirectingScriptActionTest(mid, ds)
	ds:Dialog("DialogSystemMessageBox",{Title = 'Test', Message = 'Hello', Image = ''});
end

function Action_UpdateDashboard(mid, ds, conditionOutput, dashboardKey, commands)
	local mission = GetMission(mid);
	local commandList = {};
	for i, cmd in ipairs(commands) do
		table.insert(commandList, cmd.Value);
	end
	return UpdateDashboardCore(mission, dashboardKey, unpack(commandList));
end
function Action_UpdateDashboard2(mid, ds, conditionOutput, dashboardIndicator, commands)
	local dashboard = GetDashboardFromDashboardIndicator(mid, dashboardIndicator, conditionOutput);
	local commandList = {};
	for i, cmd in ipairs(commands) do
		table.insert(commandList, cmd.Value);
	end
	return UpdateDashboardCore(mid, SafeIndex(dashboard, 'Key'), unpack(commandList));
end

function Action_UpdateSteamAchievement(mid, ds, conditionOutput, achievement, onOff)
	if not achievement or achievement == '' or achievement == 'None' then
		return;
	end
	if onOff == 'On' then
		ds:UpdateSteamAchievement(achievement, true);
	elseif onOff == 'Off' then
		ds:UpdateSteamAchievement(achievement, false);
	end
end

function Action_UpdateSteamStat(mid, ds, conditionOutput, stat, value)
	if not stat or stat == '' or stat == 'None' then
		return;
	end
	ds:UpdateSteamStat(stat, value);
end

function Action_AddSteamStat(mid, ds, conditionOutput, stat, value)
	if not stat or stat == '' or stat == 'None' then
		return;
	end
	ds:AddSteamStat(stat, value);
end

function Action_UpdateCompanyProperty(mid, ds, conditionOutput, propKV)
	local mission = GetMission(mid);
	local dc = GetMissionDatabaseCommiter(mission);
	local companies = GetAllCompanyInMission(mission);
	local keyList = string.split(propKV[1].Key, '/');
	table.insert(keyList, propKV[1].Value);
	for i, company in ipairs(companies) do
		dc:UpdateCompanyProperty(company, propKV[1].Key, propKV[1].Value);
		SafeNewIndex(company, unpack(keyList));			-- DB저장은 따로 되는거고 일단 여기서 갱신
	end
end

function Action_UpdateCompanyMissionProperty(mid, ds, conditionOutput, propKV)
	local mission = GetMission(mid);
	local dc = GetMissionDatabaseCommiter(mission);
	local companies = GetAllCompanyInMission(mission);
	local keyList = string.split(propKV[1].Key, '/');
	table.insert(keyList, propKV[1].Value);
	for i, company in ipairs(companies) do
		local companyMissionProp = GetCompanyMissionProperty(company);
		dc:UpdateCompanyMissionProperty(companyMissionProp, mission.name, propKV[1].Key, propKV[1].Value);
		SafeNewIndex(companyMissionProp, unpack(keyList));			-- DB저장은 따로 되는거고 일단 여기서 갱신
	end
end

function Action_AddCompanyProperty(mid, ds, conditionOutput, propKV)
	local mission = GetMission(mid);
	local dc = GetMissionDatabaseCommiter(mission);
	local companies = GetAllCompanyInMission(mission);
	for i, company in ipairs(companies) do
		dc:AddCompanyProperty(company, propKV[1].Key, propKV[1].Value);
		local keyList = string.split(propKV[1].Key, '/');
		local prevVal = SafeIndex(company, unpack(keyList));
		table.insert(keyList, prevVal + tonumber(propKV[1].Value));
		SafeNewIndex(company, unpack(keyList));
	end
end

function Action_AddCompanyMissionProperty(mid, ds, conditionOutput, propKV)
	local mission = GetMission(mid);
	local dc = GetMissionDatabaseCommiter(mission);
	local companies = GetAllCompanyInMission(mission);
	for i, company in ipairs(companies) do
		local cmp = GetCompanyMissionProperty(company);
		dc:AddCompanyMissionProperty(cmp, propKV[1].Key, propKV[1].Value);
		local keyList = string.split(propKV[1].Key, '/');
		local prevVal = SafeIndex(cmp, unpack(keyList));
		table.insert(keyList, prevVal + tonumber(propKV[1].Value));
		SafeNewIndex(cmp, unpack(keyList));
	end	
end

function Action_RemoveBuff(mid, ds, conditionOutput, Unit, buffName, noEvent)
	local unit = GetUnitFromUnitIndicator(mid, Unit, conditionOutput);
	if unit == nil then
		return;
	end
	local removeBuff = Result_RemoveBuff(unit, buffName);
	if noEvent == 'On' then
		removeBuff.noevent = true;
	end
	return removeBuff;
end

function Action_RemoveBuffAll(mid, ds, conditionOutput, Unit, noEvent)
	local actions = {};
	local unit = GetUnitFromUnitIndicator(mid, Unit, conditionOutput);
	if unit == nil then
		return;
	end
	local buffList = GetBuffList(unit);
	for _, buff in ipairs(buffList) do
		if buff.RemoveWhenDead and buff.SubType ~= 'Aura' then
			local removeBuff = Result_RemoveBuff(unit, buff.name);
			if noEvent == 'On' then
				removeBuff.noevent = true;
			end
			table.insert(actions, removeBuff);
		end
	end
	return unpack(actions);
end

function Action_UnitAddBuff(mid, ds, conditionOutput, Unit, buffName, buffLv)
	local unit = GetUnitFromUnitIndicator(mid, Unit, conditionOutput);
	if unit == nil then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, unit, unit, buffName, buffLv, true);
	return unpack(actions);
end

function Action_SightTeamAddBuff(mid, ds, conditionOutput, Unit, team, buffName, buffLv)
	local unit = GetUnitFromUnitIndicator(mid, Unit, conditionOutput);
	if unit == nil then
		return;
	end
	local unitPos = GetPosition(unit);
	local targets = {};
	local targetTeamCount = GetTeamCount(mid, team);
	for i = 1, targetTeamCount do
		table.insert(targets, GetTeamUnitByIndex(mid, team, i));
	end
	local actions = {};
	for _, target in ipairs(targets) do
		if IsInSight(target, unitPos, true) then
			InsertBuffActions(actions, target, target, buffName, buffLv, true);
		end
	end
	return unpack(actions);
end

function Action_TeamAddBuff(mid, ds, conditionOutput, team, buffName, buffLv, onFieldOnly, giver)
	local remainUnit = GetTeamCount(mid, team, StringToBool(onFieldOnly));
	local actions = {};
	if remainUnit == 0 or remainUnit == nil then
		return false
	end
	local giverUnit = GetUnitFromUnitIndicator(mid, giver, conditionOutput, true);
	for index = 1, remainUnit do
		local u = GetTeamUnitByIndex(mid, team, index, StringToBool(onFieldOnly));
		InsertBuffActions(actions, giverUnit or u, u, buffName, buffLv, true);
	end
	return unpack(actions);
end
function Action_TeamRemoveBuff(mid, ds, conditionOutput, team, buffName, noEvent)
	local remainUnit = GetTeamCount(mid, team);
	local actions = {};
	if remainUnit == 0 or remainUnit == nil then
		return false
	end
	for index = 1, remainUnit do
		local u = GetTeamUnitByIndex(mid, team, index);
		local removeBuff = Result_RemoveBuff(u, buffName);
		if noEvent == 'On' then
			removeBuff.noevent = true;
		end
        table.insert(actions, removeBuff);
	end	
	return unpack(actions);
end

function Action_TeamRemoveBuffAll(mid, ds, conditionOutput, team, noEvent)
	local remainUnit = GetTeamCount(mid, team);
	local actions = {};
	if remainUnit == 0 or remainUnit == nil then
		return false
	end
	for index = 1, remainUnit do
		local u = GetTeamUnitByIndex(mid, team, index);
		local buffList = GetBuffList(u);
		for _, buff in ipairs(buffList) do
			if buff.RemoveWhenDead then
				local removeBuff = Result_RemoveBuff(u, buff.name);
				if noEvent == 'On' then
					removeBuff.noevent = true;
				end
				table.insert(actions, removeBuff);
			end
		end
	end	
	return unpack(actions);
end

function Action_TeamChangeTeam(mid, ds, conditionOutput, team, team2, changeTeamDirect)
	local remainUnit = GetTeamCount(mid, team, nil, nil, true);
	if remainUnit == 0 or remainUnit == nil then
		return;
	end
	local actions = {};
	for index = 1, remainUnit do
		local obj = GetTeamUnitByIndex(mid, team, index, nil, nil, true);
		local original = GetOriginalTeam(obj);
		Action_ChangeTeamCommon(actions, ds, obj, team2, changeTeamDirect, team ~= original);
	end	
	
	local originalUnit = GetTeamCount(mid, team, nil, true, true);
	for index = 1, remainUnit do
		local obj = GetTeamUnitByIndex(mid, team, index, nil, true, true);
		local original = GetOriginalTeam(obj);
		if team ~= original then
			table.insert(actions, Result_UpdateInstantProperty(obj, 'OriginalTeam', team));
		end
	end
	return unpack(actions);
end

function Action_TeamUpdateUserMember(mid, ds, conditionOutput, team, team2, onOff)
	local remainUnit = GetTeamCount(mid, team);
	if remainUnit == 0 or remainUnit == nil then
		return;
	end
	local actions = {};
	for index = 1, remainUnit do
		local obj = GetTeamUnitByIndex(mid, team, index);
		table.insert(actions, Result_UpdateUserMember(obj, team2, onOff == 'On'));
	end
	return unpack(actions);
end

function Action_UpdateStageVariable(mid, ds, conditionOutput, variable, value)
	return Result_UpdateStageVariable(variable, value);
end
function Action_UpdateStageVariableEx(mid, ds, conditionOutput, variable, dataBinding)
	return Result_UpdateStageVariable(variable, StageDataBinder(GetMission(mid), dataBinding[1], conditionOutput));
end
function Action_RandomUpdateStageVariable(mid, ds, conditionOutput, variable, value, value2)
	local rand = math.random(value, value2)
	return Result_UpdateStageVariable(variable, rand);
end

function Action_CustomFunction(mid, ds, conditionOutput, value, value2)
    local func = _G[value]
    if func ~= nil then
        return func(mid, ds, conditionOutput, value, value2)
    end
end

function Action_AddStageVariable(mid, ds, conditionOutput, variable, value)
	local currentValue = GetStageVariable( GetMission(mid), variable);
	currentValue = currentValue + value;
	return Result_UpdateStageVariable(variable, currentValue, 'Add');
end
function Action_TurnEnd(mid, ds, conditionOutput, unit)
	return Result_TurnEnd(GetUnitFromUnitIndicator(mid, unit, conditionOutput));
end

function Action_UpdateObjectProperty(mid, ds, conditionOutput, unitIndicator, propKV)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end
	return Result_PropertyUpdated(propKV[1].Key, propKV[1].Value, unit, true);
end
function Action_UpdateObjectPropertyEx(mid, ds, conditionOutput, unitIndicator, key, stageDataBinding)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end
	local updateValue = StageDataBinder(GetMission(mid), stageDataBinding[1], conditionOutput);
	return Result_PropertyUpdated(key, updateValue, unit, true);
end

function Action_AddObjectProperty(mid, ds, conditionOutput, unitIndicator, propKV)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end
	local keyList = string.split(propKV[1].Key, '/');
	local prevVal = SafeIndex(unit, unpack(keyList));
	if prevVal == nil or type(prevVal) ~= 'number' then
		return;
	end	
	return Result_PropertyUpdated(propKV[1].Key, prevVal + tonumber(propKV[1].Value), unit, true);
end

function Action_UpdateObjectInstantProperty(mid, ds, conditionOutput, unitIndicator, propKV)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end
	
	SetInstantProperty(unit, propKV[1].Key, propKV[1].Value);
end

local g_objectStatePropMap = {
	Untargetable = 'Base_Untargetable';
};

function Action_UpdateObjectState(mid, ds, conditionOutput, unit, ...)
	local obj = GetUnitFromUnitIndicator(mid, unit, conditionOutput);
	if obj == nil then
		return;
	end
	local actions = {};
	
	local actionCls = GetClassList('Action')['UpdateObjectState'];
	for i = 2, #actionCls.ArgumentList do
		local argCls = actionCls.ArgumentList[i];
		local propName = g_objectStatePropMap[argCls.name] or argCls.name;
		local propValue = arg[i - 1];
		
		if propValue == 'On' then
			table.insert(actions, Result_PropertyUpdated(propName, true, obj));
		elseif propValue == 'Off' then
			table.insert(actions, Result_PropertyUpdated(propName, false, obj));
		end
	end

	return unpack(actions);
end

function Action_UnitSetPos(mid, ds, conditionOutput, unit, position)
	local retAction = Result_SetPosition(GetUnitFromUnitIndicator(mid, unit, conditionOutput), position[1]);
	retAction.forward = true;
	return retAction;
end

function Action_ChangeTileEnterable(mid, ds, conditionOutput, area, onOff)
	return Result_ChangeTileEnterable(area[1].From[1], area[1].To[1], onOff == 'On');
end

function Action_ChangeTileEnterableEx(mid, ds, conditionOutput, areaIndicator, onOff)
	local list = GetPositionListFromAreaIndicator(mid, areaIndicator, conditionOutput);
	return Result_ChangeTileEnterableList(list, onOff == 'On');
end

function Action_ChangeTileLink(mid, ds, conditionOutput, area, updateLink, updateVisible, updateThrowing)
	local link, visible, throwing;
	if updateLink ~= 'Cancel' then
		link = updateLink == 'On';
	end
	if updateVisible ~= 'Cancel' then
		visible = updateVisible == 'On';
	end
	if updateThrowing ~= 'Cancel' then
		throwing = updateThrowing == 'On';
	end
	return Result_ChangeTileLink(area[1].From[1], area[1].To[1], link, visible, throwing);
end

function Action_ChangeTileLinkEx(mid, ds, conditionOutput, areaIndicator, updateLink, updateVisible, updateThrowing)
	local list = GetPositionListFromAreaIndicator(mid, areaIndicator, conditionOutput);
	local link, visible, throwing;
	if updateLink ~= 'Cancel' then
		link = updateLink == 'On';
	end
	if updateVisible ~= 'Cancel' then
		visible = updateVisible == 'On';
	end
	if updateThrowing ~= 'Cancel' then
		throwing = updateThrowing == 'On';
	end
	return Result_ChangeTileLinkList(list, link, visible, throwing);
end

function Action_ChangeAI(mid, ds, conditionOutput, unit, aiForm)
	local aiArg = table.deepcopy(aiForm[1]);
	local aiType =  aiArg.AIType;
	aiArg.AIType = nil;
	SetMonsterAIInfo(GetUnitFromUnitIndicator(mid, unit, conditionOutput), aiType, aiArg);
end

function Action_ChangeAITeam(mid, ds, conditionOutput, team, aiForm)
	local aiArg = table.deepcopy(aiForm[1]);
	local aiType =  aiArg.AIType;
	aiArg.AIType = nil;
	
	local teamCount = GetTeamCount(mid, team);
	for i = 1, teamCount do
		local obj = GetTeamUnitByIndex(mid, team, i);
		SetMonsterAIInfo(obj, aiType, aiArg);
	end
end

function Action_SightSharing(mid, ds, conditionOutput, unit, team, visible)
	return Result_SightSharing(GetUnitFromUnitIndicator(mid, unit, conditionOutput), team, visible);
end

function Action_DisableInteraction(mid, ds, conditionOutput, interactionUnit, interactionType)
	return Result_UpdateInteraction(GetUnit(mid, interactionUnit), interactionType, false);
end
function Action_KillObject(mid, ds, conditionOutput, unit, noEvent)
	local u = GetUnitFromUnitIndicator(mid, unit, conditionOutput);
	if u == nil then
		return;
	end
	local invokeEvent = true;
	if noEvent == 'On' then
		invokeEvent = false;
	end	
	ds:SetDead(GetObjKey(u), 'Normal', 0, 0, 0, 0, 0, true);
	ds:WorldAction(Result_Damage(99999999, 'Normal', 'Hit', u, u, nil, nil, nil, true), invokeEvent);
end
function Action_KillObjectAll(mid, ds, conditionOutput, team)
	local remainUnit = GetTeamCount(mid, team);
	for index = 1, remainUnit do
		local u = GetTeamUnitByIndex(mid, team, index);
		ds:SetDead(GetObjKey(u), 'Normal', 0, 0, 0, 0, 0, true);
		ds:WorldAction(Result_Damage(99999999, 'Normal', 'Hit', u, u, nil, nil, nil, true), false);
	end
end
function GetHideObjectAction(ds, unit)
	if IsDead(unit) then
		return;
	end
	local curPos = GetPosition(unit);
	if IsInvalidPosition(curPos) then
		return;
	end
	SetInstantProperty(unit, 'OriginalPos', curPos);
	local invalidPos = InvalidPosition();
	local moveId = ds:Move(GetObjKey(unit), invalidPos, true, true, '', 0, 0, false, 1, true, nil, nil, true);
	local moveAction = Result_SetPosition(unit, invalidPos);
	moveAction._ref = moveId;
	moveAction._ref_offset = 0;
	ds:WorldAction(moveAction, true);
end
function ShowObjectAction(ds, unit, invokeEvent, movePos)
	if IsDead(unit) then
		return false;
	end
	local curPos = GetPosition(unit);
	if not IsInvalidPosition(curPos) then
		return false;
	end
	-- 이미 점유중이면 근처에 빈 곳을 찾자 (근처에서 못 찾으면 그냥 겹쳐도 원래 위치로...)
	local newPos = movePos;
	local mission = GetMission(unit);
	local alreadyObj = GetObjectByPosition(mission, movePos);
	if alreadyObj then
		local range = CalculateRange(unit, 'Sphere2_ExSelf', movePos);
		local candidate = table.filter(range, function(pos)
			local obj = GetObjectByPosition(mission, pos);
			return obj == nil;
		end);
		if #candidate > 0 then
			candidate = table.shuffle(candidate);
			table.sort(candidate, function(lhs, rhs)
				return GetDistance3D(lhs, movePos) < GetDistance3D(rhs, movePos);
			end);
			newPos = candidate[1];
		end
	end
	local moveId = ds:Move(GetObjKey(unit), newPos, true, true, '', 0, 0, false, 1, true, nil, nil, true);
	local moveAction = Result_SetPosition(unit, newPos);
	moveAction._ref = moveId;
	moveAction._ref_offset = 0;
	moveAction.blink = true;
	ds:WorldAction(moveAction, invokeEvent);
	return true;
end
function GetShowObjectAction(ds, unit, invokeEvent)
	local movePos = GetInstantProperty(unit, 'OriginalPos');
	if not movePos then
		return;
	end
	if ShowObjectAction(ds, unit, invokeEvent, movePos) then
		SetInstantProperty(unit, 'OriginalPos', nil);
	end
end
function Action_HideObject(mid, ds, conditionOutput, unit)
	local unit = GetUnitFromUnitIndicator(mid, unit, conditionOutput);
	if unit == nil then
		return;
	end
	GetHideObjectAction(ds, unit);
end
function Action_HideObjectTeam(mid, ds, conditionOutput, team)
	local units = {};
	for index = 1, GetTeamCount(mid, team) do
		table.insert(units, GetTeamUnitByIndex(mid, team, index));
	end
	for _, unit in ipairs(units) do
		GetHideObjectAction(ds, unit);
	end
end
function Action_ShowObject(mid, ds, conditionOutput, unit, noEvent)
	local unit = GetUnitFromUnitIndicator(mid, unit, conditionOutput);
	if unit == nil then
		return;
	end
	local invokeEvent = true;
	if noEvent == 'On' then
		invokeEvent = false;
	end
	GetShowObjectAction(ds, unit, invokeEvent);
end
function Action_ShowObjectTeam(mid, ds, conditionOutput, team, noEvent)
	local units = {};
	for index = 1, GetTeamCount(mid, team) do
		table.insert(units, GetTeamUnitByIndex(mid, team, index));
	end
	local invokeEvent = true;
	if noEvent == 'On' then
		invokeEvent = false;
	end
	for _, unit in ipairs(units) do
		GetShowObjectAction(ds, unit, invokeEvent);
	end
end
function Action_UnitMove(mid, ds, conditionOutput, unit, pos)
	local unit = GetUnitKeyFromUnitIndicator(mid, unit, conditionOutput);
	local moveId = ds:Move(unit, pos, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, true);
	local moveAction = Result_Move(invalidPos, unit);
	moveAction._ref = moveId;
	moveAction._ref_offset = 0;
	return moveAction;
end
function Action_Escape(mid, ds, conditionOutput, unitIndicator, dashboardIndicator)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end
	local dashboard = GetDashboardFromDashboardIndicator(mid, dashboardIndicator, conditionOutput);
	
	local exitPosO = dashboard.ExitPos;
	local exitPos = {x = exitPosO.x, y = exitPosO.y, z = exitPosO.z};
	if IsInvalidPosition(exitPos) then
		exitPos = FindAIMovePosition(unit, {FindMoveAbility(unit)}, function (self, adb)
			return adb.MoveDistance;	-- 가장 멀리 갈 수 있는 아무데나
		end, {}, {});
	end
	local moveTo = GetMovePosition(unit, exitPos, 0);
	local moveID = ds:Move(GetObjKey(unit), moveTo, false, false);
	local moveAction = Result_Move(moveTo, unit);
	moveAction._ref = moveID;
	moveAction._ref_offset = 0;
	ds:WorldAction(moveAction);
	ds:Connect(ds:UpdateBattleEvent(GetObjKey(unit), 'GetWord', { Color = 'KellyGreen', Word = 'Escape' }), moveID, 0);
	
	local escapeCount = GetStageVariable(GetMission(mid), '_escape_cnt_');
	if escapeCount == nil then
		escapeCount = {};
	end
	local prev = escapeCount[GetTeam(unit)] or 0;
	escapeCount[GetTeam(unit)] = prev + 1;
	return Result_UpdateStageVariable('_escape_cnt_', escapeCount), Result_DestroyObject(unit, false, true), Result_FireWorldEvent('UnitEscaped', {Unit=unit});
end

function Action_ExcludeUnit(mid, ds, conditionOutput, unitIndicator)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end
	local setPos = Result_SetPosition(unit, InvalidPosition());
	setPos.sequential = true;
	setPos.forward = true;
	return setPos, Result_FireWorldEvent('UnitBeingExcluded', {Unit = unit, AllowInvalidPosition = true}), Result_DestroyObject(unit, false, false);
end

function Action_UpdateTemporaryMastery(mid, ds, conditionOutput, unitIndicator, mastery, level)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end
	LogAndPrint(unit, mastery, level);
	return Result_UpdateMastery(unit, mastery, level);
end

function Aciton_ToggleTrigger(mid, ds, conditionOutput, triggerName, onOff)
	return Result_ToggleTrigger(triggerName, onOff == 'On', false);
end

function Action_ToggleTriggerGroup(mid, ds, conditionOutput, triggerGroup, onOff)
	return Result_ToggleTrigger(triggerGroup, onOff == 'On', true);
end

function Action_ToggleInteractionArea(mid, ds, conditionOutput, interactionAreaKey, offOn)
	local stageTable = GetStageTable(mid);
	local interactionAreas = stageTable.MapComponents[1].InteractionArea;
	
	for i, ia in ipairs(interactionAreas) do
		local key = ia.SubKey;
		if key == interactionAreaKey then
			local from = ia.Area[1].From[1];
			local to = ia.Area[1].To[1];
			local interactionType = ia.InteractionArea;
			local assetKey = ia.NamedAssetKey;
			LogAndPrint('Action_ToggleInteractionArea', interactionAreaKey, offOn);
			if offOn == 'On' then
				return Result_EnableInteractionArea(key, from, to, interactionType, assetKey);
			else
				return Result_DisableInteractionArea(key);
			end
		end
	end
end

function Action_TimeElapse(mid, ds, conditionOutput, stageDataBinding)
	local timeAmount = tonumber(StageDataBinder(GetMission(mid), stageDataBinding[1], conditionOutput));
	return Result_TimeElapsed(timeAmount);
end

function Action_TeamDistribute(mid, ds, conditionOutput, team, areaIndicator, shuffle)
	local posList = GetPositionListFromAreaIndicator(mid, areaIndicator, conditionOutput);
	if shuffle then
		posList = table.shuffle(posList);
	end
	local teamCount = GetTeamCount(mid, team);
	for i = 1, teamCount do
		if #posList == 0 then
			return;
		end
		local teamMember = GetTeamUnitByIndex(mid, team, i);
		ShowObjectAction(ds, teamMember, true, table.remove(posList));
	end
end

function Action_ResetAbilityCooldown(mid, ds, conditionOutput, unitIndicator, abilityName)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end

	local actions = {};
	local abilityList = GetAllAbility(unit, false, true);
	for _, ability in ipairs(abilityList) do
		if ability.name == abilityName then
			UpdateAbilityPropertyActions(actions, unit, ability.name, 'Cool', 0);
			ability.PriorityDecay = 0;
			break;
		end
	end	
	return unpack(actions);
end

function Action_ResetAbilityCooldownAll(mid, ds, conditionOutput, unitIndicator)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end

	local actions = {};
	local abilityList = GetAllAbility(unit, false, true);
	for _, ability in ipairs(abilityList) do
		UpdateAbilityPropertyActions(actions, unit, ability.name, 'Cool', 0);
		ability.PriorityDecay = 0;
	end	
	return unpack(actions);
end

function Action_ResetAbilityUseCount(mid, ds, conditionOutput, unitIndicator, abilityName)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);

	if unit == nil then
		return;
	end
	local actions = {};
	
	local abilityList = GetAllAbility(unit);
	for _, ability in ipairs(abilityList) do
		if ability.name == abilityName and ability.IsUseCount then
			local newUseCount = ability.MaxUseCount;
			UpdateAbilityPropertyActions(actions, unit, ability.name, 'UseCount', newUseCount);
			break;
		end
	end	

	return unpack(actions);
end

function Action_ResetAbilityUseCountAll(mid, ds, conditionOutput, unitIndicator)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end

	local actions = {};
	
	local abilityList = GetAllAbility(unit);
	for _, ability in ipairs(abilityList) do
		if ability.IsUseCount then
			local newUseCount = ability.MaxUseCount;
			UpdateAbilityPropertyActions(actions, unit, ability.name, 'UseCount', newUseCount);
		end
	end	

	return unpack(actions);
end
function Action_ResetSP(mid, ds, conditionOutput, unitIndicator)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end

	local actions = {};
	AddSPPropertyActions(actions, unit, unit.ESP.name, -1 * unit.SP, true, ds, false, true);

	return unpack(actions);
end

function Action_RestoreMaxCost(mid, ds, conditionOutput, unitIndicator)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end

	local actions = {};
	local _, reasons = AddActionCost(actions, unit, unit.MaxCost);
	-- 액션으로 추가된 기력에 대해서도 메시지가 나오나?.. 일단 무시

	return unpack(actions);
end

function Action_RestoreMaxHP(mid, ds, conditionOutput, unitIndicator)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end

	return Result_PropertyUpdated('LowestHP', unit.MaxHP, unit, false), Result_PropertyUpdated('HP', unit.MaxHP, unit, true);
end

function Action_RestoreMaxSP(mid, ds, conditionOutput, unitIndicator)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end

	local actions = {};
	AddSPPropertyActions(actions, unit, unit.ESP.name, unit.MaxSP - unit.SP, true, ds, false, true);

	return unpack(actions);
end

function Action_UpdateUserMember(mid, ds, conditionOutput, unitIndicator, team, onOff)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput, true);
	if unit == nil then
		return;
	end
	return Result_UpdateUserMember(unit, team, onOff == 'On');
end

function Action_UpdateAutoPlayable(mid, ds, conditionOutput, unitIndicator, onOff)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end
	return Result_UpdateInstantProperty(unit, 'AutoPlayable', onOff == 'On'), Result_UpdateInstantProperty(unit, 'DisableRetreat', onOff == 'Off');
end

function Action_ChangeTeamCommon(actions, ds, obj, team, changeTeamDirect, temporary)
	table.insert(actions, Result_ChangeTeam(obj, team, temporary));
	if team == 'player' then
		if not changeTeamDirect or changeTeamDirect == 'Main' then
			local objKey = GetObjKey(obj);
			local interactionID = ds:UpdateInteractionMessage(objKey, 'MemberJoin', obj.Info.name);
			local sleepID = ds:Sleep(3);
			local playSoundID = ds:PlaySound('Success.wav', 'Layout', 1);
			ds:Connect(playSoundID, interactionID, 0.5);
			ds:Connect(sleepID, interactionID, 0);
		elseif changeTeamDirect == 'Sub' then
			ds:ShowFrontmessageWithText(FormatMessageText(GuideMessageText('ChangeTeamPlayer'), {MonName = ClassDataText('ObjectInfo', obj.Info.name, 'Title')}), 'Corn');
		end
		
		Action_GiveInteractionAbilityCommon(actions, obj);
	end
end

function Action_ChangeTeam(mid, ds, conditionOutput, unitIndicator, team, changeTeamDirect, includeDead)
	local obj = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput, includeDead);
	if obj == nil then
		return;
	end
	
	local actions = {};
	Action_ChangeTeamCommon(actions, ds, obj, team, changeTeamDirect);	
	return unpack(actions);
end

function Action_GiveAbility(mid, ds, conditionOutput, unitIndicator, abilityName)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end

	local abilityList = GetAllAbility(unit);
	for _, ability in ipairs(abilityList) do
		if ability.name == abilityName then
			return;
		end
	end	
	
	return Result_GiveAbility(unit, abilityName);
end

function Action_GiveInteractionAbilityCommon(actions, unit)
	local abilityList = GetAllAbility(unit);
	
	for _, idspace in ipairs({'Interaction', 'InteractionArea'}) do
		for __, interactionCls in pairs(GetClassList(idspace)) do
			if interactionCls.AutoAbility then
				local hasAlready = false;
				for _, ability in ipairs(abilityList) do
					if ability.name == interactionCls.Ability.name then
						hasAlready = true;
						break;
					end
				end
				if not hasAlready then
					table.insert(actions, Result_GiveAbility(unit, interactionCls.Ability.name));
				end
			end
		end
	end
end

function Action_GiveInteractionAbility(mid, ds, conditionOutput, unitIndicator)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end

	local actions = {};
	Action_GiveInteractionAbilityCommon(unit);
	return unpack(actions);
end

function Action_UpdateFieldEffect(mid, ds, conditionOutput, fieldEffectType, area, onOff)
	local mission = GetMission(mid);
	local area = GetPositionListInArea(area[1].From[1], area[1].To[1]);
	local positionList = {};
	for _, pos in ipairs(area) do
		local validPos = GetValidPosition(mission, pos, false);
		if validPos then
			table.insert(positionList, validPos);
		end
	end
	
	if onOff == 'On' then
		return Result_AddFieldEffect(fieldEffectType, positionList);
	else
		return Result_RemoveFieldEffect(fieldEffectType, positionList);
	end
end

function Action_ClearFieldEffect(mid, ds, conditionOutput, fieldEffectType)
	return Result_ClearFieldEffect(fieldEffectType);
end

function Action_ClearFieldEffectAll(mid, ds, conditionOutput)
	local actions = {};
	local fieldEffectClsList = GetClassList('FieldEffect');
	for _, fieldEffectCls in pairs(fieldEffectClsList) do
		if not fieldEffectCls.Static then
			table.insert(actions, Result_ClearFieldEffect(fieldEffectCls.name));
		end
	end
	return unpack(actions);
end

function Action_CheckPoint(mid, ds, conditionOutput, actionInstance)
	local connectorAction = SafeIndex(actionInstance, 1);
	if SafeIndex(connectorAction, 'ActionType') == nil or SafeIndex(connectorAction, 'ActionType') == 'None' then
		connectorAction = nil;
	else
		connectorAction.Type = connectorAction.ActionType;
		ds:RunScript('ActivateCheckPoint', {}, true);	-- 액션 커넥터를 쓰는 경우 따로 UI표기를 해줘야한다.
	end
	ReserveMissionCheckPoint(mid, connectorAction);
	return Result_FireWorldEvent('CheckPointUpdated', {}, nil, true);
end

function Action_AcquireMastery(mid, ds, conditionOutput, team, mastery, count)
	local mission = GetMission(mid);
	local dc = GetMissionDatabaseCommiter(mission);
	local company = GetCompanyByTeam(mission, team);
	if not company then
		return;
	end
	local acquireCount = tonumber(count);
	if acquireCount <= 0 then
		return;
	end
	local unlockTechnique = dc:AcquireMastery(company, mastery, acquireCount);
	if unlockTechnique then
		company.Technique[pickedMastery.name].Opened = true;	-- 미션 임시 조치
		ds:AddMissionChat('UnlockTechnique', 'UnlockTechnique', {ObjectKey = objKey, TechniqueType = acquiredMastery.name});
	end
	ds:ShowAcquireMasteryDirecting(team, mastery, acquireCount, 'MasteryAcquiredGuideNormal', nil);
end

function Action_UpdatePatrolInfo(mid, ds, conditionOutput, unitIndicator, patrolRoute, patrolMethod, patrolRepeat)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end
	SetInstantProperty(unit, 'PatrolRoute', patrolRoute);
	SetInstantProperty(unit, 'PatrolMethod', patrolMethod);
	SetInstantProperty(unit, 'PatrolRepeat', patrolRepeat);
end

function Action_ToggleAITimeLimit(mid, ds, conditionOutput, unitIndicator, offOn)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if not unit then
		return;
	end
	SetInstantProperty(unit, 'NoAITimeLimit', offOn == 'Off');
end
function Action_ToggleTeamAITimeLimit(mid, ds, conditionOutput, team, offOn)
	local teamCount = GetTeamCount(mid, team);
	for i = 1, teamCount do
		local teamMember = GetTeamUnitByIndex(mid, team, i);
		SetInstantProperty(teamMember, 'NoAITimeLimit', offOn == 'Off');
	end
end
function Action_MonsterLocator(mid, ds, conditionOutput, locatorCandidate)
	local picker = RandomPicker.new();
	for _, candidate in ipairs(SafeIndex(locatorCandidate, 1, 'Candidate') or {}) do
		picker:addChoice(candidate.Priority, SafeIndex(candidate.UnitWithPosList, 1, 'Entry'));
	end
	
	local selList = picker:pick();
	local actions = {};
	for _, unitWithPosEntry in ipairs(selList) do
		local unit = GetUnitFromUnitIndicator(mid, unitWithPosEntry.Unit, conditionOutput);
		if unit then
			local pos = unitWithPosEntry.Position[1];
			local look = SafeIndex(unitWithPosEntry, 'LookPosition', 1);
			LogAndPrintDev('Action_MonsterLocator', unit.name, pos, look);
			local setPos = Result_SetPosition(unit, pos, nil, nil, look);
			setPos.blink = true;
			setPos.forward = true;
			table.insert(actions, setPos);
		end
	end
	return unpack(actions);
end
function Action_ToggleKillReward(mid, ds, conditionOutput, rewardMode)
	local mission = GetMission(mid);
	mission.EnableKillReward = (rewardMode == 'On');
	mission.EnableKillRewardMastery = (rewardMode == 'Mastery');
end
function Action_ToogleRewardWhenResurrect(mid, ds, conditionOutput, unitIndicator, onOff)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end
	SetInstantProperty(unit, 'RewardWhenResurrect', onOff == 'On');
end
function Action_ToggleDeadPenalty(mid, ds, conditionOutput, onOff)
	local mission = GetMission(mid);
	mission.EnableDeadPenalty = (onOff == 'On');
end
function Action_ToggleAssistMap(mid, ds, conditionOutput, onOff)
	local mission = GetMission(mid);
	local assistMap = GetWithoutError(mission, 'AssistMap');
	if not assistMap then
		LogAndPrint('[DataError] AssistMap Data not exists - mission:', mission.name);
		return;
	end
	local enabled = onOff == 'On';
	assistMap.Enabled = tostring(enabled);
	local company = GetAllCompanyInMission(mid)[1];
	if company then
		SetCompanyInstantProperty(company, 'AssistMapBeginTime', GetMissionElapsedTime(mission));
	end
end
function Action_UpdateEquipment(mid, ds, conditionOutput, unitIndicator, itemIndicator, temporary)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end
	local giveItem = Result_GiveItemByItemIndicator(unit, itemIndicator[1], conditionOutput);
	return Result_EquipItem(unit, giveItem.item_type, {IsGhost = StringToBool(temporary, true)});
end
function ForeachTeamMemberAction(mid, team, foreachFunc)
	local teamCount = GetTeamCount(mid, team);
	local actions = {};
	for i = 1, teamCount do
		local teamMember = GetTeamUnitByIndex(mid, team, i);
		table.append(actions, {foreachFunc(teamMember)});
	end
	return unpack(actions);
end
function Action_UpdateEquipmentTeam(mid, ds, conditionOutput, team, itemIndicator, temporary)
	return ForeachTeamMemberAction(mid, team, function(member)
		local giveItem = Result_GiveItemByItemIndicator(member, itemIndicator[1], conditionOutput);
		return Result_EquipItem(member, giveItem.item_type, {IsGhost = StringToBool(temporary, true)});
	end);
end
function Action_UpdateObjectPropertyTeam(mid, ds, conditionOutput, team, key, stageDataBinding, evalEach)
	local evalEach = StringToBool(evalEach);
	local updateValue;
	if not evalEach then
		updateValue = StageDataBinder(GetMission(mid), stageDataBinding[1], conditionOutput);
	end
	return ForeachTeamMemberAction(mid, team, function(member)
		conditionOutput.self = member;
		local value = evalEach and StageDataBinder(GetMission(mid), stageDataBinding[1], conditionOutput) or updateValue;
		return Result_PropertyUpdated(key, value, member, true);
	end);
end

function Action_UpdateObjectInstantPropertyTeam(mid, ds, conditionOutput, team, key, stageDataBinding, evalEach)
	local evalEach = StringToBool(evalEach);
	local updateValue;
	if not evalEach then
		updateValue = StageDataBinder(GetMission(mid), stageDataBinding[1], conditionOutput);
	end
	return ForeachTeamMemberAction(mid, team, function(member)
		local value = evalEach and StageDataBinder(GetMission(mid), stageDataBinding[1], conditionOutput) or updateValue;
		return Result_UpdateInstantProperty(member, key, value);
	end);
end

function Action_ActivateGuideTrigger(mid, ds, conditionOutput, guideTrigger)
	for _, company in ipairs(GetAllCompanyInMission(mid)) do
		RegisterGuideTriggerOne(mid, company, company.GuideTrigger[guideTrigger]);
	end
end

function Action_UpdateConditionOutput(mid, ds, conditionOutput, env)
	for i, variable in ipairs(SafeIndex(env, 1, 'Variable')) do
		local name = variable.Name;
		local dataBinding = variable.StageDataBinding[1];
		
		local envValue = StageDataBinder(GetMission(mid), dataBinding, conditionOutput);
		conditionOutput[name] = envValue;
	end
end

function Action_GiveItem(mid, ds, conditionOutput, unitIndicator, openReward)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput);
	if unit == nil then
		return;
	end
	local openReward = SafeIndex(openReward, 1);	
	local itemCollections = GetItemCollections(GetMission(mid), openReward);
	if itemCollections then
		itemCollections = RebaseXmlTableToClassTable(itemCollections);
	else
		local setType = GetItemCollectionSet(GetMission(mid), openReward);
		if setType == nil or setType == 'None' then
			itemCollections = nil;
		else
			itemCollections = GetClassList('ItemBox')[setType].Slot;
		end
	end
	if itemCollections == nil or #itemCollections == 0 then
		return;
	end
	local picker = RandomPicker.new();
	for i, slot in ipairs(itemCollections) do
		picker:addChoice(slot.Priority, SafeIndex(slot, 'Item'));
	end
	local pickedItem = picker:pick();
	local giveItem = Result_GiveItemByItemIndicator(unit, pickedItem, conditionOutput);
	if giveItem == nil then
		return;
	end
	return Result_DirectingScript(function(mid, ds, arg)
		return GiveItemWithInstantEquipDialog(ds, giveItem, unit);
	end, nil, true, true);
end

function Action_Switch(mid, ds, conditionOutput, switchEnvironment, testExpression, caseDefinition)
	local env = {math=math, os=os};
	for i, variable in ipairs(SafeIndex(switchEnvironment, 1, 'Variable')) do
		local name = variable.Name;
		local dataBinding = variable.StageDataBinding[1];
		
		local envValue = StageDataBinder(GetMission(mid), dataBinding, conditionOutput);
		env[name] = envValue;
	end
	local testFunc = loadstring('return '.. testExpression);
	setmetatable(env, {__index = _G});
	setfenv(testFunc, env);
	local testValue = testFunc();
	for _, case in ipairs(SafeIndex(caseDefinition, 1, 'Case')) do
		if tostring(testValue) == tostring(case.CaseValue) then
			local actions = case.ActionList[1].Action;
			return unpack(PlayTriggerAction(GetMission(mid), ds, actions, conditionOutput));
		end
	end
end

function Action_CallActionBundle(mid, ds, conditionOutput, actionBundle)
	actionBundle = SafeIndex(actionBundle, 1) or {};
	local coCopy = table.shallowcopy(conditionOutput);
	local funcData = GetStageFunctionDetail(mid, actionBundle.Type);
	if funcData == nil then
		LogAndPrint('Action_CallActionBundle', 'Can\'t load function data', actionBundle.Type);
		return;
	end
	local mission = GetMission(mid);
	for _, argData in ipairs(funcData.Parameter) do
		local argValue = actionBundle[argData.Name];
		local setData = nil;
		if argData.DataType == 'Position' then
			setData = GetPositionFromPositionIndicator(mid, argValue, conditionOutput, true);
		elseif argData.DataType == 'Unit' then
			setData = GetUnitFromUnitIndicator(mid, argValue, conditionOutput, true);
		elseif argData.DataType == 'Units' then
			setData = GetUnitsFromAnyUnitIndicator(mid, argValue, conditionOutput, true);
		elseif argData.DataType == 'Item' then
			setData = Result_GiveItemByItemIndicator(nil, argValue, conditionOutput);
		elseif argData.DataType == 'Dashboard' then
			setData = GetDashboardFromDashboardIndicator(mid, argValue, conditionOutput);
		elseif argData.DataType == 'Area' then
			setData = GetPositionListFromAreaIndicator(mid, argValue, conditionOutput);
		elseif argData.DataType == 'Value' then
			setData = StageDataBinder(mission, argValue[1], conditionOutput);
		elseif argData.DataType == 'Text' then
			setData = StageTextBinder(mission, argValue[1], conditionOutput);
		else
			setData = argValue;
		end
		coCopy[argData.Name] = setData;
	end
	return PlayTriggerAction(mission, ds, funcData.Action, coCopy);
end

function Action_ResetObject(mid, ds, conditionOutput, unitIndicator, maxHP, maxCost, resetSP, cooldown, useCount, turnEnd, includeDead)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput, includeDead);
	if unit == nil then
		return;
	end
	local actions = {};
	if IsDead(unit) then
		table.insert(actions, Result_Resurrect(unit, 'system'));
	end
	if maxHP then
		table.insert(actions, Result_PropertyUpdated('LowestHP', unit.MaxHP, unit, false));
		table.insert(actions, Result_PropertyUpdated('HP', unit.MaxHP, unit, true));
	end
	if maxCost then
		AddActionCost(actions, unit, unit.MaxCost);
	end
	if resetSP then
		AddSPPropertyActions(actions, unit, unit.ESP.name, -1 * unit.SP, true, ds, false, true);
	end
	if cooldown then
		local abilityList = GetAllAbility(unit, false, true);
		for _, ability in ipairs(abilityList) do
			UpdateAbilityPropertyActions(actions, unit, ability.name, 'Cool', 0);
			ability.PriorityDecay = 0;
		end	
	end
	if useCount then
		local abilityList = GetAllAbility(unit);
		for _, ability in ipairs(abilityList) do
			if ability.IsUseCount then
				local newUseCount = ability.MaxUseCount;
				UpdateAbilityPropertyActions(actions, unit, ability.name, 'UseCount', newUseCount);
			end
		end
	end
	if turnEnd then
		table.insert(actions, Result_TurnEnd(unit));
	end
	return unpack(actions);
end

function Action_ToggleBossEvent(mid, ds, conditionOutput, onOff)
	g_EnableBossEvent = onOff == 'On';
end

function InitializeCheckTeamArrivedUnitCountTest(mid, session, team, areaIndicator, operation, value)
    local teamCount = GetTeamCount(mid, team);
    local count = 0
	for i = 1, teamCount do
		local teamMember = GetTeamUnitByIndex(mid, team, i);
		local pos = GetPosition(teamMember);
		if PositionInAreaIndicator(mid, areaIndicator, pos, {}) then	
		    count = count + 1
		end
	end
	return CompareOperation(operation, count, value)
end
function CheckTeamArrivedUnitCountTest(mid, session, eventArg, team, areaIndicator, operation, value)
    local teamCount = GetTeamCount(mid, team);
    local count = 0
	for i = 1, teamCount do
		local teamMember = GetTeamUnitByIndex(mid, team, i);
		local pos = GetPosition(teamMember);
		if PositionInAreaIndicator(mid, areaIndicator, pos, {}) then	
		    count = count + 1
		end
	end
	return CompareOperation(operation, count, value)
end

function CheckTeamItemAcquired(mid, session, eventArg, team, itemType)
	if eventArg.Team ~= team then
		return;
	end
	if eventArg.ItemType ~= itemType then
		return;
	end
	return true;
end