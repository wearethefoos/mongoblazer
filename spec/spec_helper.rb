ENV["RACK_ENV"]  ||= 'test'
ENV['RAILS_ENV'] ||= 'test'

require 'bundler'
Bundler.require

Dir[File.expand_path("../../lib/**/*.rb", __FILE__)].each {|f| require f}
Dir[File.expand_path("../support/**/*.rb", __FILE__)].each {|f| require f}

RSpec.configure do |config|
  config.color_enabled = true
  config.tty = true
  config.formatter = :progress
end
