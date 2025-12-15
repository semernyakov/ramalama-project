variable "IMAGE_NAME" {
  default = "ramalama"
}

variable "IMAGE_TAG" {
  default = "latest"
}

variable "HTTP_PROXY" {
  default = ""
}

variable "HTTPS_PROXY" {
  default = ""
}

variable "NO_PROXY" {
  default = "localhost,127.0.0.0/8,::1"
}

variable "CACHE_DIR" {
  default = "/tmp/.buildx-cache"
}

group "default" {
  targets = ["ramalama"]
}

target "_common" {
  args = {
    HTTP_PROXY              = "${HTTP_PROXY}"
    HTTPS_PROXY             = "${HTTPS_PROXY}"
    NO_PROXY                = "${NO_PROXY}"
    BUILDKIT_INLINE_CACHE   = "1"
  }
  
  contexts = {
    python = "docker-image://python:3.11-slim-bookworm"
  }
}

# ============================================
# RamaLama targets
# ============================================
target "ramalama" {
  inherits = ["_common"]
  
  context    = "./ramalama"
  dockerfile = "Dockerfile"
  
  tags = [
    "${IMAGE_NAME}:${IMAGE_TAG}",
    "${IMAGE_NAME}:latest"
  ]

  cache-from = [
    "type=local,src=${CACHE_DIR}/ramalama"
  ]

  cache-to = [
    "type=local,dest=${CACHE_DIR}/ramalama-new,mode=max,oci-mediatypes=true,compression=zstd,compression-level=3",
    "type=inline"
  ]
  
  output = ["type=docker"]
  platforms = ["linux/amd64"]
}

target "ramalama-dev" {
  inherits = ["_common"]
  
  context    = "./ramalama"
  dockerfile = "Dockerfile"
  
  tags = ["${IMAGE_NAME}:dev"]
  
  no-cache = true
  output   = ["type=docker"]
}

target "ramalama-fast" {
  inherits = ["_common"]
  
  context    = "./ramalama"
  dockerfile = "Dockerfile"
  
  tags = ["${IMAGE_NAME}:${IMAGE_TAG}"]
  
  cache-from = ["type=inline"]
  cache-to   = ["type=inline"]
  
  output = ["type=docker"]
}

# ============================================
# Pull llama.cpp images (no build)
# ============================================
target "llama-cpp-pull" {
  name = "llama-cpp-${variant}"
  
  matrix = {
    variant = ["full", "full-cuda"]
  }
  
  context = "."
  
  dockerfile-inline = <<-EOT
    FROM ghcr.io/ggml-org/llama.cpp:${variant}
  EOT
  
  tags = ["llama-cpp:${variant}"]
  
  output = ["type=docker"]
}
