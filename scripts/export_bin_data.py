from __future__ import annotations

import argparse
import json
import os
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from export_pet_json import BinTableParser, sanitize_data


REQUIRED_TABLES = [
    "PETBASE_CONF",
    "PET_HANDBOOK",
    "PET_EVOLUTION_CONF",
    "LEVEL_SKILL_CONF",
    "SKILL_CONF",
    "PET_CLASSIS_CONF",
    "PET_EGG_CONF",
    "PET_RANDOM_EGG_CONF",
    "PET_NAME_MAP_CONF",
    "BAG_ITEM_CONF",
    "MEGAMAP_GATHERING_CONF",
    "MONSTER_CONF",
    "MONSTER_CATCH_CONF",
    "REWARD_CONF",
    "VISUAL_ITEM_CONF",
    "EXCHANGE_CONF",
    "ITEM_LABLE_TYPE_CONF",
]


@dataclass(frozen=True)
class TableSource:
    bin_root: Path
    conf_dir: Path
    data_dir: Path
    localize_dir: Path
    language: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Decode FModel Bin tables into the public/data/BinData RocoDataRows format. "
            "All tables are parsed and validated before any output is replaced."
        )
    )
    parser.add_argument(
        "--bin-root",
        default="NRC/Content/ScriptC/Data/Bin",
        help="Default directory containing BinConf, BinDataCompressed and BinLocalize.",
    )
    parser.add_argument(
        "--language",
        default="dev_CN",
        help="Default localization folder name under BinLocalize.",
    )
    parser.add_argument(
        "--manifest",
        help="Optional JSON manifest selecting source directories per table.",
    )
    parser.add_argument(
        "--output-dir",
        default="public/data/BinData",
        help="Directory that receives TABLE_NAME.json files.",
    )
    parser.add_argument(
        "--table",
        action="append",
        dest="tables",
        help="Export only this table; repeat for multiple tables. Defaults to all 17 required tables.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse and validate without writing files.",
    )
    parser.add_argument(
        "--allow-unresolved-refs",
        "--allow-missing-localization",
        dest="allow_unresolved_refs",
        action="store_true",
        help="Keep unresolved non-zero data/localization reference IDs instead of failing. Not recommended for releases.",
    )
    return parser.parse_args()


def read_manifest(path: Path | None) -> tuple[dict[str, Any], Path]:
    if path is None:
        return {}, Path.cwd()
    manifest_path = path.resolve()
    payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("Manifest root must be a JSON object")
    return payload, manifest_path.parent


def resolve_path(value: str | Path, base_dir: Path) -> Path:
    path = Path(value)
    return path if path.is_absolute() else (base_dir / path).resolve()


def build_source(
    table_name: str,
    args: argparse.Namespace,
    manifest: dict[str, Any],
    manifest_dir: Path,
) -> TableSource:
    defaults = manifest.get("defaults", {})
    table_configs = manifest.get("tables", {})
    if not isinstance(defaults, dict) or not isinstance(table_configs, dict):
        raise ValueError("Manifest defaults and tables must be JSON objects")
    table_config = table_configs.get(table_name, {})
    if not isinstance(table_config, dict):
        raise ValueError(f"Manifest entry for {table_name} must be a JSON object")

    config = {**defaults, **table_config}
    bin_root_value = config.get("bin_root", args.bin_root)
    bin_root = resolve_path(bin_root_value, manifest_dir if manifest else Path.cwd())
    language = str(config.get("language", args.language))

    conf_dir = resolve_path(config.get("conf_dir", bin_root / "BinConf"), manifest_dir)
    data_dir = resolve_path(
        config.get("data_dir", bin_root / "BinDataCompressed"), manifest_dir
    )
    localize_dir = resolve_path(
        config.get("localize_dir", bin_root / "BinLocalize" / language), manifest_dir
    )
    return TableSource(bin_root, conf_dir, data_dir, localize_dir, language)


def validate_source(table_name: str, source: TableSource) -> None:
    conf_path = source.conf_dir / f"{table_name}.json"
    required = [conf_path, source.data_dir / f"{table_name}.bytes"]
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        raise FileNotFoundError(
            f"{table_name}: missing required source file(s):\n  " + "\n  ".join(missing)
        )
    schema = json.loads(conf_path.read_text(encoding="utf-8"))
    if schema_contains_type(schema, "ELocalizedString"):
        localize_path = source.localize_dir / f"{table_name}.bytes"
        if not localize_path.is_file():
            raise FileNotFoundError(
                f"{table_name}: schema contains localized strings but {localize_path} is missing"
            )


def schema_contains_type(value: Any, type_name: str) -> bool:
    if isinstance(value, dict):
        if value.get("Type") == type_name:
            return True
        return any(schema_contains_type(item, type_name) for item in value.values())
    if isinstance(value, list):
        return any(schema_contains_type(item, type_name) for item in value)
    return False


