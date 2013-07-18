let s:PrettyString = ""

function! s:SkipWhitespace(string, int)
  let nextIndex = a:int
  while strpart(a:string, nextIndex, 1) == ' '
    let nextIndex += 1
  endwhile
  return nextIndex
endfunction

function! s:Match(expected, string, int)
  if match(strpart(a:string, a:int, strlen(a:expected)), a:expected) == 0
    return a:int + strlen(a:expected)
  else
    return -1
  endif
endfunction

function! s:AtEndOfValue(string, int)
  if s:Match(',', a:string, a:int) > 0
    return 1
  elseif s:Match(' ', a:string, a:int) > 0
    return 1
  elseif s:Match('}', a:string, a:int) > 0
    return 1
  elseif s:Match(']', a:string, a:int) > 0
    return 1
  else
    return 0
  endif
endfunction

" string : value
function! s:ParsePair(string, int, dictionary)
  let nextIndex = s:SkipWhitespace(a:string, a:int)
  let string = s:ParseString(a:string, nextIndex)
  let str = string[0]
  let nextIndex = string[1]

  let nextIndex = s:SkipWhitespace(a:string, nextIndex)
  let nextIndex = s:Match(":", a:string, nextIndex)
  if nextIndex < 0
    throw 'JSON Error: Expected : at index ' . nextIndex
  endif

  let value = s:ParseValue(a:string, nextIndex)
  let val = value[0]
  let nextIndex = value[1]

  let a:dictionary[str] = val

  return nextIndex
endfunction

function! s:ParseValue(string, int)

  let nextIndex = s:SkipWhitespace(a:string, a:int)

  if s:Match('"', a:string, nextIndex) > 0
    let value = s:ParseString(a:string, nextIndex)

  elseif s:Match('{', a:string, nextIndex) > 0
    let value = s:ParseObject(a:string, nextIndex)

  elseif s:Match('[', a:string, nextIndex) > 0
    let value = s:ParseArray(a:string, nextIndex)

  elseif s:IsValueBoolean(a:string, nextIndex) == 1
    let value = s:ParseBoolean(a:string, nextIndex)

  elseif s:IsValueBoolean(a:string, nextIndex) == 0
    let value = s:ParseNumber(a:string, nextIndex)
  else
    throw 'JSON Error: Invalid JSON at index ' . nextIndex
  endif

  let val = value[0]
  let nextIndex = value[1]
  return [val, nextIndex]
endfunction

function! s:ParseString(string, int)
  let index = s:Match('"', a:string, a:int)
  if index < 0
    let str = strpart(a:string, a:int - 10, 10)
    throw 'JSON Error: Expected " at index ' . a:int
  endif

  let nextindex = index
  while s:Match('"', a:string, nextindex) < 0
    if s:Match('\', a:string, nextindex) >= 0 
      let nextindex += 1 
    endif
    let nextindex += 1
  endwhile
  let length = nextindex - index
  let str = strpart(a:string, index, length) 
  return [ str, nextindex + 1]
endfunction

"number
function! s:ParseNumber(string, int)
  let nextIndex = a:int
  let str = ""
  while s:AtEndOfValue(a:string, nextIndex) < 1
    let str = str . strpart(a:string, nextIndex, 1)
    let nextIndex += 1
  endwhile
  return [ str, nextIndex ]
endfunction

"true
"false
"null
function! s:ParseBoolean(string, int)
  let nextIndex = a:int
  let str = ""
  let nextIndex = match(a:string, 'false\|true\|null', nextIndex)
  if match(a:string, "false", nextIndex) >= 0 
    let x = 5
  else
    let x = 4
  endif
  let str = strpart(a:string, nextIndex, x)
  let nextIndex += x

  return [ str, nextIndex ]
endfunction

" value = true, false || null
" return 1 if true, 0 if false
function! s:IsValueBoolean(string, int)
  let nextIndex = a:int

  let x = 0
  if match(a:string, 'true\|false\|null', nextIndex) >= 0
    let x = 1
  endif

  return x
endfunction

"value
"value, elementas
function! s:ParseElements(string, int) 
  let value = s:ParseValue(a:string, a:int)
  let array = [ value[0] ]
  let nextIndex = value[1]
  let nextIndex = s:SkipWhitespace(a:string, nextIndex)
  let test = s:Match(',', a:string, nextIndex)
  if test >= 0
    let nextIndex = test
    let x = s:ParseElements(a:string, nextIndex)
    let array += x[0]
    let nextIndex = x[1]
  endif
  return [ array, nextIndex ]
endfunction

" members = pair
"         / pair , members
function! s:ParseMembers(string, int, dictionary)
  let s:PrettyString = strpart(a:string, 0, a:int) . "\n\t" . strpart(a:string, a:int)
  let index = s:ParsePair(a:string, a:int, a:dictionary)
  let index = s:SkipWhitespace(a:string, index)
  let test = s:Match(",", a:string, index)
  if test >= 0
    let index = test
    let index = s:ParseMembers(a:string, index, a:dictionary)
  endif
  return index
endfunction

" array = []
"         [ elements ]
function! s:ParseArray(string, int)
  let nextIndex = a:int
  let elements = []
  let nextIndex = s:Match("[", a:string, nextIndex)
  if nextIndex < 0
    throw "JSON ERROR: Expected [ at index " . nextIndex
  endif
  let nextIndex = s:SkipWhitespace(a:string, nextIndex)
  let test = s:Match("]", a:string, nextIndex)
  if test < 0
    let array = s:ParseElements(a:string, nextIndex)
    let elements = array[0]
    let nextIndex = array[1]
    let nextIndex = s:Match("]", a:string, nextIndex)
    if nextIndex < 0
      throw "JSON Error: Expected ] at index " . nextIndex
    endif
  else
    let nextIndex = test
  endif
  let nextIndex = s:SkipWhitespace(a:string, nextIndex)
  return [ elements, nextIndex ]
endfunction

" object = ws { ws            } ws
"        / ws { ws members ws } ws
function! s:ParseObject(string, int)
  let dictionary = {}
  let nextIndex = a:int
  let nextIndex = s:SkipWhitespace(a:string, nextIndex)
  let nextIndex = s:Match("{", a:string, nextIndex)
  if nextIndex < 0
    throw "JSON Error: Expected { at index " . nextIndex
  endif
  let s:PrettyString = strpart(a:string, 0, a:int) . "\r\n" . strpart(a:string, a:int)
  let nextIndex = s:SkipWhitespace(a:string, nextIndex)
  let test = s:Match("}", a:string, nextIndex)
  if test < 0
    let nextIndex = s:ParseMembers(a:string, nextIndex, dictionary)
    let z = nextIndex
    let nextIndex = s:Match("}", a:string, nextIndex)
    if nextIndex < 0
      throw "JSON Error: Expected } at index " . z
    endif
  else
    let nextIndex = test
  endif
  let nextIndex = s:SkipWhitespace(a:string, nextIndex)
  return [ dictionary, nextIndex ]
endfunction


function! json_parser#parse(string)
  let result = s:ParseObject(a:string, 0)
  return result[0]
endfunction

function! json_parser#pretty_print(string)
  call json_parser#parse(a:string)
  return s:PrettyString
endfunction

" echo ParseJSON('{}')
" echo ParseJSON('  {    }   ')
" echo ParseJSON('{ "reply" : "OK", "text": "string" } ')
" echo ParseJSON('  {  "Parse Number" : 424242 }   ')
" echo ParseJSON(' { "Parse Boolean" : true } ')
"echo PrettyPrint('{"something":[{"something":"something"},{"something":"false"}]}')
" let test = ParseJSON(' { "Parse Array" : [ -1, 2, 3 ] }')
" let dict = test
" let array = dict["Parse Array"]
" echo array
" let x = array[0] + array[1]
" echo x
"echo s:ParseObject('  {  #,#  }   ', 0)
"echo ParseJSON('{ "result": "\"heyheyhey" }')
" echo ParseJSON('  { "member 1": { "member 2" : "$" } }   ')
