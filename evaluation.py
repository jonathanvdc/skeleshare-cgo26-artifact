"""Run EqSat and lowering experiments for the SHIR artifact.

This script assumes the Dockerfile has cloned the SHIR repo branches into

  /workspace/shir-new-test-tag
  /workspace/shir-new-test-tag-y
  /workspace/shir-eqsat-nn-extra-sync

For each experiment we optionally run two phases:
  * EqSat phase: an sbt `testOnly` invocation that typically produces a
    single textual output (e.g., vggexpr.txt) in the repo tree.
  * Lowering phase: an sbt `testOnly` invocation that typically produces
    an output directory under `out/NAME`.

The script detects newly created files for EqSat runs and copies them into
`results/<experiment-id>/eqsat`. For lowering runs, it deletes `out/` before
running the test and then copies the freshly generated `out/` directory into
`results/<experiment-id>/lowering`.

Usage inside the container (from /workspace):

  python3 evaluation.py                 # run all experiments, both phases
  python3 evaluation.py --phase eqsat   # run only EqSat phases
  python3 evaluation.py --phase lowering
  python3 evaluation.py --only 1-vgg,3-tinyyolo
"""

import argparse
import os
import shutil
import subprocess
from dataclasses import dataclass
from typing import List, Optional, Dict, Set


WORKSPACE_DIR = "/workspace"
RESULTS_DIR = os.path.join(WORKSPACE_DIR, "results")


@dataclass
class PhaseConfig:
    branch: str
    # Scala test file path relative to the repo root
    path: str
    # If True, a non-zero exit code from sbt is treated as an expected failure.
    expect_failure: bool = False


@dataclass
class Experiment:
    """Description of one experiment (EqSat + optional lowering)."""

    id: str
    description: str
    eqsat: Optional[PhaseConfig]
    lowering: Optional[PhaseConfig]


def fqcn_from_test_path(path: str) -> str:
    """Derive the fully-qualified Scala test class name from a source path.

    Example:
      src/test/eqsat/nn/SingleVGGTest.scala -> eqsat.nn.SingleVGGTest
      src/test/backend/hdl/arch/yolo/ShallowConvFullTest.scala
        -> backend.hdl.arch.yolo.ShallowConvFullTest
    """

    # Strip leading src/test/ or src/test/scala/
    for prefix in ("src/test/scala/", "src/test/"):
        if path.startswith(prefix):
            path = path[len(prefix) :]
            break
    if path.endswith(".scala"):
        path = path[: -len(".scala")]
    return path.replace("/", ".")


def shir_repo_dir(branch: str) -> str:
    # Dockerfile clones into /workspace/shir-<branch>
    return os.path.join(WORKSPACE_DIR, f"shir-{branch}")


def snapshot_files(root: str) -> Set[str]:
    """Return the set of relative file paths under root.

    We skip common build / VCS directories so we don't copy huge targets.
    """

    excluded_dirs = {".git", "target", "project", ".idea", ".bsp", ".metals"}
    files: Set[str] = set()
    for dirpath, dirnames, filenames in os.walk(root):
        # prune excluded dirs
        dirnames[:] = [d for d in dirnames if d not in excluded_dirs]
        for fname in filenames:
            rel = os.path.relpath(os.path.join(dirpath, fname), root)
            files.add(rel)
    return files


def copy_relative_paths(src_root: str, rel_paths: Set[str], dst_root: str) -> None:
    for rel in sorted(rel_paths):
        src = os.path.join(src_root, rel)
        dst = os.path.join(dst_root, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)


def run_sbt_test(repo_dir: str, test_path: str, expect_failure: bool = False) -> None:
    fqcn = fqcn_from_test_path(test_path)
    print(f"\n==> Running sbt testOnly {fqcn} in {repo_dir}")
    cmd = [
        "sbt",
        "-J-Xss32m",
        f"testOnly {fqcn}",
    ]
    result = subprocess.run(cmd, cwd=repo_dir)
    if expect_failure:
        if result.returncode == 0:
            raise RuntimeError(
                f"[ERROR] Expected sbt testOnly {fqcn} to fail, but it succeeded."
            )
        else:
            print(
                f"[INFO] sbt testOnly {fqcn} failed as expected "
                f"(exit code {result.returncode})."
            )
    else:
        if result.returncode != 0:
            raise subprocess.CalledProcessError(result.returncode, cmd)


def run_eqsat_phase(exp: Experiment, cfg: PhaseConfig) -> None:
    repo = shir_repo_dir(cfg.branch)
    print(f"\n==== EqSat phase: {exp.id} ({exp.description}) ====")
    before = snapshot_files(repo)
    run_sbt_test(repo, cfg.path, expect_failure=cfg.expect_failure)
    after = snapshot_files(repo)
    new_files = after - before

    if not new_files:
        print("[WARN] No new files detected for EqSat phase; nothing to copy.")
        return

    dest = os.path.join(RESULTS_DIR, exp.id, "eqsat")
    print(f"Copying {len(new_files)} new file(s) to {dest}")
    copy_relative_paths(repo, new_files, dest)


def run_lowering_phase(exp: Experiment, cfg: PhaseConfig) -> None:
    repo = shir_repo_dir(cfg.branch)
    out_dir = os.path.join(repo, "out")
    print(f"\n==== Lowering phase: {exp.id} ({exp.description}) ====")

    # Clean previous lowering outputs to isolate this run.
    if os.path.exists(out_dir):
        print(f"Removing existing {out_dir} before run")
        shutil.rmtree(out_dir)

    run_sbt_test(repo, cfg.path)

    if not os.path.exists(out_dir):
        print("[WARN] Lowering phase did not produce an 'out' directory.")
        return

    dest = os.path.join(RESULTS_DIR, exp.id, "vhdl")
    if os.path.exists(dest):
        shutil.rmtree(dest)
    print(f"Copying lowering outputs from {out_dir} to {dest}")
    shutil.copytree(out_dir, dest)


