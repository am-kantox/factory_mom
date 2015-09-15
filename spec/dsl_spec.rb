require 'spec_helper'

describe FactoryMom do
  describe FactoryMom::Kindergarten do
    let(:mom) { FactoryMom::MODEL_VISOR }

    let(:kindergartens) do
      FactoryMom.define do
        produce :user
        produce :writer
        produce :post
        produce :comment do
          trait :short do
            text 'Hello world!'
          end
        end
      end
    end

    let(:user_instance) do
      FactoryMom.define do |kg|
        kg.instantiate :user
      end
    end

    it 'might produce simple things' do
      puts kindergartens.inspect
      # puts user_instance.inspect
    end
  end
end
