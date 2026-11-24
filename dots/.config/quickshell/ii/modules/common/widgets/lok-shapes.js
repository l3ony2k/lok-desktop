.pragma library

// lok style: a plain square with sharp corners. MaterialShape draws every shape as
// this when Appearance.lok is on. Kept here (fork-owned) instead of inside the
// `shapes` git submodule, whose upstream (end-4/rounded-polygon-qmljs) we can't push to.
.import "shapes/shapes/rounded-polygon.js" as RoundedPolygon

var _lokSquare = null;
function getLokSquare() {
    if (_lokSquare !== null) return _lokSquare;
    _lokSquare = RoundedPolygon.RoundedPolygon.rectangle(1, 1).normalized();
    return _lokSquare;
}
