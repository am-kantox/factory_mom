require 'spec_helper'

describe FactoryMom do
  describe FactoryMom::Kindergarten do
    let(:mom) { FactoryMom::MODEL_VISOR }

    let(:kindergartens) do
      FactoryMom.define do
        produce :user
        produce :writer
        produce :post do
          suppress :title
        end
        produce :comment, aliases: [:комментарий]  do
          trait :arg1 do
            puts 'Hello world!'
          end
        end
      end
    end

    let(:user_instance) do
      FactoryMom.instantiate :comment
    end

    it 'might produce simple things' do
      expect(kindergartens.class).to be Hash
      expect(kindergartens.length).to eq 4
      expect(kindergartens.keys).to match_array [User, Writer, Post, Comment]
      expect(kindergartens.values.last.class).to be Hash
      expect(kindergartens.values.last[:delegates].first.first).to eq :trait
      expect(kindergartens.values.last[:delegates].first.last.class).to be Proc

      expect(FactoryMom.send(:mushrooms).length).to eq 4
    end

    it 'might produce code' do
      expect(FactoryMom.send(:kindergartens)[:common].factory_code :comments, aliases: [:комментарий]).to eq %q{
	factory :comments, aliases: [:комментарий] do
		transient do
			shallow false
		end
		# delegated to factory
		trait :arg1 do
			puts 'Hello world!'
		end
		# associations
		association :author, factory: :writer, strategy: :create
		# raw columns
		text { FactoryMom::DSL::Generators.loremipsum }
		# after hook
		after(:create, :build, :stub) do |this|
			this.post ||= create :post, comments: [this]
		end
# FIXME THROUGH
	end

}
      expect(FactoryMom.kindergartens[:common].factory_code :writer, snippet: false).to eq %q{::FactoryGirl.define do
	factory :writer, parent: :user, class: :writer do
		transient do
			shallow false
		end
		# this object has no delegates
		# associations
		association :parent, factory: :user, strategy: :create
		# raw columns
		name { FactoryMom::DSL::Generators.loremipsum }
		# this object does not use after hook
# FIXME THROUGH
	end
end
}
    end
    it 'might create instances' do
      expect(kindergartens.length).to eq 4
      expect(user_instance.class).to be Comment
    end
  end
end
