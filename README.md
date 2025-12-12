
# SkeleShare Artifact Evaluation (CGO '26)

This repository provides a Docker image and automated evaluation harness for **SkeleShare**, a technique introduced in the CGO '26 paper *SkeleShare: Algorithmic Skeletons and Equality Saturation for Hardware Resource Sharing.*

SkeleShare is a fully automated system for resource allocation and hardware sharing in functional FPGA compilation. It combines:

- a multi-abstraction skeleton IR,
- equality saturation to explore all legal transformation sequences,
- a solver‑based extractor that jointly decides allocation and sharing under device constraints,
- and a structured lowering pipeline that targets the SHIR compiler and Intel FPGA toolchains.

The Docker image in this artifact reproduces the paper's main results, which are found in Table III.
VHDL code for all experiments can be generated using a single command inside the container, and results are written to the local `results/` directory for inspection and further processing.

## Folder Structure
```
SKELESHARE-CGO26-ARTIFACT
├── scripts             # Scripts for reproducing results
│   ├── figures         # Tex scripts for producing figure 12
│   ├── scores          # Scripts for Table III's numbers
│   ├── syntest         # Wraper for synthesis
│   └── profile         # Sample enviroment setup for FPGA
├── Dockerfile          
├── evaluation.py       # Main script for running experiments
└── README.md           # Documentation
```

``scripts/scores`` prints out performance numbers such as Logic, RAM, DSP, and GOP/s after synthesis. Users will need to synthesize the generated design with ``scripts/syntest`` and run the FPGA bitstream before collecting performance numbers.

The structore of ``scripts/syntest`` is as follows. The foler contains the hardware wrappers for handling the FPGA's interface, as well as a software runtime to control the device.
After synthesis, there will be a generated ``build`` folder that contains FPGA bitstream and source usage numbers.
```
syntest
├── hw                  # Hardware wrapper for synthesis
├── sw                  # Software runtime
├── real.sh             # Script for running synthesis
├── real_sw.sh          # Script for running program on FPGA
└── real_start.sh       # Script for loading bitstream to FPGA
```

`scripts/profile` is a sample environment setup for Intel FPGA tool chain. Note that the setup will be different if users use their own software tools (due to different installation paths and software verions.)


## Step-By-Step Instructions (Table III)

The steps below walk you through the complete workflow for evaluating SkeleShare using our Docker image and server setup.
You'll connect to the server, pull the artifact's Docker container, generate VHDL for all experiments, and run the pre-synthesized designs on the provided Arria-10 FPGA.

> **Note:** These instructions are tailored specifically for CGO ‘26 Artifact Evaluation.

### 1. Access the server

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

### 2. Pull the Docker image

```bash
docker pull ghcr.io/jonathanvdc/skeleshare-cgo26-artifact:latest
```

### 3. Run the container with mounted results

Create a local results directory and mount it into the container so that all outputs are available on your host machine:

```bash
mkdir -p results
docker run --rm -it \
  --mount type=bind,src=./results,dst=/workspace/results \
  ghcr.io/jonathanvdc/skeleshare-cgo26-artifact:latest
```

This will invoke the evaluation script to produce a VHDL design for each experiment to which equality saturation finds a solution.
The VHDL code for each experiment is stored in:

```
./results/<experiment-id>/lowering/
```

After running the container, the following folder will be created as well and contain the required hardware wrapper and environment setup files to run synthesis.
```
./results/scripts
```

Before moving to the next step, please running the following command to ensure the script files are reachable. The command ``echo $SCRIPTDIR`` should include the absolute path to the ``scripts`` folder
```
export SCRIPTDIR=$(pwd)/results/scripts
echo $SCRIPTDIR
```

### 4. Running Synthesized Designs

Since synthesis typically takes between **4 to 8 hours** for each benchmark in the paper, we provide pre-synthesized designs that correspond exactly to the generated VHDL files for each experiment.
These can be found under:
```bash
/mnt/sdc1/examples/cgo26_ae/<experiment-id>/
```

To directly execute an experiment's pre-synthesized hardware design on the FPGA board, navigate to the experiment's directory and run the following commands:

```bash
source $SCRIPTDIR/profile
./real_start.sh
./real_sw.sh
```

### 5. Results

Finally, run the following script to summarize logic, RAM usage, DSP usage, and GOPS measurements taken in the previous step.

```bash
bash $SCRIPTDIR/scores/<experiment-id>.sh
```

The output adheres to the following format, which can be cross-referenced with Table III from the paper.

```
Logic utilization (in ALMs) : 207,520 / 427,200 ( 49 % )
Total RAM Blocks : 943 / 2,713 ( 35 % )
Total DSP Blocks : 1,152 / 1,518 ( 76 % )
GOP/s : 169.936
```

---

## Additional Options (Table III)

The commands above reproduce the default artifact workflow, but the evaluation harness also supports several optional paths.
These include re-running equality saturation from scratch, re-synthesizing hardware designs with Quartus, or executing only a selected subset of experiments.
The options below are independent of the main workflow and can be used as needed to inspect intermediate outputs.

