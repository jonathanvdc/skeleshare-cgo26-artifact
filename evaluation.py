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
    figure: Optional[PhaseConfig]


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

    dest = os.path.join(RESULTS_DIR, exp.id, "lowering")
    if os.path.exists(dest):
        shutil.rmtree(dest)
    os.makedirs(dest, exist_ok=True)

    # Find subdirectories inside out_dir
    subdirs = [
        d for d in os.listdir(out_dir)
        if os.path.isdir(os.path.join(out_dir, d))
    ]

    if not subdirs:
        raise RuntimeError(f"No subdirectories found in lowering output {out_dir}")
    elif len(subdirs) > 1:
        raise RuntimeError(f"Multiple subdirectories found in lowering output {out_dir}: {subdirs}")

    src_dir = os.path.join(out_dir, subdirs[0])
    print(f"Copying contents of {src_dir} to {dest}")

    for item in os.listdir(src_dir):
        s = os.path.join(src_dir, item)
        d = os.path.join(dest, item)
        if os.path.isdir(s):
            shutil.copytree(s, d)
        else:
            shutil.copy2(s, d)


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
        figure=None,
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
        figure=None,
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
        figure=None,
    ),
    Experiment(
        id="8-stencil-4stage",
        description="8. 4-stage stencil",
        eqsat=PhaseConfig(
            branch="eqsat-nn-extra-sync",
            path="src/test/eqsat/nnExtra/StencilTest.scala",
        ),
        lowering=PhaseConfig(
            branch="eqsat-nn-extra-sync",
            path="src/test/eqsat/nnExtra/StencilLoweringTest.scala",
        ),
        figure=None,
    ),
    Experiment(
        id="9-stencil-baseline",
        description="9. 4-stage stencil baseline",
        eqsat=None,
        lowering=PhaseConfig(
            branch="eqsat-nn-extra-sync",
            path="src/test/eqsat/nnExtra/StencilNoSharingTest.scala",
        ),
        figure=None,
    ),
    Experiment(
        id="10-vgg-no-sharing",
        description="10. VGG, no sharing",
        eqsat=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/SingleVGGNoSharingTest.scala",
            expect_failure=True,
        ),
        lowering=None,
        figure=None,
    ),
    Experiment(
        id="11-vgg-no-padding",
        description="11. VGG, no padding",
        eqsat=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/SingleVggNoPaddingTest.scala",
            expect_failure=True,
        ),
        lowering=None,
        figure=None,
    ),
    Experiment(
        id="12-vgg-no-tiling",
        description="12. VGG, no tiling",
        eqsat=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/SingleVGGNoTilingTest.scala",
            expect_failure=True,
        ),
        lowering=None,
        figure=None,
    ),
    Experiment(
        id="13-vgg-baseline-no-sharing",
        description="13. VGG, baseline, no sharing",
        eqsat=None,
        lowering=PhaseConfig(
            branch="eqsat-nn-extra-sync",
            path="src/test/eqsat/nnExtra/VGGLoweringTest.scala",
        ),
        figure=None,
    ),
    Experiment(
        id="14-vgg-skeleshare-1abstr",
        description="14. VGG, SkeleShare, 1 abstr",
        eqsat=PhaseConfig(
            branch="new-test-tag-abs",
            path="src/test/eqsat/nn/SingleVGGHalfAbsTest.scala",
        ),
        lowering=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/VggConvHalfAbsTest.scala",
        ),
        figure=None,
    ),
    Experiment(
        id="15-vgg-quarter-dsps",
        description="15. VGG, 1/4 DSPs",
        eqsat=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/SingleVGGFourthDSPTest.scala",
        ),
        lowering=PhaseConfig(
            branch="new-test-tag",
            path="src/test/algo/vgg8bits/VggConvFourthDSPTest.scala",
        ),
        figure=None,
    ),
    Experiment(
        id="17-vgg-half-dsps",
        description="17. VGG, 1/2 DSPs",
        eqsat=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/SingleVGGHalfDSPTest.scala",
        ),
        lowering=PhaseConfig(
            branch="new-test-tag",
            path="src/test/algo/vgg8bits/VggConvHalfDSPTest.scala",
        ),
        figure=None,
    ),
    Experiment(
        id="A-vgg-enodes",
        description="A. VGG ENodes",
        eqsat=None,
        lowering=None,
        figure=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/VGGEnodesTest.scala",
        ),
    ),
    Experiment(
        id="B-vgg-saturation",
        description="B. VGG Saturation",
        eqsat=None,
        lowering=None,
        figure=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/VGGSaturationTest.scala",
        ),
    ),
    Experiment(
        id="B-vgg-extraction-1to5",
        description="B. VGG Extration 1to5",
        eqsat=None,
        lowering=None,
        figure=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/extraction/data1to5.scala",
        ),
    ),
    Experiment(
        id="B-vgg-extraction-6",
        description="B. VGG Extration 6",
        eqsat=None,
        lowering=None,
        figure=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/extraction/data6.scala",
        ),
    ),
    Experiment(
        id="B-vgg-extraction-7",
        description="B. VGG Extration 7",
        eqsat=None,
        lowering=None,
        figure=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/extraction/data7.scala",
        ),
    ),
    Experiment(
        id="B-vgg-extraction-8",
        description="B. VGG Extration 8",
        eqsat=None,
        lowering=None,
        figure=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/extraction/data8.scala",
        ),
    ),
    Experiment(
        id="B-vgg-extraction-9",
        description="B. VGG Extration 9",
        eqsat=None,
        lowering=None,
        figure=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/extraction/data9.scala",
        ),
    ),
    Experiment(
        id="B-vgg-extraction-10",
        description="B. VGG Extration 10",
        eqsat=None,
        lowering=None,
        figure=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/extraction/data10.scala",
        ),
    ),
    Experiment(
        id="B-vgg-extraction-11",
        description="B. VGG Extration 11",
        eqsat=None,
        lowering=None,
        figure=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/extraction/data11.scala",
        ),
    ),
    Experiment(
        id="B-vgg-extraction-12",
        description="B. VGG Extration 12",
        eqsat=None,
        lowering=None,
        figure=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/extraction/data12.scala",
        ),
    ),
    Experiment(
        id="B-vgg-extraction-13",
        description="B. VGG Extration 13",
        eqsat=None,
        lowering=None,
        figure=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/extraction/data13.scala",
        ),
    ),
    Experiment(
        id="B-vgg-extraction-14",
        description="B. VGG Extration 14",
        eqsat=None,
        lowering=None,
        figure=PhaseConfig(
            branch="new-test-tag",
            path="src/test/eqsat/nn/extraction/data14.scala",
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
        choices=["eqsat", "lowering", "both", "figure"],
        default="lowering",
        help="The phases to run for each experiment.",
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

    s = os.path.join(WORKSPACE_DIR, 'scripts')
    d = os.path.join(RESULTS_DIR, 'scripts')
    if not os.path.isdir(d):
        if os.path.isdir(s):
            shutil.copytree(s, d)
        else:
            shutil.copy2(s, d)

    print(f"Copied script files to {RESULTS_DIR}")

    for exp in experiments:
        if args.phase in ("eqsat", "both") and exp.eqsat is not None:
            run_eqsat_phase(exp, exp.eqsat)
        elif args.phase in ("eqsat", "both") and exp.eqsat is None:
            print(f"\n==== EqSat phase: {exp.id} has no EqSat configuration; skipping ====")

        if args.phase in ("lowering", "both") and exp.lowering is not None:
            run_lowering_phase(exp, exp.lowering)
        elif args.phase in ("lowering", "both") and exp.lowering is None:
            print(f"\n==== Lowering phase: {exp.id} has no lowering configuration; skipping ====")

        if args.phase in ("figure") and exp.figure is not None:
            run_eqsat_phase(exp, exp.figure)
        elif args.phase in ("lowering", "both") and exp.figure is None:
            print(f"\n==== Lowering phase: {exp.id} has no lowering configuration; skipping ====")



if __name__ == "__main__":
    main()