def row_output_key(table_name: str, row: dict[str, Any]) -> str:
    value = row.get("id", row.get("_row_key"))
    if value is None or isinstance(value, (dict, list)):
        raise ValueError(f"{table_name}: row has no scalar id or row key")
    return str(value)


def build_table_payload(table_name: str, rows: list[dict[str, Any]]) -> dict[str, Any]:
    if not rows:
        raise ValueError(f"{table_name}: decoded table is empty")
    output_rows: dict[str, dict[str, Any]] = {}
    for raw_row in rows:
        row = sanitize_data(
            {key: value for key, value in raw_row.items() if not key.startswith("_row_")}
        )
        key = row_output_key(table_name, raw_row)
        if key in output_rows:
            raise ValueError(f"{table_name}: duplicate output row key {key}")
        output_rows[key] = row
    return {"RocoDataRows": output_rows}


def read_field_path(value: Any, field_path: str) -> Any:
    current = value
    for field in field_path.split("."):
        if not isinstance(current, dict) or field not in current:
            raise KeyError(field_path)
        current = current[field]
    return current


def validate_manifest_checks(
    manifest: dict[str, Any], payloads: dict[str, dict[str, Any]]
) -> int:
    checks = manifest.get("checks", [])
    if not isinstance(checks, list):
        raise ValueError("Manifest checks must be a JSON array")
    checked = 0
    for index, check in enumerate(checks):
        if not isinstance(check, dict):
            raise ValueError(f"Manifest check #{index + 1} must be a JSON object")
        table_name = check.get("table")
        if table_name not in payloads:
            continue
        if "id" not in check or "field" not in check or "equals" not in check:
            raise ValueError(
                f"Manifest check #{index + 1} requires table, id, field and equals"
            )
        row_key = str(check["id"])
        rows = payloads[table_name]["RocoDataRows"]
        if row_key not in rows:
            raise ValueError(f"Sentinel failed: {table_name}[{row_key}] does not exist")
        field_path = str(check["field"])
        try:
            actual = read_field_path(rows[row_key], field_path)
        except KeyError as error:
            raise ValueError(
                f"Sentinel failed: {table_name}[{row_key}].{field_path} does not exist"
            ) from error
        expected = check["equals"]
        if actual != expected:
            raise ValueError(
                f"Sentinel failed: {table_name}[{row_key}].{field_path} "
                f"expected {expected!r}, got {actual!r}"
            )
        checked += 1
    return checked


def write_payloads(output_dir: Path, payloads: dict[str, dict[str, Any]]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    staging_dir = Path(tempfile.mkdtemp(prefix=".bindata-export-", dir=output_dir))
    try:
        for table_name, payload in payloads.items():
            output_path = staging_dir / f"{table_name}.json"
            output_path.write_text(
                json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
        for table_name in payloads:
            os.replace(
                staging_dir / f"{table_name}.json",
                output_dir / f"{table_name}.json",
            )
    finally:
        shutil.rmtree(staging_dir, ignore_errors=True)


def main() -> None:
    args = parse_args()
    tables = args.tables or REQUIRED_TABLES
    unknown = sorted(set(tables) - set(REQUIRED_TABLES))
    if unknown:
        raise ValueError("Unsupported table(s): " + ", ".join(unknown))

    manifest_path = Path(args.manifest) if args.manifest else None
    manifest, manifest_dir = read_manifest(manifest_path)
    configured_tables = manifest.get("tables", {})
    if isinstance(configured_tables, dict):
        unknown_manifest_tables = sorted(set(configured_tables) - set(REQUIRED_TABLES))
        if unknown_manifest_tables:
            raise ValueError(
                "Manifest contains unsupported table(s): "
                + ", ".join(unknown_manifest_tables)
            )
    payloads: dict[str, dict[str, Any]] = {}

    for table_name in tables:
        source = build_source(table_name, args, manifest, manifest_dir)
        validate_source(table_name, source)
        parser = BinTableParser(
            source.bin_root,
            table_name,
            source.language,
            conf_dir=source.conf_dir,
            data_dir=source.data_dir,
            localize_dir=source.localize_dir,
            strict_refs=not args.allow_unresolved_refs,
        )
        payload = build_table_payload(table_name, parser.parse_all())
        payloads[table_name] = payload
        print(
            f"Parsed {table_name}: {len(payload['RocoDataRows'])} rows "
            f"(schema={source.conf_dir}, data={source.data_dir}, "
            f"localize={source.localize_dir})"
        )

    checked = validate_manifest_checks(manifest, payloads)
    if checked:
        print(f"Passed {checked} manifest sentinel check(s).")

    if args.dry_run:
        print(f"Validated {len(payloads)} table(s); dry run did not write output.")
        return

    output_dir = Path(args.output_dir).resolve()
    write_payloads(output_dir, payloads)
    print(f"Wrote {len(payloads)} table(s) to {output_dir}")


if __name__ == "__main__":
    main()
