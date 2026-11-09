import cv2
import time
import numpy as np

CAMERA = "/dev/video0"
OUTPUT = "camera_test.jpg"

cap = cv2.VideoCapture(CAMERA, cv2.CAP_V4L2)

if not cap.isOpened():
    raise RuntimeError(f"Cannot open camera: {CAMERA}")

# Camera configuration
cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
cap.set(cv2.CAP_PROP_FPS, 30)

print("Camera opened")

# Give camera time to initialize
time.sleep(3)

frame = None

# Read several frames because the first frames may be black
for i in range(30):
    ret, current_frame = cap.read()

    if not ret:
        print(f"Frame {i + 1}: FAILED")
        continue

    mean_brightness = float(np.mean(current_frame))

    print(
        f"Frame {i + 1}: "
        f"resolution={current_frame.shape[1]}x{current_frame.shape[0]} "
        f"brightness={mean_brightness:.2f}"
    )

    frame = current_frame

    time.sleep(0.05)

cap.release()

if frame is None:
    raise RuntimeError("Failed to capture any frame")

height, width = frame.shape[:2]

print(f"Final resolution: {width}x{height}")

success = cv2.imwrite(OUTPUT, frame)

if not success:
    raise RuntimeError("Failed to save image")

print(f"Saved: {OUTPUT}")

# Final image statistics
mean = float(np.mean(frame))
minimum = int(np.min(frame))
maximum = int(np.max(frame))

print(f"Image brightness: {mean:.2f}")
print(f"Min pixel: {minimum}")
print(f"Max pixel: {maximum}")

if maximum == 0:
    print("WARNING: Image is completely black!")
elif mean < 5:
    print("WARNING: Image is almost completely black!")
else:
    print("Image looks valid.")
