# syntax=docker/dockerfile:1
# Initialize device type args
# use build args in the docker build commmand with --build-arg="BUILDARG=true"
ARG USE_CUDA=true
ARG USE_OLLAMA=false
# Tested with cu117 for CUDA 11 and cu121 for CUDA 12 (default)
ARG USE_CUDA_VER=cu121
ARG CACHEBUST

# any sentence transformer model; models to use can be found at https://huggingface.co/models?library=sentence-transformers
# Leaderboard: https://huggingface.co/spaces/mteb/leaderboard 
# default: sentence-transformers/all-MiniLM-L6-v2 BUT for better performance and multilangauge support use "intfloat/multilingual-e5-large" (~2.5GB) or "intfloat/multilingual-e5-base" (~1.5GB)
# IMPORTANT: If you change the embedding model (sentence-transformers/all-MiniLM-L6-v2) and vice versa, you aren't able to use RAG Chat with your previous documents loaded in the WebUI! You need to re-embed them.
ARG USE_EMBEDDING_MODEL=intfloat/multilingual-e5-large 
ARG USE_RERANKING_MODEL=""

# Tiktoken encoding name; models to use can be found at https://huggingface.co/models?library=tiktoken
ARG USE_TIKTOKEN_ENCODING_NAME="cl100k_base"

ARG BUILD_HASH=dev-build
# Override at your own risk - non-root configurations are untested
ARG UID=0
ARG GID=0


######## WebUI frontend ########
FROM --platform=$BUILDPLATFORM node:22-alpine3.20 AS build
ARG BUILD_HASH

WORKDIR /app
RUN echo "$CACHEBUST"

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
ENV APP_BUILD_HASH=${BUILD_HASH}
RUN npm run build

######## WebUI backend ########
FROM python:3.11-slim-bookworm AS base

# Use args
ARG USE_CUDA
ARG USE_OLLAMA
ARG USE_CUDA_VER
ARG USE_EMBEDDING_MODEL
ARG USE_RERANKING_MODEL
ARG UID
ARG GID

## Basis ##
ENV ENV=prod \
    PORT=8080 \
    # pass build args to the build
    USE_OLLAMA_DOCKER=${USE_OLLAMA} \
    USE_CUDA_DOCKER=${USE_CUDA} \
    USE_CUDA_DOCKER_VER=${USE_CUDA_VER} \
    USE_EMBEDDING_MODEL_DOCKER=${USE_EMBEDDING_MODEL} \
    USE_RERANKING_MODEL_DOCKER=${USE_RERANKING_MODEL}

## Basis URL Config ##
ENV OLLAMA_BASE_URL="/ollama" \
    OPENAI_API_BASE_URL="https://api.openai.com/v1"

## API Key and Security Config ##
ENV OPENAI_API_KEY="" \
    WEBUI_SECRET_KEY="" \
    SCARF_NO_ANALYTICS=true \
    DO_NOT_TRACK=true \
    ANONYMIZED_TELEMETRY=false

#### Other models #########################################################
## whisper TTS model settings ##

ENV WHISPER_MODEL="ivrit-ai/faster-whisper-v2-d3-e3" \
    KMP_DUPLICATE_LIB_OK=true \
    PYTORCH_CUDA_ALLOC_CONF="max_split_size_mb:32,garbage_collection_threshold:0.8" \
    WHISPER_MODEL_DIR="/app/backend/data/cache/whisper/models"

# ENV WHISPER_MODEL="base" \
#      WHISPER_MODEL_DIR="/app/backend/data/cache/whisper/models"

## RAG Embedding model settings ##
ENV RAG_EMBEDDING_MODEL="$USE_EMBEDDING_MODEL_DOCKER" \
    RAG_RERANKING_MODEL="$USE_RERANKING_MODEL_DOCKER" \
    SENTENCE_TRANSFORMERS_HOME="/app/backend/data/cache/embedding/models"

## Tiktoken model settings ##
ENV TIKTOKEN_ENCODING_NAME="cl100k_base" \
    TIKTOKEN_CACHE_DIR="/app/backend/data/cache/tiktoken"

## Hugging Face download cache ##
ENV HF_HOME="/app/backend/data/cache/embedding/models"

## Torch Extensions ##
# ENV TORCH_EXTENSIONS_DIR="/.cache/torch_extensions"

#### Other models ##########################################################

