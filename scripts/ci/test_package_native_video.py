"""Offline lossless-retention tests; these do not validate UIKit or video content."""

import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import zipfile

import package_native_video as video


class NativeVideoPackageTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.source = self.root / video.VIDEO_NAME
        self.parts = self.root / "parts"
        self.manifest = self.root / "manifest.json"
        self.content = bytes(range(201))
        self.source.write_bytes(self.content)

    def package(self, **kwargs):
        return video.package(self.source, self.parts, self.manifest, chunk_bytes=64, **kwargs)

    def test_lossless_parts_reassemble_original_and_do_not_modify_source(self):
        result = self.package()
        self.assertEqual(result["status"], "packaged-original-bytes")
        self.assertEqual([p["size_bytes"] for p in result["parts"]], [64, 64, 64, 9])
        self.assertEqual(result["source_sha256"], hashlib.sha256(self.content).hexdigest())
        self.assertEqual(result, json.loads(self.manifest.read_text()))
        for part in result["parts"]:
            self.assertEqual(result, json.loads((self.parts / f"part-{part['index']:03d}" / "manifest.json").read_text()))
        output = self.root / "restored.mp4"
        video.reassemble(self.manifest, self.parts, output)
        self.assertEqual(output.read_bytes(), self.content)
        self.assertEqual(self.source.read_bytes(), self.content)
        self.assertFalse(output.with_name("restored.mp4.partial").exists())

    def test_exact_boundary_has_no_empty_tail(self):
        self.source.write_bytes(self.content[:128])
        self.assertEqual([p["size_bytes"] for p in self.package()["parts"]], [64, 64])

    def test_small_recording_retains_one_part(self):
        self.source.write_bytes(b"recording")
        self.assertEqual([p["size_bytes"] for p in self.package()["parts"]], [9])

    def test_missing_recording_is_explicitly_unavailable_not_a_pass(self):
        self.source.unlink()
        result = self.package()
        self.assertEqual(result["status"], "recording-unavailable")
        self.assertEqual(result["parts"], [])
        self.assertTrue(result["visualReviewRequired"])
        self.assertFalse(self.parts.exists())
        with self.assertRaises(video.PackageError):
            video.reassemble(self.manifest, self.parts, self.root / "restored.mp4")

    def test_empty_recording_is_preserved_and_not_packaged_as_playable(self):
        self.source.write_bytes(b"")
        result = self.package()
        self.assertEqual(result["status"], "recording-unavailable")
        self.assertEqual(self.source.read_bytes(), b"")
        self.assertEqual(result["parts"], [])

    def test_capacity_rejects_before_creating_any_output(self):
        with mock.patch.object(video, "MAX_PARTS", 3), self.assertRaises(video.PackageError):
            self.package()
        self.assertFalse(self.parts.exists())
        self.assertFalse(self.manifest.exists())
        self.assertEqual(self.source.read_bytes(), self.content)

    def test_does_not_overwrite_any_previous_package_or_manifest(self):
        self.package()
        before = self.manifest.read_bytes()
        with self.assertRaises(video.PackageError):
            self.package()
        self.assertEqual(self.manifest.read_bytes(), before)
        with self.assertRaises(video.PackageError):
            video.package(self.source, self.root / "new-parts", self.manifest, chunk_bytes=64)
        self.assertFalse((self.root / "new-parts").exists())

    def test_only_public_identity_is_copied_from_environment(self):
        result = self.package(environ={"GITHUB_SHA": "a" * 40, "NATIVE_SCENARIO": "compact",
                                       "GITHUB_TOKEN": "synthetic-private-value", "OTHER_SECRET": "private"})
        self.assertEqual(result["provenance"]["GITHUB_SHA"], "a" * 40)
        self.assertEqual(result["provenance"]["NATIVE_SCENARIO"], "compact")
        self.assertNotIn("GITHUB_TOKEN", result["provenance"])
        self.assertNotIn("synthetic-private-value", self.manifest.read_text())

    def test_wrong_part_bytes_or_missing_part_prevent_candidate_output(self):
        result = self.package()
        part = self.parts / "part-000" / result["parts"][0]["name"]
        original = part.read_bytes()
        output = self.root / "restored.mp4"
        for content in (original + b"x", b"x" * len(original), original[:-1]):
            with self.subTest(size=len(content)):
                part.write_bytes(content)
                with self.assertRaises(video.PackageError):
                    video.reassemble(self.manifest, self.parts, output)
                self.assertFalse(output.exists())
                self.assertFalse(output.with_name("restored.mp4.partial").exists())
        part.unlink()
        with self.assertRaises(video.PackageError):
            video.reassemble(self.manifest, self.parts, output)

    def test_invalid_manifest_names_counts_order_sizes_and_digests_are_rejected(self):
        result = self.package()
        mutations = [
            lambda d: d.update(format="other"),
            lambda d: d.update(status="recording-unavailable"),
            lambda d: d.update(source_name="../private"),
            lambda d: d.update(max_parts=100),
            lambda d: d.update(source_size_bytes=True),
            lambda d: d.update(source_size_bytes=0),
            lambda d: d.update(chunk_bytes=video.CHUNK_BYTES + 1),
            lambda d: d.update(source_sha256="not-a-digest"),
            lambda d: d["parts"].pop(),
            lambda d: d["parts"].reverse(),
            lambda d: d["parts"][0].update(index=True),
            lambda d: d["parts"][0].update(name="../private"),
            lambda d: d["parts"][0].update(size_bytes=True),
            lambda d: d["parts"][0].update(size_bytes=63),
            lambda d: d["parts"][0].update(sha256="no"),
        ]
        for index, mutate in enumerate(mutations):
            with self.subTest(index=index):
                changed = copy.deepcopy(result)
                mutate(changed)
                with self.assertRaises(video.PackageError):
                    video.validate_manifest(changed)

    def test_wrong_original_hash_removes_only_our_incomplete_candidate(self):
        result = self.package()
        result["source_sha256"] = "0" * 64
        self.manifest.write_text(json.dumps(result))
        output = self.root / "restored.mp4"
        with self.assertRaises(video.PackageError):
            video.reassemble(self.manifest, self.parts, output)
        self.assertFalse(output.exists())
        self.assertFalse(output.with_name("restored.mp4.partial").exists())
        self.assertEqual(self.source.read_bytes(), self.content)

    def test_existing_output_and_partial_are_not_overwritten(self):
        self.package()
        output = self.root / "restored.mp4"
        output.write_bytes(b"keep")
        with self.assertRaises(video.PackageError):
            video.reassemble(self.manifest, self.parts, output)
        self.assertEqual(output.read_bytes(), b"keep")
        output.unlink()
        partial = output.with_name("restored.mp4.partial")
        partial.write_bytes(b"keep partial")
        with self.assertRaises(video.PackageError):
            video.reassemble(self.manifest, self.parts, output)
        self.assertEqual(partial.read_bytes(), b"keep partial")

    def test_racing_partial_creation_is_not_deleted_when_exclusive_open_fails(self):
        self.package()
        output = self.root / "restored.mp4"
        partial = output.with_name("restored.mp4.partial")
        original_open = Path.open

        def open_with_race(path, mode="r", *args, **kwargs):
            if path == partial and mode == "xb":
                with original_open(partial, "wb") as other:
                    other.write(b"owned by another actor")
            return original_open(path, mode, *args, **kwargs)

        with mock.patch.object(Path, "open", open_with_race), self.assertRaises(FileExistsError):
            video.reassemble(self.manifest, self.parts, output)
        self.assertEqual(partial.read_bytes(), b"owned by another actor")
        self.assertFalse(output.exists())

    def test_actions_stripped_archive_roots_reassemble_with_named_extraction_directories(self):
        result = self.package()
        downloaded = self.root / "downloaded"
        downloaded.mkdir()
        for part in result["parts"]:
            dirname = f"part-{part['index']:03d}"
            archive = self.root / f"native-video-standard-source-1-{dirname}.zip"
            with zipfile.ZipFile(archive, "w") as zipped:
                # upload-artifact strips the uploaded directory itself.
                for path in (self.parts / dirname).iterdir():
                    zipped.write(path, path.name)
            with zipfile.ZipFile(archive) as zipped:
                zipped.extractall(downloaded / dirname)
        output = self.root / "downloaded-original.mp4"
        video.reassemble(downloaded / "part-000/manifest.json", downloaded, output)
        self.assertEqual(output.read_bytes(), self.content)

    def test_linked_source_or_part_is_rejected(self):
        other = self.root / "other.mp4"
        self.source.rename(other)
        self.source.symlink_to(other)
        with self.assertRaises(video.PackageError):
            self.package()
        self.source.unlink()
        other.rename(self.source)
        result = self.package()
        part = self.parts / "part-000" / result["parts"][0]["name"]
        moved = self.root / "moved-part"
        part.rename(moved)
        part.symlink_to(moved)
        with self.assertRaises(video.PackageError):
            video.reassemble(self.manifest, self.parts, self.root / "restored.mp4")

    def test_source_change_during_read_never_produces_a_success_manifest(self):
        actual = video.file_identity(self.source)
        changed = (*actual[:3], actual[3] + 1)
        with mock.patch.object(video, "file_identity", side_effect=[actual, changed]), self.assertRaises(video.PackageError):
            self.package()
        self.assertFalse(self.manifest.exists())
        self.assertEqual(self.source.read_bytes(), self.content)


if __name__ == "__main__":
    unittest.main()
