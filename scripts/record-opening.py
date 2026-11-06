import os, signal, subprocess, sys, time
from pathlib import Path
device = sys.argv[1]
folder = Path('build'); folder.mkdir(exist_ok=True)
record = subprocess.Popen(['xcrun','simctl','io',device,'recordVideo','--codec=h264',str(folder/'opening-preview.mov')])
try:
    time.sleep(1)
    subprocess.run(['xcrun','simctl','launch','--terminate-running-process',device,'com.adamnltwww.afterimage',
                    '--ui-testing','--ui-reading-fixture','--ui-opening'],check=True,timeout=45)
    time.sleep(8)
finally:
    record.send_signal(signal.SIGINT)
    try: record.wait(timeout=12)
    except subprocess.TimeoutExpired:
        record.terminate()
        try: record.wait(timeout=5)
        except subprocess.TimeoutExpired: record.kill();record.wait()
shot=folder/'opening-landed.png'
try:
    subprocess.run(['xcrun','simctl','io',device,'screenshot',str(shot)],check=True,timeout=30)
except subprocess.TimeoutExpired:
    if not shot.is_file(): raise
