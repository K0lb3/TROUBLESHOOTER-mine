---------------------------------------------------------------------
-- 조직, 우호도 변했을때 값 리턴
---------------------------------------------------------------------
-- 개인(Npc) / 조직(Organization) 공용
function UpdateFriendship(dc, company, objType, objName, addPoint)
	-- 우호도 변화가 없는 퀘스트 처리.
	if objType == 'None' then
		return;
	end
	
	local friendshipList = GetClassList('Friendship');
	local objList = nil;
	if objType == 'Npc' then
		objList = company.Npc[objName];
	elseif objType == 'Organization' then
		objList = company.Organization[objName];
	end
	addPoint = GetFriendshipChangeAmount(company, objType, objName, addPoint);
	
	-- 1. 선후 랭크 찾기
	local prevFriendShip = objList.Friendship;
	local curRank = friendshipList[prevFriendShip];
	local curRankValue = curRank.Rank;
	local upRank = nil;
	local downRank = nil;
	for key, value in pairs (friendshipList) do
		if value.Rank == curRankValue + 1 then
			upRank = value;
		elseif value.Rank == curRankValue - 1 then
			downRank = value;
		end
	end

	local resultRank = curRank;
	local curPoint = objList.FriendshipPoint;
	local totalPoint = addPoint + curPoint;
	if totalPoint > curRank.MaxPoint then
		if upRank ~= nil then
			-- 1. 우호도 등급 상승
			totalPoint = 0;
			resultRank = upRank;
		else
			totalPoint = curRank.MaxPoint;
			addPoint = totalPoint - curPoint;
		end
	elseif totalPoint < 0 and downRank then
		if downRank ~= nil then
			-- 2. 우호도 등급 하향
			totalPoint = downRank.MaxPoint;
			resultRank = downRank;
		else
			totalPoint = 0;
			addPoint = totalPoint - curPoint;
		end
	end	
	
	dc:UpdateCompanyProperty(company, objType..'/'..objName..'/'..'Friendship', resultRank.name);
	dc:UpdateCompanyProperty(company, objType..'/'..objName..'/'..'FriendshipPoint', totalPoint);
	return resultRank.name, totalPoint, addPoint, prevFriendShip.name;
end