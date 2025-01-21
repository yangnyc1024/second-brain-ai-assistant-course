ifeq (,$(wildcard .env))
$(error .env file is missing. Please create one based on .env.example)
endif

include .env

export PYTHONPATH = .

# --- Default Values ---

CHECK_DIRS := .
NOTION_LOCAL_DATA_PATH := data/notion
CRAWLED_LOCAL_DATA_PATH := data/crawled


# --- Utilities ---

help:
	@grep -E '^[a-zA-Z0-9 -]+:.*#'  Makefile | sort | while read -r l; do printf "\033[1;32m$$(echo $$l | cut -f 1 -d':')\033[00m:$$(echo $$l | cut -f 2- -d'#')\n"; done

# --- Infrastructure --- 

local-docker-infrastructure-up:
	docker compose up --build -d 

local-docker-infrastructure-stop:
	docker compose stop

local-zenml-server-up:
ifeq ($(shell uname), Darwin)
	OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES uv run zenml login --local
else
	uv run zenml login --local
endif

local-zenml-server-stop:
	uv run zenml logout --local

local-infrastructure-up: local-docker-infrastructure-up local-zenml-server-stop local-zenml-server-up

local-infrastructure-stop: local-docker-infrastructure-down local-zenml-server-down

# --- AWS ---

s3-upload-raw-dataset:  # Upload raw Notion dataset from local folder to S3
	@echo "Uploading raw Notion dataset to S3 bucket: $(AWS_S3_BUCKET_NAME)/second_brain_course/notion"
	uv run python -m tools.use_s3 upload $(NOTION_LOCAL_DATA_PATH) $(AWS_S3_BUCKET_NAME) --s3-prefix second_brain_course/notion

s3-download-raw-dataset:  # Download raw Notion dataset from S3 to local folder
	@echo "Downloading raw Notion dataset from S3 bucket: $(AWS_S3_BUCKET_NAME)/second_brain_course/notion/notion.zip"
	uv run python -m tools.use_s3 download $(AWS_S3_BUCKET_NAME) second_brain_course/notion/notion.zip $(NOTION_LOCAL_DATA_PATH)

s3-upload-crawled-dataset:  # Upload processed crawled dataset from local folder to S3
	@echo "Uploading crawled dataset to S3 bucket: $(AWS_S3_BUCKET_NAME)/second_brain_course/crawled"
	uv run python -m tools.use_s3 upload $(CRAWLED_LOCAL_DATA_PATH) $(AWS_S3_BUCKET_NAME) --s3-prefix second_brain_course/crawled

s3-download-crawled-dataset:  # Download processed crawled dataset from S3 to local folder
	@echo "Downloading crawled dataset from S3 bucket: $(AWS_S3_BUCKET_NAME)/second_brain_course/crawled/crawled.zip"
	uv run python -m tools.use_s3 download $(AWS_S3_BUCKET_NAME) second_brain_course/crawled/crawled.zip $(CRAWLED_LOCAL_DATA_PATH)

download-raw-dataset: s3-download-raw-dataset

download-crawled-dataset: s3-download-crawled-dataset

# --- Pipelines ---

collect-notion-data-pipeline:
	uv run python -m tools.run --run-collect-notion-data-pipeline --no-cache

etl-pipeline:
	uv run python -m tools.run --run-etl-pipeline --no-cache

etl-precomputed-pipeline:
	uv run python -m tools.run --run-etl-precomputed-pipeline --no-cache

generate-dataset-pipeline:
	uv run python -m tools.run --run-generate-dataset-pipeline --no-cache

compute-rag-vector-index-pipeline:
	uv run python -m tools.run --run-compute-rag-vector-index-pipeline --no-cache

# --- Tests ---

test:
	uv run pytest tests/

# --- QA ---

format-fix:
	uv run ruff format $(CHECK_DIRS)
	uv run ruff check --select I --fix 

lint-fix:
	uv run ruff check --fix

format-check:
	uv run ruff format --check $(CHECK_DIRS) 
	uv run ruff check -e
	uv run ruff check --select I -e

lint-check:
	uv run ruff check $(CHECK_DIRS)
