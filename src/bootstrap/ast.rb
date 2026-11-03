##############################
# Abstract Syntax Tree (AST)
##############################

$parser_specs = {
  stat_list: p_zero_plus(p_ref(:stat)),
  stat: p_select([
    p_ref(:nothing_stat),
    p_ref(:expr_stat),
    p_ref(:block_stat),
    p_ref(:const_stat),
    p_ref(:var_stat),
    p_ref(:if_stat),
    p_ref(:while_stat),
    p_ref(:function_stat),
    p_ref(:return_stat),
  ], [
    :nothing,
    :expr,
    :block,
    :const,
    :var,
    :if,
    :while,
    :function,
    :return,
  ]),

  nothing_stat: p_literal(";"),
  expr_stat: p_sequence([p_ref(:expr_statfirst),
    p_optional(p_sequence([p_literal("="), p_ref(:expr_statfirst)], [nil, :SPECIAL_full_body])),
    p_literal(";")], [:expr, :assign, nil]),
  block_stat: p_sequence([p_literal("{"), p_ref(:stat_list), p_literal("}")], [nil, :stats, nil]),
  const_stat: p_sequence([
    p_literal("const"), p_terminal(:name),
    p_optional(p_sequence([p_literal(":"), p_ref(:type_expr)], [nil, :SPECIAL_full_body])),
    p_literal("="),
    p_ref(:expr),
    p_literal(";"),
  ], [nil, :name, :value_type, nil, :value, nil]),
  var_stat: p_sequence([
    p_literal("var"), p_terminal(:name),
    p_optional(p_sequence([p_literal(":"), p_ref(:type_expr)], [nil, :SPECIAL_full_body])),
    p_literal("="),
    p_ref(:expr),
    p_literal(";"),
  ], [nil, :name, :value_type, nil, :value, nil]),
  if_stat: p_sequence([
    p_literal("if"), p_literal("("), p_ref(:expr), p_literal(")"),
    p_literal("{"), p_ref(:stat_list), p_literal("}"),
    p_optional(p_sequence([
      p_literal("else"),
      p_select([
        p_sequence([p_literal("{"), p_ref(:stat_list), p_literal("}")], [nil, :SPECIAL_full_body, nil]),
        p_ref(:if_stat),
      ], [:elseif, :else]),
    ], [nil, :SPECIAL_full_body])),
  ], [nil, nil, :test, nil, nil, :true_block, nil, :else_case]),
  while_stat: p_sequence([
    p_literal("while"), p_literal("("), p_ref(:expr), p_literal(")"),
    p_literal("{"), p_ref(:stat_list), p_literal("}"),
  ], [nil, nil, :test, nil, nil, :while_block, nil]),

  return_stat: p_sequence([p_literal("return"), p_optional(p_ref(:expr)), p_literal(";")], [nil, :SPECIAL_full_body, nil]),

  # Function names can be a few different things... eventually. TODO: Implement them!
  function_stat: p_sequence([
    p_literal("function"), p_ref(:function_name), p_literal("("), p_ref(:param_list), p_literal(")"),
    p_optional(p_sequence([p_literal(":"), p_ref(:type_expr)], [nil, :SPECIAL_full_body])),
    p_literal("{"), p_ref(:stat_list), p_literal("}"),
  ], [nil, :name, nil, :params, nil, :return_type, nil, :body, nil]),
  function_name: p_terminal(:name),
  param_list: p_optional(p_sequence([
    p_ref(:param), p_optional(p_ref(:opt_next_param))
  ], [:SPECIAL_head, :SPECIAL_tail])),
  param: p_sequence([p_terminal(:name), p_literal(":"), p_ref(:type_expr)], [:name, nil, :param_type]),
  opt_next_param: p_sequence([p_literal(","), p_ref(:param_list)], [nil, :SPECIAL_full_body]),

  type_expr: p_select([
    p_ref(:expr),
  ], [
    :expr,
  ]),

  expr: p_sequence([p_ref(:suffixed_expr), p_optional(p_ref(:binop_suffix))], [:e, :binop_suffix]),
  expr_statfirst: p_sequence([p_ref(:suffixed_expr_statfirst), p_optional(p_ref(:binop_suffix))], [:e, :binop_suffix]),
  suffixed_expr: p_sequence([p_ref(:expr_terminal), p_ref(:expr_suffixes)], [:e, :suffixes]),
  suffixed_expr_statfirst: p_sequence([p_ref(:expr_terminal_statfirst), p_ref(:expr_suffixes)], [:e, :suffixes]),
  expr_suffixes: p_zero_plus(p_select([
    p_ref(:expr_suffix_func_call),
  ], [:func_call])),
  expr_suffix_func_call: p_sequence([p_literal("("), p_ref(:arg_list), p_literal(")")], [nil, :args, nil]),
  expr_terminal_statfirst: p_select([
    p_ref(:bool_expr),
    p_ref(:int_expr),
    p_ref(:name_expr),
    p_ref(:string_expr),
    p_sequence([p_literal("("), p_ref(:expr), p_literal(")")], [nil, :SPECIAL_full_body, nil]),
  ], [:bool, :int, :name, :string, :expr]),
  expr_terminal: p_select([
    p_ref(:bool_expr),
    p_ref(:int_expr),
    p_ref(:name_expr),
    p_ref(:string_expr),
    p_sequence([p_literal("("), p_ref(:expr), p_literal(")")], [nil, :SPECIAL_full_body, nil]),
    p_ref(:ifelse_expr),
  ], [:bool, :int, :name, :string, :expr, :ifelse]),

  binop_suffix: p_select([
    p_ref(:binop_chain_add),
    p_ref(:binop_chain_sub),
    p_ref(:binop_chain_mul),
    p_ref(:binop_chain_div),
    p_ref(:binop_chain_mod),
    p_ref(:binop_chain_eq),
    p_ref(:binop_chain_ne),
    p_ref(:binop_chain_lt),
    p_ref(:binop_chain_gt),
    p_ref(:binop_chain_le),
    p_ref(:binop_chain_ge),
    p_ref(:binop_chain_and),
    p_ref(:binop_chain_or),
  ], [
    :add,
    :sub,
    :mul,
    :div,
    :mod,
    :eq,
    :ne,
    :lt,
    :gt,
    :le,
    :ge,
    :and,
    :or,
  ]),
  binop_chain_add: p_one_plus(p_sequence([p_literal("+"), p_ref(:suffixed_expr)], [nil, :SPECIAL_full_body])),
  binop_chain_sub: p_sequence([p_literal("-"), p_ref(:suffixed_expr)], [nil, :SPECIAL_full_body]),
  binop_chain_mul: p_one_plus(p_sequence([p_literal("*"), p_ref(:suffixed_expr)], [nil, :SPECIAL_full_body])),
  binop_chain_div: p_sequence([p_literal("/"), p_ref(:suffixed_expr)], [nil, :SPECIAL_full_body]),
  binop_chain_mod: p_sequence([p_literal("%"), p_ref(:suffixed_expr)], [nil, :SPECIAL_full_body]),
  binop_chain_eq: p_sequence([p_literal("=="), p_ref(:suffixed_expr)], [nil, :SPECIAL_full_body]),
  binop_chain_ne: p_sequence([p_literal("!="), p_ref(:suffixed_expr)], [nil, :SPECIAL_full_body]),
  binop_chain_lt: p_sequence([p_literal("<"), p_ref(:suffixed_expr)], [nil, :SPECIAL_full_body]),
  binop_chain_gt: p_sequence([p_literal(">"), p_ref(:suffixed_expr)], [nil, :SPECIAL_full_body]),
  binop_chain_le: p_sequence([p_literal("<="), p_ref(:suffixed_expr)], [nil, :SPECIAL_full_body]),
  binop_chain_ge: p_sequence([p_literal(">="), p_ref(:suffixed_expr)], [nil, :SPECIAL_full_body]),
  binop_chain_and: p_one_plus(p_sequence([p_literal("and"), p_ref(:suffixed_expr)], [nil, :SPECIAL_full_body])),
  binop_chain_or: p_one_plus(p_sequence([p_literal("or"), p_ref(:suffixed_expr)], [nil, :SPECIAL_full_body])),

  arg_list: p_optional(p_sequence([p_ref(:expr), p_optional(p_ref(:opt_next_arg))], [:SPECIAL_head, :SPECIAL_tail])),
  opt_next_arg: p_sequence([p_literal(","), p_ref(:arg_list)], [nil, :SPECIAL_full_body]),

  bool_expr: p_select([p_literal("true"), p_literal("false")], [:b_true, :b_false]),
  int_expr: p_terminal(:int),
  name_expr: p_terminal(:name),
  string_expr: p_terminal(:string),

  # NOTE: `if (x) y else z+2` is an ambiguous binop, `if (x) y+2 else z` is not, `if (x+2) y else z` is not.
  # Thus, the `else` part must not have binops.
  # `if (x) y else z()` is to be interpreted as `if (x) y else (z())` and not `(if (x) y else z)()`.
  # This is like how `x+y()` is to be interpreted as `x+(y())` and not `(x+y)()`.
  ifelse_expr: p_sequence([
    p_literal("if"), p_literal("("), p_ref(:expr), p_literal(")"),
    p_ref(:expr),
    p_literal("else"),
    p_ref(:suffixed_expr),
  ], [nil, nil, :test, nil, :true_expr, nil, :false_expr]),
}

