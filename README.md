# Neurodamus Docker Image
This repository provides the Docker recipe for the [Neurodamus](https://github.com/BlueBrain/neurodamus) project.

## Requirements
You must have:
* [Docker Desktop](https://www.docker.com/) installed and running.
* [Git](https://git-scm.com/)

## Docker image
You can either build your own docker image using the recipe in this repository or pull the image that we prebuilt on Docker Hub. 

### Option 1: Build your docker image
Before building your own docker image, you need to configure the memory limit for the Docker Desktop to be at least 4GB. (Settings->Resources->Memory) 
```
git clone <docker recipe repo>
cd <folder of DockerFile>
docker build -t neurodamus .
```
### Option 2: Pull the image from docker hub
```
docker pull weinaji weinaji/neurodamus:0.0.2
```
You can verify your image with the command `docker image ls`, for example:
```
$ docker image ls
REPOSITORY                            TAG       IMAGE ID       CREATED        SIZE
weinaji/neurodamus                    0.0.2     4784d73155e7   11 hours ago   4.08GB
```
## Run your neurodamus docker containier
We start a neurodamus container with an interative Bash shell from the docker image, and meanwhile mount your local folder which contains your mod files and circuit data.
```
docker run --rm -it --entrypoint bash -v <folder_mods_circuit>:/mnt/mydata weinaji/neurodamus:0.0.2
```
In the Bash shell, first build your mods:
```
cd /mnt/mydata/
cp $EXTRA_MODS_DIR/* <your_mod_dir>/
build_neurodamus.sh <your_mod_dir>/
```
Then we are ready to start the simulation.

To run with a single process
```
./x86_64/special -mpi -python $NEURODAMUS_PYTHON/init.py --configFile=<your_folder>/simulation_config.json
```
Or to run with multiple processes in parallel, e.g. 4 processes
```
mpirun -np 4 ./x86_64/special -mpi -python $NEURODAMUS_PYTHON/init.py --configFile=<your_folder>/simulation_config.json
```
