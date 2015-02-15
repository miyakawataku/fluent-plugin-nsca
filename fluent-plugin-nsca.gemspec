# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-nsca"
  spec.version       = '0.0.2'
  spec.authors       = ["MIYAKAWA Taku"]
  spec.email         = ["miyakawa.taku@gmail.com"]
  spec.description   = %q{Fluentd output plugin to send service checks to a Nagios NSCA daemon}
  spec.summary       = %q{Fluentd output plugin to send service checks to a Nagios NSCA daemon}
  spec.homepage      = "https://github.com/miyakawataku/fluent-plugin-nsca/"
  spec.license       = "Apache License, v2.0"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rr"
  spec.add_runtime_dependency "send_nsca", "0.5.0"
  spec.add_runtime_dependency "fluentd"
end
