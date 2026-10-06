class_name GameTheme
## 全局主题常量与样式工厂
## v3：暖米色护眼工作台（#F0E9DC 系，Steam 桌面风 1280x800）
## v4：官方截图复刻令牌（docs/ui_real_*.md 实测，1280x720 基准）
## 兼容旧 API：flat_style / border_style / button_theme

# ---- v4 官方截图实测色板（12 张图视觉分析提炼） ----
const V_PAPER_BG := Color("EDE3D3")      ## 全站麻布纸底
const V_PAPER_WARM := Color("EAD7B2")    ## 暖纸（结算信/书房页底 #F2DEBB 近似）
const V_CARD := Color("F3EBDD")          ## 奶油卡片
const V_CARD_2 := Color("FCEBCA")        ## 米白信纸卡
const V_TEXT_TITLE := Color("4A3A2A")    ## 大标题深棕
const V_TEXT_BODY := Color("6B4A23")     ## 正文
const V_TEXT_MID := Color("54452F")      ## 导航/链接
const V_TEXT_SUB := Color("9A8B78")      ## 次要说明
const V_TEXT_MUTED := Color("A79781")    ## 未选标签
const V_TEXT_FAINT := Color("B6A894")     ## 禁用/未达成
const V_BORDER := Color("C4B49A")         ## 1px 卡描边
const V_BORDER_DARK := Color("8A5A44")    ## 手绘深描边
const V_SEPARATOR := Color("DED2BE")      ## 分隔线
const V_ACCENT := Color("8B5E3C")         ## 深褐强调（进度/按钮）
const V_DEEPEST := Color("5C3A22")        ## 最深数据
const V_WOOD := Color("B98A4E")          ## 托盘木框（实测）
const V_WOOD_HI := Color("E4C48C")       ## 木高光（实测）
const V_WOOD_LINE := Color("6E4A1E")      ## 木深线（实测）
const V_TRAY_FELT := Color("ECE2C9")      ## 托盘内绒（实测）
const V_WOOD_DARK := Color("A5824F")     ## 深木
const V_SLOT_BG := Color("F3E6C8")        ## 拼图空位底（未收集米白，实测）
const V_SEAM := Color("CBB994")          ## 已放块接缝线 1-1.5px（实测）
const V_GUIDE := Color("C6B294")          ## 空位极淡引导线（低置信观测）
const V_PILL_L := Color("C8AD94")
const V_PILL_M := Color("A48C76")
const V_PILL_D := Color("9A8371")
const V_BRICK_L := Color("C5AA92")
const V_BRICK_D := Color("997D66")
const V_SEAL_RED := Color("A93226")       ## 朱红印章（仅印章）
const V_POSTBOX_RED := Color("A13D30")
const V_BADGE_ON := Color("AB7546")       ## 徽章·专注进行态（暖橙实测）
const V_BADGE_OFF := Color("6E7F8E")      ## 徽章·结束态（蓝灰实测）
const V_BREATH_GLOW := Color("B1F3E2")    ## 呼吸球
const V_OLIVE_SEL := Color("6E8B3D")      ## 选中橄榄绿
const V_TIMER := Color("764E26")         ## 番茄钟大数字（实测）
const V_BTN_FACE := Color("F5E6C2")      ## 按钮面
const V_BTN_STROKE := Color("8A6A3E")    ## 按钮描边
const V_ICON := Color("4A3A2C")          ## 线性图标描边
const V_CHART_DARK := Color("2E2016")
const V_CHART_LIGHT := Color("C6AE95")
const V_GRID := Color("D8C6B4")
const V_PIE := [Color("BD7C5D"), Color("B0707A"), Color("98A668"), Color("909075"), Color("807FA4"), Color("9580B0"), Color("71987C"), Color("64828C"), Color("8A8A80")]

# ---- v4 字号（1280x720 基准，1.506x 换算） ----
const V_F_PAGE := 30        ## 页面大标题
const V_F_TAB := 26         ## 一级标签选中
const V_F_TAB_OFF := 20    ## 标签未选
const V_F_SECTION := 21    ## 板块标题
const V_F_BODY := 19
const V_F_SMALL := 16
const V_F_KPI := 26
const V_F_TIMER := 52       ## 番茄钟大数字（34-36px 基准）
const V_F_MENU := 30       ## 书房手写菜单字
const V_F_MIN := 14

