
function AfterCraftBoardInitializer(recipeCls, updater)
	local boardCls = recipeCls.MaterialBoard;
	
	updater('Board/BoardType', boardCls.name);
	
	local slotTypes = GetClassList('SlotType');
	for slotType, cls in pairs(slotTypes) do
		if boardCls[slotType] == true then
			local picker = RandomPicker.new();
			for i, candidate in ipairs(cls.ValidSlot) do
				picker:addChoice(candidate.Probability, candidate.Type);
			end
			local chipType = picker:pick();
			updater('Board/'..slotType..'/ChipType', chipType);
		end
	end
end
--- 연구시 아이템 보상 결정 ----
function GetRewardByResearch(item, quality, production, techPoint)
	local result = {};
	local rewardList = GetExpectedRewardByResearch(item, quality, production, techPoint);
	
	local picker = RandomPicker.new();
	for i = 1, #rewardList do
		local curReward = rewardList[i];
		picker:addChoice(curReward.Probability * 100, curReward);
	end	
	
	return picker:pick();
end
----------- 분해시 아이템 결정 함수  -----------
function CalcItemResearchResult( item, quality, research, production, quantity )
	local rewards = {};
	local techPoint = GetTechPointItem(item);
	-- 획득해야할 RP --
	local acquireRP = GetResearchPointFromtechPoint(techPoint, research);
	-- 총 보상 횟수 --
	local rewardCount = GetExpectedRewardCountByResearch(quantity, techPoint);
	-- 보상받아야 할 아이템과 개수 --
	for i = 1, rewardCount do
		local rewardInfo = GetRewardByResearch(item, quality, production, techPoint);
		table.insert(rewards, { Name = rewardInfo.Name, Amount = 1 });
	end
	return acquireRP, rewards;
end
