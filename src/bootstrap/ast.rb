##############################
# Abstract Syntax Tree (AST)
##############################

$parser_specs = {
  stat_list: p_zero_plus(p_ref(:stat)),
  stat: p_select([
    p_ref(:nothing_stat),
    p_ref(:expr_stat),
    p_ref(:block_stat),
    p_ref(:if_stat),
  ], [
    :nothing,
    :expr,
    :block,
    :if,
  ]),

  nothing_stat: p_literal(";"),
  expr_stat: p_sequence([p_ref(:expr), p_literal(";")], [:expr, nil]),
  block_stat: p_sequence([p_literal("{"), p_ref(:stat_list), p_literal("}")], [nil, :stats, nil]),
  if_stat: p_sequence([
    p_literal("if"), p_ref(:expr), p_literal("{"),
    p_ref(:stat_list),
    p_literal("}"), p_optional(
      p_sequence([p_literal("else"), p_select([p_ref(:block_stat), p_ref(:if_stat)], [:else, :if])], [nil, true]),
    ),
  ], [nil, :test, nil, :true_block, nil, :false_block]),

  expr: p_sequence([p_ref(:expr_terminal), p_ref(:expr_suffixes)], [:e, :suffixes]),
  expr_suffixes: p_zero_plus(p_select([
    p_ref(:expr_suffix_func_call),
  ], [:func_call])),
  expr_suffix_func_call: p_sequence([p_literal("("), p_ref(:arg_list), p_literal(")")], [nil, :args, nil]),
  expr_terminal: p_select([p_ref(:int_expr), p_ref(:name_expr)], [:int, :name]),

  arg_list: p_optional(p_sequence([p_ref(:expr), p_optional(p_ref(:opt_next_arg))], [:SPECIAL_head, :SPECIAL_tail])),
  opt_next_arg: p_sequence([p_literal(","), p_ref(:arg_list)], [nil, :SPECIAL_full_body]),

  int_expr: p_terminal(:int),
  name_expr: p_terminal(:name),
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
end

class NameAST < AST
  def initialize(name)
    @n = name
  end

  def evaluate(ctx)
    ctx[@n]
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
      @v = literal[2..].to_i(2)
    elsif literal =~ /^0[oO]/
      @v = literal[2..].to_i(8)
    elsif literal =~ /^0[xX]/
      @v = literal[2..].to_i(16)
    else
      @v = literal.to_i(10)
    end
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

class ExprStatAST < AST
  def initialize(e)
    @e = e
  end

  def evaluate(ctx)
    @e.evaluate(ctx)
  end
end

class FuncCallAST < AST
  def initialize(e, args)
    @e = e
    @args = args
  end

  def evaluate(ctx)
    @e.evaluate(ctx).call(*(@args.map{|a| a.evaluate(ctx)}))
  end
end

$parser_to_ast = {
  literal: proc {|n| LiteralAST.new(n[:literal]) },

  terminal: proc {|n| $terminal_to_ast[n[:subtype]].call(n[:literal]) },
  int: proc {|n| n[:n]},
  name: proc {|n| n[:n]},

  name_expr: proc {|n| n[:v]},
  int_expr: proc {|n| n[:v]},
  expr_terminal: proc {|n| n[:v]},
  expr_suffixes: proc {|n| n[:v]},

  arg_list: proc {|n| n[:v]},
  opt_next_arg: proc {|n| n[:v]},

  stat_list: proc {|n| StatListAST.new(n[:v])},
  stat: proc {|n| n[:v]},
  expr_stat: proc {|n| ExprStatAST.new(n[:v][:expr])},

  expr: proc {|n|
    n = n[:v]
    result = n[:e]
    n[:suffixes].each {|suffix|
      #p ["suf-----", result, suffix[:type], suffix]
      result = $ast_apply_suffix[suffix[:type]].call(result, suffix[:v])
      #p ["sufAPPLY", result]
    }
    result
  },
  # Leave these intact until we mess with them
  expr_suffix_func_call: proc {|n| n},

}

$terminal_to_ast = {
  int: proc {|literal| IntAST.new(literal) },
  name: proc {|literal| NameAST.new(literal) },
}

$ast_apply_suffix = {
  expr_suffix_func_call: proc {|e, n| FuncCallAST.new(e, n[:args]) },
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
