---------------------------------------------------------
-- 수리 시간
---------------------------------------------------------
function GetRepairTimeCalculator(self, target, ability, abilityDetailInfo)
	local info = {};
	local totalTime = 0;

	local addTimeByMaxHP = math.floor(target.MaxHP * 0.02);
	totalTime = totalTime + addTimeByMaxHP;
	table.insert(info, { Type = 'BasicTime', Value = addTimeByMaxHP, ValueType = 'Formula' });
	
	return math.max(totalTime, 0), info;
end

function Calculated_GetInteractionSetLinkedQuest(obj)
	local ret = {};
	for key, cls in pairs(GetClassList('Quest')) do
		if cls.Type.name == 'CollectItem_Property' and cls.Target == obj.name then
			table.insert(ret, cls);
		end
	end
	return ret;
end

function Calculated_GetArrestGenSetLinkedQuest(obj)
	local ret = {};
	for key, cls in pairs(GetClassList('Quest')) do
		if cls.Type.name == 'ArrestGen_Property' and cls.Target == obj.name then
			table.insert(ret, cls);
		end
	end
	return ret;
end