##############################
# Lexer
##############################

KEYWORDS = Set[
  "const",
  "else",
  "function",
  "if",
  "var",
]

OPERATORS = [
  ",", ";",
  ":",
  "=",
  "(", ")",
]

class Lexer
  def initialize(fname, in_str)
    @fname = fname
    @in_str = in_str
    @in_offs = 0
    @line_number = 1
    @line_start = @in_offs
    @stashed_token = nil
    @latest_token = nil
  end

  def next_pos()
    loop do
      pos = get_token_pos()
      c = next_char()
      return nil unless c

      if is_ws(c) then
        # Skip whitespace

      elsif c == "#" then
        # Skip comments
        loop do
          c = next_char()
          return nil unless c
          break if is_nl(c)
        end

      else
        push_back_char()
        return pos

      end
    end
  end

  def next_token()
    if @stashed_token then
      token = @stashed_token
      @stashed_token = nil
      return token
    end

    @latest_token = next_token_unstashed()
    @latest_token
  end

  def push_back_token(token)
    raise "Attempted to push back 2 tokens!" if @stashed_token
    raise "Attempted to push back wrong token! (#{token} instead of #{@latest_token})" if token != @latest_token
    @stashed_token = token
  end

  # This is mostly for debugging.
  include Enumerable
  def each()
    loop do
      token = next_token()
      return unless token
      yield token
    end
  end

  protected

  def next_token_unstashed()
    pos = next_pos()
    c = next_char()
    return nil unless c

    if c =~ /^[a-zA-Z_]$/ then
      # Consume name
      return Token.new(pos, c + next_match(/^[a-zA-Z_0-9]*/))

    elsif c =~ /^[0-9]$/ then
      # Consume number
      c2 = next_char()
      if c2 == "b" or c2 == "B" then
        # Binary
        return Token.new(pos, c + c2 + next_match(/^[0-1]+/))
      elsif c2 == "o" or c2 == "O" then
        # Octal
        return Token.new(pos, c + c2 + next_match(/^[0-7]+/))
      elsif c2 == "x" or c2 == "X" then
        # Hexadecimal
        return Token.new(pos, c + c2 + next_match(/^[0-9A-Fa-f]+/))
      else
        # Decimal
        push_back_char()
        return Token.new(pos, c + next_match(/^[0-9]*/))
      end

    elsif c == "\"" then
      accum = c
      loop do
        m = next_match(/^[^"\\]*/)
        accum += m
        c = next_char()
        pos.raise_error("unterminated string literal") unless c
        accum += c
        if c == "\"" then
          break
        elsif c == "\\" then
          c = next_char()
          pos.raise_error("unterminated string literal") unless c
          accum += c
          if c =~ /^[nrt"\\]$/ then
            # Take as-is
          elsif c == "x" then
            # Hexadecimal 2-digit byte
            m = next_match(/^[0-9A-Fa-f]{2}/)
            get_token_pos().raise_error("expected 2 hex digits after `\\x`") unless m
            accum += m
          elsif c == "u" then
            # Hexadecimal braced Unicode character \u{...}
            m = next_match(/^\{[0-9A-Fa-f]+\}/)
            get_token_pos().raise_error("expected hex digits in {braces} after `\\u`") unless m
            accum += m
          else
            push_back_char()
            get_token_pos().raise_error("invalid string escape `\\#{c}`")
          end

        else
          push_back_char()
          get_token_pos().raise_error("BUG, case not handled!")
        end
      end
      return Token.new(pos, accum)

    else
      return Token.new(pos, c)
    end
  end

  def next_char()
    if @in_offs < @in_str.length then
      c = @in_str[@in_offs]
      @in_offs += 1
      if is_nl(c) then
        @line_start = @in_offs
        @line_number += 1
      end
      c
    else
      nil
    end
  end

  def get_token_pos()
    TokenPos.new(@fname, @line_number, (@in_offs - @line_start) + 1)
  end

  def next_match(re)
    m = re.match(@in_str[@in_offs..])
    #return nil unless m
    result = m[0]
    result.length.times { next_char() }
    result
  end

  def push_back_char()
    raise "attempted to push back before start of input" if @in_offs < 1
    @in_offs -= 1
    raise "attempted to push back before start of input" if @in_offs < 0
  end

  def is_ws(c)
    c == "\t" or c == "\n" or c == "\r" or c == " "
  end

  def is_nl(c)
    # CR (\r) is classified as whitespace here.
    # We do not support the old Macintosh-style CR-only newlines here. We don't need to.
    # CRLF (\r\n) should work fine for now.
    c == "\n"
  end
end

class TokenPos
  attr_reader :fname, :line, :col
  def initialize(fname, line, col)
    @fname = fname
    @line = line
    @col = col
  end

  def raise_error(msg)
    raise "#{@fname}:#{@line}:#{@col}: #{msg}"
  end
end

##############################
# Tokens
##############################
class Token
  attr_reader :pos, :literal
  def initialize(pos, literal)
    @pos = pos
    @literal = literal
  end

  def is_name()
    @literal[0] =~ /^[a-zA-Z_]/ and not KEYWORDS.member?(@literal)
  end

  def is_int()
    @literal[0] =~ /^[0-9]/
  end

  def is_string()
    @literal[0] == "\""
  end

  def token_class()
    return :string if self.is_string()
    return :name if self.is_name()
    return :int if self.is_int()
    @literal
  end

  def raise_error(msg)
    @pos.raise_error(msg)
  end
end
