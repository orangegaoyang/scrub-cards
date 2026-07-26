#!/usr/bin/env python3
"""扫描 scripts/ scenes/ data/ 里所有文本，按用到的字形 subset 字体。
跑前需：pip install fonttools
新增中文文案后若出现方框，重跑本脚本即可。

用法：python3 tools/subset_font.py [源字体.ttf]
默认源字体：organizer 兄弟项目的 ArialUnicode.ttf
输出：assets/fonts/ScrubCJK.ttf
"""
import glob
import os
import subprocess
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC_DEFAULT = "/Users/gaoyang/Workspace/organizer/assets/fonts/ArialUnicode.ttf"
OUT = os.path.join(ROOT, "assets", "fonts", "ScrubCJK.ttf")
GLYPHS = "/tmp/scrub_glyphs.txt"


def collect_glyphs() -> None:
	chars = set()
	for pat in ["scripts/**/*.gd", "scenes/*.tscn", "data/*.json"]:
		for p in glob.glob(os.path.join(ROOT, pat), recursive=True):
			with open(p, encoding="utf-8") as f:
				chars.update(f.read())
	# 保险：数字、字母、常用标点
	chars.update("0123456789")
	chars.update("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
	chars.update("·—✓✗★☆％():,.!?- ")
	with open(GLYPHS, "w", encoding="utf-8") as f:
		f.write("".join(sorted(chars)))
	print("glyph chars:", len(chars))


def main() -> None:
	src = sys.argv[1] if len(sys.argv) > 1 else SRC_DEFAULT
	collect_glyphs()
	cmd = [
		"pyftsubset", src,
		"--text-file=" + GLYPHS,
		"--output-file=" + OUT,
		"--no-hinting", "--desubroutinize",
	]
	subprocess.run(cmd, check=True)
	size = os.path.getsize(OUT)
	print("wrote", OUT, "(%d bytes)" % size)


if __name__ == "__main__":
	main()
