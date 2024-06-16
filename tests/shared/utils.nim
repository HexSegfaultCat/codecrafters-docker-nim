proc memOpen*(restrict: pointer, len: csize_t, modes: cstring): File {.
  importc: "fmemopen",
  header: "<stdio.h>"
.}

