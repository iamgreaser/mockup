## Naming

Here was my train of thought, roughly:

"Let's name it something that makes it sound like a temporary name, because there's nothing more permanent than a temporary solution."

- Temporal テンポラル

"But I need it to be somewhat easy to pronounce in Japanese, and that might be a bit too long."

- MockUp   モックアップ

"Yes that's fine... oh oops, it's slightly longer"
"Anyway, at least that one sounds good in English."

Then looking at file extensions, `.mu` is already used by something I haven't heard of until Vim kindly picked a syntax highlighter for it, but `.mku` is not taken.

------------------------------

## Bootstrapping language

Ruby was chosen because it handles string parsing pretty nicely and I don't have to worry too much about memory allocation.

I was regretting it as I was building the parser, but then after I got the CST-to-AST step working (CST = Concrete Syntax Tree, AST = Abstract Syntax Tree) and started working out how to execute the compiled AST, I found it actually works pretty nicely.

Sure, there's lex/yacc (which would be flex/bison in my case), but that's for LR-style grammars, and I prefer LL-style grammars.

Unlike Lua, I haven't written a Ruby parser, so transpiling the code to a suitable target language automatically would be non-trivial. Maybe I should've done this in Python as that has a working `ast` module. Oh well.

------------------------------
