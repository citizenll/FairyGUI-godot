class_name FGUIEaseManager
extends RefCounted


static func evaluate(ease_type: int, time: float, duration: float, overshoot_or_amplitude: float = 1.70158, period: float = 0.0) -> float:
	if duration <= 0.0:
		return 1.0
	var t := clampf(time / duration, 0.0, 1.0)
	match ease_type:
		FGUIEaseType.LINEAR:
			return t
		FGUIEaseType.SINE_IN:
			return 1.0 - cos(t * PI * 0.5)
		FGUIEaseType.SINE_OUT:
			return sin(t * PI * 0.5)
		FGUIEaseType.SINE_IN_OUT:
			return -0.5 * (cos(PI * t) - 1.0)
		FGUIEaseType.QUAD_IN:
			return t * t
		FGUIEaseType.QUAD_OUT:
			return -t * (t - 2.0)
		FGUIEaseType.QUAD_IN_OUT:
			t *= 2.0
			if t < 1.0:
				return 0.5 * t * t
			t -= 1.0
			return -0.5 * (t * (t - 2.0) - 1.0)
		FGUIEaseType.CUBIC_IN:
			return t * t * t
		FGUIEaseType.CUBIC_OUT:
			t -= 1.0
			return t * t * t + 1.0
		FGUIEaseType.CUBIC_IN_OUT:
			t *= 2.0
			if t < 1.0:
				return 0.5 * t * t * t
			t -= 2.0
			return 0.5 * (t * t * t + 2.0)
		FGUIEaseType.BACK_IN:
			return t * t * ((overshoot_or_amplitude + 1.0) * t - overshoot_or_amplitude)
		FGUIEaseType.BACK_OUT:
			t -= 1.0
			return t * t * ((overshoot_or_amplitude + 1.0) * t + overshoot_or_amplitude) + 1.0
		_:
			return t

