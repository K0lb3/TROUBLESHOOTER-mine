--------------------------------------------------------------------
-- 실버라이닝 바 - 외출하기
--------------------------------------------------------------------
-- 람지 플라자.
function LobbyClientEvent_PlayRamjiPlaza(company)
	if company.Progress.Tutorial.Office ~= 12 and company.Progress.Tutorial.Office ~= 13 then
		return false;
	end
	StartLobbyDialog(company, 'Office_PlayRamjiPlaza');
	return true;
end
-- 푸고 상점가.
function LobbyClientEvent_PlayPugoShop(company)
	if company.Progress.Tutorial.Opening ~= 'PugoShop' and company.Progress.Tutorial.Opening ~= 'PugoShop_Lose' then
		return false;
	end
	StartLobbyDialog(company, 'Office_PlayPugoShop');
	return true;
end
-- 푸른안개거리. 삼청 마을.
function LobbyClientEvent_PlayBlueFogStreet(company)
	if company.Progress.Character.Irene ~= 6 then
		return false;
	end
	StartLobbyDialog(company, 'Office_PlayBlueFogStreet');
	return true;
end
-- 실버라이닝 애프터
function LobbyClientEvent_PlaySilverliningAfter(company)
	if company.Progress.Character.Don ~= 1 then
		return false;
	end
	StartLobbyDialog(company, 'Office_PlaySilverliningAfter');
	return true;
end
-- 한산도
function LobbyClientEvent_PlayHansando(company)
	if company.Progress.Character.Issac ~= 4 then
		return false;
	end
	StartLobbyDialog(company, 'Office_PlayHansando');
	return true;
end
-- 한산도
function LobbyClientEvent_PlayGrayCemeteryPark(company)
	if company.Progress.Character.Anne ~= 3 then
		return false;
	end
	StartLobbyDialog(company, 'Office_PlayGrayCemeteryPark');
	return true;
end
-- 푸고상점거리 밤.
function LobbyClientEvent_PlayPugoShopAfter(company)
	if company.Progress.Character.Sion ~= 2 then
		return false;
	end
	StartLobbyDialog(company, 'Office_PlayPugoShopAfter');
	return true;
end
-- 헤이싱 영입.
function LobbyClientEvent_Office_RecruitHeissing(company)
	if company.Progress.Character.Heissing ~= 5 then
		return false;
	end
	StartLobbyDialog(company, 'Office_RecruitHeissing');
	return true;
end
-- 레톤 영입.
function LobbyClientEvent_Office_RecruitLeton(company)
	if company.Progress.Character.Leton ~= 4 then
		return false;
	end
	StartLobbyDialog(company, 'Office_RecruitLeton');
	return true;
end
-- 아이작 제안.
function LobbyClientEvent_Office_IssacRequest2(company)
	if company.Progress.Character.Albus ~= 19 then
		return false;
	end
	StartLobbyDialog(company, 'Office_IssacRequest2');
	return true;
end
-- 카일리 제안.
function LobbyClientEvent_Office_KylieRequest(company)
	if company.Progress.Character.Albus ~= 22 then
		return false;
	end
	StartLobbyDialog(company, 'Office_KylieRequest');
	return true;
end
-- 제인 제안2.
function LobbyClientEvent_Office_JaneRequest2(company)
	if company.Progress.Character.Albus ~= 24 then
		return false;
	end
	StartLobbyDialog(company, 'Office_JaneRequest2');
	return true;
end
---------------------------------------------------------------------
-- 컨디션 회복
function LobbyClientEvent_ConditionRest(company)
	local suggestion = GetClassList('Suggestion')['ConditionRest'];
	if not suggestion or not suggestion.name then
		return false;
	end
	if not HasConditionRest(company) then
		return false;
	end
	local restList = {};
	local rosterList = GetAllRoster(company);
	for index, roster in ipairs(rosterList) do
		if roster ~= nil and roster.ConditionState == 'Rest' then
			table.insert(restList, roster.name);
		end
	end	
	StartLobbyDialog(company, 'Office_ConditionRest', {rest_list=restList});
	return true;
