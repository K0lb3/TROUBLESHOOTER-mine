--------------------------------------------------------------------------------------------
--- Dashboard 업데이트 값은 다음과 같다.
-- Mode: None(비활성화), InProgress(진행중), Completed(완료), Failed(실패)
--------------------------------------------------------------------------------------------
function UpdateDashboardCore(mission, dashboardKey, command, ...)
	local dashboard = GetMissionDashboard(mission, dashboardKey);
	if dashboard == nil then
		LogAndPrint(debug.traceback());
		LogAndPrint('Dashboard Not Exist:' .. dashboardKey);
		return nil;
	end
	
	local updatedDashboards = {{dashboardKey, dashboard}};
	
	local CommandToAction = {
		-- 아래에 커맨드를 추가하면 됨
		ResetVariableCount = 	function(o)
		                            o.Count = GetStageVariable(mission, dashboard.Variable);
								end,
		Hide = 					function(o) 
									-- LogAndPrint('UpdateDashboardCoreHide', dashboardKey)
									o.Show = false
								end,
		ClearCheckList = 		function(o) 
									o.Show = true;
									o.Mode = 'Completed' 
								end,
		Fail =					function(o) o.Mode = 'Failed' end,
		RescueOne = 			function(o)
									o.Left = o.Left - 1;
									o.Rescued = o.Rescued + 1;
								end,
		RescueFailOne = 		function(o)
									o.Left = o.Left - 1;
									o.Dead = o.Dead + 1;
								end,
		RescueAll =				function(o)
									o.Rescued = o.Rescued + o.Left;
									o.Left = 0;
								end,
		RescueFailAll =			function(o)
									o.Dead = o.Dead + o.Left;
									o.Left = 0;
								end,
		TurnEnd = 				function(o)
									o.Turn = o.Turn - 1;
								end,
		UpdateMainPanel =		function(o, slotKey, state)
									if o[slotKey].State == state then
										--LogAndPrint('Same');
										return;
									end
									-- LogAndPrint('UpdateMainPanel', slotKey, state);
									o[slotKey].State = state;
								end,
		UpdateObjectiveMessage = function(o, slotKey, title)
									-- LogAndPrint('UpdateObjectiveMessage', slotKey, title);
									o[slotKey].Message = title;
								end,
		CountDown =				function(o, count)
									o.Count = o.Count - (count or 1);
								end,
		CountUp =				function(o, count)
									o.Count = o.Count + (count or 1);
								end,
		ResetCount = 			function(o, count)
									o.Count = count or 0;
								end,
		Clear = 				function(o)
									o.Clear = true;
								end,
		Show =					function(o)
									o.Show = true;
								end,
		ResetRescueCount =		function(o, count) 
									o.Left = tonumber(count);
								end,
		TimeElapsed = 			function(o, elapsed)
									if o.Active then
										o.ElapsedTime = o.ElapsedTime + elapsed;
									else
										o.WastedTime = o.WastedTime + elapsed;
									end
								end,
		Activate = 				function(o, active)
									o.Active = StringToBool(active, true);
									if o.name == 'TimeLimiter' then
										if o.Active then
											ReserveTimerEvent(mission, 'TimeLimiter_'..dashboardKey, o.LimitTime - o.ElapsedTime);
										else
											DropTimerEvent(mission, 'TimeLimiter_'..dashboardKey);
										end
									end
								end,
		Deactivate = 			function(o, deactive)
									o.Active = not StringToBool(deactive, true);
									if o.name == 'TimeLimiter' then
										if o.Active then
											ReserveTimerEvent(mission, 'TimeLimiter_'..dashboardKey, o.LimitTime - o.ElapsedTime);
										else
											DropTimerEvent(mission, 'TimeLimiter_'..dashboardKey);
										end
									end
								end,
		ResetTimer = 			function(o)
									o.WastedTime = o.WastedTime + o.ElapsedTime;
									o.ElapsedTime = 0;
									if o.Active then
										ReserveTimerEvent(mission, 'TimeLimiter_'..dashboardKey, o.LimitTime - o.ElapsedTime);
									else
										DropTimerEvent(mission, 'TimeLimiter_'..dashboardKey);
									end
								end,
		UpdateMarker = 			function(o, marker)
									o.MarkerImage = marker;
								end,
		UpdateMessage = 		function(o, message)
									o.Message = message;
								end,

		__index = function(t, key) return function(o) Log(string.format("invalid UpdateDashboard Command %s", tostring(command))) end end
	};
	setmetatable(CommandToAction, CommandToAction);
	CommandToAction[command](dashboard, unpack(arg));
	local actions = {};
	for _, updatedDashboard in ipairs(updatedDashboards) do
		table.insert(actions, Result_UpdateDashboard(updatedDashboard[1], updatedDashboard[2]));
	end
	return unpack(actions);
