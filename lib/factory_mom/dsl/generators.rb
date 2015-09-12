module FactoryMom
  module DSL
    module Generators
      @strings = []
      @counters = {}

      def string length: 16, spaces: true, strip: true, utf8: true
        samples = (utf8 ? ('א'..'ת') : ('a'..'z')).to_a
        λ = lambda do |samples, i| samples.sample end
          # content
        begin
          content = length.times.map(&λ.curry[samples]).join
          content[(2..length - 2).to_a.sample] = ' ' if spaces && length > 3
          content.gsub!(/\A.|.\z/, ' ') unless strip
        end while @strings.include? content
        @strings << content
        content
      end

      # @todo Accepting `base` param on every call leads to potential problem
      #       with overriding it during a long run. This would lead to uncatched
      #       duplicates. It left this way because nobosy is intended to call
      #       these methods outside of factories, where resetting base is not_to
      #       probable. Take care of this when calling it from everywhere else.
      # @NoWarrantyDisclamer
      def generic_counter owner: :orphans, length: 2, base: 10
        @counters[owner] = (@counters[owner] || 0).next
        @counters[owner].to_s(base).upcase.rjust(length, '0').tap do |val|
          raise MomFail.new self, "Generator Error: #{caller.first[/(?<=`).*?(?=')/]} for «#{owner}» is out of bounds" if val.length != length
        end
      end

      def counter owner: :orphans, length: 2, base: 10
        generic_counter owner: owner, length: length, base: base
      end

      # @todo Make template not mandatory param if owner was already specified
      def pattern owner: :orphans, template: '😎«3d»'
        opening, length, base, closing = template.match(/\A(.*?)[\p{Ps}\p{Pi}](\d+)([dDhHaA]?)[\p{Pe}\p{Pf}](.*?)\z/).captures
        base =  case base
                when 'd', 'D' then 10
                when 'h', 'H' then 16
                when 'a', 'A' then 36
                else 10
                end
        "#{opening}#{generic_counter owner: owner, length: (length || 2).to_i, base: base}#{closing}"
      end

      module_function :generic_counter
      module_function :string, :counter, :pattern
    end
  end
end
