#!/usr/bin/env python3
"""在独立 PTY 会话中检查 script 录制、目录继承和 cccp，可传入修补后的 zellij 路径。"""

import fcntl
import json
import os
from pathlib import Path
import pty
import re
import shlex
import shutil
import struct
import subprocess
import sys
import tempfile
import termios
import textwrap
import threading
import time


def main():
    zellij = shutil.which(sys.argv[1] if len(sys.argv) > 1 else "zellij")
    if not zellij:
        raise SystemExit("找不到 zellij")
    repo = Path(__file__).resolve().parents[1]
    source = (repo / "modules/home/shell/fish.nix").read_text()
    env = {k: v for k, v in os.environ.items() if not k.startswith("ZELLIJ")}
    env["TERM"] = "xterm-256color"
    with tempfile.TemporaryDirectory(prefix="zellij-cccp-") as directory:
        root = Path(directory)
        session = root.name
        destination = root / "中文 空格%#"
        destination.mkdir()
        definitions = []
        for name, event in [("__cccp_preexec", "fish_preexec"), ("__cccp_postexec", "fish_postexec")]:
            match = re.search(r"functions\." + name + r" = \{.*?body = ''\n(.*?)\n      '';", source, re.S)
            definitions.append(f"function {name} --on-event {event}\n{textwrap.dedent(match[1])}\nend")
        match = re.search(r"functions.cccp = ''\n(.*?)\n    '';", source, re.S)
        definitions.append("function cccp\n" + textwrap.dedent(match[1]) + "\nend")
        clipboard = root / "clipboard"
        init = root / "init.fish"
        init.write_text("\n".join(definitions) + f"""
function wl-copy
    cat > {shlex.quote(str(clipboard))}
end
function fish_prompt
    printf 'TEST> '
end
""")
        shell = root / "shell"
        command = shlex.join([shutil.which("fish"), "--no-config", "--interactive", "--init-command", "source " + shlex.quote(str(init))])
        driver = root / "fish-driver"
        driver.write_text("#!/bin/sh\nexec " + command + "\n")
        driver.chmod(0o755)
        shell.write_text(f"""#!/bin/sh
export __CCCP_SCRIPT_LOG=$(mktemp {shlex.quote(str(root / 'record.XXXXXX'))})
export SHELL={shlex.quote(str(driver))}
exec script -q -f "$__CCCP_SCRIPT_LOG"
""")
        shell.chmod(0o755)
        config = root / "config.kdl"
        config.write_text(f'default_shell {json.dumps(str(shell))}\nshow_startup_tips false\nshow_release_notes false\n')
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 35, 120, 0, 0))
        process = subprocess.Popen([zellij, "--config", str(config), "--session", session], stdin=slave, stdout=slave, stderr=slave, cwd=root, env=env, start_new_session=True)
        os.close(slave)

        def drain():
            try:
                while os.read(master, 65536):
                    pass
            except OSError:
                pass

        threading.Thread(target=drain, daemon=True).start()

        def action(*arguments):
            return subprocess.run([zellij, "--session", session, "action", *arguments], env=env, capture_output=True, text=True, timeout=10)

        def send(command):
            result = action("write-chars", command)
            assert result.returncode == 0, result.stderr
            assert action("write", "13").returncode == 0
            time.sleep(0.6)

        try:
            for _ in range(50):
                if action("list-panes", "--json").returncode == 0:
                    break
                time.sleep(0.1)
            else:
                raise AssertionError("测试会话无法启动")
            time.sleep(1)
            send("cd " + shlex.quote(str(destination)))
            os.write(master, b"\x1bn")  # 使用真实 Alt+n，避免 CLI 的 cwd 默认值干扰。
            time.sleep(1)
            inherited = root / "inherited"
            send("pwd > " + shlex.quote(str(inherited)))
            assert inherited.read_text().strip() == str(destination)
            recorders = []
            for path in Path("/proc").iterdir():
                if not path.name.isdigit():
                    continue
                try:
                    if (path / "comm").read_text().strip() == "script" and str(root).encode() in (path / "cmdline").read_bytes():
                        recorders.append(path)
                except OSError:
                    pass
            assert len(recorders) == 2, "两个 pane 都应保持 script 录制"
            send("printf 'CCCP-PRESERVED-123\\n'; sleep 0.2")
            send("cccp")
            assert clipboard.read_text() == "CCCP-PRESERVED-123\n", repr(clipboard.read_text())
            send("cccp")
            assert clipboard.read_text() == "CCCP-PRESERVED-123\n"
            print("PASS: 目录继承（中文/空格/%/#）、script 录制、cccp 纯文本与连续复制")
        finally:
            subprocess.run([zellij, "delete-session", session, "--force"], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
            process.wait(timeout=10)
            os.close(master)


if __name__ == "__main__":
    main()