end
---------------------------------------------------------------------
-- 알버스 방.
---------------------------------------------------------------------
function LobbyClientEvent_GameMenu_Company(company)
	if not company.LobbyMenu.Company.Opened then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_Company');	
	return true;
end
function LobbyClientEvent_GameMenu_Roster(company)
	if not company.LobbyMenu.Roster.Opened then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_Roster');
	return true;
end
function LobbyClientEvent_RosterTutorial1(company)
	if company.Progress.Tutorial.Roster ~= 0 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_RosterTutorial1');
	return true;
end
function LobbyClientEvent_RosterTutorial2(company)
	if company.Progress.Tutorial.Roster ~= 1 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_RosterTutorial2');
	return true;
end
function LobbyClientEvent_RosterTutorial3(company)
	if company.Progress.Tutorial.Roster ~= 2 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_RosterTutorial3');
	return true;
end
function LobbyClientEvent_RosterTutorial4(company)
	if company.Progress.Tutorial.Roster ~= 3 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_RosterTutorial4');
	return true;
end
function LobbyClientEvent_RosterTutorial5(company)
	if company.Progress.Tutorial.Roster ~= 4 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_RosterTutorial5');
	return true;
end
function LobbyClientEvent_RosterTutorial6(company)
	if company.Progress.Tutorial.Roster ~= 6 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_RosterTutorial6');
	return true;
end
function LobbyClientEvent_RosterTutorial6_Pre(company)
	if company.Progress.Tutorial.Roster ~= 5 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_RosterTutorial6_Pre');
	return true;
end
function LobbyClientEvent_GameMenu_Quest(company)
	if not company.LobbyMenu.Quest.Opened then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_Quest');	
	return true;
end
function LobbyClientEvent_GameMenu_Inventory(company)
	if not company.LobbyMenu.Inventory.Opened then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_Inventory');	
	return true;
end
function LobbyClientEvent_GameMenu_MasteryInventory(company)
	if not company.LobbyMenu.MasteryInventory.Opened then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_MasteryInventory');	
	return true;
end
function LobbyClientEvent_GameMenu_MailBox(company)
	if not company.LobbyMenu.MailBox.Opened then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_MailBox');	
	return true;
end
function LobbyClientEvent_GameMenu_MailTutorial(company)
	if StringToBool(company.LobbyMenu.Roster.Tutorial, false) then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_MailTutorial');
	return true;
end
function LobbyClientEvent_GameMenu_MailTutorial2(company)
	if company.Progress.Tutorial.Roster ~= 8 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_MailTutorial2');	
	return true;
end
function LobbyClientEvent_GameMenu_MailTutorial3(company)
	if company.Progress.Tutorial.Roster ~= 9 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_MailTutorial3');	
	return true;
end
function LobbyClientEvent_GameMenu_MailTutorial4(company)
	if company.Progress.Tutorial.Roster ~= 10 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_MailTutorial4');	
	return true;
end
function LobbyClientEvent_GameMenu_MailTutorial_Wait(company)
	if company.Progress.Tutorial.Roster ~= 9 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_MailTutorial_Wait');	
	return true;
end
function LobbyClientEvent_GameMenu_MailTutorial_WaitRead(company)
	if company.Progress.Tutorial.Roster ~= 9 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_MailTutorial_WaitRead');	
	return true;
end
function LobbyClientEvent_GameMenu_End(company)
	if company.Progress.Tutorial.Roster < 11 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_MenuTutorial_End');	
	return true;
end
---------------------------------------------------------------------
-- 오피스
---------------------------------------------------------------------
function LobbyClientEvent_Office_Tutorial_WorldMap(company)
	if not company.OfficeMenu.Worldmap.Tutorial or company.Progress.Tutorial.Office ~= 8 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_WorldMap');
	return true;
end
function LobbyClientEvent_Office_Tutorial_TroubleBook(company)
	if not company.OfficeMenu.TroubleBook.Tutorial then
		return false;
	end	
	StartLobbyDialog(company, 'Office_Tutorial_TroubleBook');
	return true;
