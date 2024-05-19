{ makeSetupHook, writeScript }:

# FIXME: https://github.com/NixOS/nixpkgs/issues/278348
makeSetupHook { name = "fixCoreFoundationCrossHook"; }
  (writeScript "fix-corefoundation-cross-hook" ''
    fixCoreFoundationCross() {
      forceLinkCoreFoundationFramework() {
        echo "Skipping forceLinkCoreFoundationFramework"
      }
    }

    preConfigureHooks+=(fixCoreFoundationCross)
  '')
