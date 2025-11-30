# Unique task identifier
TASK_ID="3e0667c8-16c1-434e-955d-f2cb69b16050"

# Base model to fine-tune (from HuggingFace)
MODEL="cagliostrolab/animagine-xl-4.0"

# Dataset ZIP file location (must be a ZIP file with images)
DATASET_ZIP="https://gradients.s3.eu-north-1.amazonaws.com/e2c467f5aab07e70_train_data.zip?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAVVZOOA7SA4UOFLPI%2F20251127%2Feu-north-1%2Fs3%2Faws4_request&X-Amz-Date=20251127T202810Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Signature=eea840f461d59676d38d6c26713329ec86c5942c6bde62a32662e1921b65b599",

# Model type: "sdxl" or "flux"
MODEL_TYPE="sdxl"

# Optional: Repository name for the trained model
EXPECTED_REPO_NAME="3e0667c8-16c1-434e-955d-f2cb69b16zay1"

# For uploading the outputs
HUGGINGFACE_TOKEN=""
HUGGINGFACE_USERNAME=""
EXPECTED_REPO_NAME="3e0667c8-16c1-434e-955d-f2cb69b16zay1"
LOCAL_FOLDER="/app/checkpoints/$TASK_ID/$EXPECTED_REPO_NAME"

CHECKPOINTS_DIR="$(pwd)/secure_checkpoints"
OUTPUTS_DIR="$(pwd)/outputs"
mkdir -p "$CHECKPOINTS_DIR"
chmod 700 "$CHECKPOINTS_DIR"
mkdir -p "$OUTPUTS_DIR"
chmod 700 "$OUTPUTS_DIR"

# Build the downloader image
# docker build --no-cache -t trainer-downloader -f dockerfiles/trainer-downloader.dockerfile .

# Build the trainer image
# docker build --no-cache -t standalone-image-trainer -f dockerfiles/standalone-image-trainer.dockerfile .

# Build the hf uploader image
# docker build --no-cache -t hf-uploader -f dockerfiles/hf-uploader.dockerfile .

# Download model and dataset
echo "Downloading model and dataset..."
docker run --rm \
  --volume "$CHECKPOINTS_DIR:/cache:rw" \
  --name downloader-image \
  trainer-downloader \
  --task-id "$TASK_ID" \
  --model "$MODEL" \
  --dataset "$DATASET_ZIP" \
  --task-type "ImageTask"

# Run the training
echo "Starting image training..."
docker run --rm --gpus all \
  --security-opt=no-new-privileges \
  --cap-drop=ALL \
  --memory=32g \
  --cpus=8 \
  --network none \
  --env TRANSFORMERS_CACHE=/cache/hf_cache \
  --volume "$CHECKPOINTS_DIR:/cache:rw" \
  --volume "$OUTPUTS_DIR:/app/checkpoints/:rw" \
  --name image-trainer-example \
  standalone-image-trainer \
  --task-id "$TASK_ID" \
  --model "$MODEL" \
  --dataset-zip "$DATASET_ZIP" \
  --model-type "$MODEL_TYPE" \
  --expected-repo-name "$EXPECTED_REPO_NAME" \
  --hours-to-complete 1 \

echo "Uploading model to HuggingFace..."
docker run --rm --gpus all \
  --volume "$OUTPUTS_DIR:/app/checkpoints/:rw" \
  --env HUGGINGFACE_TOKEN="$HUGGINGFACE_TOKEN" \
  --env HUGGINGFACE_USERNAME="$HUGGINGFACE_USERNAME" \
  --env TASK_ID="$TASK_ID" \
  --env EXPECTED_REPO_NAME="$EXPECTED_REPO_NAME" \
  --env LOCAL_FOLDER="$LOCAL_FOLDER" \
  --env HF_REPO_SUBFOLDER="checkpoints" \
  --name hf-uploader \
  hf-uploader
