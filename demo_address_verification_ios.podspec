Pod::Spec.new do |s|
  s.name             = 'demo_address_verification_ios'
  s.version          = '1.1.2'
  s.summary          = 'A lightweight iOS module for verifying user addresses.'
  s.description      = <<-DESC
    A Swift-based module designed to verify and validate address details on iOS, intended for integration with native or React Native apps.
  DESC
  s.homepage         = 'https://github.com/EQua-Dev/demo_address_verification-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'EQua Dev Team' => 'team@equa.dev' }
  s.source           = { :git => 'https://github.com/EQua-Dev/demo_address_verification-ios.git', :tag => s.version.to_s }

  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'
  s.source_files     = 'Sources/**/*.{swift,h,m}'
  s.frameworks       = 'Foundation', 'UIKit'
end
