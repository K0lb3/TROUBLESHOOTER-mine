function MasterLobbyNPCDialogScript(script, ldm, npc, company)
	
	-- 퀘스트 진행 모드를 위한 선 처리
	local init = true;
	local questList = GetClassList('Quest');
	while(true) do
		local clearable = {};	-- 완료가능 슬롯
		local chooseableMenu = {};	
			
		local fadeIn;
		-- 1. 현재 반응 대사가 먼저 진행된다.(최초 대화 진행 시에만 보여진다.)
		if init then
			local env = _G[script](ldm, npc, company, quests);
			fadeIn = not SafeIndex(env, '_dialogFadeIn');			
		end
					
		-- 1. 메인 대화 시스템
		-- 1. 퀘스트 관련 선택지.
		-- 트러블섬 같이 특수한 퀘스트들은 제외한다.
		local quests = {};
		for i, questType in pairs(npc.EndQuest) do
			local curQuest = questList[questType];
			if TestQuestClear(company, npc, questType) then
				clearable[questType] = true;
				table.insert(chooseableMenu, { Mode= 'QuestClear', Type = questType });
				quests[questType] = 'Clear';
			end
		end
		for i, questType in pairs(npc.ProgressQuest) do
			local curQuest = questList[questType];
			if not clearable[questType] and GetQuestState(company, questType) == 'InProgress' then
				table.insert(chooseableMenu, { Mode = 'QuestProgress', Type = questType});
				quests[questType] = 'Progress';
			end
		end
		for i, questType in pairs(npc.ProgressQuest_Client) do
			local curQuest = questList[questType];
			if not clearable[questType] and GetQuestState(company, questType) == 'InProgress' then
				table.insert(chooseableMenu, { Mode = 'QuestProgress_Client', Type = questType});
				quests[questType] = 'Progress_Client';
			end
		end
		for i, questType in pairs(npc.StartQuest) do
			local curQuest = questList[questType];
			if TestQuestStart(company, npc, questType) then
				table.insert(chooseableMenu, { Mode = 'QuestStart', Type = questType});
				quests[questType] = 'Start';
			end
		end
		
		-- 2. 상점을 보유한 NPC이면 상점을 넣어 준다.
		-- 2-1. 트러블섬넷(의뢰중개인)을 보유한 NPC이면 트러블섬넷을 열어준다.	
		for si, service in ipairs (npc.Service) do
			local curService = service.Type;
			local curSubService = service.Value;
			local showMenu = true;
			local checkScript = GetWithoutError(service, 'CheckScript');
			if checkScript ~= nil then
				local checkFunc = _G[checkScript];
				if checkFunc then
					showMenu = checkFunc(company);
				end
			end
			if showMenu then
				if curService == 'Shop' then	
					local shopList = GetClassList('Shop');
					local curShopName = SafeIndex(shopList[curSubService], 'name');			
					if curShopName then
						table.insert(chooseableMenu, { Mode ='Shop', Type = curSubService });
					end
				else
					table.insert(chooseableMenu, { Mode = curService, Type = curSubService });
				end
			end
		end		
		
		-- 3. 나가기 선택지.
		table.insert(chooseableMenu, { Mode= 'Leave', Type= 'None'});

		-- 선택지 화면은 '나가기' 하기전에 반복되도록 한다.	
		local dialogArgs = {};
		dialogArgs.Title = '';
		dialogArgs.NPC = npc.name;
		dialogArgs.DlgName = npc.Info.Title;
		dialogArgs.JobName = npc.Info.JobName;
		dialogArgs.FamilyName = npc.Info.FamilyName;
		dialogArgs.Friendship = company.Npc[npc.name].Friendship;
		dialogArgs.FriendshipPoint = company.Npc[npc.name].FriendshipPoint;
		dialogArgs.Mode = fadeIn and 'Start' or 'Continue';
		dialogArgs.SpeakerInfo = npc.Info.name;
		dialogArgs.SpeakerEmotion = 'Normal';
		dialogArgs.Type = 'Sub';
		dialogArgs.Slot = 'Center';
		dialogArgs.Effect = 'Appear';
		dialogArgs.SelectMode = 'Additional';
		dialogArgs.SelectType = 'List';
		dialogArgs.Mode = 'Continue';
		
		if not table.empty(quests) then
			dialogArgs.Message, dialogArgs.SpeakerEmotion = GetNpcVisitMessageOnQuest(company, npc, quests, init and 'Initialize' or 'Continue');
		end		
		if not dialogArgs.Message then
			lobbyCls = GetClassList('LobbyWorldDefinition')[GetUserLocation(company)];
			local msgList, curMsgList = GetLobbyIdleMessage(company, npc.name, lobbyCls, 'NpcVisitMessage');
			if curMsgList and #curMsgList > 0 and RandomTest(50) then
				dialogArgs.Message = table.randompick(curMsgList).Text;
			elseif #msgList > 0 then
				dialogArgs.Message = table.randompick(msgList).Text;
			end
		end

		local choice = {};
		for i, menu in ipairs(chooseableMenu) do
			dialogArgs[i] = {Type = menu.Type, Mode = menu.Mode};
		end
		local id, sel;
		if #chooseableMenu == 1 then
			sel = 1;
		else
			id, sel = ldm:Dialog('BattleSelDialog', dialogArgs);
		end
		local env = {_dialogFadeIn = true};
		if sel == 0 then
			-- do nothing
		elseif chooseableMenu[sel].Mode == 'Leave' then
			break;
		elseif chooseableMenu[sel].Mode == 'Shop' then
			env = ProgressDialog(ldm, npc, company, chooseableMenu[sel].Mode..'_'..chooseableMenu[sel].Type, env);
		elseif chooseableMenu[sel].Mode == 'FoodShop' then	
			env = ProgressDialog(ldm, npc, company, chooseableMenu[sel].Mode..'_'..chooseableMenu[sel].Type, env);			
		elseif chooseableMenu[sel].Mode == 'Troublesum' then
			env = ProgressDialog(ldm, npc, company, chooseableMenu[sel].Mode..'_'..chooseableMenu[sel].Type, env);
		elseif chooseableMenu[sel].Mode == 'TroublesumReward' then
			env = ProgressDialog(ldm, npc, company, chooseableMenu[sel].Mode..'_'..chooseableMenu[sel].Type, env);
		elseif chooseableMenu[sel].Mode == 'Waypoint' then
			env = ProgressDialog(ldm, npc, company, chooseableMenu[sel].Mode..'_'..chooseableMenu[sel].Type, env);
		elseif chooseableMenu[sel].Mode == 'AllowDivision' then
			env = ProgressDialog(ldm, npc, company, chooseableMenu[sel].Mode..'_'..chooseableMenu[sel].Type, env);
		elseif chooseableMenu[sel].Mode == 'QuestStart' then
			env = QuestDialogStart(ldm, npc, company, chooseableMenu[sel].Type, env);
		elseif chooseableMenu[sel].Mode == 'QuestClear' then
			env = QuestDialogClear(ldm, npc, company, chooseableMenu[sel].Type, env);
		elseif chooseableMenu[sel].Mode == 'QuestProgress' then
			env = QuestDialogProgress(ldm, npc, company, chooseableMenu[sel].Type, env);
		elseif chooseableMenu[sel].Mode == 'QuestProgress_Client' then
			env = QuestDialogProgress(ldm, npc, company, chooseableMenu[sel].Type, env);
		elseif chooseableMenu[sel].Mode == 'Unlock' then
			env = ProgressDialog(ldm, npc, company, npc.name .. '_' .. chooseableMenu[sel].Mode..'_'..chooseableMenu[sel].Type, env);
		elseif chooseableMenu[sel].Mode == 'Rumor' then
			env = ProgressDialog(ldm, npc, company, chooseableMenu[sel].Mode..'_'..chooseableMenu[sel].Type, env);
		elseif chooseableMenu[sel].Mode == 'CPRestore' then
			env = ProgressDialog(ldm, npc, company, npc.name .. '_' .. chooseableMenu[sel].Mode..'_'..chooseableMenu[sel].Type, env);
		elseif chooseableMenu[sel].Mode == 'ItemUpgrade' then
			env = ProgressDialog(ldm, npc, company, chooseableMenu[sel].Mode, env);
		elseif chooseableMenu[sel].Mode == 'ItemIdentify' then
			env = ProgressDialog(ldm, npc, company, chooseableMenu[sel].Mode, env);
		elseif chooseableMenu[sel].Mode == 'WarehouseManager' then
			env = ProgressDialog(ldm, npc, company, chooseableMenu[sel].Mode, env);
		elseif chooseableMenu[sel].Mode == 'BeastManager' then
			env = ProgressDialog(ldm, npc, company, npc.name .. '_' .. chooseableMenu[sel].Mode, env);
		end
		
		if env._terminated then
			break;
		end
		init = false;
	end