end
function LobbyClientEvent_Office_Tutorial_TroubleBook2(company)
	if company.Progress.Tutorial.TroubleBook ~= 1 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_TroubleBook2');
	return true;
end
function LobbyClientEvent_Office_Tutorial_TroubleBook3(company)
	if company.Progress.Tutorial.TroubleBook ~= 2 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_TroubleBook3');
	return true;
end
function LobbyClientEvent_Office_Tutorial_ActivityReport(company)
	if not StringToBool(company.OfficeMenu.ActivityReport.Tutorial) or not StringToBool(company.OfficeMenu.ActivityReport.Opened) then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_ActivityReport');
	return true;
end
function LobbyClientEvent_Office_Tutorial_ActivityReport2(company)
	if company.Progress.Tutorial.ActivityReport ~= 1 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_ActivityReport2');
	return true;
end
function LobbyClientEvent_Office_Tutorial_ActivityReport3(company)
	if company.Progress.Tutorial.ActivityReport ~= 2 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_ActivityReport3');
	return true;
end
function LobbyClientEvent_Office_Tutorial_ActivityReport4(company)
	if company.Progress.Tutorial.ActivityReport ~= 3 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_ActivityReport4');
	return true;
end
function LobbyClientEvent_Office_Tutorial_ActivityReport5(company)
	if company.Progress.Tutorial.ActivityReport ~= 4 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_ActivityReport5');
	return true;
end
function LobbyClientEvent_Office_Tutorial_ActivityReport6(company)
	if company.Progress.Tutorial.ActivityReport ~= 5 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_ActivityReport6');
	return true;
end
function LobbyClientEvent_Office_Tutorial_Troublemaker(company)
	if not StringToBool(company.OfficeMenu.TroublemakerList.Tutorial) or not StringToBool(company.OfficeMenu.TroublemakerList.Opened) then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_TroublemakerList');
	return true;
end
function LobbyClientEvent_Office_Tutorial_Troublemaker2(company)
	if company.Progress.Tutorial.Office == 0 or company.Progress.Tutorial.Troublemaker ~= 1 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_TroublemakerList2');
	return true;
end
function LobbyClientEvent_Office_Tutorial_Troublemaker3(company)
	if company.Progress.Tutorial.Troublemaker ~= 2 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_TroublemakerList3');
	return true;
end
function LobbyClientEvent_Office_Tutorial_Technique(company)
	if not StringToBool(company.OfficeMenu.Technique.Tutorial) or not StringToBool(company.OfficeMenu.Technique.Opened) then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_Technique');
	return true;
end
function LobbyClientEvent_Office_Tutorial_Technique2(company)
	if company.Progress.Tutorial.Technique ~= 1 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_Technique2');
	return true;
end
function LobbyClientEvent_Office_Tutorial_Technique3(company)
	if company.Progress.Tutorial.Technique ~= 2 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_Technique3');
	return true;
end
function LobbyClientEvent_Office_Tutorial_Statistics(company)
	if not StringToBool(company.OfficeMenu.Statistics.Tutorial) or not StringToBool(company.OfficeMenu.Statistics.Opened) or company.Progress.Tutorial.Statistics ~= 0 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_Statistics');
	return true;
end
function LobbyClientEvent_Office_Tutorial_Statistics2(company)
	if company.Progress.Tutorial.Statistics ~= 1 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_Statistics2');
	return true;
end
function LobbyClientEvent_Office_Tutorial_OfficeMoveIn06(company)
	if company.Progress.Tutorial.Office ~= 5 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_OfficeMoveIn06');
	return true;
end
function LobbyClientEvent_Office_Tutorial_OfficeMoveIn07(company)
	if company.Progress.Tutorial.Office ~= 6 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_OfficeMoveIn07');
	return true;
end
function LobbyClientEvent_Office_Tutorial_OfficeMoveIn11(company)
	if company.Progress.Tutorial.Office ~= 10 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_OfficeMoveIn11');
	return true;
