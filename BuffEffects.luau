local Effects = {}

Effects.Exhaust = {
	id = "exhaust",
	type = "Debuff",
	duration = 2,
	stacking = "refresh",
	onApply = function(controller, buffData)
		controller:applyPrivateAdd(buffData, "moveSpeedMult", -0.6)
	end,
	onRemove = function(controller, buffData)
		controller:revertPrivateMods(buffData)
	end,
}

Effects.Sprint = {
	id = "sprint",
	type = "Buff",
	stacking = "refresh",
	onApply = function(controller, buffData)
		controller:applyPrivateAdd(buffData, "moveSpeedBase", 12)
	end,
	onRemove = function(controller, buffData)
		controller:revertPrivateMods(buffData)
	end,
}

return Effects
