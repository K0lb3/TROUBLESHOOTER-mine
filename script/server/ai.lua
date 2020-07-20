----------------------------------------------------------------------
-- AIAction
-- @param script ai.lua 에 있는 AI함수 이름
-- @param abilities Ability.xml 에 있는 class 정보를 담고 있는 table

-- Writer: passion053
----------------------------------------------------------------------
function AIAction(self, script, args, abilities)
	if args == nil then
		args = {};
	end
	LogAndPrintDev('AIAction', GetObjKey(self), script, PackTableToStringReadable(abilities));
	local startTime = os.clock();
	local usingAbility, pos, debugInfo, subPositions = _G[script](self, abilities, args);
	if usingAbility == nil then
		UnitTurnEnd(self);
	else
		if not UnitUseAbility(self, usingAbility.name, pos, subPositions) then
			UnitTurnEnd(self);
		end
	end
end
-------------------
--- AI Strategy ---
-------------------
-- 대기 전략 --
-- 은 몰라.
-------------
-- 이동 전략 --
--[[
	Attackable 					-- (bool) 							공격가능 여부 체크 
	AttackableEx					-- (function) -> (bool) 				공격가능 여부 체크 엑스트라
	ForeachActionInfo				-- (function) -> (void)				어빌리티 사용 가능성별 테스팅함수
	ForeachAttackInfo				-- (function) -> (void)				공격 어빌리티 사용 가능성별 테스트 함수
	TargetAttackable				-- (bool)							AI 대상 공격 가능여부
	Coverable					-- (bool)							엄폐가능 여부 체크
	Dangerous					-- (number)							적군 밀집도 체크 ( 6 칸 이내 적군 수 )
	CoverScore					-- (number)							엄폐 수준 체크 (0 ~ 100)
	Accuracy						-- (number)							공격 정확도 체크
	Damage						-- (number)							피해량 체크
	AllyDensity					-- (number, [function]) -> (number) 	아군 밀집도 체크 ( N 칸 이내 자신을 제외한 아군 유닛 수)
	DeadlyAttack					-- (number)							사망각 체크, 광역 사용불가
	TotalObjectDistanceByFilter	-- (function) -> (number)				시야 내 필터된 대상들과의 거리합
	MinObjectDistanceByFilter		-- (function) -> (number)				시야 내 가장 가까운 필터된 대상들과의 거리
	TotalEnemyDistance			-- (number)							적과의 거리합
	MinEnemyDistance				-- (number)							팀 시야 내 가장 가까운 적과의 거리
	MinBadFieldDistance			-- (number)							팀 시야 내 가장 가까운 자연재해와의 거리
	TargetDistance				-- (number)							AI의 대상과의 거리
	MoveDistance					-- (number)							이동해야하는 거리
	BasePosition					-- (position)						시작 위치
	Position						-- (position)						테스트 중인 위치
	TotalBadFieldDistance			-- (number)							디버프 지형효과와의 거리합
	RepairAmount					-- (number)							자가 회복량 (1당 기본 회복량)
	ClearPath					-- (bool)							경로상에 나쁜 영향을 주는 필드가 존재하는가
	BadField						-- (bool)							도착 지점이 좋지 못한 필드인가
	EnemyCount					-- (number)							시야에 들어오는 적의 수
	AttractiveScore				-- (number)							현 위치의 추가 매력지수 (주변 아군의 버프로 인한 보정)
	SideAttackCount				-- (number)							현 위치에서 측면이 노출되는 적의 	수
	MovePath					-- (table of position)				이동 경로
]]

-------------------------------------------------------------------------------------------------
-- 이동 후 행동 전략 --
---------------------------------------------------------------------------
-- 공격
----------------------------------------------------------------------------
		-- 공격 선택 관련 입력 인자는 AttackInfo{Ability, Object, Pos, Damage, Accuracy}
		-- 지원 선택 관련.. 입력 인자는 SupportInfo{Ability, Object, Pos}
--[[
	DeathPossibility					-- (number)			사망확률
	Accuracy							-- (number)			정확도 평균
	Damage								-- (number)			데미지
	RemainHP							-- (number)			적의 현재 체력
	Hate								-- (number)			최대 싫은 놈
	IsTarget							-- (bool)			대상인가?
	IsCitizen							-- (bool)			시민인가?
	IsIndirect							-- (bool)			간접 공격인가?
	RepairAmount						-- (number)			회복량
	Efficiency							-- (number)			지원 효율계산
	Ability								-- (object)			사용할 어빌리티
	Distance							-- (number)			사용거리
	Object								-- (object)			사용대상
	Position							-- (position)		사용위치
	NoCoverAttack						-- (bool)			무방비 노출 공격
	ApplyTargets						-- (table of object)	어빌리티 적용대상 리스트
]]

-- 이동 AI 함수에 대한 설명.
--[[
이동 전략 AI는 현 시점에서 이동 가능한 모든 위치들에 대해서 각각 매길 수 있는
전술적 수치들을 점수화하여 가장 높은 점수를 얻은 위치를 선택함.
즉 각각의 이동관련 AI들은 접근가능한 전술 수치들의 가중치를 결정하는 함수가 된다고 볼 수 있음.
함수가 접근할 수 있는 전술 수치는 ActionDatabase라고 불리는 adb객체를 통해서 전달되는데
해당위치에서의 원하는 전술 수치는 adb.Attackable 과 같이 접근이 가능하다.
--]]
-- 1. 완전회피이동
function AI_CompleteEvasionMove(self, adb)
	--1. 엄폐가능 위치여야 함.
	if not adb.CoverScore == 0 then
		return -200;
	end
	--2. 위험도 수치가 낮을수록 좋음.
	return 1000 - adb.Dangerous;
end
-- 1.1 완전회피이동 : 퇴각
function CompleteEvasionMove_Retreat(self, adb)
	local cemScore = AI_CompleteEvasionMove(self, adb);
	--LogAndPrint('CompleteEvasionMove_Retreat', cemScore, adb.TotalEnemyDistance / 100);
	-- 적들과의 거리도합을 추가 점수로 체크한다.
	return cemScore + adb.TotalEnemyDistance;
end

-- 1.1.1 완전회피이동 : 퇴각 + 디버프 지형 효과 회피
function CompleteEvasionMove_Retreat_Debuff(self, adb)
	local cemScore = AI_CompleteEvasionMove(self, adb);
	--LogAndPrint('CompleteEvasionMove_Retreat_Debuff', cemScore, adb.TotalEnemyDistance / 100, adb.TotalBadFieldDistance / 100);
	-- 적들과의 거리도합을 추가 점수로 체크한다. (디버프 지형효과와의 거리도합도 체크)
	return cemScore + adb.TotalEnemyDistance + adb.TotalBadFieldDistance;
end

-- 1.2 완전회피이동 : 경계
function CompleteEvasionMove_Alert(self, adb)
	local cemScore = AI_CompleteEvasionMove(self, adb);
	
	-- 가장 가까운 적과의 거리가 짧은 위치일 수록 높은 점수를 부여한다.
	return cemScore - adb.MinEnemyDistance;
end

-- 1.3 완전회피이동 : 귀환
-- 정보 부족 .. 비워둠 귀환위치가 어디여?

-- 1.4 완전회피이동 : 지원
function CompleteEvasionMove_Support(self, adb)
	local cemScore = AI_CompleteEvasionMove(self, adb);
	
	-- 아군 밀집도가 높을수로 높은 점수를 부여한다.
	return cemScore + adb.AllyDensity(2);
end
-- 1.5 완전회피이동 : 대상지원 (adb에 지원대상정보가 기입되어 있어야함)
function CompleteEvasionMove_SupportTarget(self, adb)
	local cemScore = AI_CompleteEvasionMove(self, adb);
	
	-- 지원 대상과의 거리가 가까울수록 높은 점수를 부여한다.
	return cemScore + 20 / adb.TargetDistance;
end

-- 2. 공격회피이동
function AttackEvasionMove(self, adb)
	-- 엄폐가능이어야 함.
	if not adb.Coverable or not adb.Attackable then
		-- 공격 회피이동은 실패를 처리해야 함.. 다른 변수에 의해서 점수가 0 보다 높아지는걸 방지하기 위해서 쌔게 때리자
		return -10000;
	end
	
	return 10;	-- 기본점수
end
-- 2.1 공격회피이동 : 방어적
function AttackEvasionMove_Defensive(self, adb)
	local aemScore = AttackEvasionMove(self, adb);
	
	-- 위험도 점수를 추가로 준다.
	return aemScore + 10 / adb.Dangerous;
end

-- 2.2 공격회피이동 : 안정적
function AttackEvasionMove_Stable(self, adb)
	local aemScore = AttackEvasionMove(self, adb);
	
	-- 정확도에 따른 추가 점수를 부여한다.
	return aemScore + adb.Accuracy * 10;
end
-- 3. 공격이동
-- 공격 가능 지점인지 판단.
function AttackMove(self, adb)
	if not adb.Attackable then
		return -10000;
	end	
	return 10;	-- 공격이동 기본점수
end
----------------------------------------------------------------
-- 3 - 1. 무조건 공격 이동.
----------------------------------------------------------------
--[[function AttackMove_SuperAggressive(self, adb, args)
	local dangerousScore = adb.Dangerous;
	local allyDensityScore = adb.AllyDensity(2);
	local moveDistanceScore = adb.MoveDistance;
	local option = {};
	option.CoverScoreMultiplier = 1;
	option.AllyDensityWeight = 1;
	option.MoveDistanceWeight = 1;
	
	local hateRatio = args.HateRatio or 1;
	local scoreRatio = 0;
	
	local score = 0;
	if adb.TargetAttackable then
		score = score + 2000 + adb.Accuracy;
	elseif adb.Attackable then
		-- 공격 가능하면 잘 맞출 수 있는 곳을 찾는다.
		option.CoverScoreMultiplier = 0.1;
		score = score + adb.MaxActionInfoScore(function(actionInfo)
			scoreRatio = math.max(scoreRatio, GetTargetScoreRatio(self, actionInfo.Object));
			return (actionInfo.Accuracy * 100) + GetHate(self, actionInfo.Object) * hateRatio + GetTeamHate(args, GetTeam(actionInfo.Object));
		end) + 1000;
	else
		return -9680;
	end
	
	-- 적이 많은 곳을 좋아한다.
	score = score + dangerousScore;
	
	local finalRatio = 1;
	if scoreRatio > 0 then
		finalRatio = scoreRatio;
	end
	
	return (MoveAIGeneral(self, adb, args, option) + score) * finalRatio;
end]]
--[[function AttackMove_SuperAggressive_Area(self, adb, args)
	local hateRatio = args.HateRatio or 1;

	local dangerousScore = adb.Dangerous;
	local allyDensityScore = adb.AllyDensity(2);
	local moveDistanceScore = adb.MoveDistance;
	local option = {};
	option.CoverScoreMultiplier = 1;
	option.AllyDensityWeight = 1;
	option.MoveDistanceWeight = 1;
	
	local scoreRatio = 0;
	
	local score = 0;
	if adb.TargetAttackable then
		score = score + 2000 + adb.Accuracy;
	elseif adb.Attackable then
		-- 공격 가능하면 잘 맞출 수 있는 곳을 찾는다.
		option.CoverScoreMultiplier = 0.1;
		score = score + adb.MaxActionInfoScore(function(actionInfo)
			scoreRatio = math.max(scoreRatio, GetTargetScoreRatio(self, actionInfo.Object));
			return (actionInfo.AccuracySum * 100) + GetHate(self, actionInfo.Object) * hateRatio + GetTeamHate(args, GetTeam(actionInfo.Object));
		end) + 1000;
	else
		return -9681;
	end
	
	-- 적이 많은 곳을 좋아한다.
	score = score + dangerousScore;
	
	local finalRatio = 1;
	if scoreRatio > 0 then
		finalRatio = scoreRatio;
	end
	
	return (MoveAIGeneral(self, adb, args, option) + score) * finalRatio;
end]]
function AttackMove_SuperAggressive_Melee(self, adb, args)
	local totalScore = AttackMove_SuperAggressive(self, adb, args);
	local distanceScore = adb.MinEnemyDistance;
	-- 일단 적하고 붙으려고 하는 성향이다.
	totalScore = totalScore - distanceScore * 2;
	return totalScore;
end
function AttackMove_SuperAggressive_Force(self, adb)
	local totalScore = AttackMove_SuperAggressive(self, adb, args);
	local distanceScore = adb.MinEnemyDistance;
	-- 일단 적하고 붙지 않으려고 한다. 하지만 5칸 이상은 동일하다. 너무 멀리 가지 않게 하기 위해.
	totalScore = totalScore + math.max(5, distanceScore) * 2;
	return totalScore;
end
----------------------------------------------------------------
-- 3 - 1. 일반 공격 이동.
----------------------------------------------------------------
function AttackMove_Aggressive(self, adb, args)
	local rallyPoints = args.RallyPoints;
	local totalScore = 3000;	
	
	-- bad field filter
	if adb.BadField then
		return -99;
	end
	
	local accuracyScore = adb.Accuracy;
	local dangerousScore = adb.Dangerous;
	local allyDensityScore = adb.AllyDensity(2);
	local moveDistanceScore = adb.MoveDistance;
	local coverScore = 0;
	if adb.CoverScore > 0 then
		coverScore = 100 + adb.CoverScore;
	end
	
	-- 1. 자가 회복 이동
	if self.HP / self.MaxHP < 0.25 and adb.RepairAmount > 0 then
		-- 안전한 곳중에서 적이 적고 아군이 많으며 현재 위치로 부터 이동거리가 짧은 곳을 선호.
		totalScore = coverScore - dangerousScore - moveDistanceScore + allyDensityScore;
		return totalScore; 
	end

	-- 2. 공격 가능
	if adb.Attackable then
		-- 공격 가능하면 잘 맞출 수 있는 곳을 찾는다.
		-- 다만 난이도를 위해 70% 이상 명중률은 동일 처리한다.
		totalScore = totalScore + accuracyScore;
	end
	-- 엄폐 지역을 점수를 준다.
	totalScore = totalScore + coverScore;
	-- 아군이 붙는 곳을 싫어한다 ( 연출용 )
	totalScore = totalScore - allyDensityScore;
	-- 최대한 현재 위치에서 적게 움직이려고 한다.( 연출용 )
	totalScore = totalScore - moveDistanceScore * 0.5;	
	-- 랠리 포인트 가산
	for i, rallyPoint in ipairs(rallyPoints) do
		if not IsInvalidPosition(rallyPoint.Position) then
			local rallyDist = GetDistance3D(adb.Position, rallyPoint.Position);
			if rallyDist > rallyPoint.Range then
				totalScore = totalScore - (rallyDist - rallyPoint.Reference) * rallyPoint.Power;
			end
		end
	end
	-- 안 좋은 지형 피하기
	if adb.ClearPath then
		totalScore = totalScore + 500;	-- 이야 크다 I
	end
	
	return totalScore;	
end
function AttackMove_Aggressive_Melee(self, adb, args)
	local rallyPoints = args.RallyPoints;
	local totalScore = 3000;	
	
	-- bad field filter
	if adb.BadField then
		return -99;
	end
	
	local accuracyScore = adb.Accuracy;
	local dangerousScore = adb.Dangerous;
	local allyDensityScore = adb.AllyDensity(2);
	local moveDistanceScore = adb.MoveDistance;
	local distanceScore = adb.MinEnemyDistance;
	local coverScore = 0;
	if adb.CoverScore > 0 then
		coverScore = adb.CoverScore;
	end
	
	-- 1. 자가 회복 이동
	if self.HP / self.MaxHP < 0.25 and adb.RepairAmount > 0 then
		-- 안전한 곳중에서 적이 적고 아군이 많으며 현재 위치로 부터 이동거리가 짧은 곳을 선호.
		totalScore = coverScore - dangerousScore - moveDistanceScore + allyDensityScore;
		return totalScore; 
	end
			
	-- 2. 공격 이동
	if AttackMove(self, adb) > 0 then
		-- 공격 가능하면 잘 맞출 수 있는 곳을 찾는다.
		-- 다만 난이도를 위해 70% 이상 명중률은 동일 처리한다.
		totalScore = totalScore + 200 + accuracyScore;
	end
	-- 엄폐 지역을 점수를 준다.
	totalScore = totalScore + coverScore;
	-- 아군이 붙는 곳을 싫어한다 ( 연출용 )
	totalScore = totalScore - allyDensityScore;
	-- 최대한 현재 위치에서 적게 움직이려고 한다.( 연출용 )
	totalScore = totalScore - moveDistanceScore * 0.5;	
	-- 적에게 근접하려고 한다. ( 연출용 )
	totalScore = totalScore - distanceScore * 2;
	-- 랠리 포인트 가산 : 밀리니까 좀더 목표지점까지 강력하게 이동한다.
	for i, rallyPoint in ipairs(rallyPoints) do
		if not IsInvalidPosition(rallyPoint.Position) then
			local rallyDist = GetDistance3D(adb.Position, rallyPoint.Position);
			if rallyDist > rallyPoint.Range then
				totalScore = totalScore - (rallyDist - rallyPoint.Reference) * rallyPoint.Power;
			end
		end
	end
	-- 안 좋은 지형 피하기
	if adb.ClearPath then
		totalScore = totalScore + 500;	-- 이야 크다 I
	end
	return totalScore;	
