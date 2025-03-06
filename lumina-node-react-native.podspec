require "json"
package = JSON.parse(File.read(File.join(__dir__, "package.json")))
folly_compiler_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1 -Wno-comma -Wno-shorten-64-to-32'

Pod::Spec.new do |s|
  s.name         = "lumina-node-react-native"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]
  s.platform     = :ios, '13.0'
  s.source       = { :git => "https://github.com/leapwallet/lumina-node-react-native.git", :tag => "#{s.version}" }
  s.source_files = "ios/**/*.{h,m,mm,cpp,swift}"
  s.private_header_files = "ios/generated/**/*.h"
  s.preserve_paths = "ios/**/*.h"

  s.frameworks = [
    'SystemConfiguration',
    'Network',
    'CoreServices',
    'Foundation',
    'Security'
  ]

  s.libraries = ['c++']

  s.ios.frameworks = [
    'NetworkExtension'
  ]


  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_INCLUDE_PATHS' => '$(PODS_TARGET_SRCROOT)/ios',
    'FRAMEWORK_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/ios/Frameworks/',
    'OTHER_LDFLAGS' => '-ObjC',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/ios/Frameworks/lumina.xcframework/**/Headers"',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'x86_64',
    'VALID_ARCHS' => 'arm64',
    'SUPPORTS_MACCATALYST' => 'NO',
    'SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD' => 'NO'
  }


  s.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'x86_64',
    'VALID_ARCHS' => 'arm64'
  }


  s.static_framework = true
  s.vendored_frameworks = ["ios/Frameworks/lumina.xcframework"]

  # Use install_modules_dependencies helper to install the dependencies if React Native version >=0.71.0.
  if respond_to?(:install_modules_dependencies, true)
    install_modules_dependencies(s)
  else
    s.dependency "React-Core"

    # New Architecture configurations
    if ENV['RCT_NEW_ARCH_ENABLED'] == '1'
      s.compiler_flags = folly_compiler_flags + " -DRCT_NEW_ARCH_ENABLED=1"

      s.pod_target_xcconfig.merge!({
        'HEADER_SEARCH_PATHS' => '"$(PODS_ROOT)/boost"',
        'OTHER_CPLUSPLUSFLAGS' => '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1',
        'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17'
      })

      s.dependency "React-Codegen"
      s.dependency "RCT-Folly"
      s.dependency "RCTRequired"
      s.dependency "RCTTypeSafety"
      s.dependency "ReactCommon/turbomodule/core"
    end
  end
end
