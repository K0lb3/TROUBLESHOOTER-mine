-- shop
function RandomPrice_Material(item, price)
	local result = price;
	result = math.random(result * item.Rank.RandomSellPriceRatioMin, result * item.Rank.RandomSellPriceRatioMax);
	result = math.floor(result);
	return result;
end
