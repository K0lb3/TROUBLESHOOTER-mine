--- 시나리오 미션
-- 시온 영입: 푸고 스트리트.
function CheckZoneEvent_Tutorial_Event1(company)
	return company.Progress.Zone.EventType == 'Zone00';
end
-- 영일 공사장 아이린: 아이린 영입 언락.
function CheckZoneEvent_Tutorial_Event2(company)
	return company.Progress.Zone.EventType == 'Zone01' and (company.Progress.Character.Irene == 0 or company.Progress.Character.Irene == 1);
end
-- 로드 113 헤이싱: 첫 등장.
function CheckZoneEvent_Tutorial_Event3(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.Progress.Character.Pierto == 0;
end
-- 크로우빌애프터 : 아이린 앤.
function CheckZoneEvent_Tutorial_Event4(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.Progress.Character.Pierto == 1 and company.Progress.Character.Irene == 2;
end
-- 자홍뒷거리 : 아이린, 앤, 시온, 알버스
-- 시온의 제안 이후 진행 가능.
function CheckZoneEvent_Tutorial_Event5(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.Progress.Character.Heissing == 2 and company.Progress.Character.Irene == 3;
end
--푸고뒷거리 : 아이린, 시온, 알버스
-- 마르코 이벤트 진행 후 가능.
function CheckZoneEvent_Tutorial_Event6(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.Progress.Character.Marco == 5 and company.Progress.Character.Sharky == 1;
end
-- 잿빛 항구 선착장 : 아이린, 시온, 알버스, 앤
-- 앤 영입 후 진행 가능. 알리사, 비앙카 프로퍼티 막힘.
function CheckZoneEvent_Tutorial_Event7(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.Progress.Character.Anne == 5 and company.Progress.Character.Ryo == 0;
end
-- 철의숲 간이역 : 아이린, 시온, 알버스, 앤
-- 앤 영입 후 진행 가능. 대니 프로퍼티로 막힘.
function CheckZoneEvent_Tutorial_Event8(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.Progress.Character.Anne == 5 and company.Progress.Character.Danny == 0;
end
-- 철의숲 중턱 : 아이린, 시온, 알버스, 앤
-- 앤 영입 후 진행 가능. 아이작 프로퍼티로 막힘.
-- 잿빛 항구 선착장 , 철의숲 간이역 클리어 후 나오도록 수정.
function CheckZoneEvent_Tutorial_Event9(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.Progress.Character.Anne == 5 and company.Progress.Character.Issac == 5 and company.Progress.Character.Danny == 1 and company.Progress.Character.Ryo == 1;
end
-- 푸른 안개 상점가 : 아이린, 시온, 알버스, 앤
-- 철의숲 물류캠프 이후.
function CheckZoneEvent_Tutorial_Event10(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.Progress.Character.Issac == 6;
end
-- 자홍거리 : 아이린, 시온, 알버스, 앤
-- 푸른 안개 상점가 이후.
function CheckZoneEvent_Tutorial_Event11(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.Progress.Character.Issac == 7 and company.Progress.Character.Ryo == 1;
end
-- 한솔거리 : 아이린, 시온, 알버스, 앤
-- 푸고샵애프터 이후.
function CheckZoneEvent_Tutorial_Event12(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.Progress.Character.Sion == 4 and company.Progress.Character.Heissing == 3;
end
--  철의 숲 보호관리구역: 아이린, 시온, 알버스, 앤, 헤이싱
function CheckZoneEvent_Tutorial_Event13(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.Progress.Character.Heissing == 7 and company.Progress.Character.Kylie == 1;
end
-- 별빛 거리: 아이린, 시온, 알버스, 앤, 헤이싱
-- 달빛 거리 완료 후.
function CheckZoneEvent_Tutorial_Event14(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_MetroStreet and not company.MissionCleared.Tutorial_StarStreet;
end
-- 초승달 대교: 아이린, 시온, 알버스, 앤, 헤이싱
-- 철의 숲 완료 후
function CheckZoneEvent_Tutorial_Event15(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_StarStreet and not company.MissionCleared.Tutorial_CrescentBridge;
end
-- 잿빛 항구 물류 창고: 아이린, 시온, 알버스, 앤, 헤이싱
-- 달빛 거리 완료 후.
function CheckZoneEvent_Tutorial_Event16(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_CrescentBridge and not company.MissionCleared.Tutorial_GrayPortWareHouse;
end
-- 먼지바람 톨게이트: 아이린, 시온, 알버스, 앤, 헤이싱
-- 달빛 거리와 잿빛 항구 H 물루 창고 완료 후.
function CheckZoneEvent_Tutorial_Event17(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_GrayPortWareHouse and company.MissionCleared.Tutorial_StarStreet and not company.MissionCleared.Tutorial_DustWind;
end
-- 하늘 바람 공원: 아이린, 시온, 알버스, 앤, 헤이싱, 레이
-- 레이 영입 후.
function CheckZoneEvent_Tutorial_Event18(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_DustWind and company.Progress.Character.Ray >= 6 and not company.MissionCleared.Tutorial_SkyWindPark;
end
-- 푸고뒷골목애프터.
-- 경찰 훈련장 이후
function CheckZoneEvent_Tutorial_Event19(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_TrainingRoom and	not company.MissionCleared.Tutorial_PugoBackStreetAfter;
end
-- 자원 개발 구역.
function CheckZoneEvent_Tutorial_Event20(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_GrayCemeteryParkAfter and not company.MissionCleared.Tutorial_Road_111;
end
-- 먼지바람 고속도로 휴게소.
function CheckZoneEvent_Tutorial_Event21(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_Road_111 and not company.MissionCleared.Tutorial_DustWindRestArea;
end
-- 은빛 구름 시장 거리.
function CheckZoneEvent_Tutorial_Event22(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_DustWindRestArea and not company.MissionCleared.Tutorial_MarketStreet;	
end
-- 자홍 거리 상점가
function CheckZoneEvent_Tutorial_Event23(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_Road_110 and not company.MissionCleared.Tutorial_PurpleStreetAfter;	
end
-- 까마귀 폐허
function CheckZoneEvent_Tutorial_Event24(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_PurpleStreetAfter and not company.MissionCleared.Tutorial_CrowRuins;	
end
-- 푸고샵 애프터
function CheckZoneEvent_Tutorial_Event25(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_CrowRuins and not company.MissionCleared.Tutorial_PugoStreetAfter;	
end
-- 까마귀 폐허 도꺠비굴
function CheckZoneEvent_Tutorial_Event26(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_PugoStreetAfter and not company.MissionCleared.Tutorial_WasteBuilding;	
end
-- 까마귀 폐허 지하 수로.
function CheckZoneEvent_Tutorial_Event27(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_WasteBuilding and not company.MissionCleared.Tutorial_GroundWaterSlum;	
end
-- 까마귀 폐허 애프터
function CheckZoneEvent_Tutorial_Event28(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.Progress.Character.Leton > 8 and company.MissionCleared.Tutorial_GroundWaterSlum and not company.MissionCleared.Tutorial_CrowRuinsAfter;	
end
-- 자홍거리 뒷골목.
function CheckZoneEvent_Tutorial_Event29(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_SilverliningAfter and not company.MissionCleared.Tutorial_WhiteTigerBase;	
end
---------------------------------------------------------------- 
--- 반복 미션
---------------------------------------------------------------- 
-- 1. 가랑잎 공원.
function CheckZoneEvent_Common_Event0(company)
	return company.Progress.Zone.EventType == 'Zone01';
end
-- 2. 영일 공사장
function CheckZoneEvent_Common_Event1(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_Construction_A;
end
-- 3. 로드 114
function CheckZoneEvent_Common_Event2(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_Road_113;
end
-- 4. 은빛 토끼 공원
function CheckZoneEvent_Common_Event3(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_CrowBillAfter;
end
-- 5. 푸고 중심자 지하 주차장.
function CheckZoneEvent_Common_Event4(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_PugoShop;
end
-- 5. 로드 115
function CheckZoneEvent_Common_Event5(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_BlueFogStreet;
end
-- 6. 메트로디움 거리 옥상 주차장. - 푸고뒷골목
function CheckZoneEvent_Common_Event6(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_PugoBackStreet;
end
-- 7. 성난 술통 야외 주차장. - 잿빛 공원 묘지
function CheckZoneEvent_Common_Event7(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_GrayCemeteryPark;
end
-- 8. 잿빛 항구 외곽 주유소 - 철의 숲 간이역 
function CheckZoneEvent_Common_Event8(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_Orsay;
end
-- 9. 푸른 안개 거리 - 
function CheckZoneEvent_Common_Event9(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_SkyBlue;
end
-- 10. 자홍 거리 - 자홍거리 이후.
function CheckZoneEvent_Common_Event10(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_PugoShopAfter;
end
-- 11. 철의 숲 마라 늪 - 로드 112 이후.
function CheckZoneEvent_Common_Event11(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_Road_112;
end
-- 12. 철의 숲 안개 절벽 - 로드 112 이후
function CheckZoneEvent_Common_Event12(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_Road_112;
end
-- 13. 메트로디움 거주구
-- 별빛 거리 클리어 후
function CheckZoneEvent_Common_Event13(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_StarStreet;
end
-- 14. 물류 창고.
-- H 물류 창고 클리어 후.
function CheckZoneEvent_Common_Event14(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_GrayPortWareHouse;
end
-- 15. 하늘바람 공원
-- 과거의 잔향 클리어.
function CheckZoneEvent_Common_Event15(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_SkyWindPark;
end
-- 16. 그림자 장벽 지하수로
-- 푸고 뒷골목 애프터 클리어.
function CheckZoneEvent_Common_Event16(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_PugoBackStreetAfter;
end
-- 17. 자원 개발 구역
-- 자원 개발 구역 클리어후 /로드 111
function CheckZoneEvent_Common_Event17(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_Road_111;
end
-- 18. 추봉도 하역장
-- 먼지바람 고속도로 휴게소 클리어.
function CheckZoneEvent_Common_Event18(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_DustWindRestArea;
end
-- 19. 외곽도로 정비소
-- 먼지바람 고속도로 휴게소 클리어.
function CheckZoneEvent_Common_Event19(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_Road_110;
end
-- 20 푸고 번화가
-- 푸고 번화가 클리어.
function CheckZoneEvent_Common_Event20(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_PugoStreetAfter;
end
-- 21. 까마귀 폐허 지하수로
-- 까마귀 폐허 지하수로 클리어.
function CheckZoneEvent_Common_Event21(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_GroundWaterSlum;
end
---------------------------------------------------------------- 
--- 레이드 미션.
---------------------------------------------------------------- 
-- 1. 자홍 뒷거리 반복.
function CheckZoneEvent_Raid_Event1(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_PugoBackStreet;
end
-- 2. 로코 산장.
function CheckZoneEvent_Raid_Event2(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_LokoCabin;
end
-- 3. 그늘 안개 슬럼가
function CheckZoneEvent_Raid_Event3(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_PugoShopAfter;
end
-- 4. 철의 숲 수원지.
function CheckZoneEvent_Raid_Event4(company)
	return company.Progress.Zone.EventType == 'Zone01' and  company.MissionCleared.Tutorial_Road_112;
end
-- 5. 별빛 사거리.
function CheckZoneEvent_Raid_Event5(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_SkyWindPark;
end
-- 6. 철의 숲 오염지
function CheckZoneEvent_Raid_Event6(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_Road_111;
end
-- 7. 푸른 안개 물류 창고.
function CheckZoneEvent_Raid_Event7(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_PurpleStreetAfter;
end
-- 8. 철의 숲 버려진 동굴
function CheckZoneEvent_Raid_Event8(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_GroundWaterSlum;
end
-- 9. 드라키 둥지
function CheckZoneEvent_Raid_Event9(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Raid_DrakyNest and company.Progress.Mission.DrakyNest;
end
-- 10. 자홍거리 상점가
function CheckZoneEvent_Raid_Event10(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Tutorial_CrowRuinsAfter;
end
-- 11. 그림자 장벽 지하수로
function CheckZoneEvent_Raid_Event11(company)
	return company.Progress.Zone.EventType == 'Zone01' and company.MissionCleared.Raid_DrakyNest2 and company.MissionCleared.Quest_Bruna01;
end
-----------------------------------------------------------------
-- 퀘스트
-----------------------------------------------------------------
function GetQuestState_Shared(company, questType)
	if IsLobbyServer() then
		return GetQuestState(company, questType);
	else
		local session = GetSession();
		local quests = session.quests;
		local qI = quests[questType];
		if not qI then
			return 'Error';
		end
		return qI.Stage, qI.Progress;
	end
end

function GetQuestEventSlotCompany(company, zoneType)
	local questInfos = {};
	local zoneCls = GetClassList('Zone')[zoneType];
	if not zoneCls then
		return questInfos;
	end
	local itemCounter = nil;
	if IsLobbyServer() then
		itemCounter = LobbyInventoryItemCounter(company);
	else
		local session = GetSession();
		itemCounter = ClientItemCountAcquirer(session.inventory);
	end
	for i, questCls in ipairs(zoneCls.LinkedQuest) do
		local state, progress = GetQuestState_Shared(company, questCls.name);
		if not questCls.DisableWorldMap and state == 'InProgress' and not CheckRequestState(company, questCls, progress, itemCounter) then
			SafeInsert(questInfos, questCls.Mission.Slot, questCls.name);
		end
	end
	return questInfos;
end