end

function GetNPCStartQuests(self)
	local questClsList = GetClassList('Quest');
	local retQuests = {};
	for name, questCls in pairs(questClsList) do
		(function()
			if questCls.ClientType == 'Npc' then
				if questCls.Client == self.name then
					table.insert(retQuests, questCls.name);
				end
			end
		end)()
	end
	return retQuests;
end
function GetNPCEndQuests(self)
	local questClsList = GetClassList('Quest');
	local retQuests = {};
	for name, questCls in pairs(questClsList) do
		(function()
			if SafeIndex(questCls, 'CompletionNpc') == self.name then
				table.insert(retQuests, questCls.name);
			end
		end)()
	end
	return retQuests;
end
function GetNPCProgressQuests(self)
	local questClsList = GetClassList('Quest');
	local retQuests = {};
	for name, questCls in pairs(questClsList) do
		(function()
			if SafeIndex(questCls, 'Type', 'ProgressHost') and SafeIndex(questCls, 'TargetNPC') == self.name then
				table.insert(retQuests, questCls.name);
			end
		end)()
	end
	return retQuests;	
end
function GetNPCProgressQuests_Client(self)
	local questClsList = GetClassList('Quest');
	local retQuests = {};
	for name, questCls in pairs(questClsList) do
		(function()
			if SafeIndex(questCls, 'Type', 'ProgressHost') and 
				SafeIndex(questCls, 'Client') == self.name and 
				SafeIndex(questCls, 'Client') ~= SafeIndex(questCls, 'CompletionNpc') 
			then
				table.insert(retQuests, questCls.name);
			end
		end)()
	end
	return retQuests;	
end
------------------------------------------------------------------------------------------------------------------------
-- NPC의 대화 구조
---------------------------------------------------------------------------------------------------------------------------
-- 공용 기본용.
function NPCNormalDialog(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
-- 특수상황 예외처리.
function LunaClick(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
function TeacherClick(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
function InvestigatorClick(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
function CurioDealerClick(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
function Merchant_PotionClick(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
function SickManClick(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
function GirlWannabeClick(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
function GirlWanderingClick(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
function BoyRebelliousClick(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
function BoyDetectiveClick(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
function DrunkenFatClick(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
function RoubaoziClick(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
function KylieClick(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
function EmileClick(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
function HeissingClick(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
function MarcoClick(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
function VHPD_ShooterStreetClick1(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
function VHPD_ShooterStreetClick2(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
function Officer_VTrainClick(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
-- 체험판 용.
function Don_SilverliningClick(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, npc.Dialog, {questlist=questlist});
end
function FusionClick(ldm, npc, company, questlist)
	return ProgressDialog(ldm, npc, company, 'Fusion_Main');
end
------------------------------------------------------------------------------------------------------------------------
-- NPC 대화 클릭 후킹
------------------------------------------------------------------------------------------------------------------------
function Don_SilverliningPreClick(npc, company)
	if company.MissionCleared.Tutorial_PurpleBackStreet and not StringToBool(company.BarMenu.JukeBox.Opened, false) then
		return 'Don_JukeBox', {};
	end
end
------------------------------------------------------------------------------------------------------------------------
-- NPC 서비스 체크
------------------------------------------------------------------------------------------------------------------------
function Check_Don_Unlock_Workshop(company)
	return not StringToBool(company.WorkshopMenu.Opened, false);
end
function Check_Don_CPRestore(company)
	return company.UnlockService.Don_CPRestore;
end
function Check_Don_Unlock_Warehouse(company)
	return company.Progress.Tutorial.Office == 40;
end
function Check_Don_Unlock_Warehouse2(company)
	return company.Progress.Tutorial.Office == 50;
end
function Check_Leo_Unlock_BeastSlot(company, firstCheck)
	return company.Progress.Tutorial.UnlockBeastSlot;
end
function Check_Diogo_WarehouseManager(company)
	return company.Progress.Tutorial.WarehouseManagerLevel > 0;
end
function Check_Diogo_Unock_WarehouseManager(company)
	return company.Progress.Tutorial.WarehouseManagerLevel == 0;
end
function Check_Diogo_Unock_WarehouseManager2(company)
	return company.Progress.Tutorial.WarehouseManagerLevel > 0 and company.Progress.Tutorial.WarehouseManagerLevel < 10;
end
------------------------------------------------------------------------------------------------------------------------
-- NPC 퀘스트 Visit Message.
------------------------------------------------------------------------------------------------------------------------
function GetNpcVisitMessageOnQuest(company, npc, quests, mode)	
	
	local text = nil;
	local emotion = 'Normal';
	local dialogQuestList = GetClassList('DialogQuest');
	local questList = GetClassList('Quest');
	
	-- NotStarted(비활성), Requested(시작 가능), InProgress(진행중), Completed(완료), Failed(실패)
	-- Clear / Progress / Start
	local curQuestList = {};
	for key, quest in pairs (questList) do
		if quest.Client == npc.name or quest.TargetNPC == npc.name or quest.CompletionNpc == npc.name then
			table.insert(curQuestList, quest);
		end
	end
	table.sort(curQuestList, function (a, b)
		return a.ProgressOrder < b.ProgressOrder;
	end);
	local curDialogQuest = nil;
	for index, questCls in ipairs (curQuestList) do
		local curQuestKey = questCls.name;
		local curQuestState = quests[curQuestKey];
		if curQuestState then
			local curDialogQuest = dialogQuestList[curQuestKey];
			if curDialogQuest then				
				local curVisitMessage = curDialogQuest.Visit[curQuestState..'_'..mode];
				if curVisitMessage then
					text = curVisitMessage.Message;
					emotion = curVisitMessage.SpeakerEmotion;
					break;
				end				
			end
		end
	end		
	return text, emotion;
end