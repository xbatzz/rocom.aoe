#!/usr/bin/env python3
"""Batch convert PNG images to WebP."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="批量将 PNG 图片转换为 WebP。",
    )
    parser.add_argument(
        "source",
        nargs="?",
        default=".",
        type=Path,
        help="PNG 文件或目录，默认当前目录。",
    )
    parser.add_argument(
        "-o",
        "--output-dir",
        type=Path,
        help="输出目录。未指定时在源文件旁生成同名 .webp。",
    )
    parser.add_argument(
        "-r",
        "--recursive",
        action="store_true",
        help="递归转换目录下的 PNG。",
    )
    parser.add_argument(
        "-q",
        "--quality",
        type=int,
        default=85,
        help="WebP 质量，范围 1-100，默认 85。",
    )
    parser.add_argument(
        "--lossless",
        action="store_true",
        help="使用无损 WebP。启用后会忽略 --quality。",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="覆盖已存在的 WebP 文件。",
    )
    parser.add_argument(
        "--delete-source",
        action="store_true",
        help="转换成功后删除源 PNG。",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="只打印将要转换的文件，不实际写入。",
    )
    return parser.parse_args()


def find_png_files(source: Path, recursive: bool) -> list[Path]:
    if source.is_file():
        return [source] if source.suffix.lower() == ".png" else []

    if not source.is_dir():
        raise FileNotFoundError(f"找不到路径：{source}")

    pattern = "**/*.png" if recursive else "*.png"
    return sorted(path for path in source.glob(pattern) if path.is_file())


def get_output_path(png_path: Path, source_root: Path, output_dir: Path | None) -> Path:
    if output_dir is None:
        return png_path.with_suffix(".webp")

    relative_path = png_path.name if source_root.is_file(
    ) else png_path.relative_to(source_root)
    return output_dir / Path(relative_path).with_suffix(".webp")


def convert_png_to_webp(
        png_path: Path,
        output_path: Path,
        quality: int,
        lossless: bool,
) -> None:
    try:
        from PIL import Image
    except ImportError as exc:  # pragma: no cover - helpful CLI failure path
        raise RuntimeError(
            "缺少依赖 Pillow，请先安装：python -m pip install Pillow"
        ) from exc

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(png_path) as image:
        image.save(
            output_path,
            "WEBP",
            quality=quality,
            lossless=lossless,
            method=6,
        )


def main() -> int:
    args = parse_args()

    if not 1 <= args.quality <= 100:
        print("错误：--quality 必须在 1 到 100 之间。", file=sys.stderr)
        return 2

    source = args.source.resolve()
    output_dir = args.output_dir.resolve() if args.output_dir else None

    try:
        png_files = find_png_files(source, args.recursive)
    except FileNotFoundError as exc:
        print(f"错误：{exc}", file=sys.stderr)
        return 2

    if not png_files:
        print("没有找到 PNG 文件。")
        return 0

    converted = 0
    skipped = 0
    failed = 0

    for png_path in png_files:
        output_path = get_output_path(png_path, source, output_dir)

        if output_path.exists() and not args.overwrite:
            skipped += 1
            print(f"跳过：{png_path} -> {output_path}（目标已存在）")
            continue

        if args.dry_run:
            print(f"预览：{png_path} -> {output_path}")
            continue

        try:
            convert_png_to_webp(png_path, output_path,
                                args.quality, args.lossless)
            if args.delete_source:
                png_path.unlink()
            converted += 1
            print(f"完成：{png_path} -> {output_path}")
        except Exception as exc:  # noqa: BLE001 - keep batch conversion going
            failed += 1
            print(f"失败：{png_path}（{exc}）", file=sys.stderr)

    print(
        f"汇总：转换 {converted} 个，跳过 {skipped} 个，失败 {failed} 个。"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
