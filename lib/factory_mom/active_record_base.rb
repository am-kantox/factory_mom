module FactoryMom
  class ActiveRecordBase < Diagnostics
    def initialize
      super({:'ActiveRecord::Base' => lambda { |model| @hook.call(model) if @hook }})
    end

    def hook
      @hook = block_given? ? Proc.new : enum_for(:hook)
    end

    # Array of all reflections:
    #     mom.reflections.values.reduce(&:|)
    # @return yields `[Class, [Reflections]]`
    def reflections! *targets
      return enum_for(:reflections!, *targets) unless block_given?

      goal(*targets).each do |klazz|
        yield [klazz, klazz.reflections]
      end
    end

    # Array of all indices:
    #     mom.indices.values.reduce(&:|)
    # @return yields `[Class, [Indices]]`
    def indices! *targets
      return enum_for(:indices!, *targets) unless block_given?

      goal(*targets).each do |klazz|
        yield [klazz, ActiveRecord::Base.connection.indexes(klazz.name.tableize.to_sym)]
      end
    end


    # Array of all FKs:
    #     mom.foreign_keys.values.reduce(&:|)
    # @return yields `[Class, [FKs]]`
    def foreign_keys! *targets
      return enum_for(:foreign_keys!, *targets) unless block_given?

      goal(*targets).each do |klazz|
        yield [klazz, ActiveRecord::Base.connection.foreign_keys(klazz.name.tableize.to_sym)]
      end
    end

    %i(reflections indices foreign_keys).each do |meth|
      define_method :"#{meth}" do |*targets|
        reduce public_send(:"#{meth}!", *targets).to_a
      end
    end

  private

    def reduce hash
      hash.group_by(&:first).map { |k, v| [k, v.map(&:last).reduce(&:merge)] }.to_h
    end

    def goal *targets
      goal = self.targets.values.flatten
      targets.empty? ? goal : (goal & targets.map(&:to_class).compact)
    end

  end

  MODEL_VISOR = ActiveRecordBase.send :new
end
