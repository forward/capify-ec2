# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "capify-ec2/version"

Gem::Specification.new do |s|
  s.name        = "capify-ec2"
  s.version     = Capify::Ec2::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Noah Cantor", "Siddharth Dawara", "Jon Spalding", "Ryan Conway"]
  s.email       = ["capify-ec2@forwardtechnology.co.uk"]
  s.homepage    = "http://github.com/forward/capify-ec2"
  s.summary     = %q{Capify-EC2 is used to generate Capistrano namespaces and tasks from Amazon EC2 instance tags, dynamically building the list of servers to be deployed to.}
  s.description = %q{Capify-EC2 is used to generate Capistrano namespaces and tasks from Amazon EC2 instance tags, dynamically building the list of servers to be deployed to.}

  s.rubyforge_project = "capify-ec2"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.add_dependency('fog', '=1.10.0')
  s.add_dependency('colored', '=1.2')
  s.add_dependency('capistrano', '~> 2.14')
end
