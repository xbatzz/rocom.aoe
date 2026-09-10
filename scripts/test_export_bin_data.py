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
    validate_table_relationships,
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

    def test_relationship_check_rejects_pseudo_pet_and_skill_ids(self):
        for payloads in [
            {"PET_HANDBOOK": {"RocoDataRows": {"8": {"include_petbase_id": [{"petbase_id": [999999]}]}}},
             "PETBASE_CONF": {"RocoDataRows": {"23": {"id": 23}}}},
            {"LEVEL_SKILL_CONF": {"RocoDataRows": {"23": {"level": [{"param": 999999}]}}},
             "SKILL_CONF": {"RocoDataRows": {"17": {"id": 17}}}},
        ]:
            with self.assertRaisesRegex(ValueError, "missing"):
                validate_table_relationships(payloads)


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


class ReferencedStructTests(unittest.TestCase):
    def parser(self, refs=None, localized=None):
        parser = object.__new__(BinTableParser)
        parser.table_name = "fixture"
        parser.strict_refs = True
        parser.refs = refs or {}
        parser.localized_refs = localized or {}
        parser.localize_dir = Path("fixture/dev_CN")
        return parser

    def test_handbook_reference_chains_440_and_466(self):
        # Minimal real S4 ref blobs, recorded before changing the decoder.
        schema = {"Properties": [
            {"Name": "petbase_id", "Type": "EUint32", "DynamicArray": True},
        ]}
        parser = self.parser({
            1918: bytes.fromhex("80f2090000"),
            2546: bytes.fromhex("a20e0000"),
            1969: bytes.fromhex("800c0a0000"),
            2572: bytes.fromhex("d40e0000"),
        })
        for handbook, blob, expected in [(440, "7e070000", 3746), (466, "b1070000", 3796)]:
            with self.subTest(handbook=handbook):
                self.assertEqual(parser.decode_struct_array(schema, bytes.fromhex(blob)),
                                 [{"petbase_id": [expected]}])

    def test_handbook_topic_fields_and_old_sentinel(self):
        schema = {"Properties": [
            {"Name": "topic_Id", "Type": "EUint32"},
            {"Name": "topic_type", "Type": "EInt32"},
            {"Name": "topic_desc", "Type": "ELocalizedString"},
            {"Name": "topic_cnt", "Type": "EUint32"},
            {"Name": "topic_reward", "Type": "EUint32"},
        ]}
        parser = self.parser({714: bytes.fromhex("f801000000010000007d0500000100000011150300")},
                             {1405: "捕捉1只精灵".encode()})
        self.assertEqual(parser.decode_struct_array(schema, bytes.fromhex("ca020000")), [{
            "topic_Id": 1, "topic_type": 1, "topic_desc": "捕捉1只精灵",
            "topic_cnt": 1, "topic_reward": 202001,
        }])
        level_schema = {"Properties": [{"Name": name, "Type": "EUint32"}
                                      for name in ["level_point", "stage", "param"]]}
        self.assertEqual(parser.decode_struct(level_schema, bytes.fromhex("e00100000001000000481f6b00")),
                         {"level_point": 1, "stage": 1, "param": 7020360})

    def test_dynamic_struct_array_with_sparse_nested_fields(self):
        child = {"Name": "child", "Properties": [
            {"Name": "missing", "Type": "EUint32"},
            {"Name": "label", "Type": "EString"},
            {"Name": "values", "Type": "EUint16", "DynamicArray": True},
        ]}
        outer = {"Name": "outer", "Properties": [
            {"Name": "child", "Type": "EStruct", "Struct": child},
            {"Name": "omitted", "Type": "EFloat"},
            {"Name": "count", "Type": "EInt32"},
        ]}
        parser = self.parser({
            10: struct.pack("<II", 11, 12),
            11: bytes([0xa0]) + struct.pack("<Ii", 13, -7),
            12: bytes([0x20]) + struct.pack("<i", 9),
            13: bytes([0x60]) + struct.pack("<II", 14, 15),
            14: b"nested text", 15: struct.pack("<HHH", 17, 513, 65535),
        })
        prop = {"Name": "entries", "Type": "EStruct", "DynamicArray": True, "Struct": outer}
        self.assertEqual(parser.decode_value(prop, struct.pack("<I", 10)), [
            {"child": {"label": "nested text", "values": [17, 513, 65535]}, "count": -7},
            {"count": 9},
        ])

    def test_rejects_bad_lengths_and_unresolved_nested_refs(self):
        parser = self.parser()
        schema = {"Name": "single", "Properties": [{"Name": "id", "Type": "EUint32"}]}
        for blob in [b"", b"\x80\x01", b"\x00\x01"]:
            with self.subTest(blob=blob), self.assertRaises(ValueError):
                parser.decode_struct(schema, blob)
        with self.assertRaisesRegex(ValueError, "truncated struct reference"):
            parser.decode_struct_array(schema, b"\x01")
        with self.assertRaisesRegex(ValueError, "unresolved data reference 123"):
            parser.decode_struct_array(schema, struct.pack("<I", 123))

    def test_bitmap_spans_multiple_bytes(self):
        parser = self.parser()
        schema = {"Properties": [{"Name": f"value{i}", "Type": "EUint32"} for i in range(10)]}
        self.assertEqual(parser.decode_struct(schema, bytes([0x80, 0x40]) + struct.pack("<II", 13, 29)),
                         {"value0": 13, "value9": 29})


CURRENT_BIN = Path(__file__).resolve().parents[1] / "NRC/Content/ScriptC/Data/Bin"

@unittest.skipUnless((CURRENT_BIN / "BinDataCompressed/PETBASE_CONF.bytes").is_file(),
                     "Local FModel export not installed; portable byte fixtures still run")
class CurrentSnapshotTests(unittest.TestCase):
    def test_current_sentinels_and_semantic_relationships(self):
        from export_bin_data import REQUIRED_TABLES
        payloads = {name: build_table_payload(name, BinTableParser(
            CURRENT_BIN, name, "dev_CN", strict_refs=True).parse_all()) for name in REQUIRED_TABLES}
        validate_table_relationships(payloads)
        for table, expected in {
            "PETBASE_CONF": {3001: "喵喵", 3746: "睡铃雪影娃娃", 3747: "莫比乌乌", 3796: "果实立方人"},
            "SKILL_CONF": {7021280: "缓一缓", 7030620: "麦芒"},
            "PET_HANDBOOK": {440: "睡铃雪影娃娃", 466: "果实立方人"},
            "BAG_ITEM_CONF": {100001: "一小箱金币"},
        }.items():
            for key, name in expected.items():
                self.assertEqual(payloads[table]["RocoDataRows"][str(key)]["name"], name)
        handbook = payloads["PET_HANDBOOK"]["RocoDataRows"]
        for key, pet in [(440, 3746), (466, 3796)]:
            self.assertEqual(handbook[str(key)]["include_petbase_id"], [{"petbase_id": [pet]}])
        self.assertEqual(handbook["466"]["pet_topic"][-1], {
            "topic_Id": 5, "topic_type": 4, "topic_desc": "使用1次麦芒",
            "topic_cnt": 1, "topic_reward": 205201,
        })


if __name__ == "__main__":
    unittest.main()
