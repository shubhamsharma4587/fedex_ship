require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir  = File.expand_path('../../vcr', __FILE__)
  c.hook_into :webmock
end

RSpec.configure do |c|
  c.include FedexShip::Helpers
  c.around(:each, :vcr) do |example|
    name = underscorize(example.metadata[:full_description].split(/\s+/, 2).join("/")).gsub(/[^\w\/]+/, "_")
    VCR.use_cassette(name) { example.call }
  end
end
