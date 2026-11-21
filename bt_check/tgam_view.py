#!/usr/bin/env python3
"""뇌파센서(TGAM) 동작 확인용: 블루투스 COM 포트로 들어오는 패킷을 해석해 화면에 출력

설치:  pip install pyserial
사용:  python tgam_view.py --list     # COM 포트 목록
       python tgam_view.py COM7       # Ctrl+C로 종료
"""
import argparse
import time


def packets(read_byte):
    """ThinkGear 패킷: AA AA <길이> <payload> <체크섬>. 체크섬이 맞는 payload만 돌려준다."""
    while True:
        if read_byte() != 0xAA or read_byte() != 0xAA:
            continue
        n = read_byte()
        while n == 0xAA:              # sync가 더 붙은 경우
            n = read_byte()
        if n > 169:
            continue
        payload = bytes(read_byte() for _ in range(n))
        if read_byte() == (~sum(payload)) & 0xFF:
            yield payload


def rows(payload):
    """payload -> {코드: 값 바이트}"""
    out, i = {}, 0
    while i < len(payload):
        while i < len(payload) and payload[i] == 0x55:   # EXCODE
            i += 1
        if i >= len(payload):
            break
        code = payload[i]; i += 1
        if code >= 0x80:
            ln = payload[i]; i += 1
        else:
            ln = 1
        out[code] = payload[i:i + ln]; i += ln
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("port", nargs="?")
    ap.add_argument("--baud", type=int, default=57600)
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args()

    import serial
    if a.list:
        from serial.tools import list_ports
        for p in list_ports.comports():
            print(f"{p.device}\t{p.description}")
        return
    if not a.port:
        ap.error("COM 포트를 지정하세요 (--list로 확인)")

    with serial.serial_for_url(a.port, baudrate=a.baud, timeout=5) as ser:
        def read_byte():
            b = ser.read(1)
            if not b:
                raise TimeoutError("5초 동안 데이터가 없음: 센서 전원, 페어링, COM 포트를 확인하세요")
            return b[0]

        print(f"{a.port} 연결됨. 데이터 기다리는 중... (Ctrl+C로 종료)")
        raw_count, t0 = 0, time.time()
        try:
            for p in packets(read_byte):
                r = rows(p)
                if 0x80 in r:
                    raw_count += 1
                if 0x04 in r or 0x02 in r:          # 1초마다 오는 요약 패킷
                    poor = r.get(0x02, b"\xff")[0]
                    att = r.get(0x04, b"\x00")[0]
                    med = r.get(0x05, b"\x00")[0]
                    rate = raw_count / max(time.time() - t0, 1e-6)
                    state = "양호" if poor == 0 else ("전극 미접촉" if poor == 200 else "잡음 있음")
                    print(f"신호={poor:3d} ({state:6s})  Attention={att:3d}  Meditation={med:3d}  Raw {rate:4.0f}개/초")
                    raw_count, t0 = 0, time.time()
        except TimeoutError as e:
            print(e)
        except KeyboardInterrupt:
            print("종료")


if __name__ == "__main__":
    main()
