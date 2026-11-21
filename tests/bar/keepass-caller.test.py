"""Tier 1 (a secret read by one app shown as read by another, which hides who really read it: a reused PID or an
entry's name trusted as the reader). KeePassXC names the reader only in
the body, "... was used by <command> (PID: n)"; the card shows that app's name (and icon) before KeePassXC's own:
  - a reader with no desktop entry is named by its command, with KeePassXC after it;
  - secret-tool is looked through while it still runs: its parents are read from /proc, shells skipped, and the
    first other process is named, "(via secret-tool)";
  - a secret-tool that has already exited (its PID gone) is named as itself;
  - a PID that now belongs to some other process is not trusted;
  - another app's notification with the same words is left alone."""
import os
import shutil
import subprocess
import sys
import time
from ui import Shell, Input, check, done, RUN


def notify(app, summary, body):
    return subprocess.run(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path",
                           "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.Notify",
                           app, "0", "", summary, body, "[]", "{}", "20000"], capture_output=True, text=True).returncode == 0


def label(summary):
    """The app label of the newest notification with this summary, as the cards show it."""
    return s.js(f"(() => {{ const n = Notifs.list.find(x => x.summary === {summary!r}); return n ? Notifs.appLabel(n) : null; }})()")


s = Shell.launch(sys.argv[1], "shell.qml", name="bar")
Input.move(1280, 1000)

check(s.wait(lambda: notify("KeePassXC", "Plain reader", 'Entry "A" from database "db" was used by /opt/x/sleepytest-reader (PID: 4194000)')),
      "the bar answers on the bus")
check(s.wait(lambda: label("Plain reader") == "sleepytest-reader  ·  KeePassXC"),
      "a reader with no desktop entry is named by its command, before KeePassXC", repr(label("Plain reader")))
check(s.wait(lambda: s.visible(contains="sleepytest-reader  ·  KeePassXC")), "and the card shows it")

# a live secret-tool under a shell under an app: copies of sleep and bash under those names (/proc shows the file name)
bindir = RUN / "kpx-bin"
bindir.mkdir(exist_ok=True)
shutil.copy(shutil.which("sleep"), bindir / "secret-tool")
shutil.copy(shutil.which("bash"), bindir / "sleepytestapp")
shutil.copy(shutil.which("bash"), bindir / "sh")
# "; true" keeps each shell from replacing itself with its last command
app = subprocess.Popen([str(bindir / "sleepytestapp"), "-c", f'"{bindir}/sh" -c \'"{bindir}/secret-tool" 30; true\'; true'])
tool = None
for _ in range(50):
    out = subprocess.run(["pgrep", "-n", "-x", "secret-tool"], capture_output=True, text=True).stdout.split()
    if out:
        tool = int(out[0])
        break
    time.sleep(0.1)
if check(tool is not None, "the stand-in secret-tool runs under a shell under an app"):
    notify("KeePassXC", "Helper reader", f'Entry "Claude" from database "db" was used by secret-tool (PID: {tool})')
    check(s.wait(lambda: label("Helper reader") == "sleepytestapp (via secret-tool)  ·  KeePassXC"),
          "a running secret-tool is looked through to the app above its shell", repr(label("Helper reader")))
app.kill()
app.wait()
subprocess.run(["pkill", "-x", "secret-tool"], capture_output=True)

notify("KeePassXC", "Gone helper", 'Entry "B" from database "db" was used by secret-tool (PID: 4194001)')
check(s.wait(lambda: label("Gone helper") == "secret-tool  ·  KeePassXC"), "an exited secret-tool is named as itself",
      repr(label("Gone helper")))

# this test's own PID (python, not secret-tool): its parents must not be used
notify("KeePassXC", "Reused pid", f'Entry "C" from database "db" was used by secret-tool (PID: {os.getpid()})')
time.sleep(1.5)
check(label("Reused pid") == "secret-tool  ·  KeePassXC", "a PID that names another process is not trusted",
      repr(label("Reused pid")))

notify("Sleepytest", "Not KeePassXC", "was used by sleepytest-reader (PID: 5)")
check(s.wait(lambda: label("Not KeePassXC") == "Sleepytest"), "another app's notification keeps its own name",
      repr(label("Not KeePassXC")))

done()
