require 'spec_helper'

describe FactoryMom do
  context FactoryMom::Diagnostics do
    let(:mom) { FactoryMom::VISOR }
    let(:stdout) { [] }

    before do
      class A ; end
      class B
        def self.inherited subclass
          puts '      Hi! I have inherited defined.'
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

    it 'Diagnostics is able to hook classes' do
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
  end

  context FactoryMom::ActiveRecordBase do
    let(:mom) { FactoryMom::MODEL_VISOR }

    it 'counts all models in the app' do
      expect(mom.targets.keys).to match_array([ActiveRecord::Base.name.to_sym])
      expect(mom.indices.map(&:last).reduce(&:|).map(&:name)).to match_array(["index_posts_on_text"])
      expect(mom.foreign_keys.map(&:last).reduce(&:|).map(&:name)).to match_array([]) # FIXME On MySQL there must be FKs
      expect(mom.reflections.map(&:last).map(&:count).reduce(&:+)).to eq 4
    end
  end

end
