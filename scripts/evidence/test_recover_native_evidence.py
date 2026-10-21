"""Small offline checks: synthetic bytes, mocked HTTP, no native build or test."""

from contextlib import ExitStack
import copy
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import urllib.error
import urllib.request

import recover_native_evidence as recovery


class Response(io.BytesIO):
    def __init__(self, content=b"", status=200, headers=None):
        super().__init__(content)
        self.status = status
        self.headers = headers or {}


def metadata():
    source = recovery.SOURCE
    repo = {"id": source["repository_id"], "full_name": source["repository"], "private": False}
    run = {"id": source["run_id"], "run_attempt": source["run_attempt"],
           "head_sha": source["source_sha"], "head_branch": source["source_branch"],
           "path": ".github/workflows/ios-quality.yml", "repository": repo, "head_repository": repo.copy()}
    url = f"{recovery.API_ROOT}/repos/{source['repository']}/actions/artifacts/{source['artifact_id']}"
    artifact = {"id": source["artifact_id"], "name": source["artifact_name"],
                "size_in_bytes": source["size_bytes"], "digest": "sha256:" + source["sha256"],
                "expired": False, "url": url, "archive_download_url": url + "/zip",
                "workflow_run": {"id": source["run_id"], "repository_id": source["repository_id"],
                                 "head_repository_id": source["repository_id"],
                                 "head_sha": source["source_sha"], "head_branch": source["source_branch"]}}
    return run, artifact


class SourceTests(unittest.TestCase):
    def test_production_identity_and_chunk_boundaries(self):
        self.assertEqual(recovery.SOURCE["artifact_id"], 12374080329)
        self.assertEqual(recovery.SOURCE["run_id"], 39657409557)
        self.assertEqual(recovery.SOURCE["source_sha"], "c948de49ad800c1711a40b8008e416716f76f309")
        self.assertEqual(recovery.SOURCE["sha256"], "a76c6e20aabb5ad20f011fdc9ea4d9df4211e018de3317a09baf1a8ed291c1d5")
        self.assertEqual([part["size_bytes"] for part in recovery.chunk_layout()],
                         [268435456, 268435456, 115818000])

    def test_source_metadata_is_pinned(self):
        recovery.validate_metadata(*metadata())
        run, artifact = metadata()
        for key in ("id", "run_attempt", "head_sha", "head_branch", "path"):
            changed = copy.deepcopy(run)
            changed[key] = "wrong"
            with self.subTest(run_field=key), self.assertRaises(recovery.RecoveryError):
                recovery.validate_metadata(changed, artifact)
        for key in ("id", "name", "size_in_bytes", "digest", "expired", "url", "archive_download_url"):
            changed = copy.deepcopy(artifact)
            changed[key] = "wrong"
            with self.subTest(artifact_field=key), self.assertRaises(recovery.RecoveryError):
                recovery.validate_metadata(run, changed)
        for key in artifact["workflow_run"]:
            changed = copy.deepcopy(artifact)
            changed["workflow_run"][key] = "wrong"
            with self.subTest(owner_field=key), self.assertRaises(recovery.RecoveryError):
                recovery.validate_metadata(run, changed)
        for target in ("repository", "head_repository"):
            for key in ("id", "full_name", "private"):
                changed = copy.deepcopy(run)
                changed[target][key] = "wrong"
                with self.subTest(repository=target, field=key), self.assertRaises(recovery.RecoveryError):
                    recovery.validate_metadata(changed, artifact)

    def test_actions_context_rejects_other_repo_event_branch_api_or_rerun(self):
        with tempfile.TemporaryDirectory() as root:
            event = Path(root) / "event.json"
            event.write_text(json.dumps({"repository": metadata()[0]["repository"], "deleted": False}))
            env = {"GITHUB_REPOSITORY": recovery.SOURCE["repository"], "GITHUB_EVENT_NAME": "push",
                   "GITHUB_REF": "refs/heads/polish/recovery", "GITHUB_RUN_ATTEMPT": "1",
                   "GITHUB_API_URL": recovery.API_ROOT, "GITHUB_EVENT_PATH": str(event)}
            recovery.validate_context(env)
            for key in env:
                if key != "GITHUB_EVENT_PATH":
                    with self.subTest(key=key), self.assertRaises(recovery.RecoveryError):
                        recovery.validate_context({**env, key: "wrong"})
            event.write_text(json.dumps({"repository": metadata()[0]["repository"], "deleted": True}))
            with self.assertRaises(recovery.RecoveryError):
                recovery.validate_context(env)

    def test_storage_url_allowlist_and_no_redirect_handler(self):
        for url in ("https://example.blob.core.windows.net/path?sig=example",
                    "https://results-receiver.actions.githubusercontent.com/path"):
            recovery.validate_storage_url(url)
        for url in ("http://example.blob.core.windows.net/path", "https://api.github.com/path",
                    "https://example.blob.core.windows.net.evil.example/path",
                    "https://user:password@example.blob.core.windows.net/path",
                    "https://example.blob.core.windows.net:8080/path", "https://127.0.0.1/path",
                    "https://example.blob.core.windows.net/path#fragment", "file:///tmp/source"):
            with self.subTest(url=url), self.assertRaises(recovery.RecoveryError):
                recovery.validate_storage_url(url)
        self.assertIsNone(recovery.NoRedirect().redirect_request(None, None, 302, "", {}, "https://example.com"))

    def test_api_token_stays_at_official_endpoint(self):
        client = recovery.GitHubReader("not-a-real-token")
        client.opener = mock.Mock()
        client.opener.open.return_value = Response(b"{}")
        client.json(f"/repos/{recovery.SOURCE['repository']}/actions/runs/1")
        request = client.opener.open.call_args.args[0]
        self.assertTrue(request.full_url.startswith("https://api.github.com/repos/oskuhsiu/CalcuLater/"))
        self.assertEqual(request.get_method(), "GET")
        self.assertEqual(request.get_header("Authorization"), "Bearer not-a-real-token")
        for path in ("https://other.example/path", "/repos/other/repo/actions/runs/1",
                     "/repos/oskuhsiu/CalcuLater/../other", "/repos/oskuhsiu/CalcuLater/x?next=other"):
            with self.subTest(path=path), self.assertRaises(recovery.RecoveryError):
                client.request(path)

    def test_api_metadata_redirect_is_rejected_and_download_requires_302(self):
        client = recovery.GitHubReader("not-a-real-token")
        client.opener = mock.Mock()
        client.opener.open.return_value = Response(status=302, headers={"Location": "https://example.com"})
        with self.assertRaises(recovery.RecoveryError):
            client.json(f"/repos/{recovery.SOURCE['repository']}/actions/runs/1")
        client.opener.open.return_value = Response(status=200)
        with self.assertRaises(recovery.RecoveryError):
            client.download_location()
        location = "https://example.blob.core.windows.net/path?sig=redacted"
        client.opener.open.return_value = Response(status=302, headers={"Location": location})
        self.assertEqual(client.download_location(), location)


