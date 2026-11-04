-- Host tests for the documentation: the README guide links and the screenshots that the README and
-- the guide sources show.

local GUIDE_LANGS = { "en", "ru", "bg" }

local tests = {}

local function test(name, fn)
  tests[#tests + 1] = { name = name, fn = fn }
end

local function assert_true(value, label)
  if not value then
    error(label, 0)
  end
end

local function read_file(path)
  local file, open_error = io.open(path, "rb")
  if not file then
    error("cannot read " .. path .. ": " .. tostring(open_error), 0)
  end
  local content = file:read("a")
  file:close()
  return content
end

local function file_exists(path)
  local file = io.open(path, "rb")
  if file then
    file:close()
    return true
  end
  return false
end

-- Paths of the images that a Markdown or HTML file shows, relative to its folder
local function image_refs(content)
  local refs = {}
  for ref in content:gmatch('<img[^>]-src="([^"]+)"') do
    refs[#refs + 1] = ref
  end
  for ref in content:gmatch("!%[[^%]]*%]%(([^%)]+)%)") do
    refs[#refs + 1] = ref
  end
  return refs
end

local function assert_images_exist(path)
  local dir = path:match("^(.*)/[^/]*$")
  local refs = image_refs(read_file(path))
  for _, ref in ipairs(refs) do
    local full = dir and (dir .. "/" .. ref) or ref
    assert_true(file_exists(full), path .. " shows a missing image: " .. ref)
  end
  return #refs
end

test("README links the M-tail guides in English, Russian, and Bulgarian", function()
  local readme = read_file("README.md")

  for _, lang in ipairs(GUIDE_LANGS) do
    local pdf = "docs/guides/SoarEdgeTX-BW-MTail-" .. lang .. ".pdf"
    assert_true(readme:find("(" .. pdf .. ")", 1, true), "README has no link to " .. pdf)
    assert_true(file_exists(pdf), "missing guide " .. pdf)
    assert_true(file_exists("docs/guides/src/mtail-" .. lang .. ".html"), "missing guide source for " .. lang)
  end
end)

test("README shows only screenshots that exist", function()
  assert_true(assert_images_exist("README.md") > 0, "README should show screenshots")
end)

test("guide sources show only screenshots that exist", function()
  for _, lang in ipairs(GUIDE_LANGS) do
    local path = "docs/guides/src/mtail-" .. lang .. ".html"
    assert_true(assert_images_exist(path) > 0, path .. " should show screenshots")
  end
end)

-- Text from the first `from` up to the first `to` after it, or nil without `from`
local function text_between(content, from, to)
  local start = content:find(from, 1, true)
  if not start then return nil end
  local stop = content:find(to, start + #from, true)
  return content:sub(start, stop and stop - 1 or #content)
end

local THROTTLE_WARNING = {
  en = "throttle warning",
  ru = "предупреждение о газе",
  bg = "предупреждението за газ"
}

test("M-tail guides explain the stick and P1 direction and the camber slider", function()
  for _, lang in ipairs(GUIDE_LANGS) do
    local path = "docs/guides/src/mtail-" .. lang .. ".html"
    local html = read_file(path)
    local section = text_between(html, "<h3>6.10.", "</section>")
    assert_true(section, path .. " has no section 6.10")
    local needles = {
      "<code>I4:Mot</code>", "<code>!Mot</code>", "<code>I5:Brk</code>", "−100 → +100",
      "<code>CambrX</code>", "<code>!LSl</code>", "<code>I8:Adj</code>", "(6.2, 6.3)",
      "<code>I7:Cmb</code>", "<code>Slider</code>", "FM1–FM4", "<code>I6:CbP</code>", "FM1, FM3",
      "S1", "P2", THROTTLE_WARNING[lang]
    }
    for _, needle in ipairs(needles) do
      assert_true(section:find(needle, 1, true), path .. " 6.10 does not mention " .. needle)
    end
    -- The B&W templates have no CbX global variable, no TX16S sliders, and 6.7 is the battery warning
    for _, needle in ipairs({ "CbX", "TX16S", "(6.7)" }) do
      assert_true(not section:find(needle, 1, true), path .. " 6.10 mentions " .. needle)
    end
    local motor_check = text_between(html, "<h3>6.8.", "<h3>6.9.")
    assert_true(motor_check and motor_check:find("(6.10)", 1, true), path .. " 6.8 does not point to 6.10")
  end
end)

test("README explains the motor power and brake direction and the camber slider", function()
  local readme = read_file("README.md")
  local needles = {
    "### Motor Power Direction", "from `Mot` to `!Mot`",
    "### Brake and Camber Direction", "weight of its `Brake` line to `+100`", "from `LSl` to `!LSl`",
    "`I8:Adj`", "throttle warning",
    "### Camber Slider", "`I7:Cmb`", "`FM1` to `FM4`", "`I6:CbP`", "`FM1`, `FM3`, and `FM4`"
  }
  for _, needle in ipairs(needles) do
    assert_true(readme:find(needle, 1, true), "README does not mention " .. needle)
  end
end)

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
