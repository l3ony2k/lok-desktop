import pathlib, sys
p = pathlib.Path(sys.argv[1]) / "common/src/rust_fp_dbus.rs"
s = p.read_text()
if "Match error:" in s:
    print("already"); raise SystemExit
old = """            .match_templates(&templates, MATCH_STEP_TIMEOUT)
            .await
            .map_err(|e| fdo::Error::Failed(format!("{e:?}")))?;"""
new = """            .match_templates(&templates, MATCH_STEP_TIMEOUT)
            .await
            .map_err(|e| {
                warn!("Match error: {e:?}");
                fdo::Error::Failed(format!("{e:?}"))
            })?;"""
assert s.count(old) == 1
p.write_text(s.replace(old, new)); print("patched", p)
