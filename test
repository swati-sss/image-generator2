#!/usr/bin/env python3
"""Package existing Osiris iPhone build products and check their Swift interfaces.

Run on the build machine with the same DEVELOPER_DIR as the successful build:
    python3 recover_osiris_device.py /absolute/path/to/osiris-ios-interface-fix

No SDK rebuild, simulator build, publishing, or Glass modification is performed.
All writes go into a new recovery directory under the supplied SDK checkout.
"""

import argparse
from pathlib import Path
import plistlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile


MODULES = ("Osiris", "OsirisBarcode", "OsirisCamera")
BUNDLES = (
    "OsirisColors.bundle", "OsirisFonts.bundle",
    "OsirisImages.bundle", "OsirisResources.bundle",
)


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sdk_root", type=Path)
    args = parser.parse_args()
    root = args.sdk_root.expanduser().resolve()
    products = root / "build-xcframework/ios-arm64/DerivedData/Build/Products/Debug-iphoneos"
    resources = root / "build-xcframework/Resources"
    zxing = root / "Frameworks/ZXingCPP.xcframework"

    require((root / "Package.swift").is_file(), f"SDK checkout not found: {root}")
    for module in MODULES:
        obj = products / f"{module}.o"
        require(obj.is_file() and obj.stat().st_size > 0, f"Missing build product: {obj}")
        module_dir = products / f"{module}.swiftmodule"
        for suffix in ("swiftinterface", "private.swiftinterface"):
            interface = module_dir / f"arm64-apple-ios.{suffix}"
            require(interface.is_file(), f"Missing interface: {interface}")
    for name in BUNDLES:
        require((resources / name / "Info.plist").is_file(), f"Missing bundle: {resources / name}")

    zxing_info = zxing / "Info.plist"
    require(zxing_info.is_file(), f"Missing local ZXing dependency: {zxing}")
    libraries = plistlib.loads(zxing_info.read_bytes())["AvailableLibraries"]
    devices = [entry for entry in libraries
               if entry.get("SupportedPlatform") == "ios"
               and not entry.get("SupportedPlatformVariant")
               and "arm64" in entry.get("SupportedArchitectures", [])]
    require(len(devices) == 1, "Expected one ARM64 iPhone slice in the local ZXing dependency.")
    device = devices[0]
    require("HeadersPath" in device, "ZXing does not have the expected static-library headers layout.")
    headers = zxing / device["LibraryIdentifier"] / device["HeadersPath"]
    for name in ("module.modulemap", "ZXIFormat.h"):
        require((headers / name).is_file(), f"Missing ZXing header/module map: {headers / name}")

    out = Path(tempfile.mkdtemp(prefix="osiris-device-recovery-", dir=str(root)))
    log_path = out / "recovery.log"
    print(f"Recovery output: {out}", flush=True)
    print(f"Full command log: {log_path}", flush=True)
    print("Existing build products and Glass files will be preserved.", flush=True)

    with log_path.open("w") as log:
        def run(label, command):
            command = [str(item) for item in command]
            print(f"{label}...", flush=True)
            log.write(f"\n=== {label} ===\n{shlex.join(command)}\n")
            log.flush()
            result = subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT)
            log.flush()
            require(result.returncode == 0,
                    f"{label} failed (exit {result.returncode}). See {log_path}")

        try:
            run("Record selected Xcode", ["xcrun", "xcodebuild", "-version"])
            framework = out / "staging/OsirisKit.framework"
            (framework / "Modules").mkdir(parents=True)
            run("Merge the three existing device object files", [
                "xcrun", "libtool", "-static", "-o", framework / "OsirisKit",
                *[products / f"{module}.o" for module in MODULES],
            ])
            for module in MODULES:
                shutil.copytree(products / f"{module}.swiftmodule",
                                framework / "Modules" / f"{module}.swiftmodule")
            for name in BUNDLES:
                shutil.copytree(resources / name, framework / name)
                shutil.copytree(resources / name, out / "Resources" / name)

            info = {
                "CFBundleExecutable": "OsirisKit",
                "CFBundleIdentifier": "org.cocoapods.OsirisKit",
                "CFBundleInfoDictionaryVersion": "6.0",
                "CFBundleName": "OsirisKit",
                "CFBundlePackageType": "FMWK",
                "CFBundleShortVersionString": "0.0.1",
                "CFBundleVersion": "1",
                "CFBundleSupportedPlatforms": ["iPhoneOS"],
                "MinimumOSVersion": "15.1",
            }
            (framework / "Info.plist").write_bytes(plistlib.dumps(info))

            artifact = out / "OsirisKit.xcframework"
            run("Create iPhone-only XCFramework", [
                "xcrun", "xcodebuild", "-create-xcframework",
                "-framework", framework, "-output", artifact,
            ])
            artifact_info = plistlib.loads((artifact / "Info.plist").read_bytes())
            slices = artifact_info["AvailableLibraries"]
            require(len(slices) == 1, "Expected exactly one iPhone slice in the output.")
            entry = slices[0]
            require(entry.get("SupportedPlatform") == "ios"
                    and not entry.get("SupportedPlatformVariant")
                    and entry.get("SupportedArchitectures") == ["arm64"],
                    "Output is not an ARM64 iPhone-only XCFramework.")

            interfaces = list(artifact.rglob("*.swiftinterface"))
            require(bool(interfaces), "No textual Swift interfaces in the output.")
            old_class = re.compile(r"\bclass\s+OsirisBarcode\b")
            new_class = re.compile(r"\bclass\s+OsirisBarcodeModel\b")
            for path in interfaces:
                require(not old_class.search(path.read_text()),
                        f"The original class/module name collision is still present: {path}")
            require(any(new_class.search(path.read_text()) for path in interfaces),
                    "The renamed OsirisBarcodeModel class was not found in the interfaces.")

            check = out / "interface-validation"
            check.mkdir()
            validation_artifact = check / "OsirisKit.xcframework"
            shutil.copytree(artifact, validation_artifact)
            # Remove only binary module files in the disposable validation copy.
            # Keep all .swiftmodule directories and textual interface files.
            for path in validation_artifact.rglob("*.swiftmodule"):
                if path.is_file():
                    path.unlink()
            source = check / "ImportCheck.swift"
            source.write_text("import Osiris\nimport OsirisBarcode\nimport OsirisCamera\n")
            cache = check / "module-cache"
            cache.mkdir()
            sdk_result = subprocess.run(
                ["xcrun", "--sdk", "iphoneos", "--show-sdk-path"],
                text=True, stdout=subprocess.PIPE, stderr=log,
            )
            require(sdk_result.returncode == 0, f"Cannot locate iPhoneOS SDK. See {log_path}")
            modules = (validation_artifact / entry["LibraryIdentifier"]
                       / entry["LibraryPath"] / "Modules")
            run("Check all three imports using textual interfaces and a fresh cache", [
                "xcrun", "--sdk", "iphoneos", "swiftc", "-typecheck",
                "-target", "arm64-apple-ios15.1", "-sdk", sdk_result.stdout.strip(),
                "-module-cache-path", cache, "-I", modules, "-I", headers, source,
            ])

            archive = out / "xcframework-iOS-OsirisKit-0.0.1-device-only.zip"
            run("Create local ZIP", [
                "/usr/bin/ditto", "-c", "-k", "--keepParent", artifact, archive,
            ])
            (out / "zip-path.txt").write_text(str(archive) + "\n")
            log.write("\nSUCCESS: device-only packaging and textual-interface import check passed.\n")
            log.flush()
            print("\nSUCCESS: device-only packaging and textual-interface import check passed.")
            print(f"XCFramework: {artifact}")
            print(f"Resources: {out / 'Resources'}")
            print(f"ZIP: {archive}")
            print(f"Log: {log_path}")
            print("Next: replace the Glass POC copy, then build and scan on a physical iPhone.")
            print("This artifact contains no simulator slice. Linking and scanning remain untested.")
        except Exception as error:
            log.write(f"\nFAILED: {error}\n")
            log.flush()
            print(f"\nFAILED: {error}", file=sys.stderr)
            print(f"Preserved recovery files: {out}", file=sys.stderr)
            print("Do not replace the framework in Glass yet. Share recovery.log.", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"Preflight failed: {error}", file=sys.stderr)
        print("Existing build products and Glass files were not changed.", file=sys.stderr)
        sys.exit(1)
