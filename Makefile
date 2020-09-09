image:
	docker image build -t negeric/postgres-s3cmd-backup:latest .
	docker push negeric/postgres-s3cmd-backup:latest
	