# Parse / Stringify / Pretty Print JSON in VimL

These are probably most useful in combination with another plugin, I would
recommend to include them in the autoload/ directory and call the functions from
there.

Accessible functions:

json_parser#parse(string)
json_parser#pretty_print(string)
json_parser#stringify(dictionary)


### Examples

##### parse
Takes [JSON] string
returns { dictionary }
```
:echo json_parser#parse('{ "hello": [ "world", 1 ] }')
{'hello':['world',1]}
```

...Do this when you actually have time