end
function LobbyClientEvent_Office_Tutorial_OfficeMoveIn12(company)
	if company.Progress.Tutorial.Office ~= 11 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_OfficeMoveIn12');
	return true;
end
function LobbyClientEvent_Office_Tutorial_OfficeMoveIn20(company)
	if company.Progress.Tutorial.Office ~= 20 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_OfficeMoveIn20');
	return true;
end
function LobbyClientEvent_Office_Tutorial_OfficeMoveIn30(company)
	if company.Progress.Tutorial.Office ~= 30 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_OfficeMoveIn30');
	return true;
end
function LobbyClientEvent_Office_Tutorial_OfficeMoveIn31(company)
	if company.Progress.Tutorial.Office ~= 31 or 
		company.Office ~= 'Office_Silverlining' or 
		(company.Progress.Character.Pierto == 0 and company.Progress.Character.Irene < 2 ) 
	then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_OfficeMoveIn31');
	return true;
end
function LobbyClientEvent_Office_Tutorial_OfficeMoveIn32(company)
	if company.Progress.Tutorial.Office ~= 32 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_OfficeMoveIn32');
	return true;
end
function LobbyClientEvent_Office_TroublebookOpenEvent(company)
	if StringToBool(company.OfficeMenu.TroubleBook.Opened, false) or company.Progress.Character.Heissing < 2 then	
		return false;
	end
	StartLobbyDialog(company, 'Office_TroublebookOpenEvent');
	return true;
end
function LobbyClientEvent_Office_Tutorial_ItemUpgrade(company)
	if company.Progress.Tutorial.Office ~= 42 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_ItemUpgrade');
	return true;
end
function LobbyClientEvent_Office_Tutorial_ItemUpgrade2(company)
	if company.Progress.Tutorial.Office ~= 43 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_ItemUpgrade2');
	return true;
end
function LobbyClientEvent_Office_Tutorial_ItemUpgrade3(company)
	if company.Progress.Tutorial.Office ~= 44 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_ItemUpgrade3');
	return true;
end
function LobbyClientEvent_Office_Tutorial_OfficeMoveIn45(company)
	if company.Progress.Tutorial.Office ~= 45 or 
		company.Office ~= 'Office_Silverlining_Workshop'
	then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_OfficeMoveIn45');
	return true;
end
function LobbyClientEvent_Office_Tutorial_OfficeMoveIn46(company)
	if company.Progress.Tutorial.Office ~= 46 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_OfficeMoveIn46');
	return true;
end
---------------------------------------------------------------
-- 푸고 상점가.
---------------------------------------------------------------
function LobbyClientEvent_Office_Tutorial_PlayPugoShop(company)
	if company.Progress.Character.Irene ~= 3 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_PlayPugoShop');
	return true;
end
---------------------------------------------------------------
-- 푸른 안개 거리.
---------------------------------------------------------------
function LobbyClientEvent_Office_Tutorial_PlayBlueFogStreet(company)
	if company.Progress.Character.Irene ~= 4 and company.Progress.Character.Irene ~= 5 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_PlayBlueFogStreet');
	return true;
end
---------------------------------------------------------------
-- 아이린 인사
---------------------------------------------------------------
function LobbyClientEvent_Office_IreneGreeting(company)
	if company.Progress.Character.Irene ~= 8 then
		return false;
	end
	StartLobbyDialog(company, 'Office_IreneGreeting');
	return true;
end
---------------------------------------------------------------
-- 아이작 제안
---------------------------------------------------------------
function LobbyClientEvent_Office_IssacSuggetion2(company)
	if company.Progress.Character.Issac ~= 3 then
		return false;
	end
	StartLobbyDialog(company, 'Office_IssacSuggetion2');
	return true;
end
---------------------------------------------------------------
-- 알버스 제안
---------------------------------------------------------------
function LobbyClientEvent_Office_AlbusSuggetion(company)
	if company.Progress.Character.Anne ~= 2 or company.Progress.Character.Issac < 5 then
		return false;
	end
	StartLobbyDialog(company, 'Office_AlbusSuggetion');
	return true;
