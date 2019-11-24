group "default" {
  targets = ["controller"]
}

target "controller" {
  platforms = ["linux/amd64", "linux/arm/v7"]
  dockerfile = "Dockerfile"
}