end

function InitializeRescueDashboard(dashboard, dashboardKey, mission, stage, dashboardDeclaration, reinitialize)
	SubscribeGlobalWorldEvent(mission, 'CitizenRescued', function(eventArg, ds)
		return UpdateDashboardCore(mission, dashboardKey, 'RescueOne');
	end);
	SubscribeGlobalWorldEvent(mission, 'CitizenRescueFailed', function(eventArg, ds)
		return UpdateDashboardCore(mission, dashboardKey, 'RescueFailOne');
	end);
	if not reinitialize then
		SubscribeGlobalWorldEvent(mission, 'MissionBegin', function(eventArg, ds)
			local units = GetAllUnit(mission);
			local count = 0;
			for i, unit in ipairs(units) do
				if unit.Team == 'citizen' then
					count = count + 1;
				end
			end
			return UpdateDashboardCore(mission, dashboardKey, 'ResetRescueCount', count);
		end, 0);
	end
end

function InitializeTimeLimiter(dashboard, dashboardKey, mission, stage, dashboardDeclaration, reinitialize)
	SubscribeGlobalWorldEvent(mission, 'TimeElapsed', function(eventArg, ds)
		if eventArg.ElapsedTime <= 0 then
			return;
		end
		return UpdateDashboardCore(mission, dashboardKey, 'TimeElapsed', eventArg.ElapsedTime);
	end);
	if not reinitialize then
		if dashboardDeclaration.TimerMode == 'Escape' then
			dashboard.LimitTime = dashboard.LimitTime + GetMissionStatus(mission, 'EscapeTimeBonus', StatusOperator.Max)
		end
		
		if dashboard.Active then
			ReserveTimerEvent(mission, 'TimeLimiter_'..dashboardKey, dashboard.LimitTime - dashboard.ElapsedTime);
		end
	end
end

function InitializeCounterDashboard(dashboard, dashboardKey, mission, stage, dashboardDeclaration, reinitialize)
	local activated = reinitialize;
	if not reinitialize then
		SubscribeGlobalWorldEvent(mission, 'MissionPrepare', function(eventArg, ds)
			activated = true;
			local variable = GetStageVariable(mission, dashboardDeclaration.Variable);
			--LogAndPrint('InitializeCounterDashboard', 'MissionPrepare', dashboardDeclaration.Variable, variable);
			return UpdateDashboardCore(mission, dashboardKey, 'ResetCount', tonumber(variable));
		end);
	end
	if StringToBool(dashboardDeclaration.Linked, false) then
		SubscribeGlobalWorldEvent(mission, 'StageVariableUpdated', function(eventArg, ds)
			if not activated or eventArg.Key ~= dashboardDeclaration.Variable then
				return;
			end
			--LogAndPrint('InitializeCounterDashboard', 'StageVariableUpdated', dashboardDeclaration.Variable, eventArg.Value);
			return UpdateDashboardCore(mission, dashboardKey, 'ResetCount', tonumber(eventArg.Value));
		end);
	end
end

