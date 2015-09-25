module FactoryMom
  module Selfcare
    # NB Not thread safe!!! See ugly `@capturing`.
    class ActiveRecordBaseChecker
      attr_reader :result, :active_record_errors

      def initialize handler = nil
        @error_reporter = lambda do |receiver, error|
                            term_cols = $stdin.winsize.last rescue 80
                            handler.call(receiver, error) if Proc === handler
                            ((@active_record_errors ||= {})[receiver] ||= []) << error
                            puts "—⇓—[ #{receiver.inspect} ]".ljust term_cols, '—'
                            print ' '
                            puts error.respond_to?(:message) ? error.message : error.inspect
                            puts '—⇑—'.ljust term_cols, '—'
                          end
      end

      def with_error_capturing
        raise "Erroneous call to #{__callee__}. No codeblock given." unless block_given?
        begin
          start_capturing &@error_reporter
          @result = Proc.new.call
        ensure
          stop_capturing
        end
      end

      def self.with_error_capturing error_reporter = nil
        raise "Erroneous call to #{__callee__}. No codeblock given." unless block_given?
        cb = Proc.new # to pass to closure
        ActiveRecordBaseChecker.new(error_reporter).tap do |arbc|
          arbc.with_error_capturing &cb
        end
      end

    private
      def start_capturing
        raise "Internal: #{__callee__} expects to receive a block!" unless block_given?
        raise "Internal: erroneous subsequent chaining ActiveRecord::Base." if ::ActiveRecord::Base.instance_methods.include? :save_with_error_capture

        block_given = Proc.new
        ::ActiveRecord::Base.send(:define_method, :save_with_error_capture) do |*args|
          begin
            save_without_error_capture(*args)
          rescue => e
            block_given.call(self, e) if block_given
          end
        end
        ::ActiveRecord::Base.send :alias_method, :save_without_error_capture, :save
        ::ActiveRecord::Base.send :alias_method, :save, :save_with_error_capture

        ::ActiveRecord::Base.send(:define_method, :save_bang_with_error_capture) do |*args|
          begin
            save_bang_without_error_capture(*args)
          rescue => e
            block_given.call(self, e) if block_given
            raise e
          end
        end
        ::ActiveRecord::Base.send :alias_method, :save_bang_without_error_capture, :save!
        ::ActiveRecord::Base.send :alias_method, :save!, :save_bang_with_error_capture
      end

      def stop_capturing
        raise "Internal: erroneous unmatched unchaining ActiveRecord::Base." unless ::ActiveRecord::Base.instance_methods.include?(:save_without_error_capture)

        ::ActiveRecord::Base.send :alias_method, :save!, :save_bang_without_error_capture
        ::ActiveRecord::Base.send :undef_method, :save_bang_with_error_capture
        ::ActiveRecord::Base.send :undef_method, :save_bang_without_error_capture

        ::ActiveRecord::Base.send :alias_method, :save, :save_without_error_capture
        ::ActiveRecord::Base.send :undef_method, :save_with_error_capture
        ::ActiveRecord::Base.send :undef_method, :save_without_error_capture
      end
    end
  end
end
