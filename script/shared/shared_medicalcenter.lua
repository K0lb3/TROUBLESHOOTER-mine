function GetCureCost(roster)
	return 100;
end

function IsAbleToCureBase(company, roster)
	if roster.ConditionState ~= 'Rest' then
		return false;	-- 회복할 필요가 없다.
	elseif roster.NowCuring then
		return false;	-- 이미 회복실
	end
	
	for i = 1, company.MedicalCenter.SlotLimit do
		if company.MedicalCenter.Slot[i] == 'None' then
			return true;
		end
	end
	return false; -- 빈슬롯 없다.
end

function IsAbleToCure(company, roster)
	if not IsAbleToCureBase(company, roster) then
		return false;
	elseif company.RP < GetCureCost(roster) then
		return false;	-- RP 부족
	else
		return true;
	end
end

CONST_ITEM_TYPE_MaxCureRoster = 'CocaineCandy';

function IsAbleToMaxCure(company, roster, itemCounter)
	if not IsAbleToCureBase(company, roster) then
		return false;
	elseif itemCounter(CONST_ITEM_TYPE_MaxCureRoster) == 0 then
		return false; -- 캔디 부족
	else
		return true;
	end
end