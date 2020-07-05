function AbilityDirectingEventFormat_Empty(cls, eventArg)
	return {};
end
function AbilityDirectingEventFormat_BuffImmuned(cls, eventArg)
	local reason = AbilityDirectingEventFormat_Reason(cls, eventArg);
	return {Buff = GetClassList('Buff')[eventArg.Buff].Title, Reason = reason.Reason};
end
function AbilityDirectingEventFormat_Reason(cls, eventArg)
	local reason;
	if eventArg.Reason:sub(1,8) == 'Mastery_' then
		local masteryName = eventArg.Reason:sub(9);
		local mastery = GetClassList('Mastery')[masteryName];
		reason = mastery.Title;
	elseif eventArg.Reason:sub(1,5) == 'Buff_' then
		local buffName = eventArg.Reason:sub(6);
		local buff = GetClassList('Buff')[buffName];
		reason = buff.Title;
	else
		reason = GetWord(eventArg.Reason)
	end
	return {Reason = reason};
end
function AbilityDirectingEventFormat_AddWait(cls, eventArg)
	if eventArg.Time >= 0 then
		return {Time = string.format('+%d', eventArg.Time)};
	else
		return {Time = string.format('%d', eventArg.Time)};
	end
end
function AbilityDirectingEventFormat_AddCost(cls, eventArg)
	local costTypeList = GetClassList('CostType');
	if eventArg.Count >= 0 then
		return {Count = string.format('+%d', eventArg.Count), Cost = costTypeList[eventArg.CostType].Title};
	else
		return {Count = string.format('%d', eventArg.Count), Cost = costTypeList[eventArg.CostType].Title};
	end
end
function AbilityDirectingEventFormat_BuffName(cls, eventArg)
	return {Buff = GetClassList('Buff')[eventArg.Buff].Title};
end
function AbilityDirectingEventFormat_BuffRemainTurn(cls, eventArg)
	return {Buff = GetClassList('Buff')[eventArg.Buff].Title, Remain = eventArg.Remain};
end
function AbilityDirectingEventFormat_HackingRemainTurn(cls, eventArg)
	return {Remain = eventArg.Remain};
end
function AbilityDirectingEventFormat_AssassinationProgress(cls, eventArg)
	return {Current = eventArg.Current, Target = eventArg.Target};
end
function AbilityDirectingEventFormat_GetWord(cls, eventArg)
	return {Word = GetWord(eventArg.Word)};
end
function AbilityDirectingEventFormat_MasteryName(cls, eventArg)
	return {Mastery = GetClassList('Mastery')[eventArg.Mastery].Title};
end
function AbilityDirectingEventFormat_AbilityName(cls, eventArg)
	return {Ability = GetClassList('Ability')[eventArg.Ability].Title};
end
function AbilityDirectingEventFormat_GreatName(cls, eventArg)
	return {Great = GetClassList('PerformanceGreat')[eventArg.Great].Title};
end
function AbilityDirectingEventFormat_GreatLv(cls, eventArg)
	if eventArg.GreatLv > 5 then
		return {Lv = 'MAX'};
	elseif eventArg.GreatLv > 0 then
		return {Lv = eventArg.GreatLv..'+'};
	else
		return {Lv = eventArg.GreatLv};
	end
end

function AbilityDirectingEventColor_Default(cls, eventArg)
	return cls.Color;
end
function AbilityDirectingEventColor_EventArg(cls, eventArg)
	if eventArg.Color ~= nil then
		return eventArg.Color;
	else
		return cls.color;
	end
end
function AbilityDirectingEventColor_Buff(cls, eventArg)
	local buff = GetClassList('Buff')[eventArg.Buff];
	if buff.Type == 'Debuff' then
		return 'Red';
	elseif buff.Type == 'Buff' then
		return 'DodgerBlue';
	else
		return 'Yellow';
	end	
end
