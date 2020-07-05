----------------------------------------------------------------
-- 로비 이동 가능한가?
----------------------------------------------------------------
function IsEnableZoneMove(company, location)
	local reason = {};
	local isEnable = true;
	if not company.Waypoint[location] then
		table.insert(reason, 'NotExistLocation');
		isEnable = false;
		return isEnable, reason;
	end
	if not company.Waypoint[location].Opened then
		table.insert(reason, 'Closed');
		isEnable = false;
	end
	return isEnable, reason;
end
