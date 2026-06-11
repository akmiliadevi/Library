--- test_utils.lua
--- Unit tests for the pure utility functions in Lib.lua.

package.path = "tests/?.lua;?.lua;" .. package.path
require("mock_roblox")
local lu = require("luaunit")
local Library = dofile("Lib.lua")
local I = Library._internal

---------------------------------------------------------------------------
-- stripRichTags
---------------------------------------------------------------------------
TestStripRichTags = {}

function TestStripRichTags:test_removes_simple_tags()
    lu.assertEquals(I.stripRichTags("<b>bold</b>"), "bold")
end

function TestStripRichTags:test_removes_font_color_tags()
    lu.assertEquals(
        I.stripRichTags('<font color="#FF0000">red text</font>'),
        "red text"
    )
end

function TestStripRichTags:test_removes_nested_tags()
    lu.assertEquals(
        I.stripRichTags("<b><i>nested</i></b>"),
        "nested"
    )
end

function TestStripRichTags:test_plain_text_unchanged()
    lu.assertEquals(I.stripRichTags("hello world"), "hello world")
end

function TestStripRichTags:test_empty_string()
    lu.assertEquals(I.stripRichTags(""), "")
end

function TestStripRichTags:test_non_string_input_nil()
    lu.assertEquals(I.stripRichTags(nil), "")
end

function TestStripRichTags:test_non_string_input_number()
    lu.assertEquals(I.stripRichTags(42), "42")
end

function TestStripRichTags:test_non_string_input_boolean()
    lu.assertEquals(I.stripRichTags(true), "true")
end

function TestStripRichTags:test_multiple_tags()
    lu.assertEquals(
        I.stripRichTags("<b>a</b> and <i>b</i>"),
        "a and b"
    )
end

function TestStripRichTags:test_self_closing_tags()
    lu.assertEquals(I.stripRichTags("line<br/>break"), "linebreak")
end

---------------------------------------------------------------------------
-- sanitizeInput
---------------------------------------------------------------------------
TestSanitizeInput = {}

function TestSanitizeInput:test_short_string_unchanged()
    lu.assertEquals(I.sanitizeInput("hello"), "hello")
end

