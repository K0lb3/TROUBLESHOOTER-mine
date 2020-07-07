function PlayMissionDirect(mid, ds, conditionOutput, directType, beginHide, endShow)
	local missionDirectInfo = GetMissionDirectInfo(mid, directType);
	LogAndPrint('MissionDirect', directType, GetMissionGID(mid));

	if missionDirectInfo == nil then
		LogAndPrint(string.format("[DataError] [%s]'s missionDirect is nil!", directType));
		return;
	end
	PlayMissionDirect_Internal(mid, ds, conditionOutput, missionDirectInfo, 'PlayMissionDirect', beginHide, endShow);
end

function PlayMissionDirect_Internal(mid, ds, conditionOutput, missionDirectInfo, debugKey, beginHide, endShow)
	ds:StartMissionDirect(StringToBool(beginHide, true));
	
	local tableID = {};
	for i = 1, #missionDirectInfo.Action do
		local action = missionDirectInfo.Action[i];
		local actionType = action.Type or 'Error';
		tableID[action.ActionKey] = _G['MissionDirect_'..actionType](mid, ds, action, conditionOutput);
		if action.Connect ~= nil then
			if tableID[action.Connect] == nil then
				LogAndPrint(action.Connect);
				LogAndPrint(string.format("[DataError] [%s] :: ActionKey not exist on [%s] :: MissionDirect.xml!", action.Connect, debugKey or 'unknown'));
				return;
			end
			if tableID[action.ActionKey] == nil then
				LogAndPrint(string.format("[DataError] [%s] :: ActionKey not exist on [%s] :: MissionDirect.xml!", action.ActionKey, debugKey or 'unknown'));
				return;
			end
			if not action.ConnectFrame then
				LogAndPrint('action.ConnectFrame is nil',  action.ActionKey);
			end
			local connectTime = action.ConnectFrame / 30;
			if connectTime < 0 then
				-- -1은 그대로 -1로 넣어야함
				connectTime = -1;
			end
			if tableID[action.ActionKey] ~= -1 and tableID[action.Connect] ~= -1 then
				ds:Connect(tableID[action.ActionKey], tableID[action.Connect], connectTime);
			end
		end
	end
	ds:EndMissionDirect(StringToBool(endShow, true));
	--ds:MissionDirectBlocker();
end

function GetDialogTestAllowActionSet()
	local dialogTestAllowActionSet = _G['g_dialogTestAllowActionSet'];
	if not dialogTestAllowActionSet then
		local dialogTestAllowActionList = {
			'Dialog', 'DialogBattle', 'SelDialog', 'SelDialogBattle', 'DialogSystemMessageBox', 'HelpMessage', 'TitleMessage', 'Subtitle', 'SystemMessage', 'ShowFrontmessage', 'ShowFrontmessageFormat'
		};
		
		dialogTestAllowActionSet = {};
		for _, actionType in ipairs(dialogTestAllowActionList) do
			dialogTestAllowActionSet[actionType] = true;
		end
		_G['g_dialogTestAllowActionSet'] = dialogTestAllowActionSet;
	end
	return dialogTestAllowActionSet;
end

function PlayMissionDirect_DialogTest(mid, ds, missionDirectInfo)
	ds:StartMissionDirect(true);
	
	local conditionOutput = {};
	local dialogTestAllowActionSet = GetDialogTestAllowActionSet();
	
	local tableID = {};
	for i = 1, #missionDirectInfo.Action do
		local action = missionDirectInfo.Action[i];
		local actionType = action.Type or 'Error';
		local actionID = nil;
		if dialogTestAllowActionSet[actionType] then
			actionID = _G['MissionDirect_'..actionType](mid, ds, action, conditionOutput, true);
		else
			actionID = ds:Sleep(0);
		end
		tableID[action.ActionKey] = actionID;
		if action.Connect ~= nil then
			if tableID[action.Connect] == nil then
				LogAndPrint(action.Connect);
				LogAndPrint(string.format("[DataError] [%s] :: ActionKey not exist on [%s] :: MissionDirect.xml!", action.Connect, 'unknown'));
				return;
			end
			if tableID[action.ActionKey] == nil then
				LogAndPrint(string.format("[DataError] [%s] :: ActionKey not exist on [%s] :: MissionDirect.xml!", action.ActionKey, 'unknown'));
				return;
			end
			if not action.ConnectFrame then
				LogAndPrint('action.ConnectFrame is nil', action.ActionKey);
			end
			local connectTime = action.ConnectFrame / 30;
			if connectTime < 0 then
				-- -1은 그대로 -1로 넣어야함
				connectTime = -1;
			end
			if tableID[action.ActionKey] ~= -1 and tableID[action.Connect] ~= -1 then
				ds:Connect(tableID[action.ActionKey], tableID[action.Connect], connectTime);
			end
		end
	end
	
	ds:EndMissionDirect(true);
end
-------------------------------------------------------------------
-- MissionDirect.xml 의 ActionKey 기능을 등록 한다.
-------------------------------------------------------------------
function MissionDirect_Error(mid, ds, args, conditionOutput)
	LogAndPrint('Error');
	table.print(args);
end
function MissionDirect_Sound(mid, ds, args, conditionOutput)
	local soundID = nil;
	soundID = ds:PlaySound(args.Sound, 'Effect');
	return soundID;
end
function MissionDirect_Camera(mid, ds, args, conditionOutput)
	local mission = GetMission(mid);
	local cameraID = nil;
	local obj = GetUnitFromUnitIndicator(mid, args.Unit, conditionOutput, true);
	if obj == nil then
		LogAndPrint(string.format('[DataError] [%s]  MissionDirect Camera Object is nil', mission.name));
		table.print(args.Unit);
		return;
	end
	
	if IsDead(obj) then
		return ds:Sleep(0);
	end
	
	local moveTime = args.Time;
	if moveTime == nil or moveTime == '' then
		moveTime = 1;
	end
	local animSlope = args.CameraAnimSlope or 3;
	cameraID = ds:ChangeCameraTarget(GetObjKey(obj), args.CameraKey, StringToBool(args.CameraDirectMove), StringToBool(args.CameraAfterRelease), moveTime, animSlope, StringToBool(args.DisableHideAsset), true);
	return cameraID;
end
function MissionDirect_CameraTargeting(mid, ds, args, conditionOutput)
	local mission = GetMission(mid);
	local cameraID = nil;
	
	local obj = GetUnitFromUnitIndicator(mid, args.Unit, conditionOutput, true);
	local objTarget = GetUnitFromUnitIndicator(mid, args.Unit2, conditionOutput, true);
	if IsDead(obj) or IsDead(objTarget) then
		return ds:Sleep(0);
	end
	
	local moveTime = args.Time;
	if moveTime == nil or moveTime == '' then
		moveTime = 1;
	end
	local animSlope = args.CameraAnimSlope or 3;
	cameraID = ds:ChangeCameraTargetingMode(GetObjKey(obj), GetObjKey(objTarget), args.CameraKey, StringToBool(args.CameraDirectMove), StringToBool(args.CameraAfterRelease), moveTime, animSlope, true);
	return cameraID;
