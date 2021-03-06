# Modified version of the jupyter/datascience-notebook, removing R and adding
# some Julia packages

# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.
ARG BASE_CONTAINER=jupyter/scipy-notebook
FROM $BASE_CONTAINER

# LABEL maintainer="fforcher"

# Set when building on Travis so that certain long-running build steps can
# be skipped to shorten build time.
ARG TEST_ONLY_BUILD

# Set this variable to install CUDA support
ARG USE_CUDA

# Fix DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

# R pre-requisites
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    fonts-dejavu \
    gfortran \
    gcc \
    gdb \
    rr \
    && \
    rm -rf /var/lib/apt/lists/*

# Julia dependencies
# install Julia packages in /opt/julia instead of $HOME
ENV JULIA_DEPOT_PATH=/opt/julia
ENV JULIA_PKGDIR=/opt/julia
ENV JULIA_VERSION=1.5.0
# For Julia 1.4.1
#ARG JULIA_CHECKSUM = fd6d8cadaed678174c3caefb92207a3b0e8da9f926af6703fb4d1e4e4f50610a
# For Julia 1.5.0
ARG JULIA_CHECKSUM=be7af676f8474afce098861275d28a0eb8a4ece3f83a11027e3554dcdecddb91

WORKDIR /tmp

# hadolint ignore=SC2046
RUN mkdir "/opt/julia-${JULIA_VERSION}" && \
    wget -q https://julialang-s3.julialang.org/bin/linux/x64/$(echo "${JULIA_VERSION}" | cut -d. -f 1,2)"/julia-${JULIA_VERSION}-linux-x86_64.tar.gz" && \
    echo "${JULIA_CHECKSUM} *julia-${JULIA_VERSION}-linux-x86_64.tar.gz" | sha256sum -c - && \
    tar xzf "julia-${JULIA_VERSION}-linux-x86_64.tar.gz" -C "/opt/julia-${JULIA_VERSION}" --strip-components=1 && \
    rm "/tmp/julia-${JULIA_VERSION}-linux-x86_64.tar.gz"
RUN ln -fs /opt/julia-*/bin/julia /usr/local/bin/julia

# Show Julia where conda libraries are \
RUN mkdir /etc/julia && \
    echo "push!(Libdl.DL_LOAD_PATH, \"$CONDA_DIR/lib\")" >> /etc/julia/juliarc.jl && \
    # Create JULIA_PKGDIR \
    mkdir "${JULIA_PKGDIR}" && \
    chown "${NB_USER}" "${JULIA_PKGDIR}" && \
    fix-permissions "${JULIA_PKGDIR}"

USER $NB_UID

# R packages including IRKernel which gets installed globally.
# RUN conda install --quiet --yes \
#     'r-base=3.6.3' \
#     'r-caret=6.0*' \
#     'r-crayon=1.3*' \
#     'r-devtools=2.3*' \
#     'r-forecast=8.12*' \
#     'r-hexbin=1.28*' \
#     'r-htmltools=0.4*' \
#     'r-htmlwidgets=1.5*' \
#     'r-irkernel=1.1*' \
#     'r-nycflights13=1.0*' \
#     'r-plyr=1.8*' \
#     'r-randomforest=4.6*' \
#     'r-rcurl=1.98*' \
#     'r-reshape2=1.4*' \
#     'r-rmarkdown=2.1*' \
#     'r-rsqlite=2.2*' \
#     'r-shiny=1.4*' \
#     'r-tidyverse=1.3*' \
#     'rpy2=3.1*' \
#     && \
#     conda clean --all -f -y && \
#     fix-permissions "${CONDA_DIR}" && \
#     fix-permissions "/home/${NB_USER}"

# Do not install the R stuff, install diffeqpy
RUN pip --quiet --no-cache-dir install diffeqpy \
    && \
    conda clean --all -f -y && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

# Add Julia packages. Only add HDF5 if this is not a test-only build since
# it takes roughly half the entire build time of all of the images on Travis
# to add this one package and often causes Travis to timeout.
#
# Install IJulia as jovyan and then move the kernelspec out
# to the system share location. Avoids problems with runtime UID change not
# taking effect properly on the .local folder in the jovyan home dir.

# Julia Packages added here (except HDF5 and IJulia, already present)
RUN julia -e 'import Pkg; Pkg.update()' && \
    (test $TEST_ONLY_BUILD || test ! $USE_CUDA ||  julia -e 'import Pkg; Pkg.add("CUDA")') && \
    (test $TEST_ONLY_BUILD || julia -e 'import Pkg; Pkg.add("HDF5")') && \
    (test $TEST_ONLY_BUILD || julia -e 'import Pkg; Pkg.add("JLD2")') && \
    (test $TEST_ONLY_BUILD || julia -e 'import Pkg; Pkg.add("PyCall")') && \
    (test $TEST_ONLY_BUILD || julia -e 'import Pkg; Pkg.add("CxxWrap")') && \
    (test $TEST_ONLY_BUILD || julia -e 'import Pkg; Pkg.add("IterableTables")') && \
    (test $TEST_ONLY_BUILD || julia -e 'import Pkg; Pkg.add("DifferentialEquations")') && \
    (test $TEST_ONLY_BUILD || julia -e 'import Pkg; Pkg.add("Plots")') && \
    (test $TEST_ONLY_BUILD || julia -e 'import Pkg; Pkg.add("StatProfilerHTML")') && \
    (test $TEST_ONLY_BUILD || julia -e 'import Pkg; Pkg.add("Traceur")') && \
    (test $TEST_ONLY_BUILD || julia -e 'import Pkg; Pkg.add("DynamicalSystems")') && \
    (test $TEST_ONLY_BUILD || julia -e 'import Pkg; Pkg.add("Distributions")') && \
    (test $TEST_ONLY_BUILD || julia -e 'import Pkg; Pkg.add("Flux")') && \
    julia -e "using Pkg; pkg\"add IJulia\"; pkg\"precompile\"" && \
    # move kernelspec out of home \
    mv "${HOME}/.local/share/jupyter/kernels/julia"* "${CONDA_DIR}/share/jupyter/kernels/" && \
    chmod -R go+rx "${CONDA_DIR}/share/jupyter" && \
    rm -rf "${HOME}/.local" && \
    fix-permissions "${JULIA_PKGDIR}" "${CONDA_DIR}/share/jupyter"

WORKDIR $HOME