end
---------------------------------------------------------------
-- 앤 영입
---------------------------------------------------------------
function LobbyClientEvent_Office_AnneJoin(company)
	if company.Progress.Character.Anne ~= 4 or company.Progress.Tutorial.Opening ~= 'GrayCemeteryPark' then
		return false;
	end
	StartLobbyDialog(company, 'Office_AnneJoin');
	return true;
end
---------------------------------------------------------------
-- 헤이싱 제안
---------------------------------------------------------------
function LobbyClientEvent_Office_HeissingSuggetion(company)
	if company.Progress.Character.Heissing ~= 4 then
		return false;
	end
	StartLobbyDialog(company, 'Office_HeissingSuggetion');
	return true;
end
---------------------------------------------------------------
-- 푸고샵 완료.
---------------------------------------------------------------
function LobbyClientEvent_Office_PugoShopAfterWin(company)
	if company.Progress.Character.Sion ~= 3 then
		return false;
	end
	StartLobbyDialog(company, 'Office_PugoShopAfterWin');
	return true;
end
---------------------------------------------------------------
-- 푸고샵 완료.
---------------------------------------------------------------
function LobbyClientEvent_Office_RecruitHeissing_Complete(company)
	if company.Progress.Character.Heissing ~= 6 then
		return false;
	end
	StartLobbyDialog(company, 'Office_RecruitHeissing_Complete');
	return true;
end
---------------------------------------------------------------
-- 아이린 제안
---------------------------------------------------------------
function LobbyClientEvent_Office_IreneRequestStart(company)
	if company.Progress.Character.Kylie ~= 2 or company.Progress.Character.Irene ~= 9 then
		return false;
	end
	StartLobbyDialog(company, 'Office_IreneRequestStart');
	return true;
end
function LobbyClientEvent_Office_IreneRequest(company)
	if company.Progress.Character.Irene ~= 10 then
		return false;
	end
	StartLobbyDialog(company, 'Office_IreneRequest');
	return true;
end
---------------------------------------------------------------
-- 레이 영입.
---------------------------------------------------------------
function LobbyClientEvent_Office_RayStart(company)
	if company.Progress.Character.Ray ~= 5 then
		return false;
	end
	StartLobbyDialog(company, 'Office_RayStart');
	return true;
end
---------------------------------------------------------------
-- 제인 제안
---------------------------------------------------------------
function LobbyClientEvent_Office_JaneRequestStart(company)
	if not company.MissionCleared.Tutorial_SkyWindPark or company.Progress.Character.Jane ~= 1 then
		return false;
	end	
	StartLobbyDialog(company, 'Office_JaneRequestStart');
	return true;
end
function LobbyClientEvent_Office_JaneRequest(company)
	if company.Progress.Character.Jane ~= 2 then
		return false;
	end
	StartLobbyDialog(company, 'Office_JaneRequest');
	return true;
end
---------------------------------------------------------------
-- 알버스 병원
---------------------------------------------------------------
function LobbyClientEvent_Office_Albus_ReturnOffice(company)
	if company.Progress.Character.Albus ~= 2 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Albus_ReturnOffice');
	return true;
end
---------------------------------------------------------------
-- 지젤 제안
---------------------------------------------------------------
function LobbyClientEvent_Office_GiselleRequest(company)
	if company.Progress.Character.Albus ~= 5 then
		return false;
	end
	StartLobbyDialog(company, 'Office_GiselleRequest');
	return true;
end
---------------------------------------------------------------
-- 지젤 영입.
---------------------------------------------------------------
function LobbyClientEvent_Office_Giselle_Visit03(company)
	if company.Progress.Character.Albus ~= 8 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Giselle_Visit03');
	return true;
end
---------------------------------------------------------------
-- 지젤 영입.
---------------------------------------------------------------
function LobbyClientEvent_Office_Tutorial_AlbusGiselle2(company)
	if company.Progress.Character.Albus ~= 11 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_AlbusGiselle2');
	return true;
