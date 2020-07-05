function ApplySummonMachineActions(actions, user, target, targetPos)
	table.insert(actions, Result_ChangeTeam(target, GetTeam(user), false));
	local setPos = Result_SetPosition(target, targetPos);
	setPos.sequential = true;
	setPos.forward = true;
	table.insert(actions, setPos);
	table.insert(actions, Result_UpdateUserMember(target, GetTeam(user), true));
	InsertBuffActions(actions, user, target, 'SummonMachine', 1, true, nil, true);
	local pcStateKey = GetPcStateFromConditionValue_Machine(target.CP, target.MaxCP);
	local pcStateCls = GetClassList('PcState')[pcStateKey];
	if pcStateCls and pcStateCls.Buff ~= 'None' then
		InsertBuffActions(actions, user, target, pcStateCls.Buff, 1, true, nil, true);
	end
	table.insert(actions, Result_PropertyUpdated('Act', target.Wait, target, true, true));
	table.insert(actions, Result_PropertyUpdated('TurnState/TurnEnded', true, target, true, true));
	local summonMachines = GetInstantProperty(user, 'SummonMachines') or {};
	table.insert(summonMachines, { Owner = user, Target = target });
	SetInstantProperty(user, 'SummonMachines', summonMachines);
	SetInstantProperty(target, 'SummonMaster', GetObjKey(user));
	SetInstantProperty(target, 'Subordinate', true);
	table.insert(actions, Result_UpdateInstantProperty(target, 'DisableRetreat', true));
	local first = not GetInstantProperty(target, 'SummonBefore');
	SetInstantProperty(target, 'SummonBefore', true);
	local summonCount = GetInstantProperty(target, 'SummonCount') or 0;
	table.insert(actions, Result_UpdateInstantProperty(target, 'SummonCount', summonCount + 1));
	-- 위치 갱신은 이동 이벤트 처리단에서 이루어지지만 이벤트 필터 처리는 액션 처리단계에서 이루어져서 바로 던지면 제대로 핸들링 되지 않는다..
	table.insert(actions, Result_DirectingScript(function(mid, ds, args)
		return Result_FireWorldEvent('FriendlyMachineHasJoined', {Machine = target, FirstJoin = first}, nil, true);
	end));
end
function ApplyUnsummonMachineActions(actions, user, target)
	local setPos = Result_SetPosition(target, InvalidPosition());
	setPos.sequential = true;
	setPos.forward = true;
	local masterKey = GetInstantProperty(target, 'SummonMaster');
	table.insert(actions, Result_FireWorldEvent('FriendlyMachineAboutToLeave', {Machine = target, MasterKey = masterKey}));
	table.insert(actions, Result_RemoveBuff(target, 'SummonMachine'));
	table.insert(actions, setPos);
	table.insert(actions, Result_ChangeTeam(target, '__summon__', false));
	table.insert(actions, Result_UpdateUserMember(target, GetTeam(user), false));
	local summonMachines = GetInstantProperty(user, 'SummonMachines') or {};
	summonMachines = table.filter(summonMachines, function(m) return m.Target ~= target; end);
	SetInstantProperty(user, 'SummonMachines', summonMachines);
	SetInstantProperty(target, 'SummonMaster', nil);
	local unsummonCount = GetInstantProperty(target, 'UnsummonCount') or 0;
	table.insert(actions, Result_UpdateInstantProperty(target, 'UnsummonCount', unsummonCount + 1));
end