## ilan added variables ##
## ilan GROQ key ##
ENV GROQ_API_BASE_URL="https://api.groq.com/openai/v1"
ENV GROQ_API_KEY=""
## ilan ANTHROPIC key ##
ENV ANTHROPIC_API_KEY=""
ENV ANTROPHIC_BASE_URL="https://api.anthropic.com/v1/messages"
## ilan openweather key ##
ENV OPENWEATHERMAP_API_KEY=""
## ilan GOOGLE SEARCH key ##
ENV GOOGLE_API_KEY=""
ENV GOOGLE_SEARCH_ID=""
## ilan WOLFARM key ##
ENV WOLFRAM_APP_ID=""
ENV WOLFARM_BASE_URL="https://www.wolframalpha.com/api/v1/llm-api"
## ilan TAVILIY key ##
ENV TAVILIY_BASE_URL="https://api.tavily.com/"
ENV TAVILIY_SEARCH_API_KEY=""
## ilan SERPLY key ##
ENV SERPLY_BASE_URL="api.serply.io/v1/search/q=search+api"
ENV SERPLY_SEARCH_APY_KEY=""
## ilan BRAVE SEARCH key ##
ENV BRAVE_SEARCH_API_KEYBASE_URL="https://api.search.brave.com/res/v1/web/search"
ENV BRAVE_SEARCH_VIDEO_URL="https://api.search.brave.com/res/v1/videos/search"
ENV BRAVE_SEARCH_IMAGE_URL="https://api.search.brave.com/res/v1/images/search"
ENV BRAVE_SEARCH_API_KEY=""
## ilan SERPER key ##
ENV SERPER_BASE_URL="https://google.serper.dev/search"
ENV SERPER_SEARCH_API_KEY=""
## ilan JINA key ##
ENV JINA_BASE_URL="https://r.jina.ai/"
ENV JINA_SEARCH_URL="https://s.jina.ai"
ENV JINA_SEARCH_API_KEY=""
## ilan BING SEARCH key ##
ENV BING_BASE_URL="https://api.bing.microsoft.com/v7.0/search"
ENV BING_SEARCH_API_KEY=""
## ilan MISTRAL key ##
ENV MISTRAL_BASE_URL="https://api.mistral.ai/v1/chat/completions"
ENV MISTRAL_API_KEY=""
## ilan FINNHUB key ## 
ENV FINNHUB_API_KEY=""


## Local Ollama API ENDPOINTS by ilan ##
ENV OLLAMA_API_BASE_URL="http://localhost:11434/api"
ENV OLLAMA_API_EMBEDDINGS_URL="http://localhost:11434/api/embeddings" 
ENV OLLAMA_API_ENDPOINT_URL="http://localhost:11434/api/generate"
ENV OLLAMA_API_CHAT_ENDPOINT_URL="http://localhost:11434/api/chat"
ENV OLLAMA_API_ENDPOINT_URLS="http://localhost:11434/api/urls"
ENV OLLAMA_API_ENDPOINT_UPDATE_URLS="http://localhost:11434/api/urls/update"
ENV OLLAMA_API_ENDPOINT_CONFIG_URL="http://localhost:11434/api/config" 
ENV OLLAMA_API_ENDPOINT_CONFIG_UPDATE_URL="http://localhost:11434/api/config/update"
ENV OLLAMA_API_VERSION_URL="http://localhost:11434/api/version"
ENV OLLAMA_API_TAGS_URL="http://localhost:11434/api/tags"
ENV OLLAMA_API_CREATE_URL="http://localhost:11434/api/create"
ENV OLLAMA_API_DELETE_URL="http://localhost:11434/api/delete"
ENV OLLAMA_API_PULL_URL="http://localhost:11434/api/pull"
ENV OLLAMA_API_MODELS_DOWNLOAD_URL="http://localhost:11434/api/models/download"
ENV OLLAMA_API_MODELS_UPLOAD_URL="http://localhost:11434/api/models/upload"
ENV USE_OLLAMA_DOCKER="false"
ENV CORS_ALLOW_ORIGIN="*"

WORKDIR /app/backend

ENV HOME=/root
# Create user and group if not root
RUN if [ $UID -ne 0 ]; then \
    if [ $GID -ne 0 ]; then \
    addgroup --gid $GID app; \
    fi; \
    adduser --uid $UID --gid $GID --home $HOME --disabled-password --no-create-home app; \
    fi

RUN mkdir -p $HOME/.cache/chroma
RUN echo -n 00000000-0000-0000-0000-000000000000 > $HOME/.cache/chroma/telemetry_user_id

