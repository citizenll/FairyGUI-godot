class_name FGUIEaseManager
extends RefCounted

const _PI_OVER_2 := PI * 0.5
const _TWO_PI := PI * 2.0


static func evaluate(ease_type: int, time: float, duration: float, overshoot_or_amplitude: float = 1.70158, period: float = 0.0, custom_ease: FGUICustomEase = null) -> float:
	if duration <= 0.0:
		return 1.0
	time = clampf(time, 0.0, duration)
	var t := time / duration
	match ease_type:
		FGUIEaseType.LINEAR:
			return t
		FGUIEaseType.SINE_IN:
			return -cos(t * _PI_OVER_2) + 1.0
		FGUIEaseType.SINE_OUT:
			return sin(t * _PI_OVER_2)
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
		FGUIEaseType.QUART_IN:
			return t * t * t * t
		FGUIEaseType.QUART_OUT:
			t -= 1.0
			return -(t * t * t * t - 1.0)
		FGUIEaseType.QUART_IN_OUT:
			t *= 2.0
			if t < 1.0:
				return 0.5 * t * t * t * t
			t -= 2.0
			return -0.5 * (t * t * t * t - 2.0)
		FGUIEaseType.QUINT_IN:
			return t * t * t * t * t
		FGUIEaseType.QUINT_OUT:
			t -= 1.0
			return t * t * t * t * t + 1.0
		FGUIEaseType.QUINT_IN_OUT:
			t *= 2.0
			if t < 1.0:
				return 0.5 * t * t * t * t * t
			t -= 2.0
			return 0.5 * (t * t * t * t * t + 2.0)
		FGUIEaseType.EXPO_IN:
			return 0.0 if is_zero_approx(time) else pow(2.0, 10.0 * (t - 1.0))
		FGUIEaseType.EXPO_OUT:
			return 1.0 if is_equal_approx(time, duration) else -pow(2.0, -10.0 * t) + 1.0
		FGUIEaseType.EXPO_IN_OUT:
			if is_zero_approx(time):
				return 0.0
			if is_equal_approx(time, duration):
				return 1.0
			t *= 2.0
			if t < 1.0:
				return 0.5 * pow(2.0, 10.0 * (t - 1.0))
			t -= 1.0
			return 0.5 * (-pow(2.0, -10.0 * t) + 2.0)
		FGUIEaseType.CIRC_IN:
			return -(sqrt(1.0 - t * t) - 1.0)
		FGUIEaseType.CIRC_OUT:
			t -= 1.0
			return sqrt(1.0 - t * t)
		FGUIEaseType.CIRC_IN_OUT:
			t *= 2.0
			if t < 1.0:
				return -0.5 * (sqrt(1.0 - t * t) - 1.0)
			t -= 2.0
			return 0.5 * (sqrt(1.0 - t * t) + 1.0)
		FGUIEaseType.ELASTIC_IN:
			if is_zero_approx(time):
				return 0.0
			if is_equal_approx(t, 1.0):
				return 1.0
			if is_zero_approx(period):
				period = duration * 0.3
			var s0: float
			if overshoot_or_amplitude < 1.0:
				overshoot_or_amplitude = 1.0
				s0 = period / 4.0
			else:
				s0 = period / _TWO_PI * asin(1.0 / overshoot_or_amplitude)
			t -= 1.0
			return -(overshoot_or_amplitude * pow(2.0, 10.0 * t) * sin((t * duration - s0) * _TWO_PI / period))
		FGUIEaseType.ELASTIC_OUT:
			if is_zero_approx(time):
				return 0.0
			if is_equal_approx(t, 1.0):
				return 1.0
			if is_zero_approx(period):
				period = duration * 0.3
			var s1: float
			if overshoot_or_amplitude < 1.0:
				overshoot_or_amplitude = 1.0
				s1 = period / 4.0
			else:
				s1 = period / _TWO_PI * asin(1.0 / overshoot_or_amplitude)
			return overshoot_or_amplitude * pow(2.0, -10.0 * t) * sin((t * duration - s1) * _TWO_PI / period) + 1.0
		FGUIEaseType.ELASTIC_IN_OUT:
			if is_zero_approx(time):
				return 0.0
			t = time / (duration * 0.5)
			if is_equal_approx(t, 2.0):
				return 1.0
			if is_zero_approx(period):
				period = duration * (0.3 * 1.5)
			var s: float
			if overshoot_or_amplitude < 1.0:
				overshoot_or_amplitude = 1.0
				s = period / 4.0
			else:
				s = period / _TWO_PI * asin(1.0 / overshoot_or_amplitude)
			if t < 1.0:
				t -= 1.0
				return -0.5 * (overshoot_or_amplitude * pow(2.0, 10.0 * t) * sin((t * duration - s) * _TWO_PI / period))
			t -= 1.0
			return overshoot_or_amplitude * pow(2.0, -10.0 * t) * sin((t * duration - s) * _TWO_PI / period) * 0.5 + 1.0
		FGUIEaseType.BACK_IN:
			return t * t * ((overshoot_or_amplitude + 1.0) * t - overshoot_or_amplitude)
		FGUIEaseType.BACK_OUT:
			t -= 1.0
			return t * t * ((overshoot_or_amplitude + 1.0) * t + overshoot_or_amplitude) + 1.0
		FGUIEaseType.BACK_IN_OUT:
			t *= 2.0
			overshoot_or_amplitude *= 1.525
			if t < 1.0:
				return 0.5 * (t * t * ((overshoot_or_amplitude + 1.0) * t - overshoot_or_amplitude))
			t -= 2.0
			return 0.5 * (t * t * ((overshoot_or_amplitude + 1.0) * t + overshoot_or_amplitude) + 2.0)
		FGUIEaseType.BOUNCE_IN:
			return _bounce_ease_in(time, duration)
		FGUIEaseType.BOUNCE_OUT:
			return _bounce_ease_out(time, duration)
		FGUIEaseType.BOUNCE_IN_OUT:
			return _bounce_ease_in_out(time, duration)
		FGUIEaseType.CUSTOM:
			return custom_ease.evaluate(t) if custom_ease != null else t
		_:
			return -t * (t - 2.0)


static func _bounce_ease_in(time: float, duration: float) -> float:
	return 1.0 - _bounce_ease_out(duration - time, duration)


static func _bounce_ease_out(time: float, duration: float) -> float:
	time /= duration
	if time < 1.0 / 2.75:
		return 7.5625 * time * time
	if time < 2.0 / 2.75:
		time -= 1.5 / 2.75
		return 7.5625 * time * time + 0.75
	if time < 2.5 / 2.75:
		time -= 2.25 / 2.75
		return 7.5625 * time * time + 0.9375
	time -= 2.625 / 2.75
	return 7.5625 * time * time + 0.984375


static func _bounce_ease_in_out(time: float, duration: float) -> float:
	if time < duration * 0.5:
		return _bounce_ease_in(time * 2.0, duration) * 0.5
	return _bounce_ease_out(time * 2.0 - duration, duration) * 0.5 + 0.5
