"""Studio log handler — captures recent log entries for the Logs page."""

import logging


class _StudioHandler(logging.Handler):
    def __init__(self, records, maxlen=500):
        super().__init__()
        self._records = records
        self._maxlen = maxlen

    def emit(self, record):
        try:
            self._records.append({
                "level": record.levelname,
                "logger": record.name,
                "message": self.format(record),
                "timestamp": record.created,
            })
            while len(self._records) > self._maxlen:
                self._records.pop(0)
        except Exception:
            pass


_installed = False


def install_studio_log_handler(records, maxlen=500):
    global _installed
    if _installed:
        return
    h = _StudioHandler(records, maxlen)
    h.setLevel(logging.DEBUG)
    h.setFormatter(logging.Formatter("%(message)s"))
    logging.getLogger().addHandler(h)
    _installed = True
