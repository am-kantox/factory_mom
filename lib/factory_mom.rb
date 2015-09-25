require 'foreigner'
require 'active_record'

require 'factory_mom/version'
require 'factory_mom/mom_fail'
require 'factory_mom/diagnostics'
require 'factory_mom/active_record_base'
require 'factory_mom/dsl/sandbox'
require 'factory_mom/dsl/kindergarten'
require 'factory_mom/dsl/generators'
require 'factory_mom/selfcare/active_record_base_checker'

module FactoryMom
  class << self
    # @param [FactoryMom::Diagnostics] visor if set, the pool will be preloaded
    #  with all the models from it; set to `nil` to avoid predefined filling
    def define pool: :common, visor: MODEL_VISOR, yielding: false
      raise MomFail.new self, "FactoryMom Error: #{__caller__} requires a block" unless block_given?

      kindergartens[pool] ||= Kindergarten.new visor

      # Prepare stubs for all known classes
      visor.flat_targets.each do |klazz|
        kindergartens[pool].instance_eval do
          produce klazz
        end
      end if visor

      if yielding
        kindergartens[pool].instance_eval do
          yield self
        end
      else
        kindergartens[pool].instance_eval &Proc.new
      end

      # [AM] FIXME WHAT TO RETURN?
      mushrooms pool: pool
      # kindergartens[pool]
    end

    def instantiate name, pool: :common
      unless sandboxes[pool]
        kg = kindergartens[pool]
        sandboxes[pool] = Class.new(Sandbox) do
          begin
            generated = kg.factories_code as_string: true
            puts '—'*40
            puts generated
            puts '—'*40

            File.write('generated.rb', generated)
            class_eval generated
          rescue => e
            puts '='*40
            puts "==[ERROR]==> #{e}"
            puts e.backtrace.join $/
            puts '='*40
          end
        end

      end

      begin
        sandboxes[pool].class_eval "::FactoryGirl.create(:#{name})"
      rescue => e
        ActiveRecord::Base.logger.error "Error: instantiate failed for #{name}. Original: [#{e.message}]"
        ActiveRecord::Base.logger.debug e.backtrace
      end
    end

  protected

    def kindergartens
      @kindergartens ||= {}
    end

    def sandboxes
      @sandboxes ||= {}
    end

    def mushrooms pool: :common
      @kindergartens ||= {}

      kindergartens[pool] && kindergartens[pool].targets
    end
  end

  class ::Object
    def to_class
      nil
    end
  end
  class ::Hash
    def to_double_splat
      map do |k, v|
        case k
        when Symbol then "#{k}: "
        else "#{k.inspect} => "
        end << (Hash === v ? "{ #{v.to_double_splat} }" : v.inspect)
      end.join ', '
    end
  end
  class ::String
    def to_class
      Kernel.const_defined?(self.camelize) && self.camelize.constantize ||
        Kernel.const_defined?(self.camelize.singularize) && self.camelize.singularize.constantize ||
        Kernel.const_get(self.gsub(/(?:\A|_)(\w)/) { $1.upcase }) rescue nil
    end
  end
  class ::Symbol
    def to_class
      self.to_s.to_class
    end
    def pluralize
      self.to_s.pluralize.to_sym
    end
    def singularize
      self.to_s.singularize.to_sym
    end
  end
  class ::Class
    def to_class
      self
    end
    def to_sym
      self.name.gsub(/(?<=\w)([A-Z])/, '_\1').downcase.to_sym
    end
  end
  class ::NilClass
    def to_sym
      nil
    end
  end

end
