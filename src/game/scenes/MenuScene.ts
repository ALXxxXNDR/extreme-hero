import Phaser from 'phaser'
import { gameAudio } from '../audio'
import { COLORS, FONT_FAMILY } from '../palette'

export class MenuScene extends Phaser.Scene {
  constructor() {
    super('Menu')
  }

  create(): void {
    this.cameras.main.setBackgroundColor(COLORS.background)
    this.drawBackground()

    this.add
      .text(640, 104, 'HUMAN DIRECTOR / BUILD 00', {
        fontFamily: FONT_FAMILY,
        fontSize: '16px',
        fontStyle: '700',
        letterSpacing: 3,
        color: '#20d7ff',
      })
      .setOrigin(0.5)

    this.add
      .text(640, 190, 'DEBT\nBREAKER', {
        fontFamily: FONT_FAMILY,
        fontSize: '82px',
        fontStyle: '900',
        align: 'center',
        lineSpacing: -14,
        color: COLORS.text,
        stroke: '#050611',
        strokeThickness: 8,
      })
      .setOrigin(0.5)

    this.add.rectangle(640, 298, 180, 4, COLORS.debt)
    this.add
      .text(640, 334, '선택한 패치는 나를 만들고,\n버린 패치는 보스를 만든다.', {
        fontFamily: FONT_FAMILY,
        fontSize: '25px',
        fontStyle: '700',
        align: 'center',
        lineSpacing: 10,
        color: '#dce5f6',
      })
      .setOrigin(0.5)

    const flowY = 432
    this.flowChip(382, flowY, '01', '블록 파괴', COLORS.cyan)
    this.flowChip(554, flowY, '02', '패치 선택', COLORS.cyan)
    this.flowChip(726, flowY, '03', '부채 누적', COLORS.debt)
    this.flowChip(898, flowY, '04', '보스 결산', COLORS.debt)

    const start = this.add
      .rectangle(640, 560, 286, 68, COLORS.cyan, 1)
      .setStrokeStyle(2, COLORS.cyanSoft, 1)
      .setInteractive({ useHandCursor: true })

    const startLabel = this.add
      .text(640, 560, '새 빌드 시작', {
        fontFamily: FONT_FAMILY,
        fontSize: '22px',
        fontStyle: '800',
        color: '#05101a',
      })
      .setOrigin(0.5)

    this.add
      .text(640, 626, '마우스 이동 · 클릭 발사   /   방향키 이동 · SPACE 발사', {
        fontFamily: FONT_FAMILY,
        fontSize: '15px',
        color: COLORS.muted,
      })
      .setOrigin(0.5)

    const begin = (): void => {
      gameAudio.unlock()
      gameAudio.chord([220, 330, 440], 0.16)
      this.cameras.main.fadeOut(220, 5, 6, 17)
      this.time.delayedCall(220, () => this.scene.start('Game'))
    }

    start.on('pointerover', () => {
      start.setScale(1.025)
      startLabel.setScale(1.025)
    })
    start.on('pointerout', () => {
      start.setScale(1)
      startLabel.setScale(1)
    })
    start.on('pointerdown', begin)
    this.input.keyboard?.once('keydown-ENTER', begin)

    this.tweens.add({
      targets: [start, startLabel],
      alpha: { from: 0.88, to: 1 },
      duration: 900,
      yoyo: true,
      repeat: -1,
      ease: 'Sine.easeInOut',
    })
  }

  private flowChip(x: number, y: number, index: string, label: string, color: number): void {
    this.add.rectangle(x, y, 150, 52, COLORS.surfaceRaised, 0.82).setStrokeStyle(1, color, 0.5)
    this.add
      .text(x - 56, y, index, {
        fontFamily: FONT_FAMILY,
        fontSize: '13px',
        fontStyle: '800',
        color: Phaser.Display.Color.IntegerToColor(color).rgba,
      })
      .setOrigin(0, 0.5)
    this.add
      .text(x - 25, y, label, {
        fontFamily: FONT_FAMILY,
        fontSize: '15px',
        fontStyle: '700',
        color: '#e8efff',
      })
      .setOrigin(0, 0.5)
  }

  private drawBackground(): void {
    const graphics = this.add.graphics()
    graphics.lineStyle(1, COLORS.line, 0.22)
    for (let x = 0; x <= 1280; x += 48) graphics.lineBetween(x, 0, x, 720)
    for (let y = 0; y <= 720; y += 48) graphics.lineBetween(0, y, 1280, y)

    for (let i = 0; i < 34; i += 1) {
      const dot = this.add.circle(
        Phaser.Math.Between(30, 1250),
        Phaser.Math.Between(30, 690),
        Phaser.Math.Between(1, 3),
        i % 4 === 0 ? COLORS.debt : COLORS.cyan,
        Phaser.Math.FloatBetween(0.12, 0.5),
      )
      this.tweens.add({
        targets: dot,
        alpha: 0.05,
        duration: Phaser.Math.Between(800, 2200),
        yoyo: true,
        repeat: -1,
      })
    }
  }
}