# ---- 经典色板（v1/v2，旧场景引用保留） ----
const CREAM := Color("FFF8EF")
const ORANGE := Color("F4B860")
const TERRA := Color("E08E79")
const SAGE := Color("7FB6A4")
const LAVENDER := Color("8D7BA8")
const TEXT_DARK := Color("4A3728")
const NIGHT := Color("2A2333")
const WARM_TINT := Color(1.05, 0.95, 0.82)

# ---- 工作台暖米色板（v3） ----
const PAPER := Color("F0E9DC")        ## 主背景：暖米纸色
const PAPER_LIGHT := Color("F7F1E6")  ## 卡片/面板亮面
const PAPER_DEEP := Color("E4D9C6")   ## 面板暗面/分隔
const WOOD := Color("C9B08C")         ## 木框/描边
const WOOD_DEEP := Color("A98F6B")    ## 深木描边
const INK := Color("5B4F3F")          ## 正文墨色（暖棕灰）
const INK_SOFT := Color("8C7E6C")     ## 次要文字
const TOMATO := Color("E07856")       ## 番茄钟主色（暖橘红）
const TOMATO_DEEP := Color("C95F3F")  ## 番茄钟按下/深色
const TOMATO_LEAF := Color("7FA98C")  ## 番茄钟蒂绿
const BREAK_BLUE := Color("8FAFBF")   ## 休息态蓝
const GOLD := Color("E0B25C")         ## 星星/奖励金
const PIECE_DIM := Color(0.62, 0.55, 0.46, 0.85)  ## 未收集碎片遮罩

# ---- 字号 ----
const FONT_TITLE := 42
const FONT_H1 := 32
const FONT_BODY := 24
const FONT_SMALL := 18
const FONT_TIMER := 64        ## 番茄钟大数字
const FONT_TOOL := 15         ## 工具栏小字

