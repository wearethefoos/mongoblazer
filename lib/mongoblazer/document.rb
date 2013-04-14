module Mongoblazer
  module Document
    extend ActiveSupport::Concern
    include Mongoid::Document

    included do
      field :ar_id, type: String

      index ar_id: 1

      def is_mongoblazed?
        true
      end

      def ar_object
        @ar_object ||= self.class.name.sub(/Blazer$/, '').constantize.find(ar_id)
      end

      def method_missing(method_sym, *arguments, &block)
        begin
          super
        rescue NoMethodError
          Rails.logger.debug "MONGOBLAZER DEBUG: #{self.class.name} access to unblazed method:
            #{method_sym} with args:
            #{arguments.inspect}
            for record with id: #{id}"
          if ar_object.respond_to? method_sym
            ar_object.send method_sym
          end
        end
      end
    end
  end
end
