"""Regression checks for content filtering and popup dispatch, without opening UI."""

import json
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
EMPTY = [
    "", " \n\t", "{}", "[]", "null", '""', '"   "',
    '{"findings": []}',
    '{"message": " ", "data": [null, {}, [], ""]}',
    "```json\n{}\n```", "~~~json\n[null, {}]\n~~~",
    "```\n\n```",
]
NONEMPTY = [
    "Đã hoàn thành công việc.", "0", "false", "true", '"done"',
    '{"count": 0}', '{"success": false}', '{"findings": ["Fix needed"]}',
    "```json\n{\"count\": 0}\n```", "```sh\necho done\n```",
]


class AlertTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="mac-alert-tests-")
        cls.addClassCleanup(cls.temp.cleanup)
        cls.scratch = Path(cls.temp.name)
        subprocess.run([str(ROOT / "scripts/build.sh")], check=True)
        cls.binary = ROOT / ".build/mac-alert"
        # The production entry point follows the functions under test. Compile
        # those exact definitions with a small assertion harness, without UI.
        source = (ROOT / "MacAlert.swift").read_text()
        definitions, separator, _ = source.partition("\nvar parsedOptions = parseOptions()")
        if not separator:
            raise AssertionError("Cannot locate mac-alert entry point")
        cls.definitions = definitions

    def test_content_and_event_mapping(self):
        # JSON is also valid Swift array syntax for these string-only fixtures.
        empty = json.dumps(EMPTY, ensure_ascii=False)
        nonempty = json.dumps(NONEMPTY, ensure_ascii=False)
        harness = r'''
func check(_ condition: Bool, _ message: String) {
    if !condition {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(1)
    }
}
let emptyMessages: [String] = __EMPTY_FIXTURE__
let nonemptyMessages: [String] = __NONEMPTY_FIXTURE__
for message in emptyMessages {
    check(isEmptyAlertContent(message), "Expected empty: \(message)")
    check(resultSummary(message) == nil, "Unexpected summary: \(message)")
}
for message in nonemptyMessages {
    check(!isEmptyAlertContent(message), "Discarded meaningful content: \(message)")
    check(resultSummary(message) != nil, "Missing summary: \(message)")
}
for message in ["::directive{}", "**", "# "] {
    check(resultSummary(message) == nil, "Formatting is not a summary")
}
for (kind, key) in [("Stop", "last_assistant_message"),
                    ("agent-turn-complete", "last-assistant-message")] {
    let eventKey = kind == "Stop" ? "hook_event_name" : "type"
    for message in emptyMessages {
        let event: [String: Any] = [eventKey: kind, key: message]
        check(applyingHookEvent(event, to: Options(), projects: []) == nil,
              "Empty hook must not produce popup options")
    }
    for message in nonemptyMessages {
        let event: [String: Any] = [eventKey: kind, key: message,
                                   "cwd": "/work/project", "thread_title": "My task"]
        let result = applyingHookEvent(event, to: Options(), projects: [])
        check(result?.dynamicContent == true, "Lost nonempty hook")
        check(result?.title == "Codex · project", "Lost project name")
        check(result?.subtitle == "My task", "Lost thread title")
    }
    for value: Any in [NSNull(), 42, false] {
        let event: [String: Any] = [eventKey: kind, key: value]
        check(applyingHookEvent(event, to: Options(), projects: []) == nil,
              "Invalid message field must not produce popup options")
    }
    check(applyingHookEvent([eventKey: kind], to: Options(), projects: []) == nil,
          "Missing message must not produce popup options")
}
check(applyingHookEvent([:], to: Options(), projects: []) == nil, "Empty event")
check(applyingHookEvent(["hook_event_name": "PreToolUse"], to: Options(), projects: []) == nil,
      "Unrelated hook")
var manual = Options()
manual.message = "GitHub Crawl"
manual.subtitle = "repo#318"
let result = applyingHookEvent(nil, to: manual, projects: [])
check(result?.message == manual.message && result?.subtitle == manual.subtitle,
      "Manual alerts must retain supplied content")
check(resultSummary("# **Done**\nMore details") == "Done", "Markdown summary")
check(resultSummary("```\ncode\n```\nCompleted successfully.") == "Completed successfully.",
      "Prefer prose over code")
print("Content and event mapping passed")
'''.replace("__EMPTY_FIXTURE__", empty).replace("__NONEMPTY_FIXTURE__", nonempty)
        source = self.scratch / "main.swift"
        source.write_text(self.definitions + "\n" + harness)
        executable = self.scratch / "content-tests"
        subprocess.run(["xcrun", "swiftc", str(source), "-o", str(executable)], check=True)
        subprocess.run([str(executable)], check=True)

    def run_binary(self, args, event=None):
        # Supply an absent argv[0]. The hook's child uses this path, so an
        # attempted popup spawn fails observably before any UI can open.
        return subprocess.run(
            [str(self.scratch / "must-not-launch"), *args],
            executable=str(self.binary),
            input=json.dumps(event) if event is not None else "",
            text=True, capture_output=True, timeout=3,
        )

    def test_empty_hooks_exit_successfully_without_spawning(self):
        for kind, key in [("Stop", "last_assistant_message"),
                          ("agent-turn-complete", "last-assistant-message")]:
            event_key = "hook_event_name" if kind == "Stop" else "type"
            for message in EMPTY + [None, "::directive{}", "**"]:
                with self.subTest(kind=kind, message=message):
                    result = self.run_binary([], {event_key: kind, key: message})
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout, "{}\n")
                    self.assertEqual(result.stderr, "")

    def test_missing_message_and_empty_event(self):
        for event in [{}, {"hook_event_name": "Stop"}, {"type": "agent-turn-complete"}]:
            with self.subTest(event=event):
                result = self.run_binary([], event)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, "{}\n")

    def test_nonempty_hooks_reach_popup_dispatch(self):
        # This also verifies that the argv[0] trap used above actually works.
        for message in NONEMPTY:
            with self.subTest(message=message):
                result = self.run_binary([], {"hook_event_name": "Stop",
                                              "last_assistant_message": message})
                self.assertEqual(result.returncode, 1)
                self.assertIn("Cannot start popup:", result.stderr)

    def test_manual_empty_message_exits_before_loading_icon(self):
        for message in EMPTY:
            with self.subTest(message=message):
                result = self.run_binary(["--no-event", "--message", message,
                                          "--icon", str(self.scratch / "missing.png")])
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, "")
                self.assertEqual(result.stderr, "")

    def test_manual_nonempty_message_ignores_empty_stdin_event(self):
        result = self.run_binary(["--no-event", "--message", "GitHub Crawl",
                                  "--subtitle", "repo#318", "--icon",
                                  str(self.scratch / "missing.png")], {})
        self.assertEqual(result.returncode, 1)
        self.assertIn("Icon file does not exist:", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
