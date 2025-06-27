Pod::Spec.new do |s|
  s.name             = 'demo_address_verification_ios'
  s.version          = '1.1.4'
  s.summary          = 'iOS address verification and validation module for React Native applications'
  
  s.description      = <<-DESC
                       A comprehensive Swift-based module for verifying and validating user addresses on iOS.
                       This module provides seamless integration with React Native applications, offering
                       address validation, formatting, and verification capabilities. Features include
                       real-time address validation, postal code verification, and integration with
                       mapping services for accurate address resolution.
                       DESC

  s.homepage         = 'https://github.com/EQua-Dev/demo_address_verification-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'EQua Dev Team' => 'team@equa.dev' }
  s.source           = { :git => 'https://github.com/EQua-Dev/demo_address_verification-ios.git', :tag => s.version.to_s }
  
  s.ios.deployment_target = '15.0'
  s.swift_version    = '5.0'
  
  s.source_files     = 'Sources/**/*.{swift,h,m}'
  s.public_header_files = 'Sources/**/*.h'
  
  s.frameworks       = 'Foundation', 'UIKit'
  
  # Add any dependencies if needed
  # s.dependency 'React-Core'
  
  # Exclude files if necessary
  # s.exclude_files = 'Sources/Exclude'
  
  # Add resources if you have any
  # s.resource_bundles = {
  #   'demo_address_verification_ios' => ['Sources/**/*.{xib,storyboard,xcassets}']
  # }
end