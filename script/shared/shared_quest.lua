----------------------------------------------------------------------------------
-- 리퀘스트 완료 여부 체크 함수
----------------------------------------------------------------------------------
--- 리퀘스트 타입의 퀘스트 완료 조건은 아래에 정의한다.
-- 클라이언트에서 공용으로 사용하고 있다.
function CheckRequestState(company, questCls, progress, itemCountAcquirer)
	local isSuccess = false;
	local isTimeover = false;
	local curCount = 0;
	local maxCount = 0;
	(function ()
		if SafeIndex(questCls, 'name') == nil then
			return;
		end
		if questCls.name == nil then	-- 리퀘스트 형 퀘스트만 테스트함
			LogAndPrint(string.format('No request info for quest %s.', questCls.name));
			return;
		end
		curCount = questCls.Type.TargetCountGetter(questCls, progress, itemCountAcquirer);
		maxCount = questCls.Type.MaxCountGetter(questCls);
			
		--- 시간제한 퀘스트 ---
		--[[
		if os.time() > progress.EndTime then
			LogAndPrint(os.time(), progress.EndTime);
			isTimeover = true;
			return;
		end
		]]
		isSuccess = curCount >= maxCount;
	end) ();
	return isSuccess, isTimeover, curCount, maxCount;
end
------------------------------------------------------------------------------
--- 타입별 리퀘스트 타겟 카운트 게터
------------------------------------------------------------------------------
--- Type1. 프로그레스의 TargetCount를 이용하는 타입
function ProgressCountGetter(questCls, progress, itemCountAcquirer)
	return progress.TargetCount;
end
--- Type2. 인벤토리 아이템 개수 체크
function RequestInventoryItemCounter(questCls, progress, itemCountAcquirer)
	return itemCountAcquirer(questCls.Target);
end
---------------------------------------
--- 타입별 리퀘스트 맥스 카운트 게터
---------------------------------------
-- Type1. 리퀘스트의 TargetCount를 이용하는
function RequestTargetCountAsMaxCount(questCls)
	return questCls.TargetCount;
end
-- Type2. 무조건 한번만 하면 되는거
function RequestTargetCountOne(questCls)
	return 1;
end
-- Type3. 애초에 받았으면 이미 성공인거
function RequestTargetCountZero(questCls)
	return 0;
end

function Get_LinkedQuest(self)
	local questClsList = GetClassList('Quest');
	local retQuests = {};
	for key, questCls in pairs(questClsList) do
		(function()
			if questCls.Type == 'Mission' then
				return;
			end
			for i, pQuestType in ipairs(questCls.PriorQuest) do
				if pQuestType == self.name then
					table.insert(retQuests, questCls.name);
					return;
				end
			end
		end)()
	end
	return retQuests;
end
-- 퀘스트 보상 빌.
function Get_QuestRewardVill(quest)
	local result =  quest.Base_RewardVill + 50;
	-- 퀘스트 레벨
	result = result + quest.Lv * 5;
	-- 퀘스트 난이도.
	result = result * quest.Rank.RewardRatio/100;
	-- 퀘스트 타입
	result = result * quest.Type.RewardRatio;
	return math.floor(result);
end
-- 퀘스트 회사 경험치
function Get_QuestRewardCompanyExp(quest)
	local result = quest.Base_RewardCompanyExp + 10;
	-- 퀘스트 레벨
	result = result + quest.Lv * 2;
	-- 퀘스트 난이도
	result = result * quest.Rank.CompanyExpRewardRatio/100;
	-- 퀘스트 타입
	result = result * quest.Type.CompanyExpRewardRatio;	
	result = math.max(1, math.floor(result));
	return result;
end
-- 퀘스트 우호도 증가치
function Get_QuestRewardNPCFriendship(quest)
	local result = quest.Base_RewardNPCFriendship;
	-- 퀘스트 레벨
	result = result + quest.Lv;
	-- 퀘스트 난이도
	result = result * quest.Rank.FriendshipRatio/100;
	-- 퀘스트 타입
	result = result * quest.Type.FriendshipRatio;	
	result = math.max(1, math.floor(result));
	return result;
end
-- 퀘스트 미션
function Get_QuestMission(quest)
	local missionCls = GetClassList('Mission')[quest.Target];
	if missionCls and missionCls.name then
		return missionCls;
	end
