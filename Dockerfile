FROM ubuntu:22.04
MAINTAINER Weina Ji <weina.ji@epfl.ch>

# The default shell for the RUN instruction is ["/bin/sh", "-c"].
# Using SHELL instruction to change default shell for subsequent RUN instructions
SHELL ["/bin/bash", "-c"]

# Create a workdir directory 
RUN mkdir /workdir

# Install needed libs
RUN apt-get --yes -qq update \
 && apt-get --yes -qq upgrade \
 && apt-get --yes -qq install \
                      g++ \
                      gcc \
                      python3.10 \
                      python3-pip \
                      python3-venv \
                      git \
                      cmake \
                      libreadline-dev \
                      wget \
                      mpich libmpich-dev libhdf5-mpich-dev hdf5-tools

#build venv
RUN cd /workdir \
 && python3 -m venv myenv \
 && source myenv/bin/activate

#pip install libsonata
RUN CC=mpicc CXX=mpic++ pip install git+https://github.com/BlueBrain/libsonata.git@v0.1.22

# Install libsonatareport
RUN cd /workdir \
 && git clone https://github.com/BlueBrain/libsonatareport.git --recursive \
 && cd libsonatareport \
 && mkdir build && cd build \
 && cmake -DCMAKE_INSTALL_PREFIX=$(pwd)/install -DCMAKE_BUILD_TYPE=Release -DSONATA_REPORT_ENABLE_SUBMODULES=ON -DSONATA_REPORT_ENABLE_MPI=ON .. \
 && cmake --build . --parallel \
 && cmake --build . --target install
ENV SONATAREPORT_DIR "/workdir/libsonatareport/build/install"

# Install neuron
RUN cd /workdir \
 && source myenv/bin/activate \ 
 && apt-get --yes -qq update \
 && apt-get --yes -qq install flex libfl-dev bison ninja-build \
 && pip install -U pip setuptools \
 && pip install "cython<3" pytest sympy jinja2 pyyaml\
 && git clone https://github.com/neuronsimulator/nrn.git \
 && cd nrn && mkdir build && cd build \
 && cmake -G Ninja -DPYTHON_EXECUTABLE=$(which python) -DCMAKE_INSTALL_PREFIX=$(pwd)/install -DNRN_ENABLE_MPI=ON -DNRN_ENABLE_INTERVIEWS=OFF \
 -DNRN_ENABLE_CORENEURON=ON -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DCORENRN_ENABLE_REPORTING=ON -DCMAKE_PREFIX_PATH=$SONATAREPORT_DIR .. \
 && cmake --build . --parallel \
 && cmake --build . --target install
ENV PATH "/workdir/nrn/build/install/bin:$PATH"
ENV PYTHONPATH "/workdir/nrn/build/install/lib/python:$PYTHONPATH"

# pip install neurodamus
RUN cd /workdir \
 && git clone  https://github.com/BlueBrain/neurodamus.git\
 && cd neurodamus\
 && pip install .
ENV HOC_LIBRARY_PATH "/opt/src/neurodamus-py/core/hoc:$HOC_LIBRARY_PATH"

# Build model
RUN cd /workdir/neurodamus \
 && wget --output-document="O1_mods.xz" --quiet "https://zenodo.org/record/8026353/files/O1_mods.xz?download=1" \
 && tar -xf O1_mods.xz \
 && cp -r mod tests/share/ \
 && cp core/mod/*.mod tests/share/mod/ \
 && nrnivmodl -coreneuron -incflags '-DENABLE_CORENEURON -I${SONATAREPORT_DIR}/include -I/usr/include/hdf5/mpich -I/usr/lib/x86_64-linux-gnu/mpich' -loadflags '-L${SONATAREPORT_DIR}/lib -lsonatareport -Wl,-rpath,${SONATAREPORT_DIR}/lib -L/usr/lib/x86_64-linux-gnu/hdf5/mpich -lhdf5 -Wl,-rpath,/usr/lib/x86_64-linux-gnu/hdf5/mpich/ -L/usr/lib/x86_64-linux-gnu/ -lmpich -Wl,-rpath,/usr/lib/x86_64-linux-gnu/' tests/share/mod

# #ADD neurodamus_neocortex_multiscale_mod_full.tar.gz /opt/src/
# RUN cd /workdir \
#  && nrnivmodl -incflags "-DDISABLE_REPORTINGLIB -I/opt/conda/include/" -loadflags "-L/opt/conda/lib -L/opt/conda/lib64 -lmpi -lhdf5 -L/opt/src/libsonata/build/install/lib -lsonata" neurodamus_neocortex_multiscale_mod_full/
# ENV PATH "/opt/src/x86_64:$PATH"
# ENV LD_LIBRARY_PATH "/opt/src/x86_64:/opt/src/libsonata/build/install/lib:/opt/conda/lib:/opt/conda/lib64:$LD_LIBRARY_PATH"
# ENV NRNMECH_LIB_PATH "/opt/src/x86_64/libnrnmech.so"
# ENV HDF5_DISABLE_VERSION_CHECK=1
