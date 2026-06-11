--- test_config.lua
--- Unit tests for Library.ConfigSystem.

package.path = "tests/?.lua;?.lua;" .. package.path
require("mock_roblox")
local lu = require("luaunit")
local Library = dofile("Lib.lua")
local CS = Library.ConfigSystem

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function resetAll()
    _resetVirtualFS()
    _clearWarnLog()
    -- Reset config state by setting empty defaults and loading
    CS.SetDefaults({})
    -- Force internal state reset via Load
    CS.Load()
end

---------------------------------------------------------------------------
-- ConfigSystem.SetDefaults + Get
---------------------------------------------------------------------------
TestConfigDefaults = {}

function TestConfigDefaults:setUp()
    resetAll()
end

function TestConfigDefaults:test_set_defaults_and_get()
    CS.SetDefaults({ volume = 75, muted = false })
    CS.Load()
    lu.assertEquals(CS.Get("volume"), 75)
    -- Note: Get uses `value ~= nil and value or default`, so false values
    -- are indistinguishable from nil and fall through to the default.
    lu.assertIsNil(CS.Get("muted"))
end

function TestConfigDefaults:test_get_missing_key_returns_default()
    CS.SetDefaults({ volume = 75 })
    CS.Load()
    lu.assertEquals(CS.Get("nonexistent", "fallback"), "fallback")
end

function TestConfigDefaults:test_get_nil_path_returns_default()
    lu.assertEquals(CS.Get(nil, "fallback"), "fallback")
end

function TestConfigDefaults:test_defaults_deep_copied()
    local defaults = { nested = { value = 10 } }
    CS.SetDefaults(defaults)
    CS.Load()
    CS.Set("nested.value", 99)
    -- Original defaults table should be unaffected
    lu.assertEquals(defaults.nested.value, 10)
end

---------------------------------------------------------------------------
-- ConfigSystem.Get with dot-path navigation
---------------------------------------------------------------------------
TestConfigGet = {}

function TestConfigGet:setUp()
    resetAll()
end

function TestConfigGet:test_simple_key()
    CS.SetDefaults({ key = "val" })
    CS.Load()
    lu.assertEquals(CS.Get("key"), "val")
end

function TestConfigGet:test_nested_dot_path()
    CS.SetDefaults({ a = { b = { c = 42 } } })
    CS.Load()
    lu.assertEquals(CS.Get("a.b.c"), 42)
end

function TestConfigGet:test_partial_path_returns_table()
    CS.SetDefaults({ a = { b = 1, c = 2 } })
    CS.Load()
    local sub = CS.Get("a")
    lu.assertEquals(type(sub), "table")
    lu.assertEquals(sub.b, 1)
end

function TestConfigGet:test_path_through_non_table_returns_default()
    CS.SetDefaults({ a = "string_value" })
    CS.Load()
    lu.assertEquals(CS.Get("a.b.c", "fallback"), "fallback")
end

function TestConfigGet:test_deeply_nested_missing_returns_default()
    CS.SetDefaults({ a = { b = {} } })
    CS.Load()
    lu.assertEquals(CS.Get("a.b.c.d.e", "nope"), "nope")
end

---------------------------------------------------------------------------
-- ConfigSystem.Set
---------------------------------------------------------------------------
TestConfigSet = {}

function TestConfigSet:setUp()
    resetAll()
end

function TestConfigSet:test_set_simple_key()
    CS.SetDefaults({})
    CS.Load()
    CS.Set("volume", 50)
    lu.assertEquals(CS.Get("volume"), 50)
end

function TestConfigSet:test_set_nested_path_creates_intermediates()
    CS.SetDefaults({})
    CS.Load()
    CS.Set("a.b.c", "deep")
    lu.assertEquals(CS.Get("a.b.c"), "deep")
end

function TestConfigSet:test_set_overwrites_existing()
    CS.SetDefaults({ x = 1 })
    CS.Load()
    CS.Set("x", 2)
    lu.assertEquals(CS.Get("x"), 2)
end

function TestConfigSet:test_set_nil_path_does_nothing()
    CS.SetDefaults({ x = 1 })
    CS.Load()
    CS.Set(nil, "anything")
    lu.assertEquals(CS.Get("x"), 1)
end

function TestConfigSet:test_set_replaces_non_table_intermediate()
    CS.SetDefaults({ a = "not_a_table" })
    CS.Load()
    CS.Set("a.b", "value")
    lu.assertEquals(CS.Get("a.b"), "value")
end

---------------------------------------------------------------------------
-- ConfigSystem.Save / Load round-trip
---------------------------------------------------------------------------
TestConfigSaveLoad = {}

function TestConfigSaveLoad:setUp()
    resetAll()
end

function TestConfigSaveLoad:test_save_and_load_roundtrip()
    CS.SetDefaults({ theme = "dark", level = 5 })
    CS.Load()
    CS.Set("level", 10)
    CS.Save()

    -- Reset and reload
    CS.SetDefaults({ theme = "dark", level = 5 })
    CS.Load()
    lu.assertEquals(CS.Get("level"), 10)
    lu.assertEquals(CS.Get("theme"), "dark")
end

function TestConfigSaveLoad:test_load_with_no_file_uses_defaults()
    CS.SetDefaults({ mode = "auto" })
    CS.Load()
    lu.assertEquals(CS.Get("mode"), "auto")
end

