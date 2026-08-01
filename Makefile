.PHONY: lint test verify

lint:
	bash scripts/lint.sh

test:
	bash scripts/check-lua-loading.sh
	bash scripts/check-f3k-tasks.sh
	ruby tests/test_model_yaml_checker.rb
	ruby scripts/check-model-yaml.rb
	lua tests/test_model_templates.lua

verify: lint test
