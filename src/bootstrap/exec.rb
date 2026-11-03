##############################
# Context for executing code
##############################
class ExecContext
  def initialize()
    # Builtins
    @current_scope = ExecScope.new(nil)
    self.define_construct(false, "print", VTHostProc.new, [proc {|*args|
      puts args.map{|v| "#{v.evaluate_to_string()}(#{v.type.evaluate_to_string()})"}.join(" ")
    }])
    self.define_construct(false, "true", VTBool.new, [true])
    self.define_construct(false, "false", VTBool.new, [false])

    self.define_construct(false, "bool", VTType.new, [VBool.new(false).type])
    self.define_construct(false, "u8", VTType.new, [VTInt.new(8, false)])
    self.define_construct(false, "i32", VTType.new, [VTInt.new(32, true)])
    self.define_construct(false, "string", VTType.new, [VString.new("").type])
    self.define_construct(false, "type", VTType.new, [VTType.new.type])

    # Global scope
    @current_scope = ExecScope.new(@current_scope)
  end

  def push_new_scope()
    @current_scope = ExecScope.new(@current_scope)
  end

  def pop_scope()
    @current_scope = @current_scope.parent
  end

  def define_construct(is_mutable, key, value_type, value_construct_args)
    @current_scope.define(is_mutable, key, value_type, value_type.make(*value_construct_args))
  end

  def define_existing(is_mutable, key, value_type, value)
    @current_scope.define(is_mutable, key, value_type, value)
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
  end

  def define(is_mutable, key, value_type, value)
    @vars[key] = VarSlot.new(is_mutable, value_type, value_type.coerce(value))
  end

  def [](key)
    if @vars.include?(key) then
      @vars[key]
    elsif @parent then
      @parent[key]
    else
      raise "cannot access non-existent variable `#{key}`"
    end
  end
end

class VarSlot
  attr_reader :value
  def initialize(is_mutable, var_type, value)
    @is_mutable = is_mutable
    @var_type = var_type
    @value = @var_type.coerce(value)
  end

  def set(value)
    raise "attempted to write to read-only variable" unless @is_mutable
    @value = @var_type.coerce(value)
  end
end



class ValueBase
  def evaluate_to_string()
    p ["x", self]
    raise "TODO: Implement me in a concrete class!"
  end

  def evaluate_to_int()
    p ["x", self]
    raise "TODO: Implement me in a concrete class!"
  end

  def evaluate_binop(op, other)
    p ["x", op, self, other]
    raise "TODO: Implement me in a concrete class!"
  end

  def subscript_element(base)
    p ["x", self, base]
    raise "TODO: Implement me in a concrete class!"
  end

  def subscript_slice(base, len)
    p ["x", self, base, len]
    raise "TODO: Implement me in a concrete class!"
  end
end

# Types are also values
class ValueTypeBase < ValueBase
  def ==(other)
    p ["x", self, other]
    raise "TODO: Implement me in a concrete class!"
  end

  def coerce(src)
    # If the types are the same, use the value as-is.
    return src if self == src.type

    p ["x", self, src]
    raise "cannot coerce #{src.type}(#{src.type.evaluate_to_string}) into #{self}(#{self.evaluate_to_string})"
  end

  def type()
    VTType.new
  end
end

# This is the container for a type!
class VTType < ValueTypeBase
  def make(v)
    v
  end

  def ==(other)
    self.class == other.class
  end

  def evaluate_to_string()
    "type"
  end
end

class VTHostProc < ValueTypeBase
  def make(fn)
    VHostProc.new(fn)
  end

  def ==(other)
    self.class == other.class
  end

  def evaluate_to_string()
    "function{host}(...)"
  end
end
class VHostProc < ValueBase
  TYPE_INSTANCE = VTHostProc.new
  attr_reader :fn
  def initialize(fn)
    @fn = fn
  end

  def type()
    TYPE_INSTANCE
  end

  def evaluate_to_string()
    self.to_s
  end

  def call(ctx, *args)
    @fn.call(*args)
  end