end
--[[function AttackMove_Aggressive_Force(self, adb, args)
	if self.Coverable and not adb.Coverable then
		return -9999;
	end

	-- 2. 공격 이동
	if args.AllowObstacle then
		if not adb.Attackable then
			return -999;
		end
	else
		if not adb.PureAttackable then
			return -999;
		end
	end
	
	if args.NoSingleIndirectAttack or args.NoSingleAttack then
		local singlePass = false;
		local indirectPass = false;
		adb.ForeachAttackInfo(function (attackInfo)
			if not singlePass and attackInfo.HitCount >= 2 then
				singlePass = true;
			end
			if not indirectPass and not attackInfo.IsIndirect then
				indirectPass = true;
			end
			return singlePass and indirectPass;
		end);
		if args.NoSingleIndirectAttack and not (singlePass or indirectPass) then
			return -876;
		elseif args.NoSingleAttack and not singlePass then
			return -875;
		end
	end
	
	local hateRatio = args.HateRatio or 1;
	local scoreRatio = 0;

	local score = 0;
	if adb.TargetAttackable then
		score = score + 1000 + adb.Accuracy;
	else
		score = score + adb.MaxActionInfoScore(function(actionInfo)
			scoreRatio = math.max(scoreRatio, GetTargetScoreRatio(self, actionInfo.Object));
			return (actionInfo.Accuracy * 100) + GetHate(self, actionInfo.Object) * hateRatio + GetTeamHate(args, GetTeam(actionInfo.Object));
		end);
		local minAccuracy = args.MinAccuracy or 0;
		if score < minAccuracy then
			return -500;
		end
	end
	
	-- 일단 적하고 붙지 않으려고 한다.
	local distanceScore = adb.MinEnemyDistance;
	if not args.RunAway then
		-- 하지만 5칸 이상은 동일하다. 너무 멀리 가지 않게 하기 위해.
		distanceScore = math.min(5, distanceScore);
	end
	score = score + distanceScore * 20;
	
	-- 근처의 적 수가 많으면 싫어함
	local dangerousScore = adb.Dangerous;
	score = score - dangerousScore * 20;
			
	local option = {};
	option.AllyDensityWeight = 10;
	if args.RunAway then
		option.MoveDistanceWeight = 0;
	else
		option.MoveDistanceWeight = 0.75;
	end
	option.CoverScoreMultiplier = 1;
	option.NoMoveBonus = args.NoMoveBonus;
	option.HeightBonus = args.HeightBonus;
	
	local finalRatio = 1;
	if scoreRatio > 0 then
		finalRatio = scoreRatio;
	end
		
	return (MoveAIGeneral(self, adb, args, option) + score) * finalRatio;	
end]]
----------------------------------------------------------------
-- 3 - 2. 방어적 공격 이동.
----------------------------------------------------------------
--[[function AttackMove_Defensive(self, adb, args)
	local rallyPoints = {};
	
	local score = 0;
	local option = {};
	option.Melee = self.Job.AttackType == 'Melee';
	
	if option.Melee and adb.Coverable then
		score = score + 100;
	elseif not option.Melee and not adb.Coverable then
		return -9999;
	end
	
	if not adb.Actable then
		return -4823;
	end
	
	-- 1. 자가 회복 이동
	if self.HP / self.MaxHP < 0.5 and adb.RepairAmount > 0 then
		-- 안전한 곳중에서 적이 적고 아군이 많으며 현재 위치로 부터 이동거리가 짧은 곳을 선호.
		local dangerousScore = adb.Dangerous;
		score = score - dangerousScore;
		option.MoveDistanceWeight = 1;
	else
		option.MoveDistanceWeight = 0.25;
		-- 2. 공격 이동
		if AttackMove(self, adb, args) > 0 then
			-- 공격 가능하면 잘 맞출 수 있는 곳을 찾는다.
			-- 다만 난이도를 위해 70% 이상 명중률은 동일 처리한다.
			local accuracyScore = adb.Accuracy;
			score = score + accuracyScore;
		end
	end
	
	option.AllyDensityWeight = 1;
	
	local generalMoveScore = MoveAIGeneral(self, adb, args, option);
	return generalMoveScore + score;
end]]

-- 3.1 공격이동 : 안정적
function AttackMove_Stable(self, adb)
	local amScore = AttackMove(self, adb);	
	-- 정확도에 의한 추가 점수를 부여한다.
	return amScore + adb.Accuracy * 10;
end
-- 3.3 공격이동 : 돌격
function AttackMove_Assert(self, adb)
	local amScore = AttackMove(self, adb);
	if amScore < 0 then
		return amScore;
	end	
	-- 가장 가까운 적과의 거리가 짧을수록 높은 점수를 부여한다.
	return amScore + 10 / adb.MinEnemyDistance;
end

-- 3.4 공격이동 : 견제
function AttackMove_Containment(self, adb) -- 견제사격했을때 나오는 단어긴 한데.. 별로 쉬운단어는 아닌듯.
	local amScore = AttackMove(self, adb);
	
	-- 가장 가까운 적과의 거리가 멀 수록 높은 점수를 부여한다.
	-- 엄폐도 안하면서 가장 먼데로만 간다 이거지?... 흠..
	return amScore + adb.MinEnemyDistance / 10;
end
-- 4. 도망
function RunAway(self, adb)
	return adb.TotalEnemyDistance;
end
-- 5. 순찰 깨어날 때 이동
function PatrolAwakeMoveAI(self, adb, args)
	local rallyPoint = args.RallyPoint;
	local rallyRange = args.RallyRange or 4;
	local rallyPower = args.RallyPower or 10;
	local actorPos = SafeIndex(args, 'ActorPos');
	
	local totalScore = 3000;
	
	-- 1. 엄폐테스트. 엄폐가 안되는데는 일단 재끼자
	if not adb.Coverable then
		return -9999;
	end
	
	if adb.CoverScore > 0 then
		-- 엄폐가 잘 되는 지역을 선호한다.
		totalScore = totalScore + 100 + adb.CoverScore;
	end

	-- 2. 공격 가능 선호도.
	if adb.Attackable then
		-- 공격 가능하면 거리와 명중률이 중요.
		totalScore = totalScore + adb.Accuracy;
	end
	-- 아군과 밀집하지 않는다. (연출상)
	totalScore = totalScore - adb.AllyDensity(2) * 5;
	
	-- 4. 랠리 포인트 가산
	-- 제일 주도적인 것인가?
	if not IsInvalidPosition(rallyPoint) then
		local rallyDist = GetDistance3D(adb.Position, rallyPoint);
		if rallyDist > rallyRange then
			totalScore = totalScore - rallyDist * rallyPower;
		end
	end
	totalScore = totalScore - GetDistance3D(adb.Position, actorPos);
	return totalScore;
end
function PatrolAwakeMoveAI_Tima(self, adb, args)
	local rallyPoint = args.RallyPoint;
	local rallyRange = args.RallyRange or 4;
	local rallyPower = args.RallyPower or 10;
	local actorPos = SafeIndex(args, 'ActorPos');
	
	local totalScore = 3000;

	-- 아군과 밀집하지 않는다. (연출상)
	totalScore = totalScore - adb.AllyDensity(2) * 5;
	
	-- 부시 선호
	if adb.OnFieldEffect('Bush') then
		totalScore = totalScore + 500;
	end
	totalScore = totalScore - adb.RelativeMinEnemyDistance * 20;
	
	-- 4. 랠리 포인트 가산
	-- 제일 주도적인 것인가?
	if not IsInvalidPosition(rallyPoint) then
		local rallyDist = GetDistance3D(adb.Position, rallyPoint);
		if rallyDist > rallyRange then
			totalScore = totalScore - rallyDist * rallyPower;
		end
	end
	totalScore = totalScore - GetDistance3D(adb.Position, actorPos);
	return totalScore;
end

-- 5. 공격적 이동.
-- 공격 가능 지점을 최우선한다.

-- 7. 비겁한 암살자 이동.
function DeadFirstMoveAI(self, adb, args)
	local rallyPoints = args.RallyPoints;
	
	local totalScore = 10000;
	-- 1. 엄폐 지점 선호도.
	if adb.Coverable then
		totalScore = totalScore + 1000;
	end
	-- 2. 공격 가능 선호도.
	if adb.Attackable then
		totalScore = totalScore + 500;
	end
	-- 3. 명중률이 높은 곳을 좋아한다.
	totalScore = totalScore + adb.Accuracy * 100;
	-- 4. 아군이 밀집한 곳을 좋아한다.
	totalScore = totalScore + adb.AllyDensity(2);

	-- 5. 랠리 포인트 가산
	for i, rallyPoint in ipairs(rallyPoints) do
		if not IsInvalidPosition(rallyPoint.Position) then
			local rallyDist = GetDistance3D(adb.Position, rallyPoint.Position);
			if rallyDist > rallyPoint.Range then
				totalScore = totalScore - (rallyDist - rallyPoint.Reference) * rallyPoint.Power;
			end
		end
	end
	return totalScore;
end
-- 랠리 우선 이동. 
function RallyMove_Attack(self, adb, args)
	local rallyPoint = args.RallyPoint;
	local rallyRange = 4
	local rallyPower = 100;
	local rallyReference = 0;
	
	-- 5. 랠리 포인트 가산
	-- 제일 주도적인 것인가?
	local score = 10000;
	if not IsInvalidPosition(rallyPoint) then
		local rallyDist = GetDistance3D(adb.Position, rallyPoint);
		if rallyDist > rallyRange then
			score = score - (rallyDist - rallyReference) * rallyPower;
		end
	end
	-- 엄폐와 위험 요소 판단.		
	if adb.CoverScore > 0 then
		score = score + 300;		
		score = score - adb.Dangerous;
	end
	-- 공격 가능하면 명중률 만큼 보너스를 준다. 1미터 칸 차이 추가.
	if adb.Attackable then
		score = score + 100 + adb.Accuracy;
	end
	return score;
end

-- 0. 랜덤 공격
function DirectRandomAttackAI(self, adb)
	if adb.IsIndirect then
		return -22;
	end
	return math.random(1, 20);
end
-- 1. 가장 가까운 녀석 공격.
function NearFirstAttackAI(self, adb)
	return 1000 - adb.Distance * 10 + math.random(1, 9);
end
-- 2. 명중률 가장 높은 녀석 공격.
function EffectiveFirstAttackAI(self, adb)
	-- AI의 실수를 유도하기 위한 장치. 80% 이상은 동일함.
	local score = math.max(80, adb.Accuracy) + math.random(1,9)/10;
	return score;
end
-- 3. 피해량 제일 많이 주는 녀석
function DamageFirstAttackAI(self, adb, args)
	if adb.IsTarget then
		return 9999;
	end		
	local score = adb.Damage / self.MaxHP * 100 + adb.Hate * (args.HateRatio or 1) + GetTeamHate(args, GetTeam(adb.Object));	--- 체력 대비 데미지 비율
	score = score * GetTargetScoreRatio(self, adb.Object);
	return score;
end
-- 5. 절대 체력이 제일 낮은 녀석.
function MinRemainHPFirstAI(self, adb)
	local score = adb.RemainHP;
	return score;
end
function CommonAttackAI(self, adb)
	local score = 100; -- 기본점수
	-- 1. 헤이트 정도 계산.
	-- 나에게 공격한 놈을 일단 더 유력한 공격 대상으로 본다.
	if adb.Hate > 0 then
		score = score + adb.Hate;
	end
	score = score + EffectiveFirstAttackAI(self, adb);
	return score;
end
-------------------------------------------------------------------------------------------------
-- 서포트
-------------------------------------------------------------------------------------------------
function CommonSupportAI(self, adb, args)
	local ratio = args.RecoveryRatio;
	if adb.Ability.Type == 'Heal' then
		if self.HP / self.MaxHP < ratio and adb.RepairAmount > 0 then	-- 체력이 ratio% 미만이고 회복이 되면 무조건 회복
			return 10000;
		else
			return -1;
		end
	else
		return adb.Efficiency;
	end
end
function CommonHealAI(self, adb, args)
	if args.SelfHeal then
		return adb.SelfRepairAmount;
	else
		return adb.RepairAmount;
	end
end
function MakeNormalAbilityUseAI(ability)
	return function(self, adb, args)
		if adb.Ability == ability then
			return math.random(1, 10);
		else
			return -1;
		end
	end
end
----------
function TestBattleState(self)
	for i, b in ipairs(GetBuffList(self)) do
		if b.name == 'Patrol' or b.name == 'Stand' or b.name == 'Detecting' then
			return false;
		end
	end
	return true;
end
function GeneralAI(self, abilities, moveStrategy, actionStrategies, aiConfig, args)
	local t = os.clock();
	-- 아직 대기상태에 대한 정의가 없음. 따라서 무조건 전투 활성화 상태임
	
	-- 우선 이동이 가능한지 아닌지를 판별한다. 이동이 가능하면 일단 이동 AI를 돌리고 시작
	local moveAbility = nil;
	for i, ability in ipairs(abilities) do	
		if ability.name == 'Move' then
			moveAbility = ability;
			break;
		end
	end
	if moveAbility then
		local prevPos = GetPosition(self);
		-- 어떤 이동 전략을 선택할지 결정
		-- 우선은 무조건 3.3 공격이동 : 돌격으로 해보겠음.
		
		local pos, score, debugInfo = FindAIMovePosition(self, abilities, moveStrategy, aiConfig, args);
		if score ~= nil and score > 0 and (args.DebugInfoEnabled or not IsSamePosition(pos, prevPos)) then	-- 결정된 최종 스코어가 0보다는 커야 제대로 결정된 걸로 침.
			LogAndPrint('Move AI End, time consumed', os.clock() - t, moveAbility.name, self.name);
			return moveAbility, pos, debugInfo, score;
		elseif score ~= nil and score <= 0 then
			LogAndPrint('No Move', score, pos.x, pos.y, pos.z);
			return nil, nil, nil;
		end
	end
	
	if aiConfig.NoMoveIntercepter then
		local interceptResult, pos, dbgInfo = aiConfig.NoMoveIntercepter();
		if interceptResult then
			return interceptResult, pos, dbgInfo;
		end
	end
	
	-- 여기로 왔다는건 이동이 불가능 하거나 안하는 상태임 (이동을 이미 했든 이동 AI가 실패했든 같은자리로 가려고 했든)
	-- 행동 전략은 한가지를 선택하는 것이 아니라 몇가지의 전략 우선순위를 넣는 식으로 이뤄짐.
	-- 전략 우선순위는 위의 ActionAnalysisStrategy Table의 키값에 해당함.
	-- 일단은 임의로 사망, 피해량, 효율 순으로 우선순위를 정해보겠음.
	-- 각 전략에 대한 실제 처리는 연결된 함수를 찾아가서 보면 될듯
	local usingAbility, usingPos, debugInfo, score = FindAIMainAction(self, abilities, actionStrategies, aiConfig, args);
	LogAndPrint('Action AI End, time consumed', os.clock() - t, 'score', score, self.name);
	return usingAbility, usingPos, debugInfo, score;
end

----------------------------------------------------------------------------------
-- AI.xml 에 등록할 AI 등록
----------------------------------------------------------------------------------
-- 2. 무조건 공격적 AI
-- 무조건 공격. 근접용
function AI_SuperAggressive(self, abilities, args)
	args.RecoveryRatio = 0;
	return GeneralAI(self, abilities
		, 'AttackMove_SuperAggressive'
		, {{Strategy = NearFirstAttackAI, Target = 'Attack'}, 
			{Strategy = CommonSupportAI, Target = 'Assist'}}
		, {}, args);
