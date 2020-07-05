function GetFriendshipChangeAmount(company, objType, objName, addPoint)
	local mul = 0;
	local mul_info = {};
	
	if objType == 'Npc' then
		-- 남부 지구 보너스
		local southAreaBonus = GetDivisionTypeBonusValue(company.Reputation, 'Area_South');
		if southAreaBonus > 0 then
			mul = mul + southAreaBonus / 100;
			table.insert(mul_info, {Type = 'Area_South', Value = southAreaBonus, ValueType = 'ReputationDivision'});
		end
	end
	return math.floor(addPoint * (1 + mul)), mul_info;
end