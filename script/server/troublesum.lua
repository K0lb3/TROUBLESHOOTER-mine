-------------------------------------------------------------
-- 조직의 트러블섬 요청 시간 / 업데이트 여부 , 시간.
-------------------------------------------------------------
function GetNextTroublesumUpdateTime(lastUpdateTime)
	local maintainPeriod = 30 * 60; 	-- 30분
	local prevTimeIndex = math.floor(lastUpdateTime / maintainPeriod);
	return (prevTimeIndex + 1) * maintainPeriod;
end
function UpdateTroublesumAllUser(dc, updateTime)
	local alluser = GetAllUsers();
	for i, user in pairs(alluser) do		-- 유저가 몇 천명 단위로 늘어난다면? 괜찮은가!?
		ProcessQuestTimeout(dc, user);
		local isUpdate = UpdateTroublesumOneUser(dc, user, updateTime);
		dc:Commit('UpdateTroublesumAllUser');
		if isUpdate then
			SendNotification(user, 'TroublesumUpdate', {});
		end		
	end
end
function UpdateTroublesumOneUser(dc, user, updateTime)
	if user.TroublesumUpdateTime >= updateTime then
		return false;		-- 이미 갱신함
	end
	
	-- 트러블섬 갱신시간 업데이트. 아래의 예외랑 상관없이 이건 이루어짐
	dc:UpdateCompanyProperty(user, 'TroublesumUpdateTime', updateTime + 1);
	
	-- 1. 트러블섬 개수 제한 MaxTroublesumCount 'Requested', 'InProgress'
	local questList = GetClassList('Quest');
	local currentTroublesumQuests = GetQuests(user, questList, { 'Requested', 'InProgress' }, 'Troublesum');
	if #currentTroublesumQuests >= user.MaxTroublesumCount then
		return false;
	end
	local avaiableCount = user.MaxTroublesumCount - #currentTroublesumQuests;
	
	-- 2. 퀘스트 업데이트 목록 가져오기.
	local updateQuests = {} -- 새로 할당할 트러블섬 퀘스트 리스트
	------------------------
	-- 퀘스트 세팅 --
	------------------------
	local notStartedTroubleSumQuests = GetQuests(user, questList, {'NotStarted'}, 'Troublesum');
	local picker = RandomPicker.new(false);		-- 비독립시행형 랜덤피커 생성
	for i, quest in ipairs(notStartedTroubleSumQuests) do
		if quest.Grade.name == user.Grade.name then
			picker:addChoice(math.floor(100/quest.Rank.Lv), quest);	
		end
	end
	updateQuests = picker:pickMulti(avaiableCount);	-- 5개쯤 뽑아보자

	for i, updateQuest in ipairs(updateQuests) do
		-- 퀘스트 배치하기.
		local nextUpdateTime = GetNextTroublesumUpdateTime(updateTime + 1);
		local duration = nextUpdateTime - updateTime;
		local maxMaintainTime = math.floor(updateTime + math.floor(duration * 0.999));
		dc:UpdateQuestStage(user, updateQuest.name, 'Requested');
		dc:UpdateQuestProperty(user, updateQuest.name, 'StartTime', updateTime);
		dc:UpdateQuestProperty(user, updateQuest.name, 'EndTime', maxMaintainTime);
	end
	return true;
end