function InitializeEscapeAreaDashboard(dashboard, dashboardKey, mission, stage, dashboardDeclaration, reinitialize)
	local from = dashboardDeclaration.Area[1].From[1];
	local to = dashboardDeclaration.Area[1].To[1];
	
	SubscribeGlobalWorldEvent(mission, 'UnitMoved', function(eventArg, ds)
		if not PositionInArea(from, to, eventArg.Position) then
			return;
		end
		return Result_FireWorldEvent('UnitArrivedEscapeArea', {Unit=eventArg.Unit, Dashboard=dashboard});
	end);
	SubscribeGlobalWorldEvent(mission, 'UnitPositionChanged', function(eventArg, ds)
		if not PositionInArea(from, to, eventArg.Position) then
			return;
		end
		return Result_FireWorldEvent('UnitArrivedEscapeArea', {Unit=eventArg.Unit, Dashboard=dashboard});
	end);
	SubscribeGlobalWorldEvent(mission, 'UnitTurnStart', function(eventArg, ds)
		if not PositionInArea(from, to, GetPosition(eventArg.Unit)) then
			return;
		end
		
		return Result_FireWorldEvent('UnitArrivedEscapeArea', {Unit=eventArg.Unit, Dashboard=dashboard});
	end);
	SubscribeGlobalWorldEvent(mission, 'BuffAdded', function(eventArg, ds)
		if eventArg.BuffName ~= 'Civil_Confusion'
			and eventArg.BuffName ~= 'Civil_Stabilized'
			and eventArg.BuffName ~= 'Civil_Unrest'
			and eventArg.BuffName ~= 'FakeRescueRevealed' then
			return;
		end
		if not PositionInArea(from, to, GetPosition(eventArg.Unit)) then
			return;
		end
		return Result_FireWorldEvent('UnitArrivedEscapeArea', {Unit=eventArg.Unit, Dashboard=dashboard});
	end);
end

function InitializeEscortCounterDashboard(dashboard, dashboardKey, mission, stage, dashboardDeclaration, reinitialize)
	if not reinitialize then
		SubscribeGlobalWorldEvent(mission, 'MissionBegin', function(eventArg, ds)
			return UpdateDashboardCore(mission, dashboardKey, 'ResetCount', GetStageVariable(mission, '_escort_target_cnt_'));
		end);
	end
	SubscribeGlobalWorldEvent(mission, 'EscortComplete', function(eventArg, ds)
		dashboard.Success = dashboard.Success + 1;
		return UpdateDashboardCore(mission, dashboardKey, 'CountDown');
	end);
	SubscribeGlobalWorldEvent(mission, 'EscortFailed', function(eventArg, ds)
		dashboard.Failed = dashboard.Failed + 1;
		return UpdateDashboardCore(mission, dashboardKey, 'CountDown');
	end);
end

function InitializeInformationCollectorDashboard(dashboard, dashboardKey, mission, stage, dashboardDeclaration, reinitialize)
	SubscribeGlobalWorldEvent(mission, 'InformationAcquired', function(eventArg, ds)
		return UpdateDashboardCore(mission, dashboardKey, 'CountDown');
	end);
	if not reinitialize then
		SubscribeGlobalWorldEvent(mission, 'MissionBegin', function(eventArg, ds)
			local picker = RandomPicker.new(false);
			
			local units = GetAllUnit(mission);
			local secretAgentCount = 0;
			for i, unit in ipairs(units) do
				local informationPriority = GetInstantProperty(unit, 'InformationPriority');
				if informationPriority then
					picker:addChoice(informationPriority, unit);
				end
				if GetTeam(unit) == 'secret_agent' then
					secretAgentCount = secretAgentCount + 1;
				end
			end
			
			local infoCount = dashboard.Count - secretAgentCount;
			if infoCount < 0 then
				LogAndPrint('DataError::', 'DashboardCount < SecretAgentCount');
				return;
			end
			
			for i = 1, infoCount do
				local unit = picker:pick();
				if unit == nil then
					-- 정보를 배치할 대상이 없음.. 목표 카운트를 내리자
					LogAndPrint('DataError::', 'InformationHolder Not Enought');
					return UpdateDashboardCore(mission, dashboardKey, 'ResetCount', dashboard.Count - (infoCount - i + 1));
				end
				SetInstantProperty(unit, 'InformationOwner', true);
			end
		end);
	end
end

function InitializeHitListDashboard(dashboard, dashboardKey, mission, stage, dashboardDeclaration, reinitialize)
	if not reinitialize then
		local hitList = {};
		for i, objKey in ipairs(SafeIndex(dashboardDeclaration, 'ObjectKeyList', 1, 'ObjectKey') or {}) do
			hitList[objKey.ObjectKey] = true;
		end
		local count = 0;
		for _ in pairs(hitList) do
			count = count + 1;
		end
		
		dashboard.Count = count;
	end
	SubscribeGlobalWorldEvent(mission, 'UnitDead', function(eventArg, ds)
		if hitList[GetObjKey(eventArg.Unit)] == nil then
			return;
		end
		hitList[GetObjKey(eventArg.Unit)] = nil;
		return UpdateDashboardCore(mission, dashboardKey, 'CountDown');
	end);
