-- Host tests for the documentation: the README, the reference, the guide links, and the screenshots that
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

-- Text from the first `from` up to the first `to` after it, or nil without `from`
local function text_between(content, from, to)
  local start = content:find(from, 1, true)
  if not start then return nil end
  local stop = content:find(to, start + #from, true)
  return content:sub(start, stop and stop - 1 or #content)
end

-- The README is the short overview; the details are in the reference
local REFERENCE = "docs/reference.md"

test("README links the F3K guide and the M-tail guides in English, Russian, and Bulgarian", function()
  local readme = read_file("README.md")
  local guides = { { "docs/guides/SoarEdgeTX-BW-F3K-en.pdf", "docs/guides/src/f3k-en.html" } }
  for _, lang in ipairs(GUIDE_LANGS) do
    guides[#guides + 1] = {
      "docs/guides/SoarEdgeTX-BW-MTail-" .. lang .. ".pdf", "docs/guides/src/mtail-" .. lang .. ".html"
    }
  end

  for _, guide in ipairs(guides) do
    local pdf, source = guide[1], guide[2]
    assert_true(readme:find("(" .. pdf .. ")", 1, true), "README has no link to " .. pdf)
    assert_true(file_exists(pdf), "missing guide " .. pdf)
    assert_true(file_exists(source), "missing guide source " .. source)
  end
end)

test("README and the reference show only screenshots that exist", function()
  assert_true(assert_images_exist("README.md") > 0, "README should show screenshots")
  assert_true(assert_images_exist(REFERENCE) > 0, REFERENCE .. " should show screenshots")
end)

-- The screens that show at a glance what the package does
local README_SHOTS = {
  "f3k-plugins", "f3k-tasks", "f3k-task", "f3k-flight", "f3k-score", "f3k-menu", "f3k-switches",
  "f3k-channels", "f3k-align", "f3k-center", "f3k-mixes",
  "timer-ready", "timer-armed", "timer-motor", "timer-glide", "timer-landing", "timer-save", "timer-scores",
  "menu", "page-switches", "page-channels", "page-alignment", "page-airbrakes",
  "page-aileron-camber", "page-mixes", "page-battery", "page-motor-idle", "model-restore"
}

test("README is short and shows the F3K, F5J, and setup screens", function()
  local readme = read_file("README.md")
  local shown = {}
  for _, ref in ipairs(image_refs(readme)) do
    shown[ref] = true
  end
  for _, name in ipairs(README_SHOTS) do
    assert_true(shown["docs/images/" .. name .. ".png"], "README does not show " .. name .. ".png")
  end
  local _, lines = readme:gsub("\n", "")
  assert_true(lines < 200, "README has " .. lines .. " lines")
  assert_true(readme:find("(" .. REFERENCE .. ")", 1, true), "README does not link " .. REFERENCE)
  assert_true(readme:find("(dist/SDCARD/SCRIPTS/TELEMETRY/F3K_readme.txt)", 1, true),
    "README does not link the F3K task notes")
end)

test("README says what is new compared to SoarOTX", function()
  local readme = read_file("README.md")
  local news = text_between(readme, "## What's new compared to SoarOTX", "\n## ")
  assert_true(news, "README has no What's new section")
  for _, needle in ipairs({
    "Pocket", "GX12", "M-tail", "`1. Switches`", "throttle stick", "Landing", "`BkE`", "`BrE`", "slider",
    "N. Best flight", "A2", "Motor idle", "disarm", "`SAVE`", "aileron trim", "Flaps up", "guides"
  }) do
    assert_true(news:find(needle, 1, true), "README What's new does not mention " .. needle)
  end
end)

-- Menu items that have the same number in the F3K and F5J menus, or that only one of them has
local MENU_NUMBERS = {
  ["Switches"] = 1, ["Channel configuration"] = 2, ["Align flaps & ailerons"] = 3,
  ["Adjust airbrake curves"] = 4, ["Aileron and camber"] = 5, ["Motor idle"] = 8,
  ["Align flaperons"] = 3, ["Center flaperons"] = 4
}

test("README and the reference number the Configuration menus as the radio does", function()
  local checked = 0
  for _, path in ipairs({ "README.md", REFERENCE }) do
    local content = read_file(path)
    for name, number in pairs(MENU_NUMBERS) do
      for mentioned in content:gmatch("`(%d)%. " .. name:gsub("%p", "%%%0") .. "`") do
        assert_true(tonumber(mentioned) == number,
          path .. " calls " .. name .. " item " .. mentioned .. " instead of " .. number)
        checked = checked + 1
      end
    end
  end
  assert_true(checked >= 8, "README and the reference name only " .. checked .. " menu items")
end)

test("reference explains the F3K Switches page and the brakes on the throttle stick", function()
  local reference = read_file(REFERENCE)
  local section = text_between(reference, "## F3K Switches Page", "\n## ")
  assert_true(section, REFERENCE .. " has no F3K Switches Page section")
  for _, needle in ipairs({
    "`1. Switches`", "images/f3k-switches.png", "`Launch`", "`Speed`", "`Float`", "`Landing`",
    "`Crow off`", "`Alt calls`", "`Alt 10 sec`", "`L7`", "`L3`", "`L4`", "`L8`", "`L35`", "`L1`", "`L6`",
    "`NONE`", "`L50`", "`L52`", "`L53`", "(guides/SoarEdgeTX-BW-F3K-en.pdf)"
  }) do
    assert_true(section:find(needle, 1, true), REFERENCE .. " F3K Switches page does not mention " .. needle)
  end
  -- The F3K templates leave SD free: the brakes and Landing are on the throttle stick
  assert_true(not reference:find("Brake/landing control", 1, true), REFERENCE .. " still gives the F3K brakes to SD")
  for _, heading in ipairs({ "### Pocket Switch Assignments", "## RadioMaster GX12" }) do
    local part = text_between(reference, heading, "\n## ")
    assert_true(part and part:find("[F3K Switches Page](#f3k-switches-page)", 1, true),
      REFERENCE .. " " .. heading .. " does not point to the F3K Switches page")
  end
end)

test("guide sources show only screenshots that exist", function()
  for _, lang in ipairs(GUIDE_LANGS) do
    local path = "docs/guides/src/mtail-" .. lang .. ".html"
    assert_true(assert_images_exist(path) > 0, path .. " should show screenshots")
  end
end)

local THROTTLE_WARNING = {
  en = "throttle warning",
  ru = "предупреждение о газе",
  bg = "предупреждението за газ"
}

test("M-tail guides explain the stick and P1 direction and the camber slider", function()
  for _, lang in ipairs(GUIDE_LANGS) do
    local path = "docs/guides/src/mtail-" .. lang .. ".html"
    local html = read_file(path)
    local section = text_between(html, "<h3>6.10.", "<h3>6.11.")
    assert_true(section, path .. " has no section 6.10")
    local needles = {
      "<code>I4:Mot</code>", "<code>!Mot</code>", "<code>I5:Brk</code>", "−100 → +100",
      "<code>CambrX</code>", "<code>!LSl</code>", "<code>I8:Adj</code>", "(6.2, 6.3)",
      "<code>I7:Cmb</code>", "<code>Slider</code>", "FM1–FM4", "<code>I6:CbP</code>", "FM1, FM3",
      "S1", "P2", THROTTLE_WARNING[lang],
      -- The B&W firmware labels of the throttle warning in MODEL SETUP
      '<span class="ui">Preflight Checks</span>', '<span class="ui">T-Warning</span>', '<span class="ui">Cust-Pos</span>'
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

local SWITCHES_HEADING = {
  en = "<h3>6.11. Switches ",
  ru = "<h3>6.11. Тумблеры ",
  bg = "<h3>6.11. Превключватели "
}

local CAMBER_POT = {
  en = "Float camber on a pot or slider",
  ru = "Камбер Float на потенциометре или слайдере",
  bg = "Камбер Float на потенциометър или плъзгач"
}

test("M-tail guides explain the Switches page", function()
  for _, lang in ipairs(GUIDE_LANGS) do
    local path = "docs/guides/src/mtail-" .. lang .. ".html"
    local section = text_between(read_file(path), "<h3>6.11.", "</section>")
    assert_true(section, path .. " has no section 6.11")
    local needles = {
      SWITCHES_HEADING[lang], '<span class="tag">1. Switches</span>', "../../images/page-switches.png",
      '<span class="ui">Motor arm</span>', '<span class="ui">Motor/timer</span>', '<span class="ui">Speed</span>',
      '<span class="ui">Float</span>', '<span class="ui">Landing</span>', '<span class="ui">Crow off</span>',
      '<span class="ui">Ail-&gt;Ele</span>', '<span class="ui">Rud-&gt;Ele</span>',
      '<span class="ui">Timer report</span>', '<span class="ui">NONE</span>', '<span class="ui">ON</span>',
      '<span class="ui">Motor disarm</span>', "<code>L42</code>",
      "<code>!ON</code>", "<code>L41</code>", "<code>L5</code>", "<code>L9</code>", "<code>L3</code>",
      "<code>L4</code>", "<code>L7</code>", "<code>L36</code>", "<code>L46</code>", "<code>L48</code>",
      "<code>L12</code>", "<code>L50</code>", '<span class="sw">SW1</span>', "Flaps up", "(6.10)",
      -- The list offers the inverted positions too
      '<span class="sw">!SB↓</span>'
    }
    for _, needle in ipairs(needles) do
      assert_true(section:find(needle, 1, true), path .. " 6.11 does not mention " .. needle)
    end
  end
end)

test("M-tail guides point to the Switches page and move the Float camber to a pot", function()
  for _, lang in ipairs(GUIDE_LANGS) do
    local path = "docs/guides/src/mtail-" .. lang .. ".html"
    local html = read_file(path)
    local screens = text_between(html, '<section id="s5">', "</section>")
    assert_true(screens and screens:find('<span class="ui">1. Switches</span>', 1, true),
      path .. " section 5 does not list 1. Switches")
    assert_true(screens:find("(6.11)", 1, true), path .. " section 5 does not point to 6.11")
    local mixes = text_between(html, "<h3>6.6.", "<h3>6.7.")
    assert_true(mixes and mixes:find("(6.11)", 1, true), path .. " 6.6 does not point to 6.11")
    local camber = text_between(html, "<h3>6.10.", "<h3>6.11.")
    for _, needle in ipairs({ CAMBER_POT[lang], "<code>CambrX</code>", "FM5", "(6.11)" }) do
      assert_true(camber and camber:find(needle, 1, true), path .. " 6.10 does not mention " .. needle)
    end
    local flying = text_between(html, '<section id="s7">', '<h2 id="s8">')
    assert_true(flying and flying:find("(6.11)", 1, true), path .. " section 7 does not point to 6.11")
    local troubles = text_between(html, '<h2 id="s8">', '<h2 id="s9">')
    assert_true(troubles and troubles:find('<span class="ui">1. Switches</span>', 1, true),
      path .. " troubleshooting does not mention 1. Switches")
  end
end)

-- The F5J Configuration menu, in the order the radio lists it
local F5J_MENU = {
  "Switches", "Channel configuration", "Align flaps &amp; ailerons", "Adjust airbrake curves",
  "Aileron and camber", "Adjust other mixes", "Battery warning", "Motor idle"
}

test("M-tail guides number the Configuration menu with Switches first", function()
  for _, lang in ipairs(GUIDE_LANGS) do
    local path = "docs/guides/src/mtail-" .. lang .. ".html"
    local html = read_file(path)
    local screens = text_between(html, '<section id="s5">', "</section>")
    local menu = screens and text_between(screens, "<tbody>", "</tbody>")
    local listed = {}
    for item in (menu or ""):gmatch('<tr><td><span class="ui">(%d%. [^<]+)</span>') do
      listed[#listed + 1] = item
    end
    local expected = {}
    for number, name in ipairs(F5J_MENU) do
      expected[number] = number .. ". " .. name
    end
    assert_true(table.concat(listed, " | ") == table.concat(expected, " | "),
      path .. " section 5 lists the menu as " .. table.concat(listed, " | "))

    -- Every mention of a menu item anywhere in the guide carries the item's number
    for number, name in ipairs(F5J_MENU) do
      local at = 1
      while true do
        local first, last, mentioned = html:find("(%d)%. " .. name:gsub("%p", "%%%0"), at)
        if not first then break end
        local before = html:sub(first - 1, first - 1)
        if not before:match("[%d%.]") then
          assert_true(tonumber(mentioned) == number,
            path .. " calls " .. name .. " item " .. mentioned .. " instead of " .. number)
        end
        at = last + 1
      end
    end

    -- References to a page by its menu number, in the order they appear
    local pages = {}
    local pattern = lang == "en" and "[Pp]age (%d)" or "страниц[^%s]* (%d)"
    for number in html:gmatch(pattern) do
      pages[#pages + 1] = number
    end
    assert_true(table.concat(pages, ",") == "6,5,4,4,5,2,4",
      path .. " refers to the menu pages " .. table.concat(pages, ","))
  end
end)

test("reference explains the F5J Switches page and the Float camber on a pot", function()
  local readme = read_file(REFERENCE)
  local section = text_between(readme, "## F5J Switches Page", "\n## ")
  assert_true(section, "reference has no F5J Switches Page section")
  local needles = {
    "`1. Switches`", "images/page-switches.png", "`Motor arm`", "`Motor/timer`", "`Speed`",
    "`Float`", "`Landing`", "`Crow off`", "`Ail->Ele`", "`Rud->Ele`", "`Timer report`", "`NONE`",
    "`!ON`", "`L41`", "`L5`", "`L9`", "`L7`", "`L36`", "`L50`", "`L38`", "`L51`", "`L35`", "`L37`",
    "`flapup.wav`", "`L1`", "`L8`", "`!SB↓`", "`Motor disarm`", "`L42`"
  }
  for _, needle in ipairs(needles) do
    assert_true(section:find(needle, 1, true), "reference Switches page does not mention " .. needle)
  end
  assert_true(not section:find("leaves out inverted", 1, true), "reference says the list leaves out inverted switches")
  local slider = text_between(readme, "### Camber Slider", "\n### ")
  for _, needle in ipairs({ "`CambrX`", "`FM5`", "`P2`", "[F5J Switches Page](#f5j-switches-page)" }) do
    assert_true(slider and slider:find(needle, 1, true), "reference Camber Slider does not mention " .. needle)
  end
  for _, heading in ipairs({ "### Pocket Switch Assignments", "## RadioMaster GX12" }) do
    local part = text_between(readme, heading, "\n## ")
    assert_true(part and part:find("[F5J Switches Page](#f5j-switches-page)", 1, true),
      "reference " .. heading .. " does not point to the Switches page")
  end
  -- L35, the brakes-in zone of the throttle crow, reads I5:Brk
  assert_true(not readme:find("no logical switch or script reads", 1, true),
    "reference still says that no logical switch reads I5:Brk")
end)

test("reference explains the motor power and brake direction and the camber slider", function()
  local readme = read_file(REFERENCE)
  local needles = {
    "### Motor Power Direction", "from `Mot` to `!Mot`",
    "### Brake and Camber Direction", "weight of its `Brake` line to `+100`", "from `LSl` to `!LSl`",
    "`I8:Adj`", "throttle warning", "`Preflight Checks`", "`Cust-Pos`",
    "### Camber Slider", "`I7:Cmb`", "`FM1` to `FM4`", "`I6:CbP`", "`FM1`, `FM3`, and `FM4`"
  }
  for _, needle in ipairs(needles) do
    assert_true(readme:find(needle, 1, true), "reference does not mention " .. needle)
  end
end)

-- FM3 Landing replaced KAPOW: the brake stick switches it while Landing and Crow off are NONE
test("M-tail guides explain the Landing flight mode", function()
  for _, lang in ipairs(GUIDE_LANGS) do
    local path = "docs/guides/src/mtail-" .. lang .. ".html"
    local html = read_file(path)
    local section = text_between(html, "<h3>6.11.", "</section>")
    assert_true(section, path .. " has no section 6.11")
    for _, needle in ipairs({ "<code>FM3</code>", "<code>L52</code>", "<code>L53</code>", "<code>BkE</code>" }) do
      assert_true(section:find(needle, 1, true), path .. " 6.11 does not mention " .. needle)
    end
    assert_true(not html:find("KAPOW", 1, true), path .. " still mentions KAPOW")
  end
end)

test("reference explains the Landing flight mode and the aileron trim line", function()
  assert_true(not read_file("README.md"):find("KAPOW", 1, true), "README still mentions KAPOW")
  local readme = read_file(REFERENCE)
  local switches = text_between(readme, "## F5J Switches Page", "\n## ")
  for _, needle in ipairs({ "`FM3`", "`L52`", "`L53`" }) do
    assert_true(switches and switches:find(needle, 1, true), "reference Switches page does not mention " .. needle)
  end
  local pocket = text_between(readme, "## Pocket Templates", "\n## ")
  for _, needle in ipairs({ "`AilTrm`", "`T4`", "`Trm`" }) do
    assert_true(pocket and pocket:find(needle, 1, true), "reference Pocket Templates does not mention " .. needle)
  end
  assert_true(not readme:find("KAPOW", 1, true), "reference still mentions KAPOW")
end)

-- On black-and-white radios Create model makes an empty model, and Restore model lists only /BACKUP
test("M-tail guides explain Create model and the /BACKUP folder of Restore model", function()
  for _, lang in ipairs(GUIDE_LANGS) do
    local path = "docs/guides/src/mtail-" .. lang .. ".html"
    local html = read_file(path)
    local create = text_between(html, '<section id="s3">', "<h3>")
    assert_true(create, path .. " has no section 3")
    for _, needle in ipairs({
      '<span class="ui">Create model</span>', '<span class="ui">Delete model</span>',
      "<code>/TEMPLATES</code>", "No models on SD"
    }) do
      assert_true(create:find(needle, 1, true), path .. " section 3 does not mention " .. needle)
    end
    local trouble = text_between(html, '<h2 id="s8">', '<h2 id="s9">')
    assert_true(trouble, path .. " has no section 8")
    for _, needle in ipairs({ "No models on SD", "<code>/TEMPLATES</code>" }) do
      assert_true(trouble:find(needle, 1, true), path .. " section 8 does not mention " .. needle)
    end
  end
end)

-- The GX12 F5J templates latch SA in Customizable Switches, and a motor stop disarms. The radio
-- no longer lengthens SA presses, so it does not skip quick ones. The needles are the old sentence,
-- because the RU Landing text says "полсекунды" about the brakes.
local QUICK_PRESSES = {
  en = "half a second apart", ru = "чаще чем раз в полсекунды", bg = "по-често от веднъж на половин секунда"
}

test("M-tail guides explain the SA latch of the GX12 and the disarm at the motor stop", function()
  for _, lang in ipairs(GUIDE_LANGS) do
    local path = "docs/guides/src/mtail-" .. lang .. ".html"
    local html = read_file(path)
    local screens = text_between(html, '<section id="s5">', "</section>")
    local trouble = text_between(html, '<h2 id="s8">', '<h2 id="s9">')
    for _, part in ipairs({ { "section 5", screens }, { "section 8", trouble } }) do
      for _, needle in ipairs({ '<span class="ui">Customizable Switches</span>', '<span class="ui">2POS</span>' }) do
        assert_true(part[2] and part[2]:find(needle, 1, true), path .. " " .. part[1] .. " does not mention " .. needle)
      end
    end
    assert_true(not html:find(QUICK_PRESSES[lang], 1, true), path .. " says the radio skips quick SA presses")
  end
end)

test("reference explains the SA latch of the GX12 and the disarm at the motor stop", function()
  local readme = read_file(REFERENCE)
  local gx12 = text_between(readme, "## RadioMaster GX12", "\n## ")
  assert_true(gx12, "reference has no RadioMaster GX12 section")
  for _, needle in ipairs({ "`Customizable Switches`", "`2POS`", "`L42`" }) do
    assert_true(gx12:find(needle, 1, true), "reference GX12 section does not mention " .. needle)
  end
  assert_true(not readme:find(QUICK_PRESSES.en, 1, true), "reference says the radio skips quick SA presses")
  local pocket = text_between(readme, "### Pocket Switch Assignments", "\n## ")
  assert_true(pocket and pocket:find("`L42`", 1, true), "reference Pocket switches do not mention L42")
end)

-- On the F5J Save screen the roller selects SAVE or EXIT, and EXIT is selected first. A motor
-- restart after the motor run starts a new flight with the working time from Tgt, instead of
-- ending the flight with zero.
local EXIT_FIRST = {
  en = '<span class="ui">EXIT</span> at first',
  ru = 'сначала это <span class="ui">EXIT</span>',
  bg = 'отначало това е <span class="ui">EXIT</span>'
}
local RESTART_TITLE = {
  en = '<span class="t">Motor restart</span>',
  ru = '<span class="t">Повторный запуск мотора</span>',
  bg = '<span class="t">Повторно пускане на мотора</span>'
}
local ZERO_RESULT = { en = "Zero result", ru = "Нулевой результат", bg = "Нулев резултат" }

test("M-tail guides explain the Save screen choice and the motor restart", function()
  for _, lang in ipairs(GUIDE_LANGS) do
    local path = "docs/guides/src/mtail-" .. lang .. ".html"
    local html = read_file(path)
    local flying = text_between(html, '<section id="s7">', '<h2 id="s8">')
    assert_true(flying, path .. " has no section 7")
    for _, needle in ipairs({
      '<span class="ui">SAVE</span>', '<span class="ui">EXIT</span>', EXIT_FIRST[lang], RESTART_TITLE[lang]
    }) do
      assert_true(flying:find(needle, 1, true), path .. " section 7 does not mention " .. needle)
    end
    local restart = text_between(flying, RESTART_TITLE[lang], "</div>")
    assert_true(restart and restart:find('<span class="ui">Tgt</span>', 1, true),
      path .. " does not say that a restarted flight starts from Tgt")
    assert_true(not html:find(ZERO_RESULT[lang], 1, true), path .. " still describes the zero result")
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
