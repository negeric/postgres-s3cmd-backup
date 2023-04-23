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
		-f Dockerfile .
	
.PHONY: test-image
test-image:
	GITSHA1=$(GITSHA1) \
		docker buildx build \
		--platform linux/amd64 \
		-t $(IMAGE_PROD):$(GITSHA1) \
		-f Dockerfile .

.PHONY: test
test: test-image
	docker run -ti \
	--env-file .env \
	-v "$$(pwd)"/.s3cmd:/s3cmd/s3cmd:ro \
	-v "$$(pwd)"/.enc-key:/etc/enc-key/key:ro \
	$(IMAGE_PROD):$(GITSHA1)
		