end

function InitializePsionicStoneDashboard(dashboard, dashboardKey, mission, stage, dashboardDeclaration, reinitialize)
	if not reinitialize then
		local minCount = math.min(dashboardDeclaration.MinCount, dashboardDeclaration.MaxCount);
		local maxCount = math.max(dashboardDeclaration.MinCount, dashboardDeclaration.MaxCount);
		dashboard.Count = math.random(minCount, maxCount);
	end
	
	SubscribeGlobalWorldEvent(mission, 'InvestigationPsionicOccuredGlobal', function(eventArg, ds)
		if eventArg.DashboardKey ~= dashboardKey then
			return;
		end	
		return UpdateDashboardCore(mission, dashboardKey, 'CountDown');
	end);
end

function CollectItemDashboardLoader(declare, inst)
	inst.CollectItemSet = declare.CollectItemSet;
end

function InitializeCollectItemDashboard(dashboard, dashboardKey, mission, stage, dashboardDeclaration, reinitialize)	
	local collectItemSet = dashboard.CollectItemSet;
	local collectSetCls = GetClassList('CollectItemSet')[collectItemSet];
	if collectSetCls == nil then
		return;
	end
	local createMonType = SafeIndex(collectSetCls, 'BaseMonType') or 'Object_CargoBox';
	local replaceMonType = SafeIndex(collectSetCls, 'ReplaceMonType') or 'Object_CargoBox_Opened';
	local interactionType = SafeIndex(collectSetCls, 'InteractionType') or 'OpenCargo';
	local markerIcon = SafeIndex(collectSetCls, 'MarkerIcon') or 'Icons/Transport';
	local componentKey = 'CollectItem'..dashboard.Key;
	
	local maxCount = 0;
	for _, company in ipairs(GetAllCompanyInMission(mission)) do
		maxCount = math.max(maxCount, table.count(collectSetCls.LinkedQuest, function(questCls)
			local stage, progress = GetQuestState(company, questCls.name);
			local ret = SafeIndex(questCls, 'LinkedMissions', mission.name) 
			return questCls.LinkedMissions[mission.name] and stage == 'InProgress' and not CheckRequestState(company, questCls, progress, function(itemType) 
				return GetInventoryItemCount(company, itemType);
			end);
		end));
	end
	
	if maxCount == 0 then
		dashboard.Show = false;
		return;
	end
	
	local SharedPerUnitRegister = function(mon)
		EnableInteraction(mon, interactionType);
		SubscribeWorldEvent(mon, 'UnitInteractObject_Self', function(eventArg, ds)
			if eventArg.Target ~= mon then
				return;
			end
			local actions = {ReplaceMonster(ds, mon, replaceMonType, true)};
			ds:PlaySound("Success.wav", 'Layout', 1.0, true);
			ds:ShowFrontmessageWithText(FormatMessageText(ClassDataText('CollectItemSet', collectItemSet, 'CollectMessage'), {Unit = ClassDataText('ObjectInfo', eventArg.Unit.Info.name, 'Title')}), 'Corn');
			
			table.insert(actions, Result_FireWorldEvent('CollectItemCollected', {CollectItemSet = collectItemSet, Collector = eventArg.Unit, Item = eventArg.Target}));
			return unpack(actions);
		end);
	end;
	
	SubscribeGlobalWorldEvent(mission, 'QuestProgressSatisfied', function(eventArg, ds)
		if not table.exist(collectSetCls.LinkedQuest, function(questCls) 
					return questCls.name == eventArg.QuestType;
				end) then
			return;
		end
		maxCount = maxCount - 1;
		if maxCount > 0 then
			return;
		end
		
		local actions = {UpdateDashboardCore(mission, dashboard.Key, 'Hide')};
		for _, mon in ipairs(RetrieveAllMapComponentObject(mission, componentKey)) do
			if not IsDead(mon) then
				table.insert(actions, Result_UpdateInteraction(mon, interactionType, false));
			end
		end
		return unpack(actions);
	end);
	
	if reinitialize then
		for _, mon in ipairs(RetrieveAllMapComponentObject(mission, componentKey)) do
			SharedPerUnitRegister(mon);
		end
		return;
	end
	
	local genMin = dashboardDeclaration.MinCount;
	local genMax = dashboardDeclaration.MaxCount;
	local posHolder = dashboardDeclaration.PosHolderGroup;
	
	local actions = {};
	local genCount = math.random(genMin, genMax);
	local positionHolders = table.shuffle(table.filter(GetPositionHolders(mission), function(ph) return ph.Group == posHolder; end));
	for i = 1, genCount do
		if #positionHolders == 0 then
			LogAndPrint('no more PositionHolder is available', dashboardDeclaration.Key, posHolder);
			break;
		end
		
		local unitKey = GenerateUnnamedObjKey(mission);
		local ph = table.remove(positionHolders);
		local mon = CreateMonster(GetMissionID(mission), unitKey, createMonType, 'CollectItem_'..dashboard.Key, ph.Position, ph.Direction);
		SetInstantPropertyWithUpdate(mon, 'MonsterType', createMonType);
		InitObjectFromMonster(mon, GetClassList('Monster')[createMonType]);
		RegisterMapComponentObject(mission, componentKey, i, mon);
		UNIT_INITIALIZER(mon, mon.Team);
		SetSightSharingCustom(mon, 'player', true, 0);
		SharedPerUnitRegister(mon);
	end
