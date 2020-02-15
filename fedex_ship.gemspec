# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'fedex_ship/version'

Gem::Specification.new do |s|
  s.name        = 'fedex_ship'
  s.version     = FedexShip::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Jazmin Schroeder','Shubham Sharma']
  s.email       = ['shubhamsharma4587@gmail.com']
  s.homepage    = 'https://github.com/shubhamsharma4587/fedex_ship'
  s.summary     = %q{Fedex Web Services}
  s.description = %q{Provides an interface to Upgraded Fedex Web Services}

  s.add_dependency 'httparty',            '>= 0.13.7'
  s.add_dependency 'nokogiri',            '>= 1.5.6'

  s.add_development_dependency "rspec",   '~> 3.1'
  s.add_development_dependency 'vcr',     '~> 2.0'
  s.add_development_dependency 'webmock', '~> 1.8.0'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'rake'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']
end
