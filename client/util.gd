extends Node

func argmax(inputs: Array[Variant], outputs: Array[float]) -> Variant:
	var max_output := 0.0
	var corresponding_input: Variant
	for i in range(len(outputs)):
		if outputs[i] > max_output:
			max_output = outputs[i]
			corresponding_input = inputs[i]
	return corresponding_input
