#!/bin/bash

# Optimized extrajuyp.sh - Only installs packages NOT already in juypterinstall.sh
# This eliminates 211 redundant packages (60.1% reduction)
# Removed duplicates: gymnasium and unstructured (already in juypterinstall.sh)

set -e

echo "🚀 Installing additional packages not covered by juypterinstall.sh..."

# Enhanced ML/AI packages
pip install --no-cache-dir \
    ray[default] vaex bottleneck datashader xarray netCDF4 h5py tables \
    onnxconverter-common jax jaxlib nevergrad cvxpy pulp ortools cvxopt \
    neuralprophet kats ruptures statsforecast darts mlflow hydra-core wandb

# Enhanced NLP packages  
pip install --no-cache-dir \
    stanza flair fasttext ai21 annoy nmslib hnswlib \
    textstat textacy keybert yake rake-nltk lexrank sumy

# Enhanced CV packages
pip install --no-cache-dir \
    opencv-contrib-python pillow-avif-plugin pyvips scikit-video mayavi \
    meshio pyassimp laspy pyntcloud

# Enhanced audio packages
pip install --no-cache-dir \
    noisereduce musdb sphinx-measurement openai-whisper speechrecognition vosk

# Enhanced RL packages (removed duplicate gymnasium)
pip install --no-cache-dir \
    shimmy sb3-contrib stable-baselines3 \
    tianshou "ray[rllib]" dm-control brax manim manimpango \
    pyvista vedo napari "napari[all]"

# Enhanced web frameworks
pip install --no-cache-dir \
    sanic tornado textual-dev

# Enhanced Jupyter packages
pip install --no-cache-dir \
    nbclient nbformat pyflakes autoflake yapf

# Web scraping / automation (unique)
pip install --no-cache-dir \
    playwright selenium webdriver-manager aiohttp httpx "requests[security]" \
    websockets socketio uvloop anyio trio structlog rich-click

# Enhanced parsing packages (removed duplicate unstructured)
pip install --no-cache-dir \
    pyxlsb pandasql pikepdf python-pptx pypandoc reportlab weasyprint \
    xhtml2pdf markdown-it-py mistune mdformat selectolax trafilatura \
    newspaper3k scrapy parsel itemadapter itemloaders splash

# Enhanced database packages
pip install --no-cache-dir \
    sqlmodel duckdb-engine clickhouse-driver clickhouse-connect trino \
    "pyhive[hive]" thrift sasl thrift-sasl graph-tool

# Enhanced cloud packages
pip install --no-cache-dir \
    minio google-cloud-pubsub azure-kusto-data fastavro confluent-kafka \
    kafka-python prefect dagster dlt apache-airflow

# Enhanced security/utils packages
pip install --no-cache-dir \
    marshmallow marshmallow-dataclass rapidjson simplejson cloudpickle \
    nacl pyarrow-hotfix

# Enhanced geospatial packages
pip install --no-cache-dir \
    osmnx movingpandas geovoronoi geoplot geopy mercantile mapclassify \
    dgl dglgo

# Download spaCy models (keeping from original)
python -m spacy download en_core_web_sm
python -m spacy download en_core_web_md

# Install Node.js packages (keeping from original)
npm install -g @jupyter-widgets/jupyterlab-manager

# Install R kernel (keeping from original)
R -e "install.packages('IRkernel', repos='https://cran.rstudio.com/')"
R -e "IRkernel::installspec(user = FALSE)"

# Install Julia kernel (keeping from original)
julia -e 'using Pkg; Pkg.add("IJulia")'

echo "✅ Additional packages installation completed!"

# Verification script (keeping from original)
python3 << 'VERIFY_EOF'
import sys
import importlib

# Test a few key unique packages
test_packages = [
    'ray', 'jax', 'mlflow', 'wandb', 'stanza', 'playwright', 
    'selenium', 'dgl', 'napari'
]

failed = []
for pkg in test_packages:
    try:
        importlib.import_module(pkg)
        print(f"✅ {pkg}")
    except ImportError:
        print(f"❌ {pkg}")
        failed.append(pkg)

if failed:
    print(f"\n⚠️  Failed to import: {failed}")
    sys.exit(1)
else:
    print("\n🎉 All key packages verified successfully!")
VERIFY_EOF