# ---- 旧 API 保留 ----
static func flat_style(color: Color, radius: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	return sb

static func border_style(bg: Color, border: Color, radius: int = 12, width: int = 2) -> StyleBoxFlat:
	var sb := flat_style(bg, radius)
	sb.border_color = border
	sb.set_border_width_all(width)
	return sb

static func button_theme(bg: Color, hover: Color, font_size: int = FONT_BODY, text_color: Color = INK) -> Theme:
	var t := Theme.new()
	t.set_stylebox("normal", "Button", flat_style(bg))
	t.set_stylebox("hover", "Button", flat_style(hover))
	t.set_stylebox("pressed", "Button", flat_style(hover.darkened(0.12)))
	t.set_stylebox("disabled", "Button", flat_style(bg.darkened(0.3)))
	t.set_color("font_color", "Button", text_color)
	t.set_color("font_hover_color", "Button", text_color)
	t.set_color("font_pressed_color", "Button", text_color)
	t.set_color("font_disabled_color", "Button", text_color.darkened(0.4))
	t.set_font_size("font_size", "Button", font_size)
	return t

# ---- v3 工作台样式 ----

## 面板底（纸卡片）：亮面+柔和阴影
static func panel_style(bg: Color = PAPER_LIGHT, radius: int = 14) -> StyleBoxFlat:
	var sb := flat_style(bg, radius)
	sb.shadow_color = Color(0.36, 0.29, 0.20, 0.14)
	sb.shadow_size = 6
	sb.set_border_width_all(1)
	sb.border_color = WOOD * Color(1, 1, 1, 0.45)
	return sb

## 工具栏按钮（方形图标钮）：normal 透明、hover 亮、active 左侧高亮条
static func tool_button_style(active: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.30) if active else Color(1, 1, 1, 0.0)
	sb.set_corner_radius_all(10)
	if active:
		sb.border_color = TOMATO
		sb.set_border_width_all(2)
		sb.bg_color = Color(1, 1, 1, 0.55)
	return sb

## 主行动按钮（开始专注）：番茄色实底
static func action_button_theme(font_size: int = 22) -> Theme:
	var t := Theme.new()
	var normal := flat_style(TOMATO, 24)
	normal.shadow_color = Color(0.55, 0.22, 0.10, 0.25)
	normal.shadow_size = 4
	t.set_stylebox("normal", "Button", normal)
	var hover := flat_style(TOMATO.lightened(0.08), 24)
	hover.shadow_color = Color(0.55, 0.22, 0.10, 0.35)
	hover.shadow_size = 6
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", flat_style(TOMATO_DEEP, 24))
	var disabled := flat_style(PAPER_DEEP, 24)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", Color("FFF6EC"))
	t.set_color("font_hover_color", "Button", Color("FFF6EC"))
	t.set_color("font_pressed_color", "Button", Color("FFF6EC"))
	t.set_color("font_disabled_color", "Button", INK_SOFT)
	t.set_font_size("font_size", "Button", font_size)
	return t

## 次要按钮（放弃/工具内小按钮）：纸面描边
static func soft_button_theme(font_size: int = 18, tint: Color = INK) -> Theme:
	var t := Theme.new()
	var base := border_style(Color(1, 1, 1, 0.5), WOOD, 18, 2)
	base.border_color = WOOD
	t.set_stylebox("normal", "Button", base)
	var hover := border_style(Color(1, 1, 1, 0.8), WOOD_DEEP, 18, 2)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", border_style(PAPER_DEEP, WOOD_DEEP, 18, 2))
	t.set_stylebox("disabled", "Button", border_style(PAPER_DEEP * Color(1, 1, 1, 0.6), PAPER_DEEP, 18, 2))
	t.set_color("font_color", "Button", tint)
	t.set_color("font_hover_color", "Button", tint)
	t.set_color("font_pressed_color", "Button", tint)
	t.set_color("font_disabled_color", "Button", INK_SOFT)
	t.set_font_size("font_size", "Button", font_size)
	return t

## CheckBox（Todo 用）：圆角纸片
static func checkbox_theme() -> Theme:
	var t := Theme.new()
	var normal := border_style(Color(1, 1, 1, 0.0), INK_SOFT, 6, 2)
	normal.set_corner_radius_all(6)
	t.set_stylebox("normal", "CheckBox", normal)
	var hover := border_style(Color(1, 1, 1, 0.35), INK, 6, 2)
	t.set_stylebox("hover", "CheckBox", hover)
	var checked := flat_style(TOMATO_LEAF, 6)
	t.set_stylebox("checked", "CheckBox", checked)
	t.set_stylebox("checked_hover", "CheckBox", flat_style(TOMATO_LEAF.lightened(0.1), 6))
	return t

# ================= v4 官方截图风格工厂 =================

## v4 卡片：奶油底 + 1px #C4B49A 描边 + 无投影（纸质平面）
static func v4_card(radius: int = 6) -> StyleBoxFlat:
	var sb := flat_style(V_CARD, radius)
	sb.border_color = V_BORDER
	sb.set_border_width_all(1)
	return sb

## v4 纯文字按钮（无底框，real_03/04 的"暂停/结束/开始/设置"风格）
static func v4_text_button(font_size: int = V_F_BODY, color: Color = V_TEXT_MID) -> Theme:
	var t := Theme.new()
	var sb := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(s, "Button", sb)
	t.set_color("font_color", "Button", color)
	t.set_color("font_hover_color", "Button", color.darkened(0.15))
	t.set_color("font_pressed_color", "Button", color.darkened(0.25))
	t.set_color("font_disabled_color", "Button", V_TEXT_FAINT)
	t.set_font_size("font_size", "Button", font_size)
	return t

## v4 奶油按钮：#F5E6C2 底 + #8A6A3E 描边（卡片内操作）
static func v4_cream_button(font_size: int = V_F_BODY) -> Theme:
	var t := Theme.new()
	var n := flat_style(V_BTN_FACE, 8)
	n.border_color = V_BTN_STROKE
	n.set_border_width_all(1)
	var h := flat_style(V_BTN_FACE.lightened(0.05), 8)
	h.border_color = V_BTN_STROKE
	h.set_border_width_all(1)
	t.set_stylebox("normal", "Button", n)
	t.set_stylebox("hover", "Button", h)
	t.set_stylebox("pressed", "Button", h)
	t.set_color("font_color", "Button", V_TEXT_TITLE)
	t.set_font_size("font_size", "Button", font_size)
	return t

## v4 木质托盘框（棋盘/托盘外框）
static func v4_wood_frame(thick: int = 5) -> StyleBoxFlat:
	var sb := flat_style(V_WOOD, 4)
	sb.border_color = V_WOOD_LINE
	sb.set_border_width_all(thick)
	return sb

## v4 KPI 胶囊（无描边无投影）
static func v4_pill(fill: Color) -> StyleBoxFlat:
	return flat_style(fill, 8)

## v4 侧栏卡片：圆角 10 + 零投影（实测：全界面零投影，右栏间距内容驱动）
static func v4_side_card() -> StyleBoxFlat:
	var sb := flat_style(Color("E9D7B6"), 10)
	sb.border_color = Color("DCC49E")
	sb.set_border_width_all(1)
	return sb

## v4 侧栏亮卡（任务卡/便签）
static func v4_side_card_light() -> StyleBoxFlat:
	var sb := flat_style(Color("F3E1BF"), 10)
	sb.border_color = Color("E0CBA4")
	sb.set_border_width_all(1)
	return sb

## LineEdit（Todo 输入/计数器）：底线纸面
static func line_edit_theme(font_size: int = 18) -> Theme:
	var t := Theme.new()
	var normal := flat_style(Color(1, 1, 1, 0.55), 10)
	normal.border_color = WOOD * Color(1, 1, 1, 0.6)
	normal.set_border_width_all(1)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	t.set_stylebox("normal", "LineEdit", normal)
	var focus := flat_style(Color(1, 1, 1, 0.85), 10)
	focus.border_color = TOMATO
	focus.set_border_width_all(2)
	focus.content_margin_left = 12
	focus.content_margin_right = 12
	focus.content_margin_top = 6
	focus.content_margin_bottom = 6
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", INK_SOFT)
	t.set_color("caret_color", "LineEdit", TOMATO)
	t.set_font_size("font_size", "LineEdit", font_size)
	return t

## TextEdit（备忘录）
static func text_edit_theme(font_size: int = 17) -> Theme:
	var t := Theme.new()
	var normal := flat_style(Color(1, 1, 1, 0.55), 10)
	normal.border_color = WOOD * Color(1, 1, 1, 0.6)
	normal.set_border_width_all(1)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	t.set_stylebox("normal", "TextEdit", normal)
	t.set_color("font_color", "TextEdit", INK)
	t.set_color("background_color", "TextEdit", Color(0, 0, 0, 0))
	t.set_font_size("font_size", "TextEdit", font_size)
	return t

## 进度环颜色（番茄钟）
static func timer_ring_color(state: int) -> Color:
	match state:
		0: return TOMATO          # idle/focusing 番茄色
		1: return BREAK_BLUE      # break 休息蓝
		_: return TOMATO


# ================= 全站默认字体（task-37） =================
## 霞鹜文楷 LXGW WenKai（OFL 开源楷体手写风，官方截图画风特征）。
## 静态注册一次 ThemeDB.fallback_font：全站未显式设置 font 的控件统一走该兜底，
## 即全局默认字体；字体缺失/未导入时安全跳过，回落引擎内置字体。

const FONT_WENKAI_REGULAR := "res://assets/fonts/lxgw_wenkai_regular.ttf"
const FONT_WENKAI_BOLD := "res://assets/fonts/lxgw_wenkai_bold.ttf"

static var _font_registered := _setup_default_font()

static func _setup_default_font() -> bool:
	if ResourceLoader.exists(FONT_WENKAI_REGULAR, "FontFile"):
		var font := load(FONT_WENKAI_REGULAR) as FontFile
		if font != null:
			ThemeDB.fallback_font = font
			return true
	push_warning("[GameTheme] 霞鹜文楷 fallback 字体注册失败（文件缺失或未导入）: " + FONT_WENKAI_REGULAR)
	return false
