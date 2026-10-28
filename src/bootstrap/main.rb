#!/usr/bin/env ruby
# MockUp bootstrap parser and interpreter

require "./src/bootstrap/lexer.rb"
require "./src/bootstrap/parser.rb"
require "./src/bootstrap/ast.rb"

require "./src/bootstrap/exec.rb"

##############################
# Entry point
##############################

def main(in_fname)
  in_chars = IO.read(in_fname)
  lexer = Lexer.new(in_fname, in_chars)
  #lexer.each {|token| p [token.pos.fname, token.pos.line, token.pos.col, token.literal] }
  ast = parse_ast(lexer)
  #pp ast
  ctx = ExecContext.new()
  ast.evaluate(ctx)
end

##############################
# Entry point entry point
# This must be at the end!
##############################
main(*ARGV)
