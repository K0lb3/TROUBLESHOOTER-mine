--------------------------------------------------------
-- 현재 보여줘야 하는 오피스 리스트 받아오기
--------------------------------------------------------
function GetCurrentOfficeList(company)
	local list = {};
	local officeList = GetClassList('Office');
	for key, value in pairs (officeList) do
		if company.Lv >= value.RequireLv 
			and IsRequireAlignment(company, value.RequireAlignments)
		then
			table.insert(list, value);
		end
	end
	return list;
end
function IsRequireAlignment(company, requireAlignments)
	for i = 1, #requireAlignments do
		if requireAlignments[i] == company.Alignment then
			return true;
		end
	end
	return false;	
end