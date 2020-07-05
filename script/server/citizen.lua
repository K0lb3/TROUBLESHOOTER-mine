function InitializeCitizen_Healty(mission, citizenCls, citizenDecl, citizenObj)
	AddBuff(citizenObj, 'Rescue', 1);
	-- 마우스 픽킹 시에 알림 이펙트 표시를 위한 더미 상호작용 추가
end

function InitializeCitizen_Fake(mission, citizenCls, citizenDecl, citizenObj)
	AddBuff(citizenObj, 'FakeRescue', 1);
	SetInstantProperty(citizenObj, 'FakeObject', citizenDecl.FakeObject);
end

function InitializeCitizen_Injured(mission, citizenCls, citizenDecl, citizenObj)
	AddBuff(citizenObj, 'InjuredRescue', 1);
	EnableInteraction(citizenObj, 'Cure');
	citizenObj.HP = math.floor(citizenObj.MaxHP * math.random(50, 65) / 100);	-- 반피+@로 시작
	citizenObj.Act = citizenObj.Wait + math.random(1, 50);						-- Wait+@ Act로 시작
end

function InitializeCitizen_Unrest(mission, citizenCls, citizenDecl, citizenObj)
	AddBuff(citizenObj, 'Civil_Unrest', 1);
	EnableInteraction(citizenObj, 'Comfort');
end

function InitializeCitizen_Child(mission, citizenCls, citizenDecl, citizenObj)
	AddBuff(citizenObj, 'Civil_Child_Rescue', 1)
end