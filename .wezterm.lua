local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- ── Tokyo Night Storm (matches LazyVim / tokyonight.nvim) ─────────────────────
config.color_scheme = "Tokyo Night Storm"
-- Tokyo Night Storm palette (shared by tab bar formatters below)
local TN = {
	bg = "#1f2335",
	bg_dark = "#16161e",
	bg_highlight = "#292e42",
	fg = "#c0caf5",
	fg_dim = "#565f89",
	blue = "#7aa2f7",
	cyan = "#7dcfff",
	magenta = "#bb9af7",
	green = "#9ece6a",
	orange = "#ff9e64",
}

config.colors = {
	cursor_bg = "#c0caf5",
	cursor_fg = "#24283b",
	cursor_border = "#c0caf5",
	selection_bg = "#33467c",
	selection_fg = "#c0caf5",
	split = "#3b4261",
	tab_bar = {
		background = TN.bg_dark,
		active_tab = { bg_color = TN.blue, fg_color = TN.bg_dark, intensity = "Bold" },
		inactive_tab = { bg_color = TN.bg, fg_color = TN.fg_dim },
		inactive_tab_hover = { bg_color = TN.bg_highlight, fg_color = TN.cyan, italic = false },
		new_tab = { bg_color = TN.bg_dark, fg_color = TN.fg_dim },
		new_tab_hover = { bg_color = TN.bg_highlight, fg_color = TN.blue, intensity = "Bold" },
	},
}

-- ── Typography (MesloLGS NF + p10k, Ghostty default size 13) ────────────────
config.font = wezterm.font("MesloLGS NF")
config.font_size = 13.0
config.line_height = 1.05
config.cell_width = 1.0
config.harfbuzz_features = { "calt=1", "clig=1", "liga=1" }
config.font_rules = {
	{
		italic = true,
		font = wezterm.font("MesloLGS NF", { italic = true }),
	},
	{
		intensity = "Bold",
		font = wezterm.font("MesloLGS NF", { weight = "Bold" }),
	},
	{
		intensity = "Bold",
		italic = true,
		font = wezterm.font("MesloLGS NF", { weight = "Bold", italic = true }),
	},
}

-- ── Window chrome (Ghostty: native, minimal, subtle padding) ────────────────
config.window_decorations = "RESIZE"
config.window_padding = {
	top = "0.2cell",
	bottom = "0.2cell",
}
config.window_background_opacity = 0.8
config.text_background_opacity = 1.0
config.macos_window_background_blur = 50
config.native_macos_fullscreen_mode = true
config.hide_tab_bar_if_only_one_tab = true
config.initial_cols = 120
config.initial_rows = 32

-- ── Cursor (Ghostty default: block) ─────────────────────────────────────────
config.default_cursor_style = "BlinkingBlock"
config.cursor_blink_rate = 500
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"

-- ── Tabs & panes ─────────────────────────────────────────────────────────────
config.enable_tab_bar = true
config.use_fancy_tab_bar = false -- retro bar: full control via format-tab-title
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = false
config.show_new_tab_button_in_tab_bar = true
config.show_tab_index_in_tab_bar = false
config.tab_max_width = 28
config.switch_to_last_active_tab_when_closing_tab = true
config.status_update_interval = 2000

config.inactive_pane_hsb = {
	saturation = 1.0,
	brightness = 0.7,
}

-- Soft powerline edge between tabs (MesloLGS NF provides these glyphs)
local SOLID_LEFT = wezterm.nerdfonts.ple_left_half_circle_thick
local SOLID_RIGHT = wezterm.nerdfonts.ple_right_half_circle_thick

local ICON_COMMIT = wezterm.nerdfonts.md_source_commit
local ICON_CPU = wezterm.nerdfonts.md_cpu_64_bit
local ICON_BAT_CHARGING = wezterm.nerdfonts.md_battery_charging
local ICON_BAT = {
	wezterm.nerdfonts.md_battery_outline,
	wezterm.nerdfonts.md_battery_20,
	wezterm.nerdfonts.md_battery_40,
	wezterm.nerdfonts.md_battery_60,
	wezterm.nerdfonts.md_battery_80,
	wezterm.nerdfonts.md_battery,
}

local function basename(path)
	return string.gsub(path, "(.*[/\\])(.*)", "%2")
end

