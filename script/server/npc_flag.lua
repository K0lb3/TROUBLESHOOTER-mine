function CheckNPCFlag(npc, company)
	local flags = {};
	flags.Title = npc.Info.Title;
	flags.Visible = true;
	
	for i, quest in ipairs(npc.EndQuest) do
		if TestQuestClear(company, npc, quest) then
			--print('can ClearQuest', quest);
			flags.CanClearQuest = true;
		end
	end
	for i, quest in ipairs(npc.ProgressQuest) do
		if TestQuestInProgress(company, npc, quest) then
			--print('can Progress', quest);
			flags.ProgressQuest = true;
		end
	end	
	for i, quest in ipairs(npc.StartQuest) do
		if TestQuestStart(company, npc, quest) then
			--print('can StartQuest', quest);
			flags.CanStartQuest = true;
		end
	end

	local checkF = _G['CheckNPCFlag_'..npc.name];
	if checkF then
		table.overwrite(flags, checkF(npc, company));
	end
	
	if npc.VisibleScript ~= 'None' then
		local visibleF = _G[npc.VisibleScript];
		if visibleF then
			flags.Visible = visibleF(npc, company);
		end
	end
	
	if npc.Mark ~= '' then
		flags.Mark = npc.Mark;
	else
		for si, service in ipairs (npc.Service) do
			local mark = GetWithoutError(service, 'Mark');
			local unlock = GetWithoutError(service, 'Unlock');
			if mark ~= nil then
				local showMark = true;
				if unlock ~= nil then
					local keyChain = string.split(unlock, '/');
					showMark = SafeIndex(company, unpack(keyChain));
				end
				if showMark then
					flags.Mark = service.Mark;
					break;
				end
			end
		end
	end
	
	return flags;
end

-- NPC 플래그 특수화 함수들
function CheckNPCFlag_Luna(npc, company)
	return {};
end
--------------------------------------------------------------------------
-- NPC Visible 체크 함수들
---------------------------------------------------------------------------
-- 크로우빌 끝나고 피에르토, 닐 아저씨 오신거
function CheckNPCVisible_Pierto_Peddler_Silverlining(npc, company)
	if company.Progress.Character.Pierto == 1 then
		return true;
	else
		return false;
	end
end
-- 지젤 영입
function CheckNPCVisible_Giselle_Silverlining(npc, company)
	if company.Progress.Character.Albus == 4 then
		return true;
	else
		return false;
	end
end