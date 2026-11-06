import os, signal, subprocess, sys, time
from pathlib import Path
device = sys.argv[1]
folder = Path('build'); folder.mkdir(exist_ok=True)
movie=folder/'opening-preview.mov'
record_log=folder/'opening-recording.log'
stream=record_log.open('w')
record = subprocess.Popen(['xcrun','simctl','io',device,'recordVideo','--codec=h264',str(movie)],stdout=stream,stderr=subprocess.STDOUT)
try:
    ready=False
    for attempt in range(600):
        if record.poll() is not None: raise RuntimeError('Recorder exited before its first frame; see opening-recording.log')
        output=record_log.read_text(errors='replace')
        if 'Recording started' in output or (movie.is_file() and movie.stat().st_size>1024):
            ready=True;break
        time.sleep(0.25)
    if not ready: raise RuntimeError('Recorder did not become ready; see opening-recording.log')
    subprocess.run(['xcrun','simctl','launch','--terminate-running-process',device,'com.adamnltwww.afterimage',
                    '--ui-testing','--ui-reading-fixture','--ui-opening'],check=True,timeout=45)
    time.sleep(10)
finally:
    record.send_signal(signal.SIGINT)
    try: record.wait(timeout=30)
    except subprocess.TimeoutExpired:
        record.terminate()
        try: record.wait(timeout=5)
        except subprocess.TimeoutExpired: record.kill();record.wait()
    stream.close()
if not movie.is_file() or movie.stat().st_size<1024: raise RuntimeError('No usable launch recording was produced')