local function tab_title(tab)
	local title = tab.tab_title
	if title and #title > 0 then
		return title
	end
	local pane = tab.active_pane
	local process = basename(pane.foreground_process_name or "")
	if process == "" or process == "zsh" or process == "bash" or process == "fish" then
		local cwd = pane.current_working_dir
		if cwd then
			local path = cwd.file_path or tostring(cwd)
			return basename(path:gsub("/+$", ""))
		end
		return "shell"
	end
	return process
end

wezterm.on("format-tab-title", function(tab, tabs, _panes, _config, hover, max_width)
	local title = tab_title(tab)
	-- Leave room for padding + half-circles
	title = wezterm.truncate_right(title, math.max(max_width - 4, 1))

	local bg, fg
	if tab.is_active then
		bg, fg = TN.blue, TN.bg_dark
	elseif hover then
		bg, fg = TN.bg_highlight, TN.cyan
	else
		bg, fg = TN.bg, TN.fg_dim
	end

	local edge_bg = TN.bg_dark
	local index = tostring(tab.tab_index + 1)

	return {
		{ Background = { Color = edge_bg } },
		{ Foreground = { Color = bg } },
		{ Text = SOLID_LEFT },
		{ Background = { Color = bg } },
		{ Foreground = { Color = fg } },
		{ Text = " " .. index .. " " .. title .. " " },
		{ Background = { Color = edge_bg } },
		{ Foreground = { Color = bg } },
		{ Text = SOLID_RIGHT },
	}
end)

-- System metrics for the right status.
-- Paint from cache first; refresh in the background so a slow `gh`/ps never
-- leaves the right status blank (update-status must return quickly).
local METRICS_REFRESH_SECS = 3
local COMMITS_REFRESH_SECS = 300
local GH = "/opt/homebrew/bin/gh"
local metrics = {
	at = 0,
	commits_at = 0,
	commits = "–",
	cpu = "–",
	refreshing = false,
	commits_refreshing = false,
}

