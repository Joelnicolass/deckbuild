class_name PlainKeywordHighlighter
extends SyntaxHighlighter

const TAG_COLOR := Color("#ff7f7f")

var _regex: RegEx


func _init():
	_regex = RegEx.new()
	_regex.compile("\\[[^\\]]*\\]")


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var result := {}

	var text_edit := get_text_edit()
	if not text_edit:
		return result

	var line_text := text_edit.get_line(line)
	var default_color := text_edit.get_theme_color("font_color")

	for match_result in _regex.search_all(line_text):
		var start := match_result.get_start()
		var end := match_result.get_end()

		result[start] = {"color": TAG_COLOR}
		result[end] = {"color": default_color}

	return result
