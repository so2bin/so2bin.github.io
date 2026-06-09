.PHONY: restart clean build serve stop deploy

PORT := 4000
OSS_BUCKET := oss://tq-techweb

-include .env
export

OSS_FLAGS := -i $(AccessKeyID) -k $(AccessKeySecret) --region $(OSS_REGION)

stop:
	@kill $$(lsof -ti:$(PORT)) 2>/dev/null || true
	@sleep 1

clean:
	npx hexo clean

build: clean
	npx hexo generate

serve:
	npx http-server public -p $(PORT) -c-1

restart: stop build serve

deploy: build
	@echo ">>> Syncing public/ to $(OSS_BUCKET) ..."
	ossutil sync public/ $(OSS_BUCKET)/ --delete --force $(OSS_FLAGS)
	@echo ">>> Cleaning up OSS directory markers ..."
	@ossutil ls $(OSS_BUCKET)/ $(OSS_FLAGS) 2>/dev/null \
		| grep '\s0\s\+Standard' \
		| grep -oP 'oss://\S+/$$' \
		| while IFS= read -r obj; do ossutil rm "$$obj" $(OSS_FLAGS) >/dev/null 2>&1; done || true
	@echo ">>> Deploy complete."
