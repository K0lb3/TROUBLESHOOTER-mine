-------------------------------------------------------------------------
-------------------------- �̼� ����� ���Ǵ� �Լ� --------------------
-------------------------------------------------------------------------
function GetMissionResultObjectStateByHPRatio(curHP, hpRatio)
	local state = 'Normal';	
	if curHP == 0  then
		state = 'Coma';
	elseif hpRatio <= 0.25 then
		state = 'Fatal';
	elseif hpRatio <= 0.5 then
		state = 'Serious';
	elseif hpRatio <= 0.75 then
		state = 'Slight';
	end
	return state;
end