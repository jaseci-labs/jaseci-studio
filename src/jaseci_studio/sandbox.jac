"""Sandbox walkers — isolated Jac code execution."""

import from datetime { datetime }
import time;

node StudioRoot {
    has initialized: bool = False,
        created_at: str = "";
}

node SandboxSession {
    has session_id: str,
        code: str = "",
        output: str = "",
        status: str = "idle",
        created_at: str = "";
}

walker RunSandbox {
    """Execute Jac code in a sandbox and capture output."""

    has code: str,
        timeout_sec: int = 10;

    can execute with Root entry {
        import subprocess;
        import tempfile;
        import os;
        import uuid;

        session_id = str(uuid.uuid4())[:8];
        created = datetime.utcnow().isoformat();
        output_text = "";
        status = "error";

        try {
            with tempfile.NamedTemporaryFile(
                mode="w", suffix=".jac", delete=False
            ) as f {
                f.write(self.code);
                tmp_path = f.name;
            }
            try {
                proc = subprocess.run(
                    ["jac", "run", tmp_path],
                    capture_output=True,
                    text=True,
                    timeout=self.timeout_sec
                );
                output_text = proc.stdout;
                if proc.returncode != 0 {
                    output_text = proc.stdout + "\n" + proc.stderr;
                    status = "error";
                } else {
                    status = "success";
                }
            } except subprocess.TimeoutExpired {
                output_text = f"Execution timed out after {self.timeout_sec}s";
                status = "timeout";
            } finally {
                os.unlink(tmp_path);
            }
        } except Exception as e {
            output_text = str(e);
        }

        studio_nodes = [-->](?:StudioRoot);
        if len(studio_nodes) > 0 {
            studio_nodes[0] ++> SandboxSession(
                session_id=session_id,
                code=self.code,
                output=output_text,
                status=status,
                created_at=created
            );
        }

        report {
            "session_id": session_id,
            "status": status,
            "output": output_text
        };
    }
}

walker GetSandboxHistory {
    """Get recent sandbox execution history."""

    has limit: int = 10;

    can start with Root entry {
        visit [-->](?:StudioRoot);
    }

    can collect with StudioRoot entry {
        sessions: list = [];
        for s in [-->](?:SandboxSession) {
            sessions.append({
                "session_id": s.session_id,
                "code": s.code,
                "output": s.output,
                "status": s.status,
                "created_at": s.created_at
            });
        }
        sessions.sort(key=lambda x: any: x["created_at"], reverse=True);
        report sessions[:self.limit];
    }
}
