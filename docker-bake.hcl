# docker-bake.hcl - для параллельной сборки через buildx
# Использование: docker buildx bake

group "default" {
  targets = ["ramalama"]
}

target "ramalama" {
  dockerfile = "Dockerfile"
  tags       = ["ramalama:latest", "ramalama:${timestamp()}"]
  args = {
    BUILDKIT_INLINE_CACHE = "1"
  }
  
  # Кэширование между сборками
  cache-from = [
    "type=registry,ref=ramalama:buildcache"
  ]
  cache-to = [
    "type=registry,ref=ramalama:buildcache,mode=max"
  ]
  
  # Параллельная сборка слоёв
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]
  
  output = ["type=docker"]
}