
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
The docker image can be pulled from Github or downloaed from Zenodo.

From Github:
```bash
docker pull ghcr.io/jonathanvdc/skeleshare-cgo26-artifact:latest
```

From Zenodo:
```bash
wget https://zenodo.org/records/17925912/files/skeleshare-cgo26-artifact_image.zip
unzip ./skeleshare-cgo26-artifact_image.zip
docker load -i ./skeleshare-cgo26-artifact.tar
```

### 3. Run the container with mounted results

Create a local results directory and mount it into the container so that all outputs are available on your host machine:

```bash
mkdir -p results
docker run --rm -it \
  --mount type=bind,src=./results,dst=/workspace/results \
  ghcr.io/jonathanvdc/skeleshare-cgo26-artifact:latest
```

Running the container invokes the evaluation script, which generates a VHDL design for each experiment where equality saturation produces a valid solution. 
The resulting VHDL for each experiment is stored in:

```
./results/<experiment-id>/lowering/
```
After running the container, the script folder is created that contains the hardware wrapper and the required environment setup files for synthesis.
```
./results/scripts
```

Before moving to the next step, please run the following command to confirm that the script directory is correctly set and reachable. The output of ``echo $SCRIPTDIR`` should be the absolute path to the ``scripts`` folder:
```
export SCRIPTDIR=$(pwd)/results/scripts
echo $SCRIPTDIR
```

### 4. Running synthesized designs

Because synthesis typically takes **4–8 hours per benchmark** in the paper, we provide pre-synthesized designs that correspond exactly to the VHDL generated for each experiment. These can be found under:
```bash
/mnt/sdc1/examples/cgo26_ae/<experiment-id>/
```

The pre-synthesized design can also be downloaded from zenodo. The experiments will be located in the ``precomputed`` folder after unzipping the file.
```bash
wget https://zenodo.org/records/17925912/files/precomputed.zip
unzip precomputed.zip
```

The unzipped pre-synthesized design may have permission issue. Please run the following command to update the permission.
```bash
chmod -R 777 ./precomputed
```

Inside each experiment (folder ``./precomputed/<experiment-id>``), the software runtime for each experiment might also need to be updated due to different compiling environment.
```bash
cd ./sw
cmake .
make clean
make
cd ..
```

To run an experiment using its pre-synthesized hardware design on the FPGA board, go to the corresponding experiment directory and execute the following commands:

```bash
source $SCRIPTDIR/profile
./real_start.sh
./real_sw.sh
```

### 5. Results

Finally, run the following script to summarize the logic, RAM, and DSP utilization, along with the GOPS measurements collected in the previous step.

```bash
bash $SCRIPTDIR/scores/<experiment-id>.sh
```

The output adheres to the following format and can be directly cross-referenced with Table III in the paper.

```
Logic utilization (in ALMs) : 207,520 / 427,200 ( 49 % )
Total RAM Blocks : 943 / 2,713 ( 35 % )
Total DSP Blocks : 1,152 / 1,518 ( 76 % )
GOP/s : 169.936
```

---

## Additional Options (Table III)

The commands above follow the default artifact workflow. 
In addition, the evaluation harness supports several optional paths, such as re-running equality saturation from scratch, re-synthesizing designs with Quartus, or running only a selected subset of experiments. 
These options are independent of the main workflow and can be used as needed to inspect intermediate outputs.

### Re-running equality saturation

Because optimizing each benchmark with equality saturation can take multiple hours, the commands above use a precomputed solution embedded in the container. 
To recompute the solution and save it under `./results/<experiment-id>/eqsat/`, run:

```bash
docker run --rm -it \
  --mount type=bind,src=./results,dst=/workspace/results \
  ghcr.io/jonathanvdc/skeleshare-cgo26-artifact:latest \
  python3 evaluation.py --phase eqsat
```

To generate VHDL code and save it under `./results/<experiment-id>/lowering/`, run:
```bash
docker run --rm -it \
  --mount type=bind,src=./results,dst=/workspace/results \
  ghcr.io/jonathanvdc/skeleshare-cgo26-artifact:latest \
  python3 evaluation.py --phase lowering
```

Note that running all the experiments may take at least 15 hours.

### Re-running synthesis

The server also provides pre-synthesized designs that correspond to the generated VHDL for each experiment. 
To re-synthesize an experiment after Step 3 using Quartus, navigate to the experiment’s `results/lowering` directory and run:

```bash
source $SCRIPTDIR/profile
cp -r $SCRIPTDIR/syntest/* .
mkdir hw/rtl/generated
mv *.vhd *.dat hw/rtl/generated/
```

This step prepares all required files for Quartus synthesis. You can now start synthesis for the current experiment:

```bash
./real.sh
```

Synthesis typically takes 4–8 hours. Once it completes, you can run the design on the FPGA board using:

```bash
./real_start.sh
./real_sw.sh
```

## Step-By-Step Instructions (Figure 12)


To reproduce Figure 12(a), run the following commands to extract the data points for the e-node counts:

```bash
docker run --rm -it \
  --mount type=bind,src=./results,dst=/workspace/results \
  ghcr.io/jonathanvdc/skeleshare-cgo26-artifact:latest \
  python3 evaluation.py --phase figure --only A-vgg-enodes
```

To generate the figure, navigate to the experiment’s `results/A-vgg-enodes/eqsat` directory and run:

```bash
pdflatex $SCRIPTDIR/figures/enodes.tex
```

The command will generate ``enodes.pdf`` which represents Figure 12(a). If users' host terminal support X11 forwarding, they can access the pdf with ``xdg-open ./enodes.pdf``. Otherwise, users have to use ``scp`` to move the figure to their host.

To reproduce Figure 12(b), the artifact provides the following experiment options:
- `B-vgg-saturation`
- `B-vgg-extraction-1to5`
- `B-vgg-extraction-$id` ($id = 6 ~ 14)


Since running the full experiment end-to-end can take several days, we split it into multiple smaller steps.
`B-vgg-saturation` generates the saturation curve shown in Figure 12(b).
The extraction curve in Figure 12(b) is generated by `B-vgg-extraction-1to5`, `B-vgg-extraction-6`, ..., `B-vgg-extraction-14`.
Note that `B-vgg-extraction-7` through `B-vgg-extraction-14` hit the runtime cutoff and therefore report similar runtimes (180 minutes).

Run the following command to extract the data for each of the experimental options listed above:


```bash
docker run --rm -it \
  --mount type=bind,src=./results,dst=/workspace/results \
  ghcr.io/jonathanvdc/skeleshare-cgo26-artifact:latest \
  python3 evaluation.py --phase figure --only <B-vgg-experiment-option>
```

To generate the plot, go to the experiment’s `results/` directory and run:

```bash
cp B-vgg-saturation/eqsat/saturation.csv ./
bash $SCRIPTDIR/figures/concatExtraction.sh
pdflatex $SCRIPTDIR/figures/exploringTime.tex
```

The command will generate ``exploringTime.pdf`` which represents Figure 12(b). If users' host terminal support X11 forwarding, they can access the pdf with ``xdg-open ./exploringTime.pdf``. Otherwise, users have to use ``scp`` to move the figure to their host.

## Running Selected Experiments

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

**Note:**
- Experiments `10-vgg-no-sharing`, `11-vgg-no-padding`, and `12-vgg-no-tiling` are expected to trigger errors during the equality-saturation stage; as a result, they do not produce a lowering stage.
- Experiments `9-stencil-baseline` and `13-vgg-baseline-no-sharing` not include equality saturation, and its synthesis step is expected to fail due to resource limitations.
- Since `13-vgg-baseline-no-sharing` is not synthesizable, it will trigger an error and produce no performance numbers.
- In terms of runtime, the ``stencil`` experiments usually take 2–3 hours, while the ``vgg``, ``tinyyolo``, and ``self-attention`` experiments may take 7–12 hours.
