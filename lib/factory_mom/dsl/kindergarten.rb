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
        if r.active_record != target
          memo[:parent] = r.active_record.to_sym
          next memo
        end

        case r
        when ActiveRecord::Reflection::ThroughReflection
          # (memo[:association] ||= {})[name] = [r.options[:through]]
          # (memo[:after] ||= {})[name] = nil
        when ActiveRecord::Reflection::AssociationReflection
          symmetry = FactoryMom::MODEL_VISOR.reflections(name).first.last
          symmetry = symmetry[target.to_sym] || symmetry[target.to_sym.pluralize]
          key = case r.macro
                when :has_one then [:association, :after]
                when :has_many then [:after, :after]
                end
          instantiatable = r.options[:class_name] || r.name.singularize
          if symmetry.nil?
            (memo[key.first] ||= {})[r.options[:as] || r.name] = [instantiatable]
          else
            symmetry_instantiatable = symmetry.options[:class_name] || symmetry.name.singularize
            (memo[key.last] ||= {})[r.options[:as] || r.name] = [instantiatable, symmetry_instantiatable, symmetry.collection? ? [:this] : :this]
          end
        else
          raise MomFail.new self, "Kindergarten Error: unhandled reflection «#{r}». Consider to handle!"
        end
        memo
      end
    end
  end
end