end
function GetPositionFromPositionIndicator(mid, positionIndicator, conditionOutput, includeDead)
	local positionIndicator = SafeIndex(positionIndicator, 1);
	if positionIndicator == nil or type(positionIndicator) ~= 'table' then
		return InvalidPosition();
	elseif positionIndicator.Type == 'Object' then
		local key = SafeIndex(positionIndicator, 'ObjectKey');
		if not key then
			return InvalidPosition();
		end
		local obj = GetUnit(mid, key, true);
		if obj == nil then
			LogAndPrint(string.format('GetPositionFromPositionIndicator>> [DataError] :: Not Exist [%s] Object Key', key));
			return InvalidPosition();
		end
		if includeDead ~= nil and not includeDead and IsDead(obj) then
			return InvalidPosition();
		end
		return GetPosition(obj);
	elseif positionIndicator.Type == 'Position' then
		return SafeIndex(positionIndicator, 'Position', 1) or InvalidPosition();
	elseif positionIndicator.Type == 'Variable' or positionIndicator.Type == 'ConditionOutput' then
		local value = nil;
		if positionIndicator.Type == 'Variable' then
			value = GetStageVariable(mid, positionIndicator.Variable);
		else
			value = SafeIndex(conditionOutput, positionIndicator.Key);
		end
		if value == nil then
			return InvalidPosition();
		end
		if type(value) ~= 'table' then
			value = GetPosition(value);
		end
		if SafeIndex(value, 'x') and SafeIndex(value, 'y') and SafeIndex(value, 'z') then
			return value;
		else
			return InvalidPosition();
		end
	elseif positionIndicator.Type == 'CenterOfArea' then
		local from = SafeIndex(positionIndicator, 'Area', 1, 'From', 1)
		local to = SafeIndex(positionIndicator, 'Area', 1, 'To', 1)
		if not from or not to then
			return InvalidPosition();
		end
		local cx = (from.x + to.x) / 2;
		local cy = (from.y + to.y) / 2;
		local cz = (from.z + to.z) / 2;
		local cpos = { x = math.floor(cx), y = math.floor(cy), z = math.floor(cz) };
		cpos.offset = { x = cx - cpos.x, y = cy - cpos.y };
		return cpos;
	elseif positionIndicator.Type == 'ObjectInstantProperty' then
		local unit = GetUnitFromUnitIndicator(mid, positionIndicator.Unit, conditionOutput, true);
		if unit == nil then
			LogAndPrint('GetPositionFromPositionIndicator>> [DataError] :: Type=ObjectInstantProperty Not Exist Unit', positionIndicator.Unit);
			return InvalidPosition();
		end
		if includeDead ~= nil and not includeDead and IsDead(unit) then
			return InvalidPosition();
		end
		local value = GetInstantProperty(unit, positionIndicator.Key);
		if value == nil then
			return InvalidPosition();
		else
			return value;	-- 데이터 타입 오류는 제발 알아서 하자..
		end
	elseif positionIndicator.Type == 'EmptyNearObject' then
		local unit = GetUnitFromUnitIndicator(mid, positionIndicator.Unit, conditionOutput, true);
		if unit == nil then
			return InvalidPosition();
		end
		local unitPos = GetPosition(unit);
		local picker = RandomPicker.new();
		local moveRange = GetMoveRange(unit, positionIndicator.Range);
		if #moveRange <= positionIndicator.Range then
			moveRange = {};
			local mission = GetMission(unit);
			-- 이동 경로가 완전히 막혀버림
			for x = unitPos.x - positionIndicator.Range, unitPos.x + positionIndicator.Range do
				for y = unitPos.y - positionIndicator.Range, unitPos.y + positionIndicator.Range do
					local vp = GetValidPosition(mid, {x = x, y = y, z = 0}, true);
					if not GetObjectByPosition(mission, vp) and GetBaseMoveDistance(mid, unitPos, vp) < positionIndicator.Range then
						table.insert(moveRange, vp);
					end
				end
			end
		end
		Linq.new(moveRange)
			:where(function (p) return GetDistance3D(unitPos, p) > positionIndicator.Range * 2 / 3 end)
			:foreach(function(p)
				local dist = math.min(GetDistance3D(p, unitPos), positionIndicator.Range);
				picker:addChoice(math.max(1, math.floor(dist * dist)), p);
			end);
		local p = picker:pick();
		if p then
			return p;
		end
		-- 적절한 범위 내에서 위치를 찾을 수 없었던 경우 풀 레인지로 새로 뽑는다
		local picker = RandomPicker.new();
		Linq.new(moveRange)
			:foreach(function(p)
				local dist = math.min(GetDistance3D(p, unitPos), positionIndicator.Range);
				picker:addChoice(math.max(1, math.floor(dist * dist)), p);
			end);
		local p = picker:pick();
		if p == nil then
			return unitPos;
		else
			return p;
		end
	else
		return InvalidPosition();
	end
end
function GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput, includeDead)
	local unitIndicator = SafeIndex(unitIndicator, 1);
	if unitIndicator == nil or type(unitIndicator) ~= 'table' then
		return nil;
	elseif unitIndicator.Type == 'Object' then
		return GetUnit(mid, unitIndicator.ObjectKey, includeDead);
	elseif unitIndicator.Type == 'Interaction' then
		return GetUnit(mid, unitIndicator.InteractionUnit, includeDead);
	elseif unitIndicator.Type == 'Type' then
		local unitCount = GetTeamCount(mid, unitIndicator.Team);
		for index = 1, unitCount do
			local u = GetTeamUnitByIndex(mid, unitIndicator.Team, index);
			if u.name == unitIndicator.GameObject then
				return u;
			end
		end
		return nil;
	elseif unitIndicator.Type == 'ConditionOutput' or unitIndicator.Type == 'Variable' then
		local value = nil;
		if unitIndicator.Type == 'ConditionOutput' then
			value = SafeIndex(conditionOutput, unitIndicator.Key);
		else
			value = GetStageVariable(mid, unitIndicator.Variable);
		end
		if type(value) == 'string' then
			return GetUnit(mid, value);
		elseif type(value) == 'userdata' then
			if GetIdspace(value) == 'Object' then		-- Object만 허용
				return value;
			else
				return nil;
			end
		else
			return nil;
		end
	else
		return nil;
	end
end
function GetUnitKeyFromUnitIndicator(mid, unitIndicator, conditionOutput, includeDead)
	local unit = GetUnitFromUnitIndicator(mid, unitIndicator, conditionOutput, includeDead);
	if unit then
		return GetObjKey(unit);
	else
		return '__NoObject__';
	end
end
function GetUnitsFromAnyUnitIndicator(mid, unitIndicator, conditionOutput, includeDead)
	local unitIndicator = SafeIndex(unitIndicator, 1);
	if unitIndicator == nil or type(unitIndicator) ~= 'table' then
		return {};
	elseif unitIndicator.Type == 'Type' then
		local rets = {};
		local units = GetTeamUnits(mid, unitIndicator.Team, includeDead);
		for _, u in ipairs(units) do
			if u.name == unitIndicator.GameObject then
				table.insert(rets, u);
			end
		end
		return rets;
	elseif unitIndicator.Type == 'InstantProperty' then
		local rets = {};
		for _, unit in ipairs(GetAllUnit(mid)) do
			local propValue = GetInstantProperty(unit, unitIndicator.PropKey);
			local checkFunc = loadstring('return ' .. tostring(unitIndicator.SuccessExpression));
			setfenv(checkFunc, {math=math, os=os, mission=GetMission(mid), value=propValue});
			if checkFunc() then
				table.insert(rets, unit);
			end
		end
		return rets;
	elseif unitIndicator.Type == 'ConditionOutput' then
		return conditionOutput[unitIndicator.Key];
	else
		return {};
	end
