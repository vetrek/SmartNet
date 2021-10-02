Pod::Spec.new do |s|
  s.name = 'SmartNet'
  s.version = '0.0.6'
  s.license = 'MIT'
  s.summary = 'Smart and easy HTTP Networking library in Swift'
  s.homepage = 'https://github.com/Valerio69/SmartNet'
  s.authors = 'Valerio69'
  s.source = { :git => 'https://github.com/Valerio69/SmartNet.git', :tag => s.version }
  # s.documentation_url = ''

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  # s.tvos.deployment_target = '13.0'
  # s.watchos.deployment_target = '6.0'

  s.swift_versions = ['5.1', '5.2', '5.3']

  s.source_files = 'Source/**/*.swift'
end