$parser_specs.each{|name, pg|
  pg.generate()
  #p [name, pg.class.name, pg.starts, pg.has_epsilon, pg]
}

##############################
# AST node definitions
##############################

class AST
  def evaluate(ctx)
    p ["x", self]
    raise "TODO: Implement me in a concrete class!"
  end

  def evaluate_assignment(ctx, value)
    p ["x=", self]
    raise "TODO: Implement me in a concrete class!"
  end
end

class NameAST < AST
  attr_reader :n
  def initialize(name)
    @n = name
  end

  def evaluate(ctx)
    ctx[@n].value
  end

  def evaluate_assignment(ctx, value)
    ctx[@n].set(value)
  end
end

class LiteralAST < AST
  def initialize(literal)
    @literal = literal
  end
end

class IntAST < AST
  def initialize(literal)
    @literal = literal
    if literal =~ /^0[bB]/
      v = literal[2..].to_i(2)
    elsif literal =~ /^0[oO]/
      v = literal[2..].to_i(8)
    elsif literal =~ /^0[xX]/
      v = literal[2..].to_i(16)
    else
      v = literal.to_i(10)
    end
    @v = VTInt.new(32, true).make(v)
  end

  def evaluate(ctx)
    @v
  end
end

class StringAST < AST
  def initialize(literal)
    @literal = literal
    raise "BUG: string literal must start with `\"`" unless @literal[0] == "\""
    raise "BUG: string literal must end with `\"`" unless @literal.length >= 2 and @literal[-1] == "\""
    input_slice = @literal[1...@literal.length-1]
    accum = ""
    offs = 0
    loop do
      m = /^[^"\\]*/.match(input_slice[offs..])[0]
      accum += m
      offs += m.length
      break if offs == input_slice.length
      c = /^./.match(input_slice[offs..])
      #p [">>", offs, input_slice.length]
      raise "BUG: end of token reached in string literal? got EOF" unless c
      raise "BUG: end of token reached in string literal? got `#{c[0]}`" unless c and c[0].length == 1
      c = c[0]
      offs += c.length
      if c == "\"" then
        raise "BUG: unescaped `\"` in string literal"
      elsif c == "\\" then
        c = /^./.match(input_slice[offs..])
        raise "BUG: end of token reached in string literal? got EOF" unless c
        raise "BUG: end of token reached in string literal? got `#{c[0]}`" unless c and c[0].length == 1
        c = c[0]
        offs += c.length
        case c
        in "n"
          accum += "\n"
        in "r"
          accum += "\r"
        in "t"
          accum += "\t"
        in "\\"
          accum += "\\"
        in "\""
          accum += "\""
        in "x"
          # Hexadecimal 2-digit byte
          m = /^[0-9A-Fa-f]{2}/.match(input_slice[offs..])
          raise "BUG: expected 2 hex digits after `\\x`" unless m
          m = m[0]
          offs += m.length
          accum += m.to_i(16).chr
        in "u"
          # Hexadecimal braced Unicode character \u{...}
          m = /^\{([0-9A-Fa-f]+)\}/.match(input_slice[offs..])
          raise "BUG: expected hex digits in {braces} after `\\u`" unless m
          offs += m[0].length
          accum += m[1].to_i(16).chr(Encoding::UTF_8)
        else
          raise "BUG: invalid string escape `\\#{c}`"
        end

      else
        raise "BUG, case not handled!"
      end
    end
    #p ["lit", @literal, accum, accum.length]
    @v = VTString.new().make(accum)
  end

  def evaluate(ctx)
    @v
  end
end

class StatListAST < AST
  def initialize(stats)
    @stats = stats
  end

  def evaluate(ctx)
    result = nil
    @stats.each {|n| result = n.evaluate(ctx) }
    result
  end
end

class BlockStatAST < AST
  def initialize(stat_list)
    @stat_list = stat_list
  end

  def evaluate(ctx)
    ctx.push_new_scope()
    begin
      @stat_list.evaluate(ctx)
    ensure
      ctx.pop_scope()
    end
  end
end

class VarStatAST < AST
  def initialize(is_mutable, name, value_type, value)
    @is_mutable = is_mutable
    @name = name
    @value_type = value_type
    @value = value
  end

  def evaluate(ctx)
    ctx.define_existing(@is_mutable, @name.n, @value_type.evaluate(ctx), @value.evaluate(ctx))
  end
end

class ExprStatAST < AST
  def initialize(e)
    @e = e
  end

  def evaluate(ctx)
    @e.evaluate(ctx)
  end
end

class AssignExprStatAST < AST
  def initialize(target, e)
    @target = target
    @e = e
  end

  def evaluate(ctx)
    @target.evaluate_assignment(ctx, @e.evaluate(ctx))
  end
end

class FuncCallAST < AST
  def initialize(e, args)
    @e = e
    @args = args
  end

  def evaluate(ctx)
    @e.evaluate(ctx).call(ctx, *(@args.map{|a| a.evaluate(ctx)}))
  end
end

module BinOp
  Add = "+"
  Sub = "-"
  Mul = "*"
  Div = "/"
  Mod = "%"
  Eq = "=="
  Ne = "!="
  Lt = "<"
  Gt = ">"
  Le = "<="
  Ge = ">="
  And = "and"
  Or = "or"
end

class BinOpAST < AST
  def initialize(op, e1, e2)
    @op = op
    @e1 = e1
    @e2 = e2
  end

  def evaluate(ctx)
    e1 = @e1.evaluate(ctx)
    # SPECIAL CASE: `and`, `or` need to shortcut their results
    case @op
    in BinOp::And
      if e1 == TRUE_BOOL then
        @e2.evaluate(ctx)
      elsif e1 == FALSE_BOOL then
        e1
      else
        raise "expected boolean from left side of `and`"
      end

    in BinOp::Or
      if e1 == FALSE_BOOL then
        @e2.evaluate(ctx)
      elsif e1 == TRUE_BOOL then
        e1
      else
        raise "expected boolean from left side of `and`"
      end

    else
      e2 = @e2.evaluate(ctx)
      e1.evaluate_binop(@op, e2)
    end
  end
end

class IfElseAST < AST
  def initialize(test, true_part, false_part)
    @test = test
    @true_part = true_part
    @false_part = false_part
  end

  def evaluate(ctx)
    e = @test.evaluate(ctx)
    if e == TRUE_BOOL
      @true_part.evaluate(ctx)
    elsif e == FALSE_BOOL
      @false_part.evaluate(ctx) if @false_part != nil
    else
      raise "`if` expression test evaluated to a non-boolean: #{e}"
    end
  end
end

class WhileAST < AST
  def initialize(test, while_part)
    @test = test
    @while_part = while_part
  end

  def evaluate(ctx)
    loop do
      e = @test.evaluate(ctx)
      if e == TRUE_BOOL
        # TODO: Handle `break`
        @while_part.evaluate(ctx)
      elsif e == FALSE_BOOL
        break
      else
        raise "`if` expression test evaluated to a non-boolean: #{e}"
      end
    end
  end
end

class ReturnAST < AST
  def initialize(e)
    @e = e
  end

  def evaluate(ctx)
    e = @e != nil ? @e.evaluate(ctx) : nil
    throw :return, e
  end
end

class FuncDefAST < AST
  attr_reader :name, :params, :return_type, :body
  def initialize(name, params, return_type, body)
    @name = name.n
    @params = params
    @return_type = return_type
    @body = body
  end

  def evaluate(ctx)
    ftype = VTASTProc.new(
      @params.map{|p| p.param_type.evaluate(ctx)},
      @return_type ? @return_type.evaluate(ctx) : nil,
    )
    f = ftype.make(self)
    ctx.define_existing(false, @name, ftype, f)
  end
end

class ParamAST < AST
  attr_reader :param_type, :name
  def initialize(param_type, name)
    @param_type = param_type
    @name = name
  end
end

$parser_to_ast = {
  literal: proc {|n| LiteralAST.new(n[:literal]) },

  terminal: proc {|n| $terminal_to_ast[n[:subtype]].call(n[:literal]) },
  int: proc {|n| n[:n]},
  name: proc {|n| n[:n]},

  name_expr: proc {|n| n[:v]},
  int_expr: proc {|n| n[:v]},
  string_expr: proc {|n| n[:v]},
  expr_terminal_statfirst: proc {|n| $parser_to_ast[:expr_terminal].call(n) },
  expr_terminal: proc {|n| n[:v]},
  expr_suffixes: proc {|n| n[:v]},

  arg_list: proc {|n| n[:v]},
  opt_next_arg: proc {|n| n[:v]},

  stat_list: proc {|n| StatListAST.new(n[:v].filter{|v| v != nil})},
  stat: proc {|n| n[:v]},
  nothing_stat: proc {|n| nil},
  block_stat: proc {|n| BlockStatAST.new(n[:v][:stats])},
  const_stat: proc {|n| VarStatAST.new(false, n[:v][:name], n[:v][:value_type], n[:v][:value])},
  var_stat: proc {|n| VarStatAST.new(true, n[:v][:name], n[:v][:value_type], n[:v][:value])},
  expr_stat: proc {|n|
    n = n[:v]
    if n[:assign] then
      AssignExprStatAST.new(n[:expr], n[:assign])
    else
      ExprStatAST.new(n[:expr])
    end
  },
  if_stat: proc {|n| IfElseAST.new(n[:v][:test], n[:v][:true_block], n[:v][:else_case])},
  while_stat: proc {|n| WhileAST.new(n[:v][:test], n[:v][:while_block])},
  function_stat: proc {|n| FuncDefAST.new(n[:v][:name], (n[:v][:params] or []), n[:v][:return_type], n[:v][:body])},
  return_stat: proc {|n| ReturnAST.new(n[:v])},

  param: proc {|n| ParamAST.new(n[:v][:param_type], n[:v][:name])},
  param_list: proc {|n| n[:v]},
  opt_next_param: proc {|n| n[:v]},

  function_name: proc {|n| n[:v]},

  type_expr: proc {|n| n[:v]},

  expr_statfirst: proc {|n| $parser_to_ast[:expr].call(n) },
  expr: proc {|n|
    n = n[:v]
    result = n[:e]
    if n[:binop_suffix] then
      begin
        f = $ast_apply_binop[n[:binop_suffix][:type]]
      rescue
        p ["binop", n[:binop_suffix]]
        raise
      end
      result = f.call(result, n[:binop_suffix][:v])
    end
    result
  },

  # Binop stuff
  binop_suffix: proc {|n| n[:v]},
  # Leave these intact until we mess with them in a later pass
  binop_chain_add: proc {|n| n},
  binop_chain_sub: proc {|n| n},
  binop_chain_mul: proc {|n| n},
  binop_chain_div: proc {|n| n},
  binop_chain_mod: proc {|n| n},
  binop_chain_eq: proc {|n| n},
  binop_chain_ne: proc {|n| n},
  binop_chain_lt: proc {|n| n},
  binop_chain_gt: proc {|n| n},
  binop_chain_le: proc {|n| n},
  binop_chain_ge: proc {|n| n},
  binop_chain_and: proc {|n| n},
  binop_chain_or: proc {|n| n},

  # Suffixed expression stuff
  suffixed_expr_statfirst: proc {|n| $parser_to_ast[:suffixed_expr].call(n) },
  suffixed_expr: proc {|n|
    n = n[:v]
    result = n[:e]
    n[:suffixes].each {|suffix|
      #p ["suf-----", result, suffix[:type], suffix]
      result = $ast_apply_suffix[suffix[:type]].call(result, suffix[:v])
      #p ["sufAPPLY", result]
    }
    result
  },
  # Leave these intact until we mess with them in a later pass
  expr_suffix_func_call: proc {|n| n},

  ifelse_expr: proc {|n| IfElseAST.new(n[:v][:test], n[:v][:true_expr], n[:v][:false_expr])},
}

$terminal_to_ast = {
  int: proc {|literal| IntAST.new(literal) },
  name: proc {|literal| NameAST.new(literal) },
  string: proc {|literal| StringAST.new(literal) },
}

$ast_apply_suffix = {
  expr_suffix_func_call: proc {|e, n| FuncCallAST.new(e, (n[:args] or [])) },
}

$ast_apply_binop = {
  # Associative operations -- (A $ B) $ C = A $ (B $ C)
  binop_chain_add: proc {|e1, n|
    n.each {|e2| e1 = BinOpAST.new(BinOp::Add, e1, e2) }
    e1
  },
  binop_chain_mul: proc {|e1, n|
    n.each {|e2| e1 = BinOpAST.new(BinOp::Mul, e1, e2) }
    e1
  },

  # Non-associative operations -- (A $ B) $ C might not be A $ (B $ C)
  binop_chain_sub: proc {|e1, e2| BinOpAST.new(BinOp::Sub, e1, e2)},
  binop_chain_div: proc {|e1, e2| BinOpAST.new(BinOp::Div, e1, e2)},
  binop_chain_mod: proc {|e1, e2| BinOpAST.new(BinOp::Mod, e1, e2)},

  # Non-associative comparisons
  binop_chain_eq: proc {|e1, e2| BinOpAST.new(BinOp::Eq, e1, e2)},
  binop_chain_ne: proc {|e1, e2| BinOpAST.new(BinOp::Ne, e1, e2)},
  binop_chain_lt: proc {|e1, e2| BinOpAST.new(BinOp::Lt, e1, e2)},
  binop_chain_gt: proc {|e1, e2| BinOpAST.new(BinOp::Gt, e1, e2)},
  binop_chain_le: proc {|e1, e2| BinOpAST.new(BinOp::Le, e1, e2)},
  binop_chain_ge: proc {|e1, e2| BinOpAST.new(BinOp::Ge, e1, e2)},

  # Associative boolean comparisons
  binop_chain_and: proc {|e1, n|
    n.each {|e2| e1 = BinOpAST.new(BinOp::And, e1, e2) }
    e1
  },
  binop_chain_or: proc {|e1, n|
    n.each {|e2| e1 = BinOpAST.new(BinOp::Or, e1, e2) }
    e1
  },
}

##############################
# AST helper functions
##############################

def parse_ast(lexer)
  ast = p_ref(:stat_list).parse(lexer)
  token = lexer.next_token()
  if token then
    pp ["x", ast]
    pp token
    token.raise_error("expected EOF, got `#{token.literal}` instead")
  end
  ast
end
