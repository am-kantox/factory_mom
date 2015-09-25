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
            notice { puts 'Hello world!'; 'Hello world!' }
          end
          arg1
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
      expect(FactoryMom.send(:kindergartens)[:common].factory_code :comment, aliases: [:комментарий]).to eq %q{
	factory :comment, aliases: [:комментарий] do
		transient do
			shallow []
		end
		# associations
		association :author, shallow: [:✓], factory: :writer, strategy: :create
		# raw columns
		notice { FactoryMom::DSL::Generators.string length: 16 }
		text { FactoryMom::DSL::Generators.loremipsum length: 255 }
		# delegated to factory
		trait :arg1 do
			notice { puts 'Hello world!'; 'Hello world!' }
		end
		arg1
		# before hook
		before(:create) do |this, evaluator|
			this.post = ::FactoryGirl.create(:post, comments: [this], shallow: (evaluator.shallow | [:comment])) if (evaluator.shallow & [:✓, :post]).empty? && this.post.blank?
		end
# FIXME THROUGH
	end unless ::FactoryGirl.factories.any? { |f| f.name == :comment }

}
      expect(FactoryMom.send(:kindergartens)[:common].factory_code :writer, snippet: false).to eq %q{::FactoryGirl.define do
	factory :writer, parent: :user, class: :writer do
		transient do
			shallow []
		end
		# associations
		association :moderator, shallow: [:✓], factory: :user, strategy: :create
		# raw columns
		name { FactoryMom::DSL::Generators.string length: 16 }
		# this object has no delegates
		# this object does not use before hook
# FIXME THROUGH
	end unless ::FactoryGirl.factories.any? { |f| f.name == :writer }
end
}
    end

    before(:each) do
      @uc = User.count
      @wc = Writer.count
      @pc = Post.count
      @cc = Comment.count
    end

    it 'might create instances' do
      expect(kindergartens.length).to eq 4
    end

    it 'might create instances of User' do
      expect(user_instance.class).to be User
      expect(puts user_instance.inspect).to be_nil
      expect(User.count - @uc).to eq 9
      expect(Writer.count - @wc).to eq 4
      expect(Post.count - @pc).to eq 2
      expect(Comment.count - @cc).to eq 4
    end
    it 'might create instances of Writer' do
      expect(writer_instance.class).to be Writer
      expect(puts writer_instance.inspect).to be_nil
      expect(User.count - @uc).to eq 10
      expect(Writer.count - @wc).to eq 5
      expect(Post.count - @pc).to eq 2
      expect(Comment.count - @cc).to eq 4
    end
    it 'might create instances of Post' do
      expect(post_instance.class).to be Post
      expect(puts post_instance.inspect).to be_nil
      expect(User.count - @uc).to eq 5
      expect(Writer.count - @wc).to eq 2
      expect(Post.count - @pc).to eq 1
      expect(Comment.count - @cc).to eq 2
    end
    it 'might create instances of Comment' do
      expect(comment_instance.class).to be Comment
      expect(puts comment_instance.inspect).to be_nil
      expect(User.count - @uc).to eq 3
      expect(Writer.count - @wc).to eq 1
      expect(Post.count - @pc).to eq 1
      expect(Comment.count - @cc).to eq 1
    end
  end
end
