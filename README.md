<br/><br/>
<div>
    <h3 align="center">⚡ TinyCompiler</h3>
    <p align="center">
        A compiler written for fun to learn about Zig.
    </p>
</div>
<br><br>

**Disclaimer**: The grammar, found in `grammar.ebnf`, has not been validated to reject erroneous code. There is also no semantic error handling at the moment so variables are not checked for existence for example. I need to generate a symbol table over the AST before the code generation phase. 

## Syntax

The syntax is intentionally simple to make this a Zig learning experience rather than one of compiler design. I may extend it to include other features that are relatively simple like functions.

**Datatypes**: Only integers are valid at the moment.

**Keywords**: _if, while, end, print_.

### Example Usage
Source file:
```
x = 10/2
y = 5*2+1

if (x <= y) print x+2 end

while (y >= x)
    print y
    if (y == 7)
        x = x - 1
    end
    y = y - 1
end
```

Translated output (python for now):
```py
x = 10 / 2
y = 5 * 2 + 1
if x <= y:
	print(x + 2)
while y >= x:
	print(y)
	if y == 7:
		x = x - 1
	y = y - 1
```

## License

[MIT](https://github.com/williamfedele/tinycompiler/blob/main/LICENSE)
