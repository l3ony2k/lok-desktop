#!/usr/bin/env python3
"""Add EC_CMD_FP_INFO v2 support to crosec-rs (fp_info.rs).

Newer FPMCU firmware (bloonchipper v2.0.30778, 2026) only accepts FP_INFO
v2/v3; crosec-rs only implemented v1 and panicked. v2 layout per the ChromeOS
ec_commands.h: struct fp_sensor_info (20 B), struct fp_template_info (16 B),
then num_capture_types x struct fp_image_frame_params (16 B each).
"""
import sys

path = sys.argv[1]
src = open(path).read()

old = '''pub fn fp_info<File: AsRawFd>(file: &mut File) -> EcCmdResult<EcResponseFpInfo> {
    let fd = file.as_raw_fd();
    let versions = ec_cmd_get_cmd_versions(file, CrosEcCmd::FpInfo)?;
    if versions & V1 == 0 {
        panic!("fp doesn't support V1. Other versions are currently not implemented");
    }
    let info: EcResponseFpInfo = ec_command_bytemuck(CrosEcCmd::FpInfo, 1, &(), fd)?;
    Ok(info)
}'''

new = '''/// Version mask bit for EC_CMD_FP_INFO v2.
const FP_INFO_V2: u32 = 1 << 2;
/// Up to this many image frame descriptors are read for v2.
const FP_INFO_V2_MAX_FRAMES: usize = 8;

pub fn fp_info<File: AsRawFd>(file: &mut File) -> EcCmdResult<EcResponseFpInfo> {
    let fd = file.as_raw_fd();
    let versions = ec_cmd_get_cmd_versions(file, CrosEcCmd::FpInfo)?;
    if versions & V1 != 0 {
        let info: EcResponseFpInfo = ec_command_bytemuck(CrosEcCmd::FpInfo, 1, &(), fd)?;
        return Ok(info);
    }
    if versions & FP_INFO_V2 != 0 {
        return fp_info_v2(fd);
    }
    panic!("fp supports neither FP_INFO v1 nor v2 (version mask {versions:#x})");
}

/// EC_CMD_FP_INFO v2 (newer FPMCU firmware drops v1). Layout per ec_commands.h:
/// struct fp_sensor_info (20 bytes), struct fp_template_info (16 bytes), then
/// num_capture_types x struct fp_image_frame_params (16 bytes each).
/// Mapped back onto the v1 struct so callers stay unchanged.
fn fp_info_v2(fd: std::os::raw::c_int) -> EcCmdResult<EcResponseFpInfo> {
    let size = 20 + 16 + 16 * FP_INFO_V2_MAX_FRAMES;
    let r = ec_command_with_dynamic_output_size(CrosEcCmd::FpInfo, 2, &[], size, fd)?;
    let u32_at = |o: usize| u32::from_le_bytes(r[o..o + 4].try_into().unwrap());
    let u16_at = |o: usize| u16::from_le_bytes(r[o..o + 2].try_into().unwrap());
    let num_frames = (u16_at(16) as usize).clamp(1, FP_INFO_V2_MAX_FRAMES);
    // Prefer the vendor-format capture (fp_capture_type 0), as v1 reported.
    let frame = (0..num_frames)
        .map(|i| 36 + 16 * i)
        .find(|&o| r[o + 14] == 0)
        .unwrap_or(36);
    Ok(EcResponseFpInfo {
        vendor_id: u32_at(0),
        product_id: u32_at(4),
        model_id: u32_at(8),
        version: u32_at(12),
        errors: u16_at(18),
        template_size: u32_at(20),
        template_max: u16_at(24),
        template_valid: u16_at(26),
        template_dirty: u32_at(28),
        template_version: u32_at(32),
        frame_size: u32_at(frame),
        pixel_format: u32_at(frame + 4),
        width: u16_at(frame + 8),
        height: u16_at(frame + 10),
        bpp: u16_at(frame + 12),
    })
}'''

assert old in src, "fp_info pattern not found"
src = src.replace(old, new)
imp_old = "use crate::{ec_command::ec_command_bytemuck, EcCmdResult};"
imp_new = ("use crate::{\n    ec_command::{ec_command_bytemuck, ec_command_with_dynamic_output_size},\n"
           "    EcCmdResult,\n};")
assert imp_old in src, "import pattern not found"
src = src.replace(imp_old, imp_new)
open(path, "w").write(src)
print("patched", path)
