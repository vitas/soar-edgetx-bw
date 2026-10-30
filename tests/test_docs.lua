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