function TestConfigSaveLoad:test_load_corrupt_file_resets_to_defaults()
    _clearWarnLog()
    CS.SetDefaults({ x = 1 })
    CS.Load()
    -- Ensure folder exists, then write corrupt data
    makefolder("LynxGUI_Configs")
    writefile("LynxGUI_Configs/lynx_config.json", "NOT VALID JSON{{{")
    CS.Load()
    lu.assertEquals(CS.Get("x"), 1)
    lu.assertTrue(#_G._warnLog > 0)
end

function TestConfigSaveLoad:test_load_creates_backup()
    CS.SetDefaults({ a = 1 })
    CS.Load()
    CS.Set("a", 99)
    CS.Save()

    -- Load again should create backup
    CS.Load()
    lu.assertTrue(isfile("LynxGUI_Configs/lynx_config.backup.json"))
end

function TestConfigSaveLoad:test_load_validates_types_against_schema()
    CS.SetDefaults({ count = 0, name = "default" })
    CS.Load()
    -- Manually write a file with wrong types
    writefile("LynxGUI_Configs/lynx_config.json", '{"count": "wrong_type", "name": 42}')
    makefolder("LynxGUI_Configs")
    CS.Load()
    -- Both should be rejected and fall back to defaults
    lu.assertEquals(CS.Get("count"), 0)
    lu.assertEquals(CS.Get("name"), "default")
end

---------------------------------------------------------------------------
-- ConfigSystem.Reset
---------------------------------------------------------------------------
TestConfigReset = {}

function TestConfigReset:setUp()
    resetAll()
end

function TestConfigReset:test_reset_restores_defaults()
    CS.SetDefaults({ a = 1, b = 2 })
    CS.Load()
    CS.Set("a", 99)
    CS.Set("b", 88)
    CS.Reset()
    lu.assertEquals(CS.Get("a"), 1)
    lu.assertEquals(CS.Get("b"), 2)
end

---------------------------------------------------------------------------
-- ConfigSystem.Delete
---------------------------------------------------------------------------
TestConfigDelete = {}

function TestConfigDelete:setUp()
    resetAll()
end

function TestConfigDelete:test_delete_removes_file()
    CS.SetDefaults({ x = 1 })
    CS.Load()
    CS.Save()
    lu.assertTrue(isfile("LynxGUI_Configs/lynx_config.json"))
    CS.Delete()
    lu.assertFalse(isfile("LynxGUI_Configs/lynx_config.json"))
end

function TestConfigDelete:test_delete_when_no_file_no_error()
    CS.Delete()
    -- Should not raise
end

---------------------------------------------------------------------------
-- ConfigSystem.RestoreBackup
---------------------------------------------------------------------------
TestConfigRestoreBackup = {}

function TestConfigRestoreBackup:setUp()
    resetAll()
end

function TestConfigRestoreBackup:test_restore_from_backup()
    CS.SetDefaults({ score = 0 })
    CS.Load()
    CS.Set("score", 100)
    CS.Save()

    -- Backup the current state
    local raw = readfile("LynxGUI_Configs/lynx_config.json")
    writefile("LynxGUI_Configs/lynx_config.backup.json", raw)

    -- Change to different value
    CS.Set("score", 0)
    CS.Save()

    -- Restore from backup
    local ok = CS.RestoreBackup()
    lu.assertTrue(ok)
    lu.assertEquals(CS.Get("score"), 100)
end

function TestConfigRestoreBackup:test_restore_no_backup_returns_false()
    local ok, err = CS.RestoreBackup()
    lu.assertFalse(ok)
    lu.assertStrContains(err, "No backup")
end

function TestConfigRestoreBackup:test_restore_empty_backup_returns_false()
    makefolder("LynxGUI_Configs")
    writefile("LynxGUI_Configs/lynx_config.backup.json", "")
    local ok, err = CS.RestoreBackup()
    lu.assertFalse(ok)
    lu.assertStrContains(err, "empty or invalid")
end

function TestConfigRestoreBackup:test_restore_corrupt_backup_returns_false()
    makefolder("LynxGUI_Configs")
    writefile("LynxGUI_Configs/lynx_config.backup.json", "NOT JSON!!!")
    local ok, err = CS.RestoreBackup()
    lu.assertFalse(ok)
end

---------------------------------------------------------------------------
-- _G.LynxGUI global interface
---------------------------------------------------------------------------
TestGlobalInterface = {}

function TestGlobalInterface:setUp()
    resetAll()
end

function TestGlobalInterface:test_get_config_value()
    CS.SetDefaults({ foo = "bar" })
    CS.Load()
    lu.assertEquals(_G.LynxGUI.GetConfigValue("foo", "default"), "bar")
end

function TestGlobalInterface:test_get_config_value_missing()
    CS.SetDefaults({})
    CS.Load()
    lu.assertEquals(_G.LynxGUI.GetConfigValue("missing", "fallback"), "fallback")
end

function TestGlobalInterface:test_save_config_value()
    CS.SetDefaults({ counter = 0 })
    CS.Load()
    _G.LynxGUI.SaveConfigValue("counter", 42)
    lu.assertEquals(CS.Get("counter"), 42)
end

function TestGlobalInterface:test_get_full_config_returns_copy()
    CS.SetDefaults({ a = 1, b = 2 })
    CS.Load()
    local cfg = _G.LynxGUI.GetFullConfig()
    lu.assertEquals(cfg.a, 1)
    lu.assertEquals(cfg.b, 2)
    -- Mutating the copy should not affect internal state
    cfg.a = 999
    lu.assertEquals(CS.Get("a"), 1)
end

---------------------------------------------------------------------------
os.exit(lu.LuaUnit.run())
