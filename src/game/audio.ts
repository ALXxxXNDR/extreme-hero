export class GameAudio {
  private context?: AudioContext
  private enabled = true

  unlock(): void {
    if (!this.context) {
      const AudioContextClass = window.AudioContext ??
        (window as typeof window & { webkitAudioContext?: typeof AudioContext }).webkitAudioContext
      if (AudioContextClass) this.context = new AudioContextClass()
    }
    void this.context?.resume()
  }

  toggle(): boolean {
    this.enabled = !this.enabled
    return this.enabled
  }

  tone(frequency: number, duration = 0.08, type: OscillatorType = 'sine', gain = 0.035): void {
    if (!this.enabled || !this.context) return
    const now = this.context.currentTime
    const oscillator = this.context.createOscillator()
    const volume = this.context.createGain()
    oscillator.type = type
    oscillator.frequency.setValueAtTime(frequency, now)
    oscillator.frequency.exponentialRampToValueAtTime(Math.max(40, frequency * 0.78), now + duration)
    volume.gain.setValueAtTime(gain, now)
    volume.gain.exponentialRampToValueAtTime(0.0001, now + duration)
    oscillator.connect(volume)
    volume.connect(this.context.destination)
    oscillator.start(now)
    oscillator.stop(now + duration)
  }

  chord(frequencies: number[], duration = 0.2): void {
    frequencies.forEach((frequency, index) => {
      window.setTimeout(() => this.tone(frequency, duration, 'triangle', 0.025), index * 24)
    })
  }
}

export const gameAudio = new GameAudio()
