# Patches for submodules

`dots/.config/quickshell/ii/modules/common/widgets/shapes` is a git submodule
(material-shapes), so changes inside it are not part of this fork's commits.

- `material-shapes-lok-square.patch`: adds `getLokSquare()`, used by MaterialShape
  in lok style. Re-apply after a dots update that resets the submodule:
  `patch -p1 -d dots/.config/quickshell/ii/modules/common/widgets/shapes < asus/patches/material-shapes-lok-square.patch`
