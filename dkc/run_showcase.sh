#!/bin/bash
for i in 2 3 4; do
  mkdir -p runs/run_$i
  echo "Running Showcase Case $i..."
  
  flutter test integration_test/jev_showcase_test.dart --dart-define=CASE_ID=$i -d AEEC8815-D378-41AA-894A-9CA6EB46657D > runs/run_$i/test.log 2>&1 &
  PID=$!
  
  echo "Waiting for UI to appear..."
  while true; do
    if grep -q "JEV Showcase Case $i" runs/run_$i/test.log 2>/dev/null; then
       sleep 5
       break
    fi
    if ! kill -0 $PID 2>/dev/null; then
       echo "Flutter test died unexpectedly for run $i."
       cat runs/run_$i/test.log
       break
    fi
    sleep 2
  done
  
  echo "Taking screenshot for Case $i..."
  xcrun simctl io AEEC8815-D378-41AA-894A-9CA6EB46657D screenshot runs/run_$i/screenshot.png
  sips -s format pdf runs/run_$i/screenshot.png --out runs/run_$i/details.pdf
  
  echo "Done with $i! Waiting for test to clean up..."
  wait $PID
done
echo "All showcases finished!"
