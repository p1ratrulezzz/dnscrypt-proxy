IMAGE ?= ghcr.io/p1ratrulezzz/dnscrypt-proxy
VERSION ?= 2.1.18
PLATFORMS ?= linux/amd64,linux/arm64,linux/arm/v7
BUILDER ?= dnscrypt-builder

.PHONY: help builder build push load

help:
	@echo "make build   - multi-arch build, no push"
	@echo "make push    - multi-arch build and push $(IMAGE):$(VERSION)"
	@echo "make load    - single-arch build into the local docker"
	@echo "IMAGE=$(IMAGE) VERSION=$(VERSION) PLATFORMS=$(PLATFORMS)"

builder:
	docker buildx inspect $(BUILDER) >/dev/null 2>&1 || \
		docker buildx create --name $(BUILDER) --use
	docker buildx use $(BUILDER)

build: builder
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg VERSION=$(VERSION) \
		-t $(IMAGE):$(VERSION) \
		-t $(IMAGE):latest \
		.

push: builder
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg VERSION=$(VERSION) \
		-t $(IMAGE):$(VERSION) \
		-t $(IMAGE):latest \
		--push \
		.

load: builder
	docker buildx build \
		--platform linux/amd64 \
		--build-arg VERSION=$(VERSION) \
		-t $(IMAGE):$(VERSION) \
		--load \
		.