end
---------------------------------------------------------------
-- 헤이싱 제안/ 카일리 영입.
---------------------------------------------------------------
function LobbyClientEvent_Office_HeissingRequestStart(company)
	if company.Progress.Character.Albus ~= 12 then
		return false;
	end
	StartLobbyDialog(company, 'Office_HeissingRequestStart');
	return true;
end
function LobbyClientEvent_Office_HeissingRequest(company)
	if company.Progress.Character.Albus ~= 13 then
		return false;
	end
	StartLobbyDialog(company, 'Office_HeissingRequest');
	return true;
end
function LobbyClientEvent_Office_Kylie_Visit02(company)
	if company.Progress.Character.Albus ~= 15 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Kylie_Visit02');
	return true;
end
---------------------------------------------------------------
-- 레톤 영입
---------------------------------------------------------------
function LobbyClientEvent_Office_RecruitLeton_Complete(company)
	if company.Progress.Character.Leton ~= 6 then
		return false;
	end
	StartLobbyDialog(company, 'Office_RecruitLeton_Complete');
	return true;
end
function LobbyClientEvent_Office_RecruitLeton_Complete2(company)
	if company.Progress.Character.Leton ~= 7 then
		return false;
	end
	StartLobbyDialog(company, 'Office_RecruitLeton_Complete2');
	return true;
end
function LobbyClientEvent_Office_RecruitLeton_Complete3(company)
	if company.Progress.Character.Leton ~= 8 then
		return false;
	end
	StartLobbyDialog(company, 'Office_RecruitLeton_Complete3');
	return true;
end
function LobbyClientEvent_Office_ReturnHeissing_Office(company)
	if company.Progress.Character.Heissing ~= 11 then
		return false;
	end
	StartLobbyDialog(company, 'Office_ReturnHeissing_Office');
	return true;
end
-----------------------------------------------------------
-- 아이작 제안
--------------------------------------------------------------
function LobbyClientEvent_Office_IssacCallAlbus(company)
	if company.Progress.Character.Heissing ~= 12 or company.Progress.Character.Albus ~= 18  then
		return false;
	end
	StartLobbyDialog(company, 'Office_IssacCallAlbus');
	return true;
end
-----------------------------------------------------------
-- 카일리 제안
--------------------------------------------------------------
function LobbyClientEvent_Office_KylieRequestStart(company)
	if company.Progress.Character.Albus ~= 21 then
		return false;
	end
	StartLobbyDialog(company, 'Office_KylieRequestStart');
	return true;
end
--------------------------------------------------------------------
-- 작업실.
---------------------------------------------------------------------
function LobbyClientEvent_Office_Tutorial_Workshop_GetInit(company)
	if company.Progress.Tutorial.Office ~= 7 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_Workshop_GetInit');
	return true;
end
function LobbyClientEvent_Office_Tutorial_Workshop_Get(company)
	if company.Progress.Tutorial.Office ~= 8 or company.Progress.Tutorial.Workshop ~= 1 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_Workshop_Get');
	return true;
end
function LobbyClientEvent_Office_Tutorial_OfficeMoveIn10(company)
	if company.Progress.Tutorial.Office ~= 9 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_OfficeMoveIn10');
	return true;
end
function LobbyClientEvent_Office_Tutorial_Workshop_Upgrade(company)
	if not StringToBool(company.WorkshopMenu.Upgrade.Tutorial) or not StringToBool(company.WorkshopMenu.Upgrade.Opened) then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_Workshop_Upgrade');
	return true;
end
function LobbyClientEvent_Office_Tutorial_Workshop_Upgrade2(company)
	if company.Progress.Tutorial.Upgrade ~= 1 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_Workshop_Upgrade2');
	return true;
end
function LobbyClientEvent_Office_Tutorial_Workshop_Machine(company)
	if not StringToBool(company.WorkshopMenu.Machine.Opened) or not StringToBool(company.WorkshopMenu.Machine.Tutorial) then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_Workshop_Machine');
	return true;
end
function LobbyClientEvent_Office_Tutorial_Workshop_Machine2(company)
	if company.Progress.Tutorial.MachineCraft ~= 2 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_Workshop_Machine_2');
	return true;