end

class VTASTProc < ValueTypeBase
  attr_reader :param_types, :return_type
  def initialize(param_types, return_type)
    @param_types = param_types
    @return_type = return_type
  end

  def make(ast)
    VASTProc.new(self, ast)
  end

  def ==(other)
    self.class == other.class and @return_type == other.return_type and @param_types.zip(other.param_types).all?{|a,b| a == b}
  end

  #def evaluate_to_string()
  #  result = "function(...)"
  #  result
  #end
end
class VASTProc < ValueBase
  def initialize(ast_type, ast)
    @ast_type = ast_type
    @ast = ast
    # TODO: Verify!
  end

  def type()
    @ast_type
  end

  #def evaluate_to_string()
  #  self.to_s
  #end

  def call(ctx, *args)
    raise "expected #{@ast_type.param_types.length} args, got #{args.length} args instead" unless @ast_type.param_types.length == args.length
    #p ["T", @ast_type]
    #p ["p", @ast_type.param_types]
    #p ["r", @ast_type.return_type]
    #p ["a", @ast.body]
    # FIXME: Use lexical scoping; this is dynamic scoping!
    ctx.push_new_scope()
    begin
      @ast.params.zip(@ast_type.param_types).zip(args).each do |(param, param_type), arg|
        ctx.define_existing(false, param.name.n, param_type, arg)
      end
      result = catch(:return) do
        @ast.body.evaluate(ctx)
        # If it falls through, it's void
        nil
      end
      return nil if @ast_type.return_type == nil
      @ast_type.return_type.coerce(result)
    ensure
      ctx.pop_scope()
    end
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

  def ==(other)
    self.class == other.class
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

  def ==(other)
    self.class == other.class and @bits == other.bits and @signed == other.signed
  end

  def evaluate_to_string()
    (@signed ? "i" : "u") + @bits.to_s
  end

  def assert_in_range(value)
    if @signed then
      if value < -(1<<(@bits-1)) then
        raise "underflow for #{@bits}-bit signed integer: hex #{value.to_s(16).upcase}"
      elsif value >= (1<<(@bits-1))
        raise "overflow for #{@bits}-bit signed integer: hex #{value.to_s(16).upcase}"
      end
    else
      if value < 0 then
        raise "underflow for #{@bits}-bit unsigned integer: hex #{value.to_s(16).upcase}"
      elsif value >= (1<<@bits)
        raise "overflow for #{@bits}-bit unsigned integer: hex #{value.to_s(16).upcase}"
      end
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

  def coerce(src)
    if self.class == src.type.class then
      make(src.value)
    else
      super(src)
    end
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

  def evaluate_to_int()
    @value
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
      in BinOp::Eq
        return @value == other.value ? TRUE_BOOL : FALSE_BOOL
      in BinOp::Ne
        return @value != other.value ? TRUE_BOOL : FALSE_BOOL
      in BinOp::Lt
        return @value < other.value ? TRUE_BOOL : FALSE_BOOL
      in BinOp::Gt
        return @value > other.value ? TRUE_BOOL : FALSE_BOOL
      in BinOp::Le
        return @value <= other.value ? TRUE_BOOL : FALSE_BOOL
      in BinOp::Ge
        return @value >= other.value ? TRUE_BOOL : FALSE_BOOL
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

  def ==(other)
    self.class == other.class
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

  def subscript_element(base)
    base = base.evaluate_to_int()
    raise "index #{base} out of range" unless base >= 0 and base < @rstring.length
    VTInt.new(32, true).make(@rstring[base].ord)
  end

  def subscript_slice(base, len)
    base = base.evaluate_to_int()
    raise "index #{base} out of range" unless base >= 0 and base < @rstring.length
    if len == nil then
      self.type().make(@rstring[base..])
    else
      len = len.evaluate_to_int()
      final = base + len - 1
      raise "final index #{final} out of range" unless len == 0 or (final >= 0 and final < @rstring.length)
      self.type().make(@rstring[base...(base+len)])
    end
  end
end
