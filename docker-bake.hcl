variable "UNIFI_CONTROLLER_VERSION" {
  default = "latest"
}

group "default" {
  targets = ["controller"]
}

target "controller" {
  platforms = ["linux/amd64", "linux/arm/v7"]
  dockerfile = "Dockerfile"
  args = {
    UNIFI_CONTROLLER_VERSION = "${UNIFI_CONTROLLER_VERSION}"
  }
}