end

function ArrestDashboardLoader(declare, inst)
	inst.ArrestSet = declare.ArrestSet;
	inst.Team = declare.Team;
end
function InitializeArrestDashboard(dashboard, dashboardKey, mission, stage, dashboardDeclaration, reinitialize)	
	local arrestSet = dashboard.ArrestSet;
	local arrestSetCls = GetClassList('ArrestSet')[arrestSet];
	if arrestSetCls == nil then
		return;
	end
	local createMonType = SafeIndex(arrestSetCls, 'BaseMonType');
	local markerIcon = SafeIndex(arrestSetCls, 'MarkerIcon') or 'Icons/Transport';
	local componentKey = 'Arrest'..dashboard.Key;
	
	local maxCount = 0;
	for _, company in ipairs(GetAllCompanyInMission(mission)) do
		maxCount = math.max(maxCount, table.count(arrestSetCls.LinkedQuest, function(questCls)
			local stage, progress = GetQuestState(company, questCls.name);
			return questCls.LinkedMissions[mission.name] and stage == 'InProgress' and not CheckRequestState(company, questCls, progress);
		end));
	end
	
	if maxCount == 0 then
		dashboard.Show = false;
		return;
	end
	
	local SharedPerUnitRegister = function(mon)
		SubscribeWorldEvent(mon, 'UnitDead_Self', function(eventArg, ds)
			if eventArg.Unit ~= mon then
				return;
			end
			local killer = eventArg.Killer;
			if not killer then
				return;
			end
			local damageInfo = SafeIndex(eventArg, 'DamageInfo');
			if damageInfo and damageInfo.damage_type == 'Buff' then
				local buff = damageInfo.damage_invoker;
				expTaker = GetExpTaker(buff);
			else
				expTaker = GetExpTaker(killer);
			end
			if not GetCompany(expTaker) then
				return;
			end
			ds:PlaySound("Success.wav", 'Layout', 1.0, true);
			local formatTable = {};
			formatTable.Unit = ClassDataText('ObjectInfo', eventArg.Unit.Info.name, 'Title');
			formatTable.Killer = ClassDataText('ObjectInfo', expTaker.Info.name, 'Title');
			ds:ShowFrontmessageWithText(FormatMessageText(ClassDataText('ArrestSet', arrestSet, 'ArrestMessage'), formatTable), 'Corn');
			
			local actions = {};
			table.insert(actions, Result_FireWorldEvent('ArrestUnitKilled', {ArrestSet = arrestSet, Unit = eventArg.Unit, Killer = eventArg.Killer}));
			return unpack(actions);
		end);
		if arrestSetCls.AutoRetreat then
			SetInstantProperty(mon, 'AutoRetreat', true);
			SubscribeWorldEvent(mon, 'RunIntoBattle', function(eventArg, ds)
				if eventArg.Unit ~= mon then
					return;
				end
				local actions = {};
				local objKey = GetObjKey(mon);
				local turnCount = 4;
				ds:UpdateAttachingWindow(objKey, 'ObjectMarker', 'UpdateObjectObjectMarker', PackTableToString({ TurnCount = turnCount }));
				table.insert(actions, Result_UpdateInstantProperty(mon, 'RetreatCounter', turnCount));
				table.insert(actions, Result_SightSharingCustom(mon, 'player', true, 0));
				return unpack(actions);
			end);
			SubscribeWorldEvent(mon, 'UnitTurnStart_Self', function(eventArg, ds)
				if eventArg.Unit ~= mon then
					return;
				end
				local counter = GetInstantProperty(mon, 'RetreatCounter');
				if not counter then
					return;
				end
				local actions = {};
				local objKey = GetObjKey(mon);
				local nextCount = math.max(counter - 1, 0);
				if counter ~= nextCount then
					ds:UpdateAttachingWindow(objKey, 'ObjectMarker', 'UpdateObjectObjectMarker', PackTableToString({ TurnCount = nextCount }));
					table.insert(actions, Result_UpdateInstantProperty(mon, 'RetreatCounter', nextCount));
				end
				if nextCount > 0 then
					return unpack(actions);
				end
				-- 이동 불가
				if not mon.Movable then
					return unpack(actions);
				end
				-- 기절, 혼란 비슷한 것들 체크
				if HasActionControllerTest(mon, { 'DoNothingAI', 'ConfusionAI' }) then
					return unpack(actions);
				end
				
				local movePos = FindAIMovePosition(mon, {FindMoveAbility(mon)}, function (self, adb)
					local score = 1000;
					-- 일단 적하고 붙지 않으려고 한다.
					score = score + adb.MinEnemyDistance * 20;
					-- 근처의 적 수가 많으면 싫어함
					score = score - adb.Dangerous * 20;
					-- 가장 멀리 갈 수 있는 아무데나
					score = score + adb.MoveDistance * 20;
					return score;	
				end, {}, {});
				
				-- 연출 전처리
				ds:StartMissionDirect(true);
				ds:MissionSubInterfaceVisible(false);
				ds:ChangeStatusVisible(false);
				ds:SkipPointOn();
				
				-- 퇴각 연출 
				ds:ChangeCameraTarget(objKey, '_SYSTEM_', false, false, 1);
				local chatText = ClassDataText('ArrestSet', arrestSet, 'RetreatChat')
				ds:UpdateBalloonChatWithText(objKey, chatText, 'Normal_Enemy', 'NotoSansMedium-16_Auto', nil, 2.5);
				ds:Sleep(arrestSetCls.RetreatChatInterval);
				ds:FreeCamera();
				ds:Move(objKey, movePos, false, false, nil, 0, 0, false, 1, true, true, true, true);
				ds:SceneFadeOut('', false);
				ds:HideObject(objKey);
				local formatTable = {};
				formatTable.Unit = ClassDataText('ObjectInfo', eventArg.Unit.Info.name, 'Title');
				ds:ShowFrontmessageWithText(FormatMessageText(ClassDataText('ArrestSet', arrestSet, 'RetreatMessage'), formatTable), 'Corn');
				ds:Sleep(0.5);
				ds:SceneFadeIn('', false);
				
				-- 연출 후처리
				ds:SkipPointOff();
				ds:ChangeStatusVisible(true);
				ds:MissionSubInterfaceVisible(true);
				ds:EndMissionDirect(true);
				
				-- 액션 처리
				table.insert(actions, Result_UpdateInstantProperty(mon, 'RetreatCounter', nil));
				local setPos = Result_SetPosition(mon, InvalidPosition());
				setPos.sequential = true;
				table.insert(actions, setPos);
				table.insert(actions, Result_FireWorldEvent('UnitBeingExcluded', {Unit = mon, AllowInvalidPosition = true}));
				table.insert(actions, Result_DestroyObject(mon, false, true));
				return unpack(actions);
			end);
		end
	end;
	
	SubscribeGlobalWorldEvent(mission, 'QuestProgressSatisfied', function(eventArg, ds)
		if not table.exist(arrestSetCls.LinkedQuest, function(questCls) 
			return questCls.name == eventArg.QuestType;
		end) then
			return;
		end
		maxCount = maxCount - 1;
		if maxCount > 0 then
			return;
		end
		
		local actions = {UpdateDashboardCore(mission, dashboard.Key, 'Hide')};
		return unpack(actions);
	end);
	
	if reinitialize then
		for _, mon in ipairs(RetrieveAllMapComponentObject(mission, componentKey)) do
			SharedPerUnitRegister(mon);
		end
		return;
	end
	
	local genMin = dashboardDeclaration.MinCount;
	local genMax = dashboardDeclaration.MaxCount;
	local posHolder = dashboardDeclaration.PosHolderGroup;
	
	local actions = {};
	local genCount = math.random(genMin, genMax);
	local positionHolders = table.shuffle(table.filter(GetPositionHolders(mission), function(ph) return ph.Group == posHolder; end));
	for i = 1, genCount do
		if #positionHolders == 0 then
			LogAndPrint('no more PositionHolder is available', dashboardDeclaration.Key, posHolder);
			break;
		end
		
		local unitKey = GenerateUnnamedObjKey(mission);
		local ph = table.remove(positionHolders);
		local mon = CreateMonster(GetMissionID(mission), unitKey, createMonType, dashboardDeclaration.Team, ph.Position, ph.Direction);
		SetInstantPropertyWithUpdate(mon, 'MonsterType', createMonType);
		SetInstantPropertyWithUpdate(mon, 'ArrestSet', arrestSet);
		InitObjectFromMonster(mon, GetClassList('Monster')[createMonType]);
		RegisterMapComponentObject(mission, componentKey, i, mon);
		if dashboardDeclaration.AI then
			local aiArg = table.deepcopy(dashboardDeclaration.AI[1]);
			local aiType = SafeIndex(aiArg, 'AIType');
			if aiType == nil or aiType == 'None' then
				aiType = 'NormalMonsterAI';
			end
			aiArg.AIType = nil;
			SetMonsterAIInfo(mon, aiType, aiArg);
		end
		local dataTable = {};
		dataTable.StartingBuff = dashboardDeclaration.StartingBuff;
		dataTable.AngerBuff = dashboardDeclaration.AngerBuff;
		UNIT_INITIALIZER(mon, mon.Team, dataTable);
		if arrestSetCls.SightSharing then
			SetSightSharingCustom(mon, 'player', true, 0);
		end
		SharedPerUnitRegister(mon);
	end
