Pod::Spec.new do |s|
  s.name = 'MpvPlayer'
  s.version = '0.2.1'
  s.summary = 'Standalone Expo libmpv player derived from Streamyfin with Lunarr hardening'
  s.description = 'Expo native module using MPVKit/libmpv with AVSampleBufferDisplayLayer and Picture in Picture support.'
  s.author = 'Streamyfin contributors and downstream contributors'
  s.homepage = 'https://github.com/neckaros/expo-libmpv-player'
  s.license = { :type => 'MPL-2.0', :file => '../LICENSE.txt' }
  s.platforms = { :ios => '15.1', :tvos => '15.1' }
  s.source = { :git => 'https://github.com/neckaros/expo-libmpv-player.git', :tag => s.version.to_s }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.dependency 'MPVKit'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule'
  }
  s.source_files = '**/*.{h,m,mm,swift,hpp,cpp}'
end
