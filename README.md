
# SkeleShare Artifact Evaluation (CGO '26)

This repository provides a Docker image and automated evaluation harness for **SkeleShare**, the technique introduced in the CGO '26 paper *SkeleShare: Algorithmic Skeletons and Equality Saturation for Hardware Resource Sharing.*

SkeleShare is a fully automated system for **resource allocation and hardware sharing** in functional FPGA compilation. It combines:

- a **multi-abstraction skeleton IR**,
- **equality saturation** to explore all legal transformation sequences,
- a **solver‑based extractor** that jointly decides allocation and sharing under device constraints,
- and a structured **lowering pipeline** that targets the SHIR compiler and Intel FPGA toolchains.

The Docker image in this artifact reproduces the experiments from the paper, including:

- EqSat exploration for benchmarks,
- VHDL generation for chosen extracted programs,
- evaluation of neural network models (VGG, TinyYolo), self-attention, and stencil pipelines,
- ablation studies (no sharing, no padding, no tiling, single‑abstraction), and
- experiments under constrained DSP budgets.

VHDL code for all experiments can be generated using a single command inside the container, and results are written to the local `results/` directory for inspection and further processing.
## 1. Access the server

We have created temporary institutional server accounts for CGO Artifact Evaluation and provided the private SSH keys to the CGO chairs. As an evaluator, you will receive one private key along with a username in the format `csuser<NUM>`.

**I. Add the SSH key to your local machine**
```bash
ssh-add path/to/private-key
```
**II. Connect to our server via the institutional jump host**
```bash
ssh -A -J your-username@jump.cs.mcgill.ca your-username@solaire.cs.mcgill.ca
```
Once connected, you will have access to all required hardware on our server, including the Intel Arria 10 FPGA board used for the evaluation. You may directly compile and run the provided designs on the physical hardware.



## 2. Build the image

```bash
docker build -t skeleshare-eval .
```

## 3. Run the container with mounted results

Create a local results directory and mount it into the container so that all outputs are available on your host machine:

```bash
mkdir -p results
docker run --rm -it --mount type=bind,src=./results,dst=/workspace/results skeleshare-eval
```

This will invoke the evaluation script, which executes all EqSat and VHDL generation experiments.
Each experiment produces outputs in:

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

## 4. Running only specific phases

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

## 5. Running only selected experiments

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

## 6. Where outputs appear

For **EqSat experiments**, unit tests typically generate a single textual output (e.g., `vggexpr.txt`) inside their respective SHIR repo directory. The evaluation script automatically detects and copies those files to:

```
results/<experiment-id>/eqsat/
```

For **VHDL generation experiments**, tests generate an `out/NAME` directory containing VHDL outputs. The script cleans any previous `out/` directory, runs the test, and copies the resulting directory into:

```
results/<experiment-id>/lowering/out/
```


## 7. Running Quartus Synthesis

Once all VHDL files are generated for an experiment, you can synthesize them using **Quartus**. To do so, navigate to the `lowering` folder of the desired experiment and run:

```bash
source /mnt/sdc1/examples/profile
cp -r /mnt/sdc1/examples/syntest/* .
mkdir hw/rtl/generated
mv *.vhd *.dat hw/rtl/generated/
```

This prepares all required files for Quartus synthesis. Now, start the synthesis for the current experiment:

```bash
./real.sh
```

Synthesis typically takes **4 to 8 hours** to complete. After it finishes, you can run the design on the actual FPGA board using:
```bash
./real_start.sh
./real_sw.sh
```

The output will show **.... TODO: Finalize this for reports!**

### Using Pre-Synthesized Designs (Recommended to Save Time)

To avoid the long synthesis time, we also provide **pre-synthesized designs** that correspond exactly to the generated VHDL files for each experiment. These can be found under:
```bash
TODO: Update
```

Navigate to the directory for the chosen experiment, then run:

```bash
source /mnt/sdc1/examples/profile
./real_start.sh
./real_sw.sh
```

This will directly execute the pre-synthesized hardware design on the FPGA board.

