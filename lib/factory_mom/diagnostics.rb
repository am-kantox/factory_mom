module FactoryMom
  class ::Object
    @@tracked_subclasses = {}

    def self.eigenclass
      class << self
        self
      end
    end

#    def self.inherited subclass
#    end
  end

  class Diagnostics
    attr_reader :targets

    # Usage: Diagnostics.new User, Post: -> { puts 'Post class loaded!' }
    # @param targets the array of classes to get subclasses for
    # @param plugins the hash of { class => lambda } to get subclasses and callback on load
    def initialize *targets, **plugins
      self.targets! targets
      self.plugins! plugins
    end
    private_class_method :new

    def flat_targets
      targets.values.inject &:|
    end

    def target! target
      targets! [target]
    end

    def targets! *targets
      (@targets ||= {}).merge!(targets.flatten.map do |klazz|
                                 [klazz.to_s.to_sym, ObjectSpace.each_object(Class).select { |k| k < spy(klazz) }]
                               end.to_h)
    end

    def plugin! target, λ
      plugins!(**{ target.to_s.to_sym => λ })
    end

    def plugins! **hash
      targets! hash.keys
      (@plugins ||= {}).merge! hash.map { |k, v| [k.to_s.to_sym, v] }.to_h
    end

  private
    def spy_inherited klazz, subclass
      TracePoint.new(:end) do |tp|
        if tp.self == subclass
          @plugins[klazz.to_s.to_sym].call(tp.self) if @plugins[klazz.to_s.to_sym].is_a? Proc
          @targets[klazz.to_s.to_sym] << subclass
          tp.disable
        end
      end.enable
    end

    def spy klazz
      begin
        if klazz.is_a?(Symbol) || klazz.is_a?(String)
          klazz = klazz.to_s.split('::').inject(Object) do |mod, class_name|
            mod.const_get(class_name)
          end
        end
      rescue
        raise ArgumentError.new("Unknown class #{klazz}")
      end

      λ = lambda do |receiver, klazz, subclass|
            klazz.send(:∃inherited, subclass) if klazz.eigenclass.method_defined?(:∃inherited)
            receiver.send :spy_inherited, klazz, subclass
          end

      __self, __klazz = self, klazz

      if !klazz.eigenclass.method_defined?(:inherited)
        klazz.define_singleton_method :inherited do |subclass|
          # Hi. I am a stub.
          # I am not quite elegant solution of having no cumbersome logic
          #     in the method below and of allowing to override :inherited
          #     during the long run.
          # The method below just relies on that :inherited exists everywhere.
          # If it does not, we create a stub here. That simple.
        end
      end

      if !klazz.eigenclass.method_defined?(:∃inherited)
        klazz.eigenclass.send :alias_method, :∃inherited, :inherited
        klazz.define_singleton_method :inherited, λ.curry[__self, __klazz]
      end

      klazz
    end
  end

  VISOR = Diagnostics.send :new
end