function TestSanitizeInput:test_truncates_at_default_max()
    local long = string.rep("a", 1100)
    local result = I.sanitizeInput(long)
    lu.assertEquals(#result, 1000)
end

function TestSanitizeInput:test_custom_max_length()
    local result = I.sanitizeInput("abcdefghij", 5)
    lu.assertEquals(result, "abcde")
end

function TestSanitizeInput:test_exact_max_length_unchanged()
    local result = I.sanitizeInput("abcde", 5)
    lu.assertEquals(result, "abcde")
end

function TestSanitizeInput:test_nil_input()
    lu.assertEquals(I.sanitizeInput(nil), "")
end

function TestSanitizeInput:test_number_input()
    lu.assertEquals(I.sanitizeInput(123), "123")
end

function TestSanitizeInput:test_boolean_input()
    lu.assertEquals(I.sanitizeInput(true), "true")
end

function TestSanitizeInput:test_empty_string()
    lu.assertEquals(I.sanitizeInput(""), "")
end

---------------------------------------------------------------------------
-- formatRichText
---------------------------------------------------------------------------
TestFormatRichText = {}

function TestFormatRichText:test_empty_string()
    lu.assertEquals(I.formatRichText(""), "")
end

function TestFormatRichText:test_nil_input()
    lu.assertEquals(I.formatRichText(nil), "")
end

function TestFormatRichText:test_non_string_input()
    lu.assertEquals(I.formatRichText(42), "")
end

function TestFormatRichText:test_plain_text_unchanged()
    lu.assertEquals(I.formatRichText("hello world"), "hello world")
end

function TestFormatRichText:test_converts_rgb_to_hex()
    local input = '<font color="rgb(255, 0, 128)">text</font>'
    local expected = '<font color="#FF0080">text</font>'
    lu.assertEquals(I.formatRichText(input), expected)
end

function TestFormatRichText:test_converts_rgb_zero_values()
    local input = '<font color="rgb(0, 0, 0)">text</font>'
    local expected = '<font color="#000000">text</font>'
    lu.assertEquals(I.formatRichText(input), expected)
end

function TestFormatRichText:test_converts_rgb_max_values()
    local input = '<font color="rgb(255, 255, 255)">text</font>'
    local expected = '<font color="#FFFFFF">text</font>'
    lu.assertEquals(I.formatRichText(input), expected)
end

function TestFormatRichText:test_clamps_values_above_255()
    local input = '<font color="rgb(300, 400, 500)">text</font>'
    local expected = '<font color="#FFFFFF">text</font>'
    lu.assertEquals(I.formatRichText(input), expected)
end

function TestFormatRichText:test_multiple_color_tags()
    local input = '<font color="rgb(255, 0, 0)">red</font> and <font color="rgb(0, 255, 0)">green</font>'
    local expected = '<font color="#FF0000">red</font> and <font color="#00FF00">green</font>'
    lu.assertEquals(I.formatRichText(input), expected)
end

function TestFormatRichText:test_hex_tags_untouched()
    local input = '<font color="#FF0000">already hex</font>'
    lu.assertEquals(I.formatRichText(input), input)
end

---------------------------------------------------------------------------
-- DeepCopy
---------------------------------------------------------------------------
TestDeepCopy = {}

function TestDeepCopy:test_copies_primitive()
    lu.assertEquals(I.DeepCopy(42), 42)
    lu.assertEquals(I.DeepCopy("hello"), "hello")
    lu.assertEquals(I.DeepCopy(true), true)
    lu.assertIsNil(I.DeepCopy(nil))
end

function TestDeepCopy:test_copies_flat_table()
    local orig = { a = 1, b = "two" }
    local copy = I.DeepCopy(orig)
    lu.assertEquals(copy.a, 1)
    lu.assertEquals(copy.b, "two")
    lu.assertNotIs(copy, orig)
end

function TestDeepCopy:test_copies_nested_table()
    local orig = { x = { y = { z = 99 } } }
    local copy = I.DeepCopy(orig)
    lu.assertEquals(copy.x.y.z, 99)
    lu.assertNotIs(copy.x, orig.x)
    lu.assertNotIs(copy.x.y, orig.x.y)
end

function TestDeepCopy:test_mutation_does_not_affect_original()
    local orig = { items = { 1, 2, 3 } }
    local copy = I.DeepCopy(orig)
    copy.items[4] = 4
    lu.assertIsNil(orig.items[4])
end

function TestDeepCopy:test_handles_circular_references()
    local a = { val = 1 }
    a.self = a
    local copy = I.DeepCopy(a)
    lu.assertEquals(copy.val, 1)
    lu.assertIs(copy.self, copy)
end

function TestDeepCopy:test_empty_table()
    local copy = I.DeepCopy({})
    lu.assertEquals(type(copy), "table")
    lu.assertIsNil(next(copy))
end

---------------------------------------------------------------------------
-- MergeTables
---------------------------------------------------------------------------
TestMergeTables = {}

function TestMergeTables:test_flat_merge()
    local target = { a = 1 }
    local source = { b = 2 }
    I.MergeTables(target, source)
    lu.assertEquals(target.a, 1)
    lu.assertEquals(target.b, 2)
end

function TestMergeTables:test_overwrite_existing_key()
    local target = { a = 1 }
    local source = { a = 99 }
    I.MergeTables(target, source)
    lu.assertEquals(target.a, 99)
end

function TestMergeTables:test_deep_merge_nested()
    local target = { cfg = { debug = false, level = 1 } }
    local source = { cfg = { debug = true } }
    I.MergeTables(target, source)
    lu.assertTrue(target.cfg.debug)
    lu.assertEquals(target.cfg.level, 1)
end

function TestMergeTables:test_source_non_table_overwrites_target_table()
    local target = { x = { inner = true } }
    local source = { x = "replaced" }
    I.MergeTables(target, source)
    lu.assertEquals(target.x, "replaced")
end

function TestMergeTables:test_empty_source_no_change()
    local target = { a = 1 }
    I.MergeTables(target, {})
    lu.assertEquals(target.a, 1)
end

function TestMergeTables:test_empty_target_gets_populated()
    local target = {}
    I.MergeTables(target, { a = 1, b = 2 })
    lu.assertEquals(target.a, 1)
    lu.assertEquals(target.b, 2)
end

---------------------------------------------------------------------------
-- ValidateConfigTypes
---------------------------------------------------------------------------
TestValidateConfigTypes = {}

function TestValidateConfigTypes:test_matching_types_kept()
    local schema = { name = "default", count = 0 }
    local loaded = { name = "custom", count = 5 }
    local result = I.ValidateConfigTypes(loaded, schema)
    lu.assertEquals(result.name, "custom")
    lu.assertEquals(result.count, 5)
end

function TestValidateConfigTypes:test_mismatched_type_dropped()
    local schema = { name = "default", count = 0 }
    local loaded = { name = 42, count = "wrong" }
    local result = I.ValidateConfigTypes(loaded, schema)
    lu.assertIsNil(result.name)
    lu.assertIsNil(result.count)
end

function TestValidateConfigTypes:test_extra_keys_preserved()
    local schema = { name = "default" }
    local loaded = { name = "custom", extra = "bonus" }
    local result = I.ValidateConfigTypes(loaded, schema)
    lu.assertEquals(result.name, "custom")
    lu.assertEquals(result.extra, "bonus")
end

function TestValidateConfigTypes:test_nested_tables_validated()
    local schema = { settings = { volume = 50, muted = false } }
    local loaded = { settings = { volume = 80, muted = "yes" } }
    local result = I.ValidateConfigTypes(loaded, schema)
    lu.assertEquals(result.settings.volume, 80)
    lu.assertIsNil(result.settings.muted)
end

function TestValidateConfigTypes:test_non_table_loaded_returned_as_is()
    lu.assertEquals(I.ValidateConfigTypes("hello", { a = 1 }), "hello")
    lu.assertEquals(I.ValidateConfigTypes(42, { a = 1 }), 42)
end

function TestValidateConfigTypes:test_non_table_schema_returns_loaded()
    local loaded = { x = 1 }
    local result = I.ValidateConfigTypes(loaded, "not a table")
    lu.assertIs(result, loaded)
end

function TestValidateConfigTypes:test_empty_tables()
    local result = I.ValidateConfigTypes({}, {})
    lu.assertIsNil(next(result))
end

---------------------------------------------------------------------------
-- safecall
---------------------------------------------------------------------------
TestSafecall = {}

function TestSafecall:setUp()
    _clearWarnLog()
end

function TestSafecall:test_successful_call()
    local ok, err = I.safecall(function() return end)
    lu.assertTrue(ok)
end

function TestSafecall:test_error_returns_false()
    local ok, err = I.safecall(function() error("boom") end)
    lu.assertFalse(ok)
    lu.assertStrContains(tostring(err), "boom")
end

function TestSafecall:test_error_logs_warning()
    _clearWarnLog()
    I.safecall(function() error("kaboom") end)
    lu.assertTrue(#_G._warnLog > 0)
    lu.assertStrContains(_G._warnLog[1], "kaboom")
end

function TestSafecall:test_passes_arguments()
    local captured
    I.safecall(function(a, b) captured = a + b end, 3, 4)
    lu.assertEquals(captured, 7)
end

---------------------------------------------------------------------------
-- warnLog
---------------------------------------------------------------------------
TestWarnLog = {}

function TestWarnLog:setUp()
    _clearWarnLog()
end

function TestWarnLog:test_formats_message()
    I.warnLog("TestContext", "something broke")
    lu.assertTrue(#_G._warnLog > 0)
    lu.assertStrContains(_G._warnLog[1], "TestContext")
    lu.assertStrContains(_G._warnLog[1], "something broke")
end

function TestWarnLog:test_includes_lynxgui_prefix()
    I.warnLog("Ctx", "err")
    lu.assertStrContains(_G._warnLog[1], "[LynxGUI]")
end

function TestWarnLog:test_handles_nil_error()
    I.warnLog("Ctx", nil)
    lu.assertStrContains(_G._warnLog[1], "nil")
end

---------------------------------------------------------------------------
-- disconnectAll
---------------------------------------------------------------------------
TestDisconnectAll = {}

function TestDisconnectAll:test_disconnects_all_connections()
    local disconnected = {}
    local conns = {}
    for i = 1, 3 do
        conns[i] = { Disconnect = function() disconnected[i] = true end }
    end
    I.disconnectAll(conns)
    lu.assertTrue(disconnected[1])
    lu.assertTrue(disconnected[2])
    lu.assertTrue(disconnected[3])
end

function TestDisconnectAll:test_clears_list()
    local conns = {
        { Disconnect = function() end },
        { Disconnect = function() end },
    }
    I.disconnectAll(conns)
    lu.assertEquals(#conns, 0)
end

function TestDisconnectAll:test_handles_error_in_disconnect()
    local conns = {
        { Disconnect = function() error("oops") end },
    }
    -- Should not raise
    I.disconnectAll(conns)
    lu.assertEquals(#conns, 0)
end

function TestDisconnectAll:test_empty_list()
    local conns = {}
    I.disconnectAll(conns)
    lu.assertEquals(#conns, 0)
end

---------------------------------------------------------------------------
os.exit(lu.LuaUnit.run())