end
-- 무조건 공격. 근접용
function AI_SuperAggressive_Melee(self, abilities, args)
	args.RecoveryRatio = 0;
	return GeneralAI(self, abilities
		, AttackMove_SuperAggressive_Melee
		, {{Strategy = NearFirstAttackAI, Target = 'Attack'},
			{Strategy = CommonSupportAI, Target = 'Assist'}}
		, {}, args);
end
-- 무조건 공격. 원거리용
function AI_SuperAggressive_Force(self, abilities, args)
	args.RecoveryRatio = 0;
	return GeneralAI(self, abilities
		, AttackMove_SuperAggressive_Force
		, {{Strategy = NearFirstAttackAI, Target = 'Attack'},
			{Strategy = CommonSupportAI, Target = 'Assist'}}
		, {}, args);
end
-- 2. 공격적 AI
-- 25% 체력 이하 일때 서포트 행동.
-- 랠리 포인트, 활동 영역 지정 가능, 적정 거리
function AI_Aggressive(self, abilities, args)
	local rallyPoint = GetPositionFromPositionIndicator(GetMissionID(self), args.RallyPoint);
	args.RallyPoint = rallyPoint;
	if rallyPoint then
		args.RallyReference = GetDistance3D(GetPosition(self), rallyPoint);
	end
	local rallyPoint2 = GetPositionFromPositionIndicator(GetMissionID(self), args.RallyPoint2);
	args.RallyPoint2 = rallyPoint2;
	if rallyPoint2 then
		args.RallyReference2 = GetDistance3D(GetPosition(self), rallyPoint2);
	end
	args.RecoveryRatio = 0.25;
	return GeneralAI(self, abilities
		, AttackMove_Aggressive
		, {{Strategy = NearFirstAttackAI, Target = 'Attack'},
			{Strategy = CommonSupportAI, Target = 'Assist'}}
		, {}, args);
end
function AI_Aggressive_Melee(self, abilities, args)
	local rallyPoint = GetPositionFromPositionIndicator(GetMissionID(self), args.RallyPoint);
	args.RallyPoint = rallyPoint;
	if rallyPoint then
		args.RallyReference = GetDistance3D(GetPosition(self), rallyPoint);
	end
	local rallyPoint2 = GetPositionFromPositionIndicator(GetMissionID(self), args.RallyPoint2);
	args.RallyPoint2 = rallyPoint2;
	if rallyPoint2 then
		args.RallyReference2 = GetDistance3D(GetPosition(self), rallyPoint2);
	end
	args.RecoveryRatio = 0.25;
	return GeneralAI(self, abilities
		, AttackMove_Aggressive_Melee
		, {{Strategy = NearFirstAttackAI, Target = 'Attack'},
			{Strategy = CommonSupportAI, Target = 'Assist'}}
		, {}, args);
end
function AI_Aggressive_Force(self, abilities, args)
	local rallyPoint = GetPositionFromPositionIndicator(GetMissionID(self), args.RallyPoint);
	args.RallyPoint = rallyPoint;
	if rallyPoint then
		args.RallyReference = GetDistance3D(GetPosition(self), rallyPoint);
	end
	local rallyPoint2 = GetPositionFromPositionIndicator(GetMissionID(self), args.RallyPoint2);
	args.RallyPoint2 = rallyPoint2;
	if rallyPoint2 then
		args.RallyReference2 = GetDistance3D(GetPosition(self), rallyPoint2);
	end
	args.RecoveryRatio = 0.25;
	return GeneralAI(self, abilities
		, 'AttackMove_Aggressive_Force'
		, {{Strategy = NearFirstAttackAI, Target = 'Attack'},
			{Strategy = CommonSupportAI, Target = 'Assist'}}
		, {}, args);
end
-- 무조건 랠리 이동 우선 후 공격 선택.
function AI_RallyAttack(self, abilities, args)
	local rallyPoint = GetPositionFromPositionIndicator(GetMissionID(self), SafeIndex(args, 'RallyPoint'));
	args.RallyPoint = rallyPoint;
	args.RecoveryRatio = 0.25;
	return GeneralAI(self, abilities
		, RallyMove_Attack
		, {{Strategy = NearFirstAttackAI, Target = 'Attack'},
			{Strategy = CommonSupportAI, Target = 'Assist'}}
		, {}, args);
end
-- 1. 방어적 AI
function AI_Defensive(self, abilities, args)
	local rallyPoint = GetPositionFromPositionIndicator(GetMissionID(self), args.RallyPoint);
	args.RallyPoint = rallyPoint;
	if rallyPoint then
		args.RallyReference = GetDistance3D(GetPosition(self), rallyPoint);
	end
	local rallyPoint2 = GetPositionFromPositionIndicator(GetMissionID(self), args.RallyPoint2);
	args.RallyPoint2 = rallyPoint2;
	if rallyPoint2 then
		args.RallyReference2 = GetDistance3D(GetPosition(self), rallyPoint2);
	end
	args.RecoveryRatio = 0.5;
	return GeneralAI(self, abilities
		, 'AttackMove_Defensive'
		, {{Strategy = NearFirstAttackAI, Target = 'Attack'},
			{Strategy = CommonSupportAI, Target = 'Assist'}}
		, {}, args);
end

-- 3. 비겁한 암살자 AI
-- 나는 안전하고 적을 죽일수 있는 것을 최고 목표로 삼는다.
function AI_DeadFirst(self, abilities, args)
	local rallyPoint = GetPositionFromPositionIndicator(GetMissionID(self), args.RallyPoint);
	args.RallyPoint = rallyPoint;
	if rallyPoint then
		args.RallyReference = GetDistance3D(GetPosition(self), rallyPoint);
	end
	local rallyPoint2 = GetPositionFromPositionIndicator(GetMissionID(self), args.RallyPoint2);
	args.RallyPoint2 = rallyPoint2;
	if rallyPoint2 then
		args.RallyReference2 = GetDistance3D(GetPosition(self), rallyPoint2);
	end
	return GeneralAI(self, abilities, DeadFirstMoveAI, {{Strategy = DamageFirstAttackAI, Target = 'Attack'}}, {}, args);
end
function TEST_AI(self, abilities, args)
	return GeneralAI(self, abilities, AttackMove_Assert, {{Strategy = DamageFirstAttackAI, Target = 'Attack'}}, {}, args);
end
function DoNothingAI(self, abilities, args)
	return nil, nil, nil;
end
function CitizenAI(self, abilities, args)
	return nil, nil, nil;
end

function SupportRequestedAI(self, abilities, args)
	return GeneralAI(self, abilities, CompleteEvasionMove_SupportTarget, {{Strategy = NearFirstAttackAI, Target = 'Attack'}}, {Target = GetInstantProperty(self, 'SupportTarget')}, args);
end
function FearAI(self, abilities, args)
	-- 공포는 일단 도망. 후 은폐.
	return GeneralAI(self, abilities
		, CompleteEvasionMove_Retreat, {}, {}, args);
end
function RunAwayAI(self, abilities, args)
	return GeneralAI(self, abilities
		, function(self, adb, args)
			return 100 + adb.MinEnemyDistance * 20 + adb.TotalEnemyDistance - adb.MinObjectDistanceByFilter(function(o) return o ~= self and IsTeamOrAlly(self, o); end) * 20 + math.random(20);
		end, {}, {}, args);
end

function RebuildPatrolPath(self, patrolRoute, patrolMethod)
	if #patrolRoute == 0  then
		return nil;
	end
	if patrolMethod == 'Random' then		-- 랜덤 위치로
		return table.shuffle(patrolRoute);
	elseif patrolMethod == 'Oscillate' then		-- 왕복
		local routeCount = #patrolRoute;
		local retTable = table.deepcopy(patrolRoute);
		for i = routeCount - 1, 1, -1 do
			table.insert(retTable, patrolRoute[i]);
		end
		return retTable;
	else	-- Rotate or else
		return table.deepcopy(patrolRoute);
	end
end
function PatrolAI(self, abilities, args)
	-- 우선 이동이 가능한지 아닌지를 판별한다. 이동이 불가능하면 아무행동 안함
	local moveAbility = nil;
	local summonBeastAbility = nil;
	for i, ability in ipairs(abilities) do
		if ability.name == 'Move' then
			moveAbility = ability;
		elseif ability.name == 'SummonBeast' then
			return AbilityAI_SummonBeast(ability, self, {ability}, args, {});
		end
	end
	
	if not moveAbility then
		return nil, nil, nil;
	end
	
	local patrolRoute = SafeIndex(args, 'PatrolRoute') or GetInstantProperty(self, 'PatrolRoute');
	local patrolMethod = SafeIndex(args, 'PatrolMethod') or GetInstantProperty(self, 'PatrolMethod');
	local patrolRepeat = SafeIndex(args, 'PatrolRepeat') or GetInstantProperty(self, 'PatrolRepeat');
	local currentRepeatCount = GetInstantProperty(self, 'MyPatrolRepeat') or 0;
	
	local routes = SafeIndex(patrolRoute, 1, 'Route');
	if routes == nil or #routes == 0 then	-- 경로 미설정
		-- LogAndPrint('No Patrol Route Specified');
		return nil, nil, nil;
	end

	-- 경로 구축
	local path = GetInstantProperty(self, 'BuiltPatrolRoute') or {};
	local curPatrolIndex = GetInstantProperty(self, 'NextPatrolIndex') or -1;
	if path[curPatrolIndex] == nil then
		path = RebuildPatrolPath(self, table.map(routes, function (route) return route.Position[1]; end), patrolMethod);
		SetInstantProperty(self, 'BuiltPatrolRoute', path);
		if curPatrolIndex ~= -1 then
			currentRepeatCount = currentRepeatCount + 1;
			SetInstantProperty(self, 'MyPatrolRepeat', currentRepeatCount);
		end
		curPatrolIndex = 1;
	end
	
	if patrolRepeat > 0 and currentRepeatCount >= patrolRepeat then	-- 반복회수 초과
		return nil, nil, nil;
	end
	local patrolSensitiveness = 3.1;			-- 별 의미 없음
	local myPos = GetPosition(self);
	local movePos = path[curPatrolIndex];
	local nextPos = GetMovePosition(self, movePos);
	if GetDistance3D(nextPos, movePos) <= patrolSensitiveness then
		curPatrolIndex = curPatrolIndex + 1;
	end
	SetInstantProperty(self, 'NextPatrolIndex', curPatrolIndex);
	if IsSamePosition(nextPos, GetPosition(self)) then
		return nil, nil, nil;
	end
	local range = CalculateRange(self, moveAbility.TargetRange, GetPosition(self));
	local nearestPos = table.foldr(range, function(a, b)
		if b == nil then
			return a;
		end
		if GetDistance3D(a, nextPos) < GetDistance3D(b, nextPos) then
			return a;
		else
			return b;
		end
	end);
	return moveAbility, nearestPos, nil;
end

function TransportDroneAI(self, abilities, args)
	local NoMoveReturn = function ()
		-- 전투상태라면 얼음방패를 써야하는데 (...)
		return nil, nil, nil;
	end;
	
	if TestBattleState(self) then
		return NoMoveReturn();
	end
	
	-- 그외는 그냥 순찰
	local patrolArgs = {PatrolRoute = args.PatrolRoute, PatrolMethod = 'Rotate', PatrolRepeat = 1};
	local moveAbility, pos, debugInfo = PatrolAI(self, abilities, patrolArgs);
	if not moveAbility then
		return NoMoveReturn();
	end
	
	local sightRange = self.SightRange;
	local allUnit = GetAllUnitInSight(self);
	local allEnemies = table.filter(allUnit, function(unit)
		return IsEnemy(self, unit);
	end);
	for i, enemy in ipairs(allEnemies) do
		if GetDistance3D(pos, GetPosition(enemy)) < sightRange then
			-- 이동할 위치의 근처에 적이 있으면 안움직임
			return NoMoveReturn();
		end
	end
	
	return moveAbility, pos, debugInfo;
end

function NoMoveAttackAI(self, abilities, args)
	return FindAIMainAction(self, abilities, {{Strategy = DamageFirstAttackAI, Target = 'Attack'}}, {}, {});
end

function ToTargetMove(self, adb, args)
	-- 대상과의 거리가 짧을수록 높은 점수를 부여한다.
	local attackableScore = adb.TargetAttackable and 1 or 0.1;
	return (1000 / adb.TargetDistance - adb.MoveDistance / 100) * attackableScore;
end

function AttackOnlyTarget(self, adb)
	if adb.IsTarget then
		return math.random(10, 200);
	else
		return 0;
	end
end

function ProvocationAI(self, abilities, args)
	local aggroTarget = GetInstantProperty(self, 'AggroTarget');
	if not aggroTarget then
		return nil, nil, nil;
	end
	return GeneralAI(self, abilities, ToTargetMove, {{Strategy = AttackOnlyTarget, Target = 'Attack'}}, {Target = aggroTarget}, args);
end

function BodyguardTargetMove(self, adb)
	local score = 100;	--기본점수
	
	if adb.Attackable then
		score = score + 150;
	end
	
	score = score - adb.TargetDistance * 10;
	return score;
end

function TameAI(self, abilities, args)
	local master = GetInstantProperty(self, 'Tamer');
	if not master then
		return nil, nil, nil;
	end
	return GeneralAI(self, abilities, BodyguardTargetMove, {{Strategy = NearFirstAttackAI, Target = 'Attack'}}, {Target = master}, args);
end

function ConfusionAI(self, abilities, args)
	if GetBuffStatus(self, 'Unconscious', 'Or') then
		return nil;
	end
	local filteredAbilities = table.filter(abilities, function(ability) return not (ability.ItemAbility and ability.ItemType == 'Potion'); end);
	return GeneralAI(self, filteredAbilities
		, 'AttackMove_SuperAggressive'
		, {{Strategy = DirectRandomAttackAI, Target = 'Attack'}}
		, {NoIndirect = true}, args);
end

function Civil_UnrestAI(self, abilities, args)
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move'; end);
	if #filteredAbilities == 0 then
		return nil, nil, nil;
	end
	local mission = GetMission(self);
	local badField = false;
	local fieldEffects = GetFieldEffectByPosition(mission, GetPosition(self));
	for _, instance in ipairs(fieldEffects) do
		for __, affector in ipairs(SafeIndex(instance, 'Owner', 'BuffAffector')) do
			if BuffEffectivenessTest(SafeIndex(affector, 'ApplyBuff'), self) == 'Debuff' then
				badField = true;
				break;
			end
		end
		if badField then
			break;
		end
	end
	
	if not badField and IsCoveredPosition(mission, GetPosition(self)) then
		return nil, nil, nil;
	end
	
	local pos, score, debugInfo = FindAIMovePosition(self, abilities, function(self, adb, args)
		if adb.BadField then
			return -1357;
		end
		local totalScore = 1000;
		if adb.Coverable then
			totalScore = totalScore + 10000 - adb.MoveDistance * 30;
		else
			local objectDistance = adb.TotalObjectDistanceByFilter(function(o)
				if o.Race.name == 'Object' then
					return false;
				end
				if GetTeam(o) == 'player' or GetTeam(o) == 'citizen' or GetTeam(o) == '_neutral_' then
					return false;
				end
				return true;
			end);
			local badFieldDistance = adb.TotalBadFieldDistance;
			totalScore = totalScore + objectDistance + badFieldDistance;
		end
		
		if adb.ClearPath then
			totalScore = totalScore * 2;
		end
		
		return totalScore;
	end, {}, args);
	
	if pos then
		return filteredAbilities[1], pos, debugInfo, score;
	else
		return nil, nil, nil;
	end
end

function Civil_ConfusionAI(self, abilities, args)
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move'; end);
	if #filteredAbilities == 0 then
		return nil, nil, nil;
	end
	local pos, score, debugInfo = FindAIMovePosition(self, abilities, function(self, adb, args)
		if adb.BadField then
			return -1357;
		end
		
		local minObjectDist = adb.MinObjectDistanceByFilter(function(o)
			return not (o.Race.name == 'Object');
		end);
		local badFieldDistance = adb.TotalBadFieldDistance;
		return minObjectDist + badFieldDistance;
	end, {}, args);
	if pos then
		return filteredAbilities[1], pos, debugInfo, score;
	else
		return nil, nil, nil;
	end
end

function CustomAI(self, abilities, args)
	local aiFunc = _G[args.Script];
	if aiFunc == nil then
		return nil, nil, nil;
	end
	local args = SafeIndex(args, 'AI', 1) or {};
	return aiFunc(self, abilities, args);
end

