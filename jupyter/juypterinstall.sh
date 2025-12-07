set -e

echo "=== System deps ==="
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential cmake pkg-config gcc g++ make \
  curl wget git git-lfs ca-certificates unzip \
  python3-dev python3-tk \
  nodejs npm \
  libgl1-mesa-glx libglu1-mesa libgles2-mesa libegl1 \
  libx11-6 libxext6 libsm6 libxrender1 libxi6 libxrandr2 libxxf86vm1 \
  freeglut3-dev mesa-utils xvfb \
  libasound2 libasound2-dev libpulse0 libportaudio2 portaudio19-dev \
  ffmpeg gstreamer1.0-tools gstreamer1.0-libav \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
  tesseract-ocr poppler-utils \
  libjpeg-turbo-progs libpng16-16 libtiff5 \
  graphviz \
  libssl-dev zlib1g-dev \
  openjdk-17-jre-headless \
  r-base r-base-dev \
  julia \
  locales libmagic1 \
  && rm -rf /var/lib/apt/lists/*

python -m pip install --upgrade pip wheel setuptools

echo "=== Core scientific / data / ML ==="
pip install --no-cache-dir \
  numpy scipy pandas polars pyarrow fastparquet dask[complete] \
  scikit-learn scikit-image statsmodels numba numexpr \
  matplotlib seaborn plotly bokeh altair holoviews hvplot panel \
  xgboost lightgbm catboost \
  torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu \
  onnx onnxruntime \
  tensorflow-cpu || true

echo "=== NLP / LLM tooling ==="
pip install --no-cache-dir \
  transformers datasets accelerate peft diffusers \
  sentence-transformers tiktoken \
  spacy spacy-lookups-data \
  nltk gensim \
  openai anthropic google-generativeai together || true

python - <<'PY'
import sys, spacy
try:
    spacy.cli.download("en_core_web_sm")
except SystemExit:
    pass
PY

echo "=== CV / imaging / 3D ==="
pip install --no-cache-dir \
  opencv-python imageio imageio-ffmpeg pillow tifffile pyheif \
  pyopengl PyOpenGL_accelerate moderngl moderngl-window vispy \
  pythreejs ipycanvas ipyevents ipyvtklink vtk \
  shapely pyrr trimesh pyrender open3d \
  rembg onnxruntime-gpu || true

echo "=== Audio / speech / DSP ==="
pip install --no-cache-dir \
  sounddevice soundfile pyaudio librosa resampy audioread \
  pydub aubio \
  faster-whisper TTS \
  torchaudio==2.4.1 --index-url https://download.pytorch.org/whl/cpu || true

echo "=== RL / simulation / games ==="
pip install --no-cache-dir \
  pygame pyglet arcade ursina panda3d panda3d-gltf panda3d-simplepbr kivy \
  Box2D-py pymunk pybullet mujoco \
  gymnasium gymnasium[atari,accept-rom-license] \
  pettingzoo supersuit \
  simpy gymnax || true

echo "=== Dashboards / apps / serving ==="
pip install --no-cache-dir \
  streamlit dash gradio fastapi uvicorn[standard] starlette \
  flask waitress gunicorn \
  nicegui textual rich loguru typer click

echo "=== Jupyter / notebooks / authoring ==="
pip install --no-cache-dir \
  jupyter jupyterlab ipykernel ipywidgets jupytext nbconvert papermill \
  jupyterlab-git jupyter-resource-usage jupyterlab_execute_time \
  jupyterlab_code_formatter \
  nbqa black isort ruff pylint mypy

# JupyterLab extensions (Lab 4+ prefers prebuilt; these just register)
jupyter labextension install @jupyterlab/toc @ryantam626/jupyterlab_code_formatter || true

echo "=== Geospatial ==="
pip install --no-cache-dir \
  pyproj shapely fiona rasterio geopandas rtree contextily \
  folium keplergl leafmap || true

echo "=== Parsing / ETL / docs ==="
pip install --no-cache-dir \
  openpyxl xlsxwriter xlrd \
  pypdf pdfminer.six pymupdf \
  pytesseract \
  python-docx docx2txt mammoth \
  unstructured unstructured[pdf,docx,pptx,md] \
  camelot-py[cv] tabula-py pdfplumber \
  markdown beautifulsoup4 lxml html5lib \
  regex rapidfuzz

echo "=== Databases / search / graphs ==="
pip install --no-cache-dir \
  sqlalchemy alembic \
  psycopg2-binary pymysql oracledb==2.* || true \
  sqlite-utils duckdb \
  pymongo redis cassandra-driver \
  elasticsearch opensearch-py \
  faiss-cpu chromadb qdrant-client weaviate-client \
  neo4j py2neo networkx python-igraph || true

echo "=== Cloud SDK clients ==="
pip install --no-cache-dir \
  boto3 botocore s3fs \
  google-cloud-storage google-cloud-bigquery google-cloud-aiplatform \
  azure-storage-blob azure-identity || true

echo "=== MLOps / vector / LLM frameworks ==="
pip install --no-cache-dir \
  langchain langchain-core langchain-community langchain-text-splitters \
  llama-index llama-index-llms-openai llama-index-embeddings-huggingface \
  milvus pymilvus \
  sentencepiece faiss-cpu \
  deepspeed bitsandbytes || true

echo "=== Optimization / stats / forecasting ==="
pip install --no-cache-dir \
  optuna scikit-optimize hyperopt bayesian-optimization \
  prophet pmdarima orbit-ml fbprophet || true

echo "=== Packaging / testing / CLI ==="
pip install --no-cache-dir \
  pyinstaller pyoxidizer || true \
  pytest pytest-cov hypothesis tox pre-commit \
  fire

echo "=== Security / crypto / utils ==="
pip install --no-cache-dir \
  cryptography pyjwt pynacl \
  pydantic pydantic-settings dataclasses-json \
  orjson ujson msgpack \
  tenacity dill joblib tqdm rich

echo "=== R kernel & common R pkgs ==="
R -q -e "install.packages(c('IRkernel','tidyverse','data.table','arrow','DBI','RPostgres','reticulate'), repos='https://cloud.r-project.org')" || true
R -q -e "IRkernel::installspec(user = FALSE, name = 'ir', displayname = 'R (IRkernel)')" || true

echo "=== Julia IJulia kernel & basics ==="
julia -e 'using Pkg; Pkg.add(["IJulia","DataFrames","CSV","Plots","StatsBase","Flux"]); using IJulia;' || true

echo "=== Clean caches ==="
apt-get clean && rm -rf /root/.cache/pip

echo "=== Smoke test: import a broad set ==="
python - <<'PY'
mods = [
 "numpy","pandas","polars","pyarrow","dask","sklearn","statsmodels","numba",
 "matplotlib","seaborn","plotly","bokeh","altair","panel","hvplot","holoviews",
 "torch","onnxruntime","transformers","datasets","sentence_transformers","tiktoken",
 "spacy","nltk","opencv-python","PIL","imageio","vtk","trimesh","pyrender",
 "sounddevice","soundfile","pyaudio","librosa",
 "pygame","pybullet","gymnasium","pettingzoo",
 "streamlit","dash","gradio","fastapi","uvicorn",
 "jupyter","ipywidgets","jupytext","nbconvert",
 "geopandas","shapely","rasterio","pyproj","folium",
 "pypdf","pdfminer","fitz","pytesseract","python_docx","bs4","lxml",
 "sqlalchemy","psycopg2","pymysql","duckdb","pymongo","redis",
 "elasticsearch","faiss","chromadb","qdrant_client","neo4j",
 "boto3","google.cloud.storage","google.cloud.bigquery","azure.storage.blob",
 "langchain","llama_index","optuna","prophet","pmdarima","hyperopt","scikit_optimize",
 "cryptography","pyjwt","pydantic","orjson","ujson","msgpack"
]
ok, bad = [], []
for m in mods:
    try:
        __import__(m)
        ok.append(m)
    except Exception as e:
        bad.append((m, str(e)))
print("✅ OK:", len(ok), "modules")
if bad:
    print("❌ Failed imports:")
    [print(" -", m, "->", err[:140]) for m,err in bad]
else:
    print("🎉 All smoke-test imports passed.")
PY

echo "=== Done. Tip: for headless graphics use xvfb-run ... ==="