local function sh_trim(argv)
	local ok, stdout = wezterm.run_child_process(argv)
	if not ok or not stdout then
		return nil
	end
	return (stdout:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function battery_segment()
	local batteries = wezterm.battery_info()
	if not batteries or #batteries == 0 then
		return nil
	end
	local b = batteries[1]
	local pct = math.floor((b.state_of_charge or 0) * 100 + 0.5)
	local charging = b.state == "Charging" or b.state == "Full"
	local icon
	if charging then
		icon = ICON_BAT_CHARGING
	else
		local idx = math.min(6, math.max(1, math.floor(pct / 20) + 1))
		icon = ICON_BAT[idx]
	end
	local color = TN.green
	if pct <= 20 and not charging then
		color = TN.orange
	elseif charging then
		color = TN.cyan
	end
	return {
		icon = icon,
		text = string.format("%d%%", pct),
		color = color,
	}
end

local function status_cell(bg, fg, text)
	return {
		{ Background = { Color = bg } },
		{ Foreground = { Color = fg } },
		{ Text = text },
	}
end

local function append(dst, src)
	for _, item in ipairs(src) do
		table.insert(dst, item)
	end
end

local function build_right_status()
	local bat = battery_segment()
	local cells = {
		{ label = ICON_COMMIT .. " " .. metrics.commits, fg = TN.magenta },
		{ label = ICON_CPU .. " " .. metrics.cpu .. "%", fg = TN.blue },
	}
	if bat then
		table.insert(cells, { label = bat.icon .. " " .. bat.text, fg = bat.color })
	end

	local elements = {}
	local prev_bg = TN.bg_dark
	for i, cell in ipairs(cells) do
		local bg = (i % 2 == 1) and TN.bg_highlight or TN.bg
		append(elements, status_cell(prev_bg, bg, SOLID_LEFT))
		append(elements, status_cell(bg, cell.fg, " " .. cell.label .. " "))
		prev_bg = bg
	end
	return wezterm.format(elements)
end

local function refresh_github_commits(window)
	if metrics.commits_refreshing then
		return
	end
	metrics.commits_refreshing = true
	-- Schedule so we never block update-status / the UI thread.
	wezterm.time.call_after(0, function()
		local ok, result = pcall(function()
			local today = wezterm.strftime("%Y-%m-%d")
			return sh_trim({
				GH,
				"api",
				"graphql",
				"-f",
				table.concat({
					"query=",
					"query { viewer { contributionsCollection { contributionCalendar { ",
					"weeks { contributionDays { date contributionCount } } ",
					"} } } }",
				}),
				"--jq",
				string.format("[.. | objects | select(.date == %q) | .contributionCount] | first // empty", today),
			})
		end)
		if ok and result and result ~= "" then
			metrics.commits = result
		elseif not ok then
			wezterm.log_warn("github commits refresh failed: " .. tostring(result))
		end
		metrics.commits_at = os.time()
		metrics.commits_refreshing = false
		pcall(function()
			window:set_right_status(build_right_status())
		end)
	end)
end

local function refresh_metrics(window)
	if metrics.refreshing then
		return
	end
	metrics.refreshing = true
	wezterm.time.call_after(0, function()
		local ok, err = pcall(function()
			local ncpu = tonumber(sh_trim({ "sysctl", "-n", "hw.ncpu" })) or 1
			-- BSD awk has no ?: ternary — use an if.
			local cpu = sh_trim({
				"sh",
				"-c",
				string.format(
					'ps -A -o %%cpu | awk -v n=%d \'NR>1 {s+=$1} END { if (n>0) printf "%%.0f", s/n; else printf "%%.0f", s }\'',
					ncpu
				),
			})
			metrics.cpu = cpu or "–"
			metrics.at = os.time()
		end)
		if not ok then
			wezterm.log_warn("metrics refresh failed: " .. tostring(err))
		end
		metrics.refreshing = false
		pcall(function()
			window:set_right_status(build_right_status())
		end)
	end)
end

wezterm.on("update-status", function(window, pane)
	local ok, err = pcall(function()
		local now = os.time()
		-- Always paint first from cache so the bar is never blank.
		window:set_right_status(build_right_status())
		window:set_left_status("")

		if now - metrics.at >= METRICS_REFRESH_SECS then
			refresh_metrics(window)
		end
		if now - metrics.commits_at >= COMMITS_REFRESH_SECS then
			refresh_github_commits(window)
		end
	end)
	if not ok then
		wezterm.log_error("update-status failed: " .. tostring(err))
		window:set_right_status("status err")
	end
end)

-- ── Performance & scrollback ─────────────────────────────────────────────────
config.front_end = "WebGpu"
config.max_fps = 120
config.scrollback_lines = 50000
config.enable_scroll_bar = false

-- ── Shell ────────────────────────────────────────────────────────────────────
config.default_prog = { "/bin/zsh", "-l" }

-- ── Behavior ─────────────────────────────────────────────────────────────────
config.automatically_reload_config = true
config.warn_about_missing_glyphs = false
config.audible_bell = "Disabled"
config.visual_bell = {
	fade_in_function = "EaseIn",
	fade_in_duration_ms = 75,
	fade_out_function = "EaseOut",
	fade_out_duration_ms = 75,
}
config.check_for_updates = true
config.adjust_window_size_when_changing_font_size = false

-- ── Hyperlinks & quick select (WezTerm defaults) ─────────────────────────────
-- Uses built-in hyperlink_rules; no custom overrides needed.

config.quick_select_alphabet = "asdfqwertyuiopzxcvbnm"

-- Dim unfocused windows so the focused one is obvious at a glance.
local UNFOCUSED_FOREGROUND_TEXT_HSB = { hue = 1.0, saturation = 0.25, brightness = 0.45 }
local UNFOCUSED_WINDOW_BACKGROUND_OPACITY = 0.62

-- get_config_overrides() hands back a copy, so the current value is never the
-- same table we last stored; compare the fields instead of the identity.
local function same_text_hsb(actual, expected)
	if actual == nil or expected == nil then
		return actual == expected
	end
	return actual.hue == expected.hue
		and actual.saturation == expected.saturation
		and actual.brightness == expected.brightness
end

wezterm.on("window-focus-changed", function(window)
	local overrides = window:get_config_overrides() or {}
	local text_hsb, opacity
	if not window:is_focused() then
		text_hsb = UNFOCUSED_FOREGROUND_TEXT_HSB
		opacity = UNFOCUSED_WINDOW_BACKGROUND_OPACITY
	end

	-- Only write when one of the two values we own actually changes; a redundant
	-- set_config_overrides() call would trigger another config reload.
	if same_text_hsb(overrides.foreground_text_hsb, text_hsb) and overrides.window_background_opacity == opacity then
		return
	end

	overrides.foreground_text_hsb = text_hsb
	overrides.window_background_opacity = opacity
	window:set_config_overrides(overrides)
end)

return config
