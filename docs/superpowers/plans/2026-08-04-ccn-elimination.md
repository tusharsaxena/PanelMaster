# CCN elimination — PanelMaster

Branch `feat/fix-ccn`. Design: `LibKa0s/docs/superpowers/specs/2026-08-04-ccn-elimination-design.md`.

**9 functions** with `lizard` CCN > 15. Target: every one at CCN <= 15, behavior unchanged.

## Exit criteria

1. `luacheck . --quiet` — 0 warnings, 0 errors.
2. `lua5.1 tests/run.lua` — all pass, count >= baseline.
3. `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` — no CCN > 15.
4. No behavior change. No version bump, no CHANGELOG, no merge, no tag.

## Rules

- Preferred shapes, in order: table-driven dispatch; a named file-local helper for a
  self-contained block; a data table + loop replacing repeated defaulting; splitting a
  builder into N small builders.
- No dumping a body into one helper to game the metric. Every resulting function must be a
  unit a reader can name.
- Dispatch/defaults tables are **module-level**, built once at file load — never per call.
- `lizard` counts `and`/`or` as decisions. Prefer `== nil` over `or` wherever a stored
  `false` or `0` must survive.
- Hot paths must not gain a per-call allocation.
- Sixteen functions across the collection have no coverage; where this file says
  `Coverage: NONE`, write a characterization test pinning current behavior **before**
  refactoring.

## Functions

### `Artwork.BuildArtSpec` — CCN 51 → target 10

`modules/Artwork.lua:832-1087` · pattern `monolithic-spec-builder` · risk **medium**

**What it does.** Pure record-to-geometry function: takes a panel record plus the already-clamped panel width/height and returns the complete artwork render spec (drawn rect, texture coordinates, tint, blend, layer, and the per-section quad list for composed Sunn bars), or nil when the panel draws no art.

**Where the branches come from.** One function doing six independent jobs: (1) a four-guard prologue (resolve, positive(panelW/H), positive(row.w/h)); (2) a five-arm if/elseif fill matrix (STRETCH/FIT/STATIC/FILL/TILE) that each set width/height/u0..v1/tile, with `a > 1 and ... or ...` inside FILL; (3) placement defaulting gated on `fill == "STATIC" or fill == "FIT"`; (4) tint composition; (5) the contentV0 window with a three-term `declared and declared > 0 and declared < 1` guard; (6) the composite-slicing double loop with the tiled-composite quad-budget clamp, the `bandLo > u0 and bandLo or u0` min/max idioms and the epsilon sliver test. Plus the trailing `if not quads then` single-texture fallback and four `tile and X or nil` wrap fields.

**Fix.** Split by the six jobs, all as file-local helpers above BuildArtSpec.
1. Hoist the duplicated native-size block (lines 820-821 in NativeSize and 842-843 here) into `local function nativeSize(row)` returning w,h or nil — NativeSize calls it too, killing a real duplication.
2. Hoist `toTextureAxes` out of the closure into `local function toTextureAxes(turned, screenH, screenV)`.
3. Replace the fill if/elseif with a module-level dispatch table built once at load:
   `local FILL = {}` with `FILL.STRETCH = function(W,H) return W,H, 0,0,1,1, false end`, `FILL.FIT = function(W,H,ew,eh,s) local r = math.min(W/ew, H/eh)*s; return ew*r, eh*r, 0,0,1,1, false end`, `FILL.STATIC = function(W,H,ew,eh,s) return ew*s, eh*s, 0,0,1,1, false end`, `FILL.FILL = function(W,H,ew,eh,s,turned) ... return W,H,u0,v0,u1,v1,false end`, `FILL.TILE = function(W,H,ew,eh,s,turned) local u1,v1 = toTextureAxes(turned, W/(ew*s), H/(eh*s)); return W,H, 0,0,u1,v1, true end`.
   Call site: `local width, height, u0, v0, u1, v1, tile = (FILL[fill] or FILL.TILE)(W, H, ew, eh, s, turned)`. `pickEnum` already guarantees fill is a member of C.ART_FILL_SET, so `or FILL.TILE` is belt-and-braces for the same `else -- TILE` semantics the chain had. Zero per-call allocation: the table and its five closures are created once at file load.
