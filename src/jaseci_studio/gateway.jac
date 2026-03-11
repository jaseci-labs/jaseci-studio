"""AI Gateway walkers — model configuration and cost tracking."""

node StudioRoot {
    has initialized: bool = False,
        created_at: str = "";
}

node ModelConfig {
    has model_id: str,
        provider: str = "",
        api_key_env: str = "",
        is_default: bool = False,
        max_tokens: int = 4096,
        temperature: float = 0.7;
}

node CostRecord {
    has model_id: str,
        input_tokens: int = 0,
        output_tokens: int = 0,
        cost_usd: float = 0.0,
        timestamp: str = "";
}

walker AddModel {
    """Add an AI model configuration."""

    has model_id: str,
        provider: str = "",
        api_key_env: str = "",
        is_default: bool = False,
        max_tokens: int = 4096,
        temperature: float = 0.7;

    can add with Root entry {
        visit [-->](?:StudioRoot);
    }

    can create with StudioRoot entry {
        for existing in [-->](?:ModelConfig) {
            if existing.model_id == self.model_id {
                report {"error": f"Model '{self.model_id}' already exists"};
                disengage;
            }
        }
        new_model = (here ++> ModelConfig(
            model_id=self.model_id,
            provider=self.provider,
            api_key_env=self.api_key_env,
            is_default=self.is_default,
            max_tokens=self.max_tokens,
            temperature=self.temperature
        ))[0];
        report {
            "model_id": new_model.model_id,
            "provider": new_model.provider,
            "is_default": new_model.is_default
        };
    }
}

walker ListModels {
    """List all configured AI models."""

    can start with Root entry {
        visit [-->](?:StudioRoot);
    }

    can collect with StudioRoot entry {
        models: list = [];
        for m in [-->](?:ModelConfig) {
            models.append({
                "model_id": m.model_id,
                "provider": m.provider,
                "api_key_env": m.api_key_env,
                "is_default": m.is_default,
                "max_tokens": m.max_tokens,
                "temperature": m.temperature
            });
        }
        report models;
    }
}

walker RemoveModel {
    """Remove an AI model configuration."""

    has model_id: str;

    can start with Root entry {
        visit [-->](?:StudioRoot);
    }

    can find with StudioRoot entry {
        for m in [-->](?:ModelConfig) {
            if m.model_id == self.model_id {
                del m;
                report {"deleted": self.model_id};
                disengage;
            }
        }
        report {"error": f"Model '{self.model_id}' not found"};
    }
}

walker RecordCost {
    """Record an LLM usage cost entry."""

    has model_id: str,
        input_tokens: int = 0,
        output_tokens: int = 0,
        cost_usd: float = 0.0;

    can record with Root entry {
        visit [-->](?:StudioRoot);
    }

    can save with StudioRoot entry {
        import from datetime { datetime }

        here ++> CostRecord(
            model_id=self.model_id,
            input_tokens=self.input_tokens,
            output_tokens=self.output_tokens,
            cost_usd=self.cost_usd,
            timestamp=datetime.utcnow().isoformat()
        );
        report {"recorded": True, "model_id": self.model_id, "cost_usd": self.cost_usd};
    }
}

walker GetCostSummary {
    """Aggregate cost data per model."""

    can start with Root entry {
        visit [-->](?:StudioRoot);
    }

    can aggregate with StudioRoot entry {
        totals: dict = {};
        for c in [-->](?:CostRecord) {
            mid = c.model_id;
            if mid not in totals {
                totals[mid] = {
                    "model_id": mid,
                    "total_input_tokens": 0,
                    "total_output_tokens": 0,
                    "total_cost_usd": 0.0,
                    "request_count": 0
                };
            }
            totals[mid]["total_input_tokens"] += c.input_tokens;
            totals[mid]["total_output_tokens"] += c.output_tokens;
            totals[mid]["total_cost_usd"] += c.cost_usd;
            totals[mid]["request_count"] += 1;
        }
        report list(totals.values());
    }
}
