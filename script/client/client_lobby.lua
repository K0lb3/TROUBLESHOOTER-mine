---
function ClientItemCountAcquirer(inventory)
	local cache = {};
	for _, item in ipairs(inventory) do
		cache[item.name] = (cache[item.name] or 0) + item.Amount;
	end
	return function(itemName)
		return cache[itemName] or 0
	end
end