end
function GetUnitsFromAllUnitIndicator(mid, unitIndicator, conditionOutput, includeDead)
	local unitIndicator = SafeIndex(unitIndicator, 1);
	if unitIndicator == nil or type(unitIndicator) ~= 'table' then
		return {};
	elseif unitIndicator.Type == 'Team' then
		return GetTeamUnits(mid, unitIndicator.Team, includeDead);
	elseif unitIndicator.Type == 'Area' then
		local posList = GetPositionListFromAreaIndicator(mid, unitIndicator.AreaIndicator, conditionOutput);
		local units = GetAllUnit(mid, includeDead);
		return table.filter(units, function(u)
			return PositionInRange(posList, GetPosition(u));
		end);
	elseif unitIndicator.Type == 'TeamArea' then
		local posList = GetPositionListFromAreaIndicator(mid, unitIndicator.AreaIndicator, conditionOutput);
		local units = GetTeamUnits(mid, unitIndicator.Team, includeDead);
		return table.filter(units, function(u)
			return PositionInRange(posList, GetPosition(u));
		end);
	else
		return {};
	end
end
function GetDashboardFromDashboardIndicator(mid, dashboardIndicator, conditionOutput)
	local dashboardIndicator = SafeIndex(dashboardIndicator, 1);
	if dashboardIndicator == nil then
		return nil;
	end
	if dashboardIndicator.Type == 'Dashboard' then
		return GetMissionDashboard(mid, dashboardIndicator.DashboardKey);
	elseif dashboardIndicator.Type == 'ConditionOutput' then
		return conditionOutput[dashboardIndicator.Key];
	elseif dashboardIndicator.Type == 'KeyExpression' then
		local dashboardKey = tostring(StageDataBinder(GetMission(mid), dashboardIndicator.StageDataBinding[1], conditionOutput));
		return GetMissionDashboard(mid, dashboardKey);
	else
		return nil;
	end
end
function MissionDirect_CameraPosition(mid, ds, args, conditionOutput)
	local x, y, z;
	local includeDead = StringToBool(args.IncludeDead, false);
	
	local pos = GetPositionFromPositionIndicator(mid, SafeIndex(args, 'PositionIndicator'), conditionOutput, includeDead);
	
	-- 유효하지 않은 좌표의 경우 카메라 이동을 스킵한다
	if IsInvalidPosition(pos) then
		return ds:Sleep(0);
	end
	
	x = pos.x;
	y = pos.y;
	z = pos.z;
	
	local directMove = StringToBool(args.CameraDirectMove);
	local moveTime = tonumber(args.Time) or 0;
	local fov = args.CameraFOV or 0;
	local animSlope = args.CameraAnimSlope or 3;
	
	local retId;
	local updateSystemCamera = SafeIndex(args, 'UpdateDirection', 1, 'Type') == 'Yes';
	if not updateSystemCamera then
		retId = ds:ChangeCameraPosition(x, y, z, directMove, moveTime, animSlope, fov, -1, true);
	else
		local systemDirection = SafeIndex(args, 'UpdateDirection', 1, 'SystemDirection');
		retId = ds:ChangeCameraPosition(x, y, z, directMove, moveTime, animSlope, fov, systemDirection, true);
	end
	
	if args.PositionIndicator[1].Type == 'Object' and not includeDead then
		local key = SafeIndex(args, 'PositionIndicator', 1, 'ObjectKey');
		ds:Connect(retId, ds:EnableIf('TestObjectAlive', key), -1);
	end
	return retId;
end
function MissionDirect_CameraPositionDirection(mid, ds, args, conditionOutput)
	local pos = args.CamPosDir[1].Position[1];
	local dir = args.CamPosDir[1].Direction[1];
	local blink = StringToBool(args.CameraDirectMove, false);
	if type(args.Time) ~= 'number' then
		args.Time = 0;
	end
	
	local enableDOF = StringToBool(args.DOFEnable, true);
	local isFixDist = StringToBool(args.DOFFixDist, false);
	local disableFogOfWar = StringToBool(args.FogOfWarDisable, true);
	local fov = args.CameraFOV or 0;
	local animSlope = args.CameraAnimSlope or 3;
	local cameraID = ds:SetCameraPositionDirection(blink, pos.x, pos.y, pos.z, dir.x, dir.y, dir.z, args.Time or 0, animSlope, fov, enableDOF, isFixDist, args.DOFFocusDist or 2500, args.DOFInnerRange or 100000, args.DOFOuterRange or 500, disableFogOfWar, args.CamHideAssetDistance or 0);
	return cameraID;
end

function MissionDirect_CameraFree(mid, ds, args, conditionOutput)
	return ds:FreeCamera();
end

function MissionDirect_ClearDyingObjects(mid, ds, args, conditionOutput)
	local actionID = ds:WorldAction(Result_ClearDyingObjects(), true, false);
	ds:SetContinueOnEmpty(actionID);
	return actionID;
end

function MissionDirect_CleanupSight(mid, ds, args, conditionOutput)
	return ds:RunScript('CleanupSight', {}, true);
end

function MissionDirect_Dialog(mid, ds, args, conditionOutput)
	local dialogID = nil;
	local obj = GetUnitFromUnitIndicator(mid, args.Unit, conditionOutput);
	if obj == nil then
		LogAndPrint(string.format('[DataError] :: Not Exist Object'));
		table.print(args.Unit);
		return;
	end
	dialogID = ds:Dialog("NormalDialog",{DlgName = obj.Info.Title, Mode = args.DialogMode, Message = {Text = args.Message}});
	if StringToBool(args.CloseDialog, true) then
		ds:CloseDialog("NormalDialog");
	end
	return dialogID;
end
function MissionDirect_DialogBattle(mid, ds, args, conditionOutput)
	local dialogID = nil;
	local mission = GetMission(mid);
	local keywords = SafeIndex(args, 'MessageFormat', 1, 'Keyword') or {};
	local messageFormat = {};
	for i, keyword in ipairs(keywords) do
		messageFormat[keyword.Name] = StageTextBinder(mission, SafeIndex(keyword, 'StageTextBinding', 1));
	end
	
	dialogID = ds:Dialog("BattleDialog",{SpeakerInfo = args.Speaker[1].Info, SpeakerEmotion = args.Speaker[1].Emotion, Mode = args.DialogMode, Message = args.Message, Type = args.DialogType, Slot = args.ShowSlot, Effect = args.DialogEffect, CustomTitle = args.Title, MessageFormat=messageFormat});
	if StringToBool(args.CloseDialog, true) then
		ds:CloseDialog("BattleDialog");
	end
	return dialogID;
end
function MissionDirect_DialogSystemMessageBox(mid, ds, args, conditionOutput)
	local dialogID = nil;
	dialogID = ds:Dialog("DialogSystemMessageBox",{ Title = SentenceStringText(args.Title), Message = SentenceStringText(args.Message), Image = args.Image});
	return dialogID;
end
function MissionDirect_HelpMessage(mid, ds, args, conditionOutput)
	if args.HelpType == 'DialogSystemMessageBox' then
		local ret = ds:Dialog("HelpMessageBox",{ Type = args.HelpMessage });
		if StringToBool(args.ShowUI, false) then
			local ui_On = ds:BattleUIControl(true);
			local ui_Off = ds:BattleUIControl(false);
			ds:Connect(ui_On, ret, 0);
			ds:Connect(ui_Off, ret, -1);
		end
		return ret;
	elseif args.HelpType == 'SystemMessage' then
		return ds:UpdateBattleSystemMessage_Help(args.HelpMessage, 'TaharezLook/ExclamationMark');
	else
		return nil;
	end
