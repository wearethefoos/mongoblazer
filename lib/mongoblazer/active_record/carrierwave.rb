# module CarrierWave
#   class Uploader::Base
#     def __bson_dump__(io, key)
#       data = versions.merge({default: self.to_s})

#       io << Types::OBJECT_ID
#       io << key
#       io << NULL_BYTE
#       io << data
#     end
#   end
# end

module Mongoblazer
  module ActiveRecord
    module Carrierwave
      extend ActiveSupport::Concern

      module ClassMethods
        def mount_uploader(name, klass, options={})
          mongoblazer_init uploaders: name
          super
        end

        private

        def configure_mongoblazer_uploaders!
          mongoblazer_options[:uploaders].map do |uploader|
            <<-CODE
              def #{uploader}
                @#{uploader} ||= begin
                  klass = Class.new OpenStruct do
                    def to_s
                      default
                    end
                  end

                  klass.new(attributes['#{uploader}'])
                end
              end
            CODE
          end
        end
      end
    end
  end
end
