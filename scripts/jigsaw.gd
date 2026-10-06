class_name Jigsaw
## 咬合形拼图几何引擎（real_03/04 复刻）
## 板级一致性：横边数组 h_edges[(rows+1)*cols]、竖边数组 v_edges[rows*(cols+1)]
## 每条边 bump ∈ {+1,-1}；碎片查询四边，保证相邻块互补

const BUMP_RATIO := 0.18
const BUMP_POS := 0.5

static func make_edges(cols: int, rows: int, seed: int) -> Dictionary:
	## 生成整板确定性凸凹边表
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var h := PackedInt32Array()
	var v := PackedInt32Array()
	for i in (rows + 1) * cols:
		h.append(1 if rng.randf() > 0.5 else -1)
	for i in rows * (cols + 1):
		v.append(1 if rng.randf() > 0.5 else -1)
	return { "h": h, "v": v }

static func _edge(a: Vector2, b: Vector2, bump: int, cell_len: float) -> PackedVector2Array:
	## a→b 直线中段带半圆咬合（7 顶点）
	if bump == 0:
		return PackedVector2Array([a, b])
	var pts := PackedVector2Array()
	var dir := (b - a).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var r := cell_len * BUMP_RATIO
	var len_ := (b - a).length()
	var m := a + dir * len_ * BUMP_POS
	var t1 := BUMP_POS - (r / len_) * 0.85
	var t2 := BUMP_POS + (r / len_) * 0.85
	pts.append(a)
	pts.append(a + dir * len_ * t1)
	pts.append(m + normal * bump * r * 0.35 - dir * r * 0.45)
	pts.append(m + normal * bump * r)
	pts.append(m + normal * bump * r * 0.35 + dir * r * 0.45)
	pts.append(a + dir * len_ * t2)
	pts.append(b)
	return pts

static func piece_polygon(col: int, row: int, cols: int, rows: int, edges: Dictionary, cell_size: Vector2) -> PackedVector2Array:
	## 单块多边形（本地坐标，逆时针），内部边咬合、外缘边直
	## h_edges 索引：row*cols + col（该格上边）；下边 = (row+1)*cols + col
	## v_edges 索引：row*(cols+1) + col（该格左边）；右边 = row*(cols+1) + col + 1
	var h: PackedInt32Array = edges.h
	var v: PackedInt32Array = edges.v
	var w: float = cell_size.x
	var hh: float = cell_size.y
	var up := h[row * cols + col] if row > 0 else 0
	var down := h[(row + 1) * cols + col] if row < rows - 1 else 0
	var left := v[row * (cols + 1) + col] if col > 0 else 0
	var right := v[row * (cols + 1) + col + 1] if col < cols - 1 else 0
	var pts := PackedVector2Array()
	pts.append_array(_edge(Vector2(0, 0), Vector2(w, 0), up, w))
	pts.append_array(_edge(Vector2(w, 0), Vector2(w, hh), right, hh))
	var bottom := _edge(Vector2(0, hh), Vector2(w, hh), down, w)
	for i in range(bottom.size() - 1, -1, -1):
		pts.append(bottom[i])
	var lft := _edge(Vector2(0, 0), Vector2(0, hh), left, hh)
	for i in range(lft.size() - 1, -1, -1):
		pts.append(lft[i])
	return pts
