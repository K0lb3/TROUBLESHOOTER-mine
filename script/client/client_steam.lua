function InvalidateSteamStats()
	local session = GetSession();
	local company = session.company_info;
	
	-- 상자 열기
	local steamChestCount = GetSteamStat('OpenChestCount');
	if steamChestCount ~= nil then
		local companyChestCount = math.min(company.Stats.OpenChest, 100);
		if companyChestCount > steamChestCount then
			UpdateSteamStat('OpenChestCount', companyChestCount, true);
		end
	end
	-- 야수 길들이기
	local steamTamingCount = GetSteamStat('TamingCount');
	if steamTamingCount ~= nil then
		local companyTamingCount = math.min(company.BeastIndex, 10);
		if companyTamingCount > steamTamingCount then
			UpdateSteamStat('TamingCount', companyTamingCount, true);
		end
	end
end