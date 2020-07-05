function ForceSample(force, totalDistance, elapsedTime)
	local rotationX = math.sin(math.rad(-elapsedTime * 400));
	local rotationY = math.cos(math.rad(-elapsedTime * 400));
	
	if elapsedTime <= force.Wait then
		return force.Radius*rotationX, force.Radius*rotationY, math.min(totalDistance/3, elapsedTime * 500);
	else
		elapsedTime = elapsedTime - force.Wait;
		local radius = math.max((1-elapsedTime)*force.Radius, 10);
		return radius * rotationX, radius * rotationY, elapsedTime * 500 + totalDistance/3;
	end
end
function ForceStraight(force, totalDistance, elapsedTime)
	return 0, 0, elapsedTime * force.Speed;
end
function ForceSpear(force, totalDistance, elapsedTime)
	local speed = elapsedTime * elapsedTime * force.Speed;
	return 0, 0, speed;
end