module FactoryMom
  class ActiveRecordBase < Diagnostics
    def initialize
      super({:'ActiveRecord::Base' => lambda { |model| @hook.call(model) if @hook }})
    end

    def hook
      @hook = Proc.new if block_given?
      @hook
    end

    # Array of all reflections:
    #     mom.indices.map(&:last).reduce(&:|)
    # @return yields `[Class, [Reflections]]`
    def reflections *targets
      return enum_for(:reflections, *targets) unless block_given?

      goal(*targets).each do |klazz|
        yield [klazz, klazz.reflections]
      end
    end

    # Array of all indices:
    #     mom.indices.map(&:last).reduce(&:|)
    # @return yields `[Class, [Indices]]`
    def indices *targets
      return enum_for(:indices, *targets) unless block_given?

      goal(*targets).each do |klazz|
        yield [klazz, ActiveRecord::Base.connection.indexes(klazz.name.tableize.to_sym)]
      end
    end



    # Array of all FKs:
    #     mom.foreign_keys.map(&:last).reduce(&:|)
    # @return yields `[Class, [FKs]]`
    def foreign_keys *targets
      return enum_for(:foreign_keys, *targets) unless block_given?

      goal(*targets).each do |klazz|
        yield [klazz, ActiveRecord::Base.connection.foreign_keys(klazz.name.tableize.to_sym)]
      end
    end

  private

    def goal *targets
      goal = self.targets.values.flatten
      targets.empty? ? goal : (goal & targets.map(&:to_class).compact)
    end

  end

  MODEL_VISOR = ActiveRecordBase.send :new
end
