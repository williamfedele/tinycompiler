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

The syntax is intentionally simple to make this a Zig learning experience rather than one purely of compiler design. I'm not a compiler engineer, so don't expect big things haha. I may extend it to include other features that are relatively simple like functions.

**Datatypes**: Only integers are valid at the moment.

**Keywords**: _var, int, if, while, end, print_.

### Example Usage
Source file:
```
var x: int = 10;
var y: int;
y = 5*2+1;

if (x <= y) 
    print x;
else
    print y;
end

while (y >= x)
    print y;
    if (y == 7)
        x = x - 1;
    end
    y = y - 1;
end
```

Translated output (python for now):
```py
x = 10
y = 0
y = 5 * 2 + 1
if x <= y:
	print(x)
else:
	print(y)
while y >= x:
	print(y)
	if y == 7:
		x = x - 1
	y = y - 1
```

## License

[MIT](https://github.com/williamfedele/tinycompiler/blob/main/LICENSE)
