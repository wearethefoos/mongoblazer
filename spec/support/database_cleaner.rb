require 'database_cleaner'

RSpec.configure do |config|

  config.before :suite do
    DatabaseCleaner.orm =      :mongoid
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean_with :truncation
  end

  config.before :each do
    DatabaseCleaner.clean
    DatabaseCleaner.start
  end

  config.after :each do
    DatabaseCleaner.clean
  end

end
