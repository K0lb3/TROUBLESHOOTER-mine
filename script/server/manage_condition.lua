function AddRosterConditionPoint(dc, roster, cpChange, satietyChange, refreshChange)
	satietyChange = satietyChange or 0;
	refreshChange = refreshChange or 0;
	
	local curTime = os.time();
	local elapsedTime = 0;
	if roster.CPLastUpdateTime ~= 0 then
		elapsedTime = curTime - roster.CPLastUpdateTime;
	end
	
	local nextCP = roster:GetEstimatedCP();
	nextCP = clamp(nextCP + cpChange, 0, roster.OverChargeCP);
	
	local fatigueMastery = nil;
	local needDoUpdate = cpChange ~= 0 or satietyChange ~= 0 or refreshChange ~= 0 or math.abs(elapsedTime) > 300;
	
	if roster.ConditionState == 'Good' and nextCP == 0 then
		dc:UpdatePCProperty(roster, 'ConditionState', 'Rest');
		dc:AddPCProperty(roster, 'Stats/ConditionRest', 1);
		needDoUpdate = true;
	elseif roster.ConditionState == 'Rest' and roster.MaxCP <= nextCP then
		local company = GetCompany(roster);
		if RandomTest(30) then
			local masteryTable = GetMastery(roster);
			local masteryClsList = GetClassList('Mastery');
			local picker = RandomPicker.new();
			for key, cls in pairs(GetClassList('FatigueMastery')) do
				local enable = IsEnableMasterRosterMastery(company, roster, masteryClsList[key], masteryTable, true);
				if enable then
					picker:addChoice(cls.Priority, key);
				end
			end
			fatigueMastery = picker:pick();
			if fatigueMastery then
				dc:UpdateMasteryLv(roster, fatigueMastery, 1);
				dc:UpdatePCProperty(roster, 'MasteryPopupMessage', 'FatigueMastery');
				dc:UpdatePCProperty(roster, 'MasteryPopupMessageTarget', fatigueMastery);
			end
		end
		dc:UpdatePCProperty(roster, 'ConditionState', 'Good');
		needDoUpdate = true;
	end
	local nextSatiety = math.clamp(roster:GetEstimatedSatiety() + satietyChange, 0, roster.MaxSatiety);
	local nextRefresh = math.clamp(roster:GetEstimatedRefresh() + refreshChange, 0, roster.MaxRefresh);
	if needDoUpdate then
		dc:UpdatePCProperty(roster, 'CPLastUpdateTime', curTime);
		dc:UpdatePCProperty(roster, 'CP', nextCP);
		if nextSatiety ~= roster.Satiety then
			dc:UpdatePCProperty(roster, 'Satiety', nextSatiety);
		end
		if nextRefresh ~= roster.Refresh then
			dc:UpdatePCProperty(roster, 'Refresh', nextRefresh);
		end
	end
	return fatigueMastery, nextSatiety, nextRefresh;
end
function InvalidateRosterConditionPoint(dc, roster)	-- 필요없는거긴 한데 그냥 함수만 따로 만들어둠
	return AddRosterConditionPoint(dc, roster, 0);
end
function UpdateRosterConditionPoint(dc, roster, updateCp, updateSatiety, updateRefresh)
	local numberedUpdateCp = clamp(updateCp, 0, roster.OverChargeCP);
	updateSatiety = updateSatiety or roster:GetEstimatedSatiety();
	updateRefresh = updateRefresh or roster:GetEstimatedRefresh();
	local clampedUpdateSatiety = clamp(updateSatiety, 0, roster.MaxSatiety);
	local clampedUpdateRefresh = clamp(updateRefresh, 0, roster.MaxRefresh);
	dc:UpdatePCProperty(roster, 'CPLastUpdateTime', os.time());
	if roster.CP ~= numberedUpdateCp then
		dc:UpdatePCProperty(roster, 'CP', numberedUpdateCp);
	end
	if roster.Satiety ~= clampedUpdateSatiety then
		dc:UpdatePCProperty(roster, 'Satiety', clampedUpdateSatiety);
	end
	if roster.Refresh ~= clampedUpdateRefresh then
		dc:UpdatePCProperty(roster, 'Refresh', clampedUpdateRefresh);
	end
	if roster.ConditionState == 'Good' and numberedUpdateCp == 0 then
		dc:UpdatePCProperty(roster, 'ConditionState', 'Rest');
		dc:AddPCProperty(roster, 'Stats/ConditionRest', 1);
	elseif roster.ConditionState == 'Rest' and roster.MaxCP <= numberedUpdateCp then
		dc:UpdatePCProperty(roster, 'ConditionState', 'Good');
	end
end