module FactoryMom
  class Kindergarten
    def initialize
      @targets = {}
    end

    # Produces a skeleton for factory definition.
    # As soon as target is already defined, does nothing; it is safe
    #   to call this method whereever.
    # The resuting structure of `@targets[target]` is supposed to be like:
    #     {
    #        id: { generator: :autoinc },
    #        name: { generator: [:pattern, {template: 'CAIX«2h»'}] }
    #     }
    def produce name
      target =  name.to_class

      raise MomFail.new self, "DSL Error in `#{__callee__}': unknown entity to produce (#{name})" if target.nil?
      raise MomFail.new self, "DSL Error in `#{__callee__}': entity to produce (#{name}) does not respond to «columns»" unless target.respond_to?(:columns)

      puts target.to_s.rjust 40, '='
      puts reflections(target).inspect

      @targets[target] ||= target.columns.map do |c|
        # @name="id", @sql_type="INTEGER", @null=false, @limit=nil, @precision=nil, @scale=nil, @type=:integer, @default=nil, @primary=true, @coder=nil
        # @name="type", @sql_type="varchar(255)", @null=true, @limit=255, @precision=nil, @scale=nil, @type=:string, @default=nil, @primary=false, @coder=nil
        description = {}
        description[:generator] = case c.sql_type
                                  when 'INTEGER' then :autoinc
                                  when 'integer' then :counter
                                  when /\Avarchar\((\d{1,2})\)/ then :string
                                  when /\Avarchar\((\d{3,})\)/ then :loremipsum
                                  end
        description[:nullable] = c.null
        [c.name.to_sym, description]
      end.to_h
    end

    # FactoryGirl.define do
    #   factory :user do
    #     name 'Aleksei'
    #   end
    # end
    def code name
      defs = (produce name).inject([]) do |memo, (name, description)|
        next memo if description[:generator] == :autoinc
        memo << name
      end.join("#{$/}    ")

      # FIXME Change `ignore` to `transient` as the former is obsolete
      code = <<EOC
::FactoryGirl.define do
  factory :#{name} do
    transient do
      shallow false
    end
    #{defs}
  end
end
EOC
    end

    def instantiate name
      Sandbox.class_eval([
        %q(require 'factory_girl'),
        code(name),
        "object = ::FactoryGirl.create(:#{name})",
        "# binding.pry"
      ].join $/)
    end


  private
    def reflections target
      reflections = FactoryMom::MODEL_VISOR.reflections(target).first.last

      reflections.inject({}) do |memo, (name, r)|
        case r
        when ActiveRecord::Reflection::ThroughReflection
          # (memo[:association] ||= {})[name] = [r.options[:through]]
          # (memo[:after] ||= {})[name] = nil
        when ActiveRecord::Reflection::AssociationReflection
          case r.macro
          when :has_one
            symmetry = FactoryMom::MODEL_VISOR.reflections(name).first.last
            symmetry = symmetry[target.to_sym] || symmetry[target.to_sym.pluralize]
            if symmetry.nil?
              (memo[:association] ||= {})[name] = []
            else
              (memo[:after] ||= {})[name] = [r.name, [symmetry.name, symmetry.macro == :has_many ? [:self] : :self]]
            end
          when :has_many
            symmetry = FactoryMom::MODEL_VISOR.reflections(name).first.last[target.to_sym]
            # (memo[:after] ||= {})[name] = []
          end
        else
          raise MomFail.new self, "Kindergarten Error: unhandled reflection «#{r}». Consider to handle!"
        end
        memo
      end
    end
  end
end