--[[function MoveAIGeneral(self, adb, args, option)
	option = option or {};
	local melee = option.Melee or false;
	local rallyPoints = args.RallyPoints;
	
	local totalScore = 3000;	
	
	if adb.BadField then
		return -999999;
	end
	
	if option.NoMoveBonus then
		if IsSamePosition(adb.BasePosition, adb.Position) then
			totalScore = totalScore + option.NoMoveBonus;
		end
	end
	
	if option.HeightBonus then
		totalScore = totalScore + adb.Position.z * option.HeightBonus;
	end
	
	-- 엄폐 지역을 선호한다.
	if not melee and adb.CoverScore > 0 then
		totalScore = totalScore + (100 + adb.CoverScore) * (option.CoverScoreMultiplier or 1);
	end
	
	-- 아군이 붙는 곳을 싫어한다 ( 연출용 )
	local allyDensityScore = adb.AllyDensity(2);
	totalScore = totalScore - allyDensityScore * (option.AllyDensityWeight or 20);
	
	-- 최대한 현재 위치에서 적게 움직이려고 한다.( 연출용 )
	local moveDistanceScore = adb.MoveDistance;
	if not melee then
		totalScore = totalScore - moveDistanceScore * (option.MoveDistanceWeight or 30);
	end
	
	-- AI 이끌림 포인트 가산
	local attractiveScore = adb.AttractiveScore;
	totalScore = totalScore + attractiveScore;
	
	-- 필드 이펙트 가산점
	for fieldType, bonus in pairs(self.AIFieldBonus) do
		if bonus ~= 0 then
			if adb.OnFieldEffect(fieldType) then
				totalScore = totalScore + bonus;
			end
		end
	end
	
	-- 랠리 포인트 가산
	local rallyScore = 0;
	local rallyScoreRaw = 0;
	for i, rallyPoint in ipairs(rallyPoints) do
		if not IsInvalidPosition(rallyPoint.Position) then
			local rallyDist = nil;
			if rallyPoint.Method == 'MoveDistance' then
				rallyDist = adb.BaseMoveDistanceTo(rallyPoint.Position);
			else
				rallyDist = GetDistance3D(adb.Position, rallyPoint.Position);
			end
			
			if rallyDist == 0 then
				rallyScoreRaw = rallyScoreRaw + (args.MinRallyProgress or 0);
			else
				rallyScoreRaw = rallyScoreRaw - (rallyDist - reference);
			end
			if rallyPoint.FinalPosition then
				local finalDist = GetDistance3D(adb.Position, rallyPoint.FinalPosition);
				if finalDist < rallyPoint.Range then
					rallyDist = rallyDist - math.max(rallyPoint.Reference, (rallyPoint.Range - finalDist));
				end
			end
			rallyScore = rallyScore - (rallyDist - rallyPoint.Reference) * rallyPoint.Power;
		end
	end
	if rallyPoints and #rallyPoints > 0 and args.MinRallyProgress and rallyScoreRaw < args.MinRallyProgress then
		return -5677;
	end
	totalScore = totalScore + rallyScore;
	-- 안 좋은 지형 피하기
	if adb.ClearPath then
		totalScore = totalScore + 500;	-- 이야 크다
	end
	
	if args.AdditionalMoveScoreFunction then
		for _, scoreFunc in ipairs(args.AdditionalMoveScoreFunction) do
			totalScore = totalScore + scoreFunc(self, adb, args);
		end
	end
	return totalScore;	
end]]

function AbilityAI_NoUse(ability, self, abilities, args, aiConfig)
	-- AI는 사용하지 않음..
	return nil;
end

function AbilityAI_SerialShot(ability, self, abilities, args, aiConfig)
	local attackAbilities = table.filter(abilities, function(ab) return ab.Type == 'Attack' end);
	if #attackAbilities < 2 then
		return nil;
	end
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab.Type == 'Attack' or ab == ability end);
	local abl, pos, debug, score = GeneralAI(self, filteredAbilities, function(self, adb, args)
		local usableAbility = {};
		adb.ForeachAttackInfo(function (attackInfo)
			usableAbility[attackInfo.Ability.name] = math.max(attackInfo.Accuracy, usableAbility[attackInfo.Ability.name] or 0);
		end);
		if table.count(usableAbility) < 2 then
			return -90;
		end
		local accSum = 0;
		for abl, acc in pairs(usableAbility) do
			accSum = accSum + acc;
		end
		return MoveAIGeneral(self, adb, args, {}) + accSum * 100;
	end, {{Strategy = MakeNormalAbilityUseAI(ability), Target='Assist'}}, aiConfig, args);
	
	if abl == ability then
		SetInstantProperty(self, 'NextIntendAbilities', table.map(attackAbilities, function(ab) return ab.name; end));
	end
	return abl, pos, debug, score;
end

function AbilityAI_Howl_Obedience(ability, self, abilities, args, aiConfig)
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	return GeneralAI(self, filteredAbilities, function(self, adb, args)
		local beastCount = 0;
		local targetCount = 0;
		adb.ForeachActionInfo(function(actionInfo)
			local beasts = table.filter(actionInfo.ApplyTargets, function(o)
				return o.Race.name == 'Beast';
			end);
			beastCount = #beasts;
			targetCount = #actionInfo.ApplyTargets;
		end);
		-- 로직이 이상해 보일지도 모르겠으나 Self 타겟 어빌리티라 사용정보가 하나뿐이어야함..
		if beastCount <= 0 then
			return -8998;
		end
		return MoveAIGeneral(self, adb, args, {}) + beastCount * 500 + targetCount * 25;
	end, {{Strategy = MakeNormalAbilityUseAI(ability), Target='Assist'}}, aiConfig, args);
end
function AbilityAI_SpinWeb(ability, self, abilities, args, aiConfig)
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	
	local ff = _G[ability.UseableChecker];
	if #filteredAbilities == 1 and ff and ff(self, ability, GetPosition(self), false, {}) ~= nil then
		return nil;
	end
	return GeneralAI(self, filteredAbilities, function(self, adb, args)
		if adb.OnFieldEffect('Fire') or adb.OnFieldEffect('Spark') or adb.OnFieldEffect('PoisonGas') or adb.OnFieldEffect('Web') then
			return -9988;
		end
		local tileType = GetTileType(self, adb.Position);
		if tileType == 'Splash' or tileType == 'Swamp' then
			return -9988;
		end
		return MoveAIGeneral(self, adb, args, {MoveDistanceWeight = 5, CoverScoreMultiplier = 0, AllyDensityWeight = -3}) - adb.Dangerous * 3;
	end, {{Strategy = MakeNormalAbilityUseAI(ability), Target= 'Assist'}}, aiConfig, args);
end
function AbilityAI_Aiming(ability, self, abilities, args, aiConfig)
	if GetBuff(self, 'TargetChecking') then
		return nil, nil, nil;
	end;
	return GetAbilityAIFunction_Normal(ability, self, abilities, args, aiConfig);
end
function AbilityAI_SetTarget(ability, self, abilities, args, aiConfig)
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	return GeneralAI(self, filteredAbilities, function (self, adb, args)
		-- 아군이 근처에 있어야함.
		if adb.AllyDensity(8, function (o) return TestBattleState(o); end) == 0 then
			return -9999;
		end
		
		if not adb.Coverable then
			return -9999;
		end
		
		if not adb.AttackableEx(function(o) return o and GetBuff(o, 'TargetMarking') == nil end) then
			return -9999;
		end
		
		return MoveAIGeneral(self, adb, args);
	end, {{Strategy = function(self, adb, args)
		if GetBuff(adb.Object, 'TargetMarking') ~= nil then
			return -9999;
		end
		return math.random(1, 10);
	end, Target = 'Attack'}}, aiConfig, args);
end

function AbilityAI_Overwatch(ability, self, abilities, args, aiConfig)
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	local enemyDistanceRatio = args.EnemyDistanceRatio or 0;
	
	return GeneralAI(self, filteredAbilities, function (self, adb, args)		
		if not adb.Coverable then
			return -9999;
		end
		
		local minEnemyDistance = adb.MinEnemyDistance;
		if minEnemyDistance < 6 then
			return -9999;
		end
		
		if adb.EnemyCount == 0 then
			return -9999;
		end
		
		return MoveAIGeneral(self, adb, args) + minEnemyDistance * enemyDistanceRatio;
	end, {{Strategy = function(self, adb, args)
		if adb.EnemyCount == 0 then
			return -9999;
		end
		
		if adb.Ability.name == 'Overwatch' then
			return 100;
		else
			return -1;
		end
	end, Target = 'Assist'}}, aiConfig, args);
end

function AbilityAI_FlashBangGrenade(ability, self, abilities, args, aiConfig)
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	
	-- 선 확률 처리
	local usedCount = ability.MaxUseCount - ability.UseCount;
	if #filteredAbilities > 1 and RandomTest(1 / (3 * (1 + usedCount)) * 100) then	-- 1/3 -> 1/6 -> 1/9
		return nil, nil, nil;
	end
	
	return GeneralAI(self, filteredAbilities, 'AttackMove_Aggressive_Force', {{Strategy = NearFirstAttackAI, Target = 'Attack'}}, aiConfig, args);
end

function AbilityAI_Roar(ability, self, abilities, args, aiConfig)
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	local testBuffName = ability.ApplyTargetBuff.name;
	return GeneralAI(self, filteredAbilities, function(self, adb, args)
		local pass = false;
		adb.ForeachActionInfo(function(actionInfo)
			local validApplyTargets = table.filter(actionInfo.ApplyTargets, function(o)
				return IsEnemy(self, o) and GetBuff(o, testBuffName) == nil;
			end);
			if #validApplyTargets < 2 then
				return;
			end
			pass = true;
		end);
		if not pass then
			return -9999;
		end
		
		return MoveAIGeneral(self, adb, args, {Melee = true});
	end, {{Strategy = function(self, adb, args)
		local validApplyTargets = table.filter(adb.ApplyTargets, function(o)
			return IsEnemy(self, o) and GetBuff(o, testBuffName) == nil;
		end);
		if #validApplyTargets < 2 then
			return -1;
		else
			return 100;
		end
	end, Target = 'Assist'}}, aiConfig, args);
end

function AbilityAI_Conceal(ability, self, abilities, args, aiConfig)
	if args.NoConceal then
		return nil;
	end
	local moveAI = nil;
	if self.Job.AttackType == 'Melee' then
		moveAI = function (self, adb, args)
			local coverable = adb.Coverable;
			if adb.EnemyCount > 0 and not coverable then
				return -9999;
			end
			local distanceScore = math.min(adb.MinEnemyBaseMoveDist, 25);
			local coverableScore = 0;
			if coverable then
				coverableScore = 45;
			end
			return MoveAIGeneral(self, adb, args, {Melee = true, MoveDistanceWeight = 0}) - distanceScore * 20 + coverableScore;
		end;
	else
		moveAI = function (self, adb, args)
			local coverable = adb.Coverable;
			if adb.EnemyCount > 0 and not adb.Coverable then
				return -9999;
			end
			local coverableScore = 0;
			if coverable then
				coverableScore = 45;
			end
			return MoveAIGeneral(self, adb, args, {Melee = false}) + coverableScore;
		end;
	end
	-- 잠복을 사용하려 했지만 혹여나 이동한 위치에서 공격이 가능하다면 그냥 공격을 해버린다. 시야에 보이지 않던 적의 등장에 대응하기 위함
	-- 또한 이를 위해서 어빌리티 리스트 필터링을 치지 않음.
	
	local configCopy = table.deepcopy(aiConfig);
	configCopy.NoMoveIntercepter = function()
		local allUnit = GetAllUnitInSight(self, true);
		local allEnemies = table.filter(allUnit, function(unit)
			return IsEnemy(self, unit);
		end);
		local aiSession = GetAISession(self, GetTeam(self));
		if #allEnemies == 0 and #(table.filter(aiSession:GetTemporalSightObjects(), function(o) return GetDistanceFromObjectToObject(self, o) <= self.SightRange; end)) == 0 then
			return 'Wait';	-- 대기
		else
			return nil;
		end
	end;
	
	local actionAI = {{Strategy = NormalForceAbilityActionAI, Target = 'Attack'}, {Strategy = function(self, adb, args)
		if not IsCoveredPosition(GetMission(self), adb.Position) then
			return -1;
		end
		if adb.Ability == ability then
			return 1;
		end
		return -1;
	end, Target = 'Assist'}};
	return GeneralAI(self, abilities, moveAI, actionAI, configCopy, args);
end

function AbilityAI_Rest(ability, self, abilities, args, aiConfig)
	local activeRatio = args.ActiveRatio or 0.25;
	
	if self.Cost / self.MaxCost > activeRatio then
		-- 안씀
		return nil, nil, nil;
	end
	
	-- 기력 회복 물약이 있다면 우선적으로 사용하기
	local applyCostAbility = table.filter(abilities, function(ab) return ab.ItemAbility and GetAbilityApplyCost(ab, self, self) > 0 end);
	if #applyCostAbility > 0 then
		return applyCostAbility[1], GetPosition(self), {};
	end
	
	
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	return GeneralAI(self, filteredAbilities, function(self, adb, args)
		if adb.EnemyCount > 0 and not adb.Coverable then
			return -9999;
		end
		if adb.BadField then
			return -1357;
		end
		local coverScore = 0;
		if adb.CoverScore > 0 then
			coverScore = 100 + adb.CoverScore;
		end
		local dangerousScore = adb.Dangerous;	
		local moveDistanceScore = adb.MoveDistance;
		local allyDensityScore = adb.AllyDensity(4);
		
		local totalScore = 1000 + coverScore - dangerousScore * 3 - moveDistanceScore + allyDensityScore * 2;
		if adb.ClearPath then
			totalScore = totalScore + 100;
		end
		if adb.Coverable then
			totalScore = totalScore + 45;
		end
		
		local rallyPoints = args.RallyPoints;
		
		-- 랠리 포인트 가산
		for i, rallyPoint in ipairs(rallyPoints) do
			if not IsInvalidPosition(rallyPoint.Position) then
				local rallyDist = GetDistance3D(adb.Position, rallyPoint.Position);
				if rallyDist > rallyPoint.Range then
					totalScore = totalScore - (rallyDist - rallyPoint.Reference) * rallyPoint.Power;
				end
			end
		end
		return totalScore; 
	end, {{Strategy = MakeNormalAbilityUseAI(ability), Target = 'Assist'}}, aiConfig, args);
end

function AbilityAI_Move(ability, self, abilities, args, aiConfig)
	local moveAI = nil;
	if args.NoFullMove then
		aiConfig.FullMove = false;
	end
	if self.Job.AttackType == 'Melee' then
		moveAI = 'MoveStrategy_Melee';
	else
		if self.Coverable then
			moveAI = 'MoveStrategy_Cover';
		else
			moveAI = 'MoveStrategy_NoCover';
		end
	end
	local pos, score, debugInfo = FindAIMovePosition(self, {ability}, moveAI, aiConfig, args);
	if pos ~= nil and not IsInvalidPosition(pos) and not IsSamePosition(pos, GetPosition(self)) then
		return ability, pos, debugInfo, score;
	else
		return nil, nil, nil;
	end
end

function AbilityAI_StandBy(ability, self, abilities, args, aiConfig)
	local moveAbilities = table.filter(abilities, function(ab) return ab.name == 'Move'; end);
	if #moveAbilities > 0 then
		return AbilityAI_Move(moveAbilities[1], self, abilities, args, aiConfig);
	else
		local filteredAbilities = table.filter(abilities, function(ab) return ab == ability; end);
		return filteredAbilities[1], GetPosition(self);
	end
end

function AbilityAI_IronWall(ability, self, abilities, args, aiConfig)	
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);

	return GeneralAI(self, filteredAbilities, function(self, adb, args)
		if adb.MinEnemyDistance > 5 then
			return -8787;
		end
		if adb.SideAttackCount == 0 then
			return -8788;
		end
		if adb.AllyDensity(5) == 0 then
			return -8789;
		end
		local noneCoverScore = adb.Coverable and 0 or 100;
		return MoveAIGeneral(self, adb, args, {CoverScoreMultiplier = -1, MoveDistanceWeight = 0}) - adb.SideAttackCount * 50 + noneCoverScore;
	end, {{Target = 'Assist', Strategy = MakeNormalAbilityUseAI(ability)}}, aiConfig, args);
end

function TestPreCancelRatio(args, baseRatio)
	local preCancelRatio = args.PreCancelRatio or baseRatio;
	
	-- 선확률 처리
	return RandomTest(preCancelRatio);
end

function AbilityAI_SmokeGrenade(ability, self, abilities, args, aiConfig)
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	
	if #filteredAbilities > 1 and TestPreCancelRatio(args, 30) then
		return nil;
	end
	
	local allUnit = GetAllUnitInSight(self, true);
	if table.count(allUnit, function(unit)
		return IsEnemy(self, unit) and unit.Job.AttackType == 'Force';
	end) == 0 then
		return nil;
	end
	
	local allyMeleeCountInSight = table.count(allUnit, function(unit) return IsTeamOrAlly(self, unit) and unit.Job.AttackType == 'Melee'; end);
	local enemyMeleeCountInSight = table.count(allUnit, function(unit) return IsEnemy(self, unit) and unit.Job.AttackType == 'Melee'; end);
	
	-- AI의 비용을 줄이기 위해서 미리 어빌리티를 사용할 수 있는 위치를 제한한다. 최소 사용자가 아닌 아군이 적용 범위 안에 1명은 존재하는 위치들에 대해서만 테스트 하는 걸로..
	if #filteredAbilities > 1 then
		local allAllies = table.filter(allUnit, function(unit)
			return self ~= unit and IsTeamOrAlly(self, unit);
		end);
		local limitedPositions = {};
		for i, ally in ipairs(allAllies) do
			if GetDistanceFromObjectToObject(self, ally) < 15 then		-- 근처 15 칸으로 선 제한
				table.append(limitedPositions, CalculateRange(ally, ability.ApplyRange, GetPosition(ally)));
			end
		end
		aiConfig.LimitedUseablePosition = limitedPositions;
	end
	
	return GeneralAI(self, filteredAbilities, function(self, adb, args)
		local maxScore = 0;
		adb.ForeachActionInfo(function(actionInfo)
			local allyCount = 0;
			local enemyCount = 0;
			local allyMeleeCount = 0;
			local enemyMeleeCount = 0
			for i, o in ipairs(actionInfo.ApplyTargets) do
				if GetBuff(o, 'SmokeScreen') == nil then
					if IsTeamOrAlly(self, o) then
						allyCount = allyCount + 1;
						if o.Job.AttackType == 'Melee' then
							allyMeleeCount = allyMeleeCount + 1;
						end
					elseif IsEnemy(self, o) then
						enemyCount = enemyCount + 1;
						if o.Job.AttackType == 'Melee' then
							enemyMeleeCount = enemyMeleeCount + 1;
						end
					end
				end
			end
			--LogAndPrint('AbilityAI_SmokeGrenade', allyCount, enemyCount, allyMeleeCount);
			if enemyCount == 0 then
				if allyCount < 2 then
					return;
				end
			elseif allyMeleeCount == 0 or (enemyCount + (enemyMeleeCountInSight - enemyMeleeCount) / 2) > (allyCount + (allyMeleeCountInSight - allyMeleeCount) / 2) then
				return;
			end
			maxScore = math.max(maxScore, allyCount * 70);
		end);
		if maxScore == 0 then
			return -8989;
		end
		return MoveAIGeneral(self, adb, args, {Melee = self.Job.AttackType == 'Melee'}) + maxScore;
	end, {{Target = 'Assist', Strategy = function(self, adb, args)
		local allyCount = 0;
		local enemyCount = 0;
		local allyMeleeCount = 0;
		local enemyMeleeCount = 0
		for i, o in ipairs(adb.ApplyTargets) do
			if GetBuff(o, 'SmokeScreen') == nil then
				if IsTeamOrAlly(self, o) then
					allyCount = allyCount + 1;
					if o.Job.AttackType == 'Melee' then
						allyMeleeCount = allyMeleeCount + 1;
					end
				elseif IsEnemy(self, o) then
					enemyCount = enemyCount + 1;
					if o.Job.AttackType == 'Melee' then
						enemyMeleeCount = enemyMeleeCount + 1;
					end
				end
			end
		end
		if enemyCount == 0 then
			if allyCount < 2 then
				return -1;
			end
		elseif allyMeleeCount == 0 or (enemyCount + (enemyMeleeCountInSight - enemyMeleeCount) / 2) > (allyCount + (allyMeleeCountInSight - allyMeleeCount) / 2) then
			return -1;
		end
		return allyCount * 10 + math.random(1, 9);
	end}}, aiConfig, args);
end

function AbilityAI_EMPGrenade(ability, self, abilities, args, aiConfig)
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	return GeneralAI(self, filteredAbilities, function(self, adb, args)
		if not adb.Coverable then
			return -9999;
		end
		local maxEffectiveCount = 0;
		adb.ForeachActionInfo(function(actionInfo)
			-- 아군이 포함되어 있으면 무시
			local hasAlly = table.exist(actionInfo.ApplyTargets, function (obj)
				return IsTeamOrAlly(self, obj) and not BuffImmunityTest(ability.ApplyTargetBuff, obj);
			end);
			if hasAlly then
				return;
			end
			local effectiveCount = table.count(actionInfo.ApplyTargets, function (obj)
				return IsEnemy(self, obj) and not BuffImmunityTest(ability.ApplyTargetBuff, obj) and GetBuff(obj, ability.ApplyTargetBuff.name) == nil;
			end);
			maxEffectiveCount = math.max(maxEffectiveCount, effectiveCount);
		end);
		if maxEffectiveCount < 1 then
			return -9998;
		end
		return MoveAIGeneral(self, adb, args) + maxEffectiveCount * 80;
	end, {{Target = 'Assist', Strategy = function(self, adb, args)
		-- 아군이 포함되어 있으면 무시
		local hasAlly = table.exist(adb.ApplyTargets, function (obj)
			return IsTeamOrAlly(self, obj) and not BuffImmunityTest(ability.ApplyTargetBuff, obj);
		end);
		if hasAlly then
			return -5378;
		end
		local effectiveCount = table.count(adb.ApplyTargets, function (obj)
			return IsEnemy(self, obj) and not BuffImmunityTest(ability.ApplyTargetBuff, obj) and GetBuff(obj, ability.ApplyTargetBuff.name) == nil;
		end);
		if effectiveCount < 1 then
			return -5378;
		end
		return effectiveCount * 80 + math.random(1, 9);
	end}}, aiConfig, args);
end

function AbilityAI_RestoreHP(ability, self, abilities, args, aiConfig)
	if (GetInstantProperty(self, 'LastRestoreHPUsedTurn') or -1) + 1 >= self.TurnPlayed then
		return nil, nil, nil;
	end

	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	
	args.RecoveryRatio = GetInstantProperty(self, 'RecoveryRatio') or 0.25;
	if self.HP / self.MaxHP < args.RecoveryRatio then
		args.SelfHeal = true;
	end
	-- 자신 힐이 아니면, 주변 아군 중에 힐 대상이 없으면 무시
	if not args.SelfHeal then
		local allUnit = GetAllUnitInSight(self, true);
		local allAllies = table.filter(allUnit, function(unit)
			return self ~= unit and IsTeamOrAlly(self, unit);
		end);
		local mission = GetMission(self);
		-- 사용자 보정
		local selfRatio = self.Job.AssistRatio;
		-- 난이도 보정
		local difficultyRatio = 1;
		local relation = GetRelationByTeamName(mission, 'player', GetTeam(self));
		if relation == 'Team' or relation == 'Ally' then
			difficultyRatio = mission.Difficulty.RecoverRatio;
		else
			difficultyRatio = mission.Difficulty.EnemyRecoverRatio;
		end
		-- 어빌리티 보정
		local abilityRatio = ability.ItemAbility and 0.5 or 1;
		local selfTotalRatio = selfRatio * difficultyRatio * abilityRatio;
		local isEnable = false;
		for i, ally in ipairs(allAllies) do
			-- 대상 기준치
			local allyRatio = GetInstantProperty(ally, 'RecoveryRatio') or 0.25;
			if ally.HP / ally.MaxHP < allyRatio * selfTotalRatio then
				isEnable = true;
				break;
			end
		end
		if not isEnable then
			return nil;
		end
	end
	
	local selAbil, pos, debugInfo, bestScore = GeneralAI(self, filteredAbilities, function(self, adb, args)
		if adb.AllyRepairAmount <= 0 then
			return -1;
		end
		local score = 0;
		if not args.SelfHeal then
			local addScore = 100 * self.Job.AssistRatio;
			score = score + adb.AllyRepairAmount * addScore;
		end
		local option = {};
		
		if adb.Coverable then
			score = score + 100;
		end
		local dangerousScore = adb.Dangerous;
		score = score - dangerousScore;
		option.MoveDistanceWeight = 1;
		
		option.AllyDensityWeight = 1;
		option.Melee = self.Job.AttackType == 'Melee';
		local generalMoveScore = MoveAIGeneral(self, adb, args, option);
		return generalMoveScore + score;	
	end, {{Target = 'Assist', Strategy = CommonHealAI}}, aiConfig, args);
	if selAbil == nil then
		return nil, nil, nil;
	end
	
	if ability == selAbil then
		SetInstantProperty(self, 'LastRestoreHPUsedTurn', self.TurnPlayed);
	end
	return selAbil, pos, debugInfo;
end

function AbilityAI_StarCall(ability, self, abilities, args, aiConfig)
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	
	return GeneralAI(self, filteredAbilities, function(self, adb, args)
		local score = 0;
		
		local maxCount = 0;
		adb.ForeachActionInfo(function(actionInfo)
			local count = 0;
			for _, target in ipairs(actionInfo.ApplyTargets) do
				if #GetBuffType(target, 'Debuff') > 0 then
					count = count + 1;
				end
			end
			if count > maxCount then
				maxCount = count;
			end
		end);
		
		if maxCount == 0 then
			return -7342;
		end
		score = maxCount * 200;
		
		local option = {};
		
		if adb.Coverable then
			score = score + 100;
		end
		local dangerousScore = adb.Dangerous;
		score = score - dangerousScore;
		option.MoveDistanceWeight = 1;
		
		option.AllyDensityWeight = 1;
		option.Melee = self.Job.AttackType == 'Melee';
		local generalMoveScore = MoveAIGeneral(self, adb, args, option);
		return generalMoveScore + score;
	end, {{Target = 'Assist', Strategy = function(self, adb, args)
		local count = 0;
		for _, target in ipairs(adb.ApplyTargets) do
			if #GetBuffType(target, 'Debuff') > 0 then
				count = count + 1;
			end
		end
		return count;
	end}}, aiConfig, args);
end

function AbilityAI_Charging(ability, self, abilities, args, aiConfig)
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	
	local allUnit = GetAllUnitInSight(self, true);
	local allEnemies = table.filter(allUnit, function(unit)
		return IsEnemy(self, unit);
	end);
	if #allEnemies == 0 then
		return nil;
	end
	
	if self.Overcharge > 0 or self.SP + ability.ApplyAmount < self.MaxSP then
		return nil;
	end
	
	return ability, GetPosition(self), {};
end

function AbilityAI_ClimbWeb(ability, self, abilities, args, aiConfig)
	-- 시야 내에 적이 없으면 사용하지 않는다.
	local allUnit = GetAllUnitInSight(self, true);
	local allEnemies = table.filter(allUnit, function(unit)
		return IsEnemy(self, unit);
	end);
	if #allEnemies == 0 then
		return nil;
	end

	local pos = GetPosition(self);
	local debugInfo = {};
	table.insert(debugInfo, { Position = pos, Score = 9999, Ability = ability.name });
	return ability, pos, debugInfo;
end

function AbilityAI_FallWeb(ability, self, abilities, args, aiConfig)
	-- 시야 내에 적이 없으면 사용하지 않는다.
	local allUnit = GetAllUnitInSight(self, true);
	local allEnemies = table.filter(allUnit, function(unit)
		return IsEnemy(self, unit);
	end);
	if #allEnemies == 0 then
		return nil;
	end

	return FindAIMainAction(self, {ability}, {{Strategy = function (self, adb, args)
		if not args.AllowObstacle and adb.ObstacleShot then
			return -5378;
		end
		if adb.HitCount < 1 then
			return -1427;
		end

		local score = 1000 - adb.Distance * 10 + math.random(1, 9) + adb.Hate + 1000 * adb.HitCount;
		if adb.NoCoverAttack then
			score = score + 1000;
		end
		
		return score;
	end, Target = 'Attack'}}, aiConfig, args);
end

function AbilityAI_SummonBeast(ability, self, abilities, args, aiConfig)
	local summonBeastList = GetEnableSummonBeastList(self);
	if #summonBeastList == 0 then
		return nil, nil, nil;
	end
	
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	
	local moveAbility = nil;
	for i, ability in ipairs(filteredAbilities) do	
		if ability.name == 'Move' then
			moveAbility = ability;
			break;
		end
	end
	if moveAbility then
		local pos, score, debugInfo = FindAIMovePosition(self, filteredAbilities, 'AttackMove_Defensive', aiConfig, args);
		if pos ~= nil and not IsSamePosition(GetPosition(self), pos) then
			return moveAbility, pos, debugInfo;
		end
	end
	
	local mission = GetMission(self);
	local usingPos = table.randompick(Linq.new(CalculateRange(self, ability.TargetRange, GetPosition(self)))
		:where(function(pos) return GetObjectByPosition(mission, pos) == nil; end)
		:toList());
	if usingPos then
		return ability, usingPos;
	else
		return nil;
	end
end

function AbilityAI_Trap(ability, self, abilities, args, aiConfig)
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	
	local moveAbility = nil;
	for i, ability in ipairs(filteredAbilities) do	
		if ability.name == 'Move' then
			moveAbility = ability;
			break;
		end
	end
	
	if GetInstantProperty(self, 'LastTrapUsedTurn') == self.TurnPlayed then
		return;
	end
	
	-- 시야 내에 적이 없으면 사용하지 않는다.
	local allUnit = GetAllUnitInSight(self, true);
	local allEnemies = table.filter(allUnit, function(unit)
		return IsEnemy(self, unit);
	end);
	if #allEnemies == 0 then
		return;
	end
	
	local safeState = not table.exist(allEnemies, function(unit) return GetCoverState(self, GetPosition(unit)) == 'None'; end);	
	local nearestEnemy = Linq.new(allEnemies)
		:orderByAscending(function(unit) return GetDistance3D(GetPosition(unit), GetPosition(self)); end)
		:first();
	if GetDistanceFromObjectToObject(self, nearestEnemy) > 2.3 and safeState then
		local usingPos = Linq.new(CalculateRange(self, ability.TargetRange, GetPosition(self)))
			:where(function(pos) return GetDistance3D(GetPosition(self), pos) <= 4.4; end)
			:orderByAscending(function(pos) return GetDistance3D(GetPosition(nearestEnemy), pos) end)
			:first();
		SetInstantProperty(self, 'LastTrapUsedTurn', self.TurnPlayed);
		return ability, usingPos;
	else
		local pos, score, debugInfo = FindAIMovePosition(self, filteredAbilities, function(self, adb, args)
			if not adb.Coverable then
				return -551;
			end
			if adb.EnemyCount <= 0 then
				return -222;
			end
			local score = adb.TotalEnemyDistance * 10;
			return MoveAIGeneral(self, adb, args, {MoveDistanceWeight = 0, CoverScoreMultiplier = 1}) + score;
		end, aiConfig, args);
		if pos ~= nil and not IsSamePosition(pos, GetPosition(self)) then
			return moveAbility, pos, debugInfo;
		end
	end
end

function AbilityAI_Fueling(ability, self, abilities, args, aiConfig)
	if not self.TurnState.Moved then
		if self.Cost / self.MaxCost > 0.1 then
			return;
		end
		
		-- 시야 내에 적이 없으면 사용하지 않는다.
		local allUnit = GetAllUnitInSight(self, true);
		local allEnemies = table.filter(allUnit, function(unit)
			return IsEnemy(self, unit);
		end);
		if #allEnemies > 0 then
			return;
		end
	end
	
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	
	return GeneralAI(self, filteredAbilities, function(self, adb, args)
		if not adb.Interactable then
			return -239;
		end
		
		return MoveAIGeneral(self, adb, args);
	end, {{Strategy = MakeNormalAbilityUseAI(ability), Target = 'Interaction'}}, {}, args);
end

function AbilityAI_StarWall(ability, self, abilities, args, aiConfig)
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	return GeneralAI(self, filteredAbilities, function(self, adb, args)
		if not adb.Actable then
			return -2391;
		end
		
		local existEnemyTarget = false;
		adb.ForeachActionInfo(function(actionInfo)
			existEnemyTarget = existEnemyTarget or IsEnemy(self, actionInfo.Object);
		end);
		
		if not existEnemyTarget then
			return -2291;
		end
	
		return MoveAIGeneral(self, adb, args);
	end, {{Strategy = function(self, adb, args)
		if adb.Ability == ability then
			if IsEnemy(self, adb.Object) then
				return math.random(1, 10);
			else
				return -2;
			end
		else
			return -3;
		end
	end, Target = 'Assist'}}, {}, args);