end
-- 오류 방어용.. 원래는 기계 제작과 함께 열려야함..
function LobbyClientEvent_Office_Tutorial_Workshop_Module(company)
	if not StringToBool(company.WorkshopMenu.Module.Tutorial) then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_Workshop_Module');
	return true;
end
function LobbyClientEvent_Office_Tutorial_Workshop_Module1(company)
	if company.Progress.Tutorial.ModuleCraft ~= 1 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_Workshop_Module1');
	return true;
end
function LobbyClientEvent_Office_Tutorial_Workshop_Module2(company)
	if company.Progress.Tutorial.ModuleCraft ~= 2 then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_Workshop_Module2');
	return true;
end
---------------------------------------------------------------------
-- 오피스
---------------------------------------------------------------------
-- 오피스로 화면 이동할때
function LobbyClientEvent_FirstEnterOffice(company)

	-- 튜토리얼 사무실.
	if StringToBool(company.OfficeMenu.Tutorial, true) then
		--StartLobbyDialog(company, 'Office_TutorialOffice_Office_Worldmap'); 데이터가 없음
		return true;
	end
	
	return false;
end
-- 월드맵을 열때.
function LobbyClientEvent_FirstEnterWorldMap(company)
	-- 튜토리얼 다이어로그
	if StringToBool(company.OfficeMenu.Worldmap.Tutorial, true) then
		StartLobbyDialog(company, 'Office_TutorialOffice_WorldmapExplain');	
		return true;
	end
	
	return false;
end
-- 트러블 북을 열때.
function LobbyClientEvent_FirstEnterTroubleBook(company)
	-- 튜토리얼 다이어로그
	if StringToBool(company.OfficeMenu.TroubleBook.Tutorial, true) then
		StartLobbyDialog(company, 'Office_TutorialOffice_TroubleBookExplain');	
		return true;
	end	
	return false;
end
-- 업데이트 공지
function LobbyClientEvent_Common_CheckNotice(company)
	local noticeList = GetNeedNoticeList(company);
	if #noticeList == 0 then
		return false;
	end
	for _, noticeKey in ipairs(noticeList) do
		StartLobbyDialog(company, 'Notice_Common', { notice_type = noticeKey });
	end
	return true;
end
-- 어빌리티 변경 튜토리얼
function LobbyClientEvent_AbilityChangeTutorial(company)
	if company.Progress.Tutorial.AbilityChange ~= 0 then
		return false;
	end
	StartLobbyDialog(company, 'Tutorial_AbilityChange_1');
	return true;
end
function LobbyClientEvent_AbilityChangeTutorial_2(company)
	if company.Progress.Tutorial.AbilityChange ~= 1 then
		return false;
	end
	StartLobbyDialog(company, 'Tutorial_AbilityChange_2');
	return true;
end
-- 클래스 변경 튜토리얼
function LobbyClientEvent_ClassChangeTutorial(company)
	if company.Progress.Tutorial.ClassChange ~= 0 then
		return false;
	end
	StartLobbyDialog(company, 'Tutorial_ClassChange_1');
	return true;
end
function LobbyClientEvent_ClassChangeTutorial_2(company)
	if company.Progress.Tutorial.ClassChange ~= 1 then
		return false;
	end
	StartLobbyDialog(company, 'Tutorial_ClassChange_2');
	return true;
end
function LobbyClientEvent_ClassChangeTutorial_3(company)
	if company.Progress.Tutorial.ClassChange ~= 2 then
		return false;
	end
	StartLobbyDialog(company, 'Tutorial_ClassChange_3');
	return true;
end
-- 지젤 사냥꾼 이벤트
function LobbyClientEvent_Office_GiselleHunterEvent(company)
	if GetRoster(company, 'Giselle') == nil or company.Progress.Tutorial.Hunter ~= 0 then
		return false;
	end
	StartLobbyDialog(company, 'Office_GiselleHunterEvent_1');
	return true;
end
function LobbyClientEvent_Office_GiselleHunterEvent_2(company)
	if company.Progress.Tutorial.Hunter ~= 1 then
		return false;
	end
	StartLobbyDialog(company, 'Office_GiselleHunterEvent_2');
	return true;
