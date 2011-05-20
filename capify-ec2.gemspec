#-*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name = "capify-ec2"
  s.version = "1.1"
  s.authors = ["Noah Cantor"]
  s.email = "noah.cantor@forward.co.uk"
  s.homepage = "http://www.forward.co.uk"
  s.summary = "Grabs roles from ec2's tags and autogenerates capistrano tasks"
  s.platform = Gem::Platform::RUBY
  s.files = %w(lib).map {|d| Dir.glob("#{d}/**/*")}.flatten << "capify-ec2.gemspec"
  s.require_path = "lib"
  s.has_rdoc = false
  s.add_dependency('activesupport', '>= 3.0.0')
  s.add_dependency('fog')
end