4. `local function artPlacement(rec, fill, T)` -> point, x, y (the STATIC/FIT block, CCN 4).
5. `local function artTint(rec, T)` -> the 4-element color table (CCN 2).
6. `local function contentCropV0(row, tile)` -> cv0 (CCN 5); keep the one-line `toFileV` closure at the call site since it captures cv0.
7. `local function clampTiledComposite(u0, u1, n)` -> u1, tileClamped (CCN 4).
8. `local function buildSectionQuads(ctx)` for lines 1007-1046, taking ONE ctx table assembled at the call site with the fields it needs (sections, n, u0, u1, span, toFileV, v0, v1, width, height, point, x, y, flipH, flipV, rotation, tile). CCN ~9. One extra table per call is acceptable here and only on the composite path: this function already allocates the spec table plus one table per quad, and it runs on panel render (event-driven), never per frame — Canvas.BuildSpec's only caller is Canvas:Render at modules/Canvas.lua:646, and the one OnUpdate in that file (the mouseover fade driver, line 548) does not go near it.
BuildArtSpec then reads as: guards -> pickEnum block -> turned -> fill dispatch -> artPlacement -> artTint -> flips -> contentCropV0 -> composeUV -> clampTiledComposite -> buildSectionQuads or the single-texture fallback -> return the flat table.

**Must not change.** The fill matrix must stay bit-identical under the quarter-turn transpose — a 512x128 piece at FIT/90deg is the documented regression, and it is invisible on square art. `else -- TILE` is the fall-through for anything not one of the four named fills, so the dispatch must keep TILE as the default arm, not error. The epsilon sliver test (`hi - lo > span * 1e-9`) is load-bearing against bright seams on band-aligned crops and must not become `hi > lo`. STRETCH must keep ignoring `s`. Only the seam appearance and the FILL-vs-STRETCH look are truly in-game-only; the numbers are all headlessly assertable.

**Coverage.** tests/test_artwork.lua (956 lines, the heaviest suite in the repo — drives the fill matrix against wide and tall art on both sides of the turn) and tests/test_sunnart.lua (composed multi-section bars, the quad list and the contentV0 crop). Strong coverage; this is the one CCN>15 function safe to refactor without writing a characterization test first.

---

### `R.Sanitize` — CCN 40 → target 9

`modules/Registry.lua:83-208` · pattern `field-defaulting` · risk **low**

**What it does.** The registry's write-side repair pass: fills every missing panel-record field from C.PANEL_TEMPLATE and clamps every numeric one into range, mutating and returning the record it is handed. Runs on every write so the stored SavedVariables file is always already valid.

**Where the branches come from.** Pure field-defaulting volume — roughly 45 straight-line statements, almost every one a branch to lizard: 14 `Util.Clamp(rec.f, min, max, t.f)` calls, 4 `tonumber(rec.f) or t.f`, 5 `if type(rec.f) ~= "string" or rec.f == "" then rec.f = t.f end` pairs (two conditions each), 3 `if not Util.IsPoint/IsStrata(...) then` guards, 6 `x and true or false` boolean coercions plus the C.COLOR_FIELDS loop, 3 `Util.Color(...)` calls and 3 `enumMatch(...) or t.f` defaults. No nesting at all — it is a flat list, which is exactly the shape that wants a data table plus a loop.

**Fix.** Replace the flat list with module-level rule tables + loops, keeping only the genuinely irregular fields explicit.
Add above R.Sanitize:
```lua
-- {field, min, max} — the fallback is always t[field].
local CLAMPED = {
  { "width", C.MIN_SIZE, C.MAX_SIZE }, { "height", C.MIN_SIZE, C.MAX_SIZE },
  { "level", 0, 100 }, { "scale", C.MIN_PANEL_SCALE, C.MAX_PANEL_SCALE },
  { "borderSize", C.MIN_BORDER, C.MAX_BORDER },
  { "borderOffset", C.MIN_BORDER_OFFSET, C.MAX_BORDER_OFFSET },
  { "alpha", 0, 1 }, { "mouseoverAlpha", 0, 1 },
  { "accentThickness", C.MIN_ACCENT_THICKNESS, C.MAX_ACCENT_THICKNESS },
  { "accentOffset", C.MIN_ACCENT_OFFSET, C.MAX_ACCENT_OFFSET },
  { "accentBorderSize", C.MIN_BORDER, C.MAX_BORDER },
  { "accentBorderOffset", C.MIN_BORDER_OFFSET, C.MAX_BORDER_OFFSET },
  { "artAlpha", 0, 1 }, { "artScale", C.MIN_ART_SCALE, C.MAX_ART_SCALE },
}
-- Deliberately unbounded (see the comments at rec.x and rec.artX).
local FREE_NUMBERS = { "x", "y", "artX", "artY" }
-- Non-empty strings; an empty one is a dropped key, not a choice. artCustomPath is NOT here.
local NONEMPTY_STRINGS = { "bgTexture", "borderTexture", "accentTexture",
                          "accentBorderTexture", "artTexture" }
local POINT_FIELDS = { "point", "relPoint", "artPoint" }
local COLOR_VALUES = { "bgColor", "borderColor", "artColor" }
local ENUM_FIELDS  = { "artFill", "artRotation", "artLayer" }
local BOOL_FIELDS  = { "mouseover", "accentEnabled", "artFlipH", "artFlipV" }
```
Then two helpers:
- `local function sanitizeNumbers(rec, t)` — the CLAMPED loop and the FREE_NUMBERS loop. CCN 3.
- `local function sanitizeTokens(rec, t)` — NONEMPTY_STRINGS, POINT_FIELDS, COLOR_VALUES, ENUM_FIELDS, BOOL_FIELDS and the existing C.COLOR_FIELDS flag loop. CCN ~8.
R.Sanitize keeps what is genuinely irregular, so it still reads as the record's story: the type guard, `rec.name` via Util.CleanName, `rec.enabled = (rec.enabled ~= false)` (NOT a BOOL_FIELDS row — the semantics differ), the frameName stamp-if-missing block, `rec.strata` (its own predicate), `rec.accentEdges` (empty set is legitimate), `rec.artCustomPath` (empty string is legitimate), then the two helper calls and `return rec`. CCN ~8.
Every per-field comment that carries a real decision (offsets not screen-clamped, media names not validated against live LSM, artTexture not validated against the catalog, the empty-edge-set and empty-custom-path carve-outs, why the enums snap back) must move onto the corresponding table row or stay on the explicit statement — those comments are why this file is readable and none may be dropped.

