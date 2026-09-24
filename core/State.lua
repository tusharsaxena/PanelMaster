local _, NS = ...
NS.State = NS.State or {}
local State = NS.State

-- Runtime-only state. Nothing here is ever persisted to SavedVariables — every field resets on a
-- /reload or a fresh login.

-- Session-only logging flag, independent of the debug console window's visibility.
-- `/pm debug on|off`; default off, never in SavedVariables (debug-logging-§5).
State.debug = false

-- Is the addon in UNLOCK mode? While unlocked every enabled panel grows a drag handle, a name label
-- and a visible outline so it can be found and moved; locking hides all three and returns the panels
-- to being pure, mouse-transparent background art.
--
-- Session-only on purpose: an unlocked UI is an editing state, not a preference. Persisting it would
-- mean logging in to a screen full of drag handles because you forgot to lock before you logged out.
State.unlocked = false

-- Panels unlocked INDIVIDUALLY, as a set of panel ids. The global switch above is all-or-nothing,
-- which with a dozen panels means unlocking eleven you did not want to touch to nudge the twelfth.
-- Session-only for the same reason as the global flag.
State.unlockedPanels = {}

-- Event names the client refused to register this session, in the order they were refused, each
-- at most once. NS.SafeRegisterEvent (core/CoreSetup.lua) appends to it on every registration path
-- and `/pm debug dump` prints it (core/DebugLogSetup.lua), which is the record events-frames-taint-§1
-- requires the player can reach. Session-only: a refusal is a fact about this client build, and the
-- next login asks again.
State.rejectedEvents = {}