end
function ParseContentText_Quest(qdCls, baseText)
	local colorList = GetClassList('Color');
	local baseColor = string.format("[colour='%s']", colorList[qdCls.BaseColor].ARGB);
	local highlightColor = string.format("[colour='%s']", colorList[qdCls.HighlightColor].ARGB);
	return ParseContentText(qdCls, baseText, 'QuestKeyword', {qdCls.name}, 
		baseColor, baseColor, highlightColor, highlightColor
	);
end
function CalculatedProperty_QuestDesc(qdCls)
	return ParseContentText_Quest(qdCls, qdCls.Base_Desc);
end
-------------------------------------------------------------------------------
-- 퀘스트 텍스트 변환
-------------------------------------------------------------------------------
function QuestKeywordTitle_Word(cls, questName, word, colorOver)
	local colorList = GetClassList('Color');
	local curColor = colorList[cls.Color].ARGB;
	if colorOver then
		curColor = colorOver;
	end
	return string.format("[colour='%s']%s", curColor, GetWord(word, true));
end
function QuestKeywordTitle_Org(cls, questName, org, colorOver)
	local colorList = GetClassList('Color');
	local curColor = colorList[cls.Color].ARGB;
	if colorOver then
		curColor = colorOver;
	end
	local orgCls = GetClassList('Organization')[org];
	local title = org;
	if orgCls then
		title = orgCls.Title;
	end
	return string.format("[colour='%s']%s", curColor, title);
end
function QuestKeywordTitle_Person(cls, questName, person, colorOver)
	local colorList = GetClassList('Color');
	local curColor = colorList[cls.Color].ARGB;
	if colorOver then
		curColor = colorOver;
	end
	local objectInfoCls = GetClassList('ObjectInfo')[person];
	local title = person;
	if objectInfoCls then
		title = objectInfoCls.Title;
	end
	return string.format("[colour='%s']%s",  curColor, title);
end
function QuestKeywordTitle_FPerson(cls, questName, person, colorOver)
	local colorList = GetClassList('Color');
	local curColor = colorList[cls.Color].ARGB;
	if colorOver then
		curColor = colorOver;
	end
	local objectInfoCls = GetClassList('ObjectInfo')[person];
	local title = person;
	if objectInfoCls then
		title = objectInfoCls.Title;
		if objectInfoCls.FamilyName ~= '' then
			title = title .. ' ' .. objectInfoCls.FamilyName;
		end
	end
	return string.format("[colour='%s']%s",  curColor, title);
end
function QuestKeywordTitle_JPerson(cls, questName, person, colorOver)
	local colorList = GetClassList('Color');
	local curColor = colorList[cls.Color].ARGB;
	if colorOver then
		curColor = colorOver;
	end
	local objectInfoCls = GetClassList('ObjectInfo')[person];
	local title = person;
	if objectInfoCls then
		title = objectInfoCls.Title;
		if objectInfoCls.JobName ~= '' then
			title = objectInfoCls.JobName..' '..title;
		end
	end
	return string.format("[colour='%s']%s",  curColor, title);
end
function QuestKeywordTitle_Site(cls, questName, site, colorOver)
	local colorList = GetClassList('Color');
	local curColor = colorList[cls.Color].ARGB;
	if colorOver then
		curColor = colorOver;
	end
	local siteCls = GetClassList('Site')[site];
	local title = site;
	if siteCls then
		title = siteCls.Title;
	end
	return string.format("[colour='%s']%s",  curColor, title);
end
function QuestKeywordTitle_TargetCount(cls, questName)
	local colorList = GetClassList('Color');
	local curColor = colorList[cls.Color].ARGB;
	local questCls = GetClassList('Quest')[questName];
	local title = 'Error';
	if questCls then
		title = questCls.TargetCount;
	end
	return string.format("[colour='%s']%s",  curColor, title);
end
function QuestKeywordTitle_TargetItem(cls, questName)
	local result = '';
	local colorList = GetClassList('Color');
	local curColor = colorList[cls.Color].ARGB;
	local questCls = GetClassList('Quest')[questName];
	local targetClsList = GetClassList(questCls.Type.Idspace);
	local targetCls = SafeIndex(targetClsList, questCls.Target);
	local title = SafeIndex(targetCls, 'Title') or 'Error';
	-- 아이템 특수 처리
	if targetCls and questCls.Type.Idspace == 'Item' then
		curColor = colorList[targetCls.Rank.Color].ARGB;
		result = string.format("[tooltip type='item' key='%s' color='%s']%s[tooltip-end]", targetCls.name, curColor, title);
	else
		result = string.format("[colour='%s']%s", curColor, title);
	end
	return result;