**Must not change.** Three carve-outs must survive the tabling: `enabled` is `~= false` (nil means enabled), an EMPTY accentEdges table must not be repopulated with the template's TOP, and an EMPTY artCustomPath string must survive (the user has picked Custom and not typed the path yet). Also: x/y/artX/artY stay unclamped, and no media or artwork name may be validated here — an art pack registering later must not have had the user's choice rewritten to the default on first touch. Field ORDER is not behaviorally significant (each rule reads rec and t and writes one distinct key), but the frameName block must still run after rec.name is cleaned.

**Coverage.** tests/test_registry.lua, tests/test_panel.lua, tests/test_accent.lua, tests/test_artwork.lua, tests/test_media.lua and tests/test_constants.lua all call R.Sanitize directly. test_constants.lua already cross-checks the template against the field tables, which is the natural home for a new rule-table-vs-C.PANEL_FIELD_TYPE consistency assertion once the tables exist.

---

### `(anonymous) — the stubFrame __index metamethod` — CCN 33 → target 5

`tests/wow_mock.lua:80-200` · pattern `mock-index-dispatch` · risk **low**

**What it does.** The headless WoW frame stub's metatable __index: given a method name, returns a closure implementing it. Models visibility, points, size, scale, alpha, strata/level, mouse, color, text, backdrop, texture+wrap, blend, clipping and tex-coords as real recorded state, and answers any other PascalCase key with a no-op returning the frame.

**Where the branches come from.** Thirty-plus sequential `if k == "MethodName" then return function ... end` arms in one metamethod. Lizard anchors the warning at 125-200 (its Lua parser splits the body at a nested closure), but the chain really runs 80-200. Every arm is one branch; `Hide` adds three more (`was`, `f.__onHide`, the ipairs loop), `SetShown` and `HookScript` add their own, and the trailing `type(k) == "string" and k:match("^%u")` adds two.

