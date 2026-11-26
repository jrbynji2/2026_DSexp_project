"""TGAM1 블루투스 확인용: 블루투스 COM 포트로 ThinkGear 패킷을 받아 화면에 보여주고 CSV로 저장 (FPGA 없이)

사용법:
  pip install pyserial
  python tgam_bluetooth.py --list        # COM 포트 목록 (블루투스는 '보내는 쪽(Outgoing)' 포트 사용)
  python tgam_bluetooth.py COM7          # 수신 시작, Ctrl+C로 종료
  python tgam_bluetooth.py COM7 --raw    # Raw 뇌파(약 512Hz)도 raw.csv로 저장
  python tgam_bluetooth.py --test        # 파서 자체 점검

저장: logs/<날짜_시각>/eeg.csv (1초마다 Poor Signal, Attention, Meditation, 8개 대역 파워)
"""
import argparse
import csv
import os
import sys
import time

BANDS = ["delta", "theta", "lowA", "highA", "lowB", "highB", "lowG", "midG"]


def parse_payload(p):
    """payload 바이트 -> {'poor','att','med','raw','power'} 중 들어있는 것만"""
    d, i = {}, 0
    while i < len(p):
        while i < len(p) and p[i] == 0x55:  # EXCODE (쓰지 않음)
            i += 1
        if i >= len(p):
            break
        code = p[i]
        i += 1
        if code < 0x80:
            v = p[i]
            i += 1
        else:
            n = p[i]
            v = p[i + 1:i + 1 + n]
            i += 1 + n
        if code == 0x02:
            d["poor"] = v
        elif code == 0x04:
            d["att"] = v
        elif code == 0x05:
            d["med"] = v
        elif code == 0x80 and len(v) == 2:
            d["raw"] = int.from_bytes(v, "big", signed=True)
        elif code == 0x83 and len(v) == 24:
            d["power"] = [int.from_bytes(v[k:k + 3], "big") for k in range(0, 24, 3)]
    return d


class Parser:
    """바이트 스트림 -> 체크섬이 맞는 패킷들. bad = 체크섬 오류 수"""

    def __init__(self):
        self.buf = bytearray()
        self.bad = 0

    def feed(self, data):
        self.buf += data
        out, b = [], self.buf
        while True:
            i = b.find(b"\xaa\xaa")
            if i < 0:
                del b[:-1 if b[-1:] == b"\xaa" else len(b)]
                break
            del b[:i]
            if len(b) < 3:
                break
            n = b[2]
            if n == 0xAA:          # AA AA AA: 동기 바이트가 하나 더 있는 경우
                del b[0]
                continue
            if n > 169:
                del b[:2]
                continue
            if len(b) < 4 + n:
                break
            payload, chk = bytes(b[3:3 + n]), b[3 + n]
            if (~sum(payload)) & 0xFF == chk:
                out.append(parse_payload(payload))
                del b[:4 + n]
            else:
                self.bad += 1
                del b[:2]
        return out


def self_test():
    def pkt(payload):
        return b"\xaa\xaa" + bytes([len(payload)]) + payload + bytes([(~sum(payload)) & 0xFF])

    big = bytes([0x02, 0, 0x83, 24]) + bytes(range(24)) + bytes([0x04, 55, 0x05, 66])
    raw = bytes([0x80, 2, 0xFF, 0xF0])
    stream = b"\x00\xaa" + pkt(raw) + pkt(big) + b"\xaa\xaa\x04\x80\x02\x00\x00\x00" + pkt(raw)
    p = Parser()
    got = p.feed(stream[:7]) + p.feed(stream[7:])  # 중간에 끊겨 들어와도 됨
    assert got[0] == {"raw": -16}, got
    assert got[1]["poor"] == 0 and got[1]["att"] == 55 and got[1]["med"] == 66, got
    assert got[1]["power"][0] == 0x000102 and got[1]["power"][7] == 0x151617, got
    assert got[2] == {"raw": -16} and p.bad == 1 and len(got) == 3, (got, p.bad)
    print("self test OK")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("port", nargs="?")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--raw", action="store_true", help="Raw 뇌파도 raw.csv로 저장")
    ap.add_argument("--test", action="store_true")
    a = ap.parse_args()
    if a.test:
        return self_test()

    import serial
    from serial.tools import list_ports
    if a.list or not a.port:
        for p in list_ports.comports():
            print(p.device, "-", p.description)
        return

    # 블루투스 가상 COM은 PC 쪽 baud를 무시하지만, 유선 연결도 되도록 TGAM 속도로 연다
    ser = serial.Serial(a.port, 57600, timeout=0.2)
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs", time.strftime("%Y%m%d_%H%M%S"))
    os.makedirs(out_dir)
    eeg_f = open(os.path.join(out_dir, "eeg.csv"), "w", newline="")
    eeg = csv.writer(eeg_f)
    eeg.writerow(["pc_time", "poor", "att", "med"] + BANDS)
    raw_f = open(os.path.join(out_dir, "raw.csv"), "w", newline="") if a.raw else None
    raw = csv.writer(raw_f) if raw_f else None
    if raw:
        raw.writerow(["pc_time", "raw"])
    print("저장 위치:", out_dir)
    print("time      poor  att  med  raw/s  chk_err")

    p, nbytes, nraw, last = Parser(), 0, 0, time.time()
    try:
        while True:
            data = ser.read(512)
            nbytes += len(data)
            now = time.time()
            for d in p.feed(data):
                if "raw" in d:
                    nraw += 1
                    if raw:
                        raw.writerow([f"{now:.3f}", d["raw"]])
                if "poor" in d or "att" in d:
                    pw = d.get("power", [""] * 8)
                    eeg.writerow([f"{now:.3f}", d.get("poor", ""), d.get("att", ""), d.get("med", "")] + pw)
                    eeg_f.flush()
                    print(f"{time.strftime('%H:%M:%S')}  {d.get('poor', '-'):>4} {d.get('att', '-'):>4} "
                          f"{d.get('med', '-'):>4}  {nraw:>5}  {p.bad:>7}")
                    nraw = 0
            if now - last > 3 and nbytes == 0:
                print("3초 동안 받은 바이트 없음: 포트(Outgoing인지), TGAM 전원, 페어링 확인")
                last = now
            elif nbytes:
                last, nbytes = now, 0
    except KeyboardInterrupt:
        pass
    finally:
        ser.close()
        eeg_f.close()
        if raw_f:
            raw_f.close()


if __name__ == "__main__":
    sys.exit(main())
