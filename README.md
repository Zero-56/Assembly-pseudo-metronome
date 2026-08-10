# 🎵 STM8 Metronome

> A fully interrupt-driven metronome built in raw STM8 assembly — no polling loop, no RTOS, just timers, PWM, and external interrupts doing all the work on bare metal.
>
> **Computer Architectures course project — STM8S105C6 dev board**

<!-- TODO: Add a photo of the dev board running the metronome (LED bar + 7-segment display lit up) -->
<!-- ![STM8 Metronome hardware](./docs/board-photo.jpg) -->

---

## 📖 Overview

A 4/4 metronome running entirely on interrupts on an STM8S105C6 microcontroller. Once configured, `main` does nothing but sit in an empty loop (`jra infinite_loop`) — every piece of actual behavior (the beat pulse, the click sound, start/stop) is triggered by hardware interrupts firing on their own schedule, which is the whole point of the exercise: understanding how a real embedded system reacts to events instead of checking for them.

## ✨ Features

- ⏱️ **Hardware-timed beat pulse** — TIM3 fires a periodic interrupt at the configured tempo (90 BPM), completely independent of the CPU doing anything else
- 🔊 **PWM-driven click with per-beat accent** — TIM2 generates the click tone, and its duty cycle changes per beat position (`0%, 15%, 55%, 100%` across the 4 beats of the bar), so the click is audibly louder/quieter depending on where you are in the measure
- 💡 **Rotating LED beat indicator** — a 4-bit pattern shifts left one position per beat (`sll` + `bset`) to show which beat of the bar is currently active
- 🔢 **Multiplexed 7-segment display** — shows the current beat position using a single transistor-switched digit and a lookup table of segment patterns
- 🎛️ **Two independent hardware interrupts for start/stop** — separate buttons on separate GPIO ports/EXTI lines turn the metronome on and off, each with pull-ups enabled to avoid floating-pin noise
- 🧮 **Time-signature groundwork** — a small table (`timesignatures`) is pre-filled at boot to support switching between 1/4 and 4/4 later, even though the current build runs fixed 4/4

## 🛠️ Tech Stack

| Layer | Details |
|---|---|
| Language | STM8 Assembly |
| MCU | STM8S105C6 |
| Toolchain | ST Visual Develop (STVD) |
| Peripherals used | TIM2 (PWM), TIM3 (periodic interrupt), EXTI (external interrupts), GPIO (Ports B, C, D, E, G) |

## 🧠 How It Works

**The main loop is intentionally empty.** After boot-time setup (clearing RAM, configuring timers and GPIO), execution enters `infinite_loop`, which does nothing but jump to itself forever. All real behavior happens in interrupt service routines — this is deliberate: it's the cleanest possible demonstration that on this chip, hardware timers and external interrupts can drive a whole application without the CPU ever polling anything.

**Two timers split the "when" from the "what."** TIM3 is configured purely as a metronome clock — its ARR (auto-reload register) is set so it overflows and fires `LEDBeat` at the beat interval computed from BPM (`2 MHz ÷ (prescaler × beats-per-second)`). TIM2 is configured separately in PWM mode, generating the actual click tone — `LEDBeat` only reaches into TIM2's compare register to change *volume* (duty cycle) each beat, it doesn't retrigger the tone itself. Splitting "when to click" (TIM3) from "how loud the click is" (TIM2 PWM duty cycle) keeps the two concerns cleanly separate.

**Start/stop are their own interrupts, not flags checked elsewhere.** Rather than setting a `running` flag that other code checks, pressing the start or stop button fires its own dedicated interrupt (`start` / `stop`, wired to separate EXTI lines on separate GPIO ports) that directly enables or disables TIM3 and resets the LED/display state. The system genuinely does nothing until an edge is detected on one of those pins.

**The accent pattern comes from one lookup table, indexed by beat position.** `duty_cycles` holds four pre-computed values corresponding to `0%, 15%, 55%, 100%` PWM duty cycle. Each time `LEDBeat` fires, it reads `signature_counter` (which beat of the bar we're on), doubles it to index into the word-sized array, and writes that duty cycle straight into `TIM2_CCR1` — so the click volume pattern across a bar is entirely data-driven from one four-entry table, not four separate code paths.

**Display digit uses transistor multiplexing rather than a dedicated driver chip.** A single transistor on Port G switches the digit on/off, while Port C drives the 7 segments directly from a `digits` lookup table indexed by beat position — a minimal way to drive a 7-segment display without extra driver hardware, at the cost of needing the code to explicitly turn the digit on and off around each update.

## 🚀 Getting Started

**Requirements:** ST Visual Develop (STVD) or equivalent STM8 toolchain, an STM8S105C6-based dev board (as provided for the course), and an ST-LINK programmer/debugger.

```bash
# Clone the repo
git clone https://github.com/[your-username]/stm8-metronome.git
cd stm8-metronome

# Open exercise1/ as a project in STVD, build, and flash via ST-LINK
```

> **Note:** This targets specific university dev board wiring (button/LED/display pin assignments in `main.asm`'s GPIO config). Running on different hardware would require adjusting the port assignments to match your board's schematic.

## 📁 Project Structure

```
stm8-metronome/
├── exercise1/
│   ├── main.asm          # All application logic — setup, ISRs, vector table
│   ├── mapping.asm/.inc  # STVD-generated memory segment mapping (auto-generated, don't edit)
│   └── ...                # STVD project/build files
├── STM8S105C6.asm/.inc    # Vendor-provided chip register definitions
```

## 🧠 What I Learned

[ 2-4 sentences — e.g. what it's like debugging without a debugger vs. with one, working directly with timer prescalers/ARR math instead of a HAL, thinking in interrupts rather than sequential logic, anything about the course itself. ]

## 📄 License

[ Choose a license, e.g. MIT — or leave as "All rights reserved" if this was coursework ]

---

<!--
TODO before publishing:
- [ ] Add a photo or short video of the metronome running on the board
- [ ] Fill in "What I Learned"
- [ ] Confirm solo vs. team (course exercises are sometimes solo, sometimes paired — adjust credit accordingly)
- [ ] Consider excluding Debug/ and Release/ build-artifact folders and IDE workspace files (.stw, .wdb, .wed) via .gitignore — these are regenerated by STVD and don't need to be in version control
-->