**Fix.** Replace the chain with a module-level table of method FACTORIES, built once at file load — `k` is already an exact-match string compare, so this is a mechanical and total conversion:
```lua
-- method name -> factory(f) -> the bound closure. Built once; __index becomes a lookup.
local METHOD = {}
METHOD.Show = function(f) return function() f.__shown = true; return f end end
METHOD.Hide = function(f) return function()
  local was = f.__shown
  f.__shown = false
  if was and f.__onHide then for _, fn in ipairs(f.__onHide) do fn(f) end end
  return f
end end
METHOD.SetShown = function(f) return function(_, v) if v then f:Show() else f:Hide() end; return f end end
METHOD.IsShown = function(f) return function() return f.__shown end end
METHOD.IsVisible = METHOD.IsShown
METHOD.CreateTexture = function() return function() return stubFrame() end end
METHOD.CreateFontString = METHOD.CreateTexture
```
The two dozen trivial recorders collapse further with three generic factories, which is where most of the CCN goes:
```lua
local function reader(key, default)
  return function(f) return function() local v = f[key]; if v == nil then return default end return v end end
end
local function writer(key) return function(f) return function(_, v) f[key] = v; return f end end end
local function rgbaWriter(key)
  return function(f) return function(_, r, g, b, a) f[key] = { r, g, b, a }; return f end end
end
METHOD.GetWidth = reader("__w"); METHOD.SetWidth = writer("__w")
METHOD.GetScale = reader("__scale", 1); METHOD.SetScale = writer("__scale")
METHOD.SetColorTexture = rgbaWriter("__color"); METHOD.SetVertexColor = rgbaWriter("__color")
```
(`SetSize`, `SetPoint`, `GetPoint`, `GetNumPoints`, `ClearAllPoints`, `SetTexture`, `EnableMouse`, `SetClipsChildren`, `SetTexCoord`, `HookScript`, `SetScript`, `GetScript` keep bespoke factories — they are not simple key writes.)
The metamethod then reads:
```lua
setmetatable(f, { __index = function(_, k)
  local make = METHOD[k]
  if make then return make(f) end
  if type(k) == "string" and k:match("^%u") then return function() return f end end
  return nil
end })
```
CCN 4. Allocation is unchanged: the old chain also built a fresh closure on every __index miss, and this is test-only code with no frame budget.

**Must not change.** The lowercase-key-misses-to-nil rule is the whole point of the stub (it is what lets addon code do `if not f.someCustomField then f.someCustomField = ... end`), so the PascalCase fall-through must stay AFTER the table lookup and must still return nil for everything else. Frames start SHOWN (divergence 2 in the file header; 34 IsShown assertions rest on it). GetWidth/GetHeight must keep returning the recorded value INCLUDING 0, and GetScale must default to 1 — hence `reader`'s explicit nil check rather than an `or`, since `or` would turn a recorded 0 or false into the default, which is precisely the bug the current explicit code avoids. SetTexture must keep recording wrapH/wrapV (tiled-artwork correctness lives entirely there). SetTexCoord must keep the flat 8-number list in SetTexCoord's own UL,LL,UR,LR order. CreateTexture/CreateFontString must return a FRESH stub, never f — aliasing them onto the parent collapses every accent edge into one color slot.

**Coverage.** NONE directly. Indirectly everything — every suite in tests/ builds frames through this stub, so a break is loud and immediate, but nothing asserts on the stub itself (tests/test_harness.lua is the closest and does not cover the method table). Write a small direct characterization test first: points round-trip through SetPoint/GetPoint in both overloads, Hide fires __onHide exactly once, GetScale defaults to 1, GetWidth returns a recorded 0, a lowercase key is nil, CreateTexture is not the parent.

---

### `R:Set` — CCN 29 → target 8

`modules/Registry.lua:652-762` · pattern `elseif-dispatch` · risk **low**

**What it does.** The single write seam for a panel field. Resolves the panel, looks the field's kind up in C.PANEL_FIELD_TYPE, coerces and validates the incoming value for that kind, writes it, re-sanitizes, logs once and broadcasts PanelChanged.

**Where the branches come from.** A nine-arm if/elseif chain on `kind` (number, boolean, point, strata, color, edges, media, enum, artwork), each arm carrying its own nested validation and its own bespoke rejection message. media and artwork each add a case-insensitive linear scan with an inner `if`; edges and color each add a `type(value) ~= "table"` outer guard around a parse-or-reject; enum adds two separate failure modes (no list = Constants bug, no match = user error).

**Fix.** Table-driven coercion, one function per kind, built once at file load above R:Set:
```lua
-- kind -> coerce(value, field) returning (value) on success or (nil, reason) on rejection.
-- A kind absent from this table is stored verbatim: that is "string" (artCustomPath), which is
-- exactly what the old chain's fall-through did.
local COERCE = {}
function COERCE.number(value)  local n = tonumber(value); if n == nil then return nil, "expected a number" end return n end
function COERCE.boolean(value) local p = Util.ParseBool(value); if p == nil then return nil, Util.BOOL_USAGE end return p end
function COERCE.point(value)   value = tostring(value):upper(); if not Util.IsPoint(value) then return nil, "expected one of: " .. table.concat(C.POINTS, ", ") end return value end
function COERCE.strata(value)  ... end
function COERCE.color(value)   ... end
function COERCE.edges(value)   ... end   -- Util.EdgeSet applied on BOTH paths, as today
function COERCE.media(value, field) ... end
function COERCE.enum(value, field)  ... end
function COERCE.artwork(value)      ... end
```
The two linear scans share one helper: `local function matchCaseInsensitive(list, value)` returning the canonical member or nil. COERCE.media uses it over NS.Compat.MediaList(C.PANEL_FIELD_MEDIA[field]); COERCE.artwork still walks NS.Artwork.List() itself because it collects `ids` as a side effect for the rejection message — so give it `local function artworkIds()` returning the id list and match over that.
R:Set becomes: resolve guard -> kind guard -> `if field == "name" then return R:Rename(rec.id, value) end` -> `local fn = COERCE[kind]; if fn then local v, err = fn(value, field); if err then return false, err end; value = v end` -> write, R.Sanitize, NS.DebugBuild, fire, return true. CCN ~8. Largest coercer is media/artwork/enum at CCN ~4.

