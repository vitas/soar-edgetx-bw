.PHONY: lint test verify

lint:
	bash scripts/lint.sh

test:
	bash scripts/check-lua-loading.sh
	bash scripts/check-f3k-tasks.sh
	lua tests/test_model_templates.lua

verify: lint test