end
-- 기계 제작 오픈 이벤트 (바)
function LobbyClientEvent_Office_MachineCraft_1(company)
	if company.Progress.Tutorial.MachineCraft ~= 0 or GetRoster(company, 'Kylie') == nil then
		return false;
	end
	StartLobbyDialog(company, 'Office_MachineCraft_1');
	return true;
end
-- 기계 제작 오픈 이벤트 (작업실)
function LobbyClientEvent_Office_MachineCraft_2(company)
	if company.Progress.Tutorial.MachineCraft ~= 1 then
		return false;
	end
	StartLobbyDialog(company, 'Office_MachineCraft_2');
	return true;
end
-- 첫 기체 제작 이벤트
function LobbyClientEvent_Office_FirstMachineEvent(company)
	if company.Progress.Tutorial.MachineCraft ~= 3 then
		return false;
	end
	StartLobbyDialog(company, 'Office_FirstMachineEvent');
	return true;
end
-- 기계 가동률 이벤트
function LobbyClientEvent_Office_BrokenMachineEvent(company)
	if company.Progress.Tutorial.BrokenMachine ~= 0 then
		return false;
	end
	StartLobbyDialog(company, 'Office_BrokenMachineEvent');
	return true;
end
-- 재료 도감
function LobbyClientEvent_Office_ItemBookOpenEvent(company)
	if StringToBool(company.OfficeMenu.ItemBook.Opened, false) or  company.Progress.Tutorial.ItemBook ~= 3 then
		return false;
	end
	StartLobbyDialog(company, 'Office_ItemBookOpenEvent');
	return true;
end
-- 재료 도감 튜토리얼
function LobbyClientEvent_Office_ItemBookOpenEvent_Tutorial(company)
	if not StringToBool(company.OfficeMenu.ItemBook.Opened, false) or company.Progress.Tutorial.ItemBook ~= 4 then
		return false;
	end
	StartLobbyDialog(company, 'Office_ItemBookOpenEvent_Tutorial');
	return true;
end
-- 특성 세트 튜토리얼
function LobbyClientEvent_Office_Tutorial_MasterySet(company)
	if company.MasterySetIndex.Bonecrusher then
		return false;
	end
	StartLobbyDialog(company, 'Office_Tutorial_MasterySet');
	return true;
end
-- 드라키의 둥지
function LobbyClientEvent_Open_DrakyNest2(company)
	if company.Progress.Tutorial.GuideDrakyNest2 or not company.MissionCleared.Raid_DrakyNest or not company.Progress.Mission.DrakyNest  then
		return false;
	end
	StartLobbyDialog(company, 'Open_DrakyNest2');
	return true;
end
-- 아시아 서버 한정 보상 지급
function LobbyClientEvent_CheckAsiaServerErrorReward_NeedReward(company)
	if not company.NeedAsiaServerErrorReward then
		return false;
	end
	StartLobbyDialog(company, 'CheckAsiaServerErrorReward', {need_reward=true});
	return true;
end
function LobbyClientEvent_CheckAsiaServerErrorReward_NoReward(company)
	if not company.NeedAsiaServerErrorReward then
		return false;
	end
	StartLobbyDialog(company, 'CheckAsiaServerErrorReward', {need_reward=false});
	return true;
end
function ProgressCheckAsiaServerErrorReward(ds, self, company, env, parsedScript)
	local needReward = parsedScript.NeedReward;
	if needReward then
		-- 보상 공지
		ProgressNoticeAction(ds, self, company, env, { NoticeType = 'AsiaServerErrorReward' });
		-- 보상 지급
		local dc = ds:GetDatabaseCommiter();
		CheckAsiaServerErrorReward(ds, company, dc)
		return true;
	else
		-- 보상 받을 유저가 아님
		local dc = ds:GetDatabaseCommiter();
		dc:UpdateCompanyProperty(company, 'NeedAsiaServerErrorReward', false);
		return dc:Commit('ProgressCheckAsiaServerErrorReward');	
	end
end