**Must not change.** Rejection STRINGS are user-visible CLI output and several are asserted in tests/test_slash.lua — reproduce them verbatim, including the `:lower()` on the edges list and the `("unknown %s texture. Available: %s")` format. Precedence must not move: resolve, then unknown-field, then the `name` reroute to R:Rename, then coercion. The `edges` arm applies Util.EdgeSet AFTER the branch on both the parsed and the already-a-table path — that copy is what stops a caller mutating the stored set behind the seam, so an early return from the table branch would silently alias it. `enum` must keep its two failures apart (missing list is a Constants bug, no match is user error). `string`-kind fields must remain uncoerced.

**Coverage.** tests/test_panel.lua and tests/test_slash.lua exercise the coercion arms and assert rejection text; tests/test_media.lua the media arm, tests/test_accent.lua the edges arm, tests/test_artwork.lua the artwork and enum arms, tests/test_debuglog.lua the write-seam DebugBuild logging. Good per-arm coverage.

---

### `Canvas.BuildSpec` — CCN 24 → target 9

`modules/Canvas.lua:47-126` · pattern `options-builder` · risk **low**

**What it does.** Pure record+settings to render-spec function: validates and defaults every visual field of a panel into one flat table (geometry, strata/level, alpha and mouseover fade, background and border, the accent sub-table, and the artwork spec delegated to Artwork.BuildArtSpec).

**Where the branches come from.** About twenty defaulting expressions inside a single table constructor: 12 Util.Clamp calls, 3 `Util.IsPoint/IsStrata(x) and x or default` pairs (two branches each), 5 `rec.f or C.PANEL_TEMPLATE.f`, 3 `x and true or false`, the two-term `shown` fold, the `mouseover and math.min(...) or alpha` conditional, and the `NS.Artwork and ... or nil` guard. No nesting; it is one long value list with the accent sub-table nested inside it.

**Fix.** Split the one table constructor into three writers that each own a coherent slice of the spec and mutate it in place — no return-tuple gymnastics, and no allocation beyond the accent sub-table the current code already builds.
Add above BuildSpec:
- `local function addGeometry(spec, rec)` — width, height (Util.Clamp with C.MIN_SIZE/C.MAX_SIZE), scale, point, relPoint, x, y, strata, level. CCN ~8. Carries the comment explaining why scale is NOT folded into width/height.
- `local function addAppearance(spec, rec)` — alpha, mouseover, mouseoverAlpha, bg, border, bgTexture, borderTexture, borderSize, borderOffset. CCN ~7. Carries the zero-border comment and the mouseoverAlpha `math.min(..., alpha)` comment.
- `local function buildAccentSpec(rec)` — returns the accent sub-table verbatim from lines 98-116. CCN ~9. Already a self-contained unit with its own header comment.
BuildSpec becomes:
```lua
function Canvas.BuildSpec(rec, settings)
  if type(rec) ~= "table" then return nil end
  settings = settings or {}
  local spec = {
    id = rec.id, name = rec.name,
    frameName = NS.Registry.FrameName(rec),
    shown = (settings.enabled ~= false) and (rec.enabled ~= false),
  }
  addGeometry(spec, rec)
  addAppearance(spec, rec)
  spec.accent = buildAccentSpec(rec)
  spec.art = NS.Artwork and NS.Artwork.BuildArtSpec(rec, spec.width, spec.height) or nil
  return spec
end
```
CCN ~6. The art call now reads `spec.width`/`spec.height`, which makes the existing hoist comment structurally enforced rather than a convention.

**Must not change.** Artwork must be fitted to the CLAMPED width/height, never the raw record fields — the hoist comment at lines 52-54 documents exactly that bug. `shown` is the fold of two independent `~= false` switches, so nil on either means enabled. mouseoverAlpha must stay capped at `alpha` (a resting alpha above the hover alpha would make the panel fade ON mouseover). borderSize 0 is a real user choice — a plain block with no outline — and must not be floored to 1. The NS.Artwork guard exists so a partial load or a harness without the module yields a panel with no art rather than an error out of the spec builder, which every render path calls.

