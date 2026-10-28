##############################
# Context for executing code
##############################
class ExecContext
  def initialize()
    @current_scope = ExecScope.new(nil)
    @current_scope.define("print", proc {|*args| p args })
  end

  def []=(key, value)
    @current_scope[key] = value
  end

  def [](key)
    @current_scope[key]
  end
end

class ExecScope
  def initialize(parent)
    @parent = parent
    @vars = {}
  end

  def define(key, value)
    @vars[key] = value
  end

  def []=(key, value)
    if @vars.include?(key) then
      @vars[key] = value
    else
      @parent[key] = value
    end
  end

  def [](key)
    if @vars.include?(key) then
      @vars[key]
    else
      @parent[key]
    end
  end
end

