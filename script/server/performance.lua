function AddPerformanceEffectAction(actions, owner, effectType, abilityName)
	local effectLv = GetPerformanceEffectLv(owner);
	local performanceList = GetInstantProperty(owner, 'PerformanceList') or {};
	table.insert(performanceList, { Type = effectType, Lv = effectLv });
	table.insert(actions, Result_UpdateInstantProperty(owner, 'PerformanceList', performanceList, true));
	-- 액션이 처리되기 전의 서버 로직에서 반영되도록 바로 적용
	SetInstantProperty(owner, 'PerformanceList', performanceList);
	-- 이벤트 던짐
	table.insert(actions, Result_FireWorldEvent('PerformanceEffectAdded', {Unit = owner, Effect = effectType, Lv = effectLv, Ability = abilityName}));
end

function AddPerformanceGreatActionForDS(actions, owner, greatCls, ds)
	ds:UpdateBattleEvent(GetObjKey(owner), 'PerformanceGreatInvoked', { Great = greatCls.name });
	-- 적용 범위
	local applyDist = GetPerformanceGreatApplyDist(owner, greatCls);
	-- 멋짐 효과 발동
	local applyFunc = _G['ApplyPerformanceGreatAction_'..greatCls.ApplyType];
	if applyFunc then
		applyFunc(actions, owner, greatCls, applyDist, ds);
	end
	-- 멋짐 레벨 누적
	local nextLv = owner.PerformanceGreatLv + 1;
	table.insert(actions, Result_PropertyUpdated('PerformanceGreatLv', nextLv, owner, false, true));
	owner.PerformanceGreatLv = nextLv;
	-- 이벤트 던짐
	table.insert(actions, Result_FireWorldEvent('PerformanceGreatInvoked', {Unit = owner, Great = greatCls.name, GreatLv = nextLv}));
end
-- 놀람, 위압
function ApplyPerformanceGreatAction_EnemyBuff(actions, owner, greatCls, applyDist, ds)
	local nearEnemies = Linq.new(GetNearObject(owner, applyDist + 0.4))
		:where(function(o) return IsEnemy(owner, o) end)
		:toList();
	for _, target in ipairs(nearEnemies) do
		InsertBuffActions(actions, owner, target, greatCls.Buff.name, 1, true);	
	end
end
-- 경이, 현란
function ApplyPerformanceGreatAction_AllyBuff(actions, owner, greatCls, applyDist, ds)
	local nearAllies = Linq.new(GetNearObject(owner, applyDist + 0.4))
		:where(function(o) return IsAllyOrTeam(owner, o) end)
		:toList();
	for _, target in ipairs(nearAllies) do
		InsertBuffActions(actions, owner, target, greatCls.Buff.name, 1, true);	
	end
end
-- 유희
function ApplyPerformanceGreatAction_AllySP(actions, owner, greatCls, applyDist, ds)
	local nearAllies = Linq.new(GetNearObject(owner, applyDist + 0.4))
		:where(function(o) return IsAllyOrTeam(owner, o) end)
		:toList();
	for _, target in ipairs(nearAllies) do
		AddSPPropertyActionsObject(actions, target, greatCls.ApplyAmount2, true, ds, true);
	end
end
-- 연속
function ApplyPerformanceGreatAction_SelfAction(actions, owner, greatCls, applyDist, ds)
	AddActionRestoreActions(actions, owner);
end
-- 폭발
function ApplyPerformanceGreatAction_EnemyAct(actions, owner, greatCls, applyDist, ds)
	local nearEnemies = Linq.new(GetNearObject(owner, applyDist + 0.4))
		:where(function(o) return IsEnemy(owner, o) end)
		:toList();
	for _, target in ipairs(nearEnemies) do
		AddActionApplyActForDS(actions, target, greatCls.ApplyAmount2, ds, 'Hostile');
	end
end

