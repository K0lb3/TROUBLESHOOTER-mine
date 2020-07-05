function ConstructCompareAbilityUsingTargetInfo(user, ability, target)
	local ret = {};
	
	-- 대상
	ret.Target = target;
	
	-- 명중률
	local mission = GetSession().current_mission;
	local weather = mission.Weather.name;
	local missionTime = mission.MissionTime.name;
	local temperature = mission.Temperature.name;
	ret.Accuracy = ability.GetHitRateCalculator(user, target, ability, GetPosition(target), weather, missionTime, temperature)/100;
	
	-- 거리
	ret.Distance = GetDistanceFromObjectToObject(user, target);
	if target.Obstacle then
		ret.Accuracy = ret.Accuracy - ret.Distance * 10;
	end			
	-- 데미지
	if ability.Type == 'Attack' then
		ret.Damage = GetDamageCalculator(user, target, ability, weather, GetPosition(target), 1);
	end
	-- 힐
	if ability.Type == 'Heal' and ability.SubType2 == 'HP' then
		local heal = GetDamageCalculator(user, target, ability, weather, GetPosition(target), 1);
		ret.Heal = math.min(heal, target.MaxHP - target.HP);
	end	
	-- 힐
	if ability.Type == 'Heal' and ability.SubType2 == 'Cost' then
		if ability.RestoreMaxCost then
			ret.Heal = target.MaxCost - target.Cost;
		else
			local applyCost = GetAbilityApplyCost(ability, user, target);
			local nextCost = math.clamp(target.Cost + applyCost, 0, target.MaxCost);
			ret.Heal = nextCost - target.Cost;
		end
	end	
	-- 힐
	if ability.Type == 'Heal' and ability.SubType2 == 'SP' then
		ret.Heal = GetAbilityApplySP(ability, user, target);
	end
	
	-- 오브젝트 키
	ret.ObjKey = GetObjKey(target);
	
	-- 길들이는 중
	ret.Taming = GetInstantProperty(target, 'TamingUnit') ~= nil;
	
	return ret;
end

function CompareAbilityUsingTarget(user, ability, targetInfoA, targetInfoB)

	local targetA = targetInfoA.Target;
	local targetB = targetInfoB.Target;
	
	-- 힐
	if ability.Type == 'Heal' then
		local healA = targetInfoA.Heal;
		local healB = targetInfoB.Heal;
		if healA > healB then
			return true;
		elseif healA < healB then
			return false;
		end
	end
	
	-- 나 아닌 캐릭터부터
	if user == targetA and user ~= targetB then
		return false;
	elseif user == targetB and user ~= targetA then
		return true;
	end
	
	-- 길들이는 중
	if targetInfoA.Taming ~= targetInfoB.Taming then
		return targetInfoB.Taming;
	end
	
	-- 명중률
	local accuracyA = targetInfoA.Accuracy;
	local accuracyB = targetInfoB.Accuracy;
	if accuracyA > accuracyB then
		return true;
	elseif accuracyA < accuracyB then
		return false;
	end
	
	-- 거리
	local distA = targetInfoA.Distance;
	local distB = targetInfoB.Distance;
	if distA < distB then
		return true;
	elseif distA > distB then
		return false;
	end
	
	-- 데미지
	if ability.Type == 'Attack' then
		local damageA = targetInfoA.Damage;
		local damageB = targetInfoB.Damage;
		if damageA > damageB then
			return true;
		elseif damageA < damageB then
			return false;
		end
	end
	
	-- 베이스. 오브젝트 키 문자열 비교
	return targetInfoA.ObjKey < targetInfoB.ObjKey;
end