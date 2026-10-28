##############################
# Context for executing code
##############################
class ExecContext
  def initialize()
    # Builtins
    @current_scope = ExecScope.new(nil)
    @current_scope.define(false, "print", proc {|*args| p args })

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

