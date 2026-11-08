import serial
import os

PORT      = 'COM5'
BAUD      = 921600
VREF      = 3.3
N_SAMPLES = 3000
SAVE_DIR  = r'D:\kltn\compare rtl vs matlab\dump_data'

TEST_CASE = 'th2(350)'         # <-- switch 'th1' / 'th2' / 'th3'
ARCH_NAME = 'df1'         # <-- switch 'df1' / 'df1_cascade' / 'tdf2_cascade'

save_path = os.path.join(SAVE_DIR, f'hardware_{ARCH_NAME}({TEST_CASE}).txt')
os.makedirs(SAVE_DIR, exist_ok=True)

print(f'[{TEST_CASE.upper()}] {ARCH_NAME} - Collecting {N_SAMPLES} samples...')

ser = serial.Serial(PORT, BAUD, timeout=2)
ser.reset_input_buffer()

adc_values = []
while len(adc_values) < N_SAMPLES:
    if ser.in_waiting >= 2:
        high = ser.read(1)[0]
        low  = ser.read(1)[0]
        val  = ((high & 0x0F) << 8) | low
        val  = max(0, min(val, 4095))
        adc_values.append(val)

ser.close()

with open(save_path, 'w') as f:
    for v in adc_values:
        f.write(f'{v}\n')

print(f'Saved {len(adc_values)} samples -> {save_path}')
