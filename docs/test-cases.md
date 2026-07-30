# Test Cases

The full inventory of every headless test case, grouped by suite. This file is the
**authoritative pass count** for the addon.

**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`
whenever the suite changes (see [testing.md](testing.md)).

### test_util.lua (24)

- Util.SplitPath: splits a dotted path
- Util.SplitPath: a single segment is one part
- Util.Clamp: passes a value already in range
- Util.Clamp: clamps below and above
- Util.Clamp: a non-number falls back, then to the low bound
- Util.Round: rounds away from zero on both signs
- Util.Snap: a grid of 1 or less is the identity
- Util.Snap: rounds to the nearest multiple
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

### test_compat.lua (15)

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
- Compat.HasBackdrop: true when the mixin is present
- Compat owns the deprecated-API surface: no flavor branching in the addon

### test_constants.lua (11)

- Constants: the strata list runs lowest to highest and starts at BACKGROUND
- Constants: new panels default to LOW
- Constants: new panels default to CENTER at 0,0
- Constants: STRATA_SET agrees with STRATA
- Constants: nine anchor points, all in POINT_SET
- Constants: STRATA_OPTIONS is dropdown-shaped
- Constants: every template field has a declared type
- Constants: every typed field appears in the display order
- Constants: the template's own values are valid by its own rules
- Constants: preview panels are valid panel overrides
- Constants: the mono font and logo point at this addon's folder

### test_registry.lua (33)

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
- Registry.Set: parses a colour string
- Registry.Set: rejects an unknown field
- Registry.Set: rejects an invalid anchor with a helpful message
- Registry.Set: accepts a lower-case anchor and stores it upper-case
- Registry.Set: writing `name` routes through Rename's uniqueness check
- Registry.Set: clamps out-of-range input rather than rejecting it
- Registry.SetPosition: writes both coordinates at once
- Registry.FormatField: renders each field type readably
- Registry.Recover: leaves on-screen panels alone
- Registry.Recover: pulls an off-screen panel back into view
- Registry: the panel messages have exactly one sender

### test_canvas.lua (24)

- Canvas.BuildSpec: carries the record's geometry through
- Canvas.BuildSpec: repairs invalid values rather than passing them to a frame
- Canvas.BuildSpec: shown requires BOTH the master switch and the panel's own
- Canvas.BuildSpec: a missing settings table means shown
- Canvas.BuildSpec: a zero border is honoured, not floored to 1
- Canvas.BuildSpec: normalizes colours to four clamped components
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
- Canvas: the bus repaints on a registry change
- Canvas: a settings change repaints
- Canvas: OnEnable subscribes the renderer to the bus
- Canvas: consumers register on their own bus target (architecture-§4)

### test_unlock.lua (22)

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
- Canvas: the border colour is applied AFTER the backdrop
- Canvas: the border picks up a colour change
- Canvas: the border takes the class colour too
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
- Registry.Reset: clears class-colour flags
- Registry.Reset: does not alias the shared template
- Registry.Reset: repaints the panel
- Registry.Reset: an unknown panel is an error, not a silent no-op
- Registry.Reset: leaves other panels alone
- Border: class colour and a picked colour produce the same backdrop
- Border: class colour preserves the picked colour's ALPHA exactly
- Border: only the RGB differs between the two modes
- Accent bar: class colour likewise preserves alpha
- Canvas: the background colour is applied to the fill texture
- Canvas: the background picks up a colour change
- Registry.Set: a media name is matched case-insensitively against the live list
- Registry.Set: an unknown media name is refused with the available list
- Registry.Sanitize: does NOT rewrite an unresolvable texture name
- Registry.Sanitize: an empty or non-string texture falls back to the default
- Constants: every class-colour flag names a real colour field
- Util.ResolveColor: returns the stored colour when the flag is off
- Util.ResolveColor: the class colour replaces RGB but keeps the stored alpha
- Util.ResolveColor: falls back to the stored colour when the class is unknown
- Util.ResolveColor: a colour with no class-colour companion is returned as stored
- Canvas.BuildSpec: applies the class colour to the background
- Canvas.BuildSpec: applies the class colour to the border independently
- Registry.Set: the class-colour flags coerce from the CLI
- Registry.Sanitize: class-colour flags are always booleans
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

### test_accent.lua (60)

- Accent: ON by default — the accent bar is the shipped look
- Accent: the panel's OWN border is off, so only one thing defines the edge
- Accent: defaults to the top edge only
- Accent: defaults to 5px thick, flush against the panel
- Accent: the default bar texture is one LibSharedMedia always ships
- Accent: defaults to CLASS colour
- Accent: the class-colour flag is wired into the generic colour map
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
- Canvas.BuildSpec: the accent colour goes through the shared resolver
- Canvas.BuildSpec: accent class colour is independent of the others
- Canvas: no accent bar is shown when the feature is off
- Canvas: enabling shows only the chosen edges
- Canvas: all four edges at once is legal
- Canvas: an empty edge set draws nothing even when enabled
- Canvas: the top bar spans the full edge and is offset outward
- Canvas: the bottom bar is offset downward
- Canvas: the left bar is vertical and offset leftward
- Canvas: the right bar is offset rightward
- Canvas: a negative offset pulls the bar over the panel
- Canvas: the bar is painted with the resolved colour
- Canvas: the bar takes the class colour by default
- Canvas: the bar is re-anchored, not accumulated, on repaint
- Canvas: toggling accents off hides the bars again
- Canvas: the accent bar draws ABOVE the border
- Canvas: the accent/border stacking survives a frame-level change
- Canvas: the accent bars live on their own child frame
- Accent border: a 1px BLACK hairline by default
- Accent border: its class-colour flag is wired into the generic colour map
- Accent border: selects from the BORDER media pool, not statusbar
- Canvas.BuildSpec: carries the accent border settings
- Canvas.BuildSpec: clamps the accent border to the panel border's bounds
- Canvas: no border frame is built when the bar has no border
- Canvas: the bar border is a backdrop edge at the set thickness
- Canvas: the bar border colour is applied AFTER the backdrop
- Canvas: the bar border takes the class colour
- Canvas: the bar border is offset from the bar
- Canvas: dropping the bar border to zero clears it
- Canvas: a 'None' bar border texture removes it
- Registry.Reset: puts the bar border back to the shipped hairline
- Canvas: a released frame hides its accent bars

### test_database.lua (14)

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
- Database.InitSummary: survives a missing DB

### test_debuglog.lua (19)

- DebugLog.FormatPlain: '<ts> | [<tag>] <msg>' with no colour codes
- DebugLog.FormatPlain: a nil tag renders as empty brackets, not 'nil'
- DebugLog.FormatColored: colours the timestamp and the tag
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
- DebugLog.SetEnabled: the chat ack is colour-coded ON green / OFF red
- DebugLog: the title-bar toggle drives the same seam
- DebugLog: window visibility is independent of the logging flag
- DebugLog.Toggle: alternates window visibility
- DebugLog.Diagnose: reports the registry and the renderer together
- DebugLog.Diagnose: works with logging off

### test_schema.lua (23)

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
- Schema: the settings message has exactly one sender
- Schema: the numeric rows declare min and max
- Schema: defaultAlpha stays a fraction
- COMMANDS: every entry has a name, description and function
- COMMANDS: names are unique and lower-case
- COMMANDS: the standard's required verbs are present (slash-commands-§3)

### test_slash.lua (47)

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
- Slash.CliPanel: sets a colour from a string
- Slash.CliPanel: an unknown panel is reported
- Slash.CliPanel: an unknown field lists the valid ones
- Slash.CliPanel deleteall: goes through the confirm popup
- Slash.CliRecover: reports when nothing needed moving
- Slash.CliRecover: reports how many it moved
- Slash: every printed line carries the shared cyan tag

### test_panel.lua (20)

- Panel.Register: the category is registered EAGERLY at load (options-ui-§1)
- Panel.Register: both subcategories are registered
- Panel.Register: is idempotent
- Panel: every registered frame carries the framework contract (options-ui-§1)
- Panel: the body is built lazily — each page has an OnShow
- Panel: the Defaults button is NOT created at registration (anti-pattern #42)
- Panel: the pages that want a Defaults button declare the intent and park a callback
- Panel: the header Defaults action and Blizzard's OnDefault are the same function
- Panel: the landing page is the parent category, not a subcategory
- Panel.Open: refuses during combat and does NOT open (options-ui-§2)
- Panel.Open: the combat refusal is grey
- Panel.Open: does NOT defer-and-replay on leaving combat
- Panel.Open: opens out of combat
- Panel.Refresh: a hidden page is not refreshed
- Panel.RestoreDefaults: resets settings and leaves panels alone
- Panel: closing dropdowns dispatches on widget TYPE, not on field presence
- Panel: closing an unopened dropdown is a no-op, not an error
- Panel: an unknown widget type is skipped rather than guessed at
- Panel: the tracking registry is emptied between rebuilds
- Panel: the Panels page's Defaults action is confirm-gated

### test_profiles.lua (21)

- Registry.CopyFrom: copies appearance across
- Registry.CopyFrom: does NOT copy position
- Registry.CopyFrom: does NOT copy identity
- Registry.CopyFrom: DOES copy size
- Registry.CopyFrom: colours are deep-copied, not shared
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

## Totals

| Suite | Cases |
|-------|------:|
| test_util.lua | 24 |
| test_compat.lua | 15 |
| test_constants.lua | 11 |
| test_registry.lua | 33 |
| test_canvas.lua | 24 |
| test_unlock.lua | 22 |
| test_media.lua | 79 |
| test_accent.lua | 60 |
| test_database.lua | 14 |
| test_debuglog.lua | 19 |
| test_schema.lua | 23 |
| test_slash.lua | 47 |
| test_panel.lua | 20 |
| test_profiles.lua | 21 |
| **Total** | **412** |
