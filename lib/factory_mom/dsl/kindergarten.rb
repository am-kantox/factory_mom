require 'factory_girl'

module FactoryMom
  class Kindergarten
    @targets = {}
    def produce name
      target =  case name
                when Symbol, String then name.to_class
                when Class then name
                else nil
                end
      raise MomFail.new self, "DSL Error in `#{__callee__}': unknown entity to produce (#{name})." if target.nil?

      # FactoryGirl.define do
      #   factory :user do
      #     name 'Aleksei'
      #   end
      # end
      defs = target.columns.inject([]) do |memo, c|
        memo << c.name
      end.join("#{$/}  ")

      code = <<EOC
FactoryGirl.define do
  #{defs}
end
EOC

    end
  end
end