end
function MissionDirect_VictoryCondition(mid, ds, args, conditionOutput)
	local dialogArgs = {};
	dialogArgs.VictoryCondition = table.map(args.VictoryCondition[1].Entry, function(entry) return { Title = entry.Title, FontColor = entry.FontColor }; end);
	dialogArgs.DefeatCondition = table.map(args.DefeatCondition[1].Entry, function(entry) return { Title = entry.Title, FontColor = entry.FontColor }; end);
	local dialogID = nil;
	RegisterConnectionRestoreRoutine(mid, 'VictoryCondition', function(ds)
		ds:Dialog("VictoryCondition", dialogArgs);
	end);
	dialogID = ds:Dialog("VictoryCondition", dialogArgs);
	return dialogID;
end
function MissionDirect_SpawnObject(mid, ds, args, conditionOutput)
	local obj = GetUnitFromUnitIndicator(mid, args.Unit, conditionOutput, true);
	if obj == nil then
		return -1;
	end
	local objKey = GetObjKey(obj);
	local action = ds:WorldAction(Result_Resurrect(obj, 'direct'));
	local resurr = ds:Resurrect(objKey, true);
	ds:Connect(resurr, action, 0);
	local move = ds:Move(objKey, args.Position[1], true, args.NoEvent ~= 'On', nil, nil, nil, StringToBool(args.ForwardEvent, false), nil, nil, nil, nil, true);
	local moveAction = Result_SetPosition(obj, args.Position[1]);
	moveAction._ref = move;
	moveAction._ref_offset = 0;
	moveAction.directing_id = move;
	moveAction.mission_direct_move = true;
	ds:WorldAction(moveAction, args.NoEvent ~= 'On');
	ds:Connect(move, resurr, 0);
	ds:Connect(ds:LookPos(objKey, args.Direction[1], true, true), resurr, -1);
	return action;
end
function MissionDirect_LockCamera(mid, ds, args, conditionOutput)
	if game.DirectingCommand[args.CameraControlType] == nil then		-- game은 toluapp로 바인드된 idspace이고 이 구문은 거기에 선언된 enum값 얻어오는 거...
		LogAndPrint('MissionDirect_LockCamera', 'CameraControlType Require Absolutely', args.CameraControlType);
		return -1;
	end
	if args.OnOff == 'On' then
		RegisterConnectionRestoreRoutine(mid, 'LockCamera/' .. args.CameraControlType, function(ds)
			ds:LockCameraControl(game.DirectingCommand[args.CameraControlType]);
		end);
		return ds:LockCameraControl(game.DirectingCommand[args.CameraControlType]);
	else	-- Off 혹은 에러 케이스는 모두 꺼주는걸로
		UnregisterConnectionRestoreRoutine(mid, 'LockCamera/' .. args.CameraControlType);
		return ds:UnlockCameraControl(game.DirectingCommand[args.CameraControlType]);
	end
end
function MissionDirect_BalloonChat(mid, ds, args, conditionOutput)
	local chatID = nil;
	local colorList = GetClassList('Color');
	local fontColor = args.FontColor or 'Black';
	local includeDead = StringToBool(args.IncludeDead, false);
	local obj = GetUnitFromUnitIndicator(mid, args.Unit, conditionOutput, includeDead);
	if obj == nil then
		return ds:Sleep(0);
	end
	local lifeTime = args.LifeTime;
	if lifeTime == nil or lifeTime == 0 then
		lifeTime = 3;
	end
	chatID = ds:UpdateBalloonChat(GetObjKey(obj), args.Message, args.BalloonType, args.Font, colorList[fontColor].ARGB, lifeTime, not includeDead);
	if args.Time ~= nil and args.Time ~= '' then
		local sleepID = ds:Sleep(args.Time);
		ds:Connect(chatID, sleepID, 0);
		chatID = sleepID;
	end
	return chatID;
end
function MissionDirect_Move(mid, ds, args, conditionOutput)
	local unitKey = GetUnitKeyFromUnitIndicator(mid, args.Unit, conditionOutput);
	local moveAni = nil;
	if StringToBool(args.Walk, false) then
		moveAni = 'Walk';
	elseif StringToBool(args.Run, false) then
		moveAni = 'Run';
	elseif StringToBool(args.Rush, false) then
		moveAni = 'Rush';
	end
	
	local blink = StringToBool(args.Blink, false);
	local invokeEvent = args.NoEvent ~= 'On';
	local moveID = ds:Move(unitKey, args.Position[1], blink, invokeEvent, moveAni, 0, 0, false, 1, args.NoCover == 'On', args.NoWait == 'On', args.NoZOC == 'On', true);
	local moveAction = nil;
	if blink then
		moveAction = Result_SetPosition(GetUnit(mid, unitKey), args.Position[1]);
	else
		moveAction = Result_Move(args.Position[1], GetUnit(mid, unitKey));
	end
	moveAction._ref = moveID;
	moveAction._ref_offset = 0;
	moveAction.directing_id = moveID;
	moveAction.mission_direct_move = true;
	moveAction.no_zoc = args.NoZOC == 'On';
	ds:WorldAction(moveAction, invokeEvent);
	return moveID;
end
function MissionDirect_MoveEx(mid, ds, args, conditionOutput)
	local unitKey = GetUnitKeyFromUnitIndicator(mid, args.Unit, conditionOutput);
	local moveAni = nil;
	if StringToBool(args.Walk, false) then
		moveAni = 'Walk';
	elseif StringToBool(args.Run, false) then
		moveAni = 'Run';
	elseif StringToBool(args.Rush, false) then
		moveAni = 'Rush';
	end
	
	local movePos = GetPositionFromPositionIndicator(mid, SafeIndex(args, 'PositionIndicator'), conditionOutput);
	
	local blink = StringToBool(args.Blink, false);
	local invokeEvent = args.NoEvent ~= 'On';
	local moveID = ds:Move(unitKey, movePos, blink, invokeEvent, moveAni, 0, 0, false, 1, args.NoCover == 'On', args.NoWait == 'On', args.NoZOC == 'On', true);
	local moveAction = nil;
	if blink then
		moveAction = Result_SetPosition(GetUnit(mid, unitKey), movePos);
	else
		moveAction = Result_Move(movePos, GetUnit(mid, unitKey));
	end
	moveAction._ref = moveID;
	moveAction._ref_offset = 0;
	moveAction.directing_id = moveID;
	moveAction.mission_direct_move = true;
	moveAction.no_zoc = args.NoZOC == 'On';
	ds:WorldAction(moveAction, invokeEvent);
	return moveID;
end
function MissionDirect_MoveToUnit(mid, ds, args, conditionOutput)
	local unit = GetUnitFromUnitIndicator(mid, args.Unit, conditionOutput);
	local unitKey = GetObjKey(unit);
	local moveToUnit = GetUnitFromUnitIndicator(mid, args.Unit2, conditionOutput, true);
	local moveAni = nil;
	if StringToBool(args.Walk, false) then
		moveAni = 'Walk';
	elseif StringToBool(args.Run, false) then
		moveAni = 'Run';
	elseif StringToBool(args.Rush, false) then
		moveAni = 'Rush';
	end
	
	local movePos = GetMovePosition(unit, GetPosition(moveToUnit), tonumber(args.Range), nil, 999999999);
	
	local blink = StringToBool(args.Blink, false);
	local invokeEvent = args.NoEvent ~= 'On';
	local moveID = ds:Move(unitKey, movePos, blink, invokeEvent, moveAni, 0, 0, false, 1, args.NoCover == 'On', args.NoWait == 'On', args.NoZOC == 'On', true);
	local moveAction = nil;
	if blink then
		moveAction = Result_SetPosition(GetUnit(mid, unitKey), movePos);
	else
		moveAction = Result_Move(movePos, GetUnit(mid, unitKey));
	end
	moveAction._ref = moveID;
	moveAction._ref_offset = 0;
	moveAction.directing_id = moveID;
	moveAction.mission_direct_move = true;
	moveAction.no_zoc = args.NoZOC == 'On';
	ds:WorldAction(moveAction, invokeEvent);
	return moveID;
