#!/bin/bash
tail -f /Users/blackbird/.gemini/antigravity/brain/7a16568a-f908-43a7-ab4a-259a6d5d312b/.system_generated/tasks/task-40.log | while read line; do
  if [[ "$line" == *"JEV Synthetic Cases UI"* ]]; then
    sleep 5
    xcrun simctl io AEEC8815-D378-41AA-894A-9CA6EB46657D screenshot /Users/blackbird/Everything/dev/DKC/protiti/runs/run_1/screenshot.png
    sips -s format pdf /Users/blackbird/Everything/dev/DKC/protiti/runs/run_1/screenshot.png --out /Users/blackbird/Everything/dev/DKC/protiti/runs/run_1/details.pdf
    echo "Screenshot taken!"
    pkill -P $$ tail
    break
  fi
done
