"json_parser.vim
"   This file can load a valid json string into a more accessible { dict }
"
"   accessible methods:
"     json_parser#parse ( string )
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"
" Copyright (c) 2013 Auburn University and others.
" All rights reserved. This program and the accompanying materials
" are made available under the terms of the Eclipse Public License v1.0
" which accompanies this distribution, and is available at
" http://www.eclipse.org/legal/epl-v10.html
"
" Contributors:
"    Reed Allman (Auburn) - Initial API and implementation
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" make json loader

let s:pretty_string = ''
let s:indent_level = 0

function! s:PrettyKey()
  let i = 0
  while i < s:indent_level
    let s:pretty_string = s:pretty_string . "\t"
    let i += 1
  endwhile
endfunction

function! s:PrettyValue(string)
 let s:pretty_string = s:pretty_string . a:string
endfunction

function! s:PrettyBeginObject()
  let s:pretty_string = s:pretty_string . "{\n"
  let s:indent_level += 1
endfunction

function! s:PrettyEndObject()
  let s:pretty_string = s:pretty_string . "\n"
  let s:indent_level -= 1
  let i = 0
  while i < s:indent_level
    let s:pretty_string = s:pretty_string . "\t"
    let i += 1
  endwhile
  let s:pretty_string = s:pretty_string . "}"
endfunction


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
  call s:PrettyKey()
  let string = s:ParseString(a:string, nextIndex)
  let str = string[0]
  let nextIndex = string[1]

  let nextIndex = s:SkipWhitespace(a:string, nextIndex)
  let nextIndex = s:Match(":", a:string, nextIndex)
  if nextIndex < 0
    throw 'JSON Error: Expected : at index ' . nextIndex
  endif
  call s:PrettyValue(': ')

  let value = s:ParseValue(a:string, nextIndex)
  let val = value[0]
  let nextIndex = value[1]

  let a:dictionary[str] = val

  return nextIndex
endfunction

"value
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

" string
function! s:ParseString(string, int)
  let index = s:Match('"', a:string, a:int)
  if index < 0
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
  call s:PrettyValue('"' . str . '"')
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
  call s:PrettyValue(str)
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

  call s:PrettyValue(str)
  return [ str, nextIndex ]
endfunction

" value ? true || false || null
" return 1 || 0
function! s:IsValueBoolean(string, int)
  let nextIndex = a:int

  let x = 0
  if match(a:string, 'true\|false\|null', nextIndex) >= 0
    let x = 1
  endif

  return x
endfunction

"value
"value, elements
function! s:ParseElements(string, int) 
  let value = s:ParseValue(a:string, a:int)
  let array = [ value[0] ]
  let nextIndex = value[1]
  let nextIndex = s:SkipWhitespace(a:string, nextIndex)
  let test = s:Match(',', a:string, nextIndex)
  if test >= 0
    let nextIndex = test
    call s:PrettyValue(", ")
    let x = s:ParseElements(a:string, nextIndex)
    let array += x[0]
    let nextIndex = x[1]
  endif
  return [ array, nextIndex ]
endfunction

"pair
"pair , members
function! s:ParseMembers(string, int, dictionary)
  let index = s:ParsePair(a:string, a:int, a:dictionary)
  let index = s:SkipWhitespace(a:string, index)
  let test = s:Match(",", a:string, index)
  if test >= 0
    let index = test
    call s:PrettyValue(",\n")
    let index = s:ParseMembers(a:string, index, a:dictionary)
  endif
  return index
endfunction

" []
" [ elements ]
function! s:ParseArray(string, int)
  let nextIndex = a:int
  let elements = []
  let nextIndex = s:Match("[", a:string, nextIndex)
  if nextIndex < 0
    throw "JSON ERROR: Expected [ at index " . nextIndex
  endif
  call s:PrettyValue("[")
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
    call s:PrettyValue("]")
  else
    let nextIndex = test
  endif
  let nextIndex = s:SkipWhitespace(a:string, nextIndex)
  return [ elements, nextIndex ]
endfunction

