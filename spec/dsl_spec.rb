require 'spec_helper'

describe FactoryMom do
  describe FactoryMom::Kindergarten do
    let(:mom) { FactoryMom::MODEL_VISOR }

    let(:kindergartens) do
      FactoryMom.define do |kg|
        kg.produce :user
      end
    end

    it 'might produce simple things' do
      binding.pry
      puts kindergartens[:common].inspect
    end
  end
end