end
function MissionDirect_MoveAllToArea(mid, ds, args, conditionOutput)
	local mission = GetMission(mid);
	local units = GetUnitsFromAllUnitIndicator(mid, args.AllUnit, conditionOutput);
	local movePosList = GetPositionListFromAreaIndicator(mid, SafeIndex(args, 'AreaIndicator'), conditionOutput);
	if #movePosList == 0 then
		return -1;
	end	
	local emptyPosList = table.filter(movePosList, function(pos)
		return GetObjectByPosition(mission, pos) == nil and IsValidPosition(mission, pos, true);
	end);
	if #emptyPosList == 0 then
		-- 씁 어쩔 수 없지.
		emptyPosList = movePosList;
	end
	emptyPosList = table.shuffle(emptyPosList);
	
	local moveMap = {};
	for i, unit in ipairs(units) do
		local movePos = emptyPosList[(i - 1) % #emptyPosList + 1];
		moveMap[GetObjKey(unit)] = movePos;
	end
	
	local baseID = ds:Sleep(0);	
	for unitKey, movePos in pairs(moveMap) do
		local moveAni = nil;
		if StringToBool(args.Walk, false) then
			moveAni = 'Walk';
		elseif StringToBool(args.Run, false) then
			moveAni = 'Run';
		elseif StringToBool(args.Rush, false) then
			moveAni = 'Rush';
		end
		local blink = StringToBool(args.Blink, false);
		local invokeEvent = args.NoEvent ~= 'On';
		local moveID = ds:Move(unitKey, movePos, blink, invokeEvent, moveAni, 0, 0, false, 1, args.NoCover == 'On', args.NoWait == 'On', args.NoZOC == 'On', true);
		ds:Connect(moveID, baseID, 0);
		
		local moveAction = nil;
		if blink then
			moveAction = Result_SetPosition(GetUnit(mid, unitKey), movePos);
		else
			moveAction = Result_Move(movePos, GetUnit(mid, unitKey));
		end
		moveAction._ref = moveID;
		moveAction._ref_offset = 0;
		moveAction.directing_id = moveID;
		moveAction.mission_direct_move = true;
		moveAction.no_zoc = args.NoZOC == 'On';
		ds:WorldAction(moveAction, invokeEvent);
	end
	
	return baseID;
end
function MissionDirect_Look(mid, ds, args, conditionOutput)
	local pos = GetPositionFromPositionIndicator(mid, SafeIndex(args, 'PositionIndicator'), conditionOutput);
	return ds:LookPos(GetUnitKeyFromUnitIndicator(mid, args.Unit, conditionOutput), pos, false, StringToBool(args.Blink, false), StringToBool(args.Reverse, false), args.NoCover == 'On');
end
function MissionDirect_Particle(mid, ds, args, conditionOutput)
	local obj = GetUnitFromUnitIndicator(mid, args.Unit, conditionOutput);
	local particleID = nil;
	if obj == nil then
		LogAndPrint(string.format('[DataError] :: Not Exist Object'));
		table.print(args.Unit);
		return;
	end	
	local hitBone = nil;
	
	if args.ParticlePos == '_CENTER_' 
		or args.ParticlePos == '_BOTTOM_'
		or args.ParticlePos == '_TOP_'
	then
		hitBone = args.ParticlePos;
	else
		hitBone = GetObjectBonePos(obj, args.ParticlePos);
	end
	if hitBone == nil then
		return;
	end
	particleID = ds:PlayParticle(GetObjKey(obj), hitBone, args.Particle, args.ParticleLength / 30, StringToBool(args.AttachModel, true), StringToBool(args.DirectClear, false));
	return particleID;
end
function MissionDirect_ParticlePosition(mid, ds, args, conditionOutput)
	local particleID = nil;
	local pos = GetPositionFromPositionIndicator(mid, SafeIndex(args, 'PositionIndicator'), conditionOutput);
	particleID = ds:PlayParticlePosition(args.Particle, pos.x, pos.y, pos.z, args.ParticleLength/30, StringToBool(args.DirectClear, true));
	return particleID;
end
function MissionDirect_MissionVisualArea(mid, ds, args, conditionOutput)
	local particleID = nil;
	local pos = GetPositionFromPositionIndicator(mid, SafeIndex(args, 'PositionIndicator'), conditionOutput);
	local on = args.OnOff ~= 'Off';
	if on then
		RegisterConnectionRestoreRoutine(mid, 'MissionVisualArea/'..args.ParticleKey, function(ds)
			ds:MissionVisualArea_AddCustom(args.ParticleKey, pos, args.Particle, on);
		end);
	else
		UnregisterConnectionRestoreRoutine(mid, 'MissionVisualArea/'..args.ParticleKey);
	end
	particleID = ds:MissionVisualArea_AddCustom(args.ParticleKey, pos, args.Particle, args.OnOff ~= 'Off');
	return particleID;
end
function MissionDirect_Sleep(mid, ds, args, conditionOutput)
	return ds:Sleep(args.Time);
end
function MissionDirect_Animation(mid, ds, args, conditionOutput)
	local animationID = nil;
	animationID = ds:PlayAni(GetUnitKeyFromUnitIndicator(mid, args.Unit, conditionOutput), args.Animation, StringToBool(args.Loop, false), -1, args.NoWait == 'On');
	return animationID;
end
function MissionDirect_PlayPose(mid, ds, args, conditionOutput)
	local animationID = nil;
	local loopAnimation = args.LoopAnimation;
	if loopAnimation == 'None' then
		loopAnimation = '';
	end	
	animationID = ds:PlayPose(GetUnitKeyFromUnitIndicator(mid, args.Unit, conditionOutput), args.Animation, loopAnimation, StringToBool(args.FadeIn, false));
	return animationID;
end
function MissionDirect_ReleasePose(mid, ds, args, conditionOutput)
	local animationID = nil;
	local releaseAnimation = args.ReleaseAnimation;
	if releaseAnimation == 'None' then
		releaseAnimation = '';
	end	
	animationID = ds:ReleasePose(GetUnitKeyFromUnitIndicator(mid, args.Unit, conditionOutput), releaseAnimation, StringToBool(args.FadeIn, false), StringToBool(args.FadeOut, false));
	return animationID;
end
function MissionDirect_SightOn(mid, ds, args, conditionOutput)
	local sightID = nil;
	local pos = GetPositionFromPositionIndicator(mid, SafeIndex(args, 'PositionIndicator'), conditionOutput);
	RegisterConnectionRestoreRoutine(mid, 'MDSight/'..args.Name, function (ds)
		ds:CreateClientSightObject('MDSight_'..args.Name, pos.x, pos.y, pos.z, args.Range);
	end);
	sightID = ds:CreateClientSightObject('MDSight_'..args.Name, pos.x, pos.y, pos.z, args.Range);
	return sightID;
end
function MissionDirect_SightOff(mid, ds, args, conditionOutput)
	local sightID = nil;
	UnregisterConnectionRestoreRoutine(mid, 'MDSight/'..args.Name);
	sightID = ds:DestroyClientSightObject('MDSight_'..args.Name);
	return sightID;
end
function MissionDirect_SightTarget(mid, ds, args, conditionOutput)
	local unitKey = GetUnitKeyFromUnitIndicator(mid, args.Unit, conditionOutput, true);
	if unitKey == '__NoObject__' then
		return -1;
	end
	if args.OnOff == 'On' then
		RegisterConnectionRestoreRoutine(mid, 'SightTarget/'..unitKey, function(ds)
			ds:EnableTemporalSightTarget(unitKey, 0, args.Range);
		end);
		return ds:EnableTemporalSightTarget(unitKey, 0, args.Range);
	else
		UnregisterConnectionRestoreRoutine(mid, 'SightTarget/'..unitKey);
		return ds:DisableTemporalSightTarget(unitKey, 0);
	end
end
function MissionDirect_SkipPointOn(mid, ds, args, conditionOutput)
	return ds:SkipPointOn();
end
function MissionDirect_SkipPointOff(mid, ds, args, conditionOutput)
	return ds:SkipPointOff();
end
function MissionDirect_PlayBGM(mid, ds, args, conditionOutput)
	return ds:PlayCustomBGM(args.BGMName, tonumber(args.FadeTime) or 3, tonumber(args.Volume) or 1);
end
function MissionDirect_StopBGM(mid, ds, args, conditionOutput)
	return ds:StopCustomBGM(StringToBool(args.Direct, false), tonumber(args.FadeTime) or 3);
end
function MissionDirect_PlaySound(mid, ds, args, conditionOutput)
	return ds:PlaySound(args.SoundName, args.SoundGroup, tonumber(args.Volume) or 1, args.NoWait == 'On');
end
function MissionDirect_PlaySound3D(mid, ds, args, conditionOutput)
	local obj = GetUnitFromUnitIndicator(mid, args.Unit, conditionOutput);
	if obj == nil then
		LogAndPrint(string.format('[DataError] :: Not Exist Object'));
		table.print(args.Unit);
		return;
	end	
	
	local hitBone = nil;
	if args.BonePos == '_CENTER_' 
		or args.BonePos == '_BOTTOM_'
		or args.BonePos == '_TOP_'
	then
		hitBone = args.BonePos;
	else
		hitBone = GetObjectBonePos(obj, args.BonePos);
	end
	if hitBone == nil then
		return;
	end
	
	return ds:PlaySound3D(args.SoundName, GetObjKey(obj), hitBone, tonumber(args.MinDistance) or 2500, args.SoundGroup, tonumber(args.Volume) or 1, args.NoWait == 'On');
end
function MissionDirect_PlaySound3DPosition(mid, ds, args, conditionOutput)
	local pos = GetPositionFromPositionIndicator(mid, SafeIndex(args, 'PositionIndicator'), conditionOutput);
	return ds:PlaySound3DPosition(args.SoundName, pos.x, pos.y, pos.z, tonumber(args.MinDistance) or 2500, args.SoundGroup, tonumber(args.Volume) or 1, args.NoWait == 'On');
end
function MissionDirect_PlayLoopSound(mid, ds, args, conditionOutput)
	return ds:PlayLoopSound(args.Name, args.SoundName, args.SoundGroup, tonumber(args.Volume) or 1, args.NoWait == 'On');
end
function MissionDirect_StopLoopSound(mid, ds, args, conditionOutput)
	return ds:StopLoopSound(args.Name);
end
function MissionDirect_GuideControl(mid, ds, args, conditionOutput)
	return ds:GuideControl(args.GuideType);
end
function MissionDirect_GuideAbility(mid, ds, args, conditionOutput)
	local unit = GetUnitFromUnitIndicator(mid, args.Unit, conditionOutput);
	local pos = GetPositionFromPositionIndicator(mid, SafeIndex(args, 'PositionIndicator'), conditionOutput);
	local subPos = GetPositionFromPositionIndicator(mid, SafeIndex(args, 'SubPositionIndicator'), conditionOutput);
	local directingConfig = {};
	if StringToBool(args.Guide, true) then
		if args.HelpMessage and args.HelpMessage ~= 'None' then
			ds:UpdateBattleSystemMessage_Help(args.HelpMessage, 'TaharezLook/ExclamationMark');	
		end
		ds:GuideAbility(GetObjKey(unit), args.AbilityType, pos, subPos, args.CamDistance, args.HoldTime, args.SoundName, args.Particle, SafeIndex(args, 'AbilityGuideFlag', 1));
		if args.HelpMessage and args.HelpMessage ~= 'None' then
			ds:UpdateBattleSystemMessage_Help('None', 'TaharezLook/ExclamationMark');	
		end
	else
		directingConfig.NoCamera = true;
		directingConfig.NoMarker = true;
		directingConfig.NoVoice = true;
		directingConfig.NoDamageShow = true;
		directingConfig.Skipable = true;
	end
	directingConfig.NoOutline = args.NoOutline ~= 'Off';
	if StringToBool(args.NoLook) then
		directingConfig.NoLook = true;
	end
	if args.NoCamera ~= nil then
		directingConfig.NoCamera = args.NoCamera == 'On'
	end
	if args.NoWiggle ~= nil then
		directingConfig.NoWiggle = args.NoWiggle == 'On'
	end
	directingConfig.MessageVisible = args.MessageVisible ~= 'Off';
	directingConfig.StatusVisible = args.StatusVisible ~= 'Off';
	local resultModifier = SafeIndex(args, 'ResultModifier', 1);
	local rm = RebaseXmlTableToClassTable(resultModifier);
	rm.NoReward = true;
	local useAbility = Result_UseAbility(unit, args.AbilityType, pos, rm, true, directingConfig, false, args.NoTeamCheck == 'On', true);
	useAbility.sub_positions = {subPos};
	if args.UseFinalCheck == 'On' then
		useAbility.final_useable_checker = function()
			local ability = GetAbilityObject(unit, args.AbilityType);
			return GetBuffStatus(unit, 'Attackable', 'And')
				and PositionInRange(CalculateRange(unit, ability.TargetRange, GetPosition(unit)), pos);
		end;
	end
	return ds:WorldAction(useAbility, args.NoEvent ~= 'On');
end
function MissionDirect_SceneFade(mid, ds, args, conditionOutput)
	local image = args.Image or '';
	local direct = StringToBool(args.Direct, false);
	if args.FadeType == 'In' then
		return ds:SceneFadeIn(image, direct);
	elseif args.FadeType == 'Out' then
		return ds:SceneFadeOut(image, direct);
	else
		return -1;
	end
end

function StageDataBinder(mission, data, conditionOutput)
	local dataType = data.Type;
	if dataType == 'Mission' then
		return mission;
	elseif dataType == 'StageVariable' then
		return GetStageVariable(mission, data.Variable);
	elseif dataType == 'Object' then
		return GetUnitFromUnitIndicator(GetMissionID(mission), data.Unit, conditionOutput);
	elseif dataType == 'Dashboard' then
		return GetMissionDashboard(mission, data.DashboardKey);
	elseif dataType == 'Static' then
		return data.Value;
	elseif dataType == 'Position' then
		return GetPositionFromPositionIndicator(GetMissionID(mission), data.PositionIndicator, conditionOutput);
	elseif dataType =='Expr' then
		local env = {math=math, os=os, table=table, string=string};
		for i, variable in ipairs(SafeIndex(data, 'Env', 1, 'Variable')) do
			local name = variable.Name;
			local dataBinding = variable.StageDataBinding[1];
			
			local envValue = StageDataBinder(mission, dataBinding, conditionOutput);
			env[name] = envValue;
		end
		setmetatable(env, {__index = _G});
		local testFunc = loadstring('return '.. data.TestExpression);
		setfenv(testFunc, env);
		return testFunc();
	elseif dataType == 'ConditionOutput' then
		return SafeIndex(conditionOutput, data.Key);
	else
		return nil;
	end
end

function StageVariableExprProcesser(mission, varExpr)
	local env = {math=math, os=os, table=table, string=string, mission=mission};
	setmetatable(env, {__index = function(t, k)
		local var = GetStageVariable(mission, k);
		if var then
			return var;
		else
			return _G[k];
		end
	end});
	local testFunc = loadstring('return '.. varExpr);
	setfenv(testFunc, env);
	
	local succ, ret = pcall(testFunc);
	if succ then
		return ret;
	else
		return nil;
	end
end
function StageTextBinder(mission, data, conditionOutput)
	local dataType = data.Type;
	if dataType == 'Raw' then
		return SentenceStringText(data.Title);
	elseif dataType == 'ClassData' then
		return ClassDataText(unpack(string.split(StageVariableExprProcesser(mission, data.StageVarExpr), '/')));
	elseif dataType == 'Word' then
		return WordText(StageVariableExprProcesser(mission, data.StageVarExpr));
	elseif dataType == 'GuideMessage' then
		return GuideMessageText(StageVariableExprProcesser(mission, data.StageVarExpr));
	elseif dataType == 'Custom' then
		return StageVariableExprProcesser(mission, data.StageVarExpr);
	elseif dataType == 'ConditionOutput' then
		return conditionOutput[data.Key];
	else
		return RawText('ERROR');
	end	
end

function MissionDirect_Switch(mid, ds, args, conditionOutput)
	local retID = ds:Sleep(0);
	local env = {math=math, os=os};
	for i, variable in ipairs(SafeIndex(args, 'SwitchEnvironment', 1, 'Variable')) do
		local name = variable.Name;
		local dataBinding = variable.StageDataBinding[1];
		
		local envValue = StageDataBinder(GetMission(mid), dataBinding, conditionOutput);
		env[name] = envValue;
	end
	setmetatable(env, {__index = _G});
	local testFunc = loadstring('return '.. args.TestExpression);
	setfenv(testFunc, env);
	local succ, testValue = pcall(testFunc);
	if not succ then
		LogAndPrint('MissionDirect_Switch ERROR', 'testFunc has raised an error', testValue);
		return ret;
	end
	for _, case in ipairs(SafeIndex(args, 'CaseDefinition', 1, 'Case')) do
		if tostring(testValue) == tostring(case.CaseValue) then
			local actions = case.ActionList[1].Action;
			PlayTriggerAction(GetMission(mid), ds, actions, conditionOutput, function(action)
				local actionID = ds:WorldAction(action, true);
				ds:Connect(actionID, retID, 0);
			end)
			return retID;
		end
	end
	return retID;
end

function MissionDirect_SelDialog(mid, ds, args, conditionOutput)
	local dialogArgs = {};

	dialogArgs.Content = args.Message;
	local choices = SafeIndex(args, 'DialogChoice', 1, 'Choice');
	for i, choice in ipairs(choices) do
		if choice.Text == nil then
			choice.Text = choice.Message;		--뭔가의 이유로 키값이 바뀐듯.. redirect
			choice.Message = nil;
		end
		dialogArgs[i] = choice;
		if args.DBKey ~= '' and choice.DBKey ~= '' then
			dialogArgs[i].Count = GetMissionGlobalRecord(mid, args.DBKey..'/'..choice.DBKey);
		end
	end
	
	local id, sel = ds:Dialog('NormalSelDialog', dialogArgs);
	
	if StringToBool(args.CloseDialog, true) then
		ds:CloseDialog('NormalSelDialog');
	end
	
	if sel ~= 0 and sel <= #choices then
		-- 정상 입력
		local choice = choices[sel];
		LogAndPrint('MissionDirect_SelDialog', choice.Title);
		
		if args.DBKey ~= '' and choice.DBKey ~= '' then
			IncreaseMissionGlobalRecord(mid, args.DBKey..'/'..choice.DBKey, 1);
		end
		local actions = choice.ActionList[1].Action;
		for i, action in ipairs(PlayTriggerAction(GetMission(mid), ds, actions)) do
			ds:WorldAction(action, true);
		end
	end
	
	return id;
end

function MissionDirect_SelDialogBattle(mid, ds, args, conditionOutput, dialogTest)
	local dialogArgs = {SpeakerInfo = args.Speaker[1].Info, SpeakerEmotion = args.Speaker[1].Emotion, Mode = args.DialogMode, Message = args.Message, Type = args.DialogType, Slot = args.ShowSlot, Effect = args.DialogEffect};
	local dbCount = nil;
	if args.DBKey ~= '' then
		dbCount = GetMissionGlobalRecordAll(mid, args.DBKey..'/') or {};
		local totalCount = 0;
		for _, count in pairs(dbCount) do
			totalCount = totalCount + count;
		end
		dialogArgs.TotalCount = totalCount;
	end	
	local choices = SafeIndex(args, 'DialogChoice', 1, 'Choice');
	for i, choice in ipairs(choices) do
		if choice.Text == nil then
			choice.Text = choice.Message;		--뭔가의 이유로 키값이 바뀐듯.. redirect
			choice.Message = nil;
		end
		dialogArgs[i] = choice;
		if dbCount and choice.DBKey ~= '' then
			dialogArgs[i].Count = dbCount[args.DBKey..'/'..choice.DBKey] or 0;
		end
	end
	
	local id, sel = ds:Dialog('BattleSelDialog', dialogArgs);
	
	if StringToBool(args.CloseDialog, true) then
		ds:CloseDialog('BattleSelDialog');
	end
	
	if sel ~= 0 and sel <= #choices then
		-- 정상 입력
		local choice = choices[sel];
		LogAndPrint('MissionDirect_SelDialogBattle', choice.Title);
		
		if args.DBKey ~= '' and choice.DBKey ~= '' then
			IncreaseMissionGlobalRecord(mid, args.DBKey..'/'..choice.DBKey, 1);
		end
		local actions = SafeIndex(choice, 'ActionList', 1, 'Action');
		if actions and not dialogTest then
			for i, action in ipairs(PlayTriggerAction(GetMission(mid), ds, actions, conditionOutput)) do
				ds:WorldAction(action, true);
			end
		end
	end
	
	return id;
end
function MissionDirect_TitleMessage(mid, ds, args, conditionOutput)
	-- 연출 모두를 함께 보여준다.
	-- ObjectiveType 
	local keyID = nil;
	keyID = ds:UpdateTitleMessage(args.Title, args.TitleColor, args.Message, args.MessageColor, args.Image);
	return keyID;
end
function MissionDirect_TurnBack(mid, ds, args, conditionOutput)
	local u = GetUnitFromUnitIndicator(mid, args.Unit, conditionOutput);
	return ds:TurnBack(GetObjKey(u));
end
function MissionDirect_SystemMessage(mid, ds, args, conditionOutput)
	-- 연출 모두를 함께 보여준다.
	-- ObjectiveType 
	local keyID = nil;
	keyID = ds:UpdateBattleSystemMessage(args.Title, args.Message, 'TaharezLook/ExclamationMark');
	return keyID;
end
function MissionDirect_StatusVisible(mid, ds, args, conditionOutput)
	local visible = StringToBool(args.Visible, true);
	if not visible then
		RegisterConnectionRestoreRoutine(mid, 'StatusVisible', function(ds)
			ds:ChangeStatusVisible(false);
		end);
	else
		UnregisterConnectionRestoreRoutine(mid, 'StatusVisible');
	end
	return ds:ChangeStatusVisible(visible);
end
function MissionDirect_DashBoardVisible(mid, ds, args, conditionOutput)
	local visible = StringToBool(args.Visible, true);
	RegisterConnectionRestoreRoutine(mid, 'DashboardVisible', function(ds)
		ds:MissionDashBoardVisible(visible);
	end);
	return ds:MissionDashBoardVisible(visible);
end
function MissionDirect_SubInterfaceVisible(mid, ds, args, conditionOutput)
	local visible = StringToBool(args.Visible, true);
	RegisterConnectionRestoreRoutine(mid, 'SubInterfaceVisible', function(ds)
		ds:MissionSubInterfaceVisible(visible);
	end);
	return ds:MissionSubInterfaceVisible(visible);
end
function MissionDirect_KillObject(mid, ds, args, conditionOutput)
	local u = GetUnitFromUnitIndicator(mid, args.Unit, conditionOutput);
	if u == nil then
		return -1;
	end
	local ret = ds:SetDead(GetObjKey(u), 'Normal', 0, 0, 0, 0, 0);
	local voiceSound, voiceSoundVolume, voiceOffset = GetObjectVoiceSound(u, 'Dead');
	if voiceSound and voiceSound ~= 'None' then
		local deadPlaySoundID = ds:PlaySound3D(voiceSound, GetObjKey(u), '_CENTER_', 3000, 'Effect', voiceSoundVolume or 1.0, true);
		ds:Connect(deadPlaySoundID, ret, voiceOffset);
	end	
	ds:WorldAction(Result_Damage(99999999, 'Normal', 'Hit', u, u), false);
	return ret;
end

function MissionDirect_FogOfWar(mid, ds, args, conditionOutput)
	local visible = StringToBool(args.Visible, true);
	if not visible then
		RegisterConnectionRestoreRoutine(mid, 'FogOfWar', function(ds)
			ds:EnableFogOfWar(false);
		end);
	else
		UnregisterConnectionRestoreRoutine(mid, 'FogOfWar');
	end
	return ds:EnableFogOfWar(visible);
end

function MissionDirect_Opening(mid, ds, args, conditionOutput)	
	return ds:ShowOpening(args.Message, args.Font, args.FontColor or 'White', args.TypingDelay or 0.1, args.HoldTime or 1);
end

function MissionDirect_Subtitle(mid, ds, args, conditionOutput)
	return ds:ShowSubtitle({SpeakerInfo = args.Speaker[1].Info, SpeakerEmotion = args.Speaker[1].Emotion, Mode = args.DialogMode, Message = args.Message, Type = args.DialogType, Slot = args.ShowSlot, Effect = args.DialogEffect, LifeTime = args.LifeTime});
end

function MissionDirect_ShowBackgroundImage(mid, ds, args, conditionOutput)
	return ds:ShowBackgroundImage({Image = args.BackgroundImage, Type = args.DialogType, Effect = args.DialogEffect, Slow = StringToBool(args.Slow, false)});
end

function MissionDirect_HideBackgroundImage(mid, ds, args, conditionOutput)
	return ds:HideBackgroundImage({Slow = StringToBool(args.Slow, false)});
end

function MissionDirect_EnableBlackoutEffect(mid, ds, args, conditionOutput)
	RegisterConnectionRestoreRoutine(mid, 'BlackoutEffect/'..args.Name, function(ds)
		ds:EnableBlackoutEffect(args.Name, args.Area[1].From[1], args.Area[1].To[1]);
	end);
	return ds:EnableBlackoutEffect(args.Name, args.Area[1].From[1], args.Area[1].To[1]);
end

function MissionDirect_DisableBlackoutEffect(mid, ds, args, conditionOutput)
	UnregisterConnectionRestoreRoutine(mid, 'BlackoutEffect/'..args.Name);
	return ds:DisableBlackoutEffect(args.Name);
end

function MissionDirect_ShowFrontmessage(mid, ds, args, conditionOutput)
	return ds:ShowFrontmessage(args.Message, args.MessageColor);
end

function MissionDirect_ShowFrontmessageFormat(mid, ds, args, conditionOutput)
	return ds:ShowFrontmessageWithText(GameMessageFormText(args.GameMessageForm[1], args.MessageColor), args.MessageColor);
end

function MissionDirect_SyncPoint(mid, ds, args, conditionOutput)
	return ds:MissionDirectBlocker();
end

function MissionEndSyncPoint(ds)
	ds:MissionDirectBlocker();
end
function MissionDirect_NamedAssetVisible(mid, ds, args, conditionOutput)
	local key = args.Name;
	local visible = StringToBool(args.Visible, true);
	RegisterConnectionRestoreRoutine(mid, 'NamedAssetVisible'..key, function(ds)
		ds:SetNamedAssetVisible(key, visible);
	end);
	return ds:SetNamedAssetVisible(key, visible);
end
function MissionDirect_LayerAssetVisible(mid, ds, args, conditionOutput)
	local key = args.Name;
	local visible = StringToBool(args.Visible, true);
	RegisterConnectionRestoreRoutine(mid, 'LayerAssetVisible'..key, function(ds)
		ds:SetLayerAssetVisible(key, visible);
	end);
	return ds:SetLayerAssetVisible(key, visible);
end
function MissionDirect_ChangeEquipmentType(mid, ds, args, conditionOutput)
	local u = GetUnitFromUnitIndicator(mid, args.Unit, conditionOutput);
	if u == nil then
		return -1;
	end
	return ds:WorldAction(Result_PropertyUpdated('EquipmentType', args.EquipmentType, u, true, true), false);
end

function MissionDirect_EnablePostEffect(mid, ds, args, conditionOutput)
	local postEffectCls = GetClassList('PostEffect')[args.PostEffectType];
	if not postEffectCls then
		return -1;
	end
	return ds:EnablePostEffect(postEffectCls.PostEffect, args.OnOff == 'On');
end

function MissionDirect_ChangeBattleBGM(mid, ds, args, conditionOutput)
	local mission = GetMission(mid);
	mission.StartBGM = GetClassList('Bgm')[args.StartBGM];
	mission.BattleBGM = GetClassList('Bgm')[args.BattleBGM];
	return ds:RunScriptArgs('ChangeBattleBGM', args.StartBGM, args.BattleBGM, StringToBool(args.Direct, false), tonumber(args.FadeTime) or 3);
end

function MissionDirect_EnableIf(mid, ds, args, conditionOutput)
	local env = {math=math, os=os};
	for i, variable in ipairs(SafeIndex(args, 'Env', 1, 'Variable')) do
		local name = variable.Name;
		local dataBinding = variable.StageDataBinding[1];
		
		local envValue = StageDataBinder(GetMission(mid), dataBinding, conditionOutput);
		env[name] = envValue;
	end
	local argsFunc = loadstring('return '.. args.ArgsExpression);
	setmetatable(env, {__index = _G});
	setfenv(argsFunc, env);
	local argsValue = argsFunc();
	return ds:EnableIf(args.ScriptName, argsValue);
end

function MissionDirect_ShowCredit(mid, ds, args, conditionOutput)
	return ds:ShowCredit({CreditType = args.CreditType or 'None', Slow = StringToBool(args.Slow, false)});
end

function MissionDirect_ShowSplashCustom(mid, ds, args, conditionOutput)
	return ds:RunScript('ShowSplashCustom', {}, false);
end