end

function ObjectiveMarkerLoader(declare, inst)
	-- table.print(declare);
	inst.Show = declare.Show;
	inst.Message = declare.Message;
	if declare.CustomImage ~= '' then
		inst.MarkerImage = declare.CustomImage;
	end
	local assetKey = declare.NamedAssetKey;
	if assetKey and assetKey ~= '' then
		inst.AssetKey = assetKey;
	end
	inst.YOffset = declare.YOffset or 0;
	local  targetType = SafeIndex(declare, 'PositionIndicator', 1, 'Type');
	if targetType == 'Object' then
		inst.Unit = SafeIndex(declare, 'PositionIndicator', 1, 'ObjectKey');
	elseif targetType == 'Position' then
		inst.Position = SafeIndex(declare, 'PositionIndicator', 1, 'Position', 1);
	elseif targetType == 'CenterOfArea' then
		local from = SafeIndex(declare, 'PositionIndicator', 1, 'Area', 1, 'From', 1)
		local to = SafeIndex(declare, 'PositionIndicator', 1, 'Area', 1, 'To', 1)
		if not from or not to then
			inst.Position = InvalidPosition();
			return;
		end
		local cx = (from.x + to.x) / 2;
		local cy = (from.y + to.y) / 2;
		local cz = (from.z + to.z) / 2;
		local cpos = { x = math.floor(cx), y = math.floor(cy), z = math.floor(cz) };
		local offset = { x = cx - cpos.x, y = cy - cpos.y };
		inst.Position = cpos;
		inst.Offset = offset;
		inst.From = from;
		inst.To = to;
	end
end