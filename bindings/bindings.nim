import genny, fidget_dev

# exportConsts:
#   defaultMiterLimit
#   autoLineHeight

# exportEnums:
#   FileFormat
#   BlendMode

# exportProcs:
#   readImage
#   readmask
#   readTypeface

# exportObject Matrix3:
#   constructor:
#     matrix3
#   procs:
#     mul(Matrix3, Matrix3)

# exportRefObject Mask:
#   fields:
#     width
#     height
#   constructor:
#     newMask(int, int)
#   procs:
#     writeFile(Mask, string)
#     copy(Mask)
#     getValue
#     setValue

# Must have this at the end.
writeFiles("bindings/generated", "fidget")
include generated/internal
