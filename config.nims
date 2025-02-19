switch("styleCheck", "hint")

--gc:arc

if not defined(emscripten):
  --threads:on

switch("define", "DataDirPath:./data/")

if defined(emscripten):
  # This path will only run if -d:emscripten is passed to nim.

  --nimcache:tmp # Store intermediate files close by in the ./tmp dir.

  --os:linux # Emscripten pretends to be linux.
  --cpu:i386 # Emscripten is 32bits.
  --cc:clang # Emscripten is very close to clang, so we ill replace it.
  --clang.exe:emcc.bat  # Replace C
  --clang.linkerexe:emcc.bat # Replace C linker
  --clang.cpp.exe:emcc.bat # Replace C++
  --clang.cpp.linkerexe:emcc.bat # Replace C++ linker.
  --listCmd # List what commands we are running so that we can debug them.

  --gc:arc # GC:arc is friendlier with crazy platforms.
  --exceptions:goto # Goto exceptions are friendlier with crazy platforms.

  --d:noSignalHandler

  # Pass this to Emscripten linker to generate html file scaffold for us.
  # switch("passL", "-o wasm.html")
  # #switch("--preload-file data")
  # switch("--shell-file src/shell_minimal.html")

elif defined(macosx):
  --d:kqueueUserEvent
  --threads:on

# patchFile("typography", "textboxes", "patches/textboxes")