end

function AbilityAI_GlidingMove2(ability, self, abilities, args, aiConfig)
	local allUnit = GetAllUnitInSight(self, true);
	local allEnemies = table.filter(allUnit, function(unit)
		return IsEnemy(self, unit);
	end);
	if #allEnemies == 0 then
		return nil;
	end
	
	local mission = GetMission(self);

	local configCopy = table.deepcopy(aiConfig);
	configCopy.ActionWithMove = true;
	local moveOption = {CoverScoreMultiplier = 0, AllyDensityWeight = 0, MoveDistanceWeight = 0};
	local p, s, d = FindAIMovePosition(self, abilities, function(self, adb, args)
		if #GetAllObjectsByPosition(mission, adb.Position) >= 2 then
			return -902;
		end

		-- 1. 이동 후 적을 공격 가능해야
		if not adb.Attackable then
			return -982;
		end
		local score = 1000;
		
		-- 2. 이동 방향은 적과 가장 먼 곳으로
		local enemyDistance = adb.MinEnemyDistance;
		score = score + enemyDistance * 100;
		
		-- 3. 아군의 밀집도가 낮은 쪽으로
		local density = adb.AllyDensity(6);
		score = score - density * 100;
		
		local finalScore = MoveAIGeneral(self, adb, args, moveOption) + score;
		return finalScore;
	end, configCopy, args, ability);
		
	if p == nil or s < 0 or IsSamePosition(p, GetPosition(self)) then
		return nil;
	end
	SetInstantProperty(self, 'GlidingMoveRightBefore', true);
	return ability, p, d, s;	
end

function AbilityAI_Windwalker(ability, self, abilities, args, aiConfig)
	local configCopy = table.deepcopy(aiConfig);
	configCopy.ActionWithMove = true;
	local mission = GetMission(self);
	local p, s, d = FindAIMovePosition(self, abilities, function(self, adb, args)
		if #GetAllObjectsByPosition(mission, adb.Position) >= 2 then
			return -902;
		end
		local score = MoveAIGeneral(self, adb, args);
		return score;
	end, args, configCopy, ability);
	if p == nil or s < 0 or IsSamePosition(p, GetPosition(self)) then
		return nil;
	end
	return ability, p, d, s;
end

function AbilityAI_Lightningwalker(ability, self, abilities, args, aiConfig)
	local myPos = GetPosition(self);
	local range = CalculateRange(self, ability.TargetRange, myPos);
	local distanceMaxer = MinMaxer.new(function(d) return GetDistance3D(myPos, d.Pos) end);
	local mission = GetMission(self);
	local enemyCount = 0;
	for _, pos in ipairs(range) do
		local obj = GetObjectByPosition(mission, pos);
		if obj and IsEnemy(self, obj) then
			enemyCount = enemyCount + 1;
			distanceMaxer:Update({Pos = pos, Obj = obj});
		end
	end
	if enemyCount < 2 then
		return;
	end
	
	local furthermostEnemyData = distanceMaxer:GetMax();
	local distanceMiner = MinMaxer.new(function(p) 
		local myDist = GetDistance3D(myPos, p);
		local toDist = GetBaseMoveDistance(mission, p, furthermostEnemyData.Pos);
		return myDist + toDist*toDist;
	end);
	for _, pos in ipairs(range) do
		local obj = GetObjectByPosition(mission, pos);
		if obj == nil then
			distanceMiner:Update(pos);
		end
	end
	local retPos = distanceMiner:GetMin();
	if IsSamePosition(retPos, myPos) then
		return nil;
	end
	AddHate(self, furthermostEnemyData.Obj, 9999);
	SubscribeWorldEvent(self, 'UnitTurnEnd', function(eventArg, ds, subscriptionID)
		UnsubscribeWorldEvent(self, subscriptionID);
		AddHate(self, furthermostEnemyData.Obj, -9999);
	end);
	
	return ability, retPos, {{Position = retPos, Score = 100}}, 100;
end

function AbilityAI_Stealth(ability, self, abilities, args, aiConfig)
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	ForceNewInsert(args, 'AdditionalMoveScoreFunction', function(self, adb, args)
		if adb.MinEnemyDistance <= 2 then
			return -7777;
		end
		return adb.MinEnemyDistance;
	end);
	return GeneralAI(self, filteredAbilities, 'AttackMove_Defensive', 
			{{Strategy = CommonSupportAI, Target = 'Assist'}}, {}, args);
end

function AbilityAI_Entangle(ability, self, abilities, args, aiConfig)
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	local testBuffName = ability.ApplyTargetBuff.name;
	return GeneralAI(self, filteredAbilities, function(self, adb, args)
		if adb.MinEnemyDistance <= 2 then
			return -7777;
		end
		local pass = false;
		adb.ForeachActionInfo(function(actionInfo)
			local validApplyTargets = table.filter(actionInfo.ApplyTargets, function(o)
				return IsEnemy(self, o) and GetBuff(o, testBuffName) == nil;
			end);
			if #validApplyTargets < 3 then
				return;
			end
			pass = true;
		end);
		if not pass then
			return -9999;
		end
		return MoveAIGeneral(self, adb, args);
	end, {{Strategy = function(self, adb, args)
		local validApplyTargets = table.filter(adb.ApplyTargets, function(o)
			return IsEnemy(self, o) and GetBuff(o, testBuffName) == nil;
		end);
		if #validApplyTargets < 3 then
			return -1;
		else
			return 100;
		end
	end, Target = 'Assist'}}, {}, args);
end

function AbilityAI_RemoveStickyWeb(ability, self, abilities, args, aiConfig)
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	local testBuffName = ability.RemoveBuff.name;
	
	return GeneralAI(self, filteredAbilities, function(self, adb, args)
		local score = 0;
		
		local maxCount = 0;
		adb.ForeachActionInfo(function(actionInfo)
			local count = 0;
			for _, target in ipairs(actionInfo.ApplyTargets) do
				if HasBuff(target, testBuffName) then
					count = count + 1;
				end
			end
			if count > maxCount then
				maxCount = count;
			end
		end);
		
		if maxCount == 0 then
			return -7342;
		end
		score = maxCount * 200;
		
		local option = {};
		
		if adb.Coverable then
			score = score + 100;
		end
		local dangerousScore = adb.Dangerous;
		score = score - dangerousScore;
		option.MoveDistanceWeight = 1;
		
		option.AllyDensityWeight = 1;
		option.Melee = self.Job.AttackType == 'Melee';
		local generalMoveScore = MoveAIGeneral(self, adb, args, option);
		return generalMoveScore + score;
	end, {{Target = 'Assist', Strategy = function(self, adb, args)
		local count = 0;
		for _, target in ipairs(adb.ApplyTargets) do
			if HasBuff(target, testBuffName) then
				count = count + 1;
			end
		end
		return count;
	end}}, aiConfig, args);
end

function AbilityAI_Potion_Scourge(ability, self, abilities, args, aiConfig)
	if HasBuff(self, ability.ApplyTargetBuff.name) then
		return nil;
	end
	local moveAvailable = table.exist(abilities, function(ab) return ab.name == 'Move' end);
	
	if not moveAvailable then
		if #GetInstantProperty(self, 'IntendAbilities') == 1 then		-- 이 경우는 이전 행동이 스콜지 물약 AI로부터 발생한 것으로 봄. AI_Monster_Normal 참고.
			return ability, GetPosition(self), {{Position = GetPosition(self), Score = 100, Ability = ability.name}}, 100;
		end
	end
	
	local allUnit = GetAllUnitInSight(self, true);
	local allEnemies = table.filter(allUnit, function(unit)
		return IsEnemy(self, unit);
	end);
	if #allEnemies == 0 then
		return nil;
	end
	
	local selfPos = GetPosition(self);
	local _, minDist = table.min(allEnemies, function(o) return GetDistance3D(selfPos, GetPosition(o)) end);
	if minDist < 8 and self.Job.AttackType ~= 'Melee' and IsCoveredPosition(self, selfPos) then	-- 그냥 그자리에서 사용
		return ability, GetPosition(self), {{Position = GetPosition(self), Score = 100, Ability = ability.name}}, 100;
	end
	
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	return GeneralAI(self, filteredAbilities, 'AttackMove_Defensive', {{Strategy = MakeNormalAbilityUseAI(ability), Target = 'Assist'}}, aiConfig, args);
end

function AbilityAI_PreyFishing(ability, self, abilities, args, aiConfig)
	local availableEnemies = table.filter(GetTargetInRangeSight(self, ability.TargetRange, 'Enemy', true), function(unit)
		return _G[ability.TargetUseableChecker](self, ability, unit, {}) == nil;
	end);
	if #availableEnemies == 0 then
		return nil;
	end
	
	return ability, GetPosition(table.randompick(availableEnemies)), {}, 1;
end

function AbilityAI_PreyThrow(ability, self, abilities, args, aiConfig)
	local allUnit = GetAllUnitInSight(self, true);
	local allAllies = table.filter(allUnit, function(unit)
		return IsTeamOrAlly(self, unit);
	end);
	aiConfig.AllowZeroTarget = true;
	local mission = GetMission(self);
	return FindAIMainAction(self, {ability}, {{Strategy = function(self, adb, args)
		if GetObjectByPosition(mission, adb.Position) then
			return -31;
		end
		if #adb.ApplyTargets > 0 then
			return 1000 + #adb.ApplyTargets * 10;
		end
		local distanceSum = 0;
		for _, ally in ipairs(allAllies) do
			distanceSum = distanceSum + GetDistance3D(adb.Position, GetPosition(ally));
		end
		
		if distanceSum == 0 then
			return math.random(1, 5);
		end
		
		return 1000 / distanceSum;
	end, Target = 'Attack'}}, aiConfig, args);
end

function AbilityAI_PreySeal(ability, self, abilities, args, aiConfig)
	local allUnit = GetAllUnitInSight(self, true);
	local allAllies = table.filter(allUnit, function(unit)
		return IsTeamOrAlly(self, unit);
	end);
	aiConfig.AllowZeroTarget = true;
	local mission = GetMission(self);
	return FindAIMainAction(self, {ability}, {{Strategy = function(self, adb, args)		
		local distanceSum = 0;
		if GetObjectByPosition(mission, adb.Position) then
			return -31;
		end
		for _, ally in ipairs(allAllies) do
			distanceSum = distanceSum + GetDistance3D(adb.Position, GetPosition(ally));
		end
		
		if distanceSum == 0 then
			return math.random(1, 5);
		end
		
		return 1000 / distanceSum;
	end, Target = 'Any'}}, aiConfig, args);
end

function NormalForceAbilityActionAI(self, adb, args)
	local score = 1000 - adb.Distance * 10 + math.random(1, 9) + adb.Hate * (args.HateRatio or 1) + GetTeamHate(args, GetTeam(adb.Object));
	if not args.AllowObstacle and adb.ObstacleShot then
		return -5378;
	end
	if adb.NoCoverAttack then
		score = score + 1000;
	end
	
	if adb.IsTarget then
		return 9999;
	end
	score = score * GetTargetScoreRatio(self, adb.Object);
	return score;
end

function NormalRangedAbilityActionAI(self, adb, args)
	if not args.AllowObstacle and adb.ObstacleShot then
		return -5378;
	end
	if args.NoSingleIndirectAttack then
		if adb.HitCount <= 1 and adb.IsIndirect then
			return -876;
		end
	end
	if args.NoSingleAttack then
		if adb.HitCount <= 1 then
			return -875;
		end
	end
	
	if adb.IsTarget then
		return 9999;
	end
	
	local score = 1000 - adb.Distance * 10 + math.random(1, 9) + adb.Hate * (args.HateRatio or 1) + GetTeamHate(args, GetTeam(adb.Object));
	if adb.NoCoverAttack then
		score = score + 1000;
	end
	
	score = score * GetTargetScoreRatio(self, adb.Object);
	
	return score;
end

function GetAbilityAIFunction_Normal(ability, self, abilities, args, aiConfig)
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	local moveAI = 'AttackMove_Defensive';
	local actionAI = {Strategy = NormalForceAbilityActionAI, Target = 'Attack'};

	if ability.Type == 'Attack' then
		local abilityUseType = GetAbilityUseType(ability);
		if ability.HitRateType == 'Melee' then
			if ability.TargetType == 'Area' then
				moveAI = 'AttackMove_SuperAggressive_Area';
			else
				moveAI = 'AttackMove_SuperAggressive';
			end
			actionAI.Strategy = DamageFirstAttackAI;
		elseif abilityUseType == 'Attack_Range' then
			args.NoSingleIndirectAttack = ability.Target ~= 'EmptyGround' and ability.Target ~= 'Self';	-- 빈 땅에 쓰는 어빌리티는 간접공격일 수 밖에 없음.
			moveAI = 'AttackMove_Aggressive_Force';
			actionAI.Strategy = NormalRangedAbilityActionAI;
			if ability.Target == 'Ground' and ability.HitRateType == 'Force' then
				aiConfig.NoIndirect = true;
			end
		elseif ability.HitRateType == 'Force' then
			moveAI = 'AttackMove_Aggressive_Force';
		end
	elseif ability.Type == 'Assist' or ability.Type == 'Heal' then
		actionAI.Strategy = CommonSupportAI;
		actionAI.Target = 'Assist';
		args.RecoveryRatio = GetInstantProperty(self, 'RecoveryRatio') or 0.25;
	end
	
	return GeneralAI(self, filteredAbilities, moveAI, {actionAI}, aiConfig, args);
end

function GetAbilityAIFunction(ability, self, abilities, args, aiConfig)
	local predefined = _G['AbilityAI_' .. ability.name];
	if predefined then
		-- 어빌리티별 AI특수화
		return predefined(ability, self, abilities, args, aiConfig);
	end
	return GetAbilityAIFunction_Normal(ability, self, abilities, args, aiConfig);
end

GrenadePreCancelRatio = {
	Safty = 50,
	Easy = 40,
	Normal = 30,
	Hard = 20,
	Merciless = 10
}
function GetAttackGrenadeAI(ability, self, abilities, args, aiConfig)
	-- 처음 던지려는 수류탄은 일정 확률로 안 쓰고 넘어감
	if not GetInstantProperty(self, 'EnableGrenadeTurn') then
		SetInstantProperty(self, 'EnableGrenadeTurn', true);
		if RandomTest(75) then
			return nil, nil, nil;
		end
	end
	if (GetInstantProperty(self, 'LastGrenadeUsedTurn') or -2) + 2 >= self.TurnPlayed then
		return nil, nil, nil;
	end
	
	local mission = GetMission(self);
	local preCancelRatio = GrenadePreCancelRatio[mission.DifficultyGrade];
	if not args.DebugInfoEnabled and GetInstantProperty(self, 'FirstGrenadeTestPassed') == nil then
		SetInstantProperty(self, 'FirstGrenadeTestPassed', true);
		preCancelRatio = preCancelRatio * 2;
	end
	
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	
	-- 선확률 처리
	if #filteredAbilities > 1 and RandomTest(preCancelRatio) then	-- 일정 확률로 그냥 안씀
		return nil, nil, nil;
	end
	
	local selAbil, pos, debugInfo, bestScore = GeneralAI(self, filteredAbilities, function(self, adb, args)
		if not adb.Coverable then
			return -9999;
		end
		
		local score = -1;
		adb.ForeachAttackInfo(function (attackInfo)
			if not args.AllowObstacle and attackInfo.Obstacle then
				return;
			end
			-- 두명 이상을 맞출 수 있어야함
			if not args.AllowGrenadeOneTarget and attackInfo.HitCount <= 1 then
				return;
			end
			
			local avgDamage = attackInfo.Damage / #attackInfo.ApplyTargets;
			local s = attackInfo.HitCount * 500;
			for i, obj in ipairs(attackInfo.ApplyTargets) do
				if obj.HP < avgDamage then
					s = s + 10000;
				end
			end
			if s > score then
				score = s;
			end
		end);
		
		if score < 0 then
			return nil, nil, nil;
		end
		
		return MoveAIGeneral(self, adb, args) + score;
	end, {{Strategy = function (self, adb, args)
		if not args.AllowObstacle and adb.ObstacleShot then
			return -5378;
		else
			return adb.Damage;
		end
	end, Target = 'Attack'}}, aiConfig, args);
	if selAbil == nil then
		return nil, nil, nil;
	end
	
	if ability ~= selAbil and bestScore > 10000 and RandomTest(50) then	-- 치명적 공격이면 50% 확률로 봐줌 ㅇㅇ
		return nil, nil, nil;
	end
	if ability == selAbil then
		SetInstantProperty(self, 'LastGrenadeUsedTurn', self.TurnPlayed);
	end
	return selAbil, pos, debugInfo;
end

function GetDebuffGrenadeAI(ability, self, abilities, args, aiConfig)
	-- 처음 던지려는 수류탄은 일정 확률로 안 쓰고 넘어감
	if not GetInstantProperty(self, 'EnableGrenadeTurn') then
		SetInstantProperty(self, 'EnableGrenadeTurn', true);
		if RandomTest(75) then
			return nil, nil, nil;
		end
	end
	if (GetInstantProperty(self, 'LastGrenadeUsedTurn') or -2) + 2 >= self.TurnPlayed then
		return nil, nil, nil;
	end
	
	local mission = GetMission(self);
	local preCancelRatio = GrenadePreCancelRatio[mission.DifficultyGrade];
	if not args.DebugInfoEnabled and GetInstantProperty(self, 'FirstGrenadeTestPassed') == nil then
		SetInstantProperty(self, 'FirstGrenadeTestPassed', true);
		preCancelRatio = preCancelRatio * 2;
	end
	
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	
	-- 선확률 처리
	if #filteredAbilities > 1 and RandomTest(preCancelRatio) then	-- 일정 확률로 그냥 안씀
		return nil, nil, nil;
	end
	
	local testBuffName = ability.ApplyTargetBuff.name;
	
	if #filteredAbilities > 1 then
		local allUnit = GetAllUnitInSight(self, true);
		local allEnemies = table.filter(allUnit, function(unit)
			return self ~= unit and IsEnemy(self, unit);
		end);
		local limitedPositions = {};
		for i, enemy in ipairs(allEnemies) do
			if GetDistanceFromObjectToObject(self, enemy) < 15 then		-- 근처 15 칸으로 선 제한
				table.append(limitedPositions, CalculateRange(enemy, ability.ApplyRange, GetPosition(enemy)));
			end
		end
		aiConfig.LimitedUseablePosition = limitedPositions;
	end	
	
	local selAbil, pos, debugInfo, bestScore = GeneralAI(self, filteredAbilities, function(self, adb, args)
		if not adb.Coverable then
			return -9999;
		end
		
		local score = -1;
		adb.ForeachActionInfo(function (actionInfo)
			-- 아군 적용 시 제외
			local invalidApplyTargets = table.filter(actionInfo.ApplyTargets, function(o)
				return IsTeamOrAlly(self, o);
			end);
			if #invalidApplyTargets > 0 then
				return;
			end
			
			local validApplyTargets = table.filter(actionInfo.ApplyTargets, function(o)
				return IsEnemy(self, o) and GetBuff(o, testBuffName) == nil;
			end);
			local hitCount = #validApplyTargets;
			-- 두명 이상을 맞출 수 있어야함
			if not args.AllowGrenadeOneTarget and hitCount <= 1 then
				return;
			end
			
			local s = hitCount * 500;
			if s > score then
				score = s;
			end
		end);
		
		if score < 0 then
			return nil, nil, nil;
		end
		
		return MoveAIGeneral(self, adb, args) + score;
	end, {{Strategy = function (self, adb, args)
		-- 아군 적용 시 제외
		local invalidApplyTargets = table.filter(adb.ApplyTargets, function(o)
			return IsTeamOrAlly(self, o);
		end);
		if #invalidApplyTargets > 0 then
			return -9999;
		end
		
		local validApplyTargets = table.filter(adb.ApplyTargets, function(o)
			return IsEnemy(self, o) and GetBuff(o, testBuffName) == nil;
		end);
		local hitCount = #validApplyTargets;
		-- 두명 이상을 맞출 수 있어야함
		if not args.AllowGrenadeOneTarget and hitCount <= 1 then
			return -9999;
		end
		
		return hitCount * 500;
	end, Target = 'Assist'}}, aiConfig, args);
	if selAbil == nil then
		return nil, nil, nil;
	end
	
	if ability ~= selAbil then
		return nil, nil, nil;
	end
	if ability == selAbil then
		SetInstantProperty(self, 'LastGrenadeUsedTurn', self.TurnPlayed);
	end
	return selAbil, pos, debugInfo;
end

function GetAssistBuffRangeAI(ability, self, abilities, args, aiConfig)
	if GetBuff(self, ability.ApplyTargetBuff.name) ~= nil and RandomTest(50) then
		-- 내가 이미 ApplyTargetBuff에 걸려있으면 50% 확률로 안씀
		return nil, nil, nil;
	end
	
	local filteredAbilities = table.filter(abilities, function(ab) return ab.name == 'Move' or ab == ability; end);
	return GeneralAI(self, filteredAbilities, function(self, adb, args)
		local effectiveCount = 0;
		adb.ForeachActionInfo(function(actionInfo)
			effectiveCount = math.max(effectiveCount, table.count(actionInfo.ApplyTargets, function (obj) return not BuffImmunityTest(ability.ApplyTargetBuff, obj) and GetBuff(obj, ability.ApplyTargetBuff.name) == nil; end));
		end);
		if effectiveCount <= 1 then
			return -9998;
		end
		
		return MoveAIGeneral(self, adb, args, {MoveDistanceWeight = 5, AllyDensityWeight = 20, CoverScoreMultiplier = 1}) + effectiveCount * 80;
	end, {{Target = 'Assist', Strategy = MakeNormalAbilityUseAI(ability)}}, aiConfig, args);
end

function GetTeamHate(aiArgs, team)
	local teamHate = SafeIndex(aiArgs, 'TeamHate', 1, 'Entry');
	if teamHate == nil then
		return 0;
	end
	
	for _, hateEntry in ipairs(teamHate) do
		if hateEntry.Team == team then
			return hateEntry.Value;
		end
	end
	return 0;
end

function GeneralAbilityWithMoveAI(ability, self, abilities, args, aiConfig)
	local filteredAbilities = table.filter(abilities, function(ab) return ab.Type == 'Move' or ab == ability; end);
	
	local canMove = false;
	for i, ability in ipairs(filteredAbilities) do
		if ability.Type == 'Move' then
			canMove = true;
			break;
		end
	end
	local hateRatio = args.HateRatio or 1;
	local debugInfoM
	local subPos = GetPosition(self);
	if canMove then
		local configCopy = table.deepcopy(aiConfig);
		configCopy.FullMove = true;
		configCopy.ActionWithMove = true;
		configCopy.UseSightSupport = false;
		local toPos, score, debugInfo = FindAIMovePosition(self, filteredAbilities, function (self, adb, args)
			if not adb.PureAttackable then
				return -9999;
			end
			
			local score = 0;
			if adb.TargetAttackable then
				score = 1000;
			end
			
			local scoreRatio = 0;
			score = score + adb.MaxActionInfoScore(function(actionInfo)
				scoreRatio = math.max(scoreRatio, GetTargetScoreRatio(self, actionInfo.Object));
				return (actionInfo.Accuracy * 100) + GetHate(self, actionInfo.Object) * hateRatio + GetTeamHate(args, GetTeam(actionInfo.Object));
			end);
			
			local finalRatio = 1;
			if scoreRatio > 0 then
				finalRatio = scoreRatio;
			end
			
			return (MoveAIGeneral(self, adb, args, {Melee = true}) + score) * finalRatio;
		end, configCopy, args);
		if toPos == nil or score <= 0 then
			return nil, nil, nil;
		end
		subPos = toPos;
		debugInfoM = debugInfo;
	end
	
	-- 이동할 위치로 캐릭터를 임시로 옮겨놓고 공격 테스팅을 할거임
	local originalPos = GetPosition(self);
	SetPosition(self, subPos);
	local abil, pos, debugInfoA, score = FindAIMainAction(self, {ability}, {{Strategy = function (self, adb, args)
		if adb.ObstacleShot then
			return -5378;
		elseif adb.IsTarget then
			return 20 + adb.Hate * hateRatio + GetTeamHate(args, GetTeam(adb.Object));
		else
			return math.random(1, 10) + adb.Hate * hateRatio + GetTeamHate(args, GetTeam(adb.Object));
		end
	end, Target = 'Attack'}}, aiConfig, args);
	SetPosition(self, originalPos);
	
	local debugInfo = nil;
	if args.DebugInfoEnabled then
		debugInfo = table.append(debugInfoM, debugInfoA);
	end
	return abil, pos, debugInfo, {subPos};
end
-------------- 몬스터 AI --------------
function CalculateMonsterState(self, monCls, args)
	if monCls == nil then
		return nil;
	end
	if GetWithoutError(monCls, 'StateDecider') then
		return monCls.StateDecider(self, monCls, args);
	end
	return MonsterStateDecider_Base(self, monCls, args);
end
function MonsterStateDecider_Base(self, monCls, args)
	if self.HP / self.MaxHP < (SafeIndex(monCls, 'RecoveryRatio') or 0.33) and GetWithoutError(monCls.AbilityPriority, 'Danger') ~= nil then
		return 'Danger';
	end
	if ( GetBuff(self, 'Berserker') ~= nil or self.HP / self.MaxHP < 0.75 ) and GetWithoutError(monCls.AbilityPriority, 'Rage') ~= nil then
		return 'Rage';
	end
	return 'Normal';
end
function MonsterStateDecider_Mon_Beast_Bat_Wind_Challenger(self, monCls, args)
	local mode = (function()
	if self.HP / self.MaxHP < (SafeIndex(monCls, 'RecoveryRatio') or 0.33) and GetWithoutError(monCls.AbilityPriority, 'Danger') ~= nil then
		return 'Danger';
	end
	if ( GetBuff(self, 'Berserker') ~= nil or self.HP / self.MaxHP < 0.75 ) and GetWithoutError(monCls.AbilityPriority, 'Rage') ~= nil then
		return 'Rage';
	end
	if args.SneakMode then
		return 'Sneak';
	else
		return 'Normal';
	end	
	end)();
	return mode;
end
function IsAIAbility(ability)
	if ability.Type == 'Move' or ability.Target == 'Interaction' or ability.Target == 'InteractionArea' then
		if ability.name == 'Fueling' then
			return true;
		else
			return false;
		end
	end
	return true;
end
function CalculateIntendAbility(self, abilities, args)
	local intendAbility = {};
	local monType = GetInstantProperty(self, 'MonsterType');
	local monCls = monType ~= nil and GetClassList('Monster')[monType] or nil;
	local scoreFunc = function (d) return d.Priority; end;
	
	if monCls == nil then
		local rosterType = GetInstantProperty(self, 'RosterType');
		local rosterCls = rosterType ~= nil and GetClassList('Pc')[rosterType] or nil;
		if rosterCls then
			monCls = SafeIndex(rosterCls, 'EnableJobs', self.Job.name);
		end
	end
	
	local monsterState = CalculateMonsterState(self, monCls, args);
	local abilityPriorityAffectors = SafeIndex(monCls, 'AbilityPriority', monsterState);
	for i, ability in ipairs(abilities) do
		local pr = (function()
			if not IsAIAbility(ability) then
				return nil;
			end
			
			local priority = ability:GetPriority(self) - ability.PriorityDecay;
			
			-- 몬스터 상태에 따른 어빌리티 선호도 적용
			if monCls == nil or monsterState == nil then
				return priority;
			end
			if abilityPriorityAffectors == nil then
				return priority;
			end
			for i, affector in ipairs(abilityPriorityAffectors) do
				local abilityAttribute = ability[affector.Mode];
				if abilityAttribute then
					if abilityAttribute == affector.Target then
						if affector.Priority == -1 then	-- Terminator
							return -9999;
						end
						priority = priority + affector.Priority;
						break;
					end
				end
			end
			return priority;
		end)();
		if pr and pr > -5000 then	-- 하드리밋
			table.bininsert(intendAbility, {Priority = pr, Ability = ability}, scoreFunc, true);
		end
	end
	local ret = table.map(intendAbility, function(d) return d.Ability.name; end);
	LogAndPrint('CalculateIntendAbility', ret);
	return ret;
end
function NormalMonsterActionBase(self, adb, args)
	-- 아무 행동을 하지 않는것보다는 아무개 행동이라도 하게 하려고...
	return math.random(1, 5);
end
function ApplyAbilityAIArg(argsCopy, config, monCls, ability)
	if ability then
		local selfArg = GetWithoutError(ability, 'AIArg');
		if selfArg then
			for key, value in pairs(selfArg) do
				argsCopy[key] = value;
			end
		end
		local selfConfig = GetWithoutError(ability, 'AIConfig');
		if selfConfig then
			for key, value in pairs(selfConfig) do
				config[key] = value;
			end
		end
	end
	for i, applyType in ipairs({'Base', ability.name}) do
		local abilityAIArg = SafeIndex(monCls, 'AbilityAIArg', applyType);
		if abilityAIArg then
			for key, value in pairs(abilityAIArg) do
				if type(value) == 'userdata' then
					value = ClassToTable(value);
				end
				if key ~= 'name' then
					argsCopy[key] = value;
				end
			end
		end
	end
end

