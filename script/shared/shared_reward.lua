-----------------------------------------------------
-- 아이템 드랍율.
-----------------------------------------------------
function GetMonterRewardDropRatio(target, item)
	-- 랭크별 아이템 기본 드랍율
	local result = 0;
	result = item.Rank.ItemDropRatio;
	-- 몬스터 랭크별 아이템 기본 드랍율
	local monGradeItemDropRate = GetWithoutError(target.Grade.ItemDropRatio, item.Rank.name) or 0;
	result = (target.Grade.BaseItemDropRate + result) * monGradeItemDropRate * item.Category.ItemDropRatio;
	return result;
end