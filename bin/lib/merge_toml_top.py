"""fragment 의 top-level `key = value` 줄을 target TOML 의 top-level 에 교체·삽입한다.

섹션([..]) 안의 같은 이름 키는 건드리지 않는다. 결과는 stdout 으로 낸다(원본 불변).
usage: python3 merge_toml_top.py <target.toml> <fragment.toml>
"""
import re
import sys
from pathlib import Path

KEY_LINE = re.compile(r"^\s*([A-Za-z0-9_.-]+)\s*=")


def top_level_pairs(text: str) -> dict[str, str]:
    pairs: dict[str, str] = {}
    for line in text.splitlines():
        if line.lstrip().startswith("["):
            break
        match = KEY_LINE.match(line)
        if match:
            pairs[match.group(1)] = line.strip()
    return pairs


def merge(target: str, fragment: str) -> str:
    wanted = top_level_pairs(fragment)
    out: list[str] = []
    seen: set[str] = set()
    in_top = True
    for line in target.splitlines():
        if line.lstrip().startswith("["):
            in_top = False
        match = KEY_LINE.match(line) if in_top else None
        if match and match.group(1) in wanted:
            out.append(wanted[match.group(1)])
            seen.add(match.group(1))
        else:
            out.append(line)
    missing = [wanted[k] for k in wanted if k not in seen]
    return "\n".join(missing + out) + "\n"


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    target = Path(sys.argv[1])
    current = target.read_text(encoding="utf-8") if target.exists() else ""
    fragment = Path(sys.argv[2]).read_text(encoding="utf-8")
    sys.stdout.write(merge(current, fragment))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
