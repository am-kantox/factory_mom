module FactoryMom
  class ActiveRecordBase < Diagnostics
    def initialize

      super({:'ActiveRecord::Base' => lambda { |model| puts "Hooked #{model}!" }})
    end

    def hook
      @hook = Proc.new if block_given?
      @hook
    end

    # Array of all reflections:
    #     mom.indices.map(&:last).reduce(&:|)
    # @return yields `[Class, [Reflections]]`
    def reflections
      return enum_for(:reflections) unless block_given?
      targets.each do |_, subclasses|
        subclasses.each do |klazz|
          yield [klazz, klazz.reflections]
        end
      end
    end

    # Array of all indices:
    #     mom.indices.map(&:last).reduce(&:|)
    # @return yields `[Class, [Indices]]`
    def indices
      return enum_for(:indices) unless block_given?
      targets.each do |_, subclasses|
        subclasses.each do |klazz|
          yield [klazz, ActiveRecord::Base.connection.indexes(klazz.name.tableize.to_sym)]
        end
      end
    end

    # Array of all FKs:
    #     mom.foreign_keys.map(&:last).reduce(&:|)
    # @return yields `[Class, [FKs]]`
    def foreign_keys
      return enum_for(:foreign_keys) unless block_given?
      targets.each do |_, subclasses|
        subclasses.each do |klazz|
          yield [klazz, ActiveRecord::Base.connection.foreign_keys(klazz.name.tableize.to_sym)]
        end
      end
    end

  end

  MODEL_VISOR = ActiveRecordBase.send :new
end
