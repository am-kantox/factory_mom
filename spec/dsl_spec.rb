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
          trait :arg1, :arg2, hash: :hash  do
            puts 'Hello world!'
          end
        end
      end
    end

    let(:user_instance) do
      FactoryMom.define do
        instantiate :user
      end
    end

    it 'might produce simple things' do
      expect(kindergartens.class).to be Hash
      expect(kindergartens.length).to eq 4
      expect(kindergartens.keys).to match_array [User, Writer, Post, Comment]
      # { :delegates=>[[:trait, [:short], #<Proc:0x0000000223d3e8@/home/am/Proyectos/Kantox/factory_mom/spec/dsl_spec.rb:15>]],
      #   :columns=>{:id=>{:column=>..., :generator=>:autoinc, :nullable=>false},
      #              :text=>{:column=>..., :generator=>:loremipsum, :nullable=>true}
      #   },
      #   :handled=>{:author_id=>..., :post_id=>...},
      #   :suppressed=>{},
      #   :reflections=>{:after=>{:post=>[:post, :comment, [:this]]}, :association=>{:author=>[:writer]}}
      # }
      expect(kindergartens.values.last.class).to be Hash
      expect(kindergartens.values.last[:delegates].first.first).to eq :trait
      expect(kindergartens.values.last[:delegates].first.last.class).to be Proc

      expect(FactoryMom.mushrooms.length).to eq 4
    end

    it 'might produce code' do
      expect(FactoryMom.kindergartens[:common].code :comments, aliases: [:комментарий]).to eq %q{::FactoryGirl.define do
	factory :comments, aliases: [:комментарий] do
		transient do
			shallow false
		end
		# delegated to factory
		trait :arg1, :arg2, hash: :hash  do
			puts 'Hello world!'
		end
		# associations
		author :writer
		# raw columns
		text { FactoryMom::DSL::Generators.loremipsum }
# FIXME AFTER THROUGH
	end
end
}
      expect(FactoryMom.kindergartens[:common].code :writer).to eq %q{::FactoryGirl.define do
	factory :writer, parent: :user do
		transient do
			shallow false
		end
		# this object has no delegates
		# associations
		parent :user
		# raw columns
		name { FactoryMom::DSL::Generators.loremipsum }
# FIXME AFTER THROUGH
	end
end
}
    end
  end
end
