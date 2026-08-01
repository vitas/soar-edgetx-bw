.PHONY: lint test verify

lint:
	bash scripts/lint.sh

test:
	bash scripts/check-lua-loading.sh
	bash scripts/check-f3k-tasks.sh
	@if [ -f tests/test_model_templates.lua ]; then lua tests/test_model_templates.lua; fi

verify: lint test
