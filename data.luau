local Data = {}
Data.__index = Data

local function changed(old, new)
	return old ~= new
end

local function makeProxy(self, backing, callback)
	local _writing = false
	local proxy = {}

	return setmetatable(proxy, {
		__index = function(_, k)
			return backing[k]
		end,

		__newindex = function(_, k, v)
			if _writing then
				backing[k] = v
				return
			end

			local old = backing[k]
			if not changed(old, v) then return end

			backing[k] = v
			if callback then
				_writing = true
				local ok, err = pcall(callback, self, k, v, old)
				if not ok then warn("[Data] onWrite error:", err) end
				_writing = false
			end
		end,

		__pairs = function() return next, backing, nil end,
		__ipairs = function() return ipairs(backing) end,
	})
end

function Data.new(entity, opts)
	opts = opts or {}

	local self = setmetatable({
		entity = entity,
		_public  = {},
		_private = {},
		publicCallback  = opts.publicCallback,
		privateCallback = opts.privateCallback,
	}, Data)

	if opts.publicData then
		for k, v in pairs(opts.publicData) do self._public[k] = v end
	end
	if opts.privateData then
		for k, v in pairs(opts.privateData) do self._private[k] = v end
	end

	self.public  = makeProxy(self, self._public,  function(self, k, new, old)
		if self.publicCallback then self.publicCallback(self, k, new, old) end
	end)
	self.private = makeProxy(self, self._private, function(self, k, new, old)
		if self.privateCallback then self.privateCallback(self, k, new, old) end
	end)

	return self
end

function Data:getPublicRaw(k)   return self._public[k] end
function Data:setPublicRaw(k,v) self._public[k] = v end
function Data:getPrivateRaw(k)  return self._private[k] end
function Data:setPrivateRaw(k,v) self._private[k] = v end

function Data:syncAttributes(char, keys)
	if not char then return end
	if keys then
		for _, k in ipairs(keys) do
			local v = self._public[k]
			if v ~= nil then char:SetAttribute(k, v) end
		end
	else
		for k, v in pairs(self._public) do
			char:SetAttribute(k, v)
		end
	end
end

function Data:destroy()
	self.publicCallback, self.privateCallback = nil, nil
	self.public, self.private = nil, nil
	self._public, self._private = nil, nil
	self.entity = nil
end

return Data
