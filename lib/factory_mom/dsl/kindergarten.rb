module FactoryMom
  class Kindergarten
    attr_reader :targets

    def initialize
      @targets = {}
      @suppressed = {}
      @mx = Mutex.new
      @current = nil
    end

    # Produces a skeleton for factory definition.
    # As soon as target is already defined, does nothing; it is safe
    #   to call this method whereever.
    # The resuting structure of `@targets[target]` is supposed to be like:
    #     {
    #        id: { generator: :autoinc },
    #        name: { generator: [:pattern, {template: 'CAIX«2h»'}] }
    #     }
    #
    def produce name, cache: false, **params
      target = name.to_class
      raise MomFail.new self, "FactoryMom Error: producers can not be nested #{name}"  unless @current.nil?
      return @targets[target] if cache && @targets[target]

      @mx.synchronize do
        raise MomFail.new self, "DSL Error in `#{__callee__}': unknown entity to produce (#{name})" if target.nil?
        raise MomFail.new self, "FactoryMom Error: refactoring objects in prohibited (#{name})"  unless @targets[target].nil?
        raise MomFail.new self, "DSL Error in `#{__callee__}': entity to produce (#{name}) does not respond to «reflections»" unless target.respond_to?(:reflections)
        raise MomFail.new self, "DSL Error in `#{__callee__}': entity to produce (#{name}) does not respond to «columns»" unless target.respond_to?(:columns)

        @targets[@current = target] = { delegates: [], columns: {}, handled: {}, suppressed: {}, params: params }

        # start with reflections
        @targets[@current][:reflections] = reflections(@current)

        # stack all traits to be delegated
        instance_eval(&Proc.new) if block_given?

        # reflection names and traits delegated to underlying `FactoryGirl`
        handled = @targets[@current][:reflections].values.map { |kv| kv.is_a?(Hash) && kv.first.first || nil }.compact | @targets[@current][:delegates].map(&:first)

        # proceed with columns left (not handled by reflections and delegates)
         @current.columns.inject(@targets[@current]) do |memo, c|
          if handled.any? { |h| /#{h}(?:_id)?/ =~ c.name.to_s }
            memo[:handled][c.name.to_sym] = c
          elsif @suppressed[@current].is_a?(Array) && @suppressed[@current].any? { |s| s =~ c.name.to_s }
            memo[:suppressed][c.name.to_sym] = c
          else
            # @name="id", @sql_type="INTEGER", @null=false, @limit=nil, @precision=nil, @scale=nil, @type=:integer, @default=nil, @primary=true, @coder=nil
            # @name="type", @sql_type="varchar(255)", @null=true, @limit=255, @precision=nil, @scale=nil, @type=:string, @default=nil, @primary=false, @coder=nil
            memo[:columns][c.name.to_sym] = {
              column: c,
              generator:  case c.sql_type
                          when 'INTEGER' then :autoinc
                          when 'integer' then :counter
                          when /\Avarchar\((\d+)\)/ then c.limit < 16 ? :string : :loremipsum
                          end,
              nullable: c.null
            }
          end
          memo
        end

        # binding.pry if @current == Post #Comment
        @targets[@current].tap { @current = nil }
      end
    end

    def code name, **params
      target = produce name, **params, cache: true
 #      { :delegates=> [[:trait, [:short], #<Proc:0x0000000260c5c8@/home/am/Proyectos/Kantox/factory_mom/spec/dsl_spec.rb:15>]],
 #        :columns=>
 #          {:id=> {:column=>..., :generator=>:autoinc, :nullable=>false},
 #           :text=> {:column=>..., :generator=>:loremipsum, :nullable=>true}},
 #        :handled=> {:author_id=>..., :post_id=>...},
 #        :suppressed=> {},
 #        :params=> {:aliases=> [:комментарий]},
 #        :reflections=>
 #          {:after=> {:post=> [:post, :comment, [:this]]},
 #           :associations=> {:author=> [:writer]},
 #           :through=> {:owner=> [:user, :post, :this]}}}
      factory_params = target[:params].to_double_splat
      factory_title = factory_params.empty? ? name : [name, factory_params].join(', ')

      associations = target[:reflections][:associations].map do |k, v|
        "\t\t#{k} " << v.map(&:inspect).join(', ')
      end.join $/
      associations = associations.empty? ? "\t\t# this object has no associations" : "\t\t# associations#{$/}#{associations}"

      columns = target[:columns].reject do |_, v|
        v[:generator] == :autoinc
      end.map do |k, v| # FIXME add length for strings
        "\t\t#{k} { FactoryMom::DSL::Generators.#{v[:generator]} }"
      end.join $/
      columns = columns.empty? ? "\t\t# this object has no raw columns" : "\t\t# raw columns#{$/}#{columns}"

      delegates = target[:delegates].map { |el| "#{el.last.source.rstrip.gsub(/ {4}/, %Q{\t}).gsub(/(?<=\t) {2}/, '')}" }.join $/
      delegates = delegates.empty? ? "\t\t# this object has no delegates" : "\t\t# delegated to factory#{$/}#{delegates}"

      code = <<EOC
::FactoryGirl.define do
\tfactory :#{factory_title} do
\t\ttransient do
\t\t\tshallow false
\t\tend
#{delegates}
#{associations}
#{columns}
# FIXME AFTER THROUGH
\tend
end
EOC
    end


  protected
    # We will delegate to underlying FactoryGirl instance every not known trait
    def method_missing name, *args
      raise MomFail.new self, "DSL Error: inconsistent call to `#{name}'" unless @targets[@current][:delegates].is_a? Array
      @targets[@current][:delegates] << (block_given? ? [name, args, Proc.new] : [name, args])
    end

    # trait to suppress creating of fields with exotic names, containing indeed foreign keys
    def suppress name
      name = /#{name}/ unless name.is_a? Regexp
      (@suppressed[@current] ||= []) << name
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
          (memo[:through] ||= {})[r.options[:as] || r.name] = [r.options[:class_name] || r.name.singularize, r.options[:through].singularize, r.collection? ? [:this] : :this]
        when ActiveRecord::Reflection::AssociationReflection
          symmetry = FactoryMom::MODEL_VISOR.reflections(name).first.last
          symmetry = symmetry[target.to_sym] || symmetry[target.to_sym.pluralize]
          key = case r.macro
          when :has_one then [:associations, :after]
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
