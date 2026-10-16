.DEFAULT_GOAL := help
.PHONY: help test build package test-release test-homebrew test-release-tools

BUILD_DIR ?= app/build
APP ?= $(BUILD_DIR)/ClickThrough.app

help:
	@printf '%s\n' 'make test           运行现有 Swift 单元检查' 'make build          构建本地应用；BUILD_DIR 可指定新输出目录' 'make package        打包 APP（默认 BUILD_DIR/ClickThrough.app）' 'make test-release   临时副本上的分发回归' 'make test-homebrew  额外使用已安装 Homebrew 解析 Cask，不安装软件' 'make test-release-tools  检查公开归档的版本、完整性和脱敏校验工具'

test:
	swift test --package-path app

build:
	bash app/scripts/build-app.sh --output "$(BUILD_DIR)"

package:
	python3 app/scripts/package-release.py --app "$(APP)"

test-release:
	python3 app/Tests/DistributionTests/test_package_release.py --app "$(APP)"

test-homebrew:
	python3 app/Tests/DistributionTests/test_package_release.py --app "$(APP)" --homebrew

test-release-tools:
	python3 app/Tests/DistributionTests/test_verify_release.py
	python3 app/Tests/DistributionTests/test_sync_homebrew.py
