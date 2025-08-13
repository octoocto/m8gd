class_name Console extends RichTextLabel

const REMOVE_DELAY := 5.0

var lines: PackedStringArray = []

func print_line(line: String) -> void:
	lines.append(line.to_upper())
	update_text()
	await get_tree().create_timer(REMOVE_DELAY).timeout
	lines.remove_at(0)
	update_text()

func update_text() -> void:
	text = "\n".join(lines)