function AddPerformanceFinishActionForDS(actions, owner, performanceCls, greatLv, effectCount, ds)
	if greatLv < 0 then
		return;
	end
	ds:UpdateBattleEvent(GetObjKey(owner), 'PerformanceFinishInvoked', { GreatLv = greatLv });
	for _, info in ipairs(performanceCls.Finish) do
		if info.Lv <= greatLv then
			local finishCls = GetClassList('PerformanceFinish')[info.Type];
			if finishCls then
				-- 적용 범위
				local applyDist = GetPerformanceFinishApplyDist(owner, finishCls);
				-- 마무리 효과 발동
				local applyFunc = _G['ApplyPerformanceFinishAction_'..finishCls.ApplyType];
				if applyFunc then
					applyFunc(actions, owner, finishCls, applyDist, ds);
				end
			end
		end	
	end
	-- 멋짐 레벨 초기화
	local nextLv = 0;
	table.insert(actions, Result_PropertyUpdated('PerformanceGreatLv', nextLv, owner, false, true));
	owner.PerformanceGreatLv = nextLv;
	-- 이벤트 던짐
	table.insert(actions, Result_FireWorldEvent('PerformanceFinishInvoked', {Unit = owner, GreatLv = greatLv, EffectCount = effectCount}));
	-- 회사, 스팀 통계
	local company = GetCompany_Shared(owner);
	if company then
		AddCompanyStats(company, 'PerformanceFinishCount', 1);
		local team = GetTeam(owner);
		table.insert(actions, Result_DirectingScript(function(mid, ds, args)
			ds:AddSteamStat('PerformanceFinishCount', 1, team);
		end));
	end
end
function ApplyPerformanceFinishAction_EnemyAct(actions, owner, finishCls, applyDist, ds)
	local nearEnemies = Linq.new(GetNearObject(owner, applyDist + 0.4))
		:where(function(o) return IsEnemy(owner, o) end)
		:toList();
	for _, target in ipairs(nearEnemies) do
		AddActionApplyActForDS(actions, target, finishCls.ApplyAmount2, ds, 'Hostile');
	end
end
function ApplyPerformanceFinishAction_EnemySP(actions, owner, finishCls, applyDist, ds)
	local nearEnemies = Linq.new(GetNearObject(owner, applyDist + 0.4))
		:where(function(o) return IsEnemy(owner, o) end)
		:toList();
	for _, target in ipairs(nearEnemies) do
		AddSPPropertyActionsObject(actions, target, -1 * finishCls.ApplyAmount2, true, ds, true);
	end
end
function ApplyPerformanceFinishAction_EnemyBuff(actions, owner, finishCls, applyDist, ds)
	local nearEnemies = Linq.new(GetNearObject(owner, applyDist + 0.4))
		:where(function(o) return IsEnemy(owner, o) end)
		:toList();
	for _, target in ipairs(nearEnemies) do
		InsertBuffActions(actions, owner, target, finishCls.Buff.name, 1, true);	
	end
end
function ApplyPerformanceFinishAction_AllyAct(actions, owner, finishCls, applyDist, ds)
	local nearAllies = Linq.new(GetNearObject(owner, applyDist + 0.4))
		:where(function(o) return IsAllyOrTeam(owner, o) end)
		:toList();
	for _, target in ipairs(nearAllies) do
		AddActionApplyActForDS(actions, target, -1 * finishCls.ApplyAmount2, ds, 'Friendly');
	end
end
function ApplyPerformanceFinishAction_AllySP(actions, owner, finishCls, applyDist, ds)
	local nearAllies = Linq.new(GetNearObject(owner, applyDist + 0.4))
		:where(function(o) return IsAllyOrTeam(owner, o) end)
		:toList();
	for _, target in ipairs(nearAllies) do
		AddSPPropertyActionsObject(actions, target, finishCls.ApplyAmount2, true, ds, true);
	end
end
function ApplyPerformanceFinishAction_AllyBuff(actions, owner, finishCls, applyDist, ds)
	local nearAllies = Linq.new(GetNearObject(owner, applyDist + 0.4))
		:where(function(o) return IsAllyOrTeam(owner, o) end)
		:toList();
	for _, target in ipairs(nearAllies) do
		InsertBuffActions(actions, owner, target, finishCls.Buff.name, 1, true);	
	end
end