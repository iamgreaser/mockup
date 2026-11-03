##############################
# Grammar Parser
##############################

$parser_specs = {}

def grammar_parse_args(toks)
  patterns = []
  names = []
  toks.each do |tok|
    if tok[0] == "`" then
      # EDGE CASE
      name, sep, part = ["", "", tok]
    else
      name, sep, part = tok.rpartition("=")
    end
    #p ["seq", tok, name, sep, part]
    if part[0] == "`" then
      raise "invalid syntax for literal: \"#{part}\"" unless part[-1] == "`"
      lit = part[1...-1]
      raise "invalid literal" if lit == ""
      patterns.push(p_literal(lit))
    elsif part[0] == part[0].upcase then
      patterns.push(p_terminal(part.to_sym))
    else
      patterns.push(p_ref(part.to_sym))
    end
    names.push(sep == "" ? nil : name.to_sym)
  end

  [patterns, names]
end

IO.read("src/grammar.txt").split("\n").each do |line|
  toks = line.strip().split(" ")
  name = toks.shift
  if name == "#" or name == nil then
    # Comment or blank line, do nothing
  else
    last = toks.pop
    if last != ";" then
      p ["l", name, type, toks, last]
      raise "Expected `;` at end of grammar definition line, got `#{last}` instead"
    end

    name = name.to_sym
    type = toks.shift
    if type == "=" then
      $parser_specs[name] = p_sequence(*grammar_parse_args(toks))
    elsif type == "?=" then
      $parser_specs[name] = p_optional(p_sequence(*grammar_parse_args(toks)))
    elsif type == "*=" then
      $parser_specs[name] = p_zero_plus(p_sequence(*grammar_parse_args(toks)))
    elsif type == "+=" then
      $parser_specs[name] = p_one_plus(p_sequence(*grammar_parse_args(toks)))
    elsif type == "|" then
      $parser_specs[name] = p_select(*grammar_parse_args(toks))
    elsif type == "*|" then
      $parser_specs[name] = p_zero_plus(p_select(*grammar_parse_args(toks)))
    else
      p ["l", name, type, toks]
      raise "TODO: Handle grammar node type `#{type}`"
    end
  end
end

$parser_specs.each{|name, pg|
  pg.generate()
  #p [name, pg.class.name, pg.starts, pg.has_epsilon, pg]
}
