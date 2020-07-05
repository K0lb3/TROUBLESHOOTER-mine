-------------------------------------------------------------------------------
----                               Stage AI                                ----
-------------------------------------------------------------------------------
function StageAI_Test(self, abilities)
	--- No UsableAbility And TurnEnd ---
	if #abilities == 0 then return nil, nil; end
	--- Ability DevideGroup ---
	local ablityList = AbilityListByHierarchy(abilities);
	local move = ablityList['Move'];
	local attack = ablityList['Attack'];
	local assist = ablityList['Assist'];
	
		
	
	local nearObjects = GetNearObject(self, self.SightRange);
	local enemyList = GetObjectListByRelation(self, nearObjects, 'Enemy');

	if #enemyList > 0 and self.AttackAI ~= 'None' then
		local attackAI = _G["AI_"..self.AttackAI];
		if attackAI ~= nil then
			return attackAI(self, enemyList, abilities);
		end
	else
		-- 평화 상태일 경우 원하는 행동의 함수를 넣자.
		-- 순찰, 회복, 잠, 기타 등등 
		-- 후일 데이터 화 하자.
		return nil, nil;
	end	
end