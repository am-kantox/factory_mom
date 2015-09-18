module FactoryMom
  class Kindergarten
    # attribute reader for targets
    attr_reader :targets

    # constructor, preparing targets and suppressed hashes
    def initialize visor
      @visor = visor
      @targets = {}
      @suppressed = {}
      @mx = Mutex.new
      @current = nil
    end

    # Produces a skeleton for factory definition.
    # As soon as target is already defined, refactors it (when `refactor` param
    #   is set to `true` or throws an `Execption` otherwise); it is safe
    #   to call this method whereever.
    # Claimed to be thread-safe.
    # The resuting structure of `@targets[target]` is supposed to be like:
    #
    #     {
    #       :delegates=>[],
    #       :columns=>{
    #         :id=>{
    #           :column=>#<ActiveRecord::ConnectionAdapters::SQLiteColumn...>,
    #           :generator=>:autoinc,
    #           :nullable=>false},
    #         :parent_id=>{
    #           :column=>#<ActiveRecord::ConnectionAdapters::SQLiteColumn...>,
    #           :generator=>:counter,
    #           :nullable=>true},
    #         :name=>{
    #           :column=>#<ActiveRecord::ConnectionAdapters::SQLiteColumn...>,
    #           :generator=>:loremipsum,
    #           :nullable=>false}},
    #       :handled=>{},
    #       :suppressed=>{
    #         :type=>#<ActiveRecord::ConnectionAdapters::SQLiteColumn...>},
    #       :params=>{},
    #       :reflections=>{
    #         :after=>{:posts=>[:post, :user, :this]}}}
    # @param [String|Symbol|Class] name the name of class to produce
    # @param [TrueClass|FalseClass] cache use caching or recreate?
    # @param [TrueClass|FalseClass] refactor do refactor existing factory or throw an exception?
    # @param [Hash] params the additional parameters to be passed directly to `FactoryGirl`
    #
    def produce name, cache: false, refactor: true, **params
      target = name.to_class
      raise MomFail.new self, "FactoryMom Error: producers can not be nested (#{name.inspect})"  unless @current.nil?
      return @targets[target] if cache && @targets[target]

      @mx.synchronize do
        raise MomFail.new self, "DSL Error in `#{__callee__}': unknown entity to produce (#{name})" if target.nil?
        raise MomFail.new self, "FactoryMom Error: refactoring objects in prohibited (:#{target})"  unless refactor || @targets[target].nil?
        raise MomFail.new self, "DSL Error in `#{__callee__}': entity to produce (#{target}) does not respond to «reflections»" unless target.respond_to?(:reflections)
        raise MomFail.new self, "DSL Error in `#{__callee__}': entity to produce (#{target}) does not respond to «columns»" unless target.respond_to?(:columns)

        @targets[@current = target] = { delegates: [], columns: {}, handled: {}, suppressed: {}, params: params }

        # start with reflections
        @targets[@current][:reflections] = reflections(@current)

        # stack all traits to be delegated
        instance_eval(&Proc.new) if block_given?

        # reflection names and traits delegated to underlying `FactoryGirl`
        handled = @targets[@current][:reflections].values.map { |kv| kv.is_a?(Hash) && kv.first.first || nil }.compact | @targets[@current][:delegates].map(&:first)

        # proceed with columns left (not handled by reflections and delegates)
         @current.columns.inject(@targets[@current]) do |memo, c|
          if handled.any? { |h| /#{h}(?:_id)?/ =~ c.name.to_s } # reference / fk
            memo[:handled][c.name.to_sym] = c
          elsif /_id$/ =~ c.name.to_s                           # suspicious idx
            memo[:suppressed][c.name.to_sym] = c
          elsif c.name.to_s == 'type'                           # rails type field
            memo[:suppressed][c.name.to_sym] = c
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
    alias_method :factory, :produce

    # Produces a code piece for `FactoryGirl` using raw hash prepared by `produce`.
    #
    # Hash as prepared by produce looks like:
    #
    #      { :delegates=> [[:trait, [:short], #<Proc:...>]],
    #        :columns=>
    #          {:id=> {:column=>..., :generator=>:autoinc, :nullable=>false},
    #           :text=> {:column=>..., :generator=>:loremipsum, :nullable=>true}},
    #        :handled=> {:author_id=>..., :post_id=>...},
    #        :suppressed=> {},
    #        :params=> {:aliases=> [:комментарий]},
    #        :reflections=>
    #          {:after=> {:post=> [:post, :comments, [:this]]},
    #           :associations=> {:author=> [:writer]},
    #           :through=> {:owner=> [:user, :post, :this]}}}
    #
    # @param [String|Symbol|Class] name the name of class to produce code for
    # @param [TrueClass|FalseClass] snippet when `false`, will surround code with `FactoryGirl` calls
    # @param [Hash] params the additional parameters to be passed directly to `FactoryGirl`
    def factory_code name, snippet: true, **params
      target = produce name, **params, cache: true
      factory_params = target[:params].merge(target[:reflections][:parent] ? { parent: target[:reflections][:parent], class: name.to_sym } : {}).to_double_splat
      factory_title = factory_params.empty? ? name : [name, factory_params].join(', ')

      associations = target[:reflections][:associations].map do |k, v|
        "\t\tassociation :#{v[:association]}, factory: :#{v[:class]}, strategy: :create"
      end.join($/) if target[:reflections][:associations]
      associations = associations.blank? ? "\t\t# this object has no associations" : "\t\t# associations#{$/}#{associations}"

      columns = target[:columns].reject do |_, v|
        v[:generator] == :autoinc
      end.map do |k, v| # FIXME add length for strings
        "\t\t#{k} { FactoryMom::DSL::Generators.#{v[:generator]} }"
      end.join $/
      columns = columns.empty? ? "\t\t# this object has no raw columns" : "\t\t# raw columns#{$/}#{columns}"

      delegates = target[:delegates].map { |el| "#{el.last.source.rstrip.gsub(/ {4}/, %Q{\t}).gsub(/(?<=\t) {2}/, '')}" }.join $/
      delegates = delegates.empty? ? "\t\t# this object has no delegates" : "\t\t# delegated to factory#{$/}#{delegates}"

      #after(:create, :build, :stub) do |this|
      #  this.post = create :post, comments: [this]
      #end
      #{ :post=>
      #   { :association=>:post,
      #     :class=>:post,
      #     :collection=>false,
      #     :inverse=>{:name=>:comment, :association=>:comments, :class=>:comment, :collection=>true, :inverse=>:post}},
      # :author=>{:association=>:author, :class=>:writer, :collection=>false, :inverse=>:comment}}
      after = target[:reflections][:after].inject([]) do |memo, (k, v)|
        begin
          inverse_code = v[:inverse].is_a?(Hash) ? "#{v[:inverse][:association]}: #{v[:inverse][:collection] ? '[this]' : 'this'}" : "#{v[:inverse]}: this"
          create_code = "::FactoryGirl.♯(:#{v[:class]}, #{inverse_code})"
          create_code = (v[:collection] ? "[ #{create_code}, " : '') + create_code + (v[:collection] ? "]" : '')
          memo << "this.#{k} = #{create_code} if this.#{k}.blank?"
        rescue => err
          binding.pry
        end
      end.join("#{$/}\t\t\t") if target[:reflections][:after]
      # FIXME BUILD AFTER BUILD ETC
      after = if after.blank?
                "\t\t# this object does not use after hook"
              else
                "\t\t# after hook#{$/}" <<
                  %w(create build stub).map do |step|
                    "\t\tafter(:#{step}) do |this|#{$/}\t\t\t#{after.gsub('♯', step)}#{$/}\t\tend"
                  end.join($/)
              end

heredoc = <<EOC
#{snippet ? nil : '::FactoryGirl.define do'}
\tfactory :#{factory_title} do
\t\ttransient do
\t\t\tshallow false
\t\tend
#{delegates}
#{associations}
#{columns}
#{after}
# FIXME THROUGH
\tend
#{snippet ? nil : 'end'}
EOC
    end

    # Produces a code for all the factories.
    # If a codeblock is given, the string or array of strings is expected
    #   to be embedded into generated code
    # @param [TrueClass|FalseClass] as_string specifies whether the result
    #  should be returned as string or as an array of strings
    # @param [TrueClass|FalseClass] cache specifies whether the result should
    #  be cached between subsequent executions
    # @return [String|Array] the code generated
    def factories_code as_string: false, cache: true
      unless cache && @factories_code && !block_given?
        to_embed = block_given? ? [yield].flatten : nil

        @factories_code = [
          %q(require 'factory_girl_rails'),
          '::FactoryGirl.define do',
          *targets.keys.map { |k| factory_code k.to_sym, snippet: true },
          to_embed,
          'end',
        ].compact
      end

      as_string ? @factories_code.join($/) : @factories_code
    end

  protected
    # We will delegate to underlying FactoryGirl instance every not known trait
    def method_missing name, *args
      raise MomFail.new self, "DSL Error: inconsistent call to `#{name}'" unless @targets[@current] && @targets[@current][:delegates].is_a?(Array)
      @targets[@current][:delegates] << (block_given? ? [name, args, Proc.new] : [name, args])
    end

    # trait to suppress creating of fields with exotic names, containing indeed foreign keys
    def suppress name
      name = /#{name}/ unless name.is_a? Regexp
      (@suppressed[@current] ||= []) << name
    end

  private
    # FIXME Handle lambdas scopes? :as?
    def reflection_to_attrs name, r, target
      attrs = (%i(association class collection inverse).zip [
        (r.name || name).to_sym,
        (r.options[:class_name] || name).singularize.to_sym, # FIXME maybe singularize only if !collection?
        r.collection?,
        (r.options[:inverse_of] || target).to_sym
      ]).to_h

      inverse = @visor.reflections(attrs[:class]).values.first
      if inverse && inverse = inverse[attrs[:inverse]] || inverse[target.to_sym.pluralize] # we do not know yet, whether it is a collection or not
        attrs[:inverse] = (%i(name association class collection inverse).zip [
          attrs[:inverse],
          (inverse.name || attrs[:inverse]).to_sym,
          (inverse.options[:class_name] || attrs[:inverse]).singularize.to_sym,
          inverse.collection?,
          (inverse.options[:inverse_of] || r.name || name).to_sym
        ]).to_h
      end

      # FIXME Assure that attrs[:inverse][:inverse] == name
      attrs
    end

    def reflections target
      reflections = @visor.reflections(target)[target]

      reflections.inject({}) do |memo, (name, r)|
        if r.active_record != target
          memo[:parent] = r.active_record.to_sym
          next memo
        end # FIXME SHOULD I GO NEXT HERE? SEEMS YES; BUT ...

        attrs = reflection_to_attrs name, r, target

        case r
        when ActiveRecord::Reflection::ThroughReflection
          (memo[:through] ||= {})[attrs[:association]] = attrs
        when ActiveRecord::Reflection::AssociationReflection
          (memo[attrs[:inverse].is_a?(Hash) ? :after : :associations] ||= {})[attrs[:association]] = attrs
        else
          raise MomFail.new self, "Kindergarten Error: unhandled reflection «#{r}». Consider to handle!"
        end
        memo
      end #.tap { |r| binding.pry }
    end
  end
end
