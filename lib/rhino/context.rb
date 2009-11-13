module Rhino

  class Context    
    attr_reader :scope

    class << self
      def open(options = {})
        ContextFactory.new.call do |native|
          yield new(native, options)
        end
      end
                      
      private :new
    end    
    
    def initialize(native, options) #:nodoc:
      @native = native
      @global = NativeObject.new(@native.initStandardObjects(nil, options[:sealed] == true))
      if with = options[:with]
        @scope = To.javascript(with)
        @scope.setParentScope(@global.j)
      else
        @scope = @global
      end
      unless options[:java]
        for package in ["Packages", "java", "org", "com"]
          @global.j.delete(package)
        end
      end      
    end
    
    def [](k)
      @scope[k]
    end
    
    def []=(k,v)
      @scope[k] = v
    end
                            
    def eval(str)
      str = str.to_s
      begin
        scope = To.javascript(@scope)
        result = @native.evaluateString(scope, str, "<eval>", 1, nil)
        To.ruby result
      rescue J::RhinoException => e
        raise Rhino::RhinoError, e
      end
    end
    
    def instruction_limit=(limit)
      @native.setInstructionObserverThreshold(limit);
      @native.factory.instruction_limit = limit
    end
        
  end
      
  class ContextFactory < J::ContextFactory
    
    def observeInstructionCount(cxt, count)
      raise RunawayScriptError, "script exceeded allowable instruction count" if count > @limit
    end
        
    def instruction_limit=(count)
      @limit = count
    end
  end
    
    
  class RhinoError < StandardError
    def initialize(native)
      @native = native
    end
    
    def message      
      @native.cause.details
    end
    
    def javascript_backtrace
      @native.getScriptStackTrace()
    end        
  end
  
  class RunawayScriptError < StandardError; end
end