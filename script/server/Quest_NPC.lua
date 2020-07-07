------------------------------------------------------------------
-- 모든 NPC 퀘스트 시작 조건을 체크 하는 함수.
------------------------------------------------------------------
function TestQuestStart(company, npc, questType, curQuest)
	local questList = GetClassList('Quest');
	local questCls = questList[questType];
	if questCls == nil then
		return false, 'NoQuest';
	end
	-- 1. 완료하지 않은 퀘스트만 수령한다. (반복 퀘스트 제외)
	local curState, progress = GetQuestState(company, questType);
	if curState ~= 'NotStarted' and questCls.Group ~= 'Repeat' then
		return false, 'AlreadyAccepted';
	end
	-- 1-1. 반복 퀘스트는 회수 제한에 안 걸리면 완료된 퀘스트도 재시작 가능
	if questCls.Group == 'Repeat' then
		if curState == 'InProgress' then
			return false, 'AlreadyAccepted';
		end
		if questCls.RepeatLimit > 0 and progress.RepeatCount and progress.RepeatCount >= questCls.RepeatLimit then
			return false, 'RepeatLimit';
		end
	end
	
	-- 2. 존재하는 퀘스트인가.
	if questCls.name == nil or questCls.name =='None' then
		return false, 'NotExist';
	end

	-- 2-1. 회사 커맨드 레벨 체크
	if questCls.RequireCompanyLv > company.Lv then
		return false, 'RequireCompanyLv';
	end
	
	-- 2-2. 로스터 레벨 체크
	if questCls.RequireRosterLv > 0 then
		local maxRosterLv = 0;
		local rosterList = GetAllRoster(company);
		for _, pcInfo in ipairs(rosterList) do
			maxRosterLv = math.max(maxRosterLv, pcInfo.Lv);
		end
		if questCls.RequireRosterLv > maxRosterLv then
			return false, 'RequireRosterLv';
		end
	end
	
	-- 2-3. 스테이지 진행도 체크
	if questCls.RequireStageLv > 0 and GetScenarioProgressGrade(company) < questCls.RequireStageLv then
		return false, 'RequireStageLv';
	end
	
	-- 2-4. 의뢰 NPC와의 우호도 체크
	local friendshipList = GetClassList('Friendship');
	local checkGrade = friendshipList[questCls.RequireFriendship].Rank;
	if questCls.ClientType == 'Npc' then
		local curGrade = friendshipList[company.Npc[questCls.Client].Friendship].Rank;
		if curGrade < checkGrade then
			return false, 'FriendshipGrade';
		end
	elseif questCls.ClientType == 'Organization' then
		local curGrade = friendshipList[company.Organization[questCls.Client].Friendship].Rank;
		if curGrade < checkGrade then
			return false, 'OranizationFriendshipGrade';
		end	
	end
	-- 2-5. 선행 퀘스트 체크
	for i, quest in ipairs(questCls.PriorQuest) do
		local state = GetQuestState(company, quest);
		if state ~= 'Completed' and (not curQuest or quest ~= curQuest.name) then
			return false, 'PriorQuest';
		end
	end
	-- 2-6. 컴패니 프로퍼티 체크 
	for index, companyCls in ipairs(questCls.RequireCompanyProperty) do
		local keyChain = string.split(companyCls.Key, '/');
		local value = SafeIndex(company, unpack(keyChain));
		if value ~= companyCls.Value then
			return false, 'CompanyPropertyCheck';
		end
	end
	return true;
end

function TestQuestReplayEnable(company, npc)
	local checked = {};
	for _, propName in ipairs({ 'EndQuest', 'ProgressQuest', 'ProgressQuest_Client', 'StartQuest' }) do
		for _, questType in pairs(npc[propName]) do
			if not checked[questType] then
				checked[questType] = true;			
				if GetQuestState(company, questType) == 'Completed' then
					return true;
				end
			end
		end
	end
	return false;
end