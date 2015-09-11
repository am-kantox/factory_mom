module FactoryMom
  module DSL
    module Generators
      def string length: 16, spaces: true, strip: true, utf8: true
        return code unless length > 4

        samples = (utf8 ? ('א'..'ת') : ('a'..'z')).to_a
        λ = lambda do |samples, i| samples.sample end
        content = length.times.map(&λ.curry[samples]).join
        content[(2..length - 2).to_a.sample] = ' ' if spaces
        content.gsub!(/\A.|.\z/, ' ') unless strip

        content
      end
      module_function :string
    end
  end
end
