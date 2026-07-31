# Test Cases

The full inventory of every headless test case, grouped by suite. This file is the
**authoritative pass count** for the addon.

**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`
whenever the suite changes (see [testing.md](testing.md)).

### test_util.lua (27)

- Util.SplitPath: splits a dotted path
- Util.SplitPath: a single segment is one part
- Util.Clamp: passes a value already in range
- Util.Clamp: clamps below and above
- Util.Clamp: a non-number falls back, then to the low bound
- Util.Round: rounds away from zero on both signs
- Util.Snap: a grid of 1 or less is the identity
- Util.Snap: rounds to the nearest multiple
- Util.ParseBool: accepts every documented token, in any casing
- Util.ParseBool: a boolean passes straight through
- Util.ParseBool: an unrecognized token is nil, NOT false (F-023)
- Util.Color: fills a missing alpha with 1
- Util.Color: clamps out-of-range components
- Util.Color: a non-table falls back rather than erroring
- Util.ParseColor: reads a 0-1 triple and defaults alpha
- Util.ParseColor: reads a 0-255 tuple and scales it
- Util.ParseColor: the byte decision reads RGB only
- Util.ParseColor: rejects junk and wrong-length input
- Util.FormatColor: round-trips through ParseColor
- Util.CleanName: trims and collapses whitespace
- Util.CleanName: empty and whitespace-only names are nil
- Util.DeepCopy: copies nested tables rather than aliasing
- Util.IsPoint / IsStrata: accept valid tokens, reject the rest
- NS.SafeToString: renders ordinary values and booleans
- NS.IsConcatSafe: a plain value is concat-safe
- NS.Print: prepends the cyan [PM] tag
- NS.Print survived the AceConsole embed (architecture-§2)

### test_compat.lua (14)

- Compat.GetAddOnMetadata: reads the TOC Version through C_AddOns
- Compat.GetAddOnMetadata: an unknown field is nil, not an error
- Compat.GetScreenSize: returns the UIParent dimensions
- Compat.GetUIScale: defaults to 1 when the frame cannot answer
- Compat.FetchMedia: degrades to the flat texture when LibSharedMedia is absent
- Compat.FetchMedia: an unresolvable name falls back rather than rendering nothing
- Compat.FetchMedia: 'None' is an explicit choice and resolves to nil
- Compat.MediaList: always offers None first, then the built-in flat texture
- Compat.MediaList: never lists a name twice
- Compat.RegisterMedia: reports failure without LibSharedMedia rather than erroring
- Compat.GetClassColor: reads RAID_CLASS_COLORS by classFile token
- Compat.GetClassColor: an unknown class is nil, not white
- Compat.MouseIsOver: answers without the frame taking mouse input
- Compat owns the deprecated-API surface: no flavor branching in the addon

### test_constants.lua (16)

- Constants: the strata list runs lowest to highest and starts at BACKGROUND
- Constants: new panels default to LOW
- Constants: new panels default to CENTER at 0,0
- Constants: STRATA_SET agrees with STRATA
- Constants: nine anchor points, all in POINT_SET
- Constants: STRATA_OPTIONS is dropdown-shaped
- Constants: every template field has a declared type
- Constants: every typed field appears in the display order
- Constants: the template's own values are valid by its own rules
- Constants: the editor's offset reach is named, symmetric and wide enough to be useful
- Constants: no slider in the panel editor decides its own bounds
- Constants: preview panels are valid panel overrides
- Constants: the mono font and logo point at this addon's folder
- Constants: the logo file named by LOGO_PATH exists
- Constants: the logo is a Targa, which is the only format WoW loads at runtime
- Constants: the debug console's mono font exists

### test_registry.lua (41)

- Registry.New: creates a panel with the template's shape
- Registry.New: rejects an empty name
- Registry.New: rejects a duplicate name, case-insensitively
- Registry.New: ids are never reused after a delete
- Registry.New: applies the profile's default strata and alpha
- Registry.New: overrides are applied but cannot set the id
- Registry.New: does not alias the shared template
- Registry.Delete: removes the panel and reports its name
- Registry.Delete: an unknown panel is an error, not a silent no-op
- Registry.DeleteAll: empties the registry and reports the count
- Registry.DeleteAll: drops the session state keyed on the panels it removed (F-020)
- Registry.Resolve: finds by name and by id
- Registry.Resolve: a name wins over an id that looks like it
- Registry.Rename: renames and reports the old name
- Registry.Rename: re-casing a panel's own name is allowed
- Registry.Rename: rejects a collision with a different panel
- Registry.Sanitize: clamps size into range
- Registry.Sanitize: repairs invalid anchor and strata tokens
- Registry.Sanitize: a string size from a hand-edited SV becomes a number
- Registry.Sanitize: does NOT clamp offsets to the screen
- Registry.Sanitize: enabled defaults to true, and only explicit false disables
- Registry.Set: writes a number field
- Registry.Set: coerces a CLI string to the field's type
- Registry.Set: an unreadable boolean is refused, not stored as false (F-023)
- Registry.Set: parses a color string
- Registry.Set: rejects an unknown field
- Registry.Set: rejects an invalid anchor with a helpful message
- Registry.Set: accepts a lower-case anchor and stores it upper-case
- Registry.Set: writing `name` routes through Rename's uniqueness check
- Registry.Set: clamps out-of-range input rather than rejecting it
- Registry.SetPosition: writes both coordinates at once
- Registry.FormatField: renders each field type readably
- Registry.CopyFrom: never spreads the preview marker onto a real panel
- Registry.NewBatch: creates every spec and broadcasts once
- Registry.NewBatch: skips a spec whose name is taken, keeping the rest
- Registry.Recover: leaves an on-screen TOPLEFT panel alone
- Registry.Recover: still rescues a genuinely off-screen TOPLEFT panel
- Registry.Recover: survives a record whose anchor is missing or junk (F-006)
- Registry.Recover: leaves on-screen panels alone
- Registry.Recover: pulls an off-screen panel back into view
- Registry: the panel messages have exactly one sender

### test_canvas.lua (27)

- Canvas.BuildSpec: carries the record's geometry through
- Canvas.BuildSpec: repairs invalid values rather than passing them to a frame
- Canvas.BuildSpec: shown requires BOTH the master switch and the panel's own
- Canvas.BuildSpec: a missing settings table means shown
- Canvas.BuildSpec: a zero border is honoured, not floored to 1
- Canvas.BuildSpec: normalizes colors to four clamped components
- Canvas.BuildSpec: a non-table record is nil, not a crash
- Canvas.Render: builds a frame and applies the spec's size
- Canvas.Render: applies the anchor point and offsets
- Canvas.Render: re-rendering does not accumulate anchor points
- Canvas.Render: reuses the same frame for the same panel
- Canvas.Render: a disabled panel's frame is hidden, not destroyed
- Canvas.Render: the master switch hides every panel
- Canvas.Render: a deleted record retires its frame
- Canvas.RenderAll: renders every record and retires nothing else
- Canvas: frames are pooled, not leaked (hard rule #14)
- Canvas: a delete returns its frame to the pool
- Canvas: a re-created panel gets its own frame back
- Canvas: a DIFFERENT panel name gets a different frame
- Canvas: a released frame is mouse-disabled again
- Canvas: a released frame stops claiming a panel id (F-024)
- Canvas: the bus repaints on a registry change
- Canvas: a settings change repaints
- Canvas: a grid-only settings write does NOT repaint (F-012)
- Canvas: showLabels still repaints — the unlock overlay reads it (F-012)
- Canvas: OnEnable subscribes the renderer to the bus
- Canvas: consumers register on their own bus target (architecture-§4)

### test_unlock.lua (28)

- Unlock.SnapPosition: snapping off just rounds
- Unlock.SnapPosition: snaps to the configured grid
- Unlock.SnapPosition: snapping is symmetric across zero
- Unlock.SnapPosition: an out-of-range grid is clamped, not obeyed
- Unlock.SnapPosition: a missing settings table does not error
- Unlock.SetUnlocked: flips the session flag
- Unlock.Toggle: alternates
- Unlock: unlocking during combat is deferred, not applied
- Unlock: the deferred unlock is replayed when combat ends
- Unlock: ResumePending is a no-op with nothing queued
- Unlock: LOCKING during combat is never deferred
- Unlock: locking clears a queued unlock
- Unlock: an unlocked panel takes the mouse; a locked one does not
- Unlock: a DISABLED panel is still shown while unlocked
- Unlock: the drag handler writes the dropped position back to the record
- Unlock: the drag handler ignores a frame whose record is gone
- Unlock.SetPreview: adds the sample panels and turns unlock on
- Unlock.SetPreview: off removes exactly what it added
- Unlock.SetPreview: preview panels really render
- Unlock.SetPreview: a name collision skips that placeholder, not the whole preview
- Unlock.SetPreview: turning it on twice is a no-op
- Unlock.SetPreview: every placeholder carries the preview marker
- Unlock.SetPreview: each transition broadcasts the panel set ONCE
- Unlock.SetPreview: leaving preview puts the lock back through SetUnlocked
- Unlock.SetPreview: preview during combat applies whole, it is never queued (F-014)
- Unlock.SetPreview: previewing while already unlocked in combat queues nothing (F-014)
- Unlock: the global combat gate still defers a plain unlock (F-014)
- Unlock.TogglePreview: alternates

### test_media.lua (79)

- Util.Slugify: keeps alphanumerics and collapses everything else
- Util.Slugify: trims leading and trailing separators
- Util.Slugify: preserves case
- Util.Slugify: a name with no alphanumerics falls back rather than slugging to empty
- Util.Slugify: is deterministic
- Util.FrameName: prefixes the slug
- Registry.FrameName: matches Util.FrameName for a record
- Canvas: the frame is created under its deterministic global name
- Registry.New: refuses a name whose slug collides with an existing panel
- Registry.Rename: refuses a slug collision too
- Registry.Rename: a panel may still be renamed to its own slug
- Canvas: renaming a panel moves it to a new frame
- Constants: new panels default to the solid texture on both surfaces
- Constants: both media fields declare their LSM media type
- Canvas.BuildSpec: carries both texture names
- Canvas.BuildSpec: a missing texture name falls back to the template's
- Canvas: the background is drawn with the resolved texture path
- Canvas: the border is drawn as a backdrop edge, at the set thickness
- Canvas: the border color is applied AFTER the backdrop
- Canvas: the border picks up a color change
- Canvas: the border takes the class color too
- Canvas: a zero border applies no backdrop at all
- Canvas: the 'None' border texture removes the border
- Canvas: dropping the border to zero clears an existing backdrop
- Canvas.BuildSpec: carries the border offset
- Canvas.BuildSpec: clamps the border offset
- Canvas: a positive border offset pushes the border outward
- Canvas: a negative border offset pulls the border inward
- Canvas: a zero border offset sits exactly on the panel edge
- Canvas: the border frame is re-anchored, not accumulated, on repaint
- Registry.Sanitize: clamps the border offset
- Registry.Reset: restores every appearance field to the template
- Registry.Reset: restores position and anchor too
- Registry.Reset: keeps the panel's id and name
- Registry.Reset: applies the profile's New-Panel-Defaults, like New does
- Registry.Reset: clears class-color flags
- Registry.Reset: does not alias the shared template
- Registry.Reset: repaints the panel
- Registry.Reset: an unknown panel is an error, not a silent no-op
- Registry.Reset: leaves other panels alone
- Border: class color and a picked color produce the same backdrop
- Border: class color preserves the picked color's ALPHA exactly
- Border: only the RGB differs between the two modes
- Accent bar: class color likewise preserves alpha
- Canvas: the background color is applied to the fill texture
- Canvas: the background picks up a color change
- Registry.Set: a media name is matched case-insensitively against the live list
- Registry.Set: an unknown media name is refused with the available list
- Registry.Sanitize: does NOT rewrite an unresolvable texture name
- Registry.Sanitize: an empty or non-string texture falls back to the default
- Constants: every class-color flag names a real color field
- Util.ResolveColor: returns the stored color when the flag is off
- Util.ResolveColor: the class color replaces RGB but keeps the stored alpha
- Util.ResolveColor: falls back to the stored color when the class is unknown
- Util.ResolveColor: a color with no class-color companion is returned as stored
- Canvas.BuildSpec: applies the class color to the background
- Canvas.BuildSpec: applies the class color to the border independently
- Registry.Set: the class-color flags coerce from the CLI
- Registry.Sanitize: class-color flags are always booleans
- Canvas.BuildSpec: mouseover off means the resting alpha IS the alpha
- Canvas.BuildSpec: mouseover on carries the faded resting alpha
- Canvas.BuildSpec: a faded alpha above the hover alpha is clamped down
- Canvas: a mouseover panel rests at its faded alpha
- Canvas: a mouseover panel rises to full alpha under the cursor
- Canvas: a mouseover panel never takes mouse input
- Canvas: only mouseover panels are tracked by the ticker
- Canvas: turning mouseover off untracks the panel and restores its alpha
- Canvas: a deleted mouseover panel leaves the ticker
- Canvas: an unlocked mouseover panel is held fully visible
- Canvas: a panel unlocked ON ITS OWN also suspends the fade
- Unlock.IsPanelUnlocked: false by default
- Unlock.SetPanelUnlocked: unlocks just that panel
- Unlock.IsPanelUnlocked: the global unlock covers every panel
- Unlock: a global lock clears the per-panel unlocks
- Unlock: a per-panel unlock during combat is deferred
- Unlock: a deferred per-panel unlock is replayed when combat ends
- Unlock: a panel deleted mid-combat is not resurrected on replay
- Registry.Delete: drops the panel's session unlock state
- Database: per-panel unlock state is NOT persisted

### test_accent.lua (63)

- Accent: ON by default — the accent bar is the shipped look
- Accent: the panel's OWN border is off, so only one thing defines the edge
- Accent: defaults to the top edge only
- Accent: defaults to 5px thick, flush against the panel
- Accent: the default bar texture is one LibSharedMedia always ships
- Accent: defaults to CLASS color
- Accent: the class-color flag is wired into the generic color map
- Accent: the bar texture selects from the statusbar pool
- Accent: every accent field is typed and in the dump order
- Util.EdgeSet: keeps only real edges, normalized to true
- Util.EdgeSet: a non-table is the empty set, not an error
- Util.ParseEdges: reads a comma list, any casing
- Util.ParseEdges: 'none' is the empty set
- Util.ParseEdges: rejects an unknown edge rather than dropping it
- Util.FormatEdges: always renders in the declared order
- Util.FormatEdges: the empty set prints (none)
- Util.FormatEdges: round-trips through ParseEdges
- Registry.Set: parses an edge list from the CLI
- Registry.Set: an unknown edge is refused with the valid list
- Registry.Set: an edge set is copied, not aliased
- Registry.Sanitize: an EMPTY edge set is preserved, not repopulated
- Registry.Sanitize: a non-table edge set falls back to the template's
- Registry.Sanitize: clamps thickness and offset
- Registry.Sanitize: thickness has a floor of 1, not 0
- Registry.FormatField: renders an edge set readably
- Registry.Reset: puts the accent bar back to the shipped defaults
- Canvas.BuildSpec: carries the accent settings
- Canvas.BuildSpec: clamps accent thickness and offset
- Canvas.BuildSpec: the accent color goes through the shared resolver
- Canvas.BuildSpec: accent class color is independent of the others
- Canvas: no accent bar is shown when the feature is off
- Canvas: enabling shows only the chosen edges
- Canvas: all four edges at once is legal
- Canvas: an empty edge set draws nothing even when enabled
- Canvas: the top bar spans the full edge and is offset outward
- Canvas: the bottom bar is offset downward
- Canvas: the left bar is vertical and offset leftward
- Canvas: the right bar is offset rightward
- Canvas: a negative offset pulls the bar over the panel
- Canvas: the bar is painted with the resolved color
- Canvas: the bar takes the class color by default
- Canvas: the bar is re-anchored, not accumulated, on repaint
- Canvas: toggling accents off hides the bars again
- Canvas: the accent bar draws ABOVE the border
- Canvas: the accent/border stacking survives a frame-level change
- Canvas: the accent bars live on their own child frame
- Accent border: a 1px BLACK hairline by default
- Accent border: its class-color flag is wired into the generic color map
- Accent border: selects from the BORDER media pool, not statusbar
- Canvas.BuildSpec: carries the accent border settings
- Canvas.BuildSpec: clamps the accent border to the panel border's bounds
- Canvas: no border frame is built when the bar has no border
- Canvas: the bar border is a backdrop edge at the set thickness
- Canvas: the bar border color is applied AFTER the backdrop
- Canvas: the bar border takes the class color
- Canvas: the bar border is offset from the bar
- Canvas: dropping the bar border to zero clears it
- Canvas: a 'None' bar border texture removes it
- Registry.Reset: puts the bar border back to the shipped hairline
- Canvas: a released frame hides its accent bars
- Canvas: a vertical bar rotates its texture 90 degrees
- Canvas: a horizontal bar draws its texture as authored
- Canvas: the orientation is re-applied on every repaint, not just the first

### test_database.lua (18)

- Database: InitDB opened both scopes
- Database: a fresh install ships the current schema version
- Database: the panel registry is per-profile, not global
- Database: every character starts on the shared 'Default' profile
- Database: a fresh profile ships no panels
- Database: the debug flag is NOT persisted (debug-logging-§5)
- Database: unlock state is NOT persisted
- Database.RunMigrations: is idempotent
- Database.RunMigrations: stamps a version onto an unstamped DB
- Database.RunMigrations: upgrades an older DB to the current version
- Database.RunMigrations: survives being called before the DB exists
- Database.MigrationSummary: is a pure, readable line
- Database.InitSummary: names the addon, version, schema, profile and count
- Database.SweepPreviewPanels: removes the marked records and nothing else
- Database.SweepPreviewPanels: is idempotent
- Database.SweepPreviewPanels: survives being called before the DB exists
- Database: InitDB sweeps preview orphans before anything can read the panels
- Database.InitSummary: survives a missing DB

### test_debuglog.lua (25)

- DebugLog.FormatPlain: '<ts> | [<tag>] <msg>' with no color codes
- DebugLog.FormatPlain: a nil tag renders as empty brackets, not 'nil'
- DebugLog.FormatColored: colors the timestamp and the tag
- DebugLog.FormatColored / FormatPlain: the two carry the same content
- DebugLog.Add: appends to the copy buffer
- DebugLog.Clear: empties the buffer
- NS.Debug: is a no-op when logging is off (zero-alloc gate)
- NS.Debug: writes when logging is on
- NS.Debug: formats varargs through the secret-safe stringifier
- NS.Debug: a boolean arg survives (booleans are never secret)
- DebugLog.SetEnabled: flips the session flag and brackets the log
- DebugLog.SetEnabled: the disable line lands AFTER the flag flips off
- DebugLog.SetEnabled: emits no [Init] summary on disable
- DebugLog.SetEnabled: the chat ack is color-coded ON green / OFF red
- DebugLog: the title-bar toggle drives the same seam
- DebugLog: window visibility is independent of the logging flag
- DebugLog.Toggle: alternates window visibility
- DebugLog.Diagnose: reports the registry and the renderer together
- DebugLog.Diagnose: works with logging off
- NS.Debug: call sites do not restate the gate
- NS.Debug: the ungated call sites still log when logging is on
- NS.Debug: the ungated call sites stay silent when logging is off
- NS.DebugBuild: does not call its builder when logging is off
- NS.DebugBuild: calls the builder and logs when logging is on
- NS.DebugBuild: passes the builder's arguments through unbound

### test_schema.lua (21)

- Schema.Register: every path resolves against the defaults (architecture-§5)
- Schema: every row declares a group, label, type and widget
- Schema: every row has a tooltip
- Schema: paths are unique
- Schema: session-only rows supply their own get and set
- Schema.FindRow: finds a real path and rejects a bogus one
- Schema.Get / Set: round-trip a boolean
- Schema.Set: rejects an unknown path
- Schema.Set: a failing validate blocks the write
- Schema.Set: validates the strata dropdown
- Schema.Set: a session-only row never touches the DB
- Schema.Set: a session-only row reads back through its own get
- Schema.Set: fires onChange
- Schema.Set: a table value is deep-copied, not aliased
- Schema.Default: returns the row's default, deep-copied
- Schema: the defaults match the shipped profile
- Schema: the master switch reaches the renderer
- Schema: a gridSize write still changes where the next drag lands (F-012)
- Schema: the settings message has exactly one sender
- Schema: the numeric rows declare min and max
- Schema: defaultAlpha stays a fraction

### test_slash.lua (55)

- Slash.Register: registers both the short verb and the full-name alias
- Slash.Version: prefers the TOC metadata over the in-code fallback
- Slash.PrintHelp: one row per command, plus a header
- Slash.PrintHelp: no line ends in a colon (slash-commands-§4)
- Slash.OnSlash: a bare command prints help
- Slash.OnSlash: dispatches from the COMMANDS table
- Slash.OnSlash: the verb is case-insensitive
- Slash.OnSlash: an unknown verb reports it and prints help
- Slash.BuildListLines: the header, then group headers, then rows
- Slash.BuildListLines: indentation is two spaces for groups, four for rows
- Slash.BuildListLines: lists every schema row exactly once
- Slash.LIST_GROUP_ORDER: every declared group actually exists
- Slash.LIST_GROUP_ORDER: covers every group in the schema
- Slash.FormatSchemaValue: applies a row's fmt to numbers
- Slash.FormatSchemaValue: booleans render true/false
- Slash.FormatKV: gold key, white value, no trailing colon
- Slash.CliGet: prints the key = value line
- Slash.CliGet: an unknown path is reported
- Slash.CliGet: with no argument, prints usage
- Slash.CliSet: writes and echoes the STORED value
- Slash.CliSet: coerces booleans from words
- Slash.CliSet: an unreadable boolean is refused, not stored as false (F-023)
- Slash.CliSet: accepts a lower-case dropdown token
- Slash.CliSet: a non-number for a number row is refused
- Slash.CliSet: a rejected validate is reported as an error
- Slash.CliReset: restores one setting's default
- Slash.CliResetAll: restores every setting and leaves panels alone
- Slash.CliVersion: prints v<version>
- Slash.CliNew: creates a panel and confirms
- Slash.CliNew: with no name, prints usage
- Slash.CliNew: a duplicate is reported as an error
- Slash.CliDelete: removes the panel
- Slash.CliRename: renames and reports both names
- Slash.CliRename: with one word, prints usage
- Slash.BuildPanelLines: an empty registry says so and suggests the next step
- Slash.BuildPanelLines: one row per panel, plus a header
- Slash.BuildPanelLines: a disabled panel is dimmed, not hidden
- Slash.CliPanel: with no field, dumps every field in the declared order
- Slash.CliPanel: with a field, prints just that field
- Slash.CliPanel: with a value, sets it and echoes the stored result
- Slash.CliPanel: the echo reflects clamping, not what was typed
- Slash.CliPanel: sets a color from a string
- Slash.CliPanel: an unknown panel is reported
- Slash.CliPanel: an unknown field lists the valid ones
- Slash.CliPanel deleteall: goes through the confirm popup
- Slash.CliPanel: a panel genuinely named 'deleteall' is still reachable (F-022)
- Slash.CliRecover: reports when nothing needed moving
- Slash.CliRecover: reports how many it moved
- Slash: every printed line carries the shared cyan tag
- COMMANDS: the table is defined beside its dispatcher
- COMMANDS: every entry has a name, description and function
- COMMANDS: names are unique and lower-case
- COMMANDS: the standard's required verbs are present (slash-commands-§3)
- COMMANDS: the descs name the sub-verbs their handlers accept (F-011)
- PrintHelp: the generated rows carry the sub-verbs too

### test_panel.lua (40)

- PanelEditor: the editor is its own module (architecture-§3)
- PanelEditor: the bus is wired at registration, not at first paint
- Panel: all four categories survive the peel and still build on OnShow (options-ui-§5)
- Panel.Register: the category is registered EAGERLY at load (options-ui-§1)
- Panel.Register: both subcategories are registered
- Panel.Register: is idempotent
- Panel.Register: a second attempt is made on PLAYER_LOGIN (F-013)
- Panel.Register: the retry is SUBSCRIBED before PLAYER_LOGIN fires (F-013)
- PanelEditor: a slider REACHES an out-of-range value rather than clamping it (F-003)
- Panel: every registered frame carries the framework contract (options-ui-§1)
- Panel: the body is built lazily — each page has an OnShow
- Panel: the Defaults button is NOT created at registration (anti-pattern #42)
- Panel: the pages that want a Defaults button declare the intent and park a callback
- Panel: the header Defaults action and Blizzard's OnDefault are the same function
- Panel: the landing page is the parent category, not a subcategory
- Panel.Open: refuses during combat and does NOT open (options-ui-§2)
- Panel.Open: the combat refusal is gray
- Panel.Open: does NOT defer-and-replay on leaving combat
- Panel.Open: opens out of combat
- Panel.Open: says so when there is no category to open (F-013)
- Panel.Refresh: a hidden page is not refreshed
- Panel.RestoreDefaults: resets settings and leaves panels alone
- Panel: every render context owns its own dropdown registry
- Panel: one page's rebuild does not deregister another page's dropdowns
- Panel: closing dropdowns dispatches on widget TYPE, not on field presence
- Panel: closing an unopened dropdown is a no-op, not an error
- Panel: an unknown widget type is skipped rather than guessed at
- Panel: the tracking registry is emptied between rebuilds
- Panel: deleting from the page rebuilds it exactly once (F-002)
- Panel: renaming from the page rebuilds it exactly once
- Panel: a rejected rename puts the old name back and does not rebuild
- Panel: creating from the page rebuilds once and lands on the NEW panel
- Panel: a refused create leaves the typed name alone and does not rebuild
- Panel: deleting the LAST panel reaches the empty-state branch cleanly
- Panel: a field change on the SELECTED panel refreshes in place and never rebuilds
- Panel: a field change on a DIFFERENT panel neither refreshes nor rebuilds
- Panel: a hidden page is only marked dirty by a field change, never refreshed
- Panel: a rebuild drops the old refreshers before it releases their widgets
- Panel: the Panels page's Defaults action is confirm-gated
- Tagline: the landing page, the TOC Notes and the README say one thing (F-019)

### test_profiles.lua (21)

- Registry.CopyFrom: copies appearance across
- Registry.CopyFrom: does NOT copy position
- Registry.CopyFrom: does NOT copy identity
- Registry.CopyFrom: DOES copy size
- Registry.CopyFrom: colors are deep-copied, not shared
- Registry.CopyFrom: edge sets are deep-copied too
- Registry.CopyFrom: refuses to copy from itself
- Registry.CopyFrom: an unknown panel on either side is an error
- Registry.CopyFrom: reports the source's name on success
- Registry.CopyFrom: repaints the target
- Registry.CopyFrom: the copy is sanitized
- Database: profile callbacks are registered
- Database: switching profile re-renders the panels
- Database: switching profile re-runs migrations on the incoming profile
- Database: switching profile sanitizes the incoming records
- Database: the profile reload goes through Registry, keeping one sender
- Panel: the Profiles subcategory is registered
- Panel: Profiles registers AceDB's own options table
- Panel: the Profiles page carries the framework contract like every other
- Panel: the Profiles page has NO Defaults button
- Panel: the Profiles page builds lazily on OnShow

### test_spelling.lua (2)

- Spelling: the TOC and run.lua between them name every authored source
- Spelling: authored English is US English

## Totals

| Suite | Cases |
|-------|------:|
| test_util.lua | 27 |
| test_compat.lua | 14 |
| test_constants.lua | 16 |
| test_registry.lua | 41 |
| test_canvas.lua | 27 |
| test_unlock.lua | 28 |
| test_media.lua | 79 |
| test_accent.lua | 63 |
| test_database.lua | 18 |
| test_debuglog.lua | 25 |
| test_schema.lua | 21 |
| test_slash.lua | 55 |
| test_panel.lua | 40 |
| test_profiles.lua | 21 |
| test_spelling.lua | 2 |
| **Total** | **477** |