end
function QuestKeywordTitle_TargetCivilName(cls, questName)
	local result = '';
	local colorList = GetClassList('Color');
	local curColor = colorList[cls.Color].ARGB;
	local questCls = GetClassList('Quest')[questName];
	local targetClsList = GetClassList(questCls.Type.Idspace);
	local targetCls = SafeIndex(targetClsList, questCls.Target);
	local title = SafeIndex(targetCls, 'Title') or 'Error';
	result = string.format("[colour='%s']%s", curColor, title);
	return result;
end
function QuestKeywordTitle_Item(cls, questName, item, colorOver)
	local result = '';
	local colorList = GetClassList('Color');
	local curColor = colorList[cls.Color].ARGB;
	if colorOver then
		curColor = colorOver;
	end
	local itemCls = GetClassList('Item')[item];
	local title = item;
	if itemCls then
		title = itemCls.Title;
		curColor = colorList[itemCls.Rank.Color].ARGB;
		result = string.format("[tooltip type='item' key='%s' color='%s']%s[tooltip-end]", itemCls.name, curColor, title);
	else
		result = string.format("[colour='%s']%s",  curColor, title);
	end
	return result;
end
function QuestKeywordTitle_Zone(cls, questName, zone, colorOver)
	local colorList = GetClassList('Color');
	local curColor = colorList[cls.Color].ARGB;
	if colorOver then
		curColor = colorOver;
	end
	local zoneCls = GetClassList('Zone')[zone];
	local title = zone;
	if zoneCls then
		title = zoneCls.Title;
	end
	return string.format("[colour='%s']%s",  curColor, title);
end
function QuestKeywordTitle_Job(cls, questName, job, colorOver)
	local colorList = GetClassList('Color');
	local curColor = colorList[cls.Color].ARGB;
	if colorOver then
		curColor = colorOver;
	end
	local jobCls = GetClassList('Job')[job];
	local title = job;
	if jobCls then
		title = jobCls.Title;
	end
	return string.format("[colour='%s']%s",  curColor, title);
end

function QuestLinkedMissionSetGetter_Default(questCls)
	return Linq.new(GetWithoutError(questCls, 'Missions') or {})
		:select(function(md) return {md[1], true} end)
		:toMap();
end

function QuestLinkedMissionSetGetter_TargetItem(questCls)
	local monsterClsList = GetClassList('Monster');
	-- 미션에 등록된 Enemies중 에서 questCls에 등록된 Target 아이템을 드랍하는 적이 있는 미션들을 골라냄..
	local ret = Linq.new(GetClassList('Mission'))
		:where(function(md) return table.exist(md[2].Enemies, function(enemyInfo)
				local monType = enemyInfo.Type;
				local monCls = monsterClsList[monType];
				for _, reward in ipairs(monCls.Rewards) do
					if reward.Item == questCls.Target then
						return true;
					end
				end
				return false;
			end)
		end)
		:select(function(md) return {md[1], true} end)
		:toMap();
	return ret;
end

function QuestLinkedMissionSetGetter_TargetMonster(questCls)
	local monsterClsList = GetClassList('Monster');
	-- 미션에 등록된 Enemies중 에서 questCls에 등록된 TargetMonster 정보와 매치되는 적이 있는 미션들을 골라냄..
	local ret = Linq.new(GetClassList('Mission'))
		:where(function(md) return table.exist(md[2].Enemies, function(enemyInfo)
				local monType = enemyInfo.Type;
				local monCls = monsterClsList[monType];
				for _, target in ipairs(questCls.TargetMonster) do
					if target.Type == 'Monster' then
						if target.Target == monType then
							return true;
						end
					elseif target.Type == 'Race' then
						if target.Target == monCls.Object.Race.name then
							return true;
						end
					elseif target.Type == 'Job' then
						if target.Target == monCls.Object.Job.name then
							return true;
						end
					end
				end
				return false;
			end)
		end)
		:select(function(md) return {md[1], true} end)
		:toMap();
	return ret;
end