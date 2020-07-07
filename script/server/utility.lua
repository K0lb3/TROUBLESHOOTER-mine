function GetApplyActAction(obj, act, isAbilityBuff, actionCategory)
	if actionCategory == 'Hostile' then
		local retImmune, influencers = GetBuffStatus(obj, 'ImmuneDelay_Hostile', 'Or');
		if retImmune then
			return nil, table.map(influencers, function(buff) return {Type = buff.name, Value = true, ValueType = 'Buff'}; end);
		end
	end
	if obj.TurnState.TurnEnded then
		return Result_PropertyAdded('Act', act, obj, 0, GetSystemConstant('MaxActionTime'), nil, true);
	elseif act >= 0 then
		local actions = {};
		InsertBuffActions(actions, obj, obj, 'Delay', act, true, nil, isAbilityBuff);
		return actions[1], {};
	elseif act < 0 then
		local actions = {};
		InsertBuffActions(actions, obj, obj, 'Haste', -act, true, nil, isAbilityBuff);
		return actions[1], {};
	end
	return nil, {};	-- 올일없음
end


function ReasonToBattleEventTable(target, reason, eventType)
	eventType = eventType or 'Beginning';
	if reason.ValueType == 'Buff' then
		return { Object = target, EventType = 'BuffInvokedFromAbility', Args = { Buff = reason.Type, EventType = eventType } };
	elseif reason.ValueType == 'Mastery' then
		return { Object = target, EventType = 'MasteryInvokedCustomEvent', Args = { Mastery = reason.Type, EventType = eventType, MissionChat = true, WorldEventType = '' } };
	else
		-- don't care
		return nil;
	end
end

function ReasonToBattleEventTableMulti(target, reasons, eventType)
	local ret = {};
	for _, reason in ipairs(reasons) do
		local tb = ReasonToBattleEventTable(target, reason, eventType);
		if tb then
			table.insert(ret, tb);
		end
	end
	return ret;
end

function ReasonToAddBattleEvent(target, reason, eventType)
	local tb = ReasonToBattleEventTable(target, reason, eventType);
	if tb == nil then
		return;
	end
	AddBattleEvent(target, tb.EventType, tb.Args);
end

function ReasonToAddBattleEventMulti(target, reasons, eventType)
	local events = GetInstantProperty(obj, 'BattleEvents') or {};
	for _, reason in ipairs(reasons) do
		local tb = ReasonToBattleEventTable(target, reason, eventType);
		if tb then
			if not tb.Args then
				table.insert(events, tb.EventType);
			else
				local eventInst = table.deepcopy(tb.Args);
				eventInst.Type = tb.EventType;
				table.insert(events, eventInst);
			end
		end
	end
	SetInstantProperty(obj, 'BattleEvents', events);
end

function ReasonToUpdateBattleEvent(target, ds, reason, refId, refOffset)
	local objkey = GetObjKey(target);
	local cmdId = nil;
	if reason.ValueType == 'Buff' then
		cmdId = ds:UpdateBattleEvent(objkey, 'BuffInvoked', { Buff = reason.Type });
	elseif reason.ValueType == 'Mastery' then
		cmdId = ds:UpdateBattleEvent(objkey, 'MasteryInvokedCustomEvent', { Mastery = reason.Type, EventType = 'Ending', MissionChat = true, WorldEventType = ''  });
	else
		-- don't care
	end
	if cmdId and refId then
		ds:Connect(cmdId, refId, refOffset);
	end
end

function ReasonToUpdateBattleEventMulti(target, ds, reasons, refId, refOffset)
	for _, reason in ipairs(reasons) do
		ReasonToUpdateBattleEvent(target, ds, reason, refId, refOffset);
	end
end

function FindAbilityUsingInfo(targetInfos, testFunc)
	for _, info in ipairs(targetInfos) do
		if type(info) == 'table' then
			local ret = FindAbilityUsingInfo(info, testFunc);
			if ret then
				return ret;
			end
		else
			if testFunc(info) then
				return info;
			end
		end
	end
	return nil;
end

function HasAnyAbilityUsingInfo(targetInfos, testFunc)
	for _, info in ipairs(targetInfos) do
		if type(info) == 'table' then
			if HasAnyAbilityUsingInfo(info, testFunc) then
				return true;
			end
		else
			if testFunc(info) then
				return true;
			end
		end
	end
	return false;
end

function ForeachAbilityUsingInfo(targetInfos, testFunc)
	for _, info in ipairs(targetInfos) do
		if type(info) == 'table' then
			if ForeachAbilityUsingInfo(info, testFunc) == false then
				return;
			end
		else
			if testFunc(info) == false then
				return;
			end
		end
	end
	return;
end

function FilterAbilityUsingInfo(targetInfos, testFunc)
	local ret = {};
	ForeachAbilityUsingInfo(targetInfos, function(info)
		if testFunc(info) then
			table.insert(ret, info);
		end
	end);
	return ret;
end

function GetTargetListFromAbilityUsingInfo(targetInfos, testFunc)
	local ret = {};
	local targetMap = {};
	ForeachAbilityUsingInfo(targetInfos, function(info)
		if testFunc(info) then
			targetMap[GetObjKey(info.Target)] = info.Target;
		end
	end);
	for _, target in pairs(targetMap) do
		table.insert(ret, target);
	end
	return ret;
end

RandomBuffPicker = {};
function RandomBuffPicker.new(target, buffList)
	local ret = {Target = target, Picker = RandomPicker.new(false)};
	for i, buff in pairs(buffList) do
		ret.Picker:addChoice(1, buff);
	end
	setmetatable(ret, {__index = RandomBuffPicker});
	return ret;
end
function RandomBuffPicker.PickBuff(self, noCheck)
	while true do
		local buffName = self.Picker:pick();
		if buffName == nil then
			return nil;
		end
		if noCheck or GetBuff(self.Target, buffName) == nil then
			return buffName;
		end
	end
	return nil;
end