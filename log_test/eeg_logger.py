#!/usr/bin/env python3
"""FPGA(log_test_top)가 USB-Serial로 보내는 줄을 받아 CSV로 저장한다.

설치:  pip install pyserial
사용:  python eeg_logger.py --list              # 연결된 COM 포트 목록
       python eeg_logger.py COM5                # 기록 시작 (Ctrl+C로 종료)
       python eeg_logger.py --replay raw.log    # 저장해 둔 원본 로그를 다시 CSV로 변환

저장 위치: logs/<날짜_시각>/ 아래
  eeg.csv     뇌파 요약 (1초마다)
  beat.csv    박동마다 간격과 BPM
  events.csv  DIP 스위치 변경(F), 마커 버튼(M)
  raw.log     받은 줄 원본 (PC 시각 + 줄)
"""
import argparse
import csv
import datetime
import os
import sys

BANDS = ["delta", "theta", "low_alpha", "high_alpha",
         "low_beta", "high_beta", "low_gamma", "mid_gamma"]
DIPS = [f"dip{i}" for i in range(1, 9)]          # dip1 = DIPSW1 = flag bit 0
COMMON = ["pc_time", "fpga_ms", "flag"] + DIPS

HEADERS = {
    "E": COMMON + ["poor_signal", "attention", "meditation"] + BANDS,
    "B": COMMON + ["interval_ms", "bpm"],
    "F": COMMON + ["event"],
}
FILES = {"E": "eeg.csv", "B": "beat.csv", "F": "events.csv"}


def parse(line):
    """한 줄을 (파일 종류, 값 목록)으로 바꾼다. 형식이 틀리면 None."""
    p = line.strip().split(",")
    try:
        kind = p[0]
        if kind == "E" and len(p) == 14:
            nums = [int(x, 16) for x in p[1:]]
        elif kind == "B" and len(p) == 4:
            nums = [int(x, 16) for x in p[1:]]
        elif kind in ("F", "M") and len(p) == 3:
            nums = [int(x, 16) for x in p[1:]]
        else:
            return None
    except ValueError:
        return None

    t, flag = nums[0], nums[1]
    dips = [(flag >> i) & 1 for i in range(8)]
    common = [t, flag] + dips
    if kind == "E":
        return "E", common + nums[2:]
    if kind == "B":
        interval = nums[2]
        # 300ms 미만은 FPGA가 걸러내고, 3000ms 이상은 쉬었다가 온 첫 박동이라 BPM 없음
        bpm = round(60000 / interval) if 300 <= interval < 3000 else ""
        return "B", common + [interval, bpm]
    return "F", common + ["dip_change" if kind == "F" else "marker"]


class Session:
    def __init__(self, out_root):
        name = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        self.dir = os.path.join(out_root, name)
        os.makedirs(self.dir, exist_ok=True)
        self.files, self.writers = {}, {}
        for k, fname in FILES.items():
            f = open(os.path.join(self.dir, fname), "w", newline="", encoding="utf-8-sig")
            w = csv.writer(f)
            w.writerow(HEADERS[k])
            self.files[k], self.writers[k] = f, w
        self.raw = open(os.path.join(self.dir, "raw.log"), "w", encoding="utf-8")
        self.count = {"E": 0, "B": 0, "F": 0, "bad": 0}

    def add(self, line, pc_time):
        line = line.strip()
        if not line:
            return None
        self.raw.write(f"{pc_time}\t{line}\n")
        r = parse(line)
        if r is None:
            self.count["bad"] += 1
            return None
        kind, values = r
        self.writers[kind].writerow([pc_time] + values)
        self.count[kind] += 1
        return kind, values

    def flush(self):
        for f in self.files.values():
            f.flush()
        self.raw.flush()

    def close(self):
        for f in self.files.values():
            f.close()
        self.raw.close()


def show(r):
    kind, v = r
    if kind == "E":
        print(f"[EEG ] t={v[0]:>9}ms flag={v[1]:3d} poor={v[10]:3d} att={v[11]:3d} med={v[12]:3d}")
    elif kind == "B":
        print(f"[BEAT] t={v[0]:>9}ms flag={v[1]:3d} interval={v[10]:4d}ms bpm={v[11]}")
    else:
        print(f"[{v[10].upper():^4}] t={v[0]:>9}ms flag={v[1]:3d} ({format(v[1], '08b')})")


def now():
    return datetime.datetime.now().isoformat(timespec="milliseconds")


def run_serial(port, baud, out_root):
    import serial  # pip install pyserial
    s = Session(out_root)
    print(f"{port} {baud}bps 기록 시작 -> {s.dir}  (Ctrl+C로 종료)")
    try:
        with serial.serial_for_url(port, baudrate=baud, timeout=1) as ser:
            while True:
                b = ser.readline()
                if not b:
                    continue
                r = s.add(b.decode("ascii", errors="replace"), now())
                if r:
                    show(r)
                s.flush()
    except KeyboardInterrupt:
        pass
    finally:
        s.close()
        print(f"종료. 저장된 줄 수: {s.count}  ->  {s.dir}")


def run_replay(path, out_root):
    s = Session(out_root)
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            # raw.log 형식(PC시각<TAB>줄)과 줄만 있는 파일 둘 다 받음
            pc_time, _, rest = line.rstrip("\n").rpartition("\t")
            s.add(rest, pc_time)
    s.close()
    print(f"변환 완료: {s.count}  ->  {s.dir}")
    return s.dir


def main():
    ap = argparse.ArgumentParser(description="FPGA 뇌파/심박 로그를 CSV로 저장")
    ap.add_argument("port", nargs="?", help="COM 포트 (예: COM5)")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--out", default="logs", help="저장 폴더 (기본: logs)")
    ap.add_argument("--list", action="store_true", help="COM 포트 목록 보기")
    ap.add_argument("--replay", metavar="FILE", help="저장된 로그 파일을 CSV로 변환")
    a = ap.parse_args()

    if a.list:
        from serial.tools import list_ports
        for p in list_ports.comports():
            print(f"{p.device}\t{p.description}")
        return
    if a.replay:
        run_replay(a.replay, a.out)
        return
    if not a.port:
        ap.error("COM 포트를 지정하세요 (--list로 확인)")
    run_serial(a.port, a.baud, a.out)


if __name__ == "__main__":
    sys.exit(main())
