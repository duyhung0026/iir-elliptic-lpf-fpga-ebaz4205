import serial
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from collections import deque
 
PORT     = 'COM5'
BAUD     = 921600
VREF     = 3.3
BUF_SIZE = 1500
 
ser = serial.Serial(PORT, BAUD, timeout=0.01)
ser.reset_input_buffer()
 
buf = deque([0.0] * BUF_SIZE, maxlen=BUF_SIZE)
 
fig, ax = plt.subplots(figsize=(10, 4))
 
line, = ax.plot(buf, linewidth=1.2)
 
ax.set_ylim(0, VREF)
ax.set_xlim(0, BUF_SIZE)
ax.set_ylabel('Voltage (V)')
ax.set_xlabel('Sample')
ax.set_title(f'FPGA IIR Filter Output — UART {BAUD}')
ax.grid(True, alpha=0.3)
 
val_text = ax.text(0.02, 0.92, '',
                   transform=ax.transAxes,
                   fontsize=10)
 

def parse_frames():

    results = []
    MAX_SAMPLES = 1000

    while len(results) < MAX_SAMPLES:
        if ser.in_waiting < 2:
            break
        high = ser.read(1)
        low  = ser.read(1)

        if len(high) < 1 or len(low) < 1:
            break

        high = high[0]
        low  = low[0]
        adc_val = ((high & 0x0F) << 8) | low
        adc_val = max(0, min(adc_val, 4095))
        voltage = adc_val * VREF / 4095.0
        results.append(voltage)
    return results
def update(frame):

    # tránh buffer UART tràn
    if ser.in_waiting > 12000:
        ser.reset_input_buffer()
    values = parse_frames()
    if values:
        buf.extend(values)
        line.set_ydata(list(buf))
        latest = values[-1]
        adc_raw = int(latest * 4095 / VREF)
        val_text.set_text(
            f'Latest: {latest:.3f} V  (ADC={adc_raw})'
        )
    return line, val_text
ani = animation.FuncAnimation(
    fig,
    update,
    interval=50,
    blit=True,
    cache_frame_data=False
)
plt.tight_layout()
plt.show()
ser.close()
