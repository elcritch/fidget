# Package

version       = "1.7.10"
author        = "Andre von Houck"
description   = "Fidget - UI Library"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 1.4.0"
requires "https://github.com/elcritch/cssgrid.git >= 0.2.1"
requires "typography >= 0.7.14"
requires "pixie >= 5.0.1"
requires "print >= 0.1.0"
requires "opengl >= 1.2.3"
requires "html5_canvas >= 1.3"
requires "staticglfw >= 4.1.2"
requires "cligen >= 1.0.0"
requires "supersnappy >= 1.0.0"
requires "variant >= 0.1.0"
requires "patty >= 0.3.4"
requires "macroutils >= 1.2.0"
requires "cdecl >= 0.5.10"

task bindings, "Generate bindings":

  proc compile(libName: string, flags = "") =
    exec "nim c -f " & flags & " -d:release --app:lib --gc:arc --tlsEmulation:off --out:" & libName & " --outdir:bindings/generated bindings/bindings.nim"

  when defined(windows):
    compile "fidget.dll"

  elif defined(macosx):
    compile "libfidget.dylib.arm", "--cpu:arm64 -l:'-target arm64-apple-macos11' -t:'-target arm64-apple-macos11'"
    compile "libfidget.dylib.x64", "--cpu:amd64 -l:'-target x86_64-apple-macos10.12' -t:'-target x86_64-apple-macos10.12'"
    exec "lipo bindings/generated/libfidget.dylib.arm bindings/generated/libfidget.dylib.x64 -output bindings/generated/libfidget.dylib -create"

  else:
    compile "libfidget.so"
