FROM ubuntu:22.04
MAINTAINER Weina Ji <weina.ji@epfl.ch>

# The default shell for the RUN instruction is ["/bin/sh", "-c"].
# Using SHELL instruction to change default shell for subsequent RUN instructions
SHELL ["/bin/bash", "-c"]

ARG WORKDIR=/opt/software
ARG INSTALL_DIR=/opt/software/install
ARG USR_VENV=$WORKDIR/venv

# Install needed libs
RUN apt-get --yes -qq update \
 && apt-get --yes -qq upgrade \
 && apt-get --yes -qq install \
                      python3.10 \
                      python3-pip \
                      python3-venv \
                      git \
                      cmake \
                      wget \
                      mpich libmpich-dev libhdf5-mpich-dev hdf5-tools \
                      flex libfl-dev bison ninja-build libreadline-dev

RUN python3 -m venv $USR_VENV \
 && source $USR_VENV/bin/activate \
 && pip install -U pip setuptools \
 && pip install -U "cython<3" pytest sympy jinja2 pyyaml numpy \
                   numpy wheel pkgconfig

# Install libsonata
RUN source $USR_VENV/bin/activate \
 && CC=mpicc CXX=mpic++ pip install git+https://github.com/BlueBrain/libsonata

# Install libsonatareport
RUN mkdir -p $WORKDIR \
 && cd $WORKDIR \
 && git clone https://github.com/BlueBrain/libsonatareport.git --recursive \
 && cd libsonatareport \
 && mkdir build && cd build \
 && cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCMAKE_BUILD_TYPE=Release -DSONATA_REPORT_ENABLE_SUBMODULES=ON -DSONATA_REPORT_ENABLE_MPI=ON .. \
 && cmake --build . --parallel \
 && cmake --build . --target install
ENV SONATAREPORT_DIR "$INSTALL_DIR"

# Install neuron
RUN source $USR_VENV/bin/activate \
 && cd $WORKDIR \
 && git clone https://github.com/neuronsimulator/nrn.git \
 && cd nrn && mkdir build && cd build \
 && cmake -DPYTHON_EXECUTABLE=$(which python) -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DNRN_ENABLE_MPI=ON -DNRN_ENABLE_INTERVIEWS=OFF -DNRN_ENABLE_RX3D=OFF \
 -DNRN_ENABLE_CORENEURON=ON -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DCORENRN_ENABLE_REPORTING=ON -DCMAKE_PREFIX_PATH=$SONATAREPORT_DIR .. \
 && cmake --build . -- -j 2 \
 && cmake --build . --target install

# Build h5py with the local hdf5
RUN source $USR_VENV/bin/activate \
 && MPICC="mpicc -shared" pip install --no-cache-dir --no-binary=mpi4py mpi4py \
 && CC="mpicc" HDF5_MPI="ON" HDF5_INCLUDEDIR=/usr/include/hdf5/mpich HDF5_LIBDIR=/usr/lib/x86_64-linux-gnu/hdf5/mpich \
    pip install --no-cache-dir --no-binary=h5py h5py --no-build-isolation

# Install neurodamus and prepare HOC_LIBRARY_PATH
RUN source $USR_VENV/bin/activate \
 && cd $WORKDIR \
 && git clone https://github.com/BlueBrain/neurodamus.git \
 && cd neurodamus \
 && pip install . \
 && cp tests/share/hoc/* core/hoc/
ENV HOC_LIBRARY_PATH "$WORKDIR/neurodamus/core/hoc"
ENV NEURODAMUS_PYTHON "$WORKDIR/neurodamus/"
ENV NEURODAMUS_MODS_DIR "$WORKDIR/neurodamus/core/mod"

ADD build_neurodamus.sh $INSTALL_DIR/

ENV PATH "$INSTALL_DIR:$PATH"
ENV PYTHONPATH "$INSTALL_DIR/python:$PYTHONPATH"

ENTRYPOINT ["bash"]
