#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint nrf_mesh_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'nrf_mesh_flutter'
  s.version          = '3.8.0'
  s.summary          = 'Flutter plugin for Bluetooth Mesh using Nordic nRF Mesh libraries'
  s.description      = <<-DESC
Flutter plugin for Bluetooth Mesh using Nordic nRF Mesh libraries.
Supports device provisioning, network management, and mesh message communication.
                       DESC
  s.homepage         = 'https://github.com/platojobs/nrf_mesh_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'PlatoJobs' => 'platojobs@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'nRFMeshProvision', '~> 4.8.0'
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
