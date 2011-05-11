#-*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name = "uswitch-fog"
  s.version = "1"
  s.authors = ["Noah Cantor"]
  s.email = "noah.cantor@forward.co.uk"
  s.homepage = "http://www.forward.co.uk"
  s.summary = "What do you call a nun on a bike? VIRGIN MOBILE!"
  s.platform = Gem::Platform::RUBY
  s.files = %w(lib).map {|d| Dir.glob("#{d}/**/*")}.flatten << "uswitch-fog.gemspec"
  s.require_path = "lib"
  s.has_rdoc = false
  s.add_dependency('activesupport', '>= 3.0.0')
  s.add_dependency('fog')
end

