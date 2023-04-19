GITSHA1:=$(shell git rev-parse --short HEAD)
IMAGE_PROD=negeric/postgres-s3cmd-backup
.PHONY: image
image:
	GITSHA1=$(GITSHA1) \
		docker buildx build \
		--platform linux/amd64 \
		-t $(IMAGE_PROD):$(GITSHA1) \
		-t $(IMAGE_PROD):latest \
		--push \
		-f docker/Dockerfile.prod .
	