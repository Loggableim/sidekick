"""Cerebras AI provider profile."""
from providers import register_provider
from providers.base import ProviderProfile

cerebras = ProviderProfile(
    name="cerebras",
    aliases=("cerebras-ai", "cerebras-inference"),
    env_vars=("CEREBRAS_API_KEY",),
    display_name="Cerebras AI",
    description="Cerebras — ASIC-accelerated LLM inference (~0.11s latency)",
    signup_url="https://inference.cerebras.ai/",
    fallback_models=(
        "zai-glm-4.7",
        "gpt-oss-120b",
    ),
    base_url="https://api.cerebras.ai/v1",
    default_max_tokens=4096,
)
register_provider(cerebras)