function AI_Monster_Normal(self, abilities, args, startTime)
	local isRelationReversed = GetBuffStatus(self, 'ReverseRelation', 'Or');
	local myTeam = GetTeam(self);
	if isRelationReversed then
		for _, buff in ipairs(GetBuffList(self) or {}) do
			if GetWithoutError(buff, 'ReverseRelation') then
				self.Team = SafeIndex(GetBuffGiver(buff), 'Team') or myTeam;
				break;
			end
		end
	end
	local argsb = args;
	args = table.deepcopy(args);
	local startTime = startTime or os.clock();
	local allUnit = GetAllUnitInSight(self, true);
	local allEnemies = table.filter(allUnit, function(unit)
		return IsEnemy(self, unit);
	end);
	local fullMove = #allEnemies == 0;
	local hateTarget = GetHateTarget(self);
	local selfKey = GetObjKey(self);
	local mission = GetMission(self);
	
	local monType = FindBaseMonsterTypeWithCache(self);
	local monCls = monType ~= nil and GetClassList('Monster')[monType] or nil;
	local noTimeLimit = GetInstantProperty(self, 'NoAITimeLimit');
	ConfigureConditionalAIArgs(self, monCls, args);
	
	local rallyApplyTest = #allEnemies == 0 or args.AlwaysApplyRallyPoint;
	-- 랠리 정보 적용
	local rallyPoints = {};
	if rallyApplyTest then
		local rallyPoint = GetPositionFromPositionIndicator(GetMissionID(self), args.RallyPoint);
		if not IsInvalidPosition(rallyPoint) then
			args.RallyPointFinal = rallyPoint;
			args.RallyPoint = GetMovePosition(self, rallyPoint, 0, fullMove);
			args.RallyReference = GetDistance3D(GetPosition(self), args.RallyPoint);
			args.RallyMethod = 'DirectDistance';
		end
		local rallyPoint2 = GetPositionFromPositionIndicator(GetMissionID(self), args.RallyPoint2);
		if not IsInvalidPosition(rallyPoint2) then
			args.RallyPointFinal2 = rallyPoint2;
			args.RallyPoint2 = GetMovePosition(self, rallyPoint2, 0, fullMove);
			args.RallyReference2 = GetDistance3D(GetPosition(self), args.RallyPoint2);
			args.RallyMethod2 = 'DirectDistance';
		end
		local aiSession = GetAISession(mission, GetTeam(self));
		local supportTargets = aiSession:GetDetectingSupportTargets();
		if #supportTargets > 0 then
			local supportTarget = Linq.new(supportTargets)
				:where(function(o) return o.HP > 0; end)	-- 살아있는 대상만 적용
				:orderByAscending(function(o) return GetDistance3D(GetPosition(o), GetPosition(self)); end)
				:first();
			if not GetInstantProperty(self, 'NoSupportDetectingAlert') and supportTarget and supportTarget ~= self then
				args.RallyPointFinalSupport = GetPosition(supportTarget)
				args.RallyPointSupport = GetMovePosition(self, GetPosition(supportTarget), 0, true);
				args.RallyPowerSupport = 25;
				args.RallyRangeSupport = 8;
				args.RallyMethodSupport = 'DirectDistance';
				args.RallyReferenceSupport = GetDistance3D(GetPosition(self), GetPosition(supportTarget));
			end
		end
		for _, rallyKey in ipairs({'', '2', 'Support'}) do
			if not IsInvalidPosition(args['RallyPoint' .. rallyKey]) then
				table.insert(rallyPoints, {
					Position = args['RallyPoint' .. rallyKey],
					Range = args['RallyRange' .. rallyKey] or 4,
					Reference = args['RallyReference' .. rallyKey] or 0,
					Power = args['RallyPower' .. rallyKey] or 50,
					Method = args['RallyMethod' .. rallyKey] or 'DirectDistance',
					FinalPosition = args['RallyPointFinal' .. rallyKey],
				});
			end
			args['RallyPoint' .. rallyKey] = nil;
			args['RallyRange' .. rallyKey] = nil;
			args['RallyReference' .. rallyKey] = nil;
			args['RallyPower' .. rallyKey] = nil;
			args['RallyMethod' .. rallyKey] = nil;
			args['RallyPointFinal' .. rallyKey] = nil;
		end
	end
	args.RallyPoints = rallyPoints;
	
	-- 자동전투 전략수치 적용
	ManageAutoPlayStrategy(self, args);
	
	if #allEnemies == 0 and args.ActiveOnlyEnemyInSight then
		if isRelationReversed then
			self.Team = myTeam;
		end
		return nil;
	end
	
	-- 최소 명중률 수치 적용
	local minAccuracyHanger = {};
	local MinAccuracyAdder = function(target, accuracy)
		minAccuracyHanger[target] = accuracy;
		if args.MinAccuracy == nil then
			args.MinAccuracy = accuracy;
		elseif args.MinAccuracy < accuracy then
			args.MinAccuracy = accuracy;
		end
	end
	local MinAccuracyRemover = function(target)
		if args.MinAccuracy == nil then
			return;
		end
		local accuracy = minAccuracyHanger[target] or 0;
		minAccuracyHanger[target] = nil;
		if args.MinAccuracy > accuracy then
			return;
		end
		local maxAcc = nil;
		for hanger, accuracy in pairs(minAccuracyHanger) do
			if maxAcc ==  nil then
				maxAcc = accuracy;
			elseif maxAcc < accuracy then
				maxAcc = accuracy;
			end
		end
		args.MinAccuracy = maxAcc;
	end
	if GetInstantProperty(self, 'HasOverwatch') then
		MinAccuracyAdder('Overwatch', 30);
	end
	if GetInstantProperty(self, 'HasSetTarget') then
		MinAccuracyAdder('SetTaret', 30);
	end
	if GetInstantProperty(self, 'HasAiming') and not GetBuff(self, 'TargetChecking') then
		MinAccuracyAdder('Aiming', 50);
	end
	
	-- AI 연속 플레이보정
	local noAttack = false;
	local aiCorrection = mission.AICorrection;
	if aiCorrection and aiCorrection.AttackPassEnabled then
		local recitalPlayCount = mission.Instance.AIState.RecitalPlayCount;
		if GetInstantProperty(self, 'AttackPassTriggered') or (not self.TurnState.Moved and recitalPlayCount > aiCorrection.AttackPassCool and RandomTest(aiCorrection.AttackPassChance)) then
			SetInstantProperty(self, 'AttackPassTriggered', true);
			noAttack = true;
		end
	end
	if noAttack then
		abilities = table.filter(abilities, function(a) return a.Type ~= 'Attack'; end);
	end
	
	local intendAbilities = GetInstantProperty(self, 'IntendAbilities');
	args.AllowObstacle = GetInstantProperty(self, 'AI_AllowObstacle');
	local reload = true;
	if intendAbilities == nil then
		intendAbilities = CalculateIntendAbility(self, abilities, args);
		reload = false;
		SetInstantProperty(self, 'IntendAbilities', intendAbilities);
		args.AllowObstacle = RandomTest(30);		-- 장애물 공격 확률
		SetInstantProperty(self, 'AI_AllowObstacle', args.AllowObstacle);
	end
	
	for i, abilityName in ipairs(intendAbilities) do
		local ability = GetAbilityObject(self, abilityName);
		local argsCopy = table.deepcopy(args);
		local config = {FullMove = fullMove, UseSightSupport = true, NoTimeLimit = noTimeLimit, Target = hateTarget, NoPreemptiveAttack = args.NoPreemptiveAttack};
		local localTime = os.clock();
		ApplyAbilityAIArg(argsCopy, config, monCls, ability);
		local abil, pos, debugInfo, subPositions = ability:AI(self, abilities, argsCopy, config);
		if abil == 'Wait' then
			return nil, nil, nil;	-- 대기
		end
		if pos ~= nil then
			if SafeIndex(abil, 'name') == 'Move' or ability.AbilityWithMove then
				RecordAIStat(mission, monType, abilityName, os.clock() - localTime);
			end
			LogAndPrint('AI_Monster_Normal', selfKey, abilityName, 'Success', SafeIndex(abil, 'name'), os.clock() - startTime);
			if abil.Type == 'Move' then
				SetInstantProperty(self, 'IntendAbilities', {abilityName});
			else
				if not args.DebugInfoEnabled then
					abil.PriorityDecay = abil.PriorityDecay + math.random(5, 10);
				end
				SetInstantProperty(self, 'IntendAbilities', GetInstantProperty(self, 'NextIntendAbilities'));
				SetInstantProperty(self, 'NextIntendAbilities', nil);
			end
			if abil.Type == 'Attack' then
				SetInstantProperty(self, 'DetectingSupportTarget', nil);
				mission.Instance.AIState.RecitalPlayCount = mission.Instance.AIState.RecitalPlayCount + 1;
			elseif abil.Type ~= 'Move' then
				mission.Instance.AIState.RecitalPlayCount = 1;
			end
			if isRelationReversed then
				self.Team = myTeam;
			end
			return abil, pos, debugInfo, subPositions;
		end
		LogAndPrint('AI_Monster_Normal', selfKey, abilityName, 'Failed');
		if abilityName == 'Overwatch' then
			-- 이미 경계사격 AI를 돌려버렸으니 이후로는 경계 없는 것으로 간주
			MinAccuracyRemover('Overwatch');
		elseif abilityName == 'SetTarget' then
			MinAccuracyRemover('SetTarget');
		elseif abilityName == 'Aiming' then
			MinAccuracyRemover('Aiming');
		end
	end
	SetInstantProperty(self, 'IntendAbilities', nil);
	if reload then
		if isRelationReversed then
			self.Team = myTeam;
		end
		return AI_Monster_Normal(self, abilities, argsb);
	else
		local move = table.filter(abilities, function(ab) return ab.Type == 'Move'; end)
		if #move == 0 then
			if isRelationReversed then
				self.Team = myTeam;
			end
			return nil, nil, nil, nil;
		else
			local moveAbil = move[1];
			LogAndPrint('AI_Monster_Normal', selfKey, 'Use Move', os.clock() - startTime, args);
			local localTime = os.clock();
			local argsCopy = table.deepcopy(args);
			local config = {FullMove = true, UseSightSupport = true, Target = hateTarget, NoPreemptiveAttack = args.NoPreemptiveAttack};
			ApplyAbilityAIArg(argsCopy, config, monCls, move[1]);
			local result = {moveAbil:AI(self, abilities, argsCopy, config)}
			if isRelationReversed then
				self.Team = myTeam;
			end
			if SafeIndex(result, 1) == nil then
				-- MinRallyProgress 조건을 만족시키지 못한 경우 0이하로 세팅 해서 한번더 탐색
				argsCopy = table.deepcopy(args);
				argsCopy.MinRallyProgress = math.min(0, argsCopy.MinRallyProgress or 0);
				result = {moveAbil:AI(self, abilities, argsCopy, config)};
			end
			RecordAIStat(mission, monType, 'Move', os.clock() - localTime);
			return unpack(result);
		end
	end
end

function AI_Monster_Aggressive(self, abilities, args)
	local startTime = os.clock();
	local allUnit = GetAllUnitInSight(self);
	local allEnemies = table.filter(allUnit, function(unit)
		return IsEnemy(self, unit);
	end);
	
	local localAISession = GetInstantProperty(self, 'LocalAISession') or {};
	
	local mid = GetMissionID(self);
	local team = GetTeam(self);
	local aiSession = GetAISession(self, team);
	aiSession:UpdateSearchKB(self);	-- 자신은 매턴 갱신하고 
	
	local moveTarget = nil;
	local noThinkMove = true;
	
	if #allEnemies > 0 then
		-- 자기시야로 다시 체크
		allUnit = GetAllUnitInSight(self, true);
		local localEnemies = table.filter(allUnit, function(unit) return IsEnemy(self, unit); end);
		if #localEnemies > 0 then		-- 자기 시야안에 적이 있음 => 일반 AI로
			return AI_Monster_Normal(self, abilities, args, startTime);
		end
		
		-- 이동 대상을 가장 가까운 적으로 설정
		local mission = GetMission(self);
		local myPos = GetPosition(self);
		moveTarget = Linq.new(allEnemies)
			:orderBy(function(o) return GetDistance3D(myPos, GetPosition(o)); end)
			:select(function(o) return GetPosition(o) end)
			:first();
		if GetDistance3D(GetPosition(self), moveTarget) < 20 then
			noThinkMove = false;
		end
	else
		-- 시야에 적없음. 이동 대상을 탐색 위치로 설정
		-- 남들은 새로운 위치를 뽑을때마다 갱신하자.	(성능이슈)
		if localAISession.SearchPoint == nil or not aiSession:IsPositionNeedSearch(localAISession.SearchPoint) then
			local teamCount = GetTeamCount(mid, team, true);
			for i = 1, teamCount do
				local obj = GetTeamUnitByIndex(mid, team, i, true);
				aiSession:UpdateSearchKB(obj);
			end
			localAISession.SearchPoint = aiSession:PickOutSearchPoint(self);
			SetInstantProperty(self, 'LocalAISession', localAISession);
		end
		moveTarget = localAISession.SearchPoint;
	end
	
	if moveTarget ~= nil and not IsInvalidPosition(moveTarget) then		
		-- 이동 거리 기반으로 이동 대상 재설정
		moveTarget = GetMovePosition(self, moveTarget, 0, false);
		if noThinkMove then
			local moveAbility = nil;
			local standByAbility = nil;
			for i, ability in ipairs(abilities) do	
				if ability.name == 'Move' then
					moveAbility = ability;
				elseif ability.name == 'StandBy' then
					standByAbility = ability;
				end
			end
			if moveAbility then
				return moveAbility, moveTarget, {{Position = moveTarget, Score = 100}};
			elseif standByAbility then
				return standByAbility, GetPosition(self), {};
			else
				return nil;
			end
		end
	end
	local argsCopy = table.deepcopy(args);
	argsCopy.NoConceal = true;
	if moveTarget and not IsInvalidPosition(moveTarget) then
		ForceNewInsert(argsCopy, 'AdditionalMoveScoreFunction', function(self, adb, args)
			if adb.EnemyCount > 0 then
				return 0;
			else
				return - GetDistance3D(moveTarget, adb.Position) * 50;
			end
		end);
	end
	
	return AI_Monster_Normal(self, abilities, argsCopy, startTime);
end

function AI_Monster_Passive(self, abilities, args)
	local startTime = os.clock();
	local team = GetTeam(self);
	local aiSession = GetAISession(self, team);
	
	
	local allEnemies = table.filter(GetAllUnitInSight(self, true), function (o) return IsEnemy(self, o); end);
	if #allEnemies == 0 then
		local tempObjects = aiSession:GetTemporalSightObjects();
		if not table.exist(tempObjects, function(o) return GetDistanceFromObjectToObject(self, o) < self.SightRange; end) then
			return nil;
		end
	end
	
	return AI_Monster_Normal(self, abilities, args, startTime);
end

function AI_Monster_Beast(self, abilities, args)

	local startTime = os.clock();
	local argsCopy = table.deepcopy(args);
	local master = GetUnit(self, GetInstantProperty(self, 'SummonMaster'));
	
	if master then
		local basePosition = GetPosition(master);
		
		local from = GetOffsetPosition(GetMission(self), basePosition, Position(-10, -10, 0));
		local to = GetOffsetPosition(GetMission(self), basePosition, Position(10, 10, 0));
		ForceNewIndex(argsCopy, 'ActivityArea', 1, 'From', 1, from);
		ForceNewIndex(argsCopy, 'ActivityArea', 1, 'To', 1, to);
	end
	
	return AI_Monster_Normal(self, abilities, argsCopy, startTime);
end

function AI_Monster_Sneak(self, abilities, args)
	local argsCopy = table.deepcopy(args);
	argsCopy.SneakMode = true;
	
	if self.Cloaking then
		abilities = table.filter(abilities, function(abil) return abil.Type ~= 'Attack' end);
		ForceNewInsert(argsCopy, 'AdditionalMoveScoreFunction', function(self, adb, args)
			if not adb.SneakPath then
				return -9992;
			end
			return adb.MoveDistance + adb.MinEnemyDistance * 10;
		end);
	end
	return AI_Monster_Normal(self, abilities, argsCopy);
end

function ManageAutoPlayStrategy(self, args)
	if args.AutoPlayStrategy == nil then
		return;
	end
	local autoPlaySession = GetInstantProperty(self, 'AutoPlaySession') or {};
	local sessionUpdated = false;
	if args.AutoPlayStrategy ~= 'Hold' then
		sessionUpdated = true;
		autoPlaySession.StationBasePosition = nil;
	end
	if args.AutoPlayStrategy == 'Battle' or args.AutoPlayStrategy == 'Defensive' then
		if args.RallyPoints == nil then
			args.RallyPoints = {};
		end
		local mainHeros = {};
		local rallyPowerSum = 40;	-- 토탈 40 정도로 끌어당기자
		local mid = GetMissionID(self);
		local team = GetTeam(self);
		local teamCount = GetTeamCount(mid, team, true);
		for i = 1, teamCount do
			local obj = GetTeamUnitByIndex(mid, team, i, true);
			if not GetInstantProperty(obj, 'AutoPlayable') then
				table.insert(mainHeros, obj);
			end
		end
		local rallyPowerPerHero = rallyPowerSum / #mainHeros;
		for _, obj in ipairs(mainHeros) do
			table.insert(args.RallyPoints, {
				Position = GetMovePosition(self, GetPosition(obj), 0, true),
				Range = 5,
				Reference = GetDistance3D(GetPosition(self), GetPosition(obj)),
				Method = 'DirectDistance',
				Power = rallyPowerPerHero,
				FinalPosition = GetPosition(obj)
			});
		end
		if args.AutoPlayStrategy == 'Defensive' then
			args.NoPreemptiveAttack = true;
		end
	elseif args.AutoPlayStrategy == 'Hold' then
		local basePosition = autoPlaySession.StationBasePosition;
		if basePosition == nil then
			basePosition = GetPosition(self);
			autoPlaySession.StationBasePosition = basePosition;
			sessionUpdated = true;
		end
		local from = GetOffsetPosition(GetMission(self), basePosition, Position(-5, -5, 0));
		local to = GetOffsetPosition(GetMission(self), basePosition, Position(5, 5, 0));
		ForceNewIndex(args, 'ActivityArea', 1, 'From', 1, from);
		ForceNewIndex(args, 'ActivityArea', 1, 'To', 1, to);
		args.ActiveOnlyEnemyInSight = true;
	elseif args.AutoPlayStrategy == 'Search' then
		args.NoConceal = true;
		local mid = GetMissionID(self);
		local team = GetTeam(self);
		local aiSession = GetAISession(self, team);
		local teamCount = GetTeamCount(mid, team, true);
		for i = 1, teamCount do
			local obj = GetTeamUnitByIndex(mid, team, i, true);
			aiSession:UpdateSearchKB(obj);
		end
		if autoPlaySession.SearchPoint == nil or not aiSession:IsPositionNeedSearch(autoPlaySession.SearchPoint) then
			autoPlaySession.SearchPoint = aiSession:PickOutSearchPoint(self);
			sessionUpdated = true;
		end
		if IsInvalidPosition(autoPlaySession.SearchPoint) then
			-- 탐색 위치 검색 실패
			-- 주둔으로 돌리자
			args.AutoPlayStrategy = 'Hold';
			ManageAutoPlayStrategy(self, args);
			return;
		end
		local moveTarget = GetMovePosition(self, autoPlaySession.SearchPoint, 0, true);
		ForceNewInsert(args, 'AdditionalMoveScoreFunction', function(self, adb, args)
			if adb.EnemyCount > 0 then
				return 0;
			end
			return - GetDistance3D(moveTarget, adb.Position) * 50;
		end);
	end
	
	if sessionUpdated then
		SetInstantProperty(self, 'AutoPlaySession', autoPlaySession);
	end
end