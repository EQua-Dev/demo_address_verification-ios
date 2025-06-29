//
//  react-native.config.js
//  AddressVerification
//
//  Created by Richard Uzor on 29/06/2025.
//

// demo_address_verification_ios/react-native.config.js
module.exports = {
  dependency: {
    platforms: {
      ios: {
        podspecPath: './demo_address_verification_ios.podspec', // Relative to package root
        sharedLibraries: ['UIKit', 'Foundation'],
        scriptPhases: [] // Add any custom build scripts if needed
      },
      android: null // Disable Android if not needed
    }
  }
};
