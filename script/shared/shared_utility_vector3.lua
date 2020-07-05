vector3 = {};
vector3.__index = vector3;
function vector3.new(base)
	if base == nil then
		base = {x = 0, y = 0, z = 0};
	else
		base = {x = base.x, y = base.y, z = base.z};
	end
	setmetatable(base, vector3);
	return base;
end
function vector3.fromList(base)
	if #base == 3 then
		return vector3.new({x = base[1], y = base[2], z = base[3]});
	else
		return vector3.new();
	end
end
function vector3.length(self)
	return math.sqrt(self.x*self.x + self.y*self.y + self.z*self.z);
end
function vector3.normalize(self)
	local l = self:length();
	self.x = self.x / l;
	self.y = self.y / l;
	self.z = self.z / l;
	return self;
end
function vector3.normalizedCopy(self)
	local l = self:length();
	return vector3.new({x = self.x / l, y = self.y / l, z = self.z / l});
end
function vector3.__add(self, v)
	return vector3.new{x = self.x + v.x, y = self.y + v.y, z = self.z + v.z};
end
function vector3.__sub(self, v)
	return vector3.new{x = self.x - v.x, y = self.y - v.y, z = self.z - v.z};
end
function vector3.__mul(self, v)
	return vector3.new{x = self.x * v.x, y = self.y * v.y, z = self.z * v.z};
end
function vector3.__div(self, v)
	return vector3.new{x = self.x / v.x, y = self.y / v.y, z = self.z / v.z};
end
function vector3.dot(self, v)
	return self.x*v.x + self.y*v.y + self.z*v.z;
end
function vector3.angleWith(self, v)
	return math.acos(self:normalizedCopy():dot(v:normalizedCopy())) * 180 / math.pi;
end
function vector3.toTable(self)
	return {x = self.x, y = self.y, z = self.z};
end
function vector3.test()
	local a = vector3.fromList({1, 0, 0});
	local b = vector3.fromList({0, 1, 0});
	print((a + b):toTable().x, (a + b):toTable().y, (a + b):toTable().z, a:angleWith(b));
end