from __future__ import annotations

import json
import struct
import tempfile
import unittest
from pathlib import Path

from export_bin_data import (
    build_source,
    build_table_payload,
    validate_manifest_checks,
    validate_source,
    write_payloads,
)
from export_pet_json import BinTableParser


TABLE_NAME = "PETBASE_CONF"


def write_fixture(bin_root: Path, *, include_localization: bool = True) -> None:
    conf_dir = bin_root / "BinConf"
    data_dir = bin_root / "BinDataCompressed"
    localize_dir = bin_root / "BinLocalize" / "dev_CN"
    conf_dir.mkdir(parents=True)
    data_dir.mkdir(parents=True)
    localize_dir.mkdir(parents=True)

    schema = {
        "Properties": [
            {"Name": "id", "Type": "EUint32"},
            {"Name": "name", "Type": "ELocalizedString"},
        ]
    }
    (conf_dir / f"{TABLE_NAME}.json").write_text(
        json.dumps(schema), encoding="utf-8"
    )

    row = bytes([0b11000000]) + struct.pack("<II", 42, 7)
    row_index = struct.pack("<IIII", 42, len(row), 16, 0)
    meta = [0] * 16
    meta[3] = 1
    meta[4] = 8
    meta[6] = 0
    meta[9] = 16
    data = row_index + row + struct.pack("<" + "I" * 16, *meta)
    (data_dir / f"{TABLE_NAME}.bytes").write_bytes(data)

    if include_localization:
        text = "测试精灵".encode("utf-8") + b"\x00"
        localized_index = struct.pack("<IIII", 7, len(text), 0, 0)
        localized_meta = [0] * 8
        localized_meta[1] = len(text)
        localized_meta[3] = 1
        localized = (
            text
            + localized_index
            + struct.pack("<" + "I" * 8, *localized_meta)
        )
        (localize_dir / f"{TABLE_NAME}.bytes").write_bytes(localized)


class ExportBinDataTests(unittest.TestCase):
    def test_decodes_roco_data_rows_payload(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            bin_root = Path(temp_dir) / "Bin"
            write_fixture(bin_root)
            parser = BinTableParser(
                bin_root, TABLE_NAME, "dev_CN", strict_refs=True
            )
            payload = build_table_payload(TABLE_NAME, parser.parse_all())
            self.assertEqual(
                payload,
                {"RocoDataRows": {"42": {"id": 42, "name": "测试精灵"}}},
            )

    def test_missing_required_localization_fails_before_decode(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            bin_root = Path(temp_dir) / "Bin"
            write_fixture(bin_root, include_localization=False)
            source = type(
                "Source",
                (),
                {
                    "conf_dir": bin_root / "BinConf",
                    "data_dir": bin_root / "BinDataCompressed",
                    "localize_dir": bin_root / "BinLocalize" / "dev_CN",
                },
            )()
            with self.assertRaisesRegex(FileNotFoundError, "localized strings"):
                validate_source(TABLE_NAME, source)

    def test_manifest_can_select_split_source_directories(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            base_dir = Path(temp_dir)
            args = type(
                "Args",
                (),
                {"bin_root": "unused", "language": "dev_CN"},
            )()
            manifest = {
                "defaults": {"bin_root": "base/Bin"},
                "tables": {
                    TABLE_NAME: {
                        "conf_dir": "schema/BinConf",
                        "data_dir": "patch/BinDataCompressed",
                        "localize_dir": "locale/dev_CN",
                    }
                },
            }
            source = build_source(TABLE_NAME, args, manifest, base_dir)
            self.assertEqual(source.conf_dir, (base_dir / "schema/BinConf").resolve())
            self.assertEqual(
                source.data_dir, (base_dir / "patch/BinDataCompressed").resolve()
            )
            self.assertEqual(
                source.localize_dir, (base_dir / "locale/dev_CN").resolve()
            )

    def test_writes_complete_json_payload(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output_dir = Path(temp_dir) / "output"
            payload = {"RocoDataRows": {"42": {"id": 42, "name": "测试精灵"}}}
            write_payloads(output_dir, {TABLE_NAME: payload})
            written = json.loads(
                (output_dir / f"{TABLE_NAME}.json").read_text(encoding="utf-8")
            )
            self.assertEqual(written, payload)

    def test_manifest_sentinel_detects_localization_mismatch(self) -> None:
        payload = {"RocoDataRows": {"42": {"id": 42, "name": "错误名称"}}}
        manifest = {
            "checks": [
                {
                    "table": TABLE_NAME,
                    "id": 42,
                    "field": "name",
                    "equals": "测试精灵",
                }
            ]
        }
        with self.assertRaisesRegex(ValueError, "Sentinel failed"):
            validate_manifest_checks(manifest, {TABLE_NAME: payload})


if __name__ == "__main__":
    unittest.main()
