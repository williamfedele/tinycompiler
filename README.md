<br/><br/>
<div>
    <h3 align="center">⚡ TinyCompiler</h3>
    <p align="center">
        A compiler written for fun to learn about Zig.
    </p>
</div>
<br><br>

**Disclaimer**: The grammar, found in `grammar.ebnf`, is not fully implemented and there are basic operators missing right now like operations with 2 characters.

## Syntax

The syntax is intentionally simple to make this a Zig learning experience rather than one of compiler design. I may extend it to include other features that are simple like functions.

**Datatypes**: Only integers are valid at the moment.

**Keywords**: _if, while, end, print_

### Example Usage
Source file:
```
x = 5
y = 10

if (x > y) print x end

while (y > x)
    print y
    if (y > 7)
        x = x - 1
    end
    y = y - 1
end
```

Translated output (python for now):
```py
x = 5
y = 10
if x > y:
	print(x)
while y > x:
	print(y)
	if y > 7:
		x = x - 1
	y = y - 1
```

## License

[MIT](https://github.com/williamfedele/tinycompiler/blob/main/LICENSE)