EXPERIMENTS: List[Experiment] = [
    Experiment(
        id="1-vgg",
        description="1. VGG",
        eqsat=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/SingleVGGTest.scala",
        ),
        lowering=PhaseConfig(
            branch="new-test-tag",
            path="src/test/algo/vgg8bits/VggFullBiasTest.scala",
        ),
    ),
    Experiment(
        id="3-tinyyolo",
        description="3. TinyYolo",
        eqsat=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/SingleYoloTest.scala",
        ),
        lowering=PhaseConfig(
            branch="new-test-tag-y",
            path="src/test/backend/hdl/arch/yolo/ShallowConvFullTest.scala",
        ),
    ),
    Experiment(
        id="6-self-attention",
        description="6. Self-attention",
        eqsat=PhaseConfig(
            branch="eqsat-nn-extra-sync",
            path="src/test/eqsat/nnExtra/SelfAttentionTest.scala",
        ),
        lowering=PhaseConfig(
            branch="eqsat-nn-extra-sync",
            path="src/test/eqsat/nnExtra/SelfAttentionLoweringTest.scala",
        ),
    ),
    Experiment(
        id="10-stencil-4stage",
        description="10. 4-stage stencil",
        eqsat=PhaseConfig(
            branch="eqsat-nn-extra-sync",
            path="src/test/eqsat/nnExtra/StencilTest.scala",
        ),
        lowering=PhaseConfig(
            branch="eqsat-nn-extra-sync",
            path="src/test/eqsat/nnExtra/StencilLoweringTest.scala",
        ),
    ),
    Experiment(
        id="11-stencil-baseline",
        description="11. 4-stage stencil baseline",
        eqsat=None,
        lowering=PhaseConfig(
            branch="eqsat-nn-extra-sync",
            path="src/test/eqsat/nnExtra/StencilNoSharingTest.scala",
        ),
    ),
    Experiment(
        id="12-vgg-no-sharing",
        description="12. VGG, no sharing",
        eqsat=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/SingleVGGNoSharingTest.scala",
            expect_failure=True,
        ),
        lowering=None,
    ),
    Experiment(
        id="13-vgg-no-padding",
        description="13. VGG, no padding",
        eqsat=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/SingleVggNoPaddingTest.scala",
            expect_failure=True,
        ),
        lowering=None,
    ),
    Experiment(
        id="14-vgg-no-tiling",
        description="14. VGG, no tiling",
        eqsat=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/SingleVGGNoTilingTest.scala",
            expect_failure=True,
        ),
        lowering=None,
    ),
    Experiment(
        id="15-vgg-baseline-no-sharing",
        description="15. VGG, baseline, no sharing",
        eqsat=None,
        lowering=PhaseConfig(
            branch="eqsat-nn-extra-sync",
            path="src/test/eqsat/nnExtra/VGGLoweringTest.scala",
        ),
    ),
    Experiment(
        id="16-vgg-skeleshare-1abstr",
        description="16. VGG, SkeleShare, 1 abstr",
        eqsat=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/SingleVGGHalfAbsTest.scala",
        ),
        lowering=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/VggConvHalfAbsTest.scala",
        ),
    ),
    Experiment(
        id="17-vgg-quarter-dsps",
        description="17. VGG, 1/4 DSPs",
        eqsat=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/SingleVGGFourthDSPTest.scala",
        ),
        lowering=PhaseConfig(
            branch="new-test-tag",
            path="src/test/algo/vgg8bits/VggConvFourthDSPTest.scala",
        ),
    ),
    Experiment(
        id="19-vgg-half-dsps",
        description="19. VGG, 1/2 DSPs",
        eqsat=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/SingleVGGHalfDSPTest.scala",
        ),
        lowering=PhaseConfig(
            branch="new-test-tag",
            path="src/test/algo/vgg8bits/VggConvHalfDSPTest.scala",
        ),
    ),
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run SHIR EqSat and lowering experiments.")
    parser.add_argument(
        "--only",
        type=str,
        default=None,
        help="Comma-separated list of experiment IDs to run (default: all)",
    )
    parser.add_argument(
        "--phase",
        choices=["eqsat", "lowering", "both"],
        default="lowering",
        help="Which phases to run for each experiment.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    if args.only:
        wanted = {x.strip() for x in args.only.split(",") if x.strip()}
        experiments = [e for e in EXPERIMENTS if e.id in wanted]
        unknown = wanted - {e.id for e in experiments}
        if unknown:
            print(f"[WARN] Unknown experiment IDs: {', '.join(sorted(unknown))}")
    else:
        experiments = EXPERIMENTS

    os.makedirs(RESULTS_DIR, exist_ok=True)

    print(f"Results will be stored under: {RESULTS_DIR}")

    for exp in experiments:
        if args.phase in ("eqsat", "both") and exp.eqsat is not None:
            run_eqsat_phase(exp, exp.eqsat)
        elif args.phase in ("eqsat", "both") and exp.eqsat is None:
            print(f"\n==== EqSat phase: {exp.id} has no EqSat configuration; skipping ====")

        if args.phase in ("lowering", "both") and exp.lowering is not None:
            run_lowering_phase(exp, exp.lowering)
        elif args.phase in ("lowering", "both") and exp.lowering is None:
            print(f"\n==== Lowering phase: {exp.id} has no lowering configuration; skipping ====")


if __name__ == "__main__":
    main()
