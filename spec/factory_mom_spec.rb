require 'spec_helper'

describe FactoryMom do
  context ::Hash do
    let(:hash) { { a: 5, "b" => Hash, Integer => [5, 6, 7], other: { h1: 5, h2: nil } } }
    it "Hash::to_double_splat works as expected" do
      expect(hash.to_double_splat).to eq (%q{a: 5, "b" => Hash, Integer => [5, 6, 7], other: { h1: 5, h2: nil }})
      expect({}.to_double_splat).to eq ('')
    end
  end

  context FactoryMom::Diagnostics do
    let(:mom) { FactoryMom::VISOR }
    let(:stdout) { [] }

    before do
      class A ; end
      class B
        @@inherited_counter ||= 0
        def self.inherited_counter
          @@inherited_counter
        end
        def self.inherited subclass
          lambda do
            @@inherited_counter += 1
          end.call
        end
      end
      class B0 < B ; end

      mom.targets! A, B
      mom.plugins! A: lambda { |c| stdout << 'Hi, I am A plugin'}
      mom.plugin! B, lambda { |c| stdout << 'Hi, I am B plugin'}
      mom.target! A

      class A1 < A ; end
      class A2 < A ; end
      class A3 < A ; end

      class B1 < B ; end
    end

    it 'hooks standard classes properly' do
      # ▶ mom
      #⇒ #<FactoryMom::Diagnostics:0x00000004095958
      #  @plugins=
      #    { :A=>#<Proc:0x00000002606a60@/home/am/Proyectos/Kantox/factory_mom/spec/factory_mom_spec.rb:9 (lambda)>,
      #      :B=>#<Proc:0x00000002a07808@/home/am/Proyectos/Kantox/factory_mom/spec/factory_mom_spec.rb:10 (lambda)>},
      #  @targets = {:A=>[A1, A2, A3], :B=>[B1]}>
      expect(mom.targets[:A]).to match_array([A1, A2, A3])
      expect(mom.targets[:B]).to match_array([B0, B1])
      expect(mom.instance_variable_get(:@plugins).size).to eq 2
      expect(stdout).to match_array([
        'Hi, I am A plugin',
        'Hi, I am A plugin',
        'Hi, I am A plugin',
        'Hi, I am B plugin'
      ])
    end
    it 'handles both defined and undefined inherited callbacks' do
      expect(B.inherited_counter).to eq 2
    end
  end

  context FactoryMom::ActiveRecordBase do
    let(:mom) { FactoryMom::MODEL_VISOR }

    it 'hooks ActiveRecord::Base' do
      expect(mom.targets.keys).to match_array([ActiveRecord::Base.name.to_sym])
    end
    it 'reads indices properly' do
      expect(mom.indices.values.reduce(&:|).map(&:name)).to match_array(["index_posts_on_text", "index_comments_on_text"])
    end
    it 'reads foreign keys properly' do
      expect(mom.foreign_keys.values.reduce(&:|).map(&:name)).to match_array([]) # FIXME On MySQL there must be FKs
      skip 'unless I have MySQL tests' do
        pending 'test this on MySQL database to ensure proper functionality'
      end
    end
    it 'reads reflections properly' do
      expect(mom.reflections(:user).to_a.length).to eq 1
      expect(mom.reflections(:user, :post).to_a.length).to eq 2
      expect(mom.reflections.map(&:last).map(&:count).reduce(&:+)).to eq 7
    end
    it 'reads parents properly' do
      expect(mom.parents(:user).first.last).to be_nil
      expect(mom.parents(:user, unsplat: true)).to be_nil
      expect(mom.parents(:writer, unsplat: true).to_sym).to eq :user
    end
    it 'supports hooks on inheritance' do
      hooked = false
      mom.hook do |model|
        hooked = true
      end
      expect(hooked).to be false
      class ARB < ActiveRecord::Base ; end
      expect(hooked).to be true
    end
  end

  context FactoryMom::DSL::Generators do
    it 'generates string properly' do
      expect(subject.string.length).to eq 16
      expect(subject.string(length: 5).length).to eq 5
      expect(subject.string(utf8: false)).to match /[a-z]+/
      expect(subject.string(utf8: true)).to match /\p{Letter}+/
      expect(subject.string(strip: true)).to match /\S.+\S/
      expect(subject.string(strip: false)).to match /\s.+\s/
      expect(puts "\t\t#{subject.string(utf8: true)}").to be_nil
    end

    it 'generates counter properly' do
      expect(subject.counter.length).to eq 2
      expect(subject.counter(length: 5).length).to eq 5
      expect(subject.counter(owner: :aleksei)).to eq '01'
      # subsequent execution
      expect(subject.counter(owner: :aleksei)).to eq '02'
      9.times { subject.counter(owner: :hex, base: 16) }
      expect(subject.counter(owner: :hex, base: 16)).to eq '0A'
      expect { 99.times { subject.counter(owner: :overflow) } }.not_to raise_error
      expect { 100.times { subject.counter(owner: :overflow) } }.to raise_error(FactoryMom::MomFail)
    end

    it 'generates pattern properly' do
      expect(subject.pattern(owner: :pattern).length).to eq 4
      expect(subject.pattern(owner: :pattern)).to eq '😎002'
      expect(puts "\t\t#{subject.pattern(owner: :pattern)}").to be_nil
      expect(subject.pattern(template: 'Шаблон«5»').length).to eq 11
      expect(subject.pattern(owner: :шаблон, template: 'Шаблон«3a»')).to eq 'Шаблон001'
      # subsequent execution
      35.times { subject.pattern(owner: :шаблон, template: 'Шаблон«3a»') }
      expect(subject.pattern(owner: :шаблон, template: 'Шаблон«3a»')).to eq 'Шаблон011'
    end

    it 'might generate sequences basing on name and params' do
      expect(subject.sequence(:string).call.length).to eq 16
      expect(subject.sequence(:counter, owner: :sequence).call.length).to eq 2
      expect(subject.sequence(:pattern, owner: :sequence).call.length).to eq 4
    end
  end

end