class SmallArchiveTests(unittest.TestCase):
    def setUp(self):
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.root = Path(self.stack.enter_context(tempfile.TemporaryDirectory()))
        self.content = bytes(range(201))
        source = {**recovery.SOURCE, "size_bytes": len(self.content),
                  "sha256": hashlib.sha256(self.content).hexdigest()}
        self.stack.enter_context(mock.patch.object(recovery, "SOURCE", source))
        self.stack.enter_context(mock.patch.object(recovery, "CHUNK_BYTES", 64))
        self.archive = self.root / "original.zip"
        self.archive.write_bytes(self.content)
        self.parts = self.root / "packages"

    def split(self):
        result = recovery.split_original(self.archive, self.parts)
        return result, self.parts / "manifest/manifest.json"

    def test_split_is_deterministic_and_reassembly_exact(self):
        manifest, path = self.split()
        second = recovery.split_original(self.archive, self.root / "second")
        self.assertEqual(manifest, second)
        self.assertEqual([part["size_bytes"] for part in manifest["chunks"]], [64, 64, 64, 9])
        output = self.root / "reassembled.zip"
        recovery.reassemble(path, self.parts, output)
        self.assertEqual(output.read_bytes(), self.content)
        self.assertEqual(self.archive.read_bytes(), self.content)

    def test_exact_multiple_has_no_empty_tail(self):
        self.archive.write_bytes(self.content[:192])
        with mock.patch.dict(recovery.SOURCE, size_bytes=192, sha256=hashlib.sha256(self.content[:192]).hexdigest()):
            manifest, _ = self.split()
        self.assertEqual([part["size_bytes"] for part in manifest["chunks"]], [64, 64, 64])

    def test_original_size_and_digest_failure_create_no_packages(self):
        for content in (self.content[:-1], b"x" * len(self.content)):
            self.archive.write_bytes(content)
            with self.assertRaises(recovery.RecoveryError):
                self.split()
            self.assertFalse(self.parts.exists())

    def test_manifest_rejects_source_change_order_traversal_and_size(self):
        manifest, _ = self.split()
        for key in manifest["source"]:
            changed = copy.deepcopy(manifest)
            changed["source"][key] = "wrong"
            with self.subTest(source=key), self.assertRaises(recovery.RecoveryError):
                recovery.validate_manifest(changed)
        for key, value in (("name", "../original.zip"), ("size_bytes", 65), ("index", 1), ("sha256", "invalid")):
            changed = copy.deepcopy(manifest)
            changed["chunks"][0][key] = value
            with self.subTest(chunk=key), self.assertRaises(recovery.RecoveryError):
                recovery.validate_manifest(changed)
        manifest["chunks"].reverse()
        with self.assertRaises(recovery.RecoveryError):
            recovery.validate_manifest(manifest)

    def test_missing_duplicate_corrupt_or_symlink_chunk_rejected(self):
        _, path = self.split()
        first = self.parts / "part-000/original.zip.part000"
        saved = first.read_bytes()
        output = self.root / "result.zip"
        first.unlink()
        with self.assertRaises(recovery.RecoveryError):
            recovery.reassemble(path, self.parts, output)
        first.write_bytes(saved)
        duplicate = self.parts / first.name
        duplicate.write_bytes(saved)
        with self.assertRaises(recovery.RecoveryError):
            recovery.reassemble(path, self.parts, output)
        duplicate.unlink()
        first.write_bytes(b"x" * len(saved))
        with self.assertRaises(recovery.RecoveryError):
            recovery.reassemble(path, self.parts, output)
        first.unlink()
        first.symlink_to(self.archive)
        with self.assertRaises(recovery.RecoveryError):
            recovery.reassemble(path, self.parts, output)
        self.assertFalse(output.exists())

    def test_output_and_package_overwrite_are_refused(self):
        _, path = self.split()
        with self.assertRaises(FileExistsError):
            self.split()
        with self.assertRaises(recovery.RecoveryError):
            recovery.reassemble(path, self.parts, self.archive)
        output = self.root / "result.zip"
        partial = output.with_name("result.zip.partial")
        partial.write_bytes(b"keep this")
        with self.assertRaises(FileExistsError):
            recovery.reassemble(path, self.parts, output)
        self.assertEqual(partial.read_bytes(), b"keep this")

    def test_final_digest_blocks_manifest_with_altered_chunk_and_digest(self):
        manifest, path = self.split()
        first = self.parts / "part-000/original.zip.part000"
        first.write_bytes(b"x" * 64)
        manifest["chunks"][0]["sha256"] = hashlib.sha256(first.read_bytes()).hexdigest()
        path.write_text(json.dumps(manifest))
        output = self.root / "result.zip"
        with self.assertRaises(recovery.RecoveryError):
            recovery.reassemble(path, self.parts, output)
        self.assertFalse(output.exists())
        self.assertFalse(output.with_name("result.zip.partial").exists())

    def test_storage_download_has_no_auth_and_preserves_bytes(self):
        opener = mock.Mock()
        opener.open.return_value = Response(self.content, headers={"Content-Length": str(len(self.content))})
        destination = self.root / "download.zip"
        with mock.patch.object(urllib.request, "build_opener", return_value=opener):
            recovery.download_original("https://example.blob.core.windows.net/file?sig=test", destination)
        request = opener.open.call_args.args[0]
        self.assertIsNone(request.get_header("Authorization"))
        self.assertEqual(request.get_header("Accept-encoding"), "identity")
        self.assertEqual(destination.read_bytes(), self.content)

    def test_storage_content_length_encoding_overflow_digest_and_redirect_rejected(self):
        cases = [(self.content, {"Content-Length": "1"}, 200),
                 (self.content, {"Content-Encoding": "gzip"}, 200),
                 (self.content + b"x", {}, 200), (self.content[:-1], {}, 200),
                 (b"x" * len(self.content), {}, 200), (self.content, {}, 302)]
        for index, (content, headers, status) in enumerate(cases):
            opener = mock.Mock()
            opener.open.return_value = Response(content, status, headers)
            with self.subTest(index=index), mock.patch.object(urllib.request, "build_opener", return_value=opener):
                with self.assertRaises(recovery.RecoveryError):
                    recovery.download_original("https://example.blob.core.windows.net/path", self.root / f"download-{index}")


