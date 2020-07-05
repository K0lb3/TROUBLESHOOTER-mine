---------------------------------------------------------------------
-- 경험치 레벨업.
---------------------------------------------------------------------
function UpdateCompanyExp(dc, company, rewardExp)
	if rewardExp < 1 then
		LogAndPrint('[Error] UpdateCompanyExp - rewardExp < 1 ');
		return;
	end
	local uplevel = 0;
	local curExp = company.Exp + rewardExp;
	local nextExp = GetNextExp('Company', company.Lv);
	while( curExp >= nextExp ) do
		if nextExp > 0 then
			curExp = curExp - nextExp;
			uplevel = uplevel + 1;
			nextExp = GetNextExp('Company', company.Lv + uplevel);
		end
	end
	if uplevel > 0 then
		dc:UpdateCompanyProperty(company, 'Lv', company.Lv + uplevel );	
	end
	dc:UpdateCompanyProperty(company, 'Exp', curExp);
end 
function GetCompanyExpByMission(company, mission, missionRank, completeCount)
	local result = 0;
	local missionResultRankList = GetClassList('MissionResultRank');
	local curRankRatio = SafeIndex(missionResultRankList[missionRank], 'Ratio');
	if curRankRatio == nil then
		return result;
	end
	result = result + mission.Exp * curRankRatio;
	result = math.max(1, math.floor(result));
	return result;
end
function UpdateCompanyAlignment(dc, company, alignment, addPoint)
	local updatePoint = company.AlignmentPoint[alignment] + addPoint;
	-- 최대 포인트를 넘어서면 패널티 작동.
	if updatePoint > company.MaxAlignment then
		local alignmentList = GetClassList('Alignment');
		local overPointPenaltyList = alignmentList[alignment].OverPointPenalty;
		for key, value in pairs (overPointPenaltyList) do
			local additionalUpdatePoint = math.max(0, company.AlignmentPoint[key] + value);
			dc:UpdateCompanyProperty(company, 'AlignmentPoint/'..key, additionalUpdatePoint);
		end
	end	
	updatePoint = math.max(0, math.min(updatePoint, company.MaxAlignment));
	dc:UpdateCompanyProperty(company, 'AlignmentPoint/'..alignment, updatePoint);
end
function AddCompanyRP(dc, company, rp)
	if rp + company.RP > company.MaxRP then
		rp = company.MaxRP - company.RP;
	elseif rp + company.RP < 0 then
		rp = company.RP;
	end
	dc:AddCompanyProperty(company, 'RP', rp);
end 