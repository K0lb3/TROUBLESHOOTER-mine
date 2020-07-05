local reservedCompanyStats = {
	'PerformanceFinishCount',
	'ProtocolUseCount',
	'TrapUseCount',
	'TamingSuccessCount',
	'UseAbilityConceal',
	'UseAbilityStandBy',
	'RewardItemMaterial',
	'ExtractPsionicStone',
	'GiantKill',
	'LegendaryMachineKill',
	'LegendaryBeastKill',
	'DodgeOnCover',
	'OpenChest'
};
function GetReservedStat_Company(company, stats)
	local retStats = {};
	for _, key in ipairs(reservedCompanyStats) do
		retStats[key] = SafeIndex(stats, key);
	end
	return retStats;
end
function RestoreReservedStat_Company(company, savedStats, newStats)
	for _, key in ipairs(reservedCompanyStats) do
		if SafeIndex(savedStats, key) then
			SafeNewIndex(newStats, key, SafeIndex(savedStats, key));
		end
	end
end

function GetReservedStat_Roster(roster, stats)
	local retStats = {};
	return retStats;
end

function RestoreReservedStat_Roster(roster, savedStats, newStats)

end