" { }
" { members }
function! s:ParseObject(string, int)
  let dictionary = {}
  let nextIndex = a:int
  let nextIndex = s:SkipWhitespace(a:string, nextIndex)
  let nextIndex = s:Match("{", a:string, nextIndex)
  if nextIndex < 0
    throw "JSON Error: Expected { at index " . nextIndex
  endif
  call s:PrettyBeginObject()
  let nextIndex = s:SkipWhitespace(a:string, nextIndex)
  let test = s:Match("}", a:string, nextIndex)
  if test < 0
    let nextIndex = s:ParseMembers(a:string, nextIndex, dictionary)
    let z = nextIndex
    let nextIndex = s:Match("}", a:string, nextIndex)
    if nextIndex < 0
      throw "JSON Error: Expected } at index " . z
    endif
    call s:PrettyEndObject()
  else
    let nextIndex = test
  endif
  let nextIndex = s:SkipWhitespace(a:string, nextIndex)
  return [ dictionary, nextIndex ]
endfunction

function! s:StringifyObject(dict)
  let string = "{"
  let i = 0
  for k in keys(a:dict)
    if i > 0
      let string = string . ', '
    endif
    let string = string . '"' . k . '": ' . s:StringifyValue(a:dict[k])
    let i += 1
  endfor
  return string . "}"
endfunction

function! s:StringifyValue(val)
  let val = a:val
  if type(val) == type(0) || type(val) == type(0.0)
    return val
  elseif type(val) == type("")
    return '"' . val . '"'
  elseif type(val) == type([])
    return s:StringifyArray(val)
  elseif type(val) == type({})
    return s:StringifyObject(val)
  elseif match(val, 'true\|false\|null') >= 0
    return val
  else 
    throw "Invalid JSON for value" . val
  endif
endfunction

function! s:StringifyArray(val)
  let string = '['
  let i = 0
  for v in a:val
    if i > 0
      " let define separator?
      let string = string . ', '
    endif
    let string = string . s:StringifyValue(v)
    let i += 1
  endfor
  return string . ']'
endfunction

function! json_parser#parse(string)
  let result = s:ParseObject(a:string, 0)
  return result[0]
endfunction

function! json_parser#pretty_print(string)
  let dict = json_parser#parse(a:string)
  return s:pretty_string
endfunction

function! json_parser#stringify(dict)
  return s:StringifyObject(a:dict)
endfunction

" hooray janky TDD
" echo ParseJSON('{}')
" echo ParseJSON('  {    }   ')
" echo json_parser#pretty_print('{    "glossary": {        "title": "example glossary",    "GlossDiv": {            "title": "S",      "GlossList": {                "GlossEntry": {                    "ID": "SGML",          "SortAs": "SGML",          "GlossTerm": "Standard Generalized Markup Language",          "Acronym": "SGML",          "Abbrev": "ISO 8879:1986",          "GlossDef": {                        "para": "A meta-markup language, used to create markup languages such as DocBook.",            "GlossSeeAlso": ["GML", "XML"]                    },          "GlossSee": "markup"                }            }        }    },    "glossary2": {        "title": "example glossary",    "GlossDiv": {            "title": "S",      "GlossList": {                "GlossEntry": {                    "ID": "SGML",          "SortAs": "SGML",          "GlossTerm": "Standard Generalized Markup Language",          "Acronym": "SGML",          "Abbrev": "ISO 8879:1986",          "GlossDef": {                        "para": "A meta-markup language, used to create markup languages such as DocBook.",            "GlossSeeAlso": ["GML", "XML"]                    },          "GlossSee": "markup"                }            }        }    }}')
" echo json_parser#stringify({ 'hey': { 'hello': [ { 'world': 1 }, { 'people': 0 } ] } })
" echo ParseJSON('  {  "Parse Number" : 424242 }   ')
" echo ParseJSON(' { "Parse Boolean" : true } ')
" let test = ParseJSON(' { "Parse Array" : [ -1, 2, 3 ] }')
" let dict = test
" let array = dict["Parse Array"]
" echo array
" let x = array[0] + array[1]
" echo x
" echo s:ParseObject('  {  #,#  }   ', 0)
" echo ParseJSON('{ "result": "\"heyheyhey" }')
" echo ParseJSON('  { "member 1": { "member 2" : "$" } }   ')
