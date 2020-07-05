-- Great 테스트
function TestPerformanceGreatType(performanceCls, effect1, effect2, effect3, effect4)
	for _, greatType in ipairs(performanceCls.Great) do
		local greatCls = GetClassList('PerformanceGreat')[greatType.Type];
		if greatCls then
			local checkFunc = _G['CheckPerformanceGreat_'..greatCls.CheckType];
			if checkFunc and checkFunc(effect1.Type, effect2.Type, effect3.Type, effect4.Type) then
				return greatCls;
			end
		end
	end
end

function CheckPerformanceGreat_AllSame(type1, type2, type3, type4)
	return type1 == type2 and type2 == type3 and type3 == type4;
end
function CheckPerformanceGreat_AllDifferent(type1, type2, type3, type4)
	return type1 ~= type2 and type1 ~= type3 and type1 ~= type4 and type2 ~= type3 and type2 ~= type4 and type3 ~= type4;
end
function CheckPerformanceGreat_TwoRepeat(type1, type2, type3, type4)
	return type1 ~= type2 and type1 == type3 and type2 == type4;
end
function CheckPerformanceGreat_ThreeUroborus(type1, type2, type3, type4)
	return type1 ~= type2 and type1 ~= type3 and type2 ~= type3 and type1 == type4;
end

function GetPerformanceEffectLv(owner)
	local effectLv = 1;
	local masteryTable = GetMastery(owner);
	-- 특성 천부적 재능
	local mastery_Genius_Leton = GetMasteryMastered(masteryTable, 'Genius_Leton');
	if mastery_Genius_Leton then
		effectLv = effectLv + mastery_Genius_Leton.ApplyAmount;
	end
	-- 특성 떠오르는 별
	local mastery_RisingStar = GetMasteryMastered(masteryTable, 'RisingStar');
	if mastery_RisingStar then
		effectLv = effectLv + mastery_RisingStar.ApplyAmount;
	end
	-- 특성 춤! 춤! 춤!
	local mastery_DanceDanceDacne = GetMasteryMastered(masteryTable, 'DanceDanceDacne');
	if mastery_DanceDanceDacne then
		effectLv = effectLv + mastery_DanceDanceDacne.ApplyAmount;
	end
	return effectLv;
end

function GetPerformanceGreatApplyDist(owner, greatCls)
	local applyDist = greatCls.ApplyAmount;
	local masteryTable = GetMastery(owner);
	-- 특성 열연
	local mastery_EnthusiasticPerformance = GetMasteryMastered(masteryTable, 'EnthusiasticPerformance');
	if mastery_EnthusiasticPerformance then
		applyDist = mastery_EnthusiasticPerformance.ApplyAmount2;
	end
	-- 특성 대성황 (열연 세트)
	local mastery_GreatSuccess = GetMasteryMastered(masteryTable, 'GreatSuccess');
	if mastery_GreatSuccess then
		applyDist = mastery_GreatSuccess.ApplyAmount;
	end
	return applyDist;
end

function GetPerformanceFinishApplyDist(owner, finishCls)
	local applyDist = finishCls.ApplyAmount;
	local masteryTable = GetMastery(owner);
	-- 특성 열연
	local mastery_EnthusiasticPerformance = GetMasteryMastered(masteryTable, 'EnthusiasticPerformance');
	if mastery_EnthusiasticPerformance then
		applyDist = mastery_EnthusiasticPerformance.ApplyAmount2;
	end
	-- 특성 대성황 (열연 세트)
	local mastery_GreatSuccess = GetMasteryMastered(masteryTable, 'GreatSuccess');
	if mastery_GreatSuccess then
		applyDist = mastery_GreatSuccess.ApplyAmount;
	end
	return applyDist;
end

function FunctionProperty_PerformanceGreatDesc(greatCls, owner)
	if not owner then
		return greatCls.Desc;
	end
	local applyDist = GetPerformanceGreatApplyDist(owner, greatCls);
	local dummyCls = WrapperObject.new(greatCls, { ApplyAmount = applyDist });
	return FormatMessageWithCustomKeywordTable(greatCls.Desc_Format, dummyCls, GetIdspace(greatCls));
end

function FunctionProperty_PerformanceFinishDesc(finishCls, owner)
	if not owner then
		return finishCls.Desc;
	end
	local applyDist = GetPerformanceFinishApplyDist(owner, finishCls);
	local dummyCls = WrapperObject.new(finishCls, { ApplyAmount = applyDist });
	return FormatMessageWithCustomKeywordTable(finishCls.Desc_Format, dummyCls, GetIdspace(finishCls));
end

function FunctionProperty_PerformanceDesc(performanceCls, owner)
	if not owner then
		return performanceCls.Desc;
	end
	return FormatMessageWithCustomKeywordTable(performanceCls.Desc_Format, performanceCls, GetIdspace(performanceCls), false, owner);
end