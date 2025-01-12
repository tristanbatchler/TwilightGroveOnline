extends Node

func argmax(inputs: Array[Variant], outputs: Array[float]) -> Variant:
	var max_output := 0.0
	var corresponding_input: Variant
	for i in range(len(outputs)):
		if outputs[i] > max_output:
			max_output = outputs[i]
			corresponding_input = inputs[i]
	return corresponding_input

func pretty_int(num: int) -> String:
	if num < 10_000:
		return str(num)
	if num < 10_000_000:
		return "%dK" % roundi(num / 1_000.0)
	if num < 10_000_000_000:
		return "%.dM" % roundi(num / 1_000_000.0)
	if num < 10_000_000_000_000:
		return "%.dB" % roundi(num / 1_000_000_000.0)
	return "%dT" % roundi(num / 1_000_000_000_000.0)
