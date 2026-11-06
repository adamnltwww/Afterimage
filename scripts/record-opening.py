import os, signal, subprocess, sys, time
from pathlib import Path
device = sys.argv[1]
folder = Path('build'); folder.mkdir(exist_ok=True)
record = subprocess.Popen(['xcrun','simctl','io',device,'recordVideo','--codec=h264',str(folder/'opening-preview.mov')])
try:
    time.sleep(1)
    subprocess.run(['xcrun','simctl','launch','--terminate-running-process',device,'com.adamnltwww.afterimage',
                    '--ui-testing','--ui-reading-fixture','--ui-opening'],check=True,timeout=45)
    start=time.monotonic()
    for elapsed in [0.6,1.3,2.2,3.2,4.6,6.0]:
        time.sleep(max(0,start+elapsed-time.monotonic()))
        subprocess.run(['xcrun','simctl','io',device,'screenshot',str(folder/('opening-%02d.png'%int(elapsed*10)))],check=True,timeout=20)
finally:
    record.send_signal(signal.SIGINT)
    try: record.wait(timeout=12)
    except subprocess.TimeoutExpired:
        record.terminate()
        try: record.wait(timeout=5)
        except subprocess.TimeoutExpired: record.kill();record.wait()
