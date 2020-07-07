 -------------------------------------------------------------------------
-- 클라이언트 / 로비 / 미션/ 크래프터 판단 함수.
-------------------------------------------------------------------------
function IsLobbyServer()
	return (_G['GetAppName'] ~= nil and GetAppName() == 'LobbyServer')
end

function IsMissionServer()
	return (_G['GetAppName'] ~= nil and GetAppName() == 'MissionServer')
end

function IsClient()
	return (_G['GetAppName'] ~= nil and GetAppName() == 'Client')
end

function IsDandyCrafter()
	return (_G['GetAppName'] ~= nil and GetAppName() == 'DandyCrafter')
end
-------------------------------------------------------------------------
--- 로비인지 아닌지 (클라는 로비 모드인지, 서버는 로비 서버인지)
-------------------------------------------------------------------------
function IsLobby()
	if IsLobbyServer() then
		return true
	elseif IsClient() then
		return IsLobbyMode() or IsOfficeMode()
	else
		return false
	end
end
--- 미션인지 아닌지 (클라는 미션 모드인지, 서버는 미션 서버인지)
function IsMission()
	if IsMissionServer() then
		return true
	elseif IsClient() then
		return IsMissionMode()
	elseif IsDandyCrafter() then
		return IsMissionMode()
	else
		return false
	end
end
-------------------------------------------------------------------------
--- 게임 로직 함수.
-------------------------------------------------------------------------
function GetClassNameList(idspace, filter, noNone)
	local clsList = GetClassList(idspace);
	local list = {};
	if not noNone then
		table.insert(list, 'None');
	end
	for name, cls in pairs(clsList) do
		if filter == nil or filter(cls) then
			table.insert(list, name);
		end
	end
	return list;
end
function GetClassNameTitleList(idspace, filter, noNone)
	local clsList = GetClassList(idspace);
	local list = {};
	if not noNone then
		table.insert(list, {'None', '없음'});
	end
	for i = 1, #clsList do
		local cls = GetByIndex(clsList, i);
		local name = cls.name;
		if filter == nil or filter(cls) then
			local key = name;
			local title = name;
			if GetWithoutError(cls, 'Title') then
				title = string.format('%s (%s)', cls.Title, title);
			end
			table.insert(list, {name, title});
		end
	end
	return list;
end
function GetPcInfo(target, rosters)
	local checkFunc = function(pcInfo)
		if IsMission() and pcInfo.RosterType == 'Beast' then
			local team = nil;
			if IsClient() then
				team = GetPlayerTeamName();
			else
				team = GetTeam(target);
			end
			return GetObjKey(target) == GetBeastObjKey(team, pcInfo);
		elseif IsMission() and pcInfo.RosterType == 'Machine' then
			local team = nil;
			if IsClient() then
				team = GetPlayerTeamName();
			else
				team = GetTeam(target);
			end
			return GetObjKey(target) == GetMachineObjKey(team, pcInfo);
		else
			return pcInfo.Object.name == target.name;
		end
	end
	local pcInfo = nil;
	for index, value in ipairs (rosters) do
		if checkFunc(value) then
			pcInfo = value;
			break;
		end
	end
	return pcInfo;
end
function GetPcInfoByName(targetName, rosters)
	local pcInfo = nil;
	for index, value in ipairs (rosters) do
		if value.RosterKey == targetName then
			pcInfo = value;
			break;
		end
	end
	return pcInfo;
end
---------------------------------------------------------------------------------------------------
-- 3D 공간의 월드 거리 받아오는 함수, 내가 더 높은 위치에 있으면 음수, 내가 낮은 위치면 양수
---------------------------------------------------------------------------------------------------
function GetDistanceFromObjectToObjectAbility(ability, startObj, endObj)
	if IsMissionServer() and ability.AbilityWithMove then
		local startPos = GetInstantProperty(startObj, 'AbilityPrevPosition') or GetPosition(startObj);
		local endPos = GetPosition(endObj);
		return GetDistance3D(startPos, endPos), GetHeight(startPos, endPos);
	else
		return GetDistanceFromObjectToObject(startObj, endObj);
	end
end
function GetDistanceFromObjectToObject(startObj, endObj)
	local selfPos = GetPosition(startObj);
	local targetPos = GetPosition(endObj);
	local distance = GetDistance3D(selfPos, targetPos);
	local height = GetHeight(selfPos, targetPos);
	return distance, height;
end
function GetDistance3D(p1, p2) 
	if p1 == nil or p2 == nil or p1.x == nil or p2.x == nil then
		Traceback();
	end
	if IsInvalidPosition(p1) or IsInvalidPosition(p2) then
		return math.huge;
	end

	return math.sqrt(math.pow(p1.x - p2.x, 2) + math.pow(p1.y - p2.y, 2) + math.pow((p1.z - p2.z)/15, 2));
end
function GetDistance2D(p1, p2)
	if p1 == nil or p2 == nil or p1.x == nil or p2.x == nil then
		Traceback();
	end
	if IsInvalidPosition(p1) or IsInvalidPosition(p2) then
		return math.huge;
	end

	return math.sqrt(math.pow(p1.x - p2.x, 2) + math.pow(p1.y - p2.y, 2));
end
function IsMeleeDistance(p1, p2, dist)
	return GetDistance2D(p1, p2) < (dist or 1.4) + 0.4 and math.abs(p1.z - p2.z) <= 16;
end
function IsMeleeDistanceAbility(o1, o2, dist)
	return IsMeleeDistance(GetAbilityUsingPosition(o1), GetAbilityUsingPosition(o2), dist);
end
function IsMeleeDistanceHeight(distance, height)
	return distance < 1.8 and height <= 16 / 15;
end
function GetMeleeDistancePositions(self)
	return CalculateRange(self, 'Sphere1.4_Attack', GetPosition(self));
end
function GetPathLength(path)
	local prev = path[1];
	local length = 0;
	for i, p in ipairs(path) do
		length = length + GetDistance3D(p, prev);
		prev = p;
	end
	return length;
end
function GetHeight(p1, p2) 
	return (p1.z - p2.z)/15;
end
function AddPosition(p1, p2)
	return { x = p1.x + p2.x, y = p1.y + p2.y, z = p1.z + p2.z };
end

-- xml에 선언된 table 타입 프로퍼티는 실제로는 lua table이 아니므로, lua table 값이 필요한 곳에서는 변환해서 사용해야 한다.
function PositionPropertyToTable(pos)
	return { x = pos.x, y = pos.y, z = pos.z };
end
---------------------------------------------------------------------------------------------------
-- WordCollection.xml 
---------------------------------------------------------------------------------------------------
function GetWord(wordKey, noError)
	local textMap = GetClassList('WordCollection');
	if SafeIndex(textMap, wordKey, 'Text') == nil then
		if not noError then
			LogAndPrint('Error in GetWord, wordKey:'..wordKey);
			Traceback();
		end
		return wordKey;
	end
	return textMap[wordKey]['Text'];
