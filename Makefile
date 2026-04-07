.PHONY: restart clean build serve stop

PORT := 4000

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
