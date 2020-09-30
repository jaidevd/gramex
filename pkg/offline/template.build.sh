#!/bin/bash
set -e
export OFFLINE=$(pwd)/pkg/offline
# Make the conda recipe and copy it, without the post link files.
export CONDA_RECIPE_DIR=$OFFLINE/_conda_offline_recipe
export CONDA_OUTPUT_DIR=$OFFLINE/_conda_offline_pkg
mkdir $CONDA_RECIPE_DIR
mkdir $CONDA_OUTPUT_DIR

cp $(pwd)/pkg/conda/meta.yaml $CONDA_RECIPE_DIR/
cp $(pwd)/pkg/conda/build.sh $CONDA_RECIPE_DIR/

# Build the package
conda build -c conda-forge --no-test --output-folder $CONDA_OUTPUT_DIR $CONDA_RECIPE_DIR

# Install the package in a new environment, to be backed up
conda create -n offline python=3.7 -y
source $(conda info --base)/etc/profile.d/conda.sh
conda activate offline
python -c "import sys; print(sys.prefix)"

# Install the package
export PIP_DOWNLOAD_CACHE=$OFFLINE/pip
export CONDA_PKGS_DIRS=$OFFLINE/conda
export GRAMEXAPPS_OFFLINE=$OFFLINE/GRAMEXAPPS
export GRAMEXDATA_OFFLINE=$OFFLINE/GRAMEXDATA
mkdir $CONDA_PKGS_DIRS
mkdir $PIP_DOWNLOAD_CACHE
mkdir $GRAMEXAPPS_OFFLINE
mkdir $GRAMEXDATA_OFFLINE

# Install pip packages
{% for req in release.pip %}
pip download --destination-directory $PIP_DOWNLOAD_CACHE "{% raw req %}"
{% end %}

# Install gramex
conda install -c conda-forge -c file://$CONDA_OUTPUT_DIR gramex -y
{% for req in release.pip %}
pip install --use-feature=2020-resolver --no-index --find-links $PIP_DOWNLOAD_CACHE "{% raw req %}"
{% end %}
yarn config set ignore-engines true
gramex setup --all

# Backup $GRAMEXAPPS and $GRAMEXDATA
# Those envvars have to be gathered from a different directory because you're already in the gramex folder;
# So the imports will be incorrect :-/
cd /tmp/
export GRAMEXDATA_SRC=$(python -c "from gramex.config import variables; print(variables['GRAMEXDATA'])")
export GRAMEXAPPS_SRC=$(python -c "from gramex.config import variables; print(variables['GRAMEXAPPS'])")
cd -
cp -R $GRAMEXAPPS_SRC/* $GRAMEXAPPS_OFFLINE/
cp -R $GRAMEXDATA_SRC/* $GRAMEXDATA_OFFLINE/

# Build the archive
tar -jcvf gramex-offline.tar.bz2 -C $OFFLINE .

# Cleanup
conda deactivate