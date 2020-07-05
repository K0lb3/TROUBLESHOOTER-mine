-------------------------------------------------------------------------
-- 로비 체크 스크립트.
-------------------------------------------------------------------------
-- Office_Main
function ProgressPreDialogCheck_Office_Main(ldm, self, company, env, parsedScript)
	
	-- 모든 로비 공통으로 시작하는 이벤트.
	ProgressPreDialogCheck_AllLobby(ldm, self, company, env, parsedScript);
	
	ProgressDialog(ldm, self, company, 'Office_Main_Progress_Tutorial_Opening', env);
	ProgressDialog(ldm, self, company, 'Office_Main_Progress_Character_Albus', env);
	ProgressDialog(ldm, self, company, 'Office_Main_Progress_Character_Leton', env);
	ProgressDialog(ldm, self, company, 'Office_Main_Progress_Character_Heissing', env);
end
-- Office_Night_Main
function ProgressPreDialogCheck_Office_Night_Main(ldm, self, company, env, parsedScript)
	
	-- 모든 로비 공통으로 시작하는 이벤트.
	ProgressPreDialogCheck_AllLobby(ldm, self, company, env, parsedScript);
	
	if company.Progress.Tutorial.ItemBookEvent then
		ProgressDialog(ldm, self, company, 'Office_Night_Main_ItemBookEvent', env);
	else
		ProgressDialog(ldm, self, company, 'Office_Night_Main_Office_Night', env);
		return;
	end
	
	if company.Progress.Tutorial.Office == 42 then
		ProgressDialog(ldm, self, company, 'Office_Night_Main_Office_Night', env);
	end
end
-- ShooterStreet
function ProgressPreDialogCheck_ShooterStreet_Main(ldm, self, company, env, parsedScript)
	-- 모든 로비 공통으로 시작하는 이벤트.
	ProgressPreDialogCheck_AllLobby(ldm, self, company, env, parsedScript);
	
	ProgressDialog(ldm, self, company, 'ShooterStreet_Main_Progress_Tutorial_Opening', env);	
end
function ProgressPreDialogCheck_AllLobby(ldm, self, company, env, parsedScript)
	
	-- 아이작 & 알버스 이벤트
	if company.Progress.Character.Heissing == 12 and company.Progress.Character.Albus == 18 then
		ProgressDialog(ldm, self, company, 'Office_IssacCallAlbus', env);
	end	
end
-------------------------------------------------------------------------
-- 퀘스트 NPC 공용 스크립트.
-------------------------------------------------------------------------
function ProgressPreDialogCheck_CommonNPC(ldm, self, company, env, parsedScript)
	local dialogName = self.name..'_Selection';
	local allQuests = GetAllQuests(company);
	local questList = GetClassList('Quest');
	-- 퀘스트가 없으면 일반 진행.
	local isQuest = false;
	for _, QuestCls in ipairs (allQuests) do
		if QuestCls.Stage ~= 'Completed' then
			local curQuest = questList[QuestCls.Type];
			if curQuest then
				if curQuest.Client == self.name or curQuest.TargetNPC == self.name or curQuest.CompletionNpc == self.name then
					isQuest = true;
					break;
				end
			end
		end
	end
	-- 시작 퀘스트 여부
	for _, questType in ipairs (self.StartQuest) do
		if TestQuestStart(company, self, questType) then
			isQuest = true;
			break;
		end
	end
	if not isQuest then
		ProgressDialog(ldm, self, company, dialogName, env);		
	end
end