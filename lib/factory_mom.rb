require 'foreigner'
require 'active_record'

require 'factory_mom/version'
require 'factory_mom/mom_fail'
require 'factory_mom/diagnostics'
require 'factory_mom/active_record_base'
require 'factory_mom/dsl/sandbox'
require 'factory_mom/dsl/kindergarten'
require 'factory_mom/dsl/generators'

module FactoryMom
  class << self
    attr_reader :kindergartens

    def define pool: :common, yielding: false
      raise MomFail.new self, "FactoryMom Error: #{__caller__} requires a block" unless block_given?
      @kindergartens ||= {}

      kindergartens[pool] ||= Kindergarten.new
      if yielding
        kindergartens[pool].instance_eval do
          yield self
        end
      else
        kindergartens[pool].instance_eval &Proc.new
      end
      mushrooms pool: pool
    end

    def mushrooms pool: :common
      @kindergartens ||= {}

      kindergartens[pool].targets
    end
  end

  class ::Object
    def to_class
      nil
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
end
