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
  def define pool: :common
    return enum_for(:define) unless block_given?
    @kindergartens ||= {}
    @kindergartens[pool] ||= Kindergarten.new
    @kindergartens[pool].instance_eval do
      yield self
    end
    @kindergartens
  end
  module_function :define

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
  end
end
