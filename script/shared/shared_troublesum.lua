---------------------------------------------------------------
--- 현재 교섭 가능한 조직 리스트 반환
---------------------------------------------------------------
function GetEnableContactOrganization(organization)
	local list = {};
	for key, value in pairs (organization) do
		if value.Opened then
			local addList = { Name = key, Organization = value};
			table.insert(list, addList);
		end
	end
	return list;
end