class WorkflowIsolationTests(unittest.TestCase):
    def test_recovery_paths_do_not_match_native_trigger(self):
        import fnmatch
        import re
        root = Path(__file__).resolve().parents[2]
        native = (root / ".github/workflows/ios-quality.yml").read_text()
        path_block = native.split("    paths:\n", 1)[1].split("  workflow_dispatch:", 1)[0]
        patterns = re.findall(r'      - "([^"]+)"', path_block)
        self.assertTrue(patterns)
        owned = [".github/workflows/recover-native-evidence.yml",
                 "scripts/evidence/recover_native_evidence.py", "scripts/evidence/test_recover_native_evidence.py",
                 "docs/quality/2026-10-21-native-evidence-recovery.md"]
        self.assertFalse([(path, pattern) for path in owned for pattern in patterns if fnmatch.fnmatchcase(path, pattern)])
        workflow = (root / owned[0]).read_text()
        self.assertIn('branches: ["polish/**"]', workflow)
        self.assertIn("runs-on: ubuntu-24.04", workflow)
        self.assertIn("timeout-minutes: 15", workflow)
        self.assertNotIn("workflow_dispatch:", workflow)
        self.assertNotIn("ios-quality-${{", workflow)
        self.assertEqual(workflow.count("overwrite: false"), 4)
        self.assertEqual(workflow.count("compression-level: 0"), 4)
        self.assertNotIn("scripts/ci/", workflow)
        self.assertNotIn("xcodebuild", workflow)


if __name__ == "__main__":
    unittest.main()
