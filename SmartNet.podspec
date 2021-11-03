Pod::Spec.new do |s|
  s.name      = 'SmartNet'
  s.version   = '0.1.0'
  s.summary   = 'Smart and easy HTTP Networking library in Swift'
  s.homepage  = 'https://github.com/Valerio69/SmartNet'
  s.license   = { :type => 'MIT', :file => 'LICENSE' }
  s.author   = { 'Valerio Sebastianelli' => 'valerio.alsebas@gmail.com' } 
  s.source    = { :git => 'https://github.com/Valerio69/SmartNet.git', :tag => s.version }
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.swift_versions = ['5.1', '5.2', '5.3']
  s.source_files = 'Source/**/*.swift'
end
