--[[
pandoc-linguex: make interlinear glossing with pandoc

Copyright © 2021 Michael Cysouw <cysouw@mac.com>

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
]]

-- because of new table structure:
PANDOC_VERSION:must_be_at_least '2.10'

---------------------
-- 'global' variables
---------------------

local counter = 0 -- actual numbering of examples
local chapter = 0 -- numbering of chapters
local counterInChapter = 0 -- counter reset for each chapter
local indexEx = {} -- global lookup for example IDs
local orderInText = 0 -- order of references for resolving "Next"-style references
local indexRef = {}     -- key/value: order in text = refID/exID
local nextRefIndex = {} -- key/value: next ref id = order position of ref

------------------------------------
-- User Settings with default values
------------------------------------

local formatGloss = false -- format interlinear examples
local xrefSuffixSep = " " -- &nbsp; separator to be inserted after number in example references
local restartAtChapter = false -- restart numbering at highest header without adding local chapternumbers
local addChapterNumber = false -- add chapternumbers to counting and restart at highest header
local latexPackage = "linguex"
local topDivision = "section"
local noFormat = false
local documentclass = "article"

function getUserSettings (meta)
  if meta.formatGloss ~= nil then
    formatGloss = meta.formatGloss
  end
  if meta.noFormat ~= nil then
    noFormat = meta.noFormat
  end
  if meta.xrefSuffixSep ~= nil then
    xrefSuffixSep = pandoc.utils.stringify(meta.xrefSuffixSep)
  end
  if meta.restartAtChapter ~= nil then
    restartAtChapter = meta.restartAtChapter
  end
  if meta.addChapterNumber ~= nil then
    addChapterNumber = meta.addChapterNumber
  end
  if meta.latexPackage ~= nil then
    latexPackage = pandoc.utils.stringify(meta.latexPackage)
  end
  if meta["top-level-division"] ~= nil then
    topDivision = pandoc.utils.stringify(meta["top-level-division"])
  end
  if meta.documentclass ~= nil then
    documentclass = pandoc.utils.stringify(meta.documentclass)
  end
end

------------------------------------------
-- add latex dependencies: langsci-gb4e is not on CTAN!
-- restarting of counters is not working right for gb4e
------------------------------------------

function addFormatting (meta)

  local tmp = pandoc.MetaList{meta['header-includes']}
  if meta['header-includes'] ~= nil then
    tmp = meta['header-includes']
  end

  if FORMAT:match "html" then
    -- add specific CSS for layout of examples
    -- building on classes set in this filter
    -- local f = io.open("pandoc-ling.css")
    -- local css = f:read("*a")
    -- f:close()
    local css = [[
<!-- CSS added by lua-filter 'pandoc-ling' -->
<style>
.linguistic-example { 
  margin: 0; 
}
.linguistic-example caption { 
  margin-bottom: 0; 
}
.linguistic-example tbody { 
  border-top: none; 
  border-bottom: none;
}
.linguistic-example-preamble {
  height: 1em;
  vertical-align: top; 
}
.linguistic-example td {
  padding-left: 0;
}
.linguistic-example-content { 
  vertical-align: top;  
}
.linguistic-example-label {
  vertical-align: top;
}
.linguistic-example-judgement { 
  vertical-align: top; 
  padding-right: 2px;
}
.linguistic-example-gloss {
  /*width: 100px;*/
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-start;
  align-items: flex-start;
}
.linguistic-example-gloss table {
  width: auto;
  margin-top: 0px;
  margin-right: 1em;
  margin-bottom: 5px;
}
.linguistic-example-gloss tbody {
  border-top: none; 
  border-bottom: none;

}
.linguistic-example-gloss tr:first-child {
  font-style: italic;
}
.linguistic-example-gloss td {
  padding: 0em;
}
</style>
      ]]
    tmp[#tmp+1] = pandoc.MetaBlocks(pandoc.RawBlock("html", css))
    meta['header-includes'] = tmp
  end
  
  local function add (s)
    tmp[#tmp+1] = pandoc.MetaBlocks(pandoc.RawBlock("tex", s))
  end
  
  if FORMAT:match "latex" or FORMAT:match "beamer" then
  
    if latexPackage == "linguex" then
      add("\\usepackage{linguex}")
      -- no brackets
      add("\\renewcommand{\\theExLBr}{}")
      add("\\renewcommand{\\theExRBr}{}")
      -- space for judgements
      add("\\newcommand{\\jdg}[1]{\\makebox[0.4em][r]{\\normalfont#1\\ignorespaces}}")
      -- chapternumbes
      add("\\usepackage{chngcntr}")
      if addChapterNumber then
        add("\\counterwithin{ExNo}{"..topDivision.."}")
        add("\\renewcommand{\\Exarabic}{\\the"..topDivision..".\\arabic}")
      elseif restartAtChapter then
        add("\\counterwithin*{ExNo}{"..topDivision.."}")
      end

    elseif latexPackage == "gb4e" then
      add("\\usepackage{"..latexPackage.."}")
      add("\\noautomath")
      -- nnext package does not work with added top level number
      -- add("\\usepackage[noparens]{nnext}")
      add("\\usepackage{chngcntr}")
      if addChapterNumber then
        add("\\counterwithin{xnumi}{"..topDivision.."}")
        add("\\counterwithin{exx}{"..topDivision.."}")
        add("\\exewidth{(9.123)}")
      elseif restartAtChapter then
        add("\\counterwithin*{exx}{"..topDivision.."}")
      end

    elseif latexPackage == "langsci-gb4e" then
      add("\\usepackage{"..latexPackage.."}")
      -- nnext package does not work with added top level number
      -- add("\\usepackage[noparens]{nnext}")
      add("\\usepackage{chngcntr}")
      if addChapterNumber then
        add("\\counterwithin{xnumi}{"..topDivision.."}")
        --add("\\counterwithin{exx}{"..topDivision.."}")
        add("\\exewidth{(9.123)}")
      elseif restartAtChapter then
        add("\\counterwithin*{xnumi}{"..topDivision.."}")
      end

    elseif latexPackage == "expex" then
      add("\\usepackage{expex}")
      add("\\lingset{ \
            belowglpreambleskip = -1.5ex, \
            aboveglftskip = -1.5ex, \
            exskip = 0ex, \
            interpartskip = -0.5ex, \
            belowpreambleskip = -2ex \
          }")
      if addChapterNumber then
        if documentclass == "book" then
          add("\\lingset{exnotype=chapter.arabic}")
        end
      end
      if restartAtChapter then
        --add("\\usepackage{epltxchapno}")
        add("\\usepackage{etoolbox}")
        add("\\pretocmd{\\"..topDivision.."}{\\excnt=1}{}{}")
      end

    end
    meta['header-includes'] = tmp
  end

  return meta
end

-------------------------------------------
-- add temporary divs to first header level
-------------------------------------------

-- will be removed again once the chapters are counted
function addDivToHeader (head)
  if  head.tag == "Header" 
      and head.level == 1 
      and head.classes[1] ~= "unnumbered"
  then
    return pandoc.Div(head, pandoc.Attr(nil, {"restart"}))
  end
end

----------------------------
-- parse/rewrite example div
----------------------------

function processDiv (div)

  -- keep track of chapters (header == 1)
  -- included in this loop by trick "addDivToHeader"
  if div.classes[1] == "restart" then
    chapter = chapter + 1
    counterInChapter = 0
    -- remove div
    return div.content
  end

  -- only do formatting for divs with class "ex"
  if div.classes[1] == "ex" then

    -- check format override per example
    local saveGlobalformatGloss = formatGloss
    if div.attributes.formatGloss ~= nil then
      formatGloss = div.attributes.formatGloss
    end

    local saveGlobalnoFormat = noFormat
    if div.attributes.noFormat ~= nil then
      noFormat = div.attributes.noFormat
    end

    -- parse!
    local parsedDiv = parseDiv(div)

    -- add temporary Cite to resolve "Next"-type references
    -- will be removed after cross-references are in place
    local tmpCite = pandoc.Plain(pandoc.Cite(
            {pandoc.Str("@Target")},
            {pandoc.Citation(parsedDiv.exID,"NormalCitation")}))

    -- reformat!
    local example
    if FORMAT:match "latex" or FORMAT:match "beamer" then
      example = texMakeExample(parsedDiv)
    else
      example = pandocMakeExample(parsedDiv)
      example = pandoc.Div(example, pandoc.Attr("ex"..parsedDiv.number) )
    end

    -- return to global setting
    formatGloss = saveGlobalformatGloss
    noFormat = saveGlobalnoFormat

    return { tmpCite, example }
  end
end

------------
-- parse div
------------

function parseDiv (div)

  -- keep count of examples
  counter = counter + 1
  counterInChapter = counterInChapter + 1
  
  -- format the numbering
  local number = counter
  if addChapterNumber then
    number = chapter.."."..counterInChapter
  elseif restartAtChapter then
    number = counterInChapter
  end
  
  -- make identifier for example
  local exID = ""
  if div.identifier == "" then
    if restartAtChapter then
      -- to resolve clashes with same number used in different chapters
      exID = "ex"..chapter.."."..counterInChapter
    else
      -- use actual number
      exID = "ex"..number
    end
  else
      -- or keep user-provided identifier
    exID = div.identifier
  end
  
  -- keep global index of ids/numbers for crossreference
  indexEx[exID] = number
  
  -- extract preamble
  local preamble = nil	
  local data = div.content[1]
  if #div.content== 2 then
    preamble = pandoc.Plain(div.content[1].content)
    data = div.content[2]
  end

  -- extract judgements and content of examples
  local judgements = {}
  local examples = {}
  local kind = {}

  if noFormat then
    preamble = nil
    kind[1] = "single"
    judgements[1] = nil
    examples[1] = div
  elseif data.tag == "OrderedList" or data.tag == "BulletList" then
    for i=1,#data.content do
      judgements[i], examples[i], kind[i] = parseExample(data.content[i][1])
    end
  else
    judgements[1], examples[1], kind[1] = parseExample(data)
  end

  return { 	kind = kind, -- list of single/interlinear
            preamble = preamble,   -- preamble is Plain
            judgements = judgements, -- judgements is list of Str
            examples = examples,   -- examples is list of (list of) Plain
            number = number,       -- number, exID are bare string
            exID = exID 
          }
end

----------------------------------
-- parse various kinds of examples
----------------------------------

function parseExample (data)

  local judgement, example, kind

  -- either a single line example
  if data.tag == "Para" or data.tag == "Plain" then
    judgement, example = splitJudgement(data.content)
    example = pandoc.Plain(example)
    kind = "single"

  -- or an interlinear example
  elseif data.tag == "LineBlock" then
    judgement, example = parseInterlinear(data.content)
    kind = "interlinear"
  end

  -- judgement is Str, example is (list of) Plain
  return judgement, example, kind
end

-------------------------------

function parseInterlinear (block)

  local interlinear = {}
  local judgement, source = splitJudgement( block[2] )

  -- header
  interlinear["header"] = pandoc.Plain( block[1] )
  -- source
  interlinear["source"] = splitSource(source)
  -- gloss
  interlinear["gloss"] = splitGloss( block[3] )
  -- translation
  interlinear["trans"] = getTrans( block[#block] )

  -- judgement is Str
  -- (header, trans) in interlinear is Plain
  -- (source, gloss) in interlinear is list of Plain
  return judgement, interlinear
end

----------------------------------------
-- helper functions to parse interlinear
----------------------------------------

function splitSource (line)
  local splitSource = splitPara(line)
  if formatGloss then
    -- remove format and make emph throughout
    for i=1,#splitSource do 
      local string = pandoc.utils.stringify(splitSource[i])
      splitSource[i] = pandoc.Plain(pandoc.Emph(string))
    end
  end
  -- list of Plain
  return splitSource
end

-------------------------------

function splitGloss (line)
  local splitGloss = splitPara(line)
  if formatGloss then 
    -- remove format and turn capital-sequences into smallcaps
    for i=1,#splitGloss do 
      local string = pandoc.utils.stringify(splitGloss[i])
      splitGloss[i] = pandoc.Plain(formatGlossLine(string))
    end 
  end 
  -- list of Plain
  return splitGloss
end

-------------------------------

function getTrans (line)
  if formatGloss then
    -- remove quotes and add singlequote througout
    if line[1].tag == "Quoted" then
      line = line[1].content
    end
    line = pandoc.Quoted("SingleQuote", line)
  end
  return pandoc.Plain(line)
end

------------------------------------------
-- helper functions for (lists of) inlines
------------------------------------------

function formatGlossLine (s)
  -- turn uppercase in gloss into small caps
  local split = {}
  for lower,upper in string.gmatch(s, "(.-)([%u%d][%u%d]+)") do
    if lower ~= "" then
      lower = pandoc.Str(lower)
      table.insert(split, lower)
    end
    upper = pandoc.SmallCaps(pandoc.text.lower(upper))
    table.insert(split, upper)
  end
  for leftover in string.gmatch(s, "[%u%d][%u%d]+(.-[^%u%s])$") do
    leftover = pandoc.Str(leftover)
    table.insert(split, leftover)
  end
  if #split == 0 then
    if s == "~" then s = "   " end -- sequence "space-nobreakspace-space"
    table.insert(split, pandoc.Str(s))
  end
  -- result is list of inlines
  return split
end

function splitPara (p)
  -- remove quotes, they interfere with the splitting
 if p[1].tag == "Quoted" then
   p = p[1].content
 end
 -- push down emphasis to the individual words
 if p[1].tag == "Emph" then
  p = pandoc.walk_inline( p, { 
    Str = function(s) return Emph(s) end 
  } )
  end
  -- split paragraph in subtables at Space 
  -- to insert paragraph into pandoc.Table
  -- Is there a better way to do this in Pandoc-Lua?
  local start = 1
  local result = {}
  for i=1,#p do
    if p[i].tag == "Space" then
     -- take everythins from start up to the space
      local chunk = table.move(p, start, i-1, 1, {})
      table.insert(result, pandoc.Plain(chunk) )
      -- move start to after space
      start = i + 1
    end
  end
  -- everything after the last space
  if start <= #p then
    local chunk = table.move(p, start, #p, 1, {})
    table.insert(result, pandoc.Plain(chunk) )
  end
  -- result is list of Plain chunks
  return result
end

function splitJudgement (line)
  local judgement = nil
  local first = pandoc.utils.stringify(line[1])
  -- complex judgements, e.g. with formatting
  if first == "^" then
    judgement = line[2]
    for i=1,3 do table.remove(line, 1) end
  -- simple judgement, only a string
  elseif string.sub(first, 1, 1) == "^" then
    judgement = pandoc.Str(string.sub(first, 2))
    for i=1,2 do table.remove(line, 1) end
  end
  -- judgement is Str, line is list of inlines
  return judgement, line
end

--------------
-- rewrite div
--------------

function pandocMakeExample (parsedDiv)

  -- sequences of 'single' will be combined into one output table
  local kind = parsedDiv.kind
  local onlySingle = true
  for i=1,#kind do
    if kind[i] ~= "single" then
      onlySingle = false
    end
  end

  -- prepare the examples for output as tables
  local example = {}
  if noFormat then
    example[1] = pandocNoFormat(parsedDiv)
  elseif #kind == 1 and kind[1] == "single" then
    example[1] = pandocMakeSingle(parsedDiv)
  else
    example[1] = pandocMakeList(parsedDiv)
  end

  -- Add example number to top left of first table
  local numberParen = pandoc.Plain( "("..parsedDiv.number..")" )
  example[1].bodies[1].body[1][2][1].contents[1] = numberParen
  
  -- set class and vertical align for noFormat
  if noFormat then
    example[1].bodies[1].body[1][2][1].attr = 
      pandoc.Attr(nil, {"linguistic-example-number"}, {style = "vertical-align: middle;"})
  else
    example[1].bodies[1].body[1][2][1].attr = 
      pandoc.Attr(nil, {"linguistic-example-number"}, {style = "vertical-align: top;"})
  end

  return example
end

function pandocNoFormat (parsedDiv)

  -- make a simple 1x2 table with the whole div in the second cell
  local example = turnIntoTable({{ {}, {parsedDiv.examples[1]} } } , 2, 0)
  -- set class of content
  example.bodies[1].body[1][2][2].attr = 
    pandoc.Attr(nil, {"linguistic-example-content"})

  return example
end

function pandocMakeSingle (parsedDiv)

  -- basic content
  local exampleLine = parsedDiv.examples[1]
  local rowContent = { {{ exampleLine }} }
  -- set dimensions
  local nCols = 1
  local nRows = 1
  local judgeCol = 1
  -- add judgements
  local judgement = parsedDiv.judgements[1]
  if judgement ~= nil then 
    rowContent = addCol ( rowContent )
    nCols = nCols + 1
    judgeCol = judgeCol + 1
    rowContent[1][1][1] = pandoc.Plain(judgement)
  end
  -- add preamble
  local preamble = parsedDiv.preamble
  if preamble ~= nil then
    if judgement ~= nil then
      table.insert(rowContent, 1, { {}, { preamble } } )
    else
      table.insert(rowContent, 1, {{ preamble }} )
    end
    nRows = nRows + 1
  end
  -- add number column
  rowContent = addCol(rowContent)
  nCols = nCols + 1

  -- make into table
  local example = turnIntoTable(rowContent, nCols, judgeCol)

  -- set class of content
    example.bodies[1].body[nRows][2][nCols].attr = 
      pandoc.Attr(nil, {"linguistic-example-content"})
  -- set class of preamble
  if preamble ~= nil then
    example.bodies[1].body[1][2][nCols].attr = 
      pandoc.Attr(nil, {"linguistic-example-preamble"})
  end
  -- set class of judgment
    if judgeCol > 1 then
    example.bodies[1].body[nRows][2][judgeCol].attr = 
      pandoc.Attr(nil, {"linguistic-example-judgement"})
    end

  return example
end

function pandocMakeInterlinear (interlinear, forceJudge)
    -- basic content
  local source = interlinear.source
  local gloss  = interlinear.gloss 

  local widths = {0, 0}
  local aligns = {"AlignLeft"}

  sourceGlossTables = {}
  for i=1,#source do
    local currentTable = pandoc.SimpleTable(
      {},
      aligns,
      widths,
      {},
      {{{source[i]}}, {{gloss[i]}}}
    )
    currentTable = pandoc.utils.from_simple_table(currentTable)
    table.insert(sourceGlossTables, currentTable)
  end
  local glossDiv = pandoc.Div(sourceGlossTables, {class="linguistic-example-gloss"})

  return pandoc.Div({
    interlinear.header,
    glossDiv,
    interlinear.trans
  })
end

function pandocMakeList (parsedDiv, from, to, forceJudge)
  -- for a group of subsequent single examples
  local lines      = parsedDiv.examples
  local judgements = parsedDiv.judgements
  local kind       = parsedDiv.kind

  if from == nil then from = 1 end
  if to == nil then to = #lines end

  -- basic content
  local rowContent = { }
  for i=from,to do
    if kind[i] ~= "interlinear" then
      table.insert(rowContent, {{ lines[i] }} )
    else
      table.insert(rowContent, {{ pandocMakeInterlinear(lines[i], nil) }} )
    end
  end
  -- set dimensions
  local nCols = 1
  local nRows = #rowContent
  local judgeCol = 0
  -- add judgements
  for i=from,to do
    if judgements[i] ~= nil or forceJudge then 
      rowContent = addCol ( rowContent )
      nCols =  nCols + 1
      judgeCol = judgeCol + 2
      break
    end
  end
  for i=from,to do
    if judgements[i] ~= nil then
      rowContent[i][1][1] = pandoc.Plain(judgements[i])
    end
  end
  -- add labels
  local labels = {}
  -- do not add label if there is just one interlinear gloss
  local needsLabels = not(to - from == 0 and kind[from] == "interlinear")
  if needsLabels  then
    for i=from,to do 
      local label = pandoc.Str(string.char(96+i)..".")
      table.insert(rowContent[i], 1, { pandoc.Plain(label) })
    end
    nCols = nCols + 1
    judgeCol = judgeCol + 1
  end

  -- add preamble
  local preamble = parsedDiv.preamble
  if preamble ~= nil then
    table.insert(rowContent, 1, {{ preamble }} )
    nRows = nRows + 1
  end
  -- add number column
  rowContent = addCol(rowContent)
  nCols = nCols + 1

  -- make into table
  local example = turnIntoTable(rowContent, nCols, judgeCol)
  
  -- set class of content and labels
  local start = 1
  if preamble ~= nil then start = 2 end
  for i=start,nRows do
    example.bodies[1].body[i][2][nCols].attr = 
      pandoc.Attr(nil, {"linguistic-example-content"})
    if needsLabels then
      example.bodies[1].body[i][2][2].attr = 
        pandoc.Attr(nil, {"linguistic-example-label"})
    end
  end
  -- set class of judgment
  if judgeCol > 1 then
    for i=start,#example.bodies[1].body do
      example.bodies[1].body[i][2][judgeCol].attr = 
        pandoc.Attr(nil, {"linguistic-example-judgement"})
    end
  end
  -- set class of preamble and extend cell
  if preamble ~= nil then
    example.bodies[1].body[1][2][2].attr = 
      pandoc.Attr(nil, {"linguistic-example-preamble"})
    example.bodies[1].body[1][2][2].col_span = nCols - 1
  end

  return example
end


--------------------------------------
-- helper functions to format examples
--------------------------------------

function addCol (lines)
  for i=1,#lines do
    table.insert(lines[i], 1, {})
  end
  return lines
end

function sLength (j)
  if j == nil then
    return 0
  else
    return utf8.len(pandoc.utils.stringify(j)) 
  end
end

-------------------------------

function turnIntoTable (rowContent, nCols, judgeCol)
  -- turn examples into Tables for alignment
  -- use simpleTable for construction
  local caption = {}
  local headers = {}
  local aligns = {}
    for i=1,nCols do aligns[i] = "AlignLeft" end
    aligns[1] = "AlignDefault"
    if judgeCol > 1 then
      aligns[judgeCol] = "AlignRight" -- Column for grammaticality judgements
    end
  local widths = {}
    for i=1,nCols do widths[i] = 0 end
  local rows = rowContent

  local result = pandoc.SimpleTable(
      caption,
      aligns,
      widths,
      headers,
      rows
  )
  -- turn into fancy new tables
  result = pandoc.utils.from_simple_table(result)

  -- set class of table to "example" for styling via CSS
  result.attr = { class = "linguistic-example" }

  return result
end

--------------------------
-- make markup in Latex
--------------------------

-- convenience functions for Latex

function texFront (tex, pndc)
  return table.insert(pndc, 1, pandoc.RawInline("tex", tex))
end

function texEnd (tex, pndc)
  return table.insert(pndc, pandoc.RawInline("tex", tex))
end

function texCombine (separated)
  -- to align source/gloss they are separated
  -- for Latex, they have to returned to one object
  local result = pandoc.List()
  for i=1,#separated do 
    separated[i]=separated[i].content
    table.insert(separated[i], pandoc.Space())
    result:extend(separated[i])
  end
  return(result)
end

function texSquashMulti (multi)
  -- for 'noFormat' content
  local result = pandoc.List()
  if multi.tag == "Div" then
    for i=1,#multi.content do
      result:extend(multi.content[i].content)
      texEnd("\\\\\n  ", result)
    end
  else
    result = multi.content
  end
  return result
end

-- send request to different packages

function texMakeExample (parsedDiv)
  local result
  if latexPackage == "expex" then
    result = texMakeExpex(parsedDiv)
  elseif latexPackage == "linguex" then
    result = texMakeLinguex(parsedDiv)
  elseif latexPackage == "gb4e" then
    result = texMakeGb4e(parsedDiv)
  elseif latexPackage == "langsci-gb4e" then
    result = texMakeLangsci(parsedDiv)
  end
  return result
end

-------------------------
-- Different tex packages
-------------------------

function texMakeExpex (parsedDiv)

  -- prepare parsed chunks
  local kind = parsedDiv.kind
  local ID = parsedDiv.exID
  local preamble = parsedDiv.preamble
  local judgements = parsedDiv.judgements
  local line, header, source, gloss, trans

  if preamble == nil then 
    preamble = pandoc.List() 
  else 
    preamble = preamble.content
    texEnd("\\\\", preamble)
  end

  local judgeMax = ""
  for i=1,#kind do
    if sLength(judgements[i]) > sLength(judgeMax) then
      judgeMax = judgements[i]
    end
  end
  local judgeOffset = "[*="..string.gsub(pandoc.utils.stringify(judgeMax), "([#$%&_{}~^])", "\\%1").."]"

  for i=1,#kind do
    if judgements[i] == nil then 
      judgements[i] = { pandoc.RawInline("tex","") }
    elseif #kind == 1 and kind[1] == "single" then
      judgements[i] = { judgements[i] }
      texFront("\n  \\judge{", judgements[i])
      texEnd("} ", judgements[i])
    else
      judgements[i] = { judgements[i] }
      texFront("\\ljudge{", judgements[i])
      texEnd("}", judgements[i])
    end
  end

  -- build Latex code starting with preamble and adding rest to it

  if #kind == 1 and kind[1] == "single" then
    texFront("\\ex<"..ID.."> ", preamble)
  elseif #kind ==1 and kind[1] == "interlinear" then
    texFront("\\ex"..judgeOffset.."<"..ID.."> ", preamble)
  else
    texFront("\\pex"..judgeOffset.."<"..ID.."> ", preamble)
  end
  texFront("\\begin{samepage}\n", preamble)

  for i=1,#kind do
    if kind[i] == "single" then

      line = texSquashMulti(parsedDiv.examples[i])

      if #kind > 1 then 
        texFront("\n  \\a ", judgements[i])
      else 
        texFront("\n  ", judgements[i])
      end

      preamble:extend(judgements[i])
      preamble:extend(line)

    elseif kind[i] == "interlinear" then

      header = parsedDiv.examples[i].header.content
      source = parsedDiv.examples[i].source
      gloss  = parsedDiv.examples[i].gloss
      trans  = parsedDiv.examples[i].trans.content
      
      source = texCombine(source)
      gloss  = texCombine(gloss)

      if pandoc.utils.stringify(header) == "" then
        header = pandoc.List()
      else
        texFront("\n  \\glpreamble ", header)
        texEnd("//", header)
      end

      if #kind > 1 then 
        texEnd("\n  \\a ", preamble)
      end 

      texEnd("\n  \\begingl", preamble)
      preamble:extend(header)
      texFront("\n  \\gla ", judgements[i])
      preamble:extend(judgements[i])
      texEnd("//", source)
      preamble:extend(source)
      texFront("\n  \\glb ", gloss)
      texEnd("//", gloss)
      preamble:extend(gloss)
      texFront("\n  \\glft ", trans)
      texEnd("//", trans)
      preamble:extend(trans)
      texEnd("\n  \\endgl", preamble)

    end
  end
  texEnd("\n\\xe\n\\end{samepage}", preamble)
  return pandoc.Plain(preamble)
end

----------------------

function texMakeLinguex (parsedDiv)

  -- prepare parsed chunks
  local kind = parsedDiv.kind
  local ID = parsedDiv.exID
  local preamble = parsedDiv.preamble
  local judgements = parsedDiv.judgements
  local line, header, source, gloss, trans

  if preamble == nil then 
    preamble = pandoc.List() 
  else 
    preamble = preamble.content
    if #kind == 1 and kind[1] == "single" then
      texEnd("\\\\", preamble)
    end
  end

  for i=1,#kind do
    if judgements[i] == nil then 
      judgements[i] = { pandoc.RawInline("tex","") }
    else
      judgements[i] = { judgements[i] }
      --texFront("\\jdg{", judgements[i])
      --texEnd("}", judgements[i])
    end
  end

  -- build Latex code starting with preamble and adding rest to it
  texFront("\\begin{samepage}\n\n\\ex. \\label{"..ID.."} ", preamble)

  for i=1,#kind do
    if kind[i] == "single" then

      line = texSquashMulti(parsedDiv.examples[i])

      if #kind > 1 and i == 1 then 
        texFront("\n  \\a. ", judgements[i])
      elseif #kind > 1 and i > 1 then
        texFront("\n  \\b. ", judgements[i])
      else
        texFront("\n  ", judgements[i])
      end

      preamble:extend(judgements[i])
      preamble:extend(line)

    elseif kind[i] == "interlinear" then

      header = parsedDiv.examples[i].header.content
      source = parsedDiv.examples[i].source
      gloss  = parsedDiv.examples[i].gloss
      trans  = parsedDiv.examples[i].trans.content
      
      source = texCombine(source)
      gloss  = texCombine(gloss)

      if pandoc.utils.stringify(header) == "" then
        header = pandoc.List()
      end

      if #kind > 1 and i == 1 then 
        texFront("\n  \\a. ", header)
      elseif #kind > 1 and i > 1 then
        texFront("\n  \\b. ", header)
      else
        texFront("\n  ", header)
      end

      preamble:extend(header)
      texFront("\n  \\gll ", judgements[i])
      preamble:extend(judgements[i])
      texEnd("\\\\", source)
      preamble:extend(source)
      texFront("\n       ", gloss)
      texEnd("\\\\", gloss)
      preamble:extend(gloss)
      texFront("\n  \\glt ", trans)
      preamble:extend(trans)

    end
  end
  texEnd("\n\n\\end{samepage}", preamble)
  return pandoc.Plain(preamble)
end

----------------------

function texMakeGb4e (parsedDiv)

  -- prepare parsed chunks
  local kind = parsedDiv.kind
  local ID = parsedDiv.exID
  local preamble = parsedDiv.preamble
  local nopreamble
  local judgements = parsedDiv.judgements
  local line, header, source, gloss, trans

  if preamble == nil then 
    preamble = pandoc.List() 
    nopreamble = true
  else 
    preamble = preamble.content
  end

  local judgeMax = ""
  for i=1,#kind do
    if sLength(judgements[i]) > sLength(judgeMax) then
      judgeMax = judgements[i]
    end
  end
  local judgeOffset = "\\judgewidth{"..string.gsub(pandoc.utils.stringify(judgeMax), "([#$%&_{}~^])", "\\%1").."}"

  for i=1,#kind do
    if judgements[i] == nil then 
      judgements[i] = { pandoc.RawInline("tex","[] { ") }
    else
      judgements[i] = { judgements[i] }
      texFront("[", judgements[i])
      texEnd("] { ", judgements[i])
    end
  end

  -- build Latex code starting with preamble and adding rest to it
    texFront("\\begin{samepage}\n\\begin{exe} "..judgeOffset.."\n  \\ex ", preamble)

  for i=1,#kind do
    if kind[i] == "single" then

      line = texSquashMulti(parsedDiv.examples[i])
      
      if #kind > 1 and i == 1 then 
        texFront("\n  \\begin{xlist}\n  \\ex ", judgements[i])
      elseif #kind > 1 and i > 1 then
        texFront("\n  \\ex ", judgements[i])
      elseif #kind ==1 and nopreamble then
          texFront("", judgements[i])
      else
          texFront("\n  \\sn ", judgements[i])
      end
      
      preamble:extend(judgements[i])
      preamble:extend(line)
      texEnd(" }", preamble)

    elseif kind[i] == "interlinear" then

      header = parsedDiv.examples[i].header.content
      source = parsedDiv.examples[i].source
      gloss  = parsedDiv.examples[i].gloss
      trans  = parsedDiv.examples[i].trans.content
      
      source = texCombine(source)
      gloss  = texCombine(gloss)

      if pandoc.utils.stringify(header) == "" then
        header = pandoc.List()
      else texFront("\n       ", header)
      end

      if #kind > 1 and i == 1 then 
        texFront("\n      \\begin{xlist}\n  \\ex ", judgements[i])
      elseif #kind > 1 and i > 1 then
        texFront("\n  \\ex ", judgements[i])
      else
        texFront("", judgements[i])
      end

      preamble:extend(judgements[i])
      preamble:extend(header)
      texFront("\n  \\gll ", source)
      texEnd("\\\\", source)
      preamble:extend(source)
      texFront("\n       ", gloss)
      texEnd("\\\\", gloss)
      preamble:extend(gloss)
      texFront("\n  \\glt ", trans)
      preamble:extend(trans)
      texEnd(" }", preamble)

    end
  end
  if #kind > 1 then texEnd("\n  \\end{xlist}", preamble) end
  texEnd("\n  \\label{"..ID.."}\n\\end{exe}\n\\end{samepage}", preamble)
  return pandoc.Plain(preamble)
end

----------------------

function texMakeLangsci (parsedDiv)

  -- prepare parsed chunks
  local kind = parsedDiv.kind
  local ID = parsedDiv.exID
  local preamble = parsedDiv.preamble
  local nopreamble
  local judgements = parsedDiv.judgements
  local line, header, source, gloss, trans

  if preamble == nil then 
    preamble = pandoc.List() 
    nopreamble = true
  else 
    preamble = preamble.content
  end

  local judgeMax = ""
  for i=1,#kind do
    if sLength(judgements[i]) > sLength(judgeMax) then
      judgeMax = judgements[i]
    end
  end
  local judgeOffset = "\\judgewidth{"..string.gsub(pandoc.utils.stringify(judgeMax), "([#$%&_{}~^])", "\\%1").."}"

  for i=1,#kind do
    if judgements[i] == nil then
      if #kind == 1 and kind[1] == "single" then
        judgements[i] = { pandoc.RawInline("tex","") }
      else
        judgements[i] = { pandoc.RawInline("tex","[] { ") }
      end
    else
      judgements[i] = { judgements[i] }
      if #kind > 1 or kind[1] == "interlinear" then
        texFront("[", judgements[i])
        texEnd("] { ", judgements[i])
      end
    end
  end

  -- build Latex code starting with preamble and adding rest to it
  if #kind == 1 and kind[1] == "interlinear" then
    texFront("\\ea ", judgements[1])
    local tmp = pandoc.List()
    tmp:extend(judgements[1])
    texFront(judgeOffset.." \\label{"..ID.."} ", preamble)
    tmp:extend(preamble)
    preamble = tmp
  else
    texFront("\\ea "..judgeOffset.." \\label{"..ID.."} ", preamble)
  end
  texFront("\\begin{samepage}\n", preamble)

  for i=1,#kind do
    if kind[i] == "single" then

      line = texSquashMulti(parsedDiv.examples[i])
      
      if #kind == 1 and nopreamble ~= true then
        texEnd("\\\\", preamble)
      end

      if #kind > 1 and i == 1 then 
        texFront("\n  \\ea ", judgements[i])
      elseif #kind > 1 and i > 1 then
        texFront("\n  \\ex ", judgements[i])
      else
        texFront("\n  ", judgements[i])
      end
      
      preamble:extend(judgements[i])
      preamble:extend(line)

      if #kind > 1 then
        texEnd(" }", preamble)
      end

    elseif kind[i] == "interlinear" then

      header = parsedDiv.examples[i].header.content
      source = parsedDiv.examples[i].source
      gloss  = parsedDiv.examples[i].gloss
      trans  = parsedDiv.examples[i].trans.content
      
      source = texCombine(source)
      gloss  = texCombine(gloss)

      if pandoc.utils.stringify(header) == "" then
        header = pandoc.List()
      else 
        texFront("\n       ", header)
        texEnd("\\\\", header)
      end

      if #kind > 1 and i == 1 then 
        texFront("\n  \\ea ", judgements[i])
        preamble:extend(judgements[i])
      elseif #kind > 1 and i > 1 then
        texFront("\n  \\ex ", judgements[i])
        preamble:extend(judgements[i])
      end

      preamble:extend(header)
      texFront("\n  \\gll ", source)
      texEnd("\\\\", source)
      preamble:extend(source)
      texFront("\n       ", gloss)
      texEnd("\\\\", gloss)
      preamble:extend(gloss)
      texFront("\n  \\glt ", trans)
      preamble:extend(trans)
      texEnd(" }", preamble)

    end
  end
  if #kind > 1 then texEnd("\n  \\z", preamble) end
  texEnd("\n\\z\n\\end{samepage}", preamble)
  return pandoc.Plain(preamble)
end

-------------------------
-- format crossreferences
-------------------------

function uniqueNextrefs (cite)


  -- to resolve "Next"-style references 
  -- we construct a list that lists example refs in order
  local target = string.match(cite.content[1].text, "@Target")
  if target ~= nil then
      orderInText = orderInText + 1
      indexRef[orderInText] = cite.citations[1].id
  else
    -- next/last refs are given a number ID.
    -- this ID maps to the position of the example that it refers to in "nextRefIndex"
    local nameN = string.match(cite.citations[1].id, "([n]+)ext")
    local nameL = string.match(cite.citations[1].id, "([l]+)ast")
    if nameN ~= nil or nameL ~= nil then
      local id = tostring(#nextRefIndex + 1)
      cite.citations[1].id = id

      local add = 0
      if nameN ~= nil then
        add = string.len(nameN)
      else
        add = - string.len(nameL) + 1
      end
      table.insert(nextRefIndex, orderInText + add) 
    end
  end

  return(cite)
end

------------------------------------------

-- debug purposes: REMOVE ME!
function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end


function resolveNextrefs (cite)

  -- assume Next-style refs have numeric id (from uniqueNextrefs)
  -- assume Example-IDs are not numeric (user should not use them!)

  local id = cite.citations[1].id
  if tonumber(id) ~= nil then
    cite.citations[1].id = indexRef[nextRefIndex[tonumber(id)]]
  end
  
  return(cite)
end

------------------------------------------

function removeTmpTargetrefs (cite)
  -- remove temporary cites for resolving Next-style reference
  if cite.content[1].text == "@Target" then
    return pandoc.Plain({})
  end 
end

------------------------------------------

function makeCrossrefs (cite)

  local id = cite.citations[1].id

  -- ignore other "cite" elements
  if indexEx[id] ~= nil then 
    
    -- only make suffix if there is something there
    local suffix = ""
    if #cite.citations[1].suffix > 0 then
      suffix = pandoc.utils.stringify(cite.citations[1].suffix[2])
      suffix = xrefSuffixSep..suffix
    end

    -- prevent Latex error when user sets xrefSuffixSep to space or nothing
    if FORMAT:match "latex" then
      if xrefSuffixSep == ""  or -- empty
        xrefSuffixSep == " " or -- space
        xrefSuffixSep == " "    -- non-breaking space
      then
        xrefSuffixSep = "\\," -- set to thin space
      end
    end

    -- make the cross-reference
    if FORMAT:match "latex" then
      if latexPackage == "expex" then
        return pandoc.RawInline("latex", "(\\getref{"..id.."}"..suffix..")")
      else
        return pandoc.RawInline("latex", "(\\ref{"..id.."}"..suffix..")")
      end
    else	
      return pandoc.Link("("..indexEx[id]..suffix..")", "#"..id)
    end

  end
end

------------------------------------------
-- Pandoc trick to cycle through documents
------------------------------------------

return {
  -- preparations
  --{ Pandoc = addSectionNumbering },
  { Header = addDivToHeader },
  { Meta = getUserSettings },
  { Meta = addFormatting },
  -- parse examples and rewrite
  { Div = processDiv },
   -- three passes necessary to resolve NNext-style references
   { Cite = uniqueNextrefs },
   { Cite = resolveNextrefs },
   { Cite = removeTmpTargetrefs },
   -- now finally all cross-references can be set
   { Cite = makeCrossrefs }
}




