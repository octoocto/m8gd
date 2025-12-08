extends Node

func ln(message: String, index: int = 1) -> void:
	var stack: Array = get_stack()
	if stack.size() > index:
		var source: String = stack[index].source.trim_prefix("res://")
		var line: int = stack[index].line
		print_rich("[color=aqua][%s:%d][/color] %s" % [source, line, message])
	else:
		print(message)

## Call a function and measure how long it takes to execute.
func call_task(fn: Callable, task_name: String = "") -> Variant:
	if task_name == "":
		task_name = "%s()" % fn.get_method()
	var time := Time.get_ticks_msec()
	ln("[color=green]starting task \"%s\"[/color]" % [task_name], 2)
	var ret: Variant = fn.call()
	ln("[color=green]finished task \"%s\" in %.3fs[/color]" % [task_name, ((Time.get_ticks_msec() - time) / 1000.0)], 2)
	return ret
