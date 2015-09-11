module FactoryMom
  class MomFail < StandardError
    attr_reader :context
    def initialize context, *args
      @context = context
      super *args
    end
  end
end