### Re-Running Equality Saturation

Since optimizing each benchmark using equality saturation takes multiple hours, the commands above use a precomputed solution embedded in the container.
To recompute this solution and place it in `./results/<experiment-id>/eqsat/`, run:

```bash
docker run --rm -it \
  --mount type=bind,src=./results,dst=/workspace/results \
  ghcr.io/jonathanvdc/skeleshare-cgo26-artifact:latest \
  python3 evaluation.py --phase eqsat
```

```bash
docker run --rm -it \
  --mount type=bind,src=./results,dst=/workspace/results \
  ghcr.io/jonathanvdc/skeleshare-cgo26-artifact:latest \
  python3 evaluation.py --phase lowering
```

Note that running all the experiments may take at least 15 hours.

### Re-Running Synthesis

The server stores pre-synthesized designs corresponding to the generated VHDL files for each experiment.
To re-synthesize these designs for an experiment after Step 3, use Quartus.
For each experiment, navigate to the `results/lowering` folder of the desired experiment and run:

```bash
source $SCRIPTDIR/profile
cp -r $SCRIPTDIR/syntest/* .
mkdir hw/rtl/generated
mv *.vhd *.dat hw/rtl/generated/
```

This prepares all required files for Quartus synthesis. Now, start the synthesis for the current experiment:

```bash
./real.sh
```

Synthesis typically takes 4 to 8 hours to complete. After it finishes, you can run the design on the FPGA board using:
```bash
./real_start.sh
./real_sw.sh
```

## Step-By-Step Instructions (Figure 12)

To repdouce, figure 12 (a), please run the following commands to get the data points for enode numbers:

```bash
docker run --rm -it \
  --mount type=bind,src=./results,dst=/workspace/results \
  ghcr.io/jonathanvdc/skeleshare-cgo26-artifact:latest \
  python3 evaluation.py --phase figure --only A-vgg-enodes
```

To draw the figure, navigate to the `results/figure/A-vgg-enodes` folder of the desired experiment and run:

```bash
cp $SCRIPTDIR/figures/enodes.tex ./
pdflatex enodes.tex
```

To repdouce figure 12 (b), there are following options:
- `B-vgg-saturation`
- `B-vgg-extraction-1to5`
- `B-vgg-extraction-$id` ($id = 6 ~ 14)

Since running the whole experiment will take several days, we partition the experiment into several move steps.
`B-vgg-saturation` produces the saturation curve in figure 12 (b). 
`B-vgg-extraction-1to5`, `B-vgg-extraction-6`, ..., and `B-vgg-extraction-14` produce the extraction curve in figure 12 (b). 
Note that `B-vgg-extraction-7` to `B-vgg-extraction-14` will reach the run time cut-off and therefore produce similar run time (180 minutes).

```bash
docker run --rm -it \
  --mount type=bind,src=./results,dst=/workspace/results \
  ghcr.io/jonathanvdc/skeleshare-cgo26-artifact:latest \
  python3 evaluation.py --phase figure --only B-vgg-saturation
```

To draw the figure, navigate to the `results/figure/` folder of the desired experiment and run:
```bash
cp B-vgg-saturation/saturation.csv ./
cp $SCRIPTDIR/figures/exploringTime.tex ./
bash $SCRIPTDIR/figures/concatExtraction.sh
pdflatex exploringTime.tex
```

### Running only selected experiments

You may restrict execution to a comma‑separated list of experiment IDs, e.g.:

```bash
python3 evaluation.py --only 1-vgg,3-tinyyolo,14-vgg-skeleshare-1abstr
```

A full list of experiment IDs is defined in `evaluation.py` and corresponds to the experiments in the artifact appendix.
These experiment IDs are:

- `1-vgg`
- `3-tinyyolo`
- `6-self-attention`
- `8-stencil-4stage`
- `9-stencil-baseline`
- `10-vgg-no-sharing`
- `11-vgg-no-padding`
- `12-vgg-no-tiling`
- `13-vgg-baseline-no-sharing`
- `14-vgg-skeleshare-1abstr`
- `15-vgg-quarter-dsps`
- `17-vgg-half-dsps`
- `A-vgg-enodes`
- `B-vgg-saturation`
- `B-vgg-extraction-1to5`
- `B-vgg-extraction-$id` ($id = 6 ~ 14)

Note experiments `10-vgg-no-sharing`, `11-vgg-no-padding`, and `12-vgg-no-tiling` will trigger erros during the equality saturation stage. Therefore, there is no lowering stage for them. 
`13-vgg-baseline-no-sharing` does not contain the equality saturation stage and the synthesis step will fail during to resource limitation.
Note that `13-vgg-baseline-no-sharing` is not synthesizable so the experiment will trigger an error and produce no performance number.
The ``stencil`` experiments usaully need 2-3 hours. 
The ``vgg``, ``tinyyolo``, ``self-attention`` tests may take 7-12 hours.