--------------------------------------------------
-- ���� �׷��̵�� �������� Ÿ��.
----------------------------------------------------
function CalculatedProperty_MonsterOriginalType(mon, arg)
	local monsterList = GetClassList('Monster');
	local monsterType = mon.name;	
	for key, mon in pairs (monsterList) do
		if mon.GradeUp == monsterType then
			monsterType = key;
			break;
		end
	end
	return monsterType;
end
--------------------------------------------------
-- ���� Ʈ�������Ŀ�� �����ϴ°�.
----------------------------------------------------
function CalculatedProperty_MonsterIsEnrollTroublemaker(mon, arg)
	local troublemakerList = GetClassList('Troublemaker');
	for key, tm in pairs (troublemakerList) do
		if mon.OriginalType == key then
			return true;
		end
	end
	return false;
end