# Make sure the user has access to the app and root directory
RUN chown -R $UID:$GID /app $HOME

# RUN if [ "$USE_OLLAMA" = "true" ]; then \
#     apt-get update && \
#     # Install pandoc and netcat
#     apt-get install -y --no-install-recommends git build-essential pandoc netcat-openbsd curl && \
#     apt-get install -y --no-install-recommends gcc python3-dev && \
#     # for RAG OCR
#     apt-get install -y --no-install-recommends ffmpeg libsm6 libxext6 && \
#     # install helper tools
#     apt-get install -y --no-install-recommends curl jq && \
#     # install ollama
#     curl -fsSL https://ollama.com/install.sh | sh && \
#     # cleanup
#     rm -rf /var/lib/apt/lists/*; \
#     else \
#     apt-get update && \
#     # Install pandoc, netcat and gcc
#     apt-get install -y --no-install-recommends git build-essential pandoc gcc netcat-openbsd curl jq && \
#     apt-get install -y --no-install-recommends gcc python3-dev && \
#     # for RAG OCR
#     apt-get install -y --no-install-recommends ffmpeg libsm6 libxext6 && \
#     # cleanup
#     rm -rf /var/lib/apt/lists/*; \
#     fi

#Install build dependencies and other necessary packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    g++ \
    pandoc \
    netcat-openbsd \
    curl \
    jq \
    gcc \
    python3-dev \
    ffmpeg \
    libsm6 \
    libxext6 && \
    if [ "$USE_OLLAMA" = "true" ]; then \
    curl -fsSL https://ollama.com/install.sh | sh; \
    fi && \
    rm -rf /var/lib/apt/lists/*

# install python dependencies
COPY --chown=$UID:$GID ./backend/requirements.txt ./requirements.txt

RUN pip3 install uv && \
    if [ "$USE_CUDA" = "true" ]; then \
    # If you use CUDA the whisper and embedding model will be downloaded on first use
    pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/$USE_CUDA_DOCKER_VER --no-cache-dir && \
    uv pip install --system -r requirements.txt --no-cache-dir && \
    python -c "import os; from sentence_transformers import SentenceTransformer; SentenceTransformer(os.environ['RAG_EMBEDDING_MODEL'], device='cpu')" && \
    python -c "import os; from faster_whisper import WhisperModel; WhisperModel(os.environ['WHISPER_MODEL'], device='cpu', compute_type='int8', download_root=os.environ['WHISPER_MODEL_DIR'])"; \
    python -c "import os; import tiktoken; tiktoken.get_encoding(os.environ['TIKTOKEN_ENCODING_NAME'])"; \
    else \
    pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu --no-cache-dir && \
    uv pip install --system -r requirements.txt --no-cache-dir && \
    python -c "import os; from sentence_transformers import SentenceTransformer; SentenceTransformer(os.environ['RAG_EMBEDDING_MODEL'], device='cpu')" && \
    python -c "import os; from faster_whisper import WhisperModel; WhisperModel(os.environ['WHISPER_MODEL'], device='cpu', compute_type='int8', download_root=os.environ['WHISPER_MODEL_DIR'])"; \
    python -c "import os; import tiktoken; tiktoken.get_encoding(os.environ['TIKTOKEN_ENCODING_NAME'])"; \
    fi; \
    chown -R $UID:$GID /app/backend/data/



# copy embedding weight from build
# RUN mkdir -p /root/.cache/chroma/onnx_models/all-MiniLM-L6-v2
# COPY --from=build /app/onnx /root/.cache/chroma/onnx_models/all-MiniLM-L6-v2/onnx

# Ensure the data directory exists and has correct permissions
RUN mkdir -p /app/backend/data && chown -R $UID:$GID /app/backend/data

# copy built frontend files
COPY --chown=$UID:$GID --from=build /app/build /app/build
COPY --chown=$UID:$GID --from=build /app/CHANGELOG.md /app/CHANGELOG.md
COPY --chown=$UID:$GID --from=build /app/package.json /app/package.json

# copy backend files
COPY --chown=$UID:$GID ./backend .

EXPOSE 8080

HEALTHCHECK CMD curl --silent --fail http://localhost:${PORT:-8080}/health | jq -ne 'input.status == true' || exit 1

USER $UID:$GID

ARG BUILD_HASH
ENV WEBUI_BUILD_VERSION=${BUILD_HASH}
ENV DOCKER=true

CMD [ "bash", "start.sh"]