**Coverage.** Heavy: tests/test_canvas.lua, tests/test_panel.lua, tests/test_accent.lua (the whole accent sub-table), tests/test_media.lua (bg/border texture defaulting), tests/test_artwork.lua (the clamped-size handoff) and tests/test_registry.lua. Safe without new characterization tests.

---

### `S.Themes` — CCN 22 → target 6

`modules/SunnArt.lua:303-363` · pattern `two-pass-collector` · risk **low**

**What it does.** Enumerates every installed SunnArt theme as {file, name, sections, overlap, folder} in a stable (folder, name, file) order, merging live registrations from all sources with the known-pack manifest fallback for themes nothing registered.

**Where the branches come from.** Two collection passes plus a sort in one body. Pass one is a nested `for _, names in ipairs(sources())` / `for file, name in pairs(names)` with a five-term guard (`type(file) == "string" and file ~= "" and not RESERVED[file] and type(name) == "string" and folderInstalled(...)`), then a three-branch sections clamp, then a seen/new if/else. Pass two repeats the same three-branch sections clamp behind a three-term guard over NS.SunnArtPacks. The sort comparator adds two more branches and allocates a closure per call.

**Fix.** Four file-local extractions plus a hoisted comparator, all above S.Themes:
1. `local function clampSections(v)` — `local n = math.floor(tonumber(v) or DEFAULT_SECTIONS); if n < 1 then return 1 elseif n > MAX_SECTIONS then return MAX_SECTIONS end; return n`. CCN 4. This kills a genuine duplication: lines 311-313 and 340-341 are the same three-branch clamp written twice, in two different spellings (the first floors after the `or DEFAULT_SECTIONS`, the second floors around it — same result, two shapes to keep in step).
2. `local function isRegisterable(file, name, folders)` — the five-term guard. CCN 6.
3. `local function collectRegistered(seen, list, folders, panels, overlaps)` — the nested source loop, now `if isRegisterable(file, name, folders) then ... end` with the seen/new if/else and clampSections. CCN ~6. Keeps the later-sources-win-the-name comment.
4. `local function collectKnownPacks(seen, list, folders)` — the manifest fallback loop with the `known = true` marker. CCN ~5. Keeps the comment about `seen` being the whole test.
5. `local function byFolderNameFile(a, b)` at module level — the comparator hoisted out so it is created once at load rather than per call.  CCN 3.
S.Themes becomes six lines: `local panels, overlaps = meta(); local folders = addonFolders(); local seen, list = {}, {}; collectRegistered(seen, list, folders, panels, overlaps); collectKnownPacks(seen, list, folders); table.sort(list, byFolderNameFile); return list`. CCN 1.

**Must not change.** Later sources must win the NAME while sections and overlap stay from their own merge (the comment at lines 314-316) — the `seen[file].name = name` branch, not a wholesale replace. The manifest fallback must add ONLY themes nothing registered, with `seen` as the whole test, so live registration wins by construction rather than by an ordering rule that can be got backwards. The (folder, name, file) sort must stay stable across sessions — a dropdown that reshuffles between logins is the bug it exists to prevent, and that ordering is the only genuinely in-game-visible part.

**Coverage.** tests/test_sunnart.lua (692 lines) covers S.Themes including the manifest fallback and the `known` marker. Adequate.

---

### `D:Diagnose` — CCN 21 → target 8

`core/DebugLogSetup.lua:33-76` · pattern `guard-stack` · risk **low**

**What it does.** The `/pm debug dump` structured dump: returns a list of lines describing what the addon believes is on screen right now — master/unlock/preview/snap settings, screen size and scale, every registry record with its geometry, media and frame presence, and the active/pooled/orphaned frame counts. Attached on both the library and the degraded path because it reads the addon's own state.

**Where the branches come from.** Almost entirely `and`/`or` short-circuits, because everything is resolved at CALL time to keep this file above the modules it reports on: `(NS.db and NS.db.profile and NS.db.profile.settings) or {}` (3), `NS.Canvas and NS.Canvas:FrameFor(rec.id)` (1), `f and "yes" or "NO"` (2), `(rec.bgClassColor or rec.borderClassColor) and " classcolor" or ""` (3), `NS.Unlock and NS.Unlock:IsPanelUnlocked(rec.id) and " UNLOCKED" or ""` (3), `(NS.Canvas and NS.Canvas.__active) or {}` twice (4), `(NS.Canvas and NS.Canvas.PooledCount and NS.Canvas.PooledCount()) or 0` (3). Plus the record loop, the orphan loop, the inline IIFE that counts __active, and `add`'s own `select("#", ...) > 0 and ... or ...`.

**Fix.** Extract four file-local helpers above attachDiagnose — NOT inside it: they capture nothing, so hoisting means they are created once at load rather than once per attachDiagnose call (and attachDiagnose runs on both the library and the degraded path).
1. `local function activeFrames() return (NS.Canvas and NS.Canvas.__active) or {} end` — the doubly-repeated resolve, CCN 3, used by both the orphan loop and the count.
2. `local function addHeader(add)` — the settings line and the screen line, owning the `(NS.db and NS.db.profile and NS.db.profile.settings) or {}` resolve. CCN ~4.
3. `local function addPanel(add, rec)` — the two `add` calls for one record (the geometry line and the frame-name/media line), owning the `f and "yes" or "NO"`, classcolor and UNLOCKED short-circuits. CCN ~8. Keeps the comment about why the global name and the two media names belong in a pasted log.
4. `local function addFrames(add)` — replaces the inline IIFE at line 72 with a plain named count (`local n = 0; for _ in pairs(activeFrames()) do n = n + 1 end`), plus the orphan loop and the PooledCount resolve. CCN ~6. That IIFE is the least readable line in the file and should not survive the refactor.
D:Diagnose becomes: build `out` and the `add` closure, `addHeader(add)`, `local records = NS.Registry:All(); add("registry: %d panels", #records)`, `for _, rec in ipairs(records) do addPanel(add, rec) end`, `addFrames(add)`, `return out`. CCN ~2, and it now reads as the shape of the dump. `add` stays a per-call closure — it captures `out`, and Diagnose is invoked by hand from a slash verb, so there is no allocation concern.

**Must not change.** Everything must stay resolved at CALL time. The whole reason this file can sit in core/ above Registry, Canvas and Unlock is that nothing here holds a load-time upvalue on them (see the WHERE THIS FILE SITS header, lines 11-16) — a refactor that hoists `local Registry = NS.Registry` at file scope would invert a dependency and break the degraded path. The registry view and the renderer view must keep being printed together: a panel in the registry with no frame, or the reverse, is the shape of every rendering bug this addon can have. Diagnose must keep working on the degraded (no-LibKa0s) path, where it is attached to a plain table with stub methods.

**Coverage.** tests/test_debuglog.lua:163 ("reports the registry and the renderer together") and :178 ("works with logging off") — thin but real: one asserts a frame-bearing panel appears, one asserts a non-empty dump with logging off. Nothing asserts the orphan/pooled counts line; add a characterization test pinning that line before splitting addFrames out.

---

### `Sl:CliPanel` — CCN 17 → target 10

`settings/Slash.lua:113-177` · pattern `guard-stack` · risk **low**

**What it does.** The `/pm panel ...` CLI verb: parses `<name> [field] [value]`, resolves the panel (with `deleteall` as a verb only when nothing answers to that name), handles the `fitart` action, and otherwise dumps all fields, shows one field, or writes one field and echoes the stored result.

**Where the branches come from.** A stack of nine early-return guards, each a branch: the key match, the `not rec and key:lower() == "deleteall"` two-term guard with its own `type(StaticPopup_Show) == "function"` if/else and an `n == 1 and "panel" or "panels"` pluralization, the no-rec return, the two-step field/value match (`if not field then field = ... end`), the no-field dump, the `fitart` action with its own ok/else, the unknown-field return, the nil-value show, and the Set error path.

**Fix.** Extract the two ACTIONS — the parts that are not about parsing at all — plus the parse, as file-local helpers above Sl:CliPanel:
1. `local function doDeleteAll()` — the StaticPopup-or-fallback block including the pluralization. CCN 3. Keeps the comment about why the panel wins the name.
2. `local function doFitArt(rec)` — the FitToArtwork call and its two-branch echo. CCN 3. Keeps the comment about reading both axes back off the record so the MIN/MAX clamp shows rather than what the artwork asked for.
3. `local function parseFieldValue(tail)` — `local field, value = tail:match("^(%S+)%s+(.+)$"); if not field then field = tail:match("^(%S+)$") end; return field, value`. CCN 3.
CliPanel then reads as pure routing: parse key -> usage guard -> Resolve -> `if not rec and key:lower() == "deleteall" then return doDeleteAll() end` -> no-rec message -> `local field, value = parseFieldValue(tail)` -> no-field dump -> `if field:lower() == "fitart" then return doFitArt(rec) end` -> unknown-field message -> nil-value show -> Set + echo. CCN ~10.
This is the one function on the list whose residual CCN is honest structure rather than a smell: every remaining guard is a distinct user-facing outcome with its own message. 10 is comfortably under the bar and splitting further would only scatter the routing across helpers nobody can follow.

**Must not change.** Precedence is the contract and must not move: the PANEL wins the name over `deleteall` (someone who names a panel "deleteall" can still edit it from the CLI, and the wipe becomes reachable again the moment that panel is gone), and `fitart` is checked BEFORE the field table for the same reason. The StaticPopup fallback exists so the headless suite can drive DeleteAll without a popup — `type(StaticPopup_Show) == "function"` must stay the test, not a nil check on a different global. Every echo reads the STORED value back through NS.Registry:Get/FormatField so clamping and coercion show, never the value the user typed.

**Coverage.** tests/test_slash.lua (436 lines, 92 functions) covers CliPanel including the deleteall precedence and the fitart action. Good.

---

### `release (frame pool release)` — CCN 17 → target 6

`modules/Canvas.lua:585-624` · pattern `guard-stack` · risk **low**

**What it does.** Returns a panel frame to the name-keyed pool: hides it, clears its points and mouse, untracks its mouseover fade, tears down the border backdrop, the four accent bars and their borders, clears the artwork textures, strips the unlock overlay, and files it under its frame name.

**Where the branches come from.** A guard stack plus a duplicated teardown idiom. `if X.borderFrame and type(X.borderFrame.SetBackdrop) == "function"` appears twice — once for f.borderFrame, once inside the accent-bar loop for bar.borderFrame — at two branches each. Then `for _, bar in pairs(f.accents or {})` (2), `if f.artFrame`, `if f.artTextures` plus its ipairs loop, `if NS.Unlock and NS.Unlock.StripOverlay` (2), `f.__frameName or (f.GetName and f:GetName())` (2), `if f.panelID`, and the final `type(name) == "string"` test.

**Fix.** Extract the duplicated idiom and the two independent teardowns as file-local helpers above `release`:
1. `local function clearBackdrop(owner)` — `if owner and owner.borderFrame and type(owner.borderFrame.SetBackdrop) == "function" then owner.borderFrame:SetBackdrop(nil); owner.borderFrame:Hide() end`. CCN 4. Called for the panel frame AND for each accent bar, which removes the copy outright.
2. `local function releaseAccents(f)` — `for _, bar in pairs(f.accents or {}) do bar:Hide(); clearBackdrop(bar) end`. CCN 3. Keeps the comment about bars being anchored OUTSIDE the panel's bounds, so a pooled frame that kept them leaves four colored strips floating.
3. `local function releaseArt(f)` — the artFrame hide plus the artTextures SetTexture(nil) loop. CCN 4. Keeps the comment about why a released frame must be inert rather than merely hidden.
4. `local function poolName(f)` — `local name = f.__frameName or (f.GetName and f:GetName()); if type(name) == "string" then return name end return nil`. CCN 4. Keeps the comment about __frameName being the authority because the headless stub answers every PascalCase call with itself, so GetName() there returns a table and would key the pool on a frame object.
`release` becomes: `if not f then return end`, the Hide/ClearAllPoints/EnableMouse/__spec block, the SetMouseoverTracked untrack, `f.panelID = nil`, `clearBackdrop(f)`, `releaseAccents(f)`, `releaseArt(f)`, the Unlock strip guard, `local name = poolName(f); if name then pool[name] = f end`. CCN ~6.

**Must not change.** ORDER: `f.panelID` must be cleared only AFTER SetMouseoverTracked reads it, or the mouseover ticker keeps driving a dead panel. `f.__frameName` must stay the pool key authority over GetName() — that is what stops the headless stub keying the pool on a frame object. A released frame must end up inert, not merely hidden: the accent bars are anchored outside the panel bounds and would leave four colored strips floating, and an uncleared art texture puts the previous panel's artwork on screen for the next one (Unlock's overlay, a debug dump or a stray Show all reach a pooled frame before applySpec runs again). Those two are in-game-only symptoms — headlessly you can only assert the pool count and that Hide/SetTexture(nil) were called.

**Coverage.** tests/test_canvas.lua asserts the pool count grows by one when a panel is deleted (line 164) and that active+pooled is conserved (line 144); tests/test_accent.lua and tests/test_artwork.lua drive frames through the pool. Nothing directly asserts that a released frame's accent bars and art textures were cleared — add a characterization test on __color/__texture/__backdrop being nil after release before touching this.

---
