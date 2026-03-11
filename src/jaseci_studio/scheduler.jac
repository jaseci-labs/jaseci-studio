"""Scheduler walkers — cron and webhook trigger management."""

import from datetime { datetime }

node StudioRoot {
    has initialized: bool = False,
        created_at: str = "";
}

node Schedule {
    has name: str,
        walker_name: str = "",
        payload: dict = {},
        cron_expr: str = "",
        webhook_path: str = "",
        enabled: bool = True,
        last_run: str = "",
        next_run: str = "";
}

walker CreateSchedule {
    """Create a new cron or webhook schedule."""

    has name: str,
        walker_name: str = "",
        payload: dict = {},
        cron_expr: str = "",
        webhook_path: str = "";

    can start with Root entry {
        visit [-->](?:StudioRoot);
    }

    can create with StudioRoot entry {
        for existing in [-->](?:Schedule) {
            if existing.name == self.name {
                report {"error": f"Schedule '{self.name}' already exists"};
                disengage;
            }
        }
        sched = (here ++> Schedule(
            name=self.name,
            walker_name=self.walker_name,
            payload=self.payload,
            cron_expr=self.cron_expr,
            webhook_path=self.webhook_path,
            enabled=True,
            last_run="",
            next_run=""
        ))[0];
        report {
            "name": sched.name,
            "walker_name": sched.walker_name,
            "cron_expr": sched.cron_expr,
            "webhook_path": sched.webhook_path,
            "enabled": sched.enabled
        };
    }
}

walker ListSchedules {
    """List all configured schedules."""

    can start with Root entry {
        visit [-->](?:StudioRoot);
    }

    can collect with StudioRoot entry {
        schedules: list = [];
        for s in [-->](?:Schedule) {
            schedules.append({
                "name": s.name,
                "walker_name": s.walker_name,
                "cron_expr": s.cron_expr,
                "webhook_path": s.webhook_path,
                "enabled": s.enabled,
                "last_run": s.last_run
            });
        }
        report schedules;
    }
}

walker ToggleSchedule {
    """Enable or disable a schedule."""

    has name: str,
        enabled: bool = True;

    can start with Root entry {
        visit [-->](?:StudioRoot);
    }

    can toggle with StudioRoot entry {
        for s in [-->](?:Schedule) {
            if s.name == self.name {
                s.enabled = self.enabled;
                report {"name": s.name, "enabled": s.enabled};
                disengage;
            }
        }
        report {"error": f"Schedule '{self.name}' not found"};
    }
}

walker DeleteSchedule {
    """Delete a schedule by name."""

    has name: str;

    can start with Root entry {
        visit [-->](?:StudioRoot);
    }

    can remove with StudioRoot entry {
        for s in [-->](?:Schedule) {
            if s.name == self.name {
                del s;
                report {"deleted": self.name};
                disengage;
            }
        }
        report {"error": f"Schedule '{self.name}' not found"};
    }
}
