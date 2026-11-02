##############################
# Context for executing code
##############################
class ExecContext
  def initialize()
    # Builtins
    @current_scope = ExecScope.new(nil)
    @current_scope.define(false, "print", proc {|*args|
      puts args.map{|v| "#{v.evaluate_to_string()}(#{v.type.evaluate_to_string()})"}.join(" ")
    })
    @current_scope.define(false, "true", TRUE_BOOL);
    @current_scope.define(false, "false", FALSE_BOOL);

    # Global scope
    @current_scope = ExecScope.new(@current_scope)
  end

  def push_new_scope()
    @current_scope = ExecScope.new(@current_scope)
  end

  def pop_scope()
    @current_scope = @current_scope.parent
  end

  def define(is_mutable, key, value)
    @current_scope.define(is_mutable, key, value)
  end

  def []=(key, value)
    @current_scope[key] = value
  end

  def [](key)
    @current_scope[key]
  end
end

class ExecScope
  attr_reader :parent
  def initialize(parent)
    @parent = parent
    @vars = {}
    @var_is_mutable = {}
  end

  def define(is_mutable, key, value)
    @vars[key] = value
    @var_is_mutable[key] = is_mutable
  end

  def []=(key, value)
    if @vars.include?(key) then
      raise "attempted to write to read-only name `#{key}`" unless @var_is_mutable[key]
      @vars[key] = value
    elsif @parent then
      @parent[key] = value
    else
      raise "cannot write to non-existent variable `#{key}`"
    end
  end

  def [](key)
    if @vars.include?(key) then
      @vars[key]
    elsif @parent then
      @parent[key]
    else
      raise "cannot read from non-existent variable `#{key}`"
    end
  end
end

class ValueTypeBase
  def evaluate_to_string()
    p ["x", self]
    raise "TODO: Implement me in a concrete class!"
  end
end

class ValueBase
  def evaluate_to_string()
    p ["x", self]
    raise "TODO: Implement me in a concrete class!"
  end

  def evaluate_binop(op, other)
    p ["x", op, self, other]
    raise "TODO: Implement me in a concrete class!"
  end
end

class VTBool < ValueTypeBase
  def make(v)
    # Use the same instances everywhere
    if v === true then
      TRUE_BOOL
    elsif v === false then
      FALSE_BOOL
    else
      raise "invalid boolean value #{v}"
    end
  end

  def evaluate_to_string()
    "bool"
  end
end
class VBool < ValueBase
  TYPE_INSTANCE = VTBool.new
  attr_reader :v
  def initialize(v)
    raise "mismatched host type #{v.class.name}" unless v === true or v === false
    @v = v
  end

  def type()
    TYPE_INSTANCE
  end

  def evaluate_to_string()
    @v ? "true" : "false"
  end

  def evaluate_binop(op, other)
    p ["x", op, self, other]
    raise "binops not implemented on strings, not sure if they ever will be"
  end
end
TRUE_BOOL = VBool.new(true)
FALSE_BOOL = VBool.new(false)

class VTInt < ValueTypeBase
  attr_reader :bits, :signed
  def initialize(bits, signed)
    @bits = bits
    @signed = signed
  end

  def evaluate_to_string()
    (@signed ? "i" : "u") + @bits.to_s
  end

  def assert_in_range(value)
    if @signed then
      if value < -(1<<(@bits-1)) then
        raise "underflow for #{@bits}-bit signed integer: #{value.to_s(16).upcase}"
      elsif value >= (1<<(@bits-1))
        raise "overflow for #{@bits}-bit signed integer: #{value.to_s(16).upcase}"
      end
    else
      raise "TODO: Handle unsigned integers"
    end
  end

  def coerce_int_type(other)
    b1 = @bits
    b2 = other.bits
    # Coercion rules:
    # - Unsigned(n) @ Signed(...) converts to Signed(n+1)
    signed = @signed or other.signed
    b1 += 1 if signed and not @signed
    b2 += 1 if signed and not other.signed
    # - Int(n) @ Int(m) converts to Int(max(n, m))
    bits = b1
    bits = b2 if b2 > b1
    VTInt.new(bits, signed)
  end

  def make(value)
    VInt.new(self, value)
  end
end
class VInt < ValueBase
  attr_reader :type, :value
  def initialize(type, value)
    raise "mismatched host type #{value.class.name}" unless value.kind_of?(Integer)
    @type = type
    @value = value
    @type.assert_in_range(value)
  end

  def evaluate_to_string()
    @value.to_s
  end

  def evaluate_binop(op, other)
    if other.kind_of?(VInt) then
      type = @type.coerce_int_type(other.type)

      case op
      in BinOp::Add
        v = @value + other.value
      in BinOp::Sub
        v = @value - other.value
      in BinOp::Mul
        v = @value * other.value
      in BinOp::Div
        v = @value / other.value
      in BinOp::Mod
        v = @value % other.value
      else
        raise "TODO implement binop `#{op}`"
      end
      type.make(v)
    else
      p ["x", op, self, other]
      raise "cannot do binop between these types"
    end
  end
end

class VTString < ValueTypeBase
  def make(rstring)
    VString.new(rstring)
  end

  def evaluate_to_string()
    "string"
  end
end
class VString < ValueBase
  TYPE_INSTANCE = VTString.new
  # TODO: Make this a wrapper around []u8
  attr_reader :rstring
  def initialize(rstring)
    raise "mismatched host type #{rstring.class.name}" unless rstring.kind_of?(String)
    @rstring = rstring
  end

  def type()
    TYPE_INSTANCE
  end

  def evaluate_to_string()
    @rstring
  end

  def evaluate_binop(op, other)
    p ["x", op, self, other]
    raise "binops not implemented on strings, not sure if they ever will be"
  end
end