end
function GetCivilMessage(msgType, ageType)
	local civilMessageList = GetClassList('CivilMessage');
	if SafeIndex(civilMessageList, msgType, 'Reactions', ageType, 'TextList') == nil then
		LogAndPrint('Error in GetCivilMessage, wordKey:'..msgType, ageType);
		return nil;
	end
	
	local textList = civilMessageList[msgType].Reactions[ageType].TextList;
	local text = textList[math.random(1, #textList)].Text;
	return text;
end
function GetBuffType(obj, buffType, buffSubType, buffGroup, isWithAura)
	if obj == nil then
		return {};
	end
	local buffList = GetBuffList(obj);
	if buffList == nil or #buffList == 0 then
		return {};
	end
	-- 오라 버프 참여 여부
	if not isWithAura then
		buffList = table.filter(buffList, function(buff) return buff.SubType ~= 'Aura'; end);
	end
	if #buffList == 0 then
		return buffList;
	end
	local filterGen = function(column, testValue)
		return function (buff)
			if testValue then
				return buff[column] == testValue;
			else
				return true;
			end
		end
	end
	
	-- 버프 타입 추리기.
	local filteredByType = table.filter(buffList, filterGen('Type', buffType));
	
	-- 버프 서브 타입 추리기.
	local filteredBySubType = table.filter(filteredByType, filterGen('SubType', buffSubType));
	
	-- 버프 그룹 추리기.
	return table.filter(filteredBySubType, filterGen('Group', buffGroup));
end
function HasBuffType(obj, buffType, buffSubType, buffGroup, isWithAura)
	if obj == nil then
		return false;
	end
	local buffList = GetBuffList(obj);
	if buffList == nil or #buffList == 0 then
		return false;
	end
	-- 오라 버프 참여 여부
	if not isWithAura then
		buffList = table.filter(buffList, function(buff) return buff.SubType ~= 'Aura'; end);
	end
	if #buffList == 0 then
		return false;
	end
	
	local checkerList = {};
	local checkerGen = function(column, testValue)
		if not testValue then
			return;
		end
		local checker = function (buff)
			return buff[column] == testValue;
		end
		table.insert(checkerList, checker);
		return checker;
	end
	
	checkerGen('Type', buffType);
	checkerGen('SubType', buffSubType);
	checkerGen('Group', buffGroup);
	if #checkerList == 0 then
		return false;
	end
	
	return table.findif(buffList, function (buff)
		for _, checker in ipairs(checkerList) do
			if not checker(buff) then
				return false;
			end
		end
		return true;
	end);
end
function GetObjectBonePosWithParts(obj, posWithParts)
	local separated = string.split(posWithParts, '/');
	if #separated <= 1 then	
		return GetObjectBonePos(obj, posWithParts);
	else
		return GetObjectBonePos(obj, separated[2]), separated[1];
	end
end
function GetObjectBonePos(obj, pos)	
	if pos == '_TOP_' or pos == '_CENTER_' or pos == '_BOTTOM_' then
		return pos
	end
	local bonePosRaw = SafeIndex(GetClassList('BoneMap'), obj.Shape.BodySize, pos);
	if bonePosRaw == nil then
		LogAndPrint(string.format('BoneMap.%s.%s 가 존재하지 않음', obj.Shape.BodySize, pos));
		return '_CENTER_';
	end
	local separated = string.split(bonePosRaw, '/');
	if #separated <= 1 then
		return separated[1];
	else
		return separated[2], separated[1];
	end
end
function GetElapsedTimeString(amount)
	local curSec = math.floor(amount%60);
	local curMin = math.floor(amount/60)%60;
	local curHour = math.floor(amount/3600)%24;
	local curDay = math.floor(amount/86400);
	local result = '';
	if curDay > 0 then
		result = curDay..'D';
	end
	if curHour > 0 then
		result = result..'  '..curHour..'H';
	end
	if curMin > 10 then
		result = result..' '..curMin..'M';
	elseif curMin > 0 then
		result = result..'  '..curMin..'M';
	end
	if curSec > 10 then
		result = result..' '..curSec..'S';
	elseif curSec > 0 then
		result = result..'  '..curSec..'S';
	end
	return result;
end
function GetElapsedTimeShortString(amount)
	local curSec = math.floor(amount%60);
	local curMin = math.floor(amount/60)%60;
	local curHour = math.floor(amount/3600)%24;
	local curDay = math.floor(amount/86400);
	local result = '';
	if curDay > 0 then
		return curDay..' D';
	end
	if curHour > 0 then
		return curHour..' H';
	end
	if curMin > 0 then
		return curMin..' M';
	end
	if curSec > 0 then
		return curSec..' S';
	end
	return result;
end
function GetDateString(amount)
	local curMinutes = tonumber(os.date("%M", amount));
	local curHours = tonumber(os.date("%H", amount));
	local curDays =  tonumber(os.date("%d", amount));
	local curMonths = tonumber(os.date("%m", amount));
	local curYears =tonumber( os.date("%Y", amount));
	local result = '';
	
	if curYears > 0 then
		result = curYears..'Y';
	end
	if curMonths > 0 then
		result = result..' '..'M';
	end
	if curDays > 0 then
		result = result..' '..curDays..'D';
	end
	if curHours > 0 then
		result = result..' '..curHours..'H';
	end
	if curMinutes > 0 then
		result = result..' '..curMinutes..'M';
	end
	result = result..GetWord('ExpireDateMsg');	
	return result;
end
function GetShortTimeString(amount, forceHour, forceMin)
	local curSec = math.floor(amount%60);
	local curMin = math.floor(amount/60)%60;
	local curHour = math.floor(amount/3600);
	
	if curHour > 0 or forceHour then
		return string.format('%d:%02d:%02d', curHour, curMin, curSec);
	elseif curMin > 0 or forceMin then
		return string.format('%d:%02d', curMin, curSec);
	else
		return string.format('%d', curSec);
	end
end
--------------------------------- 미션 시간 ------------------------------
-- Act 1은 1/1000초 기준, 분, 초
--------------------------------------------------------------------------
function GetMissionElapsedTimeString(amount)
	local curAmount = math.floor(amount/10);
	local curSec = math.floor(curAmount%60);
	local curMin = math.floor(curAmount/60)%60;
	local curHour = math.floor(curAmount/3600)%24;
	local curDay = math.floor(curAmount/86400);
	local result = '';
	if curDay > 0 then
		result = curDay..GetWord('LeftDay');
	end
	if curHour > 0 then
		result = result..'  '..curHour..GetWord('LeftHour');
	end
	if curMin > 10 then
		result = result..' '..curMin..GetWord('Minute');
	else
		result = result..'  '..curMin..GetWord('Minute');
	end
	if curSec > 10 then
		result = result..' '..curSec..GetWord('Second');
	else
		result = result..'  '..curSec..GetWord('Second');
	end
	return result;
end
--------------------------------- 미션 시간 ------------------------------
-- 시간
--------------------------------------------------------------------------
function GetMissionElapsedSymbolicTime(amount)
	local curSec = math.floor(amount%60);
	local curMin = math.floor(amount/60)%60;
	local curHour = math.floor(amount/3600);
	local result = '';

	if curHour > 9 then
		result = curHour;
	else
		result = '0'..curHour;
	end	
	if curMin > 9 then
		result = result..':'..curMin;
	else
		result = result..':0'..curMin;
	end
	if curSec > 9 then
		result = result..':'..curSec;
	else
		result = result..':0'..curSec;
	end

	return result;
end
--------------------------- 미션 왕복 시간 ------------------------------------
function GetTurnOverTime(speed, distance)
	local turnOverTime = distance/speed * 60 * 60 * 10;
	-- 왕복
	turnOverTime = turnOverTime * 2;
	return turnOverTime;
end
------------------- 미션 왕복 시간에 따른 컨디션 소모량 --------------------------
function GetTurnOverConsumeCondition(elapsedTime)
	local comsumeContionPoint = math.max(1, math.floor(elapsedTime/600));
	return comsumeContionPoint;
end
------------------- 전투 시간에 따른 컨디션 소모량 --------------------------
function GetBattleDurationConsumeCondition(amount)
	return math.max(1,math.floor(amount/600));
end
----------------------------------------------------------------------------
-- 다음 경험치 찾기
----------------------------------------------------------------------------
function GetNextExp(field, lv)
	local expTable = GetClassList('Exp');
	lv = math.min(50, math.max(1,lv));
	return expTable[tostring(lv)][field];
end
function GetNextLvAndExp(field, curLv, curExp, limit)
	if limit == nil or limit == 0 then
		limit = SafeIndex(GetClassList('ExpLimit'), field, 'Limit') or 99999;
	end
	local loseExp = 0;
	if curLv >= limit then
		loseExp = curExp;
		curExp = 0;
	end
	local nextExp = GetNextExp(field, curLv);
	while curExp >= nextExp do
		curExp = curExp - nextExp;
		curLv = curLv + 1;
		nextExp = GetNextExp(field, curLv);
		if curLv >= limit then
			loseExp = curExp;
			curExp = 0;
			break;
		end
	end
	
	return curLv, curExp, loseExp;
end
function CalculateExpDiff(field, fromLv, fromExp, toLv, toExp)
	if fromLv > toLv then
		return 0;	-- 에러임..
	end
	if fromLv == toLv then
		return toExp - fromExp;
	end
	local nextExp = GetNextExp(field, fromLv);
	return nextExp - fromExp + CalculateExpDiff(field, fromLv + 1, 0, toLv, toExp);
end
----------------------------------------------------------------------------
-- 지정된 부모(조상)으로부터 /로 계층화된 프로퍼티 키값을 받아온다.
----------------------------------------------------------------------------
function GetRecursiveKey(parent, obj, propName)
	if obj[propName] == nil then
		return nil;
	end
	local keyChain = GetObjectKeyChain(parent, obj);
	if keyChain == nil then
		return nil;
	end
	if keyChain == '' then
		return propName;
	else
		return keyChain..'/'..propName;
	end
end
function GetItemAbilities(owner)
	local list = {};
	local equipmentList = GetItemSlotList();
	for _, slot in ipairs (equipmentList) do
		local itemAbility = GetWithoutError(owner[slot], 'Ability', 'name');
		if itemAbility and itemAbility ~= 'None' then
			table.insert(list, itemAbility);
		end
	end
	return list;
end

function IsCoveredObject(object, position)
	position = position or GetPosition(object);
	if IsMissionServer() then
		return IsCoveredPosition(GetMission(object), position);
	elseif IsClient() and IsMissionMode() then
		return IsCoveredPosition(position);
	else
		return false;
	end
end

function GetPositionIndicatorString(posIndicator)
	if posIndicator == nil then
		return 'NoPosition';
	end
	posIndicator = posIndicator[1];
	if posIndicator == nil then
		return '';
	elseif posIndicator.Type == 'Object' and posIndicator.ObjectKey ~= nil then
		return string.format('대상:%s', posIndicator.ObjectKey);
	elseif posIndicator.Type == 'Position' and posIndicator.Position and posIndicator.Position[1] then
		local pos = posIndicator.Position[1];
		return string.format('위치: (%d,%d,%d)', pos.x, pos.y, pos.z);
	elseif posIndicator.Type == 'ConditionOutput' then
		return string.format('조건결과(%s)', posIndicator.Key);
	elseif posIndicator.Type == 'Variable' then
		return string.format('변수값(%s)', posIndicator.Variable);
	elseif posIndicator.Type == 'CenterOfArea' then
		table.print(posIndicator)
		local from = posIndicator.Area[1].From[1];
		local to = posIndicator.Area[1].To[1];
		return string.format('영역의 가운데:{(%d,%d,%d),(%d,%d,%d)}', from.x, from.y, from.z, to.x, to.y, to.z);
	elseif posIndicator.Type == 'ObjectInstantProperty' then
		return string.format('대상의 InstantProperty %s{%s}', GetUnitIndicatorString(posIndicator.Unit), posIndicator.Key);
	elseif posIndicator.Type == 'EmptyNearObject' then
		return string.format('랜덤의 대상으로부터 거리: %s 범위: %d', GetUnitIndicatorString(posIndicator.Unit), tonumber(posIndicator.Range));
	else
		return 'NoPosition';
	end
end

function GetUnitIndicatorString(unitIndicator)
	unitIndicator = SafeIndex(unitIndicator, 1);
	if unitIndicator == nil then
		return 'NoUnit';
	end
	
	if unitIndicator.Type == 'Object' and unitIndicator.ObjectKey ~= nil then
		return string.format('Object(%s)', unitIndicator.ObjectKey);
	elseif unitIndicator.Type == 'Type' and unitIndicator.Team and unitIndicator.GameObject then
		return string.format('%s(%s)', unitIndicator.GameObject, unitIndicator.Team);
	elseif unitIndicator.Type == 'ConditionOutput' and unitIndicator.Key then
		return string.format('Condition(%s)', unitIndicator.Key);
	elseif unitIndicator.Type == 'Interaction' and unitIndicator.InteractionUnit then
		return string.format('Interaction(%s)', unitIndicator.InteractionUnit);
	elseif unitIndicator.Type == 'Variable' and unitIndicator.Variable then
		return string.format('Variable(%s)', unitIndicator.Variable);
	else
		return 'NoUnit';
	end;
end

function GetItemIndicatorString(itemIndicator)
	itemIndicator = SafeIndex(itemIndicator, 1);
	if itemIndicator == nil then
		return 'NoItem';
	end
	
	if itemIndicator.Type == 'Simple' then
		return string.format('%s(%d)', itemIndicator.ItemType, tonumber(itemIndicator.Count));
	end
	
	return 'No Item';
end

function GetAnyUnitIndicatorString(unitIndicator)
	unitIndicator = SafeIndex(unitIndicator, 1);
	if unitIndicator == nil then
		return 'NoUnit';
	end
	
	if unitIndicator.Type == 'Type' and unitIndicator.Team and unitIndicator.GameObject then
		return string.format('%s(%s)', unitIndicator.GameObject, unitIndicator.Team);
	elseif unitIndicator.Type == 'InstantProperty' and unitIndicator.PropKey then
		return string.format('InstantProperty(%s: %s)', unitIndicator.PropKey, unitIndicator.SuccessExpression);
	elseif unitIndicator.type == 'ConditionOutput' then
		return string.format('Condtion(%s)', unitIndicator.Key);
	else
		return 'NoUnit';
	end;
end

function GetAllUnitIndicatorString(unitIndicator)
	unitIndicator = SafeIndex(unitIndicator, 1);
	if unitIndicator == nil then
		return 'NoUnit';
	end
	
	if unitIndicator.Type == 'Team' then
		return string.format('팀: %s', unitIndicator.Team);
	elseif unitIndicator.Type == 'Area' then
		return string.format('범위: %s', GetAreaIndicatorString(unitIndicator.AreaIndicator));
	elseif unitIndicator.Type == 'TeamArea' then
		return string.format('팀: %s, 범위: %s', unitIndicator.Team, GetAreaIndicatorString(unitIndicator.AreaIndicator));
	else
		return 'NoUnit';
	end;
end

function GetAreaIndicatorString(areaIndicator)
	areaIndicator = SafeIndex(areaIndicator, 1);
	if areaIndicator == nil or areaIndicator.Type == 'None' then
		return 'NoArea';
	end
	
	if areaIndicator.Type == 'Area' and areaIndicator.Area ~= nil then
		return AreaToString(areaIndicator.Area[1]);
	elseif areaIndicator.Type == 'Range' and areaIndicator.PositionIndicator ~= nil then
		return string.format('%s에서 %s만큼', GetPositionIndicatorString(areaIndicator.PositionIndicator), areaIndicator.Range);
	elseif areaIndicator.Type == 'PositionList' then
		local posList = SafeIndex(areaIndicator, 'PositionList', 1, 'PosElem');
		if posList == nil or #posList == 0 then
			return string.format('빈 영역');
		else
			return string.format('%s를 포함한 %d칸', GetPositionIndicatorString(posList[1].PositionIndicator), #posList);
		end
	elseif areaIndicator.Type == 'PositionHolder' then
		return string.format('지정영역: %s', areaIndicator.PosHolderGroup);
	elseif areaIndicator.Type == 'Union' then
		return string.format('%s', Linq.new(areaIndicator.AreaIndicatorList[1].Areas)
			:select(function(ai) return GetAreaIndicatorString(ai.AreaIndicator) end)
			:concat(' U '));
	elseif areaIndicator.Type == 'Difference' then
		return string.format('Diff (%s - %s)', GetAreaIndicatorString(areaIndicator.AreaIndicatorFrom), GetAreaIndicatorString(areaIndicator.AreaIndicatorDiff));
	elseif areaIndicator.Type == 'ConditionOutput' then
		return string.format('Condition:%s', areaIndicator.Key);
	else
		return 'InvalidArea';
	end
end

function GetStageDataBindingString(dataBinding)	
	dataBinding = SafeIndex(dataBinding, 1);
	if dataBinding == nil then
		return 'No Data';
	end
	local dataType = dataBinding.Type;
	if dataType == 'Mission' then
		return 'mission';
	elseif dataType == 'StageVariable' then
		return string.format('var: %s', dataBinding.Variable);
	elseif dataType == 'Object' then
		return GetUnitIndicatorString(dataBinding.Unit);
	elseif dataType == 'Dashboard' then
		return string.format('dashboard: %s', dataBinding.DashboardKey);
	elseif dataType == 'Static' then
		return dataBinding.Value;
	elseif dataType == 'Position' then
		return GetPositionIndicatorString(dataBinding.PositionIndicator);
	elseif dataType =='Expr' then
		local envMap = {}
		local expr = dataBinding.TestExpression;
		for _, var in ipairs(SafeIndex(dataBinding, 'Env', 1, 'Variable') or {}) do
			envMap[var.Name] = string.format('%s', GetStageDataBindingString(var.StageDataBinding));
			expr = string.gsub(expr, '([^.]?)'..var.Name, '%1$'..var.Name..'$');
		end
		return FormatMessage(tostring(expr), envMap);
	else
		return 'No Data';
	end
end

function GetStageTextBindingString(textBinding)
	textBinding = SafeIndex(textBinding, 1);
	if textBinding == nil then
		return 'No Data';
	end
	local dataType = textBinding.Type;
	if dataType == 'Raw' then
		return textBinding.Title;
	elseif dataType == 'ClassData' then
		return string.format('ClassDataText %s', textBinding.StageVarExpr);
	elseif dataType == 'Word' then
		return string.format('Word %s', textBinding.StageVarExpr);
	elseif dataType == 'GuideMessage' then
		return string.format('GuideMessage %s', textBinding.StageVarExpr);
	elseif dataType == 'Custom' then
		return string.format('Custom %s', textBinding.StageVarExpr);
	elseif dataType == 'ConditionOutput' then
		return string.format('Condition: %s', textBinding.Key);
	else
		return 'ERROR';
	end
end

function GetItemCollectionString(itemCollections)
	if not itemCollections or #itemCollections == 0 then
		return 'NoItem';
	elseif #itemCollections == 1 then
		return SafeIndex(itemCollections, 1, 'Item', 1, 'ItemType');
	else
		return string.format('%s 외 %d 종', SafeIndex(itemCollections, 1, 'Item', 1, 'ItemType'), #itemCollections - 1);
	end
end

function GetOpenRewardString(openReward)
	openReward = SafeIndex(openReward, 1);
	if openReward == nil then
		return 'NoReward';
	end
	if openReward.Type == 'Information' then
		return string.format('%s(%s)', openReward.Type, tostring(openReward.Priority));
	elseif openReward.Type == 'Item_Chest' or openReward.Type == 'Item_Lock' then
		local itemCollections = SafeIndex(openReward, 'ItemCollection', 1, 'Slot');
		return string.format('%s(%s)', openReward.Type, GetItemCollectionString(itemCollections));
	elseif openReward.Type == 'Item_Chest_Difficulty' then
		local itemCollectionEasy = SafeIndex(openReward, 'ItemCollectionEasy', 1, 'Slot');
		local itemCollectionNormal = SafeIndex(openReward, 'ItemCollectionNormal', 1, 'Slot');
		local itemCollectionHard = SafeIndex(openReward, 'ItemCollectionHard', 1, 'Slot');
		return string.format('%s\n└ Easy: %s\n└ Normal: %s\n└ Hard: %s', openReward.Type, GetItemCollectionString(itemCollectionEasy), GetItemCollectionString(itemCollectionNormal), GetItemCollectionString(itemCollectionHard));
	elseif openReward.Type == 'ItemSet_Chest' then
		local itemCollectionSet = SafeIndex(openReward, 'ItemCollectionSet');
		return string.format('%s(%s)', openReward.Type, itemCollectionSet);
	elseif openReward.Type == 'ItemSet_Chest_Difficulty' then
		local itemCollectionSetEasy = SafeIndex(openReward, 'ItemCollectionSetEasy');
		local itemCollectionSetNormal = SafeIndex(openReward, 'ItemCollectionSetNormal');
		local itemCollectionSetHard = SafeIndex(openReward, 'ItemCollectionSetHard');
		return string.format('%s\n└ Easy: %s\n└ Normal: %s\n└ Hard: %s', openReward.Type, itemCollectionSetEasy, itemCollectionSetNormal, itemCollectionSetHard);
	else
		return 'NoReward';
	end
end

function GetItemCollections(mission, openReward)
	local itemCollections = SafeIndex(openReward, 'ItemCollection', 1, 'Slot');
	if itemCollections ~= nil then
		return itemCollections;
	end
	local grade = mission.DifficultyGrade;
	local difficulty = nil;	
	if grade == 'Easy' or grade == 'Safty' then
		difficulty = 'Easy';
	elseif grade == 'Normal' then
		difficulty = 'Normal';
	else
		difficulty = 'Hard';
	end
	return SafeIndex(openReward, 'ItemCollection'..difficulty, 1, 'Slot');
end

function GetItemCollectionSet(mission, openReward)
	local itemCollectionSet = SafeIndex(openReward, 'ItemCollectionSet');
	if itemCollectionSet ~= nil then
		return itemCollectionSet;
	end
	local grade = mission.DifficultyGrade;
	local difficulty = nil;	
	if grade == 'Easy' or grade == 'Safty' then
		difficulty = 'Easy';
	elseif grade == 'Normal' then
		difficulty = 'Normal';
	else
		difficulty = 'Hard';
	end
	return SafeIndex(openReward, 'ItemCollectionSet'..difficulty);
end


function AreaToString(area)
	return string.format('{{%d, %d, %d}, {%d, %d, %d}}',
			area.From[1].x, area.From[1].y, area.From[1].z,
			area.To[1].x, area.To[1].y, area.To[1].z);
end

function OperationToString(operation)
	local operationTable = {
		Equal = "==",
		NotEqual = "~=",
		LessThan = "<",
		GreaterThan = ">",
	};
	
	local ret = operationTable[operation];
	if ret == nil then
		ret = '?';
	end
	return ret;
end

function GetDashboardIndicatorString(dashboardIndicator)
	dashboardIndicator = SafeIndex(dashboardIndicator, 1);
	if dashboardIndicator == nil then
		return '(nil)';
	end
	local dit = dashboardIndicator.Type;
	if dit == 'Dashboard' then
		return string.format('Dashboard: %s', dashboardIndicator.DashboardKey);
	elseif dit == 'ConditionOutput' then
		return string.format('Condition: %s', dashboardIndicator.Key);
	elseif dit == 'KeyExpression' then
		return GetStageDataBindingString(dashboardIndicator.StageDataBinding);
	end
end

function ConditionCaptionInitializer(cls, condition)
	--LogAndPrint('ConditionCaptionInitializer - cls.name : ', cls.name);
	local dumpStr = PackTableToStringReadable(condition);

	local msg = '';	
	if cls.name == 'TeamDestroy' then
		msg = string.format('\\[ ♨ %s \\] - %s, \\[%s\\]', cls.Desc, condition.Team, StringToBool(condition.OnFieldOnly) and 'Invalid 위치 제외' or '전체');
	elseif cls.name == 'TeamDestroyInstant' then
		msg = string.format('\\[ ♨ %s \\] - %s, \\[%s\\]', cls.Desc, condition.Team, StringToBool(condition.OnFieldOnly) and 'Invalid 위치 제외' or '전체');
	elseif cls.name == 'UnitArrived' then
		msg = string.format('\\[ ◎ %s \\]\\[ %s \\] ▷▷▷ 영역: %s', cls.Desc, GetUnitIndicatorString(condition.Unit), AreaToString(condition.Area[1]));
	elseif cls.name == 'UnitArrived2' then
		msg = string.format('\\[ ◎ %s \\]\\[ %s \\] ▷▷▷ 영역: %s', cls.Desc, GetUnitIndicatorString(condition.Unit), GetAreaIndicatorString(condition.AreaIndicator));
	elseif cls.name == 'UnitNotInArea' then
		msg = string.format('\\[ ◎ %s \\]\\[ %s \\] ▷▷▷ 영역: %s', cls.Desc, GetUnitIndicatorString(condition.Unit), AreaToString(condition.Area[1]));
	elseif cls.name == 'UnitNotInArea2' then
		msg = string.format('\\[ ◎ %s \\]\\[ %s \\] ▷▷▷ 영역: %s', cls.Desc, GetUnitIndicatorString(condition.Unit), GetAreaIndicatorString(condition.AreaIndicator));
	elseif cls.name == 'UnitArrivedEscapeArea' then
		msg = string.format('\\[ ▨ %s \\] - 대상: %s', cls.Desc, GetUnitIndicatorString(condition.Unit));
	elseif cls.name == 'TeamAccessToUnit' then
		msg = string.format('\\[ ◎ %s \\]\\[ 팀: %s \\] ▷▷▷ 대상: %s, 범위 %s', cls.Desc, condition.Team, GetUnitIndicatorString(condition.Unit), condition.Range);
	elseif cls.name == 'TeamArrived' then
		msg = string.format('\\[ ◎ %s \\]\\[ %s \\] ▷▷▷ 영역: %s', cls.Desc, condition.Team, AreaToString(condition.Area[1]));
	elseif cls.name == 'TeamArrived2' then
		msg = string.format('\\[ ◎ %s \\]\\[ %s \\] ▷▷▷ 영역: %s', cls.Desc, condition.Team, GetAreaIndicatorString(condition.AreaIndicator));
	elseif cls.name == 'GroupArrived' then
		msg = string.format('\\[ ◎ %s \\]\\[ %s \\] ▷▷▷ 영역: %s', cls.Desc, condition.Group, GetAreaIndicatorString(condition.AreaIndicator));
	elseif cls.name == 'UnitArrivedToUnit' then
		msg = string.format('\\[ ◎ %s \\]\\[ %s \\] ▷▷▷ 유닛: %s, 범위: %s', cls.Desc, GetUnitIndicatorString(condition.Unit), GetUnitIndicatorString(condition.Unit2), condition.Range);
	elseif cls.name == 'TeamArrivedToUnit' then
		msg = string.format('\\[ ◎ %s \\]\\[ 팀: %s \\] ▷▷▷ 대상: %s, 범위 %s', cls.Desc, condition.Team, GetUnitIndicatorString(condition.Unit), condition.Range);
	elseif cls.name == 'MissionBegin' then
		msg = string.format('\\[ ☆☆☆ %s ☆☆☆ \\]', cls.Desc);
	elseif cls.name == 'MissionEnd' then
		msg = string.format('\\[ ☆☆☆ %s ☆☆☆ \\] - 팀: %s', cls.Desc, condition.Team);
	elseif cls.name == 'NearUnitCountTest' then
		msg = string.format('\\[ ♨ %s \\] - 대상: %s, \n└ 거리: %s \n└ 관계: %s \n└ 필터: %s \n└ %s %s', 
			cls.Desc, GetUnitIndicatorString(condition.Unit), condition.Range, condition.Relation, tostring(condition.UnitFilterExpr), OperationToString(condition.Operation), tostring(condition.Value)
		);
	elseif cls.name == 'UnitAlive' then
		msg = string.format('\\[ ♨ %s \\] - 대상: %s', cls.Desc, GetUnitIndicatorString(condition.Unit));
	elseif cls.name == 'UnitDead' then
		local checkKiller = '사용 안함';
		if StringToBool(condition.CheckKiller) then
			checkKiller = '사용함';
		end
		msg = string.format('\\[ ♨ %s \\] - 대상: %s, 킬러 체크: %s', cls.Desc, GetUnitIndicatorString(condition.Unit), checkKiller);
	elseif cls.name == 'TeamDeadEvent' then
		msg = string.format('\\[ ♨ %s \\] - 팀: %s', cls.Desc, condition.Team);
	elseif cls.name == 'GroupDeadEvent' then
		msg = string.format('\\[ ♨ %s \\] - 그룹 : %s', cls.Desc, condition.Group);
	elseif cls.name == 'UnitDeadEvent' then
		local checkKiller = '사용 안함';
		if StringToBool(condition.CheckKiller) then
			checkKiller = '사용함';
		end
		msg = string.format('\\[ ♨ %s \\] - 대상: %s, 킬러 체크: %s', cls.Desc, GetUnitIndicatorString(condition.Unit), checkKiller);
	elseif cls.name == 'AnyUnitDeadEvent' then
		local checkKiller = '사용 안함';
		if StringToBool(condition.CheckKiller) then
			checkKiller = '사용함';
		end
		msg = string.format('\\[ ♨ %s \\] - 대상: %s, 킬러 체크: %s', cls.Desc, GetAnyUnitIndicatorString(condition.AnyUnit), checkKiller);
	elseif cls.name == 'UnitLastKill' then
		msg = string.format('\\[ ♨ %s \\] - 전투 불능 대상: %s', cls.Desc, GetUnitIndicatorString(condition.Unit));
	elseif cls.name == 'UnitInsightToTeam' then
		msg = string.format('\\[ ◎ %s \\] - 발견 팀: %s ▶▶▶ 발각 대상: %s', cls.Desc, condition.Team, GetUnitIndicatorString(condition.Unit));
	elseif cls.name == 'UnitInsightToUnit' then
		msg = string.format('\\[ ◎ %s \\] - 발견 대상: %s ▶▶▶ 발각 대상: %s', cls.Desc, GetUnitIndicatorString(condition.SearchUnit), GetUnitIndicatorString(condition.TargetUnit));
	elseif cls.name == 'UnitInsightEachOther' then
		msg = string.format('\\[ ◎ %s \\] - 유닛1: %s, Unit2: %s', cls.Desc, GetUnitIndicatorString(condition.Unit), GetUnitIndicatorString(condition.Unit2));
	elseif cls.name == 'AnyUnitInsightToTeam' then
		msg = string.format('\\[ ◎ %s \\] - 발견 팀: %s ▶▶▶ 발각 대상: %s', cls.Desc, condition.Team, GetAnyUnitIndicatorString(condition.AnyUnit));
	elseif cls.name == 'AnyUnitInsightToUnit' then
		msg = string.format('\\[ ◎ %s \\] - 발견 대상: %s ▶▶▶ 발각 대상: %s', cls.Desc, GetUnitIndicatorString(condition.SearchUnit), GetAnyUnitIndicatorString(condition.AnyUnit));
	elseif cls.name == 'TeamInsightToTeam' then
		msg = string.format('\\[ ◎◎ %s \\] - 발견 팀: %s ▶▶▶ 발각 팀: %s', cls.Desc, condition.Team2, condition.Team);
	elseif cls.name == 'TeamInsightToUnit' then
		local checkEachOther = '사용 안함';
		if StringToBool(condition.CheckEachOther) then
			checkEachOther = '사용함';
		end
		msg = string.format('\\[ ◎◎ %s \\] - 발견 대상: %s\n ▶▶▶ 발각 팀: %s, 서로 시야 체크: %s', cls.Desc, GetUnitIndicatorString(condition.Unit), condition.Team, checkEachOther);
	elseif cls.name == 'TeamBuffState' then
		msg = string.format('\\[ ♤ %s \\]\\[ 팀: %s \\] - %s %s %s', cls.Desc, condition.Team, condition.BuffName, OperationToString(condition.Operation), tostring(condition.Value));
	elseif cls.name == 'TeamArrivedVisualArea' then
		msg = string.format('\\[ ◎ %s \\]\\[ 팀: %s \\] ▷▷▷ 영역: %s', cls.Desc, condition.Team, condition.VisualArea);
	elseif cls.name == 'TeamLeftVisualArea' then
		msg = string.format('\\[ ◎ %s \\]\\[ 팀: %s \\] ◁◁◁ 영역: %s', cls.Desc, condition.Team, condition.VisualArea);
	elseif cls.name == 'TeamTurnEnd' then
		msg = string.format('\\[ ♧ %s \\] - 팀: %s', cls.Desc, condition.Team);
	elseif cls.name == 'TeamTurnStart' then
		msg = string.format('\\[ ♧ %s \\] - 팀: %s', cls.Desc, condition.Team);
	elseif cls.name == 'CompanyEvaluatorAll' then
		msg = string.format('\\[ □ %s \\] - 조건: %s', cls.Desc, tostring(condition.SuccessExpression));
	elseif cls.name == 'CompanyEvaluatorCount' then
		msg = string.format('\\[ □ %s \\] - 조건: %s, 회사 수 %s %s', cls.Desc, tostring(condition.SuccessExpression), OperationToString(condition.Operation), tostring(condition.Value));
	elseif cls.name == 'DashboardEvaluator' then
		msg = string.format('\\[ □ %s \\] - 키: %s, 값: %s', cls.Desc, tostring(condition.DashboardKey), tostring(condition.SuccessExpression));
	elseif cls.name == 'ObjectInteractionEvent' then
		msg = string.format('\\[ ▨ %s \\] - 대상: %s', cls.Desc, GetUnitIndicatorString(condition.Unit));
	elseif cls.name == 'ObjectInteractionOccured' then
		msg = string.format('\\[ ▨ %s \\] - 대상: %s', cls.Desc, GetUnitIndicatorString(condition.Unit));
	elseif cls.name == 'UnitAttacked' then
		msg = string.format('\\[ ↘ %s \\] - %s ◀ 팀: %s',cls.Desc,GetUnitIndicatorString(condition.Unit),  condition.Relation);
	elseif cls.name == 'TeamAttacked' then
		msg = string.format('\\[ ↘ %s \\] - 팀: %s', cls.Desc, condition.Team);
	elseif cls.name == 'TeamAttackedToUnit' then
		msg = string.format('\\[ ↘ %s \\] - 팀: %s, 공격자: %s', cls.Desc, condition.Team, GetUnitIndicatorString(condition.Unit));
	elseif cls.name == 'TeamRunIntoBattle' then
		msg = string.format('\\[ ▨ %s \\] - 팀: %s', cls.Desc, condition.Team);
	elseif cls.name == 'UnitHPTest' then
		msg = string.format('\\[ ↘ %s \\]\\[ %s \\] - 현재 체력 %s 최대 체력 %s%%', cls.Desc, GetUnitIndicatorString(condition.Unit), OperationToString(condition.Operation), tostring(condition.Value));
	elseif cls.name == 'UnitCostTest' then
		msg = string.format('\\[ ♧ %s \\]\\[ %s \\] - 현재 코스트 %s 최대 코스트 %s%%', cls.Desc, GetUnitIndicatorString(condition.Unit), OperationToString(condition.Operation), tostring(condition.Value));
	elseif cls.name == 'UnitTurnReached' then
		msg = string.format('\\[ ♧ %s \\]\\[ %s \\] - 턴: %d, 상태: %s', cls.Desc, GetUnitIndicatorString(condition.Unit), condition.TurnCount, condition.TurnState);
	elseif cls.name == 'UnitBuffState' or cls.name == 'UnitBuffStateEvent' then
		local onoff = '비활성화';
		if condition.OnOff == 'On' then
			onoff = '활성화';
		end
		msg = string.format('\\[ ♤ %s \\]\\[ %s \\] - %s %s ', cls.Desc, GetUnitIndicatorString(condition.Unit), condition.BuffName, onoff);
	elseif cls.name == 'UnitTurnEnd' then
		msg = string.format('\\[ ♧ %s  \\] - 대상: %s', cls.Desc, GetUnitIndicatorString(condition.Unit));
	elseif cls.name == 'VariableTest' then
		msg = string.format('\\[ ♬ %s \\] - %s %s %s', cls.Desc, condition.Variable, OperationToString(condition.Operation), tostring(condition.Value));
	elseif cls.name == 'VariableToVariableTest' then
		msg = string.format('\\[ ♬ %s \\] - %s %s %s', cls.Desc, condition.Variable, OperationToString(condition.Operation), condition.Variable2);
	elseif cls.name == 'VariableTestInstant' then
		msg = string.format('\\[ ♬ %s \\] - %s %s %s', cls.Desc, condition.Variable, OperationToString(condition.Operation), tostring(condition.Value));
	elseif cls.name == 'UnitTurnStart' then
		msg = string.format('\\[ ♧ %s \\] - 대상: %s', cls.Desc, GetUnitIndicatorString(condition.Unit));
	elseif cls.name == 'TeamArrivedEscapeArea' then
		msg = string.format('\\[ ▨ %s \\] - 팀: %s', cls.Desc, condition.Team);
	elseif cls.name == 'TeamAllEscaped' then
		msg = string.format('\\[ ◎ %s \\] - 팀: %s', cls.Desc, condition.Team);
	elseif cls.name == 'FieldEffectAdded' then
		msg = string.format('\\[ ▨ %s \\] - 지형 효과: %s', cls.Desc, condition.FieldEffectName);
	elseif cls.name == 'UnitStateTest' then
		msg = string.format('\\[ ▨ %s \\]\\[ %s \\] - %s', cls.Desc, GetUnitIndicatorString(condition.Unit), tostring(condition.TestExpression));
	elseif cls.name == 'UnitBattleStateTest' then
		local battleState = '비전투 상태';
		if StringToBool(condition.BattleState, true) then
			battleState = '전투 상태';
		end
		msg = string.format('\\[ ▨ %s \\]\\[ %s \\] - %s', cls.Desc, GetUnitIndicatorString(condition.Unit), battleState);
	elseif cls.name == 'NoEnemyToTeam' then
		msg = string.format('\\[ ◎&♨ %s \\] - 팀: %s', cls.Desc, condition.Team);
	elseif cls.name == 'DifficultyTest' then
		msg = string.format('\\[ %s \\] - %s', cls.Desc, (condition.DifficultyType and GetClassList('GameDifficulty')[condition.DifficultyType].Title) or 'nil');
	elseif cls.name == 'ChallengerTest' then
		msg = string.format('\\[ %s \\]', cls.Desc);
	elseif cls.name == 'ActionDelimiter' then
		msg = string.format('\\[ ♧ %s \\]', cls.Desc);
	elseif cls.name == 'TeamArrivedUnitCountTest' then
		msg = string.format('\\[ ◎ %s \\]\\[팀: %s \\] ▷▷▷ 영역: %s 비교: %s, 값 %s', cls.Desc, condition.Team, GetAreaIndicatorString(condition.AreaIndicator), OperationToString(condition.Operation), tostring(condition.Value));
	elseif cls.name == 'TeamItemAcquired' then
		msg = string.format('\\[ ◎ %s \\]\\[팀: %s \\] 아이템: %s', cls.Desc, condition.Team, condition.ItemType);
	else
		msg = cls.Desc;
	end
	
	-- 컨디션 아웃풋.
	local conditionOutPutList = GetClassList('ConditionOutputDataType');
	for key, value in pairs (conditionOutPutList) do
		if condition.ConditionOutput then
			if condition.ConditionOutput[1] then
				local outputkey = condition.ConditionOutput[1][key];
				if outputkey and outputkey ~= '' then
					msg = string.format('%s\n└ \\[ ◈ 아웃풋 \\] - %s: %s', msg, key, outputkey);
				end
			end
		end
	end
	
	local filter = condition.ConditionFilter;
	-- nil , true, '' string
	if filter ~= nil and filter ~= '' then
		msg = string.format('%s\n└ \\[ ♬ 필터 \\] - %s', msg, tostring(filter));
	end	
	return msg;
end

function ActionCaptionInitializer(cls, action)
	--LogAndPrint('ActionCaptionInitializer - cls.name : ', cls.name);
	local dumpStr = PackTableToStringReadable(action);
	--LogAndPrint('ActionCaptionInitializer - action : ', dumpStr);

	if cls.name == 'MissionDirect' then
		return string.format('\\[ ☆ %s \\] - %s', cls.Title, action.DirectType);
	elseif cls.name == 'AcquireMastery' then
		return string.format('\\[ ▧ %s \\]\\[ %s \\] - %s (%s)', cls.Title, action.Team, action.Mastery, action.Count);
	elseif cls.name == 'UpdateDashboard' then
		return string.format('\\[ □ %s \\] -  %s ▶▶▶ %s', cls.Title, action.DashboardKey, table.concat(table.map(action.Command, function (c) return c.Value; end), ', '));
	elseif cls.name == 'UpdateStageVariable' then
		return string.format('\\[ ▶ %s \\] %s = %s', cls.Title or 'nil',  action.Variable or 'nil', tostring(action.Value));
	elseif cls.name == 'UpdateStageVariableEx' then
		return string.format('\\[ ▶ %s \\] %s = %s', cls.Title or 'nil', action.Variable or 'nil', string.gsub(string.gsub(GetStageDataBindingString(action.StageDataBinding), '%[', '\\%['), '%]', '\\%]'));
	elseif cls.name == 'RandomUpdateStageVariable' then
		return string.format('\\[ ▶ %s \\] %s = math.random( %s, %s )', cls.Title, action.Variable, tostring(action.Value), tostring(action.Value2));
	elseif cls.name == 'CustomFunction' then
		return string.format('\\[ ▧ %s \\] - %s, %s', cls.Title, tostring(action.Value), tostring(action.Value2));
	elseif cls.name == 'TurnEnd' then
		return string.format('\\[ ▧ %s \\] - %s', cls.Title, GetUnitIndicatorString(action.Unit));
	elseif cls.name == 'ExcludeUnit' then
		return string.format('\\[ ▧ %s \\] - %s', cls.Title, GetUnitIndicatorString(action.Unit));
	elseif cls.name == 'AddObjectProperty' then
		return string.format('\\[ △ %s \\] - 대상: %s, 키: %s, 값: %s', cls.Title,
			GetUnitIndicatorString(action.Unit), action.PropKV[1].Key, tostring(action.PropKV[1].Value));
	elseif cls.name == 'UpdateObjectProperty' then
		return string.format('\\[ ▶ %s \\] - 대상: %s, 키: %s, 값: %s', cls.Title,
			GetUnitIndicatorString(action.Unit), action.PropKV[1].Key, tostring(action.PropKV[1].Value));
	elseif cls.name == 'UpdateObjectPropertyEx' then
		return string.format('\\[ ▶ %s \\] - 대상: %s, 키: %s, 값: %s', cls.Title,
			GetUnitIndicatorString(action.Unit), action.Key, string.gsub(string.gsub(GetStageDataBindingString(action.StageDataBinding), '%[', '\\%['), '%]', '\\%]'));
	elseif cls.name == 'UpdateObjectInstantProperty' then
		return string.format('\\[ ▶ %s \\] - 대상: %s, 키: %s, 값: %s', cls.Title,
			GetUnitIndicatorString(action.Unit), action.PropKV[1].Key, tostring(action.PropKV[1].Value));
	elseif cls.name == 'UpdateObjectPropertyTeam' then
		return string.format('\\[ ▶ %s \\] - 팀: %s, 키: %s, 값: %s, 독립계산: %s', cls.Title,
			action.Team, action.Key, string.gsub(string.gsub(GetStageDataBindingString(action.StageDataBinding), '%[', '\\%['), '%]', '\\%]'), tostring(action.EvalEach));
	elseif cls.name == 'UpdateObjectInstantPropertyTeam' then
		return string.format('\\[ ▶ %s \\] - 팀: %s, 키: %s, 값: %s, 독립계산: %s', cls.Title,
			action.Team, action.Key, string.gsub(string.gsub(GetStageDataBindingString(action.StageDataBinding), '%[', '\\%['), '%]', '\\%]'), tostring(action.EvalEach));
	elseif cls.name == 'ChangeTileEnterable' then
		local onoff = '에러';
		if action.OnOff == 'On' then
			onoff = '활성화';
		elseif action.OnOff == 'Off' then
			onoff = '비활성화';
		end
		return string.format('\\[ ▧ %s \\]\\[ %s \\] - %s', cls.Title, onoff, AreaToString(action.Area[1]));
	elseif cls.name == 'ChangeTileEnterableEx' then
		local onoff = '에러';
		if action.OnOff == 'On' then
			onoff = '활성화';
		elseif action.OnOff == 'Off' then
			onoff = '비활성화';
		end
		return string.format('\\[ ▧ %s \\]\\[ %s \\] - %s', cls.Title, onoff, GetAreaIndicatorString(action.AreaIndicator));
	elseif cls.name == 'ChangeTileLink' then
		local infoStr = '';
		for _, key in ipairs({ 'Link', 'Visible', 'Throwing' }) do
			local value = action['Update'..key];
			if value and value ~= 'Cancel' then
				local onoff = '에러';
				if value == 'On' then
					onoff = '활성화';
				elseif value == 'Off' then
					onoff = '비활성화';
				end
				if infoStr ~= '' then
					infoStr = infoStr..', ';
				end
				infoStr = infoStr..string.format('%s: %s', key, onoff);
			end
		end
		return string.format('\\[ ▧ %s \\] - %s\n     └ %s', cls.Title, AreaToString(action.Area[1]), infoStr);
	elseif cls.name == 'ChangeTileLinkEx' then
		local infoStr = '';
		for _, key in ipairs({ 'Link', 'Visible', 'Throwing' }) do
			local value = action['Update'..key];
			if value and value ~= 'Cancel' then
				local onoff = '에러';
				if value == 'On' then
					onoff = '활성화';
				elseif value == 'Off' then
					onoff = '비활성화';
				end
				if infoStr ~= '' then
					infoStr = infoStr..', ';
				end
				infoStr = infoStr..string.format('%s: %s', key, onoff);
			end
		end
		return string.format('\\[ ▧ %s \\] - %s\n     └ %s', cls.Title, GetAreaIndicatorString(action.AreaIndicator), infoStr);
	elseif cls.name == 'ChangeAI' then
		local ai = action.AIForm[1];
		local areaType = '';
		if ai.ActivityArea then
			areaType = AreaToString(ai.ActivityArea[1]);
		end
		return string.format('\\[ ▧ %s \\] - %s ▶▶▶ %s\n     └ 활동구역: %s\n     └ 랠리포인트(1): %s ▷ 영향력: %s, 범위 %s\n     └ 랠리포인트(2): %s ▷ 영향력: %s, 범위 %s', 
			cls.Title, GetUnitIndicatorString(action.Unit), ai.AIType, 
			areaType,
			GetPositionIndicatorString(ai.RallyPoint), tostring(ai.RallyPower), tostring(ai.RallyRange),
			GetPositionIndicatorString(ai.RallyPoint2), tostring(ai.RallyPower2), tostring(ai.RallyRange2)			
		);
	elseif cls.name == 'ChangeTeam' then
		return string.format('\\[ ▧ %s \\] - %s ▶▶▶ %s, 연출: %s', cls.Title, GetUnitIndicatorString(action.Unit), action.Team, action.ChangeTeamDirect or 'Main');
	elseif cls.name == 'Win' then
		return string.format('\\[ ▧ %s \\] - %s ', cls.Title, action.Team);
	elseif cls.name == 'SightSharing' then
		local sight = '해제';
		if StringToBool(action.Visible) then
			sight = '공유';
		end
		return string.format('\\[ ▧ %s \\]\\[ %s \\] - 대상팀: %s, 유닛: %s', cls.Title, sight, action.Team, GetUnitIndicatorString(action.Unit));
	elseif cls.name == 'DisableInteraction' then
		return string.format('\\[ ▧ %s \\] - %s', cls.Title, action.InteractionUnit);
	elseif cls.name == 'ToggleTrigger' then
		local onoff = '에러';
		if action.OffOn == 'On' then
			onoff = '활성화';
		elseif action.OffOn == 'Off' then
			onoff = '비활성화';
		end
		return string.format('\\[ ▧ %s \\]\\[ %s \\] - %s', cls.Title, onoff, action.Trigger);
	elseif cls.name == 'ToggleTriggerGroup' then
		local onoff = '에러';
		if action.OffOn == 'On' then
			onoff = '활성화';
		elseif action.OffOn == 'Off' then
			onoff = '비활성화';
		end
		return string.format('\\[ ▧ %s \\]\\[ %s \\] - %s', cls.Title, onoff, action.TriggerGroup);
	elseif cls.name == 'ToogleRewardWhenResurrect' then
		local onoff = '에러';
		if action.OnOff == 'On' then
			onoff = '활성화';
		elseif action.OnOff == 'Off' then
			onoff = '비활성화';
		end
		return string.format('\\[ ▧ %s \\]\\[ %s \\] - %s', cls.Title, onoff, GetUnitIndicatorString(action.Unit));
	elseif cls.name == 'ResetAbilityCooldown' then
		return string.format('\\[ ▧ %s \\] - 대상: %s, 어빌리티: %s', cls.Title, GetUnitIndicatorString(action.Unit), action.Ability);
	elseif cls.name == 'ResetAbilityCooldownAll' then
		return string.format('\\[ ▧ %s \\] - 대상: %s', cls.Title, GetUnitIndicatorString(action.Unit));
	elseif cls.name == 'ResetAbilityUseCount' then
		return string.format('\\[ ▧ %s \\] - 대상: %s, 어빌리티: %s', cls.Title, GetUnitIndicatorString(action.Unit), action.Ability);
	elseif cls.name == 'ResetAbilityUseCountAll' then
		return string.format('\\[ ▧ %s \\] - 대상: %s', cls.Title, GetUnitIndicatorString(action.Unit));
	elseif cls.name == 'RestoreMaxCost' then
		return string.format('\\[ ▧ %s \\] - 대상: %s', cls.Title, GetUnitIndicatorString(action.Unit));
	elseif cls.name == 'ResetSP' then
		return string.format('\\[ ▧ %s \\] - 대상: %s', cls.Title, GetUnitIndicatorString(action.Unit));
	elseif cls.name == 'RestoreMaxSP' then
		return string.format('\\[ ▧ %s \\] - 대상: %s', cls.Title, GetUnitIndicatorString(action.Unit));
	elseif cls.name == 'RestoreMaxHP' then
		return string.format('\\[ ▧ %s \\] - 대상: %s', cls.Title, GetUnitIndicatorString(action.Unit));
	elseif cls.name == 'ResetObject' then
		return string.format('\\[ ▧ %s \\] - 대상: %s', cls.Title, GetUnitIndicatorString(action.Unit));
	elseif cls.name == 'UpdateUserMember' then
		local onoff = '에러';
		if action.OnOff == 'On' then
			onoff = '추가';
		elseif action.OnOff == 'Off' then
			onoff = '해제';
		end
		return string.format('\\[ ▧ %s \\]\\[ %s \\] - 대상: %s, 팀: %s', cls.Title, onoff, GetUnitIndicatorString(action.Unit), action.Team);
	elseif cls.name == 'UpdateAutoPlayable' then
		return string.format('\\[ ▧ %s \\]\\[ %s \\] - 대상: %s', cls.Title, action.OnOff, GetUnitIndicatorString(action.Unit));
	elseif cls.name == 'GiveAbility' then
		return string.format('\\[ ▧ %s \\] - 대상: %s ▶▶▶ 어빌리티: %s', cls.Title, GetUnitIndicatorString(action.Unit), action.Ability);
	elseif cls.name == 'GiveInteractionAbility' then
		return string.format('\\[ ▧ %s \\] - 대상: %s', cls.Title, GetUnitIndicatorString(action.Unit));
	elseif cls.name == 'ClearFieldEffect' then
		return string.format('\\[ ▧ %s \\] - 지형효과: %s', cls.Title, action.FieldEffectType);
	elseif cls.name == 'ClearFieldEffectAll' then
		return string.format('\\[ ▧ %s \\]', cls.Title);
	elseif cls.name == 'UpdateFieldEffect' then
		local onoff = '에러';
		if action.OnOff == 'On' then 
			onoff = '추가';
		elseif action.OnOff == 'Off' then
			onoff = '해제';
		end
		return string.format('\\[ ▧ %s \\]\\[ %s \\] - 지형효과: %s, 좌표: %s', cls.Title, onoff, action.FieldEffectType, AreaToString(action.Area[1]));
	elseif cls.name == 'UnitAddBuff' then
		return string.format('\\[ ♤ %s \\] - 대상: %s, 버프: %s, 레벨: %s', cls.Title, GetUnitIndicatorString(action.Unit), action.Name, tostring(action.Value));
	elseif cls.name == 'UnitRemoveBuff' then
		return string.format('\\[ ♤ %s \\] - 대상: %s, 버프: %s', cls.Title, GetUnitIndicatorString(action.Unit), action.Name);
	elseif cls.name == 'UnitRemoveBuffAll' then
		return string.format('\\[ ♤ %s \\] - 대상: %s', cls.Title, GetUnitIndicatorString(action.Unit));
	elseif cls.name == 'ChangeTeamAI' then
		return string.format('\\[ ♤ %s \\] - 팀: %s', cls.Title, action.Team);
	elseif cls.name == 'SightTeamAddBuff' then
		return string.format('\\[ ♤ %s \\] - 대상: %s, 팀: %s, 버프: %s, 레벨: %s', cls.Title, GetUnitIndicatorString(action.Unit), action.Team, action.Name, tostring(action.Value));
	elseif cls.name == 'TeamAddBuff' then
		return string.format('\\[ ♤ %s \\] - 팀: %s, 버프: %s, 레벨: %s%s', cls.Title, action.Team, action.Name, tostring(action.Value), StringToBool(action.OnFieldOnly) and ', Invalid 위치 제외' or '');
	elseif cls.name == 'TeamRemoveBuff' then
		return string.format('\\[ ♤ %s \\] - 팀: %s, 버프: %s', cls.Title, action.Team, action.Name);
	elseif cls.name == 'TeamRemoveBuffAll' then
		return string.format('\\[ ♤ %s \\] - 팀: %s', cls.Title, action.Team);
	elseif cls.name == 'TeamChangeTeam' then
		return string.format('\\[ ▧ %s \\] 팀: %s ▶▶▶ %s, 연출: %s', cls.Title, action.Team, action.Team2, action.ChangeTeamDirect or 'Main');
	elseif cls.name == 'TeamUpdateUserMember' then
		local onoff = '에러';
		if action.OnOff == 'On' then
			onoff = '추가';
		elseif action.OnOff == 'Off' then
			onoff = '해제';
		end
		return string.format('\\[ ▧ %s \\]\\[ %s \\] - 팀: %s ▶▶▶ %s', cls.Title, onoff, action.Team, action.Team2);
	elseif cls.name == 'AddCompanyProperty' then
		return string.format('\\[ △ %s \\]\\[ %s \\] += %s', cls.Title, tostring(action.PropKV[1].Key), tostring(action.PropKV[1].Value));
	elseif cls.name == 'UpdateCompanyProperty' then
		return string.format('\\[ ▶ %s \\]\n└ %s == %s', cls.Title, tostring(action.PropKV[1].Key), tostring(action.PropKV[1].Value));
	elseif cls.name == 'AddStageVariable' then
		return string.format('\\[ △ %s \\]\\[ %s \\] += %s', cls.Title,  action.Variable, tostring(action.Value));
	elseif cls.name == 'CheckPoint' then
		local actionInstance = SafeIndex(action, 'ActionInstance', 1);
		if actionInstance and actionInstance.ActionType and actionInstance.ActionType ~= 'None' then
			local subActionCls = GetClassList('Action')[actionInstance.ActionType];
			return string.format('\\[ ☆ %s \\]\n          └ %s', cls.Title, ActionCaptionInitializer(subActionCls, actionInstance));
		else
			return string.format('\\[ ☆ %s \\]', cls.Title);
		end
	elseif cls.name == 'KillObject' then
		return string.format('\\[ ▧ %s \\] - 대상: %s', cls.Title,  GetUnitIndicatorString(action.Unit));
	elseif cls.name == 'HideObject' then
		return string.format('\\[ ▧ %s \\] - 대상: %s', cls.Title,  GetUnitIndicatorString(action.Unit));
	elseif cls.name == 'HideObjectTeam' then
		return string.format('\\[ ▧ %s \\] - 팀: %s', cls.Title, action.Team);
	elseif cls.name == 'ShowObject' then
		return string.format('\\[ ▧ %s \\] - 대상: %s', cls.Title,  GetUnitIndicatorString(action.Unit));
	elseif cls.name == 'ShowObjectTeam' then
		return string.format('\\[ ▧ %s \\] - 팀: %s', cls.Title, action.Team);
	elseif cls.name == 'UnitMove' then
		local pos = string.format('%d,%d,%d', action.Position[1].x, action.Position[1].y, action.Position[1].z);
		return string.format('\\[ ▧ %s \\] - 대상: %s, 위치: %s ', cls.Title,  GetUnitIndicatorString(action.Unit),  pos);
	elseif cls.name == 'UnitSetPos' then
		local pos = string.format('%d,%d,%d', action.Position[1].x, action.Position[1].y, action.Position[1].z);
		return string.format('\\[ ▧ %s \\] - 대상: %s, 위치: %s ', cls.Title,  GetUnitIndicatorString(action.Unit), pos);
	elseif cls.name == 'UpdateObjectState' then
		local ret = string.format('\\[ ▧ %s \\] - 대상: %s', cls.Title, GetUnitIndicatorString(action.Unit));
		for i = 2, #cls.ArgumentList do
			local argCls = cls.ArgumentList[i];
			local propName = argCls.name;
			local propValue = action[propName];
			if propValue == 'On' then
				ret = ret .. string.format('\n└ %s = %s', propName, 'true');
			elseif propValue == 'Off' then
				ret = ret .. string.format('\n└ %s = %s', propName, 'false');
			end
		end
		return ret;
	elseif cls.name == 'UpdateSteamAchievement' then
		local onoff = '에러';
		if action.OnOff == 'On' then 
			onoff = '달성';
		elseif action.OnOff == 'Off' then
			onoff = '해제';
		end
		return string.format('\\[ ☆ %s \\]\\[ %s \\] - 업적: %s', cls.Title, onoff, action.SteamAchievement);
	elseif cls.name == 'AddSteamStat' then
		return string.format('\\[ △ %s \\]\\[ %s \\] += %s', cls.Title, action.SteamStat, tostring(action.Value));
	elseif cls.name == 'UpdateSteamStat' then
		return string.format('\\[ ▶ %s \\]\\[ %s \\] = %s', cls.Title, action.SteamStat, tostring(action.Value));
	elseif cls.name == 'ToggleInteractionArea' then
		return string.format('\\[%s\\] %s %s', cls.Title, action.InteractionAreaKey, action.OffOn);
	elseif cls.name == 'UpdateEquipment' then
		return string.format('\\[ ▧ %s \\]\\[ %s \\] - %s', cls.Title, GetUnitIndicatorString(action.Unit), GetItemIndicatorString(action.Item));
	elseif cls.name == 'MonsterLocator' then
		local unitqueUnits = table.distinct(table.flatten(table.map(action.LocatorCandidate[1].Candidate, function(candidate)
			return table.map(candidate.UnitWithPosList[1].Entry, function(entry)
				return GetUnitIndicatorString(entry.Unit);
			end);
		end)));
		table.sort(unitqueUnits);
		return string.format('\\[%s\\]\n└ %s', cls.Title, table.concat(unitqueUnits, '\n└ '));
	elseif cls.name == 'ToggleKillReward' then
		local rewardMode = '에러';
		if action.RewardMode == 'On' then
			rewardMode = '활성화';
		elseif action.RewardMode == 'Off' then
			rewardMode = '비활성화';
		elseif action.RewardMode == 'Mastery' then
			rewardMode = '특성만';
		end
		return string.format('\\[ ▧ %s \\]\\[ %s \\]', cls.Title, rewardMode);
	elseif cls.name == 'ToggleDeadPenalty' then
		local onoff = '비활성화';
		if action.OnOff == 'On' then
			onoff = '활성화';
		end
		return string.format('\\[ ▧ %s \\]\\[ %s \\]', cls.Title, onoff);
	elseif cls.name == 'ToggleAssistMap' then
		local onoff = '비활성화';
		if action.OnOff == 'On' then
			onoff = '활성화';
		end
		return string.format('\\[ ▧ %s \\]\\[ %s \\]', cls.Title, onoff);
	elseif cls.name == 'ProgressQuest' then
		return string.format('\\[ ☆ %s \\]\\[ %s (%s) \\]', cls.Title, SafeIndex(GetClassList('Quest')[action.Quest], 'Title') or 'Error', action.Quest);
	elseif cls.name == 'ReplaceMonster' then
		return string.format('\\[ ▧ %s \\]\\[ %s \\]-> \\[ %s \\]', cls.Title, GetUnitIndicatorString(action.Unit), action.Object);
	elseif cls.name == 'UpdateConditionOutput' then
		local envStrList = {};
		for _, var in ipairs(SafeIndex(action, 'Env', 1, 'Variable') or {}) do
			local envStr = string.format('\n└ %s = %s', var.Name, GetStageDataBindingString(var.StageDataBinding));
			table.insert(envStrList, envStr);
		end
		return string.format('\\[ ▶ %s \\]%s', cls.Title, table.concat(envStrList, ''));
	elseif cls.name == 'GiveItem' then
		return string.format('\\[ ▶ %s \\] - 대상: %s, 아이템: %s', cls.Title, GetUnitIndicatorString(action.Unit), GetOpenRewardString(action.OpenReward_GiveItem));
	elseif cls.name == 'TeamDistribute' then
		return string.format('\\[ ▧ %s \\] - 팀: \\[%s\\] 영역: (%s)', cls.Title, action.Team, GetAreaIndicatorString(action.AreaIndicator));
	elseif cls.name == 'CallActionBundle' then
		local actionBundle = SafeIndex(action.ActionBundle, 1) or {};
		local funcData = GetStageFunctionDetail(actionBundle.Type);
		local paramText = '';
		if funcData then
			paramText = '(' .. (Linq.new(table.deepcopy(funcData.Parameter))
				:select(function(p) return string.format('%s(%s)', p.Name, GetClassList('StageValueIndicators')[p.DataType].Title) end)
				:concat(',')) .. ')';
			for _, p in ipairs(funcData.Parameter) do
				local argData = actionBundle[p.Name];
				local argText = '';
				if p.DataType == 'Position' then
					argText = GetPositionIndicatorString(argData);
				elseif p.DataType == 'Unit' then
					argText = GetUnitIndicatorString(argData);
				elseif p.DataType == 'Units' then
					argText = GetAnyUnitIndicatorString(argData);
				elseif p.DataType == 'Item' then
					argText = GetItemIndicatorString(argData);
				elseif p.DataType == 'Dashboard' then
					argText = GetDashboardIndicatorString(argData);
				elseif p.DataType == 'Area' then
					argText = GetAreaIndicatorString(argData);
				elseif p.DataType == 'Value' then
					argText = GetStageDataBindingString(argData);
				elseif p.DataType == 'Text' then
					argText = GetStageTextBindingString(argData);
				else
					argText = argData;
				end
				paramText = paramText .. string.format('\n - %s: %s', p.Name, argText);
			end
		end
		return string.format('\\[ ☆ %s \\] - 함수: %s%s', cls.Title, actionBundle.Type, paramText);
	elseif cls.name == 'Switch' then
		local textSeldialog = string.format('\\[ ♤ 선택 분기 \\]\\[ 조건 : %s \\]', action.TestExpression);				
		for i, caseEntry in ipairs(action.CaseDefinition[1].Case) do
			textSeldialog = textSeldialog..string.format('\n   └ \\[ %s == %s \\]', tostring(action.TestExpression), tostring(caseEntry.CaseValue));
			local curActionList = SafeIndex(caseEntry, 'ActionList', 1, 'Action');
			if curActionList and #curActionList > 0  then
				for j = 1, #curActionList do
					local curAction = curActionList[j];
					if curAction.Type then
						local cls = GetClassList('Action')[curAction.Type];
						textSeldialog = textSeldialog..'\n              └ '..ActionCaptionInitializer(cls, curAction);
					end
				end
			end
		end
		return textSeldialog;
	end
	
	return cls.Title;
end

BattleFormulaComposer = {}
function BattleFormulaComposer.new(formula, factors)
	local bfc = {DecompData = {}, Composer = {math=math}, Formula = loadstring('return ' .. formula), FactorOrder = {}};
	setmetatable(bfc.Composer, {__index = function(t, key) return SafeIndex(bfc, 'DecompData', key, 'Value') or 0; end;});
	if bfc.Formula == nil then
		LogAndPrint('BattleFormulaComposer.new - formula:', formula);
		Traceback();
	end
	setfenv(bfc.Formula, bfc.Composer);
	setmetatable(bfc, {__index = BattleFormulaComposer});
	if factors then
		for _, factor in ipairs(factors) do
			bfc:RegisterDecompFactor(factor);
		end
	end
	return bfc;
end
function BattleFormulaComposer.RegisterDecompFactor(self, factor)
	self.DecompData[factor] = {Value = 0, Info = {}};
	table.insert(self.FactorOrder, factor);
end
function BattleFormulaComposer.AddDecompData(self, factor, value, infoList)
	if self.DecompData[factor] == nil then
		self:RegisterDecompFactor(factor);
	end
	self.DecompData[factor].Value = self.DecompData[factor].Value + value;
	table.append(self.DecompData[factor].Info, infoList);
end
function BattleFormulaComposer.ComposeFormula(self)
	setfenv(self.Formula, self.Composer);
	return math.floor(self.Formula());
end
function BattleFormulaComposer.ComposeInfoTable(self)
	local final = self:ComposeFormula();
	local retInfo = {};
	-- 값을 모두 초기화
	for factor, decompElement in pairs(self.DecompData) do
		decompElement.OriginalValue = decompElement.Value;
		decompElement.Value = 0;
	end
	local currentValue = self:ComposeFormula();
	for _, factor in ipairs(self.FactorOrder) do
		local decompElement = self.DecompData[factor];
		--LogAndPrint('BattleFormulaComposer.ComposeInfoTable', 'new factor', factor);
		for _, info in ipairs(decompElement.Info) do
			decompElement.Value = decompElement.Value + info.Value;
			local changed = self:ComposeFormula();
			--LogAndPrint('BattleFormulaComposer.ComposeInfoTable', _, factor, info.Type, changed, currentValue, changed - currentValue);
			info.Value = changed - currentValue;
			currentValue = changed;
			table.insert(retInfo, info);
		end
		decompElement.Value = decompElement.OriginalValue;
		currentValue = self:ComposeFormula();
	end
	return retInfo;
end
function BattleFormulaComposer.Reset(self)
	for _, data in pairs(self.DecompData) do
		data.Value = 0;
		data.Info = {};
	end
end
function BattleFormulaComposer.Clone(self)
	local bfc = {DecompData = {}, Composer = {math=math}, Formula = self.Formula, FactorOrder = {}};
	setmetatable(bfc.Composer, {__index = function(t, key) return SafeIndex(bfc, 'DecompData', key, 'Value') or 0; end;});
	setmetatable(bfc, {__index = BattleFormulaComposer});
	for _, factor in ipairs(self.FactorOrder) do
		bfc:RegisterDecompFactor(factor);
	end
	return bfc;
end
function BattleFormulaComposer.Merge(self, target)
	for factor, data in pairs(target.DecompData) do
		if self.DecompData[factor] == nil then
			self:RegisterDecompFactor(factor);
		end
		self.DecompData[factor].Value = self.DecompData[factor].Value + data.Value;
		--LogAndPrint('BattleFormulaComposer.Merge', factor, data.Info);
		table.append(self.DecompData[factor].Info, table.map(data.Info, function(info) return table.deepcopy(info); end));
	end
end

--테스트 코드
--[[
damageDecomp = BattleFormulaComposer.new('((Base + Add) * (1 + Mult) - Defence) * (1 + FinalMultiplier)');
damageDecomp:AddDecompData('Base', 200, {{Key = 'Base', Value = 200}});
damageDecomp:AddDecompData('Add', 37, {{Key = 'Add', Value = 37}});
damageDecomp:AddDecompData('Mult', 0.2, {{Key = 'Mult', Value = 0.2}});
damageDecomp:AddDecompData('Mult', 0.1, {{Key = 'Mult2', Value = 0.1}});
damageDecomp:AddDecompData('Defence', 75, {{Key = 'Defence', Value = 75}});
damageDecomp:AddDecompData('FinalMultiplier', 0.25, {{Key = 'FinalMultiplier', Value = 0.25}});
x = damageDecomp:Clone();
x:Reset();
x:AddDecompData('Base', 53, {{Key = 'Base2', Value = 53}});
x:AddDecompData('Mult', 0.2, {{Key = 'Mult3', Value = 0.2}});
damageDecomp:Merge(x);
LogAndPrint(damageDecomp:ComposeFormula(), damageDecomp:ComposeInfoTable(), x:ComposeFormula(), x:ComposeInfoTable());
]]

function GetAbilityUsingPosition(obj)
	return GetInstantProperty(obj, 'AbilityPrevPosition') or GetPosition(obj);
end
function SetObjetProfileImage(win, objInfo)
	local image = objInfo.Image;
	if objInfo.Image_Small ~= 'None' then
		local isChange = false;
		local pos = win:getOuterRectClipper();
		local winWidth = pos.max.x - pos.min.x;
		local winHeight = pos.max.y - pos.min.y;
		local curSize = math.min(winWidth,winHeight);
		if curSize <= 64 then
			image = objInfo.Image_Small;
		end
	end
	win:setProperty('Image', image);
end

function GetUnitDebugName(object)
	if object == nil then
		return 'nil';
	else
		local idspace = GetIdspace(object);
		if idspace == nil then
			return string.format('%s:%s', type(object), tostring(object));
		elseif idspace ~= 'Object' then
			return string.format('%s:%s', GetIdspace(object), tostring(object));
		else
			return string.format('%s:%s', object.name, GetObjKey(object));
		end
	end
end

function SetInstantPropertyWithUpdate(obj, key, value)
	SetInstantProperty(obj, key, value);
	local updateTarget = GetInstantProperty(obj, 'UPDATE_TARGET') or {};
	updateTarget[key] = true;
	SetInstantProperty(obj, 'UPDATE_TARGET', updateTarget);
end

function IsLongDistanceAttack(ability)
	return ability.HitRateType ~= 'Melee';
end