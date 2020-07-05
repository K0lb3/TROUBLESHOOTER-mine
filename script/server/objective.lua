function PlayTriggerAction(mission, ds, actions, conditionOutput, doFunc)
	if actions == nil then
		return {};
	end
	local retActions = {};
	local actionClsList = GetClassList('Action');
	for i, action in ipairs(actions) do
		local actionCls = actionClsList[action.Type];
		local actionArg = {};
		for i, argCls in ipairs(actionCls.ArgumentList) do
			table.insert(actionArg, action[argCls.name]);
		end
		for i, action in ipairs({_G[actionCls.Script](GetMissionID(mission), ds, conditionOutput or {}, unpack(actionArg))}) do
			if doFunc then
				doFunc(action);
			else
				table.insert(retActions, action);
			end
		end
	end
	LogAndPrint('PlayTriggerAction End', #retActions);
	return retActions;
end

function PlayTriggerActionUnpack(mission, ds, actions, conditionOutput)
	return unpack(PlayTriggerAction(mission, ds, actions, conditionOutput));
end

function MissionObjectiveInitializer_DashboardEvaluator(mission, objective, panelKey, reinitialize)
	local cleared = nil;
	if reinitialize then
		local mainPanel = GetMissionDashboard(mission, DASHBOARD_MAIN_PANEL_KEY);
		if mainPanel[panelKey].State == 'Completed' or mainPanel[panelKey].State == 'Failed' then
			-- 이미 달성됨
			return;
		end
	end
	SubscribeGlobalWorldEvent(mission, 'DashboardUpdated', function (eventArg, ds)
		if cleared 
			or eventArg.Key ~= objective.DashboardKey then
			return;
		end
		local dashboard = GetMissionDashboard(mission, eventArg.Key);
		local testEnv = {math=math, dashboard = dashboard};
		local successExpression = objective.SuccessExpression;
		local testFunc = loadstring('return ' .. successExpression);
		setfenv(testFunc, testEnv);
		if testFunc() then	-- 성공!
			cleared = true;
			local triggerActions = PlayTriggerAction(mission, ds, SafeIndex(objective, 'OnSuccessActionList', 1, 'Action'));
			table.insert(triggerActions, UpdateDashboardCore(mission, DASHBOARD_MAIN_PANEL_KEY, 'UpdateMainPanel', panelKey, 'Completed'));
			--table.print(triggerActions, LogAndPrint);
			return unpack(triggerActions);
		end
		
		local failExpression = objective.FailExpression;
		if failExpression then
			testFunc = loadstring('return ' .. failExpression);
			setfenv(testFunc, testEnv);
			if testFunc() then -- 실패!
				cleared = true;
				local triggerActions = PlayTriggerAction(mission, ds, SafeIndex(objective, 'OnFailActionList', 1, 'Action'));
				table.insert(triggerActions, UpdateDashboardCore(mission, DASHBOARD_MAIN_PANEL_KEY, 'UpdateMainPanel', panelKey, 'Failed'));
				if objective.LoseOnFail and panelKey ~= 'MainObjective' then
					table.insert(triggerActions,Result_EndMission('enemy'));
				end
				--table.print(triggerActions);
				return unpack(triggerActions);
			end
		end
	end);
end

function MissionObjectiveInitializer_Condition(mission, objective, panelKey, reinitialize)
	if reinitialize then
		-- 컨디션 타입 오브젝티브 핸들러는 트리거 리로드에 의하여 자동으로 리로드된다.
		return;
	end
	
	local isRepeat = true;
	if objective.Key == mission.Objectives.MainObjective.Key then
		isRepeat = false;
	end
	local successCondition = nil;
	local failCondition = nil;
	if type(objective.SuccessCondition) ~= 'string' then
		successCondition = SafeIndex(objective, 'SuccessCondition', 1);
	end
	if type(objective.FailCondition) ~= 'string' then
		failCondition = SafeIndex(objective, 'FailCondition', 1);
	end
	if successCondition then
		local triggerActions = SafeIndex(objective, 'OnSuccessActionList', 1, 'Action') or {};
		table.insert(triggerActions, {Type='UpdateDashboard', DashboardKey=DASHBOARD_MAIN_PANEL_KEY, Command={{Value='UpdateMainPanel'}, {Value=panelKey}, {Value='Completed'}}});
		RegisterTrigger(mission, successCondition, isRepeat, unpack(triggerActions));
	end
	if failCondition then
		local triggerActions = SafeIndex(objective, 'OnFailActionList', 1, 'Action') or {};
		table.insert(triggerActions, {Type='UpdateDashboard', DashboardKey=DASHBOARD_MAIN_PANEL_KEY, Command={{Value='UpdateMainPanel'}, {Value=panelKey}, {Value='Failed'}}});
		if objective.LoseOnFail and panelKey ~= 'MainObjective' then
			table.insert(triggerActions, {Type='Lose'});
		end
		RegisterTrigger(mission, failCondition, isRepeat, unpack(triggerActions));
	end
end