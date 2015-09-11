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
      def counter owner: :orphans, length: 2, base: 10
        @counters[owner] = (@counters[owner] || 0).next
        @counters[owner].to_s(base).upcase.rjust(length, '0').tap do |val|
          raise MomFail.new self, "Generator Error: counter for «#{owner}» is out of bounds" if val.length != length
        end
      end
      module_function :string, :counter
    end
  end
end
