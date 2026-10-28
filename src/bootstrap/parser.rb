##############################
# Parser
##############################

def postparse(result)
  return result if result == nil
  return result if result.kind_of?(AST)
  return result if result.kind_of?(Array)
  return result unless result.include?(:type)
  begin
    result = $parser_to_ast[result[:type]].call(result)
  rescue
    #p ["type", result]
    p ["type", result[:type], result]
    raise
  end
  result
end

class ParseGenNode
  def initialize()
    # We cache these values so we don't have to compute them over and over again during parser generation.
    @starts_cache = nil
    @has_epsilon_cache = nil
  end

  def generate()
    starts()
    has_epsilon()
  end

  def parse(lexer)
    result = on_parse(lexer)
    result = postparse(result)
    result
  end

  protected

  def on_parse(lexer)
    p ["x", self]
    raise "TODO: Implement me in a concrete class!"
  end

  # What literals or types of terminals can this start with?
  def immediate_starts()
    p ["x", self]
    raise "TODO: Implement me in a concrete class!"
  end

  # Can this node be ignored?
  def immediate_has_epsilon()
    p ["x", self]
    raise "TODO: Implement me in a concrete class!"
  end

  public

  def starts()
    @starts_cache = immediate_starts() if @starts_cache == nil
    @starts_cache
  end

  def has_epsilon()
    @has_epsilon_cache = immediate_has_epsilon() if @has_epsilon_cache == nil
    @has_epsilon_cache
  end
end

class ParseRef < ParseGenNode
  attr_reader :name
  def initialize(name)
    super()
    @name = name
  end

  def on_parse(lexer)
    #$parser_specs[@name].parse(lexer)
    {type: @name, v: $parser_specs[@name].parse(lexer)}
  end

  def immediate_starts()
    begin
      spec = $parser_specs[@name]
      raise "could not find spec for #{@name}" if spec == nil
    rescue
      p ["name", @name, spec]
      raise
    end
    spec.starts()
  end
  def immediate_has_epsilon()
    $parser_specs[@name].has_epsilon()
  end
end
def p_ref(name)
  ParseRef.new(name)
end

class ParseLiteral < ParseGenNode
  attr_reader :literal
  def initialize(literal)
    super()
    @literal = literal
  end

  def on_parse(lexer)
    token = lexer.next_token()
    raise "unexpected EOF, expected `#{@literal}`" unless token
    token.raise_error("unexpected token `#{token.literal}`, expected `#{@literal}`") unless token.literal == @literal
    return {type: :literal, literal: @literal}
  end

  def immediate_starts()
    Set[@literal]
  end
  def immediate_has_epsilon()
    false
  end
end
def p_literal(literal)
  ParseLiteral.new(literal)
end

class ParseTerminal < ParseGenNode
  attr_reader :terminal
  def initialize(terminal)
    super()
    @terminal = terminal
  end

  def on_parse(lexer)
    token = lexer.next_token()
    raise "unexpected EOF, expected `#{@terminal}`" unless token
    tclass = token.token_class()
    token.raise_error("unexpected token `#{token.literal}`, expected `#{@terminal}`") unless tclass == @terminal
    return {type: :terminal, subtype: @terminal, literal: token.literal}
  end

  def immediate_starts()
    Set[@terminal]
  end
  def immediate_has_epsilon()
    false
  end
end
def p_terminal(terminal)
  ParseTerminal.new(terminal)
end

class ParseZeroPlus < ParseGenNode
  attr_reader :node
  def initialize(node)
    super()
    @node = node
  end

  def on_parse(lexer)
    result = []
    while true do
      token = lexer.next_token()
      #p ["0+", self, token]
      break unless token
      literal = token.literal
      tclass = token.token_class()
      lexer.push_back_token(token)
      break unless self.starts().member?(tclass)
      result.push @node.parse(lexer)
    end
    result
  end

  def immediate_starts()
    @node.starts()
  end
  def immediate_has_epsilon()
    # This *can* be nothing!
    true
  end
end
def p_zero_plus(node)
  ParseZeroPlus.new(node)
end

class ParseOnePlus < ParseGenNode
  attr_reader :node
  def initialize(node)
    super()
    @node = node
  end

  def on_parse(lexer)
    result = []
    while true do
      token = lexer.next_token()
      unless token
        token.raise_error("unexpected EOF") if result.empty?
        break
      end
      literal = token.literal
      tclass = token.token_class()
      unless self.starts().member?(tclass)
        token.raise_error("unexpected EOF") if result.empty?
        lexer.push_back_token(token)
        break
      end
      lexer.push_back_token(token)
      result.push @node.parse(lexer)
    end
    result
  end

  def immediate_starts()
    @node.starts()
  end
  def immediate_has_epsilon()
    false
  end
end
def p_one_plus(node)
  ParseOnePlus.new(node)
end

class ParseOptional < ParseGenNode
  attr_reader :node
  def initialize(node)
    super()
    @node = node
  end

  def on_parse(lexer)
    token = lexer.next_token()
    return nil unless token
    literal = token.literal
    tclass = token.token_class()
    lexer.push_back_token(token)
    return nil unless self.starts().member?(tclass)
    return @node.parse(lexer)
  end

  def immediate_starts()
    @node.starts()
  end
  def immediate_has_epsilon()
    # This *can* be nothing!
    true
  end
end
def p_optional(node)
  ParseOptional.new(node)
end

class ParseSelect < ParseGenNode
  attr_reader :node_list
  def initialize(node_list, name_map)
    super()
    @node_list = node_list.zip(name_map)
    @start_select = {}
  end

  def on_parse(lexer)
    token = lexer.next_token()
    raise "unexpected EOF" unless token
    literal = token.literal
    tclass = token.token_class()
    node, name = @start_select[tclass]
    token.raise_error("unexpected token `#{token.literal}`") unless node
    lexer.push_back_token(token)
    #{type: name, n: node.parse(lexer)}
    node.parse(lexer)
  end

  def immediate_starts()
    result = Set[]
    @node_list.each {|n, name|
      n.starts().each {|start|
        #p ["start", start]
        raise "ambiguous start case `#{start}`" if result.member?(start)
        result.add? start
        @start_select[start] = [n, name]
      }
    }
    result
  end
  def immediate_has_epsilon()
    @node_list.any? {|n, name| n.has_epsilon() }
  end
end
def p_select(node_list, name_map)
  ParseSelect.new(node_list, name_map)
end

class ParseSequence < ParseGenNode
  attr_reader :node_list, :name_map
  def initialize(node_list, name_map)
    super()
    @node_list = node_list.zip(name_map)
  end

  def on_parse(lexer)
    result = {}
    @node_list.each {|n, name|
      parsed = n.parse(lexer)
      result[name] = parsed if name
    }

    # Special cases

    # Singly-linked list
    if result.include?(:SPECIAL_head) then
      raise "Node spec invalid: :SPECIAL_head without :SPECIAL_tail" unless result.include?(:SPECIAL_tail)
      raise "Node spec invalid: :SPECIAL_head and :SPECIAL_tail keys and something else likely defined" unless result.size == 2
      head = result[:SPECIAL_head]
      tail = result[:SPECIAL_tail]
      tail = [] if tail == nil
      return [head] + tail
    end
    raise "Node spec invalid: :SPECIAL_tail without :SPECIAL_head" if result.include?(:SPECIAL_head)

    # Everything else is syntax and we want to ignore it
    if result.include?(:SPECIAL_full_body) then
      #p result
      raise "Node spec invalid: :SPECIAL_full_body key and something else likely defined" unless result.size == 1
      return result[:SPECIAL_full_body]
    end

    return result
  end

  def immediate_starts()
    result = Set[]
    @node_list.each {|n, name|
      n.starts().each {|start|
        raise "ambiguous start case `#{start}`" if result.member?(start)
        result.add? start
      }
      break unless n.has_epsilon()
    }
    # Sanity check!
    @starts_cache = result
    @node_list.each {|n, name| n.starts() }
    return result
  end
  def immediate_has_epsilon()
    result = @node_list.all? {|n, name| n.has_epsilon() }
    # Sanity check! TODO: Make this work without triggering a recursion-driven stack overflow
    @has_epsilon_cache = result
    @node_list.each {|n, name| n.has_epsilon() }
    return result
  end
end
def p_sequence(node_list, name_map)
  ParseSequence.new(node_list, name_map)
end
