# Local models (GTX 1070 compatible - 8GB VRAM)
start-qwen2.5-3b:
	ollama run qwen2.5:3b

start-qwen2.5-7b:
	ollama run qwen2.5:7b

start-llama3.2-3b:
	ollama run llama3.2:3b

start-mistral-7b:
	ollama run mistral:7b

start-codellama-7b:
	ollama run codellama:7b

# Cloud models (advisors)
start-minimax2.5:
	ollama launch claude --model minimax-m2.5:cloud

start-minimax2.7:
	ollama launch claude --model minimax-m2.7:cloud

start-devstral-2:
	ollama run devstral-2:123b-cloud

start-devstral-small-2:
	ollama run devstral-small-2:24b-cloud

start-glm-5.1:
	ollama run glm-5.1:cloud

start-ministral-3:
	ollama run ministral-3:14b-cloud

start-gemma4:
	ollama run gemma4:31b-cloud

# Mixed setup: local executor + cloud advisor
# Usage: run executor in one terminal, then call advisor via ollama run <advisor>
start-security-agent:
	@echo "Executor: qwen2.5:3b (local)"
	@echo "Advisor: devstral-small-2:24b-cloud (cloud)"
	@echo "Run: ollama run qwen2.5:3b"
	@echo "Then at decision points: ollama run devstral-small-2:24b-cloud"

start-solutions-agent:
	@echo "Executor: qwen2.5:3b (local)"
	@echo "Advisor: devstral-small-2:24b-cloud (cloud)"
	@echo "Run: ollama run qwen2.5:3b"
	@echo "Then at decision points: ollama run devstral-small-2:24b-cloud"

start-requirements-agent:
	@echo "Executor: qwen2.5:7b (local)"
	@echo "Advisor: devstral-2:123b-cloud (cloud)"
	@echo "Run: ollama run qwen2.5:7b"
	@echo "Then at decision points: ollama run devstral-2:123b-cloud"

start-system-health-agent:
	@echo "Executor: qwen2.5:3b (local)"
	@echo "Advisor: gemma4:31b-cloud (cloud)"
	@echo "Run: ollama run qwen2.5:3b"
	@echo "Then at decision points: ollama run gemma4:31b-cloud"

start-maintenance-agent:
	@echo "Executor: qwen2.5:3b (local)"
	@echo "Advisor: devstral-2:123b-cloud (cloud)"
	@echo "Run: ollama run qwen2.5:3b"
	@echo "Then at decision points: ollama run devstral-2:123b-cloud"