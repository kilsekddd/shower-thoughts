#
# Local-path podspec that ships the C-ABI wrapper around whisper.cpp into the
# Runner app. The Podfile references this via:
#
#   pod 'ShowerThoughtsWhisper', :path => './whisper'
#
# It compiles wrapper.cpp (which exposes spike_transcribe_wav for Dart FFI)
# and vendors the prebuilt whisper.xcframework sitting next to this file.
#
Pod::Spec.new do |s|
  s.name             = 'ShowerThoughtsWhisper'
  s.version          = '0.1.0'
  s.summary          = 'C-ABI wrapper around whisper.cpp for the shower-thoughts Flutter app.'
  s.description      = <<-DESC
    Exposes a single C entry point (spike_transcribe_wav) that Dart FFI binds
    to. The actual whisper.cpp implementation comes from the prebuilt
    whisper.xcframework vendored alongside this podspec.
  DESC
  s.homepage         = 'https://github.com/kilsekddd/shower-thoughts'
  s.license          = { :type => 'MIT' }
  s.author           = { 'shower-thoughts' => 'noreply@local' }
  s.source           = { :path => '.' }

  s.ios.deployment_target = '16.0'

  # Dart FFI only needs the wrapper symbol present in the linked binary; no
  # C/ObjC consumer in this project imports wrapper.h. Keeping the header
  # private avoids Xcode 16+ flagging the auto-generated umbrella's
  # `#import "wrapper.h"` as a double-quoted-include-in-framework-header
  # error.
  s.source_files = 'wrapper.cpp', 'wrapper.h'
  s.private_header_files = 'wrapper.h'

  # Prebuilt whisper.cpp framework (ios-arm64 + ios-arm64_x86_64-simulator).
  s.vendored_frameworks = 'whisper.xcframework'

  # whisper.cpp pulls in Metal / Accelerate via its modulemap; the linker needs
  # to know about them explicitly when consumed as a vendored framework.
  s.frameworks       = 'Metal', 'Accelerate', 'Foundation'
  s.libraries        = 'c++'

  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    # Make sure the wrapper symbol is not stripped — Dart FFI looks it up by name.
    'GCC_SYMBOLS_PRIVATE_EXTERN' => 'NO',
    'STRIP_INSTALLED_PRODUCT' => 'NO',
    # Under `use_frameworks!` the pod itself becomes a dynamic framework, and
    # `vendored_frameworks` only auto-propagates `-framework whisper` to
    # consumers — not to the pod's own link line. Add it explicitly so the
    # wrapper resolves whisper_* symbols at the pod's link step.
    'OTHER_LDFLAGS' => '$(inherited) -framework whisper',
  }
end
