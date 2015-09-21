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

    let(:counters) { {} }

    %i(user writer post comment).each do |who|
      let(:"#{who}_instance") do
        FactoryMom.instantiate who
      end
    end

    before do
      %i(user writer post comment).each do |who|
        counters[:"#{who}_count_before"] = who.to_class.count
      end
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
			shallow []
		end
		# delegated to factory
		trait :arg1 do
			puts 'Hello world!'
		end
		# associations
		association :author, shallow: [:✓], factory: :writer, strategy: :create
		# raw columns
		text { FactoryMom::DSL::Generators.loremipsum }
		# before hook
		before(:create) do |this, evaluator|
			this.post = ::FactoryGirl.create(:post, comments: [this], shallow: (evaluator.shallow | [:comments])) if (evaluator.shallow & [:✓, :post]).empty? && this.post.blank?
		end
# FIXME THROUGH
	end

}
      expect(FactoryMom.send(:kindergartens)[:common].factory_code :writer, snippet: false).to eq %q{::FactoryGirl.define do
	factory :writer, parent: :user, class: :writer do
		transient do
			shallow []
		end
		# this object has no delegates
		# associations
		association :moderator, shallow: [:✓], factory: :user, strategy: :create
		# raw columns
		name { FactoryMom::DSL::Generators.loremipsum }
		# this object does not use before hook
# FIXME THROUGH
	end
end
}
    end

    it 'might create instances' do
      expect(kindergartens.length).to eq 4
    end
    it 'might create instances of User' do
      expect(user_instance.class).to be User
      expect(puts user_instance.inspect).to be_nil
      expect(User.count).to eq 11
      expect(Writer.count).to eq 5
      expect(Post.count).to eq 3
      expect(Comment.count).to eq 5
    end
    it 'might create instances of Writer' do
      expect(writer_instance.class).to be Writer
      expect(puts writer_instance.inspect).to be_nil
      expect(User.count).to eq 21
      expect(Writer.count).to eq 10
      expect(Post.count).to eq 5
      expect(Comment.count).to eq 9
    end
    it 'might create instances of Post' do
      expect(post_instance.class).to be Post
      expect(puts post_instance.inspect).to be_nil
      expect(User.count).to eq 26
      expect(Writer.count).to eq 12
      expect(Post.count).to eq 6
      expect(Comment.count).to eq 11
    end
    it 'might create instances of Comment' do
      expect(comment_instance.class).to be Comment
      expect(puts comment_instance.inspect).to be_nil
      expect(User.count).to eq 29
      expect(Writer.count).to eq 13
      expect(Post.count).to eq 7
      expect(Comment.count).to eq 12
    end
  end
end
