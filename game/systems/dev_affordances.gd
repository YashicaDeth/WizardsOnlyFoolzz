class_name DevAffordances
extends RefCounted

## Single gate for controls and command-line hooks that exist to exercise a
## build rather than to play it. Release exports cannot opt themselves back in.

static func available() -> bool:
	return OS.is_debug_build() and (Engine.is_editor_hint() or OS.get_environment("ATG_TEST_MODE") == "1" or OS.get_environment("ATG_DEV_TOOLS") == "1")


static func accepts_command_line(flag: String) -> bool:
	return available() and flag in OS.get_cmdline_user_args()
