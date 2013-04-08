module Mongoblazer
  if defined? Rails::Railtie
    require 'rails'

    class Railtie < Rails::Railtie
      initializer 'mongoblazer.insert_into_active_record' do
        ActiveSupport.on_load :active_record do
          Mongoblazer::Railtie.insert
        end
      end

      rake_tasks do
        load "tasks/mongoblazer.rake"
      end
    end
  end

  class Railtie
    def self.insert
      if defined?(::ActiveRecord)
        ::ActiveRecord::Base.class_eval do
          include Mongoblazer::ActiveRecord
        end
      end
    end
  end
end
