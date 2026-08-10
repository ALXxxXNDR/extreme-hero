import Phaser from 'phaser'
import './style.css'
import { BootScene } from './game/scenes/BootScene'
import { GameScene } from './game/scenes/GameScene'
import { MenuScene } from './game/scenes/MenuScene'

document.querySelector<HTMLDivElement>('#app')!.innerHTML = `
  <main class="game-shell" aria-label="DEBT BREAKER 게임">
    <div id="game"></div>
    <p class="orientation-note">화면을 가로로 돌리면 더 편하게 플레이할 수 있습니다.</p>
  </main>
`

const game = new Phaser.Game({
  type: Phaser.AUTO,
  parent: 'game',
  width: 1280,
  height: 720,
  backgroundColor: '#070914',
  pixelArt: false,
  antialias: true,
  physics: {
    default: 'arcade',
    arcade: {
      gravity: { x: 0, y: 0 },
      debug: false,
    },
  },
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
  },
  scene: [BootScene, MenuScene, GameScene],
})

if (import.meta.env.DEV) {
  ;(window as typeof window & { __DEBT_BREAKER_GAME__?: Phaser.Game }).__DEBT_BREAKER_GAME__ = game
}
