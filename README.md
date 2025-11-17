

## 1. Build the image

```bash
docker build -t skeleshare-eval .
```

## 2. Run the container with mounted results

Create a local results directory and mount it into the container so that all outputs are available on your host machine:

```bash
mkdir -p results
docker run --rm -it --mount type=bind,src=./results,dst=/workspace/results skeleshare-eval
```

This will invoke the evaluation script, which executes **all EqSat and lowering experiments** across all three SHIR branches (`new-test-tag`, `new-test-tag-y`, `eqsat-nn-extra-sync`). Each experiment produces outputs in:

```
/workspace/results/<experiment-id>/eqsat/
/workspace/results/<experiment-id>/lowering/
```

Because the container was launched with a bind mount:

```
./results → /workspace/results
```

you will find all outputs on the host machine under the local `results/` directory.

---

## 3. Running only specific phases

Run **only the EqSat phases**:

```bash
python3 evaluation.py --phase eqsat
```

Run **only the lowering phases**:

```bash
python3 evaluation.py --phase lowering
```

Run both phases (default):

```bash
python3 evaluation.py --phase both
```

---

## 4. Running only selected experiments

You may restrict execution to a comma‑separated list of experiment IDs, e.g.:

```bash
python3 evaluation.py --only 1-vgg,3-tinyyolo,16-vgg-skeleshare-1abstr
```

A full list of experiment IDs is defined in `evaluation.py` and corresponds to the experiments in the artifact appendix:

- `1-vgg`
- `3-tinyyolo`
- `6-self-attention`
- `10-stencil-4stage`
- `11-stencil-baseline`
- `12-vgg-no-sharing`
- `13-vgg-no-padding`
- `14-vgg-no-tiling`
- `15-vgg-baseline-no-sharing`
- `16-vgg-skeleshare-1abstr`
- `17-vgg-quarter-dsps`
- `19-vgg-half-dsps`

---

## 5. Where outputs appear

For **EqSat experiments**, unit tests typically generate a single textual output (e.g., `vggexpr.txt`) inside their respective SHIR repo directory. The evaluation script automatically detects and copies those files to:

```
results/<experiment-id>/eqsat/
```

For **lowering experiments**, tests generate an `out/NAME` directory containing HDL outputs. The script cleans any previous `out/` directory, runs the test, and copies the resulting directory into:

```
results/<experiment-id>/lowering/out/
```
