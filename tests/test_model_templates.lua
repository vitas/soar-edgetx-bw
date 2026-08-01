local tests = {}

local function test(name, fn)
  tests[#tests + 1] = { name = name, fn = fn }
end

local function assert_equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %q, got %q", label, tostring(expected), tostring(actual)), 0)
  end
end

local function assert_absent(content, needle, label)
  if content:find(needle, 1, true) then
    error(label .. " unexpectedly contains " .. needle, 0)
  end
end

local function read_file(path)
  local file, open_error = io.open(path, "rb")
  if not file then
    error("missing template file: " .. path .. " (" .. tostring(open_error) .. ")", 0)
  end
  local content = file:read("*a")
  file:close()
  return content:gsub("\r\n", "\n")
end

local function lines_from(content)
  local lines = {}
  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    lines[#lines + 1] = line
  end
  return lines
end

local function top_level_section(content, name)
  local section = {}
  local in_section = false

  for _, line in ipairs(lines_from(content)) do
    if line:match("^" .. name .. ":%s*$") then
      in_section = true
      section[#section + 1] = line
    elseif in_section and line:match("^%S") then
      break
    elseif in_section then
      section[#section + 1] = line
    end
  end

  if #section == 0 then
    error("missing section: " .. name, 0)
  end
  return table.concat(section, "\n")
end

local function indexed_blocks(content, section_name)
  local section = top_level_section(content, section_name)
  local blocks = {}
  local block = nil
  local index = nil
  local block_indent = nil

  for _, line in ipairs(lines_from(section)) do
    local indent = line:match("^(%s+)%d+:%s*$")
    if indent and (not block_indent or #indent < #block_indent) then
      block_indent = indent
    end
  end
  if not block_indent then return blocks end

  local function finish_block()
    if block then
      blocks[#blocks + 1] = { index = index, text = table.concat(block, "\n") }
    end
  end

  for _, line in ipairs(lines_from(section)) do
    local indent, found = line:match("^(%s+)(%d+):%s*$")
    if found and #indent == #block_indent then
      finish_block()
      index = tonumber(found)
      block = { line }
    elseif block then
      block[#block + 1] = line
    end
  end
  finish_block()
  return blocks
end

local function find_indexed_block(content, section_name, index)
  for _, block in ipairs(indexed_blocks(content, section_name)) do
    if block.index == index then return block.text end
  end
  return nil
end

local function indexed_block(content, section_name, index)
  local block = find_indexed_block(content, section_name, index)
  if block then return block end
  error("missing " .. section_name .. " block " .. tostring(index), 0)
end

local function list_item_indent(line)
  return line:match("^(%s*)%-%s*$") or line:match("^(%s*)%-%s+")
end

local function list_blocks(content, section_name)
  local section = top_level_section(content, section_name)
  local blocks = {}
  local block = nil
  local block_indent = nil

  for _, line in ipairs(lines_from(section)) do
    local indent = list_item_indent(line)
    if indent and (not block_indent or #indent < #block_indent) then
      block_indent = indent
    end
  end
  if not block_indent then return blocks end

  local function finish_block()
    if block then
      blocks[#blocks + 1] = table.concat(block, "\n")
    end
  end

  for _, line in ipairs(lines_from(section)) do
    local indent = list_item_indent(line)
    if indent and #indent == #block_indent then
      finish_block()
      block = { line }
    elseif block then
      block[#block + 1] = line
    end
  end
  finish_block()
  return blocks
end

local function normalize_scalar(value)
  if not value then return nil end
  value = value:match("^%s*(.-)%s*$")
  local double_quoted = value:match('^"(.*)"$')
  local single_quoted = value:match("^'(.*)'$")
  return double_quoted or single_quoted or value
end

local function scalar_field(block, field)
  local value = ("\n" .. block .. "\n"):match("\n%s+%-?%s*" .. field .. ":%s*([^\n]-)%s*\n")
  return normalize_scalar(value)
end

local function list_blocks_for(content, section_name, key, value)
  local matches = {}
  for _, block in ipairs(list_blocks(content, section_name)) do
    if scalar_field(block, key) == normalize_scalar(tostring(value)) then
      matches[#matches + 1] = block
    end
  end
  return matches
end

local function mix_blocks_for(content, dest_ch)
  return list_blocks_for(content, "mixData", "destCh", dest_ch)
end

local function expo_blocks_for(content, chn)
  return list_blocks_for(content, "expoData", "chn", chn)
end

local function find_mix_block_matching(blocks, expected)
  for _, block in ipairs(blocks) do
    local matches = true
    for _, field_text in ipairs(expected) do
      local key, value = field_text:match("^([%w_]+):%s*(.-)%s*$")
      if not key or scalar_field(block, key) ~= normalize_scalar(value) then
        matches = false
        break
      end
    end
    if matches then return block end
  end
  return nil
end

local function find_named_list_block(content, section_name, chn, name)
  for _, block in ipairs(list_blocks_for(content, section_name, "chn", chn)) do
    if scalar_field(block, "name") == name then
      return block
    end
  end
  error(string.format("missing %s block %s on input %d", section_name, name, chn + 1), 0)
end

local function curve_signature(block)
  if not ("\n" .. block .. "\n"):match("\n%s+curve:%s*\n") then
    return "0:0"
  end
  return tostring(scalar_field(block, "type")) .. ":" .. tostring(scalar_field(block, "value"))
end

local function mix_signature(block)
  return table.concat({
    "src=" .. tostring(scalar_field(block, "srcRaw")),
    "weight=" .. tostring(scalar_field(block, "weight")),
    "switch=" .. tostring(scalar_field(block, "swtch")),
    "curve=" .. curve_signature(block),
    "trim=" .. tostring(scalar_field(block, "carryTrim")),
    "mux=" .. tostring(scalar_field(block, "mltpx")),
    "fm=" .. tostring(scalar_field(block, "flightModes")),
    "offset=" .. tostring(scalar_field(block, "offset")),
    "name=" .. tostring(scalar_field(block, "name"))
  }, "|")
end

local function assert_mix_signatures(content, dest_ch, expected, label)
  local actual = {}
  for _, block in ipairs(mix_blocks_for(content, dest_ch)) do
    actual[#actual + 1] = mix_signature(block)
  end
  table.sort(actual)
  table.sort(expected)
  assert_equal(table.concat(actual, "\n"), table.concat(expected, "\n"), label)
end

local function assert_named_indexed_set(content, section_name, field, expected, label)
  local actual = {}
  for _, block in ipairs(indexed_blocks(content, section_name)) do
    local value = scalar_field(block.text, field)
    if value then actual[#actual + 1] = value end
  end
  assert_equal(table.concat(actual, ","), table.concat(expected, ","), label)
end

local function assert_index_set(content, section_name, expected, label)
  local actual = {}
  for _, block in ipairs(indexed_blocks(content, section_name)) do
    actual[#actual + 1] = tostring(block.index)
  end
  assert_equal(table.concat(actual, ","), table.concat(expected, ","), label)
end

local function assert_point_values(content, first_index, expected, label)
  for offset, value in ipairs(expected) do
    local index = first_index + offset - 1
    local block = find_indexed_block(content, "points", index)
    local actual = block and scalar_field(block, "val") or "0"
    assert_equal(actual, tostring(value), label .. " point " .. tostring(index))
  end
end

local function assert_flight_mode_trims_neutral(content, label)
  local section = top_level_section(content, "flightModeData")
  local in_trim = false
  local trim_indent = nil
  local entry_indent = nil
  local entry_index = nil
  local entry_value = nil

  local function finish_entry()
    if entry_index then
      assert_equal(entry_value, "0", label .. " trim " .. tostring(entry_index))
    end
    entry_index = nil
    entry_value = nil
  end

  for _, line in ipairs(lines_from(section)) do
    local indent = line:match("^(%s*)")
    local trim = line:match("^%s*trim:%s*$")

    if trim then
      finish_entry()
      in_trim = true
      trim_indent = #indent
      entry_indent = nil
    elseif in_trim and line:match("%S") and #indent <= trim_indent then
      finish_entry()
      in_trim = false
    elseif in_trim then
      local item_indent, index = line:match("^(%s+)(%d+):%s*$")
      if index and (not entry_indent or #item_indent == entry_indent) then
        finish_entry()
        entry_indent = #item_indent
        entry_index = tonumber(index)
      elseif entry_index then
        local value = line:match("^%s+value:%s*([^%s]+)%s*$")
        if value then entry_value = normalize_scalar(value) end
      end
    end
  end
  finish_entry()
end

local function blocks_for_destinations(content, destinations)
  local result = {}
  for _, destination in ipairs(destinations) do
    local blocks = mix_blocks_for(content, destination)
    result[#result + 1] = "destCh " .. tostring(destination)
    for _, block in ipairs(blocks) do result[#result + 1] = block end
  end
  return table.concat(result, "\n")
end

local TEMPLATE_ROOT = "dist/SDCARD/TEMPLATES/3.SoarEdgeTx"
local F3K = TEMPLATE_ROOT .. "/pocket-F3K.yml"
local F5J_X = TEMPLATE_ROOT .. "/pocket-F5J-XTail.yml"
local F5J_M = TEMPLATE_ROOT .. "/pocket-F5J-MTail.yml"
local F5J_V = TEMPLATE_ROOT .. "/pocket-F5J-VTail.yml"

local templates = {
  { path = F3K, name = "Pocket F3K", kind = "F3K" },
  { path = F5J_X, name = "Pocket F5J XTail", kind = "F5J" },
  { path = F5J_M, name = "Pocket F5J MTail", kind = "F5J" },
  { path = F5J_V, name = "Pocket F5J VTail", kind = "F5J" }
}

local copied_failsafes = {
  F3K = { 149, -91, 126, -292 },
  F5J = { 112, -70, -1233, -122, 38, 57, -189 }
}

test("block helpers parse model05 and model06 YAML shapes exactly", function()
  local model05_shape = [[mixData:
  - destCh: 0
    srcRaw: ch(31)
    weight: "100"
    name: ""
expoData:
  - srcRaw: Thr
    chn: 3
    weight: -100
    name: Brake
limitData:
  0:
    name: Ai-L
points:
  0:
    val: 25
  2:
    val: -25
]]
  local model06_shape = [[mixData:
   -
     destCh: 2
     srcRaw: MAX
     weight: 1000
     name: Motor
     curve:
       type: 3
       value: 13
expoData:
   -
     srcRaw: "Thr"
     chn: 7
     weight: "-100"
     name: "Adjust"
limitData:
   2:
     name: "Moto"
]]

  assert_equal(#mix_blocks_for(model05_shape, 0), 1, "model05-shaped mix block")
  assert_equal(#expo_blocks_for(model05_shape, 3), 1, "model05-shaped expo block")
  assert_equal(scalar_field(indexed_block(model05_shape, "limitData", 0), "name"), "Ai-L",
    "model05-shaped indexed block")
  assert_equal(#mix_blocks_for(model06_shape, 2), 1, "model06-shaped three-space mix block")
  assert_equal(#expo_blocks_for(model06_shape, 7), 1, "model06-shaped three-space expo block")
  assert_equal(scalar_field(mix_blocks_for(model06_shape, 2)[1], "srcRaw"), "MAX",
    "model06-shaped standalone-dash mix fields")
  assert_equal(scalar_field(expo_blocks_for(model06_shape, 7)[1], "srcRaw"), "Thr",
    "model06-shaped standalone-dash expo fields")
  assert_equal(curve_signature(mix_blocks_for(model05_shape, 0)[1]), "0:0",
    "omitted mix curve uses EdgeTX defaults")
  assert_equal(curve_signature(mix_blocks_for(model06_shape, 2)[1]), "3:13",
    "explicit mix curve stays exact")
  assert_equal(scalar_field(indexed_block(model06_shape, "limitData", 2), "name"), "Moto",
    "model06-shaped three-space indexed block")
  assert(find_mix_block_matching(mix_blocks_for(model05_shape, 0), { "weight: 100" }),
    "quoted scalar should equal unquoted scalar")
  assert(not find_mix_block_matching(mix_blocks_for(model06_shape, 2), { "weight: 100" }),
    "weight 100 must not match 1000")
  assert_point_values(model05_shape, 0, { 25, 0, -25 }, "sparse points")
  local accepts_nonzero_missing = pcall(assert_point_values, model05_shape, 0, { 25, 1, -25 }, "sparse points")
  assert(not accepts_nonzero_missing, "missing sparse point must not satisfy a nonzero expectation")

  local two_space_trims = [[flightModeData:
  0:
    trim:
      1:
        value: 0
        mode: 31
  3:
    trim:
      2:
        value: 0
        mode: 10
]]
  local three_space_trims = [[flightModeData:
   0:
     trim:
       0:
         value: 0
         mode: 1
   5:
     trim:
       3:
         value: 0
         mode: 4
]]
  assert_flight_mode_trims_neutral(two_space_trims, "two-space sparse trims")
  assert_flight_mode_trims_neutral(three_space_trims, "three-space sparse trims")
  local accepts_nonzero_trim = pcall(assert_flight_mode_trims_neutral,
    two_space_trims:gsub("value: 0", "value: 8", 1), "nonzero trim")
  assert(not accepts_nonzero_trim, "nonzero trim must fail neutrality")
end)

for _, template in ipairs(templates) do
  test(template.name .. " has sanitized model and RF metadata", function()
    local content = read_file(template.path)
    assert_equal(content:match("^semver:%s*([^%s]+)"), "2.12.2", template.name .. " version")

    local header = top_level_section(content, "header")
    assert_equal(scalar_field(header, "name"), template.name, template.name .. " header")
    for value in header:gmatch("\n%s+val:%s*(-?%d+)") do
      assert_equal(tonumber(value), 0, template.name .. " header modelId")
    end

    local registration = content:match("^modelRegistrationID:%s*([^\n]*)") or
      content:match("\nmodelRegistrationID:%s*([^\n]*)")
    if registration then
      registration = registration:match("^%s*(.-)%s*$"):gsub('^""$', "")
      assert_equal(registration, "", template.name .. " registration ID")
    end
    assert(not content:match("^telemetrySensors:%s*") and not content:match("\ntelemetrySensors:%s*"),
      template.name .. " should not contain telemetrySensors")

    local module = indexed_block(content, "moduleData", 0)
    assert_equal(scalar_field(module, "type"), "TYPE_CROSSFIRE", template.name .. " module type")
    assert_equal(scalar_field(module, "channelsStart"), "0", template.name .. " channel start")
    assert_equal(scalar_field(module, "channelsCount"), "16", template.name .. " channel count")
    assert_equal(scalar_field(module, "failsafeMode"), "NOT_SET", template.name .. " failsafe mode")

    local limits = indexed_blocks(content, "limitData")
    assert(#limits > 0, template.name .. " should define output limits")
    for _, limit in ipairs(limits) do
      local output = template.name .. " limitData " .. tostring(limit.index)
      for _, field in ipairs({ "min", "max", "offset", "revert", "ppmCenter", "curve" }) do
        assert_equal(scalar_field(limit.text, field), "0", output .. " " .. field)
      end
    end

    for _, failsafe in ipairs(indexed_blocks(content, "failsafeChannels")) do
      local value = tonumber(scalar_field(failsafe.text, "val"))
      assert(value == 0 or value == -1024 or value == 2001,
        template.name .. " unexpected failsafe " .. tostring(value))
      for _, copied in ipairs(copied_failsafes[template.kind]) do
        assert(value ~= copied, template.name .. " copied calibrated failsafe " .. tostring(copied))
      end
    end

    assert_flight_mode_trims_neutral(content, template.name .. " flight mode")
  end)
end

test("Pocket F3K keeps Flitz screens and physical channel routing", function()
  local content = read_file(F3K)
  assert_equal(scalar_field(indexed_block(content, "screens", 0), "file"), "JF3Ksk", "F3K screen 1")
  assert_equal(scalar_field(indexed_block(content, "screens", 1), "file"), "JFXKcf", "F3K screen 2")

  assert_equal(scalar_field(indexed_block(content, "limitData", 0), "name"), "Ai-L", "F3K CH1")
  assert_equal(scalar_field(indexed_block(content, "limitData", 1), "name"), "Ai-R", "F3K CH2")
  assert_equal(scalar_field(indexed_block(content, "limitData", 2), "name"), "Elev", "F3K CH3")
  assert_equal(scalar_field(indexed_block(content, "limitData", 3), "name"), "Rudd", "F3K CH4")
  assert(find_mix_block_matching(mix_blocks_for(content, 0), { "srcRaw: ch(31)", "weight: -100" }), "F3K missing CH1 aileron path")
  assert(find_mix_block_matching(mix_blocks_for(content, 1), { "srcRaw: ch(31)", "weight: 100" }), "F3K missing CH2 aileron path")
  assert(find_mix_block_matching(mix_blocks_for(content, 2), { "srcRaw: I1", "weight: 100" }), "F3K missing CH3 elevator path")
  assert(find_mix_block_matching(mix_blocks_for(content, 3), { "srcRaw: I0", "weight: 100" }), "F3K missing CH4 rudder path")
  for index = 0, 3 do
    assert_equal(scalar_field(indexed_block(content, "failsafeChannels", index), "val"), "0", "F3K surface failsafe")
  end
end)

test("Pocket F3K keeps Flitz behavior sets", function()
  local content = read_file(F3K)
  assert_named_indexed_set(content, "timers", "name", { "Fli", "Win" }, "F3K timer names")
  assert_named_indexed_set(content, "flightModeData", "name",
    { "Cruise", "Adjust", "Launch", "Zoom", "Speed", "Float" }, "F3K flight modes")
  assert_named_indexed_set(content, "gvars", "name",
    { "Ail", "Brk", "AiR", "Dif", "BkE", "Snp", "Cmb", "Adj", "Tmr" }, "F3K GVars")
  assert_named_indexed_set(content, "curves", "name",
    { "Lft", "Rgt", "BrF", "Snp", "Abs", "DB", "Aln", "LSl" }, "F3K curves")
  assert_named_indexed_set(content, "inputNames", "val",
    { "Rud", "Ele", "Ail", "Brk", "CbP", "Cmb", "Aln", "Pok" }, "F3K inputs")
  assert_index_set(content, "logicalSw",
    { "0", "1", "2", "3", "4", "5", "6", "7", "8", "10", "11", "12", "13", "15", "16", "18", "19", "20", "21", "23", "24", "25", "26", "28", "29", "30", "32", "33", "34" },
    "F3K logical switches")
end)

test("Pocket F3K resets setup curves and keeps utility curve shapes", function()
  local content = read_file(F3K)
  assert_point_values(content, 0, { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, "F3K setup")
  assert_point_values(content, 13, {
    -100, -100, 0, 0, -50, 0, 100, 0, 100, -100, 100, 100, 90, -100, -100, -50,
    -50, 0, 0, 50, 50, 100, 100, -90, -90, -30, -30, 30, 30, 90, 90, 0, 100
  }, "F3K utility")
end)

local f5j_variants = {
  { path = F5J_X, label = "F5J X-tail" },
  { path = F5J_M, label = "F5J M-tail" },
  { path = F5J_V, label = "F5J V-tail" }
}

local common_f5j_mix_signatures = {
  [0] = {
    "src=ch(29)|weight=-100|switch=NONE|curve=0:0|trim=0|mux=ADD|fm=000000000|offset=0|name=",
    "src=I2|weight=gv(0)|switch=NONE|curve=0:!gv(3)|trim=0|mux=ADD|fm=010000000|offset=0|name="
  },
  [1] = {
    "src=ch(29)|weight=100|switch=NONE|curve=0:0|trim=0|mux=ADD|fm=000000000|offset=0|name=",
    "src=I2|weight=gv(0)|switch=NONE|curve=0:gv(3)|trim=0|mux=ADD|fm=010000000|offset=0|name="
  },
  [2] = {
    "src=MAX|weight=-100|switch=NONE|curve=0:0|trim=0|mux=ADD|fm=000000000|offset=0|name=Idle",
    "src=ch(19)|weight=100|switch=NONE|curve=0:0|trim=0|mux=REPL|fm=110111111|offset=0|name=Motor",
    "src=ch(19)|weight=100|switch=NONE|curve=3:13|trim=1|mux=ADD|fm=110111111|offset=0|name=Motor"
  },
  [3] = {
    "src=ch(31)|weight=100|switch=NONE|curve=0:!gv(3)|trim=0|mux=ADD|fm=000000000|offset=0|name=",
    "src=ch(30)|weight=-100|switch=NONE|curve=0:0|trim=0|mux=ADD|fm=000000000|offset=0|name="
  },
  [4] = {
    "src=ch(31)|weight=100|switch=NONE|curve=0:gv(3)|trim=0|mux=ADD|fm=000000000|offset=0|name=",
    "src=ch(30)|weight=100|switch=NONE|curve=0:0|trim=0|mux=ADD|fm=000000000|offset=0|name="
  }
}

for _, variant in ipairs(f5j_variants) do
  test(variant.label .. " keeps common screens, wing, motor, and inputs", function()
    local content = read_file(variant.path)
    assert_equal(scalar_field(indexed_block(content, "screens", 0), "file"), "JF5Jsk", variant.label .. " screen 1")
    assert_equal(scalar_field(indexed_block(content, "screens", 1), "file"), "JFXJcf", variant.label .. " screen 2")

    for index, name in ipairs({ "Ai-L", "Ai-R", "Moto", "Fl-L", "Fl-R" }) do
      assert_equal(scalar_field(indexed_block(content, "limitData", index - 1), "name"), name,
        variant.label .. " CH" .. tostring(index))
    end
    for dest_ch = 0, 4 do
      assert_mix_signatures(content, dest_ch, common_f5j_mix_signatures[dest_ch],
        variant.label .. " CH" .. tostring(dest_ch + 1) .. " exact mixes")
    end

    local brake = find_named_list_block(content, "expoData", 4, "Brake")
    local adjust = find_named_list_block(content, "expoData", 7, "Adjust")
    assert_equal(scalar_field(brake, "srcRaw"), "Thr", variant.label .. " brake source")
    assert_equal(scalar_field(adjust, "srcRaw"), "Thr", variant.label .. " adjust source")
    assert_equal(scalar_field(adjust, "weight"), scalar_field(brake, "weight"), variant.label .. " brake/adjust weight")

    for index = 0, 4 do
      local expected = index == 2 and -1024 or 0
      assert_equal(scalar_field(indexed_block(content, "failsafeChannels", index), "val"), tostring(expected),
        variant.label .. " CH" .. tostring(index + 1) .. " failsafe")
    end
  end)
end

test("F5J variants keep the Sense behavior sets", function()
  for _, variant in ipairs(f5j_variants) do
    local content = read_file(variant.path)
    assert_named_indexed_set(content, "timers", "name", { "Fli", "Mot" }, variant.label .. " timers")
    assert_named_indexed_set(content, "flightModeData", "name",
      { "Cruise", "Adjust", "Motor", "KAPOW", "Speed", "Float" }, variant.label .. " flight modes")
    assert_named_indexed_set(content, "gvars", "name",
      { "Ail", "AiF", "AiR", "Dif", "BkE", "Snp", "CbA", "Adj", "Tmr" }, variant.label .. " GVars")
    assert_named_indexed_set(content, "curves", "name",
      { "LA", "RA", "LF", "RF", "BrF", "BrA", "Snp", "Adj", "Mot", "Abs", "DB", "LSl", "Pot" }, variant.label .. " curves")
    assert_named_indexed_set(content, "inputNames", "val",
      { "Rud", "Ele", "Ail", "Mot", "Brk", "CbP", "Cmb", "Adj" }, variant.label .. " inputs")
    assert_index_set(content, "logicalSw",
      { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "18", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "33", "34", "35", "36", "38", "39", "42", "43", "44" },
      variant.label .. " logical switches")
    for _, unsupported in ipairs({ "gv(11)", "!gv(11)", "L46", "AilEle" }) do
      assert_absent(content, unsupported, variant.label)
    end
  end
end)

test("F5J variants keep common sections and mix routes identical", function()
  local expected = read_file(F5J_X)
  local common_sections = { "timers", "flightModeData", "expoData", "inputNames", "curves", "logicalSw", "gvars" }
  local common_destinations = { 0, 1, 2, 3, 4 }
  for destination = 19, 31 do common_destinations[#common_destinations + 1] = destination end

  for _, variant in ipairs({ f5j_variants[2], f5j_variants[3] }) do
    local actual = read_file(variant.path)
    for _, section in ipairs(common_sections) do
      assert_equal(top_level_section(actual, section), top_level_section(expected, section),
        variant.label .. " common " .. section)
    end
    assert_equal(blocks_for_destinations(actual, common_destinations),
      blocks_for_destinations(expected, common_destinations), variant.label .. " common mixes")
  end
end)

test("F5J variants reset CV1-CV6 and keep utility curve shapes", function()
  local utility = {
    -100, -100, 0, 0, -50, 0, -100, -100, -50, -50, 0, 0, 50, 50, 100, 100,
    -90, -90, -30, -30, 30, 30, 90, 90, -70, 75, 100, 100, 90, 90, 100, 0,
    100, -100, 100, 100, 90, 0, 100, 99, 32, 0, 0
  }
  for _, variant in ipairs(f5j_variants) do
    local content = read_file(variant.path)
    local neutral = {}
    for _ = 1, 30 do neutral[#neutral + 1] = 0 end
    assert_point_values(content, 0, neutral, variant.label .. " setup")
    assert_point_values(content, 30, utility, variant.label .. " utility")
  end
end)

test("F5J X-tail maps rudder and one elevator exactly", function()
  local content = read_file(F5J_X)
  assert_equal(scalar_field(indexed_block(content, "limitData", 5), "name"), "Rudd", "X-tail CH6 name")
  assert_equal(scalar_field(indexed_block(content, "limitData", 6), "name"), "Elev", "X-tail CH7 name")
  assert_mix_signatures(content, 5, {
    "src=I0|weight=100|switch=NONE|curve=0:0|trim=0|mux=ADD|fm=000000000|offset=0|name=",
    "src=I2|weight=gv(2)|switch=NONE|curve=0:0|trim=1|mux=ADD|fm=000000000|offset=0|name=AilRud"
  }, "X-tail CH6 exact mixes")
  assert_mix_signatures(content, 6, {
    "src=ch(21)|weight=100|switch=NONE|curve=0:0|trim=0|mux=ADD|fm=000000000|offset=0|name=",
    "src=I1|weight=100|switch=NONE|curve=0:0|trim=0|mux=ADD|fm=000100000|offset=0|name="
  }, "X-tail CH7 exact mixes")
  assert_mix_signatures(content, 7, {}, "X-tail CH8 exact mixes")
  assert_equal(scalar_field(indexed_block(content, "failsafeChannels", 5), "val"), "0", "X-tail CH6 failsafe")
  assert_equal(scalar_field(indexed_block(content, "failsafeChannels", 6), "val"), "0", "X-tail CH7 failsafe")
end)

test("F5J M-tail maps rudder and two elevators without unsupported AilEle", function()
  local content = read_file(F5J_M)
  assert_equal(scalar_field(indexed_block(content, "limitData", 5), "name"), "Rudd", "M-tail CH6 name")
  assert_equal(scalar_field(indexed_block(content, "limitData", 6), "name"), "Ele-L", "M-tail CH7 name")
  assert_equal(scalar_field(indexed_block(content, "limitData", 7), "name"), "Ele-R", "M-tail CH8 name")
  assert_mix_signatures(content, 5, {
    "src=I0|weight=100|switch=NONE|curve=0:0|trim=0|mux=ADD|fm=000000000|offset=0|name=",
    "src=I2|weight=gv(2)|switch=NONE|curve=0:0|trim=1|mux=ADD|fm=000000000|offset=0|name=AilRud"
  }, "M-tail CH6 exact mixes")
  local elevator = {
    "src=ch(21)|weight=100|switch=NONE|curve=0:0|trim=0|mux=ADD|fm=000000000|offset=0|name=",
    "src=I1|weight=100|switch=NONE|curve=0:0|trim=0|mux=ADD|fm=000100000|offset=0|name="
  }
  assert_mix_signatures(content, 6, elevator, "M-tail CH7 exact mixes")
  assert_mix_signatures(content, 7, elevator, "M-tail CH8 exact mixes")
  for index = 5, 7 do
    assert_equal(scalar_field(indexed_block(content, "failsafeChannels", index), "val"), "0",
      "M-tail CH" .. tostring(index + 1) .. " failsafe")
  end
end)

test("F5J V-tail maps Challenger pitch and yaw signs without AilEle", function()
  local content = read_file(F5J_V)
  assert_equal(scalar_field(indexed_block(content, "limitData", 6), "name"), "Vt-L", "V-tail CH7 name")
  assert_equal(scalar_field(indexed_block(content, "limitData", 7), "name"), "Vt-R", "V-tail CH8 name")
  assert_mix_signatures(content, 5, {}, "V-tail CH6 exact mixes")
  assert_mix_signatures(content, 6, {
    "src=I0|weight=50|switch=NONE|curve=0:0|trim=0|mux=ADD|fm=000000000|offset=0|name=Vt-l",
    "src=ch(21)|weight=-50|switch=NONE|curve=0:0|trim=0|mux=ADD|fm=000000000|offset=0|name=",
    "src=I1|weight=100|switch=NONE|curve=0:0|trim=0|mux=ADD|fm=000100000|offset=0|name="
  }, "V-tail CH7 exact mixes")
  assert_mix_signatures(content, 7, {
    "src=I0|weight=50|switch=NONE|curve=0:0|trim=0|mux=ADD|fm=000000000|offset=0|name=",
    "src=ch(21)|weight=50|switch=NONE|curve=0:0|trim=0|mux=ADD|fm=000000000|offset=0|name=Vt-R",
    "src=I1|weight=100|switch=NONE|curve=0:0|trim=0|mux=ADD|fm=000100000|offset=0|name="
  }, "V-tail CH8 exact mixes")
  assert_equal(scalar_field(indexed_block(content, "failsafeChannels", 6), "val"), "0", "V-tail CH7 failsafe")
  assert_equal(scalar_field(indexed_block(content, "failsafeChannels", 7), "val"), "0", "V-tail CH8 failsafe")
end)

print("1.." .. tostring(#tests))
local failures = 0
for index, case in ipairs(tests) do
  local ok, message = pcall(case.fn)
  if ok then
    print("ok " .. tostring(index) .. " - " .. case.name)
  else
    failures = failures + 1
    print("not ok " .. tostring(index) .. " - " .. case.name)
    print("  ---")
    print("  message: " .. tostring(message):gsub("\n", " "))
    print("  ...")
  end
end

if failures